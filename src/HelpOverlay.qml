import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Every shortcut, shown with ?.
Rectangle {
    id: root
    signal closed()

    color: "#cc000000"

    MouseArea { anchors.fill: parent; onClicked: root.closed() }

    readonly property var shortcuts: [
        ["?", qsTr("Show or hide shortcuts")],
        ["Super+`", qsTr("Turn OneSec on or off, from anywhere")],
        ["Ctrl+O", qsTr("Turn OneSec on or off")],
        ["Ctrl+F", qsTr("Search apps")],
        ["Space / Enter", qsTr("Pick or unpick the app")],
        ["Ctrl+T", qsTr("Try the pause")],
        ["Esc", qsTr("Close this, or clear the search")],
        ["Q", qsTr("Quit")]
    ]

    Pane {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 480)
        padding: 22
        background: Rectangle {
            color: "#1b1b1f"
            radius: theme.radius
            border.color: "#2c2c32"
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
                text: qsTr("Shortcuts")
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            GridLayout {
                columns: 2
                columnSpacing: 20
                rowSpacing: 8

                Repeater {
                    model: root.shortcuts
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 0
                        text: modelData[0]
                        font.family: "monospace"
                        color: theme.accent
                    }
                }

                Repeater {
                    model: root.shortcuts
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.row: index
                        Layout.column: 1
                        text: modelData[1]
                    }
                }
            }
        }
    }
}
