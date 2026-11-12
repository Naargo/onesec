import QtQuick
import QtQuick.Window

// The pause, drawn the way one sec draws it, in navy. A black screen asks
// for a deep breath; a sheet with rounded top corners rises from the bottom
// while you breathe in until it covers everything, then sinks while you
// breathe out. The last time it sinks it uncovers the choice underneath. It
// covers the whole screen, above the bar, until you answer. Esc always gets
// you out, by not opening the app (or closing it, if it was already open).
Window {
    id: root
    visible: false
    title: "OneSec"
    width: Screen.width
    height: Screen.height
    color: "#05070d"

    // How much of the screen the sheet covers, from 0 to 1.
    property real level: 0
    // Whether the choice is under the sheet yet, and whether it's showing.
    property bool revealed: false
    property bool choosing: false

    readonly property int inhaleMs: 10000
    readonly property int exhaleMs: 10000

    function quit() { Qt.callLater(Qt.quit) }

    Connections {
        target: session
        function onFinished() { leave.start() }
    }

    // Fading out before quitting, so the app (or the desktop) doesn't snap in.
    NumberAnimation {
        id: leave
        target: scene; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InQuad
        onFinished: root.quit()
    }

    Item {
        id: scene
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: { appear.start(); breathing.start() }
        NumberAnimation on opacity { id: appear; running: false; to: 1; duration: 400; easing.type: Easing.OutQuad }

        // Before: black, and the words.
        Text {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 640)
            visible: !root.revealed
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            // Trailing dots like one sec, unless the phrase already ends in some.
            text: /[.…!?]$/.test(session.phrase) ? session.phrase : session.phrase + "..."
            color: "#ffffff"
            font.pixelSize: 46
            font.weight: Font.Bold
        }

        // After: the choice, on a navy gradient, uncovered by the last breath out.
        Rectangle {
            anchors.fill: parent
            visible: root.revealed
            gradient: Gradient {
                GradientStop { position: 0.00; color: "#0b1442" }
                GradientStop { position: 0.45; color: "#1a3590" }
                GradientStop { position: 1.00; color: "#4a78de" }
            }

            // Small, and not the main part: how often today.
            Text {
                visible: !session.alreadyOpen
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.08
                width: Math.min(parent.width - 64, 560)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("%n attempts to open %1 today", "", session.attempts).arg(session.appName)
                color: "#d9e2ff"
                font.pixelSize: 20
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.max(48, parent.height * 0.09)
                spacing: 20
                opacity: root.choosing ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }

                ChoiceButton {
                    id: stayButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    primary: true
                    text: session.alreadyOpen ? qsTr("I don't want %1 open").arg(session.appName)
                                              : qsTr("I don't want to open %1").arg(session.appName)
                    KeyNavigation.tab: goButton
                    KeyNavigation.down: goButton
                    onActivated: session.dontOpen()
                }

                ChoiceButton {
                    id: goButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Continue to %1").arg(session.appName)
                    KeyNavigation.tab: stayButton
                    KeyNavigation.up: stayButton
                    onActivated: session.continueToApp()
                }
            }
        }

        // The breath: a sheet rising from the bottom, flat-topped with rounded
        // corners, slate blue fading down into navy. It runs past the bottom
        // edge by its corner radius so only the top corners are round.
        Rectangle {
            id: sheet
            readonly property real corner: 40
            x: 0
            width: parent.width
            y: parent.height * (1 - root.level)
            height: parent.height * root.level + corner
            visible: root.level > 0
            radius: corner
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#8497c0" }
                GradientStop { position: 1.0; color: "#25347a" }
            }
        }

        Text {
            visible: session.preview
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24
            text: qsTr("Preview")
            color: "#7d8bb5"
            font.pixelSize: 14
        }

        SequentialAnimation {
            id: breathing
            running: false
            PauseAnimation { duration: 600 }
            ScriptAction { script: root.breathe(session.breaths) }
        }
    }

    // One breath at a time: ten seconds up, ten seconds down. Built as a
    // chain rather than one long animation so the number of breaths can come
    // from the settings.
    property int breathsLeft: 0
    function breathe(count) {
        breathsLeft = count
        nextBreath()
    }
    function nextBreath() {
        if (breathsLeft <= 0) {
            choosing = true
            stayButton.forceActiveFocus()
            return
        }
        breathsLeft -= 1
        breath.start()
    }

    SequentialAnimation {
        id: breath
        NumberAnimation { target: root; property: "level"; to: 1; duration: root.inhaleMs; easing.type: Easing.InOutSine }
        // Swapped while the sheet covers everything, so the last breath out
        // uncovers the choice instead of the words.
        ScriptAction { script: if (root.breathsLeft === 0) root.revealed = true }
        NumberAnimation { target: root; property: "level"; to: 0; duration: root.exhaleMs; easing.type: Easing.InOutSine }
        onFinished: root.nextBreath()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: session.dontOpen()
    }
}
