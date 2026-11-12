import QtQuick

// A button on the pause screen. The primary one is filled, pale on navy; the
// other is quieter text, so going on takes a deliberate look. Enter or Space
// presses whichever has focus, and focus shows as an outline.
FocusScope {
    id: button
    property string text
    property bool primary: false
    signal activated()

    implicitWidth: label.implicitWidth + (primary ? 88 : 48)
    implicitHeight: label.implicitHeight + (primary ? 36 : 24)
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: Math.min(4, theme.radius)
        color: button.primary ? (hover.hovered ? "#ffffff" : "#e6ecff") : "transparent"
        border.width: !button.primary && button.activeFocus ? 1 : 0
        border.color: button.primary ? "#7f9cf0" : "#5b74c2"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // A focus ring outside the filled button, so it shows against the fill.
    Rectangle {
        visible: button.primary && button.activeFocus
        anchors.fill: parent
        anchors.margins: -5
        radius: Math.min(4, theme.radius) + 3
        color: "transparent"
        border.width: 2
        border.color: "#6f8de8"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? "#0a1640" : (hover.hovered || button.activeFocus ? "#d4ddfb" : "#8ea2d8")
        font.pixelSize: button.primary ? 19 : 16
        font.weight: button.primary ? Font.DemiBold : Font.Normal
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.activated() }

    Keys.onReturnPressed: button.activated()
    Keys.onEnterPressed: button.activated()
    Keys.onSpacePressed: button.activated()
}
