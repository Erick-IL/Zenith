import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Agents: tariffs and loading limits of installed AI agents.
//
// The data comes from scripts/agents.sh - it decides who is installed and what
// it is known about him. The view knows nothing about the format of other people's configs and draws
// what they gave.
//
// The bars here are NOT sliders: they have neither a MouseArea nor a wheel handler.
// These are indicators, and there is nowhere to drag them - the limit is set by the tariff, not by the window.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property var  agents: []
    property real serverNow: 0
    property bool loaded: false

    // Countdown clock. Separate from script polling: before limit reset
    // there are hours, and to drive because of the signature “in 2 hours 14 minutes” is a whole process of times
    // in a second there is no need. A tick every 30 seconds - the signature in minutes will not become more accurate.
    property real clockNow: Date.now()
    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: view.clockNow = Date.now()
    }

    Process {
        id: pAgents
        command: ["sh", view.sys.scriptDir + "/agents.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    view.agents = d.agents || [];
                    view.serverNow = d.now || Date.now();
                } catch (e) {
                    view.agents = [];
                }
                view.loaded = true;
                view.clockNow = Date.now();
            }
        }
    }

    function refresh() { pAgents.running = false; pAgents.running = true; }

    // The poll is less frequent than it seems necessary: the file with the load itself is updated by the agent,
    // when running, not the shell. Asking more often means re-reading more often.
    // same thing.
    Timer {
        interval: 20000; repeat: true; running: true
        onTriggered: view.refresh()
    }

    // They opened the window and re-read it. Creating a view alone is not enough: until the page
    // reset to main, reopening reuses the same view, and
    // the numbers would remain the same as they arrived last time. Shell counter
    // It grows with every discovery, and that’s enough.
    Connections {
        target: view.sys
        function onAgentsEpochChanged() { view.refresh(); }
    }

    // Changing an account or fresh numbers means editing one file, and wait until
    // there is no need for the next tick: we re-read it immediately after it has changed.
    FileView {
        path: Quickshell.env("HOME") + "/.claude.json"
        watchChanges: true
        printErrors: false
        onFileChanged: view.refresh()
    }

    // ------------------------------------------------------------- signatures
    // The key comes stable (kind), we substitute the human name here:
    // otherwise, changing the interface language would not have reached this window.
    function limitLabel(kind) {
        switch (String(kind)) {
        case "session":       return view.sys.tr("5 часов");
        case "weekly_all":    return view.sys.tr("Неделя");
        case "weekly_opus":   return view.sys.tr("Opus, неделя");
        case "weekly_sonnet": return view.sys.tr("Sonnet, неделя");
        }
        return String(kind).replace(/_/g, " ");
    }

    // "in 2 hours 14 minutes." A window that should have been updated a long time ago
    // we say: the data is in the agent cache, and until it is launched, it hangs there
    // old. Lying to “0%” would be worse—it would look like fact.
    function untilText(ms) {
        if (!ms || ms <= 0) return "";
        var left = ms - view.clockNow;
        if (left <= 0) return view.sys.tr("окно уже обновилось");
        var mins = Math.floor(left / 60000);
        var h = Math.floor(mins / 60), m = mins % 60;
        var pre = view.sys.tr("обновится через") + " ";
        if (h >= 24) return pre + Math.floor(h / 24) + " " + view.sys.tr("д") + " " + (h % 24) + " " + view.sys.tr("ч");
        if (h > 0)   return pre + h + " " + view.sys.tr("ч") + " " + m + " " + view.sys.tr("мин");
        return pre + Math.max(1, m) + " " + view.sys.tr("мин");
    }

    function agoText(ms) {
        if (!ms || ms <= 0) return "";
        var mins = Math.floor((view.clockNow - ms) / 60000);
        if (mins < 1)  return view.sys.tr("только что");
        if (mins < 60) return mins + " " + view.sys.tr("мин назад");
        var h = Math.floor(mins / 60);
        if (h < 24) return h + " " + view.sys.tr("ч назад");
        return Math.floor(h / 24) + " " + view.sys.tr("д назад");
    }

    // Color by load, not by limit name: what matters is how much is left.
    function barColor(pct, severity) {
        if (String(severity) === "critical" || pct >= 90) return view.sys.colCrit;
        if (pct >= 70) return view.sys.colWarn;
        return view.sys.colOn;
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // -------------------------------------------------------- title
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                glyph: String.fromCodePoint(0xF1719)   // md-robot_outline
                color: view.sys.colFg
                fontFam: view.sys.fontFam
                size: 19
            }
            Text {
                text: view.sys.tr("Агенты")
                color: view.sys.colFg
                font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 1; bold: true }
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: view.loaded && view.agents.length > 0
                text: view.agents.length
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }
        }

        // ------------------------------------------------------- cards
        Repeater {
            model: view.agents

            Rectangle {
                id: card
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 26
                radius: 14
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.05)
                border.width: 1
                border.color: view.sys.colLine

                ColumnLayout {
                    id: body
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14; rightMargin: 14
                    }
                    spacing: 10

                    // agent name, version and tariff
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: card.modelData.name || ""
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                        }
                        Text {
                            visible: String(card.modelData.version || "").length > 0
                            text: card.modelData.version || ""
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                        }
                        Item { Layout.fillWidth: true }

                        // Tariff with a die: this is not a signature for something, but the fact itself,
                        // and they look for him with their eyes first.
                        Rectangle {
                            visible: String(card.modelData.plan || "").length > 0
                            implicitWidth: planText.implicitWidth + 18
                            implicitHeight: 22
                            radius: 11
                            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                            Text {
                                id: planText
                                anchors.centerIn: parent
                                text: card.modelData.plan || ""
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5; bold: true }
                            }
                        }
                    }

                    // ------------------------------------------- limits
                    Repeater {
                        model: card.modelData.limits || []

                        ColumnLayout {
                            id: lim
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: view.limitLabel(lim.modelData.kind)
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(lim.modelData.percent) + "%"
                                    color: view.barColor(lim.modelData.percent, lim.modelData.severity)
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                                }
                            }

                            // Stripe. Neither MouseArea nor WheelHandler: shows
                            // but does not allow himself to be pulled.
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 7
                                radius: 4
                                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10)

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * Math.max(0, Math.min(100, lim.modelData.percent)) / 100
                                    color: view.barColor(lim.modelData.percent, lim.modelData.severity)
                                    Behavior on width  { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
                                    Behavior on color  { ColorAnimation  { duration: view.sys.animFade } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: view.untilText(lim.modelData.resetsAt)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                            }
                        }
                    }

                    // There are no limits - we’ll tell you exactly why. "Their agent is not
                    // is giving" and "data has not arrived yet" look the same, but
                    // mean the opposite: the first is forever, the second will pass
                    // itself. After changing the account, just the second one is visible, and
                    // to report “does not give back” would be an outright lie.
                    //
                    // An empty line at zero is good for neither
                    // case: it reads “nothing was spent”, and we
                    // we just don't know.
                    Text {
                        Layout.fillWidth: true
                        visible: (card.modelData.limits || []).length === 0
                        // For Claude the hint is specific. He writes down
                        // load into your file only when you go get it yourself
                        // to the server, but does it rarely and in his own way
                        // schedule: after changing the account the key may not be available
                        // for hours, and restarting doesn't change anything. Team
                        // /usage follows it forcibly - this is the way
                        // get the numbers now rather than wait.
                        text: String(card.modelData.note) !== "nodata"
                              ? view.sys.tr("Лимиты этот агент наружу не отдаёт")
                              : String(card.modelData.id) === "claude"
                              ? view.sys.tr("Данных пока нет — выполните /usage в Claude Code")
                              : view.sys.tr("Данных пока нет — появятся, когда агент поработает")
                        color: view.sys.colMuted
                        wrapMode: Text.WordWrap
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                    }

                    // When was the last time the numbers were updated by the agent itself. Important:
                    // the island doesn't ask for them, it reads what the agent left
                    // at home - and without this line the freshness would look
                    // today's always.
                    Text {
                        Layout.fillWidth: true
                        visible: (card.modelData.limits || []).length > 0
                                 && String(view.agoText(card.modelData.fetchedAt)).length > 0
                        text: view.sys.tr("данные агента от") + " " + view.agoText(card.modelData.fetchedAt)
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                    }
                }
            }
        }

        // ---------------------------------------------------------- empty
        Text {
            Layout.fillWidth: true
            visible: view.loaded && view.agents.length === 0
            text: view.sys.tr("Ни одного агента не найдено")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }
    }
}
