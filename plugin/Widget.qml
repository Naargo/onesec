import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

// OneSec in the bar: a circle that's empty while OneSec is off and half full
// while it's on, like the breathing sheet halfway up. Click turns it on or
// off (the same as Super + `), right-click opens its settings.
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
    iconComponent: Component {
      Item {
        id: icon
        readonly property real size: button.iconSize * 0.86
        readonly property real stroke: Math.max(1.5, size * 0.11)
        readonly property real r: size / 2 - stroke / 2
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // How full the circle is: the sheet's flat top sits at this height.
        readonly property real fill: root.isOn ? 0.5 : 0
        readonly property real topY: cy + r - 2 * r * fill
        readonly property real halfChord: Math.sqrt(Math.max(0, r * r - (topY - cy) * (topY - cy)))
        readonly property color ink: button.foreground

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            strokeColor: icon.ink
            strokeWidth: icon.stroke
            fillColor: "transparent"
            startX: icon.cx + icon.r; startY: icon.cy
            PathArc { x: icon.cx - icon.r; y: icon.cy; radiusX: icon.r; radiusY: icon.r }
            PathArc { x: icon.cx + icon.r; y: icon.cy; radiusX: icon.r; radiusY: icon.r }
          }

          ShapePath {
            strokeWidth: -1
            fillColor: icon.fill > 0 ? icon.ink : "transparent"
            startX: icon.cx - icon.halfChord; startY: icon.topY
            PathLine { x: icon.cx + icon.halfChord; y: icon.topY }
            PathArc {
              x: icon.cx - icon.halfChord; y: icon.topY
              radiusX: icon.r; radiusY: icon.r
              direction: PathArc.Clockwise
              useLargeArc: icon.fill > 0.5
            }
          }
        }
      }
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("onesec")
      else root.bar.run("onesec toggle")
    }
  }
}
