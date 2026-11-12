// OneSec for websites. While OneSec is on, a tab heading to one of the
// websites picked in OneSec is held on a blank page while OneSec's own
// full-screen breathing pause runs, the same one apps get. Going on loads the
// page; not going on closes the tab. Turning OneSec on also holds the tabs
// already open on those websites, behind one pause for all of them.
//
// The helper on the laptop (onesec-host) keeps this worker up to date with
// OneSec's settings and runs the pause when asked. If the helper isn't
// there, nothing is held: a broken helper never strands a page.

const HOST = 'com.onesec.omarchy';
const HOLD_PAGE = chrome.runtime.getURL('hold.html');

let port = null;
let settings = null; // { enabled, sites, graceMinutes } once the helper answers
let nextId = 1;

const grace = new Map();    // site -> time (ms) until which it opens without a pause
const pauses = new Map();   // pause id -> { sites, tabs: [{ tabId, url }] }
const pausing = new Map();  // site -> pause id, so one site never gets two pauses
const allowOnce = new Set(); // tab ids about to load the page they were held from

function connect() {
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (error) {
    port = null;
    return;
  }
  port.onMessage.addListener(onHostMessage);
  port.onDisconnect.addListener(() => {
    void chrome.runtime.lastError;
    port = null;
    settings = null;
    // Let anything held go, rather than leave it on a blank page.
    for (const id of [...pauses.keys()]) answer(id, true);
    setTimeout(connect, 5000);
  });
}

// The website a URL belongs to, if it's one OneSec watches.
function siteFor(url) {
  if (!settings || !url) return null;
  let host;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
    host = parsed.hostname.toLowerCase().replace(/^www\./, '');
  } catch (error) {
    return null;
  }
  return settings.sites.find((site) => host === site || host.endsWith('.' + site)) || null;
}

function inGrace(site) {
  return (grace.get(site) || 0) > Date.now();
}

function holdUrl(site) {
  return HOLD_PAGE + '#' + encodeURIComponent(site);
}

// Holds the tab and asks for a pause, or joins the pause already running for
// that site.
function hold(tabs, alreadyOpen) {
  if (!port || tabs.length === 0) return;
  const fresh = [];
  for (const tab of tabs) {
    const running = pausing.get(tab.site);
    if (running) pauses.get(running).tabs.push(tab);
    else fresh.push(tab);
    chrome.tabs.update(tab.tabId, { url: holdUrl(tab.site) }).catch(() => {});
  }
  if (fresh.length === 0) return;

  const id = nextId++;
  const sites = [...new Set(fresh.map((tab) => tab.site))];
  pauses.set(id, { sites, tabs: fresh });
  for (const site of sites) pausing.set(site, id);
  port.postMessage({ type: 'pause', id, sites, open: alreadyOpen });
}

function answer(id, go) {
  const pause = pauses.get(id);
  if (!pause) return;
  pauses.delete(id);
  for (const site of pause.sites) {
    pausing.delete(site);
    if (go && settings) grace.set(site, Date.now() + settings.graceMinutes * 60000);
  }
  for (const tab of pause.tabs) {
    if (go) {
      allowOnce.add(tab.tabId);
      chrome.tabs.update(tab.tabId, { url: tab.url }).catch(() => allowOnce.delete(tab.tabId));
    } else {
      chrome.tabs.remove(tab.tabId).catch(() => {});
    }
  }
}

// When OneSec comes on, the tabs already open on its websites get the same
// pause, all behind one.
async function holdOpenTabs() {
  const tabs = await chrome.tabs.query({});
  const held = [];
  for (const tab of tabs) {
    const site = siteFor(tab.url);
    if (site && !inGrace(site)) held.push({ tabId: tab.id, url: tab.url, site });
  }
  hold(held, true);
}

function onHostMessage(message) {
  if (message?.type === 'settings') {
    const wasEnabled = settings?.enabled;
    settings = {
      enabled: message.enabled === true,
      sites: Array.isArray(message.sites) ? message.sites.map(String) : [],
      graceMinutes: Number(message.graceMinutes) || 0,
    };
    // Only a real switch from off to on, not the browser starting with
    // OneSec already on.
    if (settings.enabled && wasEnabled === false) holdOpenTabs();
    if (!settings.enabled) grace.clear();
  } else if (message?.type === 'answer') {
    answer(message.id, message.go === true);
  }
}

chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId !== 0) return;
  if (allowOnce.delete(details.tabId)) return;
  if (!settings?.enabled) return;
  const site = siteFor(details.url);
  if (!site || inGrace(site)) return;
  hold([{ tabId: details.tabId, url: details.url, site }], false);
});

// A held tab closed by hand no longer needs bringing back.
chrome.tabs.onRemoved.addListener((tabId) => {
  allowOnce.delete(tabId);
  for (const pause of pauses.values()) pause.tabs = pause.tabs.filter((tab) => tab.tabId !== tabId);
});

connect();
