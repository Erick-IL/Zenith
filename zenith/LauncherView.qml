import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Application launcher: search, icons, arrow navigation, Enter - launch.
// Lives inside the same pill, so it opens with the same animation.
//
// The root is FocusScope, not Item: the panel gives focus to the loaded view
// entirely, and a regular Item would take it FOR ITSELF, leaving the input field dead.
// The focus area will redirect it to the child who has focus: true.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property string query: ""
    property int index: 0
    readonly property int maxRows: 6

    // Recently Launched: List of IDs that are fresh at the beginning.
    // Stored in ~/.cache/zenith/recent-apps, so it survives restarts.
    property var recent: []
    readonly property string recentFile:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/zenith/recent-apps"

    Process {
        id: pRecentRead
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", view.recentFile]
        running: true
        stdout: StdioCollector {
            onStreamFinished: view.recent = text.trim().split("\n").filter(x => x.length)
        }
    }
    Process { id: pRecentWrite }

    function rememberApp(app) {
        var id = String(app.id || app.name || "");
        if (!id.length) return;
        var list = view.recent.filter(x => x !== id);
        list.unshift(id);
        if (list.length > 20) list = list.slice(0, 20);
        view.recent = list;
        pRecentWrite.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s' \"$2\" > \"$1\"",
            "_", view.recentFile, list.join("\n")];
        pRecentWrite.running = true;
    }

    function recentRank(app) {
        var i = view.recent.indexOf(String(app.id || app.name || ""));
        return i < 0 ? 999 : i;
    }

    // Your own launcher lines: not applications from the system, but island pages.
    // They live in the general list and are searched along with everything else - otherwise about them
    // I would have to remember separately.
    //
    // keys - what the line is located by, in addition to the name: both in Russian and
    // in English, and by the names of the agents themselves, so that “claude” also leads
    // here.
    readonly property var builtins: [{
        builtin: "agents",
        // The key for the recent list is specified explicitly and in English: it is also the name of the string
        // in the file, and the name is translated. Through the interface language “Agents” and “Agents”
        // would become two different records, and the recent one would be lost when switching.
        id: "zenith:agents",
        glyph: String.fromCodePoint(0xF1719),      // md-robot_outline
        name: view.sys.tr("Агенты"),
        genericName: view.sys.tr("Тарифы и лимиты установленных ИИ-агентов"),
        keys: "agents agent ai claude codex gemini copilot cursor limits usage plan "
              + "агенты агент лимиты тариф подписка нагрузка"
    }]

    // ------------------------------------------------- other systems on disk
    // They appear in the list only if they are actually present on the machine:
    // bootos.sh looks for them itself, and an empty response means an empty list. By car
    // with one system there will not be a single such line in the launcher - not a gray one,
    // neither disabled, nor any.
    //
    // The list is not fixed by two points: how many systems are found, so many
    // lines and will appear.
    property var systems: []

    Process {
        id: pSystems
        command: ["sh", view.sys.scriptDir + "/bootos.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length < 3) continue;
                    out.push({
                        builtin: "bootos",
                        bootId: p[0],
                        // Recent people remember the system by its identifier in
                        // bootloader, not by name: the name comes from
                        // os-prober and changes with it.
                        id: "zenith:bootos:" + p[0],
                        glyph: view.osGlyph(p[2]),
                        name: p[1],
                        genericName: view.sys.tr("Перезагрузиться в эту систему"),
                        keys: "reboot restart boot " + p[1].toLowerCase() + " " + p[2]
                              + " перезагрузка загрузиться система"
                    });
                }
                view.systems = out;
            }
        }
    }

    function osGlyph(kind) {
        switch (String(kind)) {
        case "windows": return String.fromCodePoint(0xF05B3);   // md-microsoft_windows
        case "linux":   return String.fromCodePoint(0xF033D);   // md-linux
        case "mac":     return String.fromCodePoint(0xF0035);   // md-apple
        }
        return String.fromCodePoint(0xF02CA);                   // md-harddisk
    }

    function bootInto(app) {
        // The launch itself lives in the root of the shell, not here. Launcher closes
        // next line, and everything declared in it is destroyed along with
        // appearance - pkexec did not even have time to show the window with the password.
        //
        // The password here is also a confirmation: the reboot is irreversible, and
        // a separate “are you sure?” should not be on the way to it - man
        // asked to reboot rather than talk about it.
        sys.bootIntoSystem(app.bootId);
        sys.closeLauncher();
    }

    // Everything that the launcher shows besides applications.
    readonly property var extras: view.builtins.concat(view.systems)

    function builtinMatches(b, q) {
        if (q.length === 0) return false;   // with an empty request list - applications
        if (String(b.name).toLowerCase().indexOf(q) >= 0) return true;
        return String(b.keys).toLowerCase().indexOf(q) >= 0;
    }

    // Selection and sorting: first matches from the beginning of the name, then the rest.
    readonly property var results: {
        var q = query.trim().toLowerCase();
        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var starts = [], contains = [];
        // We keep our lines in a separate list, and not in starts: the one at the end
        // sorted alphabetically, and “Agents” would go to the middle of the issue.
        // They are asked by name, with aim, so they have first place.
        var pinned = [];
        for (var b = 0; b < view.extras.length; b++) {
            var bi = view.extras[b];
            // With an empty request, its own line goes to the general list and is placed according to
            // as old as applications: they opened it last - she and
            // first. With a request, she always gets first place.
            //
            // Except for systems: they are not on the “everything” list at all. There's their line
            // would stand close to the browser, and a miss on Enter would lead to
            // reboot. The system is called intentionally by typing its name.
            if (q.length === 0) { if (bi.builtin !== "bootos") starts.push(bi); }
            else if (view.builtinMatches(bi, q)) pinned.push(bi);
        }
        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a || a.noDisplay) continue;
            var n = String(a.name || "").toLowerCase();
            if (q.length === 0) { starts.push(a); continue; }
            var pos = n.indexOf(q);
            if (pos === 0) starts.push(a);
            else if (pos > 0) contains.push(a);
            else if (String(a.genericName || "").toLowerCase().indexOf(q) >= 0) contains.push(a);
        }
        var byName = function (x, y) {
            return String(x.name || "").localeCompare(String(y.name || ""));
        };
        // Empty request - on top is what was launched recently: the cursor right away
        // It's on the last opened application.
        if (q.length === 0) {
            starts.sort(function (x, y) {
                var d = view.recentRank(x) - view.recentRank(y);
                return d !== 0 ? d : byName(x, y);
            });
            return starts;
        }
        starts.sort(byName); contains.sort(byName);
        return pinned.concat(starts, contains);
    }

    // ------------------------------------------------------------ calculator
    // If the line contains only numbers and signs, we count and display the answer first.
    // Enter copies the result. Strictly safe character set allowed
    // so that nothing extraneous gets into the calculation.
    readonly property bool isMath: {
        var q = query.trim();
        if (q.length < 3) return false;
        if (!/[+\-*/^%]/.test(q)) return false;         // there must be at least one sign
        return /^[0-9\s+\-*/().,%^]+$/.test(q);
    }

    readonly property string mathResult: {
        if (!isMath) return "";
        try {
            var e = query.trim().replace(/,/g, ".").replace(/\^/g, "**");
            var r = Function('"use strict"; return (' + e + ')')();
            if (typeof r !== "number" || !isFinite(r)) return "";
            // remove the tail due to the floating point: 0.1+0.2 -> 0.3
            return String(parseFloat(r.toFixed(10)));
        } catch (err) {
            return "";
        }
    }

    Process { id: pCopyCalc }
    function copyResult() {
        if (mathResult.length === 0) return;
        pCopyCalc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", mathResult];
        pCopyCalc.running = true;
        sys.closeLauncher();
    }

    onQueryChanged: index = 0
    onResultsChanged: if (index >= results.length) index = Math.max(0, results.length - 1)

    function launch() {
        if (view.mathResult.length > 0) { copyResult(); return; }
        var app = results[index];
        if (!app) return;
        // We don’t run our line as a program - it opens the page
        // islands. But it gets into the recent ones on a par with applications: it was opened
        // from the same list and with the same Enter, and next time she should
        // wait from above, and not in your place according to the alphabet.
        if (app.builtin === "agents") { rememberApp(app); sys.openAgents(); return; }
        // We DO NOT record the system as recent. Recent is “what I use”
        // and rebooting to another system happens once a week and after that
        // would hang first line in an empty launcher until the end of time. Moreover
        // the first line, which is easiest to hit with a random Enter.
        if (app.builtin === "bootos") { bootInto(app); return; }
        rememberApp(app);
        app.execute();
        sys.closeLauncher();
    }
    function move(delta) {
        if (results.length === 0) return;
        index = Math.max(0, Math.min(results.length - 1, index + delta));
        list.positionViewAtIndex(index, ListView.Contain);
    }

    // focus immediately, plus several repetitions: layer gets keyboard
    // a frame or two later than the creation of the component
    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------ search
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 9

                Text {
                    text: ""
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }
                TextField {
                    id: input
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.tr("Поиск приложений…")
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                    background: null
                    onTextChanged: view.query = text

                    Keys.onDownPressed:   view.move(1)
                    Keys.onUpPressed:     view.move(-1)
                    Keys.onReturnPressed: view.launch()
                    Keys.onEnterPressed:  view.launch()
                    Keys.onEscapePressed: view.sys.closeLauncher()
                    Keys.onTabPressed:    view.move(1)
                }
                Text {
                    visible: view.results.length > 0
                    text: view.results.length
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // ------------------------------------------------------------ list
        // the result of the calculation is the first line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: view.mathResult.length > 0
            radius: 12
            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.14)
            border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Glyph {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    glyph: String.fromCodePoint(0xF00EC)
                    color: view.sys.colOn
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                Text {
                    Layout.fillWidth: true
                    text: view.mathResult
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 3; bold: true }
                }
                Text {
                    text: "Enter"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.copyResult()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            visible: view.mathResult.length === 0
            Layout.preferredHeight: view.mathResult.length > 0 ? 0
                                  : Math.min(view.results.length, view.maxRows) * 46
            // The height is animated by the capsule. Here we started our own animation from scratch
            // and was superimposed on it: the panel first stretched, then
            // “completed development” - those same two stages.
            clip: true
            model: view.results
            currentIndex: view.index
            boundsBehavior: Flickable.OvershootBounds
            flickDeceleration: 2200
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: 44
                radius: 12
                color: index === view.index ? Qt.rgba(1, 1, 1, 0.11)
                     : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 11

                    // application icon from the system theme
                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: row.modelData.icon
                                    ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 52
                            sourceSize.height: 52
                            visible: status === Image.Ready
                        }
                        // spare icon if the icon is not in the theme
                        Rectangle {
                            anchors.fill: parent
                            visible: !appIcon.visible
                            radius: 7
                            color: Qt.rgba(1, 1, 1, 0.10)
                            // your lines do not have icons in the theme and cannot have them -
                            // we draw a glyph, but only applications use the letter
                            Glyph {
                                anchors.centerIn: parent
                                visible: String(row.modelData.glyph || "").length > 0
                                glyph: row.modelData.glyph || ""
                                color: view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: 15
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: String(row.modelData.glyph || "").length === 0
                                text: String(row.modelData.name || "?").charAt(0).toUpperCase()
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name || ""
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: 13
                                bold: row.index === view.index
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData.genericName || ""
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }

                    Text {
                        visible: row.index === view.index
                        text: "󰌑"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.index = row.index
                    onClicked: view.launch()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.results.length === 0 && view.mathResult.length === 0
            text: view.sys.tr("Ничего не найдено")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: 11 }
        }
    }
}
