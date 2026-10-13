import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

FocusScope {
    id: view
    property var sys

    width: parent ? parent.width : ((view.sys && view.sys.panelW) ? view.sys.panelW - 30 : 680)
    implicitHeight: col.implicitHeight

    property string tab: "containers" // "containers" | "images" | "create" | "search" | "dockerfile" | "logs"
    property bool initialChecked: false
    property var dockerStatus: ({
        installed: false,
        running: false,
        cli: "",
        containers_count: 0,
        images_count: 0,
        error: ""
    })

    ListModel { id: containersModel }
    ListModel { id: imagesModel }
    ListModel { id: searchModel }
    ListModel { id: tagsModel }
    ListModel { id: dockerfilesModel }

    property string selectedSearchImage: ""
    property string selectedTag: "latest"
    property bool searchingImages: false
    property bool loadingTags: false

    // Pull status
    property bool isPulling: false
    property string pullTarget: ""
    property string pullLog: ""
    property string pullStatusText: ""

    // Build status
    property bool isBuilding: false
    property string buildTarget: ""
    property string buildLog: ""

    // Create container status
    property bool isCreatingContainer: false
    property string createContainerError: ""
    property string createContainerSuccess: ""
    property string preselectedImage: ""

    property string logContainerName: ""
    property string logContainerId: ""
    property string containerLogs: ""

    Process {
        id: pDockerAll
        command: ["python3", view.sys.scriptDir + "/docker.py", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                view.initialChecked = true;
                try {
                    var d = JSON.parse(text);
                    if (d.status) view.dockerStatus = d.status;
                    
                    var cs = d.containers || [];
                    containersModel.clear();
                    for (var i = 0; i < cs.length; i++) containersModel.append(cs[i]);

                    var imgs = d.images || [];
                    imagesModel.clear();
                    for (var j = 0; j < imgs.length; j++) imagesModel.append(imgs[j]);
                } catch (e) {}
            }
        }
    }

    Process {
        id: pSearch
        stdout: StdioCollector {
            onStreamFinished: {
                view.searchingImages = false;
                try {
                    var res = JSON.parse(text);
                    searchModel.clear();
                    for (var i = 0; i < res.length; i++) {
                        searchModel.append(res[i]);
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pTags
        stdout: StdioCollector {
            onStreamFinished: {
                view.loadingTags = false;
                try {
                    var ts = JSON.parse(text);
                    tagsModel.clear();
                    for (var i = 0; i < ts.length; i++) {
                        tagsModel.append({ "name": ts[i] });
                    }
                    if (ts.length > 0) {
                        view.selectedTag = ts[0];
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pPullStatus
        command: ["python3", view.sys.scriptDir + "/docker.py", "pull_status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var s = JSON.parse(text);
                    view.isPulling = s.running;
                    view.pullTarget = s.target || "";
                    view.pullLog = s.log || "";
                    if (s.status === "done") {
                        view.pullStatusText = (view.sys && view.sys.isPt) ? "Concluído com sucesso!" : "Download completed successfully!";
                        view.refresh();
                    } else if (s.status === "error") {
                        view.pullStatusText = (view.sys && view.sys.isPt) ? "Erro ao baixar imagem" : "Failed to download image";
                    } else if (s.running) {
                        view.pullStatusText = (view.sys && view.sys.isPt) ? ("Baixando " + s.target + "…") : ("Downloading " + s.target + "…");
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pBuildStatus
        command: ["python3", view.sys.scriptDir + "/docker.py", "build_status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var b = JSON.parse(text);
                    view.isBuilding = b.running;
                    view.buildTarget = b.target || "";
                    view.buildLog = b.log || "";
                    if (b.status === "done") {
                        view.refresh();
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pScanDockerfiles
        command: ["python3", view.sys.scriptDir + "/docker.py", "scan_dockerfiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var dfs = JSON.parse(text);
                    dockerfilesModel.clear();
                    for (var i = 0; i < dfs.length; i++) {
                        dockerfilesModel.append(dfs[i]);
                    }
                } catch (e) {}
            }
        }
    }

    Process { id: pAction }
    Process {
        id: pLogs
        stdout: StdioCollector {
            onStreamFinished: view.containerLogs = text
        }
    }
    Process {
        id: pRunContainer
        stdout: StdioCollector {
            onStreamFinished: {
                view.isCreatingContainer = false;
                try {
                    var res = JSON.parse(text);
                    if (res.success) {
                        view.createContainerSuccess = (view.sys && view.sys.isPt)
                            ? "Container criado e iniciado com sucesso!"
                            : "Container created and started successfully!";
                        view.createContainerError = "";
                        view.refresh();
                        switchTabTimer.restart();
                    } else {
                        view.createContainerError = res.error || "Falha ao criar container.";
                        view.createContainerSuccess = "";
                    }
                } catch (e) {
                    view.createContainerError = text ? text : "Erro desconhecido.";
                    view.createContainerSuccess = "";
                }
            }
        }
    }

    Timer {
        id: switchTabTimer
        interval: 1200
        repeat: false
        onTriggered: {
            view.tab = "containers";
            view.createContainerSuccess = "";
        }
    }

    function refresh() {
        if (!pDockerAll.running) {
            pDockerAll.command = ["python3", view.sys.scriptDir + "/docker.py", "all"];
            pDockerAll.running = true;
        }
    }

    function refreshLogs() {
        if (view.logContainerId.length > 0) {
            pLogs.command = ["python3", view.sys.scriptDir + "/docker.py", "logs", view.logContainerId, "200"];
            pLogs.running = false;
            pLogs.running = true;
        }
    }

    function doAction(act, target) {
        pAction.command = ["python3", view.sys.scriptDir + "/docker.py", act, target];
        pAction.running = false;
        pAction.running = true;
        refreshTimer.restart();
        view.refresh();
    }

    function doSearch(q) {
        if (!q || q.trim().length === 0) return;
        view.searchingImages = true;
        pSearch.command = ["python3", view.sys.scriptDir + "/docker.py", "search", q.trim()];
        pSearch.running = false;
        pSearch.running = true;
    }

    function doFetchTags(imgName) {
        view.selectedSearchImage = imgName;
        view.loadingTags = true;
        tagsModel.clear();
        pTags.command = ["python3", view.sys.scriptDir + "/docker.py", "tags", imgName];
        pTags.running = false;
        pTags.running = true;
    }

    function doPullAsync(target) {
        if (!target || target.trim().length === 0) return;
        view.isPulling = true;
        view.pullTarget = target.trim();
        view.pullStatusText = (view.sys && view.sys.isPt) ? ("Iniciando download de " + target.trim() + "…") : ("Starting pull for " + target.trim() + "…");
        pAction.command = ["python3", view.sys.scriptDir + "/docker.py", "pull_async", target.trim()];
        pAction.running = false;
        pAction.running = true;
    }

    function doBuildAsync(dfPath, tag, ctx) {
        if (!dfPath || !tag) return;
        view.isBuilding = true;
        view.buildTarget = tag;
        pAction.command = ["python3", view.sys.scriptDir + "/docker.py", "build_async", dfPath, tag, ctx || ""];
        pAction.running = false;
        pAction.running = true;
    }

    function showLogs(cid, name) {
        view.logContainerId = cid;
        view.logContainerName = name;
        view.tab = "logs";
        view.refreshLogs();
    }

    function doCreateContainer(params) {
        view.isCreatingContainer = true;
        view.createContainerError = "";
        view.createContainerSuccess = "";
        pRunContainer.command = ["python3", view.sys.scriptDir + "/docker.py", "run_json", JSON.stringify(params)];
        pRunContainer.running = false;
        pRunContainer.running = true;
    }

    function openCreateForImage(imgName) {
        view.preselectedImage = imgName;
        view.createContainerError = "";
        view.createContainerSuccess = "";
        view.tab = "create";
    }

    Timer {
        id: refreshTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            view.refresh();
            if (view.tab === "logs") view.refreshLogs();
            if (view.isPulling || view.pullTarget.length > 0) {
                pPullStatus.running = false;
                pPullStatus.running = true;
            }
            if (view.isBuilding) {
                pBuildStatus.running = false;
                pBuildStatus.running = true;
            }
        }
    }

    Component.onCompleted: {
        view.refresh();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ====================================================================
        // DOCKER HEADER (Icon + Title + Status + Prune + Close)


        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                glyph: String.fromCodePoint(0xF0868) // docker whale
                color: "#0db7ed"
                fontFam: view.sys.fontFam
                size: 22
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                RowLayout {
                    spacing: 8
                    Text {
                        text: "Docker Manager"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2; bold: true }
                    }
                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: statTxt.implicitWidth + 10
                        radius: 4
                        color: !view.initialChecked ? Qt.rgba(1, 1, 1, 0.08)
                             : view.dockerStatus.running ? Qt.rgba(0.06, 0.72, 0.5, 0.2)
                             : Qt.rgba(1, 0.2, 0.2, 0.2)
                        Text {
                            id: statTxt
                            anchors.centerIn: parent
                            text: !view.initialChecked ? "CONECTANDO…" : (view.dockerStatus.running ? "ONLINE" : "OFFLINE")
                            color: !view.initialChecked ? view.sys.colMuted : (view.dockerStatus.running ? "#10b981" : view.sys.colCrit)
                            font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (view.sys && view.sys.isPt) ? "Gerenciamento de containers e imagens" : "Manage local containers and images"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            Item { Layout.fillWidth: true }

            // Prune / Limpeza Geral
            Rectangle {
                visible: view.dockerStatus.running
                Layout.preferredHeight: 28
                Layout.preferredWidth: pruneRow.implicitWidth + 16
                radius: 6
                color: pruneMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                RowLayout {
                    id: pruneRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: String.fromCodePoint(0xF01B4) // trash icon
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                    Text {
                        text: (view.sys && view.sys.isPt) ? "Limpeza" : "Prune"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10 }
                    }
                }
                MouseArea {
                    id: pruneMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.doAction("prune", "")
                }
            }

            // Close button


            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: 6
                color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0156) // close icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
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

        // ====================================================================
        // WARNING IF OFFLINE (Only after first scan complete)


        // ====================================================================
        Rectangle {
            visible: view.initialChecked && !view.dockerStatus.running
            Layout.fillWidth: true
            Layout.preferredHeight: errCol.implicitHeight + 20
            radius: 10
            color: Qt.rgba(1, 0.3, 0.3, 0.08)
            border.color: Qt.rgba(1, 0.3, 0.3, 0.25)
            border.width: 1

            ColumnLayout {
                id: errCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    spacing: 8
                    Text {
                        text: String.fromCodePoint(0xF015A) // alert-circle
                        color: view.sys.colCrit
                        font { family: view.sys.fontFam; pixelSize: 16 }
                    }
                    Text {
                        text: view.dockerStatus.installed
                              ? ((view.sys && view.sys.isPt) ? "Serviço do Docker Inativo" : "Docker Daemon Not Running")
                              : ((view.sys && view.sys.isPt) ? "Docker não instalado" : "Docker Not Installed")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.dockerStatus.error.length > 0
                          ? view.dockerStatus.error
                          : ((view.sys && view.sys.isPt)
                             ? "Certifique-se de que o Docker está instalado e o serviço iniciado (systemctl start docker)."
                             : "Ensure Docker is installed and started.")
                    color: Qt.rgba(1, 1, 1, 0.75)
                    wrapMode: Text.WordWrap
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // ====================================================================
        // NAVIGATION TABS


        // ====================================================================
        RowLayout {
            visible: !view.initialChecked || view.dockerStatus.running
            Layout.fillWidth: true
            spacing: 6

            component DTabBtn: Rectangle {
                property string key: ""
                property string label: ""
                property string iconGlyph: ""
                readonly property bool isCur: view.tab === key

                Layout.preferredHeight: 28
                Layout.preferredWidth: dTabInnerRow.implicitWidth + 16
                radius: 7
                color: isCur ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                             : (dtMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                border.color: isCur ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    id: dTabInnerRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        visible: parent.parent.iconGlyph.length > 0
                        text: parent.parent.iconGlyph
                        color: parent.parent.isCur ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                    Text {
                        text: parent.parent.label
                        color: parent.parent.isCur ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10; bold: parent.parent.isCur }
                    }
                }

                MouseArea {
                    id: dtMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.tab = parent.key
                }
            }

            DTabBtn {
                key: "containers"
                iconGlyph: String.fromCodePoint(0xF0A36) // container-box
                label: "Containers (" + containersModel.count + ")"
            }
            DTabBtn {
                key: "images"
                iconGlyph: String.fromCodePoint(0xF0330) // layers
                label: "Imagens (" + imagesModel.count + ")"
            }
            DTabBtn {
                key: "create"
                iconGlyph: String.fromCodePoint(0xF0415) // plus-box
                label: (view.sys && view.sys.isPt) ? "Criar" : "Create"
            }
            DTabBtn {
                key: "search"
                iconGlyph: String.fromCodePoint(0xF0349) // search
                label: "Hub"
            }
            DTabBtn {
                key: "dockerfile"
                iconGlyph: String.fromCodePoint(0xF0214) // file-document
                label: "Dockerfile"
            }
            DTabBtn {
                visible: view.tab === "logs"
                key: "logs"
                iconGlyph: String.fromCodePoint(0xF0646) // text-box
                label: "Logs: " + view.logContainerName
            }

            Item { Layout.fillWidth: true }
        }

        // ====================================================================
        // STATUS DE DOWNLOAD / PULL EM ANDAMENTO
        // ====================================================================
        Rectangle {
            visible: view.isPulling || (view.pullStatusText.length > 0 && view.tab === "search")
            Layout.fillWidth: true
            Layout.preferredHeight: pullInfoCol.implicitHeight + 14
            radius: 8
            color: view.isPulling ? Qt.rgba(0.05, 0.45, 0.9, 0.15) : Qt.rgba(0.06, 0.72, 0.5, 0.15)
            border.color: view.isPulling ? "#38bdf8" : "#10b981"
            border.width: 1

            ColumnLayout {
                id: pullInfoCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: String.fromCodePoint(view.isPulling ? 0xF0450 : 0xF012C)
                        color: view.isPulling ? "#38bdf8" : "#10b981"
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.pullStatusText
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: view.pullLog.length > 0
                    Layout.fillWidth: true
                    text: view.pullLog
                    color: Qt.rgba(1, 1, 1, 0.65)
                    font { family: "monospace"; pixelSize: 9 }
                    elide: Text.ElideRight
                }
            }
        }

        // ====================================================================
        // 1. ABA: CONTAINERS
        // ====================================================================
        ColumnLayout {
            visible: (view.dockerStatus.running || !view.initialChecked) && view.tab === "containers"
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: (view.sys && view.sys.isPt) ? "CONTAINERS LOCAIS" : "LOCAL CONTAINERS"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.8 }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: newContBtnTxt.implicitWidth + 24
                    radius: 7
                    color: newContMa.containsMouse
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3)
                           : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                    border.color: view.sys.colOn
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: String.fromCodePoint(0xF0415) // plus
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 12 }
                        }
                        Text {
                            id: newContBtnTxt
                            text: (view.sys && view.sys.isPt) ? "Criar Container" : "New Container"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }
                    }

                    MouseArea {
                        id: newContMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.createContainerError = "";
                            view.createContainerSuccess = "";
                            view.tab = "create";
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(380, Math.max(160, containersModel.count * 56 + 12))
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.02)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                clip: true

                ListView {
                    id: containersList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: containersModel
                    spacing: 4

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    WheelHandler {
                        onWheel: event => {
                            containersList.contentY = Math.max(0, Math.min(containersList.contentHeight - containersList.height, containersList.contentY - event.angleDelta.y));
                        }
                    }

                    delegate: Rectangle {
                        id: cRow
                        required property var model
                        readonly property bool isUp: cRow.model.state === "running" || cRow.model.status.toLowerCase().indexOf("up") >= 0

                        width: containersList.width
                        height: 52
                        radius: 8
                        color: cMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)

                        MouseArea {
                            id: cMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.showLogs(cRow.model.id, cRow.model.name)
                        }

                        RowLayout {
                            z: 2
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            // Status dot
                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: cRow.isUp ? "#10b981" : Qt.rgba(1, 1, 1, 0.25)
                            }

                            // Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: cRow.model.name
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 200
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: cRow.model.image
                                        color: view.sys.colMuted
                                        elide: Text.ElideRight
                                        font { family: "monospace"; pixelSize: view.sys.fontSize - 3 }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: cRow.model.status
                                        color: cRow.isUp ? "#10b981" : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                    }
                                    Text {
                                        visible: cRow.isUp && cRow.model.cpu !== undefined
                                        Layout.fillWidth: true
                                        text: "• CPU: " + cRow.model.cpu + " • RAM: " + cRow.model.mem
                                        color: Qt.rgba(1, 1, 1, 0.45)
                                        font { family: "monospace"; pixelSize: view.sys.fontSize - 4 }
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Action buttons
                            RowLayout {
                                z: 10
                                spacing: 4

                                // Start / Stop
                                Rectangle {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                                    color: csMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(cRow.isUp ? 0xF04DB : 0xF040A)
                                        color: cRow.isUp ? view.sys.colCrit : "#10b981"
                                        font { family: view.sys.fontFam; pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: csMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (cRow.isUp) view.doAction("stop", cRow.model.id);
                                            else view.doAction("start", cRow.model.id);
                                        }
                                    }
                                }

                                // Restart
                                Rectangle {
                                    visible: cRow.isUp
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                                    color: crMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(0xF0450) // sync / restart
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: crMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.doAction("restart", cRow.model.id)
                                    }
                                }

                                // Logs
                                Rectangle {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                                    color: clgMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(0xF0646) // text-box / logs
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: clgMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.showLogs(cRow.model.id, cRow.model.name)
                                    }
                                }

                                // Remove
                                Rectangle {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 6
                                    color: cdelMa.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(0xF01B4) // trash
                                        color: cdelMa.containsMouse ? view.sys.colCrit : Qt.rgba(1, 1, 1, 0.4)
                                        font { family: view.sys.fontFam; pixelSize: 12 }
                                    }
                                    MouseArea {
                                        id: cdelMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.doAction("rm", cRow.model.id)
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: containersModel.count === 0 && view.initialChecked
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (view.sys && view.sys.isPt) ? "Nenhum container encontrado" : "No containers found"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: emptyNewBtnTxt.implicitWidth + 24
                            radius: 7
                            color: emptyNewMa.containsMouse
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                   : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.2)
                            border.color: view.sys.colOn
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: String.fromCodePoint(0xF0415)
                                    color: view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }
                                Text {
                                    id: emptyNewBtnTxt
                                    text: (view.sys && view.sys.isPt) ? "Criar Primeiro Container" : "Create First Container"
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                            }

                            MouseArea {
                                id: emptyNewMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.createContainerError = "";
                                    view.createContainerSuccess = "";
                                    view.tab = "create";
                                }
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 2. ABA: IMAGENS LOCAIS
        // ====================================================================
        ColumnLayout {
            visible: view.dockerStatus.running && view.tab === "images"
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: inPull.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    TextField {
                        id: inPull
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        placeholderText: (view.sys && view.sys.isPt) ? "Baixar imagem (ex: postgres:16, alpine, redis)…" : "Pull image by name…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                        color: view.sys.colFg
                        background: null
                        font { family: "monospace"; pixelSize: view.sys.fontSize - 2 }
                        onAccepted: {
                            if (text.trim().length > 0) {
                                view.doPullAsync(text.trim());
                                text = "";
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: pullBtnTxt.implicitWidth + 24
                    radius: 8
                    color: pullBtnMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.8) : view.sys.colOn

                    Text {
                        id: pullBtnTxt
                        anchors.centerIn: parent
                        text: (view.sys && view.sys.isPt) ? "Baixar" : "Pull"
                        color: view.sys.fgOn(view.sys.colOn)
                        font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                    }
                    MouseArea {
                        id: pullBtnMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (inPull.text.trim().length > 0) {
                                view.doPullAsync(inPull.text.trim());
                                inPull.text = "";
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(360, Math.max(140, imagesModel.count * 46 + 12))
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.02)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                clip: true

                ListView {
                    id: imagesList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: imagesModel
                    spacing: 3

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    WheelHandler {
                        onWheel: event => {
                            imagesList.contentY = Math.max(0, Math.min(imagesList.contentHeight - imagesList.height, imagesList.contentY - event.angleDelta.y));
                        }
                    }

                    delegate: Rectangle {
                        id: imgRow
                        required property var model
                        width: imagesList.width
                        height: 44
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.03)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: imgRow.model.repository + ":" + imgRow.model.tag
                                    color: view.sys.colFg
                                    font { family: "monospace"; pixelSize: view.sys.fontSize - 2; bold: true }
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "ID: " + imgRow.model.id + " • " + imgRow.model.size + " • " + imgRow.model.created
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                    elide: Text.ElideRight
                                }
                            }

                            // Run / Create Container
                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: runImgRow.implicitWidth + 14
                                radius: 6
                                color: irunMa.containsMouse
                                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3)
                                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.15)
                                border.color: view.sys.colOn
                                border.width: 1

                                RowLayout {
                                    id: runImgRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: String.fromCodePoint(0xF040A)
                                        color: view.sys.colOn
                                        font { family: view.sys.fontFam; pixelSize: 11 }
                                    }
                                    Text {
                                        text: (view.sys && view.sys.isPt) ? "Rodar" : "Run"
                                        color: "#ffffff"
                                        font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                    }
                                }

                                MouseArea {
                                    id: irunMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var imgTarget = (imgRow.model.repository && imgRow.model.repository !== "<none>")
                                            ? (imgRow.model.repository + (imgRow.model.tag ? ":" + imgRow.model.tag : ""))
                                            : imgRow.model.id;
                                        view.openCreateForImage(imgTarget);
                                    }
                                }
                            }

                            // Remove image
                            Rectangle {
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 6
                                color: idelMa.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF01B4)
                                    color: idelMa.containsMouse ? view.sys.colCrit : Qt.rgba(1, 1, 1, 0.4)
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }
                                MouseArea {
                                    id: idelMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.doAction("rmi", imgRow.model.id)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: imagesModel.count === 0
                        text: (view.sys && view.sys.isPt) ? "Nenhuma imagem encontrada" : "No images found"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }
            }
        }

        // ====================================================================
        // 3. TAB: CREATE CONTAINER (2 Column Layout, no content trimming)


        // ====================================================================
        ColumnLayout {
            visible: view.dockerStatus.running && view.tab === "create"
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: (view.sys && view.sys.isPt) ? "CRIAR NOVO CONTAINER" : "CREATE NEW CONTAINER"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.8 }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: (view.sys && view.sys.isPt) ? "Voltar aos containers" : "Back to containers"
                    color: cancelCreateMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        id: cancelCreateMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.tab = "containers"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: createFormCol.implicitHeight + 20
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.02)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: createFormCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    property bool optDetached: true
                    property bool optRestart: true

                    function submitCreate() {
                        var img = inRunImage.text.trim();
                        if (img.length === 0) {
                            view.createContainerError = (view.sys && view.sys.isPt)
                                ? "Por favor, especifique o nome da imagem."
                                : "Please specify an image name.";
                            return;
                        }
                        view.doCreateContainer({
                            image: img,
                            name: inRunName.text.trim(),
                            ports: inRunPorts.text.trim(),
                            env: inRunEnv.text.trim(),
                            volumes: inRunVolumes.text.trim(),
                            detached: optDetached,
                            restart: optRestart ? "unless-stopped" : ""
                        });
                    }

                    Connections {
                        target: view
                        function onPreselectedImageChanged() {
                            inRunImage.text = view.preselectedImage;
                        }
                    }

                    // 1. Campo: Imagem Docker
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            spacing: 4
                            Text {
                                text: (view.sys && view.sys.isPt) ? "IMAGEM DOCKER *" : "DOCKER IMAGE *"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            Text {
                                text: "(ex: postgres:16, redis:alpine, nginx)"
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font { family: view.sys.fontFam; pixelSize: 9 }
                            }
                        }

                        TextField {
                            id: inRunImage
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: "#ffffff"
                            text: view.preselectedImage
                            placeholderText: (view.sys && view.sys.isPt) ? "Nome da imagem (ex: postgres:16, nginx:alpine)…" : "Image name…"
                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                            font { family: "monospace"; pixelSize: 11 }
                            background: Rectangle {
                                color: "#111218"
                                radius: 6
                                border.color: inRunImage.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                            }
                            onAccepted: createFormCol.submitCreate()
                        }

                        // Local image chips already downloaded


                        ColumnLayout {
                            visible: imagesModel.count > 0
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: (view.sys && view.sys.isPt) ? "Imagens locais disponíveis (clique para preencher):" : "Downloaded images (click to use):"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font { family: view.sys.fontFam; pixelSize: 8 }
                            }

                            Flickable {
                                id: chipsFlick
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                contentWidth: localImgsRow.implicitWidth
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

                                WheelHandler {
                                    orientation: Qt.Horizontal
                                    onWheel: event => {
                                        chipsFlick.contentX = Math.max(0, Math.min(chipsFlick.contentWidth - chipsFlick.width, chipsFlick.contentX - event.angleDelta.y));
                                    }
                                }

                                RowLayout {
                                    id: localImgsRow
                                    spacing: 5

                                    Repeater {
                                        model: imagesModel
                                        delegate: Rectangle {
                                            id: imgChip
                                            required property var model
                                            readonly property string fullName: (model.repository && model.repository !== "<none>")
                                                ? (model.repository + (model.tag ? ":" + model.tag : ""))
                                                : model.id
                                            readonly property bool isSelected: inRunImage.text === fullName

                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: imgChipTxt.implicitWidth + 14
                                            radius: 11
                                            color: isSelected ? Qt.rgba(0.06, 0.72, 0.51, 0.3) : (chipImgMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                                            border.color: isSelected ? "#10b981" : Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            Text {
                                                id: imgChipTxt
                                                anchors.centerIn: parent
                                                text: imgChip.fullName
                                                color: imgChip.isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                                                font { family: "monospace"; pixelSize: 9; bold: imgChip.isSelected }
                                            }

                                            MouseArea {
                                                id: chipImgMa
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: inRunImage.text = imgChip.fullName
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. Line with Name and Ports side by side

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: (view.sys && view.sys.isPt) ? "NOME DO CONTAINER (OPCIONAL)" : "CONTAINER NAME (OPTIONAL)"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            TextField {
                                id: inRunName
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "#ffffff"
                                placeholderText: "ex: meu-postgres"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                font { family: "monospace"; pixelSize: 11 }
                                background: Rectangle {
                                    color: "#111218"
                                    radius: 6
                                    border.color: inRunName.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                                onAccepted: createFormCol.submitCreate()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: (view.sys && view.sys.isPt) ? "PORTAS (HOST:CONTAINER)" : "PORTS (HOST:CONTAINER)"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            TextField {
                                id: inRunPorts
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "#ffffff"
                                placeholderText: "ex: 5432:5432, 8080:80"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                font { family: "monospace"; pixelSize: 11 }
                                background: Rectangle {
                                    color: "#111218"
                                    radius: 6
                                    border.color: inRunPorts.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                                onAccepted: createFormCol.submitCreate()
                            }
                        }
                    }

                    // 3. Line with ENV and Volumes side by side

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: (view.sys && view.sys.isPt) ? "VARIÁVEIS (ENV)" : "ENV (KEY=VAL)"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            TextField {
                                id: inRunEnv
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "#ffffff"
                                placeholderText: "ex: POSTGRES_PASSWORD=123"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                font { family: "monospace"; pixelSize: 11 }
                                background: Rectangle {
                                    color: "#111218"
                                    radius: 6
                                    border.color: inRunEnv.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                                onAccepted: createFormCol.submitCreate()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: (view.sys && view.sys.isPt) ? "VOLUMES" : "VOLUMES"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            TextField {
                                id: inRunVolumes
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "#ffffff"
                                placeholderText: "ex: /host/dir:/container/dir"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.35)
                                font { family: "monospace"; pixelSize: 11 }
                                background: Rectangle {
                                    color: "#111218"
                                    radius: 6
                                    border.color: inRunVolumes.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                                onAccepted: createFormCol.submitCreate()
                            }
                        }
                    }

                    // 4. Options: Detached & Restart


                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        RowLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                radius: 4
                                color: createFormCol.optDetached ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                                border.color: createFormCol.optDetached ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    visible: createFormCol.optDetached
                                    text: String.fromCodePoint(0xF012C) // checkmark
                                    color: view.sys.fgOn(view.sys.colOn)
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: createFormCol.optDetached = !createFormCol.optDetached
                                }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Segundo plano (-d)" : "Detached (-d)"
                                color: Qt.rgba(1, 1, 1, 0.8)
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                        }

                        RowLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                radius: 4
                                color: createFormCol.optRestart ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                                border.color: createFormCol.optRestart ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.2)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    visible: createFormCol.optRestart
                                    text: String.fromCodePoint(0xF012C) // checkmark
                                    color: view.sys.fgOn(view.sys.colOn)
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: createFormCol.optRestart = !createFormCol.optRestart
                                }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Auto-reiniciar (--restart unless-stopped)" : "Restart policy"
                                color: Qt.rgba(1, 1, 1, 0.8)
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                        }
                    }

                    // Mensagem de Erro
                    Rectangle {
                        visible: view.createContainerError.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: errTxtLayout.implicitHeight + 14
                        radius: 6
                        color: Qt.rgba(1, 0.2, 0.2, 0.15)
                        border.color: view.sys.colCrit
                        border.width: 1

                        RowLayout {
                            id: errTxtLayout
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Text {
                                text: String.fromCodePoint(0xF015A)
                                color: view.sys.colCrit
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.createContainerError
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 10 }
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Mensagem de Sucesso
                    Rectangle {
                        visible: view.createContainerSuccess.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: succTxtLayout.implicitHeight + 14
                        radius: 6
                        color: Qt.rgba(0.06, 0.72, 0.51, 0.2)
                        border.color: "#10b981"
                        border.width: 1

                        RowLayout {
                            id: succTxtLayout
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Text {
                                text: String.fromCodePoint(0xF012C)
                                color: "#10b981"
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.createContainerSuccess
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Create and Launch Container button


                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: createSubmitMa.containsMouse
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                               : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                        border.color: view.sys.colOn
                        border.width: 1.5

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: String.fromCodePoint(view.isCreatingContainer ? 0xF0450 : 0xF040A)
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            Text {
                                text: view.isCreatingContainer
                                      ? ((view.sys && view.sys.isPt) ? "CRIANDO E INICIANDO CONTAINER…" : "CREATING CONTAINER…")
                                      : ((view.sys && view.sys.isPt) ? "CRIAR E INICIAR CONTAINER" : "CREATE AND START CONTAINER")
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true; letterSpacing: 0.8 }
                            }
                        }

                        MouseArea {
                            id: createSubmitMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: createFormCol.submitCreate()
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 4. TAB: SEARCH DOCKER HUB & VERSES / TAGS


        // ====================================================================
        ColumnLayout {
            visible: view.dockerStatus.running && view.tab === "search"
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    color: "#111218"
                    border.color: inSearch.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: String.fromCodePoint(0xF0349) // search
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }

                        TextField {
                            id: inSearch
                            Layout.fillWidth: true
                            placeholderText: (view.sys && view.sys.isPt) ? "Buscar no Docker Hub (ex: postgres, redis, node, alpine)…" : "Search Docker Hub…"
                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                            color: "#ffffff"
                            background: null
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            onAccepted: view.doSearch(text)
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: searchBtnTxt.implicitWidth + 24
                    radius: 8
                    color: searchBtnMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3) : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                    border.color: view.sys.colOn
                    border.width: 1

                    Text {
                        id: searchBtnTxt
                        anchors.centerIn: parent
                        text: view.searchingImages ? "Buscando…" : "Buscar"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                    }

                    MouseArea {
                        id: searchBtnMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.doSearch(inSearch.text)
                    }
                }
            }

            // Tag selection of the selected image


            Rectangle {
                visible: view.selectedSearchImage.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: tagBoxCol.implicitHeight + 14
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                ColumnLayout {
                    id: tagBoxCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: (view.sys && view.sys.isPt) ? "Imagem selecionada:" : "Selected image:"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        Text {
                            text: view.selectedSearchImage
                            color: "#38bdf8"
                            font { family: "monospace"; pixelSize: 11; bold: true }
                        }
                        Text {
                            text: ":"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font { family: "monospace"; pixelSize: 11 }
                        }
                        Text {
                            text: view.selectedTag
                            color: "#10b981"
                            font { family: "monospace"; pixelSize: 11; bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: pullSelBtnTxt.implicitWidth + 16
                            radius: 6
                            color: view.isPulling ? Qt.rgba(1, 1, 1, 0.1) : view.sys.colOn

                            Text {
                                id: pullSelBtnTxt
                                anchors.centerIn: parent
                                text: view.isPulling ? "Baixando…" : "Baixar Imagem"
                                color: view.sys.fgOn(view.sys.colOn)
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!view.isPulling) {
                                        view.doPullAsync(view.selectedSearchImage + ":" + view.selectedTag);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: runSelBtnTxt.implicitWidth + 18
                            radius: 6
                            color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.2)
                            border.color: view.sys.colOn
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: String.fromCodePoint(0xF040A)
                                    color: view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                                Text {
                                    id: runSelBtnTxt
                                    text: (view.sys && view.sys.isPt) ? "Criar Container" : "Create Container"
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.openCreateForImage(view.selectedSearchImage + ":" + view.selectedTag);
                                }
                            }
                        }
                    }

                    Text {
                        text: view.loadingTags ? "Carregando versões disponíveis…" : "Versões / Tags disponíveis:"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font { family: view.sys.fontFam; pixelSize: 9 }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        contentWidth: tagsRow.implicitWidth
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: tagsRow
                            spacing: 6

                            Repeater {
                                model: tagsModel
                                delegate: Rectangle {
                                    required property var model
                                    readonly property bool isCurTag: view.selectedTag === model.name
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: tagChipTxt.implicitWidth + 14
                                    radius: 12
                                    color: isCurTag ? Qt.rgba(0.06, 0.72, 0.51, 0.3) : (chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                                    border.color: isCurTag ? "#10b981" : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    Text {
                                        id: tagChipTxt
                                        anchors.centerIn: parent
                                        text: model.name
                                        color: isCurTag ? "#ffffff" : Qt.rgba(1, 1, 1, 0.75)
                                        font { family: "monospace"; pixelSize: 10; bold: isCurTag }
                                    }

                                    MouseArea {
                                        id: chipMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.selectedTag = model.name
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                radius: 10
                color: "#111218"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                clip: true

                ListView {
                    id: searchList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: searchModel
                    spacing: 3

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    WheelHandler {
                        onWheel: event => {
                            searchList.contentY = Math.max(0, Math.min(searchList.contentHeight - searchList.height, searchList.contentY - event.angleDelta.y));
                        }
                    }

                    delegate: Rectangle {
                        id: sRow
                        required property var model
                        readonly property bool isSelected: view.selectedSearchImage === sRow.model.name
                        width: searchList.width
                        height: 48
                        radius: 8
                        color: isSelected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                          : (sMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03))
                        border.color: isSelected ? view.sys.colOn : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: sRow.model.name
                                        color: "#ffffff"
                                        font { family: "monospace"; pixelSize: 12; bold: true }
                                    }
                                    Rectangle {
                                        visible: sRow.model.official
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: offTxt.implicitWidth + 8
                                        radius: 3
                                        color: Qt.rgba(0.06, 0.72, 0.51, 0.25)
                                        Text {
                                            id: offTxt
                                            anchors.centerIn: parent
                                            text: "OFFICIAL"
                                            color: "#10b981"
                                            font { family: view.sys.fontFam; pixelSize: 8; bold: true }
                                        }
                                    }
                                    RowLayout {
                                        spacing: 3
                                        Text {
                                            text: String.fromCodePoint(0xF04CE) // star icon
                                            color: "#fbbf24"
                                            font { family: view.sys.fontFam; pixelSize: 10 }
                                        }
                                        Text {
                                            text: sRow.model.stars
                                            color: "#fbbf24"
                                            font { family: view.sys.fontFam; pixelSize: 10 }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: sRow.model.description || "Sem descrição"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font { family: view.sys.fontFam; pixelSize: 9 }
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: (view.sys && view.sys.isPt) ? "Versões" : "Tags"
                                    color: isSelected ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.5)
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                                Text {
                                    text: String.fromCodePoint(0xF0142) // chevron-right
                                    color: isSelected ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.4)
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }
                        }

                        MouseArea {
                            id: sMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.doFetchTags(sRow.model.name)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: searchModel.count === 0 && !view.searchingImages
                        text: (view.sys && view.sys.isPt) ? "Digite um nome de imagem acima (ex: postgres, redis) e clique em Buscar." : "Type an image name above and click Search."
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                }
            }
        }

        // ====================================================================
        // 5. ABA: BUILD DOCKERFILE
        // ====================================================================
        ColumnLayout {
            visible: view.dockerStatus.running && view.tab === "dockerfile"
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (view.sys && view.sys.isPt) ? "CONSTRUIR IMAGEM COM DOCKERFILE" : "BUILD IMAGE WITH DOCKERFILE"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true; letterSpacing: 0.8 }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: scanDfTxt.implicitWidth + 24
                    radius: 6
                    color: scanDfMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: String.fromCodePoint(0xF0214) // file
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                        Text {
                            id: scanDfTxt
                            text: (view.sys && view.sys.isPt) ? "Escanear Dockerfiles" : "Scan Dockerfiles"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }
                    MouseArea {
                        id: scanDfMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pScanDockerfiles.running = true
                    }
                }
            }

            Rectangle {
                visible: dockerfilesModel.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 8
                color: "#111218"
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    model: dockerfilesModel
                    spacing: 2

                    delegate: Rectangle {
                        required property var model
                        width: parent ? parent.width : 400
                        height: 24
                        radius: 5
                        color: dfMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: String.fromCodePoint(0xF0214)
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                            Text {
                                text: model.name
                                color: "#ffffff"
                                font { family: "monospace"; pixelSize: 10; bold: true }
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
                            id: dfMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                inDfPath.text = model.path;
                                inDfTag.text = "local-app:latest";
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: (view.sys && view.sys.isPt) ? "CAMINHO DO DOCKERFILE" : "DOCKERFILE PATH"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                    }
                    TextField {
                        id: inDfPath
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: "#ffffff"
                        placeholderText: "/caminho/para/Dockerfile"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                        font { family: "monospace"; pixelSize: 11 }
                        background: Rectangle {
                            color: "#111218"
                            radius: 6
                            border.color: inDfPath.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 220
                    spacing: 3
                    Text {
                        text: (view.sys && view.sys.isPt) ? "TAG DA IMAGEM" : "IMAGE TAG"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                    }
                    TextField {
                        id: inDfTag
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: "#ffffff"
                        text: "minha-imagem:latest"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                        font { family: "monospace"; pixelSize: 11 }
                        background: Rectangle {
                            color: "#111218"
                            radius: 6
                            border.color: inDfTag.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: buildBtnMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                border.color: view.sys.colOn
                border.width: 1.5

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: String.fromCodePoint(view.isBuilding ? 0xF0450 : 0xF040A)
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }
                    Text {
                        text: view.isBuilding ? "CONSTRUINDO IMAGEM…" : "CONSTRUIR IMAGEM (DOCKER BUILD)"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 11; bold: true; letterSpacing: 0.8 }
                    }
                }

                MouseArea {
                    id: buildBtnMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (inDfPath.text.trim().length > 0 && inDfTag.text.trim().length > 0) {
                            view.doBuildAsync(inDfPath.text.trim(), inDfTag.text.trim(), "");
                        }
                    }
                }
            }

            Rectangle {
                visible: view.buildLog.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                radius: 8
                color: "#0c0d10"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    TextArea {
                        text: view.buildLog
                        readOnly: true
                        color: "#cbd5e1"
                        background: null
                        font { family: "monospace"; pixelSize: 10 }
                    }
                }
            }
        }

        // ====================================================================
        // 6. ABA: LOGS DO CONTAINER
        // ====================================================================
        Rectangle {
            visible: view.dockerStatus.running && view.tab === "logs"
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            radius: 10
            color: "#0c0d10"
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Qt.rgba(1, 1, 1, 0.04)
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: (view.sys && view.sys.isPt) ? "LOGS DO CONTAINER:" : "CONTAINER LOGS:"
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.logContainerName + " (" + view.logContainerId + ")"
                            color: "#0db7ed"
                            elide: Text.ElideRight
                            font { family: "monospace"; pixelSize: 10; bold: true }
                        }
                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: bckTxt.implicitWidth + 14
                            radius: 4
                            color: bckMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            Text {
                                id: bckTxt
                                anchors.centerIn: parent
                                text: "Voltar"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                            MouseArea {
                                id: bckMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.tab = "containers"
                            }
                        }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        text: view.containerLogs.length > 0 ? view.containerLogs : "Carregando logs…"
                        readOnly: true
                        color: Qt.rgba(0.85, 0.9, 0.9, 0.85)
                        background: null
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        font { family: "monospace"; pixelSize: 11 }
                        cursorPosition: text.length
                    }
                }
            }
        }
    }
}
