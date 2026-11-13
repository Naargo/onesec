import QtQuick

// A button on the choice screen, laid out as one sec has them but with
// corners that follow Hyprland's rounding (square by default): the way out
// is a pale block, and going on is plain text under it, so it takes a
// deliberate look. Enter or Space presses whichever has focus, and focus
// shows as a ring or an underline.
FocusScope {
    id: button
    property string text
    property bool primary: false
    // A second block, outlined rather than filled, for when there are two
    // ways out (YouTube: YouLearn, or not at all).
    property bool outline: false
    signal activated()

    readonly property bool block: primary || outline
    implicitWidth: label.implicitWidth + (block ? 112 : 32)
    implicitHeight: label.implicitHeight + (block ? 36 : 16)
    activeFocusOnTab: true

    Rectangle {
        visible: button.block
        anchors.fill: parent
        radius: Math.min(4, theme.radius)
        color: button.primary ? (hover.hovered ? "#ffffff" : "#e8eeff")
                              : (hover.hovered ? "#24ffffff" : "transparent")
        border.width: button.outline ? 2 : 0
        border.color: "#e8eeff"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // The focus ring sits outside the block, so it shows against both.
    Rectangle {
        visible: button.block && button.activeFocus
        anchors.fill: parent
        anchors.margins: -6
        radius: Math.min(4, theme.radius)
        color: "transparent"
        border.width: 2
        border.color: "#ffffff"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? "#13205a" : "#ffffff"
        opacity: button.block || hover.hovered || button.activeFocus ? 1 : 0.85
        font.pixelSize: 19
        font.weight: Font.Bold
        font.underline: !button.block && button.activeFocus
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.activated() }

    Keys.onReturnPressed: button.activated()
    Keys.onEnterPressed: button.activated()
    Keys.onSpacePressed: button.activated()
}
