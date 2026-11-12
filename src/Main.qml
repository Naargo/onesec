import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The settings window: OneSec on or off, which apps get a pause, and how the
// pause goes. Every change saves at once; there's no Save button.
ApplicationWindow {
    id: window
    width: 620
    height: 760
    minimumWidth: 460
    minimumHeight: 520
    visible: true
    title: "OneSec"
    color: "#121318"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property var allApps: catalog.apps()
    property string filter: ""
    readonly property var shownApps: allApps.filter(app =>
        filter === "" || app.name.toLowerCase().indexOf(filter.toLowerCase()) >= 0)

    function textFocused() {
        return activeFocusItem && activeFocusItem.hasOwnProperty("cursorPosition")
    }

    Shortcut {
        sequence: "?"
        context: Qt.ApplicationShortcut
        enabled: !window.textFocused()
        onActivated: help.visible = !help.visible
    }
    Shortcut {
        sequence: "Q"
        context: Qt.ApplicationShortcut
        enabled: !window.textFocused()
        onActivated: Qt.quit()
    }
    Shortcut {
        sequence: "Ctrl+F"
        context: Qt.ApplicationShortcut
        onActivated: search.forceActiveFocus()
    }
    Shortcut {
        sequence: "Ctrl+O"
        context: Qt.ApplicationShortcut
        onActivated: config.enabled = !config.enabled
    }
    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.ApplicationShortcut
        onActivated: config.tryPause()
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (help.visible) help.visible = false
            else if (search.text !== "") search.text = ""
            else appList.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18

        // On or off, which is the whole point most days.
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    text: "OneSec"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: "#9a9cab"
                    text: config.enabled
                          ? qsTr("On. The apps you pick open after a breath.")
                          : qsTr("Off. Your apps open right away.")
                }
            }

            Switch {
                id: onSwitch
                checked: config.enabled
                onToggled: config.enabled = checked
            }
        }

        // Saying what's wrong: without the hook, nothing gets paused.
        Label {
            visible: !config.hookLoaded
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: "#ff8a80"
            text: qsTr("Hyprland hasn't loaded OneSec yet, so nothing will be paused. Add this line to ~/.config/hypr/hyprland.lua:")
                  + "\npcall(dofile, \"/usr/share/onesec/onesec.lua\")"
        }

        Label {
            text: qsTr("Apps")
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: qsTr("Search apps")
            onTextChanged: window.filter = text
            Keys.onDownPressed: appList.forceActiveFocus()
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: window.shownApps
            keyNavigationEnabled: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Keys.onSpacePressed: if (currentItem) currentItem.toggle()
            Keys.onReturnPressed: if (currentItem) currentItem.toggle()

            delegate: ItemDelegate {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 48
                highlighted: ListView.isCurrentItem && appList.activeFocus
                property bool watched: config.isWatched(modelData.id)
                Connections {
                    target: config
                    function onChanged() { row.watched = config.isWatched(row.modelData.id) }
                }
                function toggle() { config.setWatched(modelData, !watched) }
                onClicked: { appList.currentIndex = index; toggle() }

                contentItem: RowLayout {
                    spacing: 14
                    Image {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        sourceSize: Qt.size(52, 52)
                        source: row.modelData.icon ? "image://icon/" + encodeURIComponent(row.modelData.icon) : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 15
                    }
                    CheckBox {
                        checked: row.watched
                        focusPolicy: Qt.NoFocus
                        onToggled: row.toggle()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#262833" }

        Label {
            text: qsTr("The pause")
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 6

            Label { text: qsTr("Words on screen") }
            TextField {
                Layout.fillWidth: true
                text: config.phrase
                onEditingFinished: config.phrase = text
            }

            Label { text: qsTr("Breaths") }
            SpinBox {
                from: 1; to: 5
                value: config.breaths
                onValueModified: config.breaths = value
            }

            Label {
                text: qsTr("No pause again for")
            }
            RowLayout {
                SpinBox {
                    from: 0; to: 60
                    value: config.graceMinutes
                    onValueModified: config.graceMinutes = value
                }
                Label {
                    text: qsTr("minutes after you go on")
                    color: "#9a9cab"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: qsTr("Try the pause")
                onClicked: config.tryPause()
            }
            Item { Layout.fillWidth: true }
            Label {
                color: "#6f7180"
                text: qsTr("Super + ` turns OneSec on and off.  ? for shortcuts")
            }
        }
    }

    HelpOverlay {
        id: help
        anchors.fill: parent
        visible: false
        onClosed: visible = false
    }
}
