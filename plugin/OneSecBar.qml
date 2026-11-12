import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

// OneSec in the bar: an hourglass, an empty outline while OneSec is off
// and solid while it's on. Click turns it on or off (the same as Super + `),
// right-click opens its settings.
//
// The state comes from OneSec's own config file, watched for changes, so
// the icon follows the key, the settings window and this button alike.
BarWidget {
  id: root
  moduleName: "tom.onesec"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property bool isOn: false

  function readConfig(text) {
    try {
      root.isOn = JSON.parse(text).enabled === true
    } catch (e) {
      root.isOn = false
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/onesec/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readConfig(text())
    onLoadFailed: root.readConfig("")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.isOn ? strings.t("tooltip.on") : strings.t("tooltip.off")
    // An hourglass from the bar's icon font, like its neighbours: an empty
    // outline while OneSec is off, solid while it's on, so the two read
    // apart at a glance.
    text: String.fromCodePoint(root.isOn ? 0xF078C : 0xF06AD)
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("onesec")
      else root.bar.run("onesec toggle")
    }
  }
}
