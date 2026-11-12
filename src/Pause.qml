import QtQuick
import QtQuick.Window

// The pause: one slow breath (or a few) drawn as a navy horizon that rises while
// you breathe in and sinks while you breathe out, then the choice. It covers
// the whole screen, above the bar, until you answer. Esc always gets you out,
// by not opening the app.
Window {
    id: root
    visible: false
    title: "OneSec"
    width: Screen.width
    height: Screen.height
    color: "#03060f"

    // How high the horizon has risen, from 0 to 1. The breathing animation
    // drives it; everything else follows.
    property real level: 0
    property string cue: ""
    property bool choosing: false

    readonly property int inhaleMs: 4000
    readonly property int holdMs: 1200
    readonly property int exhaleMs: 5000
    readonly property real low: 0.12
    readonly property real high: 0.80

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
        NumberAnimation on opacity { id: appear; running: false; to: 1; duration: 500; easing.type: Easing.OutQuad }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#02040b" }
                GradientStop { position: 1.0; color: "#070d22" }
            }
        }

        Horizon {
            anchors.fill: parent
            level: root.level
        }

        // What to do right now, above the horizon.
        Column {
            id: breathText
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.24
            width: parent.width - 64
            spacing: 18
            opacity: root.choosing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 500 } }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: session.phrase
                color: "#f2f5ff"
                font.pixelSize: 40
                font.weight: Font.Medium
            }

            Text {
                id: cueText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.cue
                color: "#9fb3ee"
                font.pixelSize: 21
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: cueText; property: "opacity"; to: 0; duration: 300 }
                        PropertyAction {}
                        NumberAnimation { target: cueText; property: "opacity"; to: 1; duration: 400 }
                    }
                }
            }
        }

        SequentialAnimation {
            id: breathing
            running: false
            PauseAnimation { duration: 500 }
            ScriptAction { script: root.breathe(session.breaths) }
        }

        // The choice, once the breathing is done.
        Column {
            id: choice
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height * 0.06
            width: Math.min(parent.width - 64, 720)
            spacing: 34
            opacity: root.choosing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Do you still want to open %1?").arg(session.appName)
                color: "#f2f5ff"
                font.pixelSize: 34
                font.weight: Font.Medium
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                ChoiceButton {
                    id: stayButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    primary: true
                    text: qsTr("I don't want to open %1").arg(session.appName)
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

        // Small, and only after the breath: how often today.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.07
            opacity: root.choosing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 900 } }
            text: qsTr("%n attempts to open %1 today", "", session.attempts).arg(session.appName)
            color: "#8396cc"
            font.pixelSize: 15
        }

        Text {
            visible: session.preview
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24
            text: qsTr("Preview")
            color: "#5d6c99"
            font.pixelSize: 14
        }
    }

    // One breath at a time: in, hold, out. Built as a chain rather than one
    // long animation so the number of breaths can come from the settings.
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
        ScriptAction { script: root.cue = qsTr("Breathe in") }
        NumberAnimation { target: root; property: "level"; to: root.high; duration: root.inhaleMs; easing.type: Easing.InOutSine }
        ScriptAction { script: root.cue = qsTr("Hold") }
        PauseAnimation { duration: root.holdMs }
        ScriptAction { script: root.cue = qsTr("Breathe out") }
        NumberAnimation { target: root; property: "level"; to: root.low; duration: root.exhaleMs; easing.type: Easing.InOutSine }
        onFinished: root.nextBreath()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: session.dontOpen()
    }
}
