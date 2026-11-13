import QtQuick
import QtQuick.Window

// The pause, drawn the way one sec draws it, in navy. A black screen asks
// for a deep breath; a square-edged sheet rises from the bottom
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
    // Whether the choice is showing (greyed out), and whether it can be picked.
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

        // The words, on black, the whole time. The background never changes.
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height * 0.08
            width: Math.min(parent.width - 64, 640)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            // Trailing dots like one sec, unless the phrase already ends in some.
            text: /[.…!?]$/.test(session.phrase) ? session.phrase : session.phrase + "..."
            color: "#ffffff"
            font.pixelSize: 46
            font.weight: Font.Bold
        }

        // The breath: a sheet rising from the bottom with a flat, square top,
        // navy all the way down, a touch lighter at the top. Square like
        // Omarchy's windows, not rounded like one sec's phone screen.
        Rectangle {
            id: sheet
            x: 0
            width: parent.width
            y: parent.height * (1 - root.level)
            height: parent.height * root.level
            visible: root.level > 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1c2f6e" }
                GradientStop { position: 1.0; color: "#08102e" }
            }
        }

        // The choice, in the lower third, drawn over the sheet. It fades in
        // greyed out halfway through the last breath out, and wakes up once
        // the sheet is gone.
        Item {
            anchors.fill: parent

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 2 / 3
                spacing: 20
                opacity: root.choosing ? 1 : (root.revealed ? 0.35 : 0)
                visible: opacity > 0
                enabled: root.choosing
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }

                // Small, and not the main part: how often today.
                Text {
                    visible: !session.alreadyOpen
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("%n attempts to open %1 today", "", session.attempts).arg(session.appName)
                    color: "#d9e2ff"
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    bottomPadding: 8
                }

                // On YouTube, YouLearn is the way in worth taking, so it
                // comes first and has the focus.
                ChoiceButton {
                    id: learnButton
                    visible: session.offerYouLearn
                    anchors.horizontalCenter: parent.horizontalCenter
                    primary: true
                    text: qsTr("Open YouLearn instead")
                    KeyNavigation.tab: stayButton
                    KeyNavigation.down: stayButton
                    onActivated: session.openYouLearn()
                }

                ChoiceButton {
                    id: stayButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    primary: !session.offerYouLearn
                    outline: session.offerYouLearn
                    text: session.alreadyOpen ? qsTr("I don't want %1 open").arg(session.appName)
                                              : qsTr("I don't want to open %1").arg(session.appName)
                    KeyNavigation.tab: goButton
                    KeyNavigation.down: goButton
                    KeyNavigation.up: session.offerYouLearn ? learnButton : null
                    onActivated: session.dontOpen()
                }

                ChoiceButton {
                    id: goButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Continue to %1").arg(session.appName)
                    KeyNavigation.tab: session.offerYouLearn ? learnButton : stayButton
                    KeyNavigation.up: stayButton
                    onActivated: session.continueToApp()
                }
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
            if (session.offerYouLearn) learnButton.forceActiveFocus()
            else stayButton.forceActiveFocus()
            return
        }
        breathsLeft -= 1
        breath.start()
    }

    SequentialAnimation {
        id: breath
        NumberAnimation { target: root; property: "level"; to: 1; duration: root.inhaleMs; easing.type: Easing.InOutSine }
        // On the last breath out, the choice fades in greyed out once the
        // sheet is halfway down, before it's all the way gone.
        ParallelAnimation {
            NumberAnimation { target: root; property: "level"; to: 0; duration: root.exhaleMs; easing.type: Easing.InOutSine }
            SequentialAnimation {
                PauseAnimation { duration: root.exhaleMs / 2 }
                ScriptAction { script: if (root.breathsLeft === 0) root.revealed = true }
            }
        }
        onFinished: root.nextBreath()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: session.dontOpen()
    }
}
