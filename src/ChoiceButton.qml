import QtQuick

// A button on the choice screen, as one sec has them: the way out is a pale
// pill, and going on is plain text under it, so it takes a deliberate look.
// Enter or Space presses whichever has focus, and focus shows as a ring or
// an underline.
FocusScope {
    id: button
    property string text
    property bool primary: false
    signal activated()

    implicitWidth: label.implicitWidth + (primary ? 112 : 32)
    implicitHeight: label.implicitHeight + (primary ? 36 : 16)
    activeFocusOnTab: true

    Rectangle {
        visible: button.primary
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? "#ffffff" : "#e8eeff"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // The focus ring sits outside the pill, so it shows against both.
    Rectangle {
        visible: button.primary && button.activeFocus
        anchors.fill: parent
        anchors.margins: -6
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: "#ffffff"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? "#13205a" : "#ffffff"
        opacity: button.primary || hover.hovered || button.activeFocus ? 1 : 0.85
        font.pixelSize: button.primary ? 19 : 16
        font.weight: button.primary ? Font.DemiBold : Font.Medium
        font.underline: !button.primary && button.activeFocus
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.activated() }

    Keys.onReturnPressed: button.activated()
    Keys.onEnterPressed: button.activated()
    Keys.onSpacePressed: button.activated()
}
