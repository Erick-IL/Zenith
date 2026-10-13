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

    ListModel { id: tasksModel }
    ListModel { id: scriptsModel }

    property var detailTask: null
    property string logsText: ""
    property bool addingTask: false
    property bool showScriptPicker: false

    Process {
        id: pListTasks
        command: ["python3", view.sys.scriptDir + "/terminals.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text);
                    var oldDetailId = view.detailTask ? view.detailTask.id : "";
                    tasksModel.clear();
                    var foundDetail = null;
                    for (var i = 0; i < list.length; i++) {
                        tasksModel.append(list[i]);
                        if (list[i].id === oldDetailId) {
                            foundDetail = list[i];
                        }
                    }
                    if (foundDetail) {
                        view.detailTask = foundDetail;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pLogs
        stdout: StdioCollector {
            onStreamFinished: view.logsText = text
        }
    }

    Process {
        id: pAction
        onExited: (code, status) => {
            view.refresh();
            view.refreshLogs();
        }
    }

    Process {
        id: pScanScripts
        command: ["python3", view.sys.scriptDir + "/terminals.py", "scan_scripts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text);
                    scriptsModel.clear();
                    for (var i = 0; i < list.length; i++) {
                        scriptsModel.append(list[i]);
                    }
                } catch (e) {}
            }
        }
    }

    function runAction(args) {
        pAction.running = false;
        pAction.command = args;
        pAction.running = true;
    }

    function refresh() {
        if (!pListTasks.running) {
            pListTasks.command = ["python3", view.sys.scriptDir + "/terminals.py", "list"];
            pListTasks.running = true;
        }
    }

    function refreshLogs() {
        if (view.detailTask && view.detailTask.id) {
            pLogs.command = ["python3", view.sys.scriptDir + "/terminals.py", "logs", view.detailTask.id, "150"];
            pLogs.running = false;
            pLogs.running = true;
        } else {
            view.logsText = "";
        }
    }

    function scanScripts() {
        pScanScripts.running = false;
        pScanScripts.running = true;
    }

    function doStart(id) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "start", id]);
    }

    function doStop(id) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "stop", id]);
    }

    function doRestart(id) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "restart", id]);
    }

    function doDelete(id) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "delete", id]);
        if (view.detailTask && view.detailTask.id === id) {
            view.detailTask = null;
        }
    }

    function doClearLogs(id) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "clear_logs", id]);
        view.logsText = "";
    }

    function doAddTask(name, dir, cmd, port) {
        runAction(["python3", view.sys.scriptDir + "/terminals.py", "add",
                   name || "Task", dir || "~", cmd || "", port || "", "false", "false"]);
        view.addingTask = false;
    }

    function goBack() {
        if (view.addingTask) {
            view.addingTask = false;
            view.showScriptPicker = false;
            return true;
        }
        if (view.detailTask !== null) {
            view.detailTask = null;
            return true;
        }
        return false;
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            view.refresh();
            if (view.detailTask) view.refreshLogs();
        }
    }

    Component.onCompleted: {
        view.refresh();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ====================================================================
        // SCREEN 1: MAIN LIST OF SERVICES (No terminal at the bottom)


        // ====================================================================
        ColumnLayout {
            id: mainServicesView
            visible: !view.addingTask && view.detailTask === null
            Layout.fillWidth: true
            spacing: 12

            // Header (BACKGROUND Title + Refresh Button + Close Button)


            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Glyph {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    glyph: String.fromCodePoint(0xF018D) // console / terminal
                    color: view.sys.colOn
                    fontFam: view.sys.fontFam
                    size: 22
                }

                Text {
                    text: "BACKGROUND"
                    color: "#ffffff"
                    font {
                        family: view.sys.fontFam
                        pixelSize: view.sys.fontSize + 4
                        bold: true
                        letterSpacing: 1.5
                    }
                }

                Item { Layout.fillWidth: true }

                // Update Button


                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: 8
                    color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }

                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.refresh();
                        }
                    }
                }

                // Close button


                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: 8
                    color: clsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                    }

                    MouseArea {
                        id: clsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.collapse()
                    }
                }
            }

            // Description persistence via systemd


            Text {
                Layout.fillWidth: true
                text: "Persistent via systemd - Terminal is only a window into the process"
                color: Qt.rgba(1, 1, 1, 0.65)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                wrapMode: Text.WordWrap
            }

            // + NEW SERVICE button


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: newSvcMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.12)
                border.color: view.sys.colOn
                border.width: 1.5
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "+"
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 16; bold: true }
                    }
                    Text {
                        text: "NEW SERVICE"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 12; bold: true; letterSpacing: 1.0 }
                    }
                }

                MouseArea {
                    id: newSvcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.addingTask = true;
                        view.showScriptPicker = false;
                    }
                }
            }

            // List of Active Service Cards


            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: tasksModel

                    delegate: Rectangle {
                        id: cardItem
                        required property var model
                        required property int index
                        readonly property bool isRunning: cardItem.model.status === "running"

                        Layout.fillWidth: true
                        Layout.preferredHeight: cardCol.implicitHeight + 18
                        radius: 12
                        color: cardBodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 130 } }

                        // Click on the card to open the details screen

                        MouseArea {
                            id: cardBodyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                view.detailTask = cardItem.model;
                                view.refreshLogs();
                            }
                        }

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            // Top Row: Name + Status Badge + Spacer + Action Buttons


                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: cardItem.model.name
                                    color: "#ffffff"
                                    font { family: "monospace"; pixelSize: 13; bold: true; letterSpacing: 0.5 }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: badgeTxt.implicitWidth + 12
                                    radius: 5
                                    color: cardItem.isRunning ? Qt.rgba(0.06, 0.72, 0.51, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: cardItem.isRunning ? "#10b981" : Qt.rgba(1, 1, 1, 0.25)
                                    border.width: 1

                                    Text {
                                        id: badgeTxt
                                        anchors.centerIn: parent
                                        text: cardItem.isRunning ? "RUNNING" : "STOPPED"
                                        color: cardItem.isRunning ? "#10b981" : "#94a3b8"
                                        font { family: view.sys.fontFam; pixelSize: 9; bold: true; letterSpacing: 0.8 }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Action Buttons with z: 10 to not collide with the card's MouseArea


                                RowLayout {
                                    z: 10
                                    spacing: 6

                                    // Play / Stop
                                    Rectangle {
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                        radius: 6
                                        color: actMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                        border.color: cardItem.isRunning ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Qt.rgba(0.06, 0.72, 0.51, 0.5)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: cardItem.isRunning ? "󰓛" : "󰐊"
                                            color: cardItem.isRunning ? "#ef4444" : "#10b981"
                                            font { family: view.sys.fontFam; pixelSize: 13 }
                                        }

                                        MouseArea {
                                            id: actMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (cardItem.isRunning) view.doStop(cardItem.model.id);
                                                else view.doStart(cardItem.model.id);
                                            }
                                        }
                                    }

                                    // Restart
                                    Rectangle {
                                        visible: cardItem.isRunning
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                        radius: 6
                                        color: rstMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                        border.color: Qt.rgba(1, 1, 1, 0.15)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰑐"
                                            color: "#cbd5e1"
                                            font { family: view.sys.fontFam; pixelSize: 12 }
                                        }

                                        MouseArea {
                                            id: rstMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.doRestart(cardItem.model.id)
                                        }
                                    }

                                    // Delete
                                    Rectangle {
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                        radius: 6
                                        color: delMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: delMa.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰆴"
                                            color: delMa.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.6)
                                            font { family: view.sys.fontFam; pixelSize: 13 }
                                        }

                                        MouseArea {
                                            id: delMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.doDelete(cardItem.model.id)
                                        }
                                    }
                                }
                            }

                            // Box with the executed command (Muted slate styling)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: cmdTxt.implicitHeight + 8
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1

                                Text {
                                    id: cmdTxt
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    anchors.topMargin: 4; anchors.bottomMargin: 4
                                    text: cardItem.model.cmd
                                    color: "#cbd5e1"
                                    font { family: "monospace"; pixelSize: 11 }
                                    elide: Text.ElideRight
                                }
                            }

                            // Last output line (> smoke)


                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: ">"
                                    color: "#64748b"
                                    font { family: "monospace"; pixelSize: 11; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (cardItem.model.last_line && cardItem.model.last_line.length > 0)
                                          ? cardItem.model.last_line
                                          : (cardItem.isRunning ? "waiting for output..." : "stopped")
                                    color: "#94a3b8"
                                    font { family: "monospace"; pixelSize: 11 }
                                    elide: Text.ElideRight
                                }
                            }

                            // Metadados (PID · UP · PORT · MEM)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "PID " + cardItem.model.pid
                                    color: "#94a3b8"
                                    font { family: "monospace"; pixelSize: 10 }
                                }

                                Text {
                                    text: "•"
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    font { pixelSize: 10 }
                                }

                                Text {
                                    text: cardItem.model.uptime_str || ("UP " + cardItem.model.uptime + "s")
                                    color: cardItem.isRunning ? "#34d399" : "#94a3b8"
                                    font { family: "monospace"; pixelSize: 10; bold: cardItem.isRunning }
                                }

                                Text {
                                    visible: cardItem.model.port && cardItem.model.port.length > 0
                                    text: "•"
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    font { pixelSize: 10 }
                                }

                                Text {
                                    visible: cardItem.model.port && cardItem.model.port.length > 0
                                    text: "PORT " + cardItem.model.port
                                    color: "#60a5fa"
                                    font { family: "monospace"; pixelSize: 10 }
                                }

                                Text {
                                    visible: cardItem.model.mem_mb > 0
                                    text: "•  " + cardItem.model.mem_mb + " MB"
                                    color: "#94a3b8"
                                    font { family: "monospace"; pixelSize: 10 }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Detalhes 󰅂"
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: tasksModel.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    text: "Nenhum serviço ativo. Clique em '+ NEW SERVICE' acima."
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font { family: view.sys.fontFam; pixelSize: 12 }
                }
            }
        }

        // ====================================================================
        // SCREEN 2: SERVICE DETAILS AND REAL-TIME LOGS CONSOLE


        // ====================================================================
        ColumnLayout {
            id: detailTaskView
            visible: view.detailTask !== null && !view.addingTask
            Layout.fillWidth: true
            spacing: 12

            // Details header (< Back | NAME | STATUS | Actions | Close)


            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 8
                    color: dtBackMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 16; bold: true }
                    }

                    MouseArea {
                        id: dtBackMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.detailTask = null
                    }
                }

                Text {
                    text: view.detailTask ? view.detailTask.name : "SERVICE"
                    color: "#ffffff"
                    font {
                        family: "monospace"
                        pixelSize: view.sys.fontSize + 3
                        bold: true
                        letterSpacing: 0.8
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: dtBadgeTxt.implicitWidth + 12
                    radius: 5
                    color: (view.detailTask && view.detailTask.status === "running") ? Qt.rgba(0.06, 0.72, 0.51, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: (view.detailTask && view.detailTask.status === "running") ? "#10b981" : Qt.rgba(1, 1, 1, 0.25)
                    border.width: 1

                    Text {
                        id: dtBadgeTxt
                        anchors.centerIn: parent
                        text: (view.detailTask && view.detailTask.status === "running") ? "RUNNING" : "STOPPED"
                        color: (view.detailTask && view.detailTask.status === "running") ? "#10b981" : "#94a3b8"
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true; letterSpacing: 0.8 }
                    }
                }

                Item { Layout.fillWidth: true }

                // Details body actions


                RowLayout {
                    spacing: 6

                    // Start / Stop
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        radius: 8
                        color: dtActMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: (view.detailTask && view.detailTask.status === "running") ? Qt.rgba(0.9, 0.2, 0.2, 0.5) : Qt.rgba(0.06, 0.72, 0.51, 0.5)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: (view.detailTask && view.detailTask.status === "running") ? "󰓛" : "󰐊"
                            color: (view.detailTask && view.detailTask.status === "running") ? "#ef4444" : "#10b981"
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }

                        MouseArea {
                            id: dtActMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.detailTask) {
                                    if (view.detailTask.status === "running") view.doStop(view.detailTask.id);
                                    else view.doStart(view.detailTask.id);
                                }
                            }
                        }
                    }

                    // Restart
                    Rectangle {
                        visible: view.detailTask && view.detailTask.status === "running"
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        radius: 8
                        color: dtRstMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: "#cbd5e1"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }

                        MouseArea {
                            id: dtRstMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (view.detailTask) view.doRestart(view.detailTask.id)
                        }
                    }

                    // Delete
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        radius: 8
                        color: dtDelMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: dtDelMa.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            color: dtDelMa.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.6)
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }

                        MouseArea {
                            id: dtDelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (view.detailTask) view.doDelete(view.detailTask.id)
                        }
                    }

                    // Close Panel

                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        radius: 8
                        color: dtClsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                        }

                        MouseArea {
                            id: dtClsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.collapse()
                        }
                    }
                }
            }

            // Service Metadata Card


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dtInfoCol.implicitHeight + 16
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.09)
                border.width: 1

                ColumnLayout {
                    id: dtInfoCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "CMD:"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font { family: "monospace"; pixelSize: 10; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.detailTask ? view.detailTask.cmd : ""
                            color: "#cbd5e1"
                            font { family: "monospace"; pixelSize: 11 }
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "DIR:"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font { family: "monospace"; pixelSize: 10; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.detailTask ? view.detailTask.dir : ""
                            color: "#94a3b8"
                            font { family: "monospace"; pixelSize: 11 }
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "PID: " + (view.detailTask ? view.detailTask.pid : "0")
                            color: "#94a3b8"
                            font { family: "monospace"; pixelSize: 10 }
                        }
                        Text {
                            text: view.detailTask ? (view.detailTask.uptime_str || ("UP " + view.detailTask.uptime + "s")) : "UP 0s"
                            color: (view.detailTask && view.detailTask.status === "running") ? "#34d399" : "#94a3b8"
                            font { family: "monospace"; pixelSize: 10; bold: true }
                        }
                        Text {
                            visible: view.detailTask && view.detailTask.port && view.detailTask.port.length > 0
                            text: "PORT: " + (view.detailTask ? view.detailTask.port : "")
                            color: "#60a5fa"
                            font { family: "monospace"; pixelSize: 10 }
                        }
                        Text {
                            visible: view.detailTask && view.detailTask.mem_mb > 0
                            text: "RAM: " + (view.detailTask ? view.detailTask.mem_mb : 0) + " MB"
                            color: "#94a3b8"
                            font { family: "monospace"; pixelSize: 10 }
                        }
                    }
                }
            }

            // Visualizador de Logs em Tempo Real Dedicado
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                radius: 10
                color: "#0a0b0f"
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(1, 1, 1, 0.05)
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "LIVE TERMINAL OUTPUT"
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true; letterSpacing: 1.0 }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: clrTxt.implicitWidth + 12
                                radius: 4
                                color: clrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰆴"
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: view.sys.fontFam; pixelSize: 11 }
                                    }
                                    Text {
                                        id: clrTxt
                                        text: "Limpar"
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: view.sys.fontFam; pixelSize: 10 }
                                    }
                                }

                                MouseArea {
                                    id: clrMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (view.detailTask) view.doClearLogs(view.detailTask.id)
                                }
                            }
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        TextArea {
                            id: logArea
                            text: view.logsText.length > 0 ? view.logsText : "Aguardando saída do processo..."
                            readOnly: true
                            color: "#e2e8f0"
                            background: null
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            font {
                                family: "monospace"
                                pixelSize: 11
                            }
                            cursorPosition: text.length
                        }
                    }
                }
            }
        }

        // ====================================================================
        // SCREEN 3: CREATION FORM (NEW SERVICE) + .SH IMPORT


        // ====================================================================
        ColumnLayout {
            id: newServiceView
            visible: view.addingTask
            Layout.fillWidth: true
            spacing: 12

            // Header with back button (<), title NEW SERVICE and close


            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 8
                    color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 16; bold: true }
                    }

                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.addingTask = false;
                            view.showScriptPicker = false;
                        }
                    }
                }

                Text {
                    text: "NEW SERVICE"
                    color: "#ffffff"
                    font {
                        family: view.sys.fontFam
                        pixelSize: view.sys.fontSize + 3
                        bold: true
                        letterSpacing: 1.2
                    }
                }

                Item { Layout.fillWidth: true }

                // Close button in opposite corner


                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: 8
                    color: nsClsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                    }

                    MouseArea {
                        id: nsClsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.collapse()
                    }
                }
            }

            // Button to load .sh file


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 8
                color: shPickMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                border.color: view.showScriptPicker ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰈔"
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                    Text {
                        text: view.showScriptPicker ? "Ocultar arquivos .sh" : "Carregar arquivo de script (.sh)"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                    }
                }

                MouseArea {
                    id: shPickMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.showScriptPicker = !view.showScriptPicker;
                        if (view.showScriptPicker) view.scanScripts();
                    }
                }
            }

            // List of detected .sh scripts for quick selection


            Rectangle {
                visible: view.showScriptPicker
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 8
                color: "#111218"
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    model: scriptsModel
                    spacing: 2

                    delegate: Rectangle {
                        required property var model
                        width: parent ? parent.width : 380
                        height: 28
                        radius: 5
                        color: scMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: "󰈔"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }
                            Text {
                                text: model.name
                                color: "#ffffff"
                                font { family: "monospace"; pixelSize: 11; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: model.path
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font { family: "monospace"; pixelSize: 9 }
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: scMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var base = model.name.replace(/\.sh$/i, "").toUpperCase();
                                inName.text = base;
                                inDir.text = model.dir;
                                inCmd.text = "bash " + model.path;
                                view.showScriptPicker = false;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: scriptsModel.count === 0
                        text: "Procurando scripts .sh no sistema..."
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                }
            }

            // Componente de Campo de Input Escuro e Arredondado
            component DarkField: ColumnLayout {
                id: dField
                property string label: ""
                property alias text: tf.text
                property alias placeholderText: tf.placeholderText
                spacing: 4
                Layout.fillWidth: true

                Text {
                    text: dField.label
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.8 }
                }

                TextField {
                    id: tf
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: "#ffffff"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                    font { family: "monospace"; pixelSize: 12 }
                    background: Rectangle {
                        color: "#111218"
                        radius: 8
                        border.color: tf.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                        border.width: tf.activeFocus ? 1.5 : 1
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                    }
                }
            }

            // Campos do formulario

            DarkField {
                id: inName
                label: "NAME"
                text: ""
                placeholderText: "e.g. HOMELAB-SMOKE"
            }

            DarkField {
                id: inDir
                label: "DIRECTORY"
                text: Quickshell.env("HOME") || "~"
                placeholderText: "/path/to/project"
            }

            DarkField {
                id: inCmd
                label: "COMMAND"
                text: ""
                placeholderText: "e.g. npm run dev or bash ./script.sh"
            }

            DarkField {
                id: inPort
                label: "PORT (OPCIONAL)"
                text: ""
                placeholderText: "e.g. 3000"
            }

            Text {
                Layout.fillWidth: true
                text: "Cria unidade persistente via systemd --user (sobrevive ao fechar o terminal)."
                color: Qt.rgba(1, 1, 1, 0.6)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 10
                color: createMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.15)
                border.color: view.sys.colOn
                border.width: 2.0
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "CREATE"
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true; letterSpacing: 1.2 }
                }

                MouseArea {
                    id: createMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (inCmd.text.trim().length > 0) {
                            view.doAddTask(inName.text, inDir.text, inCmd.text, inPort.text);
                            inName.text = "";
                            inCmd.text = "";
                        }
                    }
                }
            }
        }
    }
}
