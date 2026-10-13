import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FocusScope {
    id: view
    property var sys

    width: parent ? parent.width : ((view.sys && view.sys.panelW) ? view.sys.panelW - 30 : 420)
    implicitHeight: col.implicitHeight

    property var sysinfo: ({
        cpu_pct: 0,
        cores: 1,
        mem_total: 0,
        mem_used: 0,
        mem_pct: 0,
        swap_total: 0,
        swap_used: 0,
        swap_pct: 0
    })

    ListModel { id: procsModel }
    property string query: ""
    property string sortBy: "cpu" // "cpu" | "mem" | "name" | "pid"
    property int selectedIndex: -1
    property var selectedProc: selectedIndex >= 0 && selectedIndex < procsModel.count ? procsModel.get(selectedIndex) : null

    function humanBytes(b) {
        if (!b || b <= 0) return "0 MB";
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var val = b;
        while (val >= 1024 && i < u.length - 1) { val /= 1024; i++; }
        return (val >= 100 || i < 2 ? Math.round(val) : val.toFixed(1)) + " " + u[i];
    }

    Process {
        id: pTaskData
        command: ["python3", view.sys.scriptDir + "/taskmgr.py", "all", view.sortBy, "100", view.query]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    if (d.sysinfo) view.sysinfo = d.sysinfo;
                    var list = d.processes || [];
                    
                    var oldPid = view.selectedProc ? view.selectedProc.pid : -1;
                    procsModel.clear();
                    var newIdx = -1;
                    for (var i = 0; i < list.length; i++) {
                        procsModel.append(list[i]);
                        if (list[i].pid === oldPid) newIdx = i;
                    }
                    if (newIdx >= 0) view.selectedIndex = newIdx;
                    else if (view.selectedIndex >= procsModel.count) view.selectedIndex = procsModel.count - 1;
                } catch (e) {
                }
            }
        }
    }

    Process { id: pAction }

    function refresh() {
        if (!pTaskData.running) {
            pTaskData.command = ["python3", view.sys.scriptDir + "/taskmgr.py", "all", view.sortBy, "100", view.query];
            pTaskData.running = true;
        }
    }

    function doKill(pid, force) {
        pAction.command = ["python3", view.sys.scriptDir + "/taskmgr.py", force ? "kill9" : "kill", String(pid)];
        pAction.running = true;
        refreshTimer.restart();
        view.refresh();
    }

    function doTogglePause(pid, isPaused) {
        pAction.command = ["python3", view.sys.scriptDir + "/taskmgr.py", isPaused ? "cont" : "stop", String(pid)];
        pAction.running = true;
        view.refresh();
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: view.refresh()
    }

    Component.onCompleted: {
        view.refresh();
        input.forceActiveFocus();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // -------------------------------------------------------- Hat

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Glyph {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                glyph: String.fromCodePoint(0xF0748) // monitor / pulse
                color: view.sys.colOn
                fontFam: view.sys.fontFam
                size: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: (view.sys && view.sys.isPt) ? "Gerenciador de Tarefas" : "Task Manager"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 3; bold: true }
                }
                Text {
                    text: procsModel.count + ((view.sys && view.sys.isPt) ? " processos listados" : " processes listed")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            Item { Layout.fillWidth: true }

            // Close button
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: 6
                color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 14; bold: true }
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.collapse()
                }
            }
        }

        // -------------------------------------------------------- Cartoes de Recursos

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // CPU Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CPU"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.sysinfo.cpu_pct + "%"
                            color: view.sysinfo.cpu_pct > 80 ? view.sys.colCrit : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            width: parent.width * Math.min(1.0, view.sysinfo.cpu_pct / 100.0)
                            height: parent.height
                            radius: 2
                            color: view.sysinfo.cpu_pct > 80 ? view.sys.colCrit : view.sys.colOn
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text {
                        text: view.sysinfo.cores + ((view.sys && view.sys.isPt) ? " núcleos" : " cores")
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }
                }
            }

            // RAM Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "RAM"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.sysinfo.mem_pct + "%"
                            color: view.sysinfo.mem_pct > 85 ? view.sys.colCrit : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            width: parent.width * Math.min(1.0, view.sysinfo.mem_pct / 100.0)
                            height: parent.height
                            radius: 2
                            color: view.sysinfo.mem_pct > 85 ? view.sys.colCrit : view.sys.colOn
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text {
                        text: view.humanBytes(view.sysinfo.mem_used) + " / " + view.humanBytes(view.sysinfo.mem_total)
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }
                }
            }

            // Swap Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "SWAP"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.sysinfo.swap_pct + "%"
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            width: parent.width * Math.min(1.0, view.sysinfo.swap_pct / 100.0)
                            height: parent.height
                            radius: 2
                            color: view.sys.colOn
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text {
                        text: view.humanBytes(view.sysinfo.swap_used) + " / " + view.humanBytes(view.sysinfo.swap_total)
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }
                }
            }
        }

        // -------------------------------------------------------- Search and Sort Bar


        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Search field

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: input.activeFocus ? view.sys.colOn : view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    Text {
                        text: String.fromCodePoint(0xF0349) // magnify
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                    TextField {
                        id: input
                        focus: true
                        Layout.fillWidth: true
                        placeholderText: (view.sys && view.sys.isPt) ? "Filtrar por nome, PID, comando…" : "Filter by name, PID, command…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.25)
                        color: view.sys.colFg
                        background: null
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                        onTextChanged: {
                            view.query = text;
                            filterTimer.restart();
                        }
                    }
                }
            }

            Timer {
                id: filterTimer
                interval: 250
                onTriggered: view.refresh()
            }

            // Ordering


            RowLayout {
                spacing: 3
                component SortCapsule: Rectangle {
                    property string key: ""
                    property string label: ""
                    readonly property bool isCur: view.sortBy === key

                    Layout.preferredHeight: 30
                    Layout.preferredWidth: sortLabel.implicitWidth + 14
                    radius: 8
                    color: isCur ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                 : (scMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    border.color: isCur ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    Text {
                        id: sortLabel
                        anchors.centerIn: parent
                        text: parent.label
                        color: parent.isCur ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 11; bold: parent.isCur }
                    }
                    MouseArea {
                        id: scMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.sortBy = parent.key;
                            view.refresh();
                        }
                    }
                }

                SortCapsule { key: "cpu"; label: "CPU" }
                SortCapsule { key: "mem"; label: "RAM" }
                SortCapsule { key: "pid"; label: "PID" }
                SortCapsule { key: "name"; label: (view.sys && view.sys.isPt) ? "Nome" : "Name" }
            }
        }

        // -------------------------------------------------------- Table Header


        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            color: Qt.rgba(1, 1, 1, 0.03)
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: (view.sys && view.sys.isPt) ? "PROCESSO" : "PROCESS"
                    Layout.fillWidth: true
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                }
                Text {
                    text: "PID"
                    Layout.preferredWidth: 46
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                }
                Text {
                    text: "CPU"
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignRight
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                }
                Text {
                    text: "RAM"
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                }
                Text {
                    text: (view.sys && view.sys.isPt) ? "USUÁRIO" : "USER"
                    Layout.preferredWidth: 70
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                }
            }
        }

        // -------------------------------------------------------- Lista de Processos
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            clip: true

            ListView {
                id: procList
                anchors.fill: parent
                anchors.margins: 4
                model: procsModel
                spacing: 2
                clip: true
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                delegate: Rectangle {
                    id: row
                    required property var model
                    required property int index
                    readonly property bool isSel: row.index === view.selectedIndex

                    width: procList.width
                    height: 28
                    radius: 6
                    color: isSel ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                 : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Nome
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Glyph {
                                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                glyph: String.fromCodePoint(row.model.kernel ? 0xF017E : 0xF0079) // cog vs app
                                color: row.isSel ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.4)
                                fontFam: view.sys.fontFam
                                size: 12
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.model.name
                                color: row.isSel ? view.sys.colFg : Qt.rgba(1, 1, 1, 0.85)
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: row.isSel }
                            }
                        }

                        // PID
                        Text {
                            Layout.preferredWidth: 46
                            text: String(row.model.pid)
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        // CPU %
                        Text {
                            Layout.preferredWidth: 48
                            text: row.model.cpu.toFixed(1) + "%"
                            horizontalAlignment: Text.AlignRight
                            color: row.model.cpu > 50 ? view.sys.colCrit
                                                      : (row.model.cpu > 10 ? view.sys.colOn : view.sys.colFg)
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: row.model.cpu > 10 }
                        }

                        // RAM
                        Text {
                            Layout.preferredWidth: 64
                            text: view.humanBytes(row.model.rss)
                            horizontalAlignment: Text.AlignRight
                            color: Qt.rgba(1, 1, 1, 0.75)
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        // User
                        Text {
                            Layout.preferredWidth: 70
                            text: row.model.user
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.selectedIndex = row.index
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: procsModel.count === 0
                    text: (view.sys && view.sys.isPt) ? "Nenhum processo encontrado" : "No processes found"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }
            }
        }

        // -------------------------------------------------------- Process Actions Bar


        Rectangle {
            visible: view.selectedProc !== null
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: view.sys.colLine
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: view.selectedProc ? (view.selectedProc.name + " (PID " + view.selectedProc.pid + ")") : ""
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.selectedProc ? view.selectedProc.cmd : ""
                        color: view.sys.colMuted
                        elide: Text.ElideMiddle
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                }

                // Finalizar (SIGTERM)
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: killTxt.implicitWidth + 20
                    radius: 8
                    color: killMa.containsMouse ? view.sys.colCrit : Qt.rgba(1, 0.2, 0.2, 0.2)
                    border.color: view.sys.colCrit
                    border.width: 1

                    Text {
                        id: killTxt
                        anchors.centerIn: parent
                        text: (view.sys && view.sys.isPt) ? "Finalizar Tarefa" : "End Task"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                    }

                    MouseArea {
                        id: killMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.selectedProc) view.doKill(view.selectedProc.pid, false);
                        }
                    }
                }

                // Force Quit (SIGKILL)


                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: fkillTxt.implicitWidth + 14
                    radius: 8
                    color: fkillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Text {
                        id: fkillTxt
                        anchors.centerIn: parent
                        text: (view.sys && view.sys.isPt) ? "Forçar" : "Force Kill"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }

                    MouseArea {
                        id: fkillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.selectedProc) view.doKill(view.selectedProc.pid, true);
                        }
                    }
                }
            }
        }
    }
}
