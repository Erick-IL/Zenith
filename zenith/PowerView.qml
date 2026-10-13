import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Nutrition menu (Super+N) in pill style.
// The first press highlights the action, the second confirms to
// An accidental touch did not turn off the machine. Escape cancels.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property int armed: -1          // index of the action awaiting confirmation
    property int current: 0

    Timer {
        id: disarm
        interval: 4000
        onTriggered: view.armed = -1
    }

    // Icons from the same Material Design family and, more importantly, the same
    // weight group: reboot and shutdown exist only as a stroke,
    // Therefore, the lock and exit are also lined. Filled silhouettes next to
    // they were knocked out and looked like they had been pasted on from another set.
    // The lock disappears from the menu if the lock screen is turned off: press
    // a button that does nothing is worse than no button at all.
    readonly property var actions: view.sys.cfg.featLock ? view.allActions
                                 : view.allActions.filter(a => a.id !== "lock")
    readonly property var allActions: [
        { id: "sleep", icon: "", label: view.sys.tr("Сон"),          cmd: "systemctl suspend",     accent: view.sys.tint("#38bdf8") },  // drawn in letters, see below
        // instant: fires on the first press. Confirmation is needed where
        // An error costs unsaved work - shutdown, reboot, sleep.
        // The lock costs nothing: it can be canceled with the same password used
        // and is removed. To demand a second press on it was to pretend
        // that the button does not work: the first one does nothing.
        { id: "lock", instant: true, icon: String.fromCodePoint(0xF033E), label: view.sys.tr("Блокировка"), cmd: view.sys.scriptDir + "/lock.sh", accent: view.sys.tint("#a78bfa") },  // md-lock_outline
        { icon: String.fromCodePoint(0xF0343), label: view.sys.tr("Выйти"),        cmd: "out=$(hyprctl dispatch 'hl.dsp.exit()' 2>&1); "
              + "case \"$out\" in ok*) ;; *) hyprctl dispatch exit ;; esac", accent: view.sys.colWarn },  // md-logout
        { icon: String.fromCodePoint(0xF0709), label: view.sys.tr("Перезагрузка"), cmd: "systemctl reboot",      accent: view.sys.tint("#fb923c") },  // md-restart
        { icon: String.fromCodePoint(0xF0425), label: view.sys.tr("Выключить"),    cmd: "systemctl poweroff",    accent: view.sys.colCrit }   // md-power
    ]

    function trigger(i) {
        if (i < 0 || i >= actions.length) return;
        if (!actions[i].instant && view.armed !== i) {
            view.armed = i;
            view.current = i;
            disarm.restart();
            return;
        }
        disarm.stop();
        // We launch it through the root of the shell, and not through our Process.
        //
        // setsid -f takes the command into its own session, but that's not enough:
        // the line below closes the panel, the page is destroyed, and along with
        // her and her Process - before the team has time to separate. Fast
        // a moment was enough, but there was no blocking: its script first prepares the background
        // from wallpaper. From the outside it looked like a broken button.
        view.sys.runDetached(actions[i].cmd);
        view.sys.collapse();
    }

    focus: true
    Keys.onEscapePressed: view.sys.collapse()
    Keys.onReturnPressed: trigger(current)
    Keys.onLeftPressed:  if (current > 0) { current--; armed = -1 }
    Keys.onRightPressed: if (current < actions.length - 1) { current++; armed = -1 }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: view.armed >= 0
                  ? view.sys.tr("Ещё раз, чтобы подтвердить: ") + view.actions[view.armed].label
                  : view.sys.tr("Завершение работы")
            color: view.armed >= 0 ? view.actions[view.armed].accent : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            Repeater {
                model: view.actions

                Rectangle {
                    required property int index
                    required property var modelData

                    readonly property bool isArmed: view.armed === index
                    readonly property bool isCurrent: view.current === index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    radius: 16

                    // the base is always neutral; confirmation paint top layer
                    color: btnMa.containsMouse || isCurrent
                           ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)

                    // separate layer for confirmation highlighting
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: modelData.accent
                        opacity: parent.isArmed ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    border.color: isArmed ? modelData.accent
                                : isCurrent ? Qt.rgba(1, 1, 1, 0.22)
                                            : view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: btnMa.pressed ? 0.94 : (btnMa.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        id: body
                        anchors.centerIn: parent
                        spacing: 9

                        // A bare icon without a circle underneath it. Circle with your
                        // fill, stroke and glow argued with the tiles, on
                        // which is worth: two nested selections of the same
                        // same actions. The cocking is shown by the tile itself.
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            readonly property color ink: modelData.accent

                            // The dream is drawn in letters, not in glyphs: the month has
                            // Nerd Font has no relation to the others - it's about the night, and
                            // not about a dream, and next to the lock and arrow it read
                            // like the weather. Three z's in a triangle speak directly.
                            Item {
                                anchors.fill: parent
                                visible: modelData.id === "sleep"

                                Text {
                                    x: 1; y: 15
                                    text: "Z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 19; bold: true }
                                }
                                Text {
                                    x: 17; y: 1
                                    text: "z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 10; bold: true }
                                }
                                Text {
                                    x: 24; y: 8
                                    text: "z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 14; bold: true }
                                }
                            }

                            Glyph {
                                anchors.fill: parent
                                visible: modelData.id !== "sleep"
                                glyph: modelData.icon
                                color: parent.ink
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize + 8
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: body.parent.isArmed ? view.sys.tr("Подтвердите") : modelData.label
                            color: body.parent.isArmed ? view.sys.colFg : view.sys.colMuted
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 4
                                bold: body.parent.isArmed
                            }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { view.current = index; view.forceActiveFocus() }
                        onClicked: view.trigger(index)
                    }
                }
            }
        }
    }
}
