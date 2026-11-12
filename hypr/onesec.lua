-- OneSec for Hyprland: a breathing pause in front of the apps you pick, while
-- OneSec is on.
--
-- While it's on, a window rule sends every new window of a watched app to a
-- hidden workspace from its first frame, so it never shows. The hook below
-- then starts `onesec pause`, which covers the screen with the breathing
-- exercise. When you choose, the pause calls back through hyprctl:
-- onesec_release() brings the window back where it would have opened,
-- onesec_dismiss() closes it. Turning OneSec off brings back anything still
-- waiting, so a crashed pause never strands a window.
--
-- Load it from ~/.config/hypr/hyprland.lua:
--   pcall(dofile, "/usr/share/onesec/onesec.lua")

local HOLD = "special:onesec"
local RULE = "onesec-hold"
local STATE_FILE = os.getenv("HOME") .. "/.local/state/onesec/hypr.lua"
-- A pause that hasn't answered in this long is treated as gone, and the
-- next window of that app gets a fresh one.
local PAUSE_TIMEOUT = 600

-- Kept in a global so a config reload doesn't forget windows that are
-- waiting or apps still inside their grace period.
onesec_state = onesec_state or { held = {}, pausing = {}, grace = {}, settings = nil }
local S = onesec_state

local function load_settings()
  local ok, settings = pcall(dofile, STATE_FILE)
  if not ok or type(settings) ~= "table" then
    settings = {}
  end
  settings.enabled = settings.enabled == true
  settings.classes = type(settings.classes) == "table" and settings.classes or {}
  settings.grace = tonumber(settings.grace) or 300
  settings.command = type(settings.command) == "string" and settings.command or "onesec"
  S.settings = settings
end

-- Window classes are matched as a regular expression, and web app classes
-- carry dots and the like, so escape everything that means something there.
local function escape(text)
  return (text:gsub("[%^%$%(%)%.%[%]%*%+%?%{%}|\\]", "\\%0"))
end

local function shell_quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function sync_rule()
  local settings = S.settings
  if settings.enabled and #settings.classes > 0 then
    local parts = {}
    for _, class in ipairs(settings.classes) do
      table.insert(parts, escape(class))
    end
    hl.window_rule({
      name = RULE,
      enabled = true,
      match = { class = "^(" .. table.concat(parts, "|") .. ")$" },
      workspace = HOLD .. " silent",
    })
  else
    hl.window_rule({ name = RULE, enabled = false })
  end
end

local function exists(address)
  return hl.get_window("address:" .. address) ~= nil
end

local function release(class)
  local last
  for _, held in ipairs(S.held[class] or {}) do
    if exists(held.address) then
      hl.dispatch(hl.dsp.window.move({ workspace = held.workspace, follow = true, window = "address:" .. held.address }))
      last = held.address
    end
  end
  if last then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. last }))
  end
  S.held[class] = nil
  S.pausing[class] = nil
end

-- Where a window would have opened: the workspace you're looking at.
local function current_workspace()
  local workspace = hl.get_active_workspace()
  if not workspace then
    return "1"
  end
  return workspace.special and workspace.name or tostring(workspace.id)
end

hl.on("window.open", function(window)
  if not window.workspace or window.workspace.name ~= HOLD then
    return
  end
  local class = window.class
  S.held[class] = S.held[class] or {}
  table.insert(S.held[class], { address = window.address, workspace = current_workspace() })

  -- Coming back within the grace period, or with OneSec turned off since the
  -- rule fired, skips the pause.
  if not S.settings.enabled or (S.grace[class] or 0) > os.time() then
    release(class)
    return
  end

  -- An app that opens several windows at once gets one pause, which answers
  -- for all of them.
  local started = S.pausing[class]
  if started and os.time() - started < PAUSE_TIMEOUT then
    return
  end
  S.pausing[class] = os.time()
  hl.exec_cmd(shell_quote(S.settings.command) .. " pause " .. shell_quote(class))
end)

-- Called by `onesec pause` through hyprctl. Each returns a no-op dispatcher,
-- because hyprctl dispatch expects one.
function onesec_release(class)
  S.grace[class] = os.time() + S.settings.grace
  release(class)
  return hl.dsp.no_op()
end

function onesec_dismiss(class)
  for _, held in ipairs(S.held[class] or {}) do
    if exists(held.address) then
      hl.dispatch(hl.dsp.window.close({ window = "address:" .. held.address }))
    end
  end
  S.held[class] = nil
  S.pausing[class] = nil
  return hl.dsp.no_op()
end

-- Called by the OneSec app after every settings change.
function onesec_sync()
  load_settings()
  sync_rule()
  if not S.settings.enabled then
    for class in pairs(S.held) do
      release(class)
    end
    S.pausing = {}
    S.grace = {}
  end
  return hl.dsp.no_op()
end

onesec_sync()
