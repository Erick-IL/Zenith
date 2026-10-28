import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// =============================================================================
// EmulatorView — Biblioteca & Seletor de Jogos (GBA · Nintendo DS · Nintendo 3DS)
// Abre os jogos diretamente nos emuladores nativos (mGBA, melonDS, Azahar).
// =============================================================================
Item {
    id: view
    required property var sys

    readonly property bool isPt: !view.sys || view.sys.isPt === undefined ? true : view.sys.isPt
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/zenith/scripts/emulator.py"

    // "library" | "homebrew"
    property string activeTab: "library"
    // "ALL" | "GBA" | "NDS" | "3DS" | "FAV"
    property string consoleFilter: "ALL"
    property string searchQuery: ""
    property int selectedIndex: 0

    property var roms: []
    property var catalog: []
    property var engines: ({
        mgba: { installed: true, bin: "" },
        melonds: { installed: true, bin: "" },
        azahar: { installed: true, bin: "" }
    })
    property var cfg3ds: ({
        resolution_factor: 3,
        graphics_api: 2,
        fullscreen: false
    })
    property bool loading: true
    property string downloadingId: ""
    property string statusMsg: ""

    readonly property var filteredRoms: {
        var list = view.roms || [];
        var q = view.searchQuery.trim().toLowerCase();
        var cf = view.consoleFilter;
        return list.filter(function(r) {
            if (cf === "FAV" && !r.favorite) return false;
            if (cf !== "ALL" && cf !== "FAV" && r.platform !== cf) return false;
            if (q.length > 0) {
                var t = (r.title || "").toLowerCase();
                var it = (r.internal_title || "").toLowerCase();
                var fn = (r.filename || "").toLowerCase();
                var gc = (r.game_code || "").toLowerCase();
                if (t.indexOf(q) < 0 && it.indexOf(q) < 0 && fn.indexOf(q) < 0 && gc.indexOf(q) < 0)
                    return false;
            }
            return true;
        });
    }

    onFilteredRomsChanged: {
        if (view.selectedIndex >= view.filteredRoms.length)
            view.selectedIndex = Math.max(0, view.filteredRoms.length - 1);
    }

    implicitWidth: 500
    implicitHeight: mainCol.implicitHeight

    Component.onCompleted: {
        view.refreshAll();
    }

    function showToast(msg) {
        view.statusMsg = msg;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2500
        onTriggered: view.statusMsg = ""
    }

    function refreshAll() {
        view.loading = true;
        pFetch.running = false;
        pFetch.running = true;
    }

    function launchGame(rom, fullscreen) {
        if (!rom || !rom.path) return;
        var args = ["python3", view.scriptPath, "launch", rom.path];
        if (fullscreen) args.push("fullscreen");
        pCmd.command = args;
        pCmd.running = false;
        pCmd.running = true;
        if (view.sys) view.sys.collapse();
    }

    function toggleFavorite(romPath) {
        pFav.command = ["python3", view.scriptPath, "toggle_fav", romPath];
        pFav.running = false;
        pFav.running = true;
    }

    function openEmulatorApp(engineKey) {
        pCmd.command = ["python3", view.scriptPath, "open_engine", engineKey];
        pCmd.running = false;
        pCmd.running = true;
        if (view.sys) view.sys.collapse();
    }

    function openRomsFolder() {
        var dir = Quickshell.env("HOME") + "/ROMs";
        if (view.sys && view.sys.openFilesAt) {
            view.sys.openFilesAt(dir);
        }
    }

    function set3dsOption(key, val) {
        var next = Object.assign({}, view.cfg3ds);
        next[key] = val;
        view.cfg3ds = next;
        pCmd.command = ["python3", view.scriptPath, "set_3ds_config", String(key), String(val)];
        pCmd.running = false;
        pCmd.running = true;
    }

    function downloadHomebrew(itemId) {
        if (view.downloadingId.length > 0) return;
        view.downloadingId = itemId;
        pDownload.command = ["python3", view.scriptPath, "download_homebrew", itemId];
        pDownload.running = false;
        pDownload.running = true;
    }

    function moveSelection(delta) {
        if (view.filteredRoms.length === 0) return;
        view.selectedIndex = Math.max(0, Math.min(view.filteredRoms.length - 1, view.selectedIndex + delta));
        romList.positionViewAtIndex(view.selectedIndex, ListView.Contain);
    }

    function platformColor(plat) {
        if (plat === "GBA") return "#a855f7";
        if (plat === "NDS") return "#38bdf8";
        if (plat === "3DS") return "#f43f5e";
        return view.sys ? view.sys.colOn : "#ffffff";
    }

    function platformAppLabel(plat) {
        if (plat === "GBA") return "mGBA";
        if (plat === "NDS") return "melonDS";
        if (plat === "3DS") return "Azahar";
        return "App";
    }

    // ---------------------------------------------------------------- Processos
    Process {
        id: pFetch
        command: ["python3", view.scriptPath, "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                view.loading = false;
                try {
                    var d = JSON.parse(text.trim());
                    if (d.roms) view.roms = d.roms;
                    if (d.engines) view.engines = d.engines;
                    if (d.catalog) view.catalog = d.catalog;
                    if (d.state && d.state["3ds_config"]) view.cfg3ds = d.state["3ds_config"];
                } catch (e) {}
            }
        }
    }

    Process { id: pCmd }

    Process {
        id: pFav
        onExited: view.refreshAll()
    }

    Process {
        id: pDownload
        stdout: StdioCollector {
            onStreamFinished: {
                view.downloadingId = "";
                try {
                    var r = JSON.parse(text.trim());
                    if (r.ok) {
                        view.showToast(view.isPt ? "Jogo baixado em ~/ROMs!" : "Downloaded to ~/ROMs!");
                        view.refreshAll();
                    } else {
                        view.showToast(r.error || "Erro ao baixar");
                    }
                } catch (e) {
                    view.refreshAll();
                }
            }
        }
    }

    FocusGrabber { target: searchInput }

    // =========================================================================
    // Layout Principal
    // =========================================================================
    ColumnLayout {
        id: mainCol
        width: parent.width
        spacing: 10

        // ----------------------------------------------------------- Cabeçalho
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 9
                color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.togglePage("features")
                }
            }

            Text {
                text: "󰊗"
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 18 }
            }

            ColumnLayout {
                spacing: 0
                Text {
                    text: view.isPt ? "Biblioteca de Jogos" : "Game Library"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 14; bold: true }
                }
                Text {
                    text: view.roms.length + (view.isPt ? " jogos · abre direto no emulador" : " games · launches native app")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Item { Layout.fillWidth: true }

            // Atalhos rápidos para abrir os emuladores direto
            Repeater {
                model: [
                    { key: "mgba",    label: "GBA", col: "#a855f7", tip: "Abrir mGBA" },
                    { key: "melonds", label: "DS",  col: "#38bdf8", tip: "Abrir melonDS" },
                    { key: "azahar",  label: "3DS", col: "#f43f5e", tip: "Abrir Azahar 3DS" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: engText.implicitWidth + 14
                    implicitHeight: 26
                    radius: 7
                    color: engMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    RowLayout {
                        id: engText
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: modelData.col
                        }
                        Text {
                            text: modelData.label
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                    }

                    MouseArea {
                        id: engMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.openEmulatorApp(modelData.key)
                    }
                }
            }

            // Botão abrir pasta ~/ROMs
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: dirMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                Text {
                    anchors.centerIn: parent
                    text: "󰉋"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }
                MouseArea {
                    id: dirMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.openRomsFolder()
                }
            }

            // Botão atualizar biblioteca
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    color: view.loading ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }
                MouseArea {
                    id: refMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.refreshAll()
                }
            }
        }

        // ---------------------------------------------- Filtros de Plataforma
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: [
                    { id: "ALL", label: view.isPt ? "Todos" : "All", glyph: "󰊗" },
                    { id: "GBA", label: "GBA", glyph: "󰯙" },
                    { id: "NDS", label: "DS",  glyph: "󰓓" },
                    { id: "3DS", label: "3DS", glyph: "Glasses" },
                    { id: "FAV", label: "★",   glyph: "" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSel: view.activeTab === "library" && view.consoleFilter === modelData.id
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: filterLbl.implicitWidth + 18
                    radius: 8
                    color: isSel ? view.sys.colOn
                                 : (fltMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: filterLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        color: isSel ? "#111111" : view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 11; bold: isSel }
                    }

                    MouseArea {
                        id: fltMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.activeTab = "library";
                            view.consoleFilter = modelData.id;
                            view.selectedIndex = 0;
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Botão Loja Homebrew & Ajustes 3DS
            Rectangle {
                readonly property bool isStore: view.activeTab === "homebrew"
                Layout.preferredHeight: 28
                Layout.preferredWidth: storeLbl.implicitWidth + 18
                radius: 8
                color: isStore ? view.sys.colOn
                               : (storeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))

                Text {
                    id: storeLbl
                    anchors.centerIn: parent
                    text: view.isPt ? "󰏗 Homebrew & 3DS" : "󰏗 Homebrew & 3DS"
                    color: parent.isStore ? "#111111" : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11; bold: parent.isStore }
                }

                MouseArea {
                    id: storeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.activeTab = (view.activeTab === "homebrew" ? "library" : "homebrew")
                }
            }
        }

        // --------------------------------------------------- Barra de Pesquisa
        Rectangle {
            visible: view.activeTab === "library"
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 11
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: searchInput.activeFocus ? view.sys.colOn : view.sys.colLine
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "󰍉"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 14 }
                }

                TextField {
                    id: searchInput
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.isPt ? "Buscar jogo (Enter abre o jogo)…" : "Search game (Enter launches)…"
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 12 }
                    background: null
                    onTextChanged: {
                        view.searchQuery = text;
                        view.selectedIndex = 0;
                    }

                    Keys.onDownPressed: view.moveSelection(1)
                    Keys.onUpPressed: view.moveSelection(-1)
                    Keys.onReturnPressed: {
                        if (view.filteredRoms.length > 0)
                            view.launchGame(view.filteredRoms[view.selectedIndex], false);
                    }
                    Keys.onEnterPressed: {
                        if (view.filteredRoms.length > 0)
                            view.launchGame(view.filteredRoms[view.selectedIndex], false);
                    }
                    Keys.onEscapePressed: view.sys.collapse()
                }

                Text {
                    visible: view.searchQuery.length > 0
                    text: "󰅖"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        // ------------------------------------------------ Lista da Biblioteca
        Rectangle {
            visible: view.activeTab === "library"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Math.max(view.filteredRoms.length * 60 + 10, 140), 340)
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: view.sys.colLine
            border.width: 1
            clip: true

            ListView {
                id: romList
                anchors.fill: parent
                anchors.margins: 5
                model: view.filteredRoms
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: view.filteredRoms.length > 5 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    width: 4
                }

                delegate: Rectangle {
                    id: romCard
                    required property var modelData
                    required property int index
                    readonly property bool isSel: romCard.index === view.selectedIndex

                    width: romList.width
                    height: 56
                    radius: 10
                    color: isSel ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                 : (cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                    border.color: isSel ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Clique no card seleciona; duplo clique já abre o jogo
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.selectedIndex = romCard.index
                        onDoubleClicked: view.launchGame(romCard.modelData, false)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Ícone extraído da ROM (NDS/3DS/GBA)
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            clip: true

                            Image {
                                id: romIconImg
                                anchors.fill: parent
                                anchors.margins: 2
                                source: romCard.modelData.icon ? ("file://" + romCard.modelData.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: romIconImg.status !== Image.Ready
                                text: romCard.modelData.platform === "GBA" ? "󰯙"
                                    : romCard.modelData.platform === "NDS" ? "󰓓" : "󰊗"
                                color: view.platformColor(romCard.modelData.platform)
                                font { family: view.sys.fontFam; pixelSize: 18 }
                            }
                        }

                        // Nome e metadados
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // Badge do Console
                                Rectangle {
                                    implicitWidth: platTxt.implicitWidth + 10
                                    implicitHeight: 16
                                    radius: 4
                                    color: view.platformColor(romCard.modelData.platform)
                                    Text {
                                        id: platTxt
                                        anchors.centerIn: parent
                                        text: romCard.modelData.platform
                                        color: "#111111"
                                        font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: romCard.modelData.title
                                    color: view.sys.colFg
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: view.platformAppLabel(romCard.modelData.platform) + " · " + romCard.modelData.size_str + " · " + romCard.modelData.game_code
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }
                        }

                        // Favorito ★
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 7
                            color: favMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: romCard.modelData.favorite ? "★" : "☆"
                                color: romCard.modelData.favorite ? "#fbbf24" : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            MouseArea {
                                id: favMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.toggleFavorite(romCard.modelData.path)
                            }
                        }

                        // Abrir em Tela Cheia
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 7
                            color: fsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.05)
                            Text {
                                anchors.centerIn: parent
                                text: "󰊓"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }
                            MouseArea {
                                id: fsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.launchGame(romCard.modelData, true)
                            }
                        }

                        // Botão Jogar (Abre no App)
                        Rectangle {
                            implicitWidth: playRow.implicitWidth + 16
                            Layout.preferredHeight: 30
                            radius: 8
                            color: playMa.containsMouse ? Qt.lighter(view.sys.colOn, 1.15) : view.sys.colOn

                            RowLayout {
                                id: playRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "▶"
                                    color: "#111111"
                                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                }
                                Text {
                                    text: view.isPt ? "Jogar" : "Play"
                                    color: "#111111"
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                            }

                            MouseArea {
                                id: playMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.launchGame(romCard.modelData, false)
                            }
                        }
                    }
                }

                // Estado vazio
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: view.filteredRoms.length === 0 && !view.loading
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰊗"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 26 }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.isPt ? "Nenhum jogo encontrado" : "No games found"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.isPt ? "Coloque suas ROMs em ~/ROMs/{GBA,NDS,3DS}" : "Place ROMs in ~/ROMs/{GBA,NDS,3DS}"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 10 }
                    }
                }
            }
        }

        // --------------------------------------- Aba Homebrew & Ajustes do 3DS
        ColumnLayout {
            visible: view.activeTab === "homebrew"
            Layout.fillWidth: true
            spacing: 8

            // Config rápida do Azahar 3DS (Resolução e API Gráfica)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cfgCol.implicitHeight + 16
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    id: cfgCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: view.isPt ? "󰒓 Ajustes Rápidos do 3DS (Azahar)" : "󰒓 3DS Quick Config (Azahar)"
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (view.cfg3ds.graphics_api === 2 ? "Vulkan" : "OpenGL") + " · " + view.cfg3ds.resolution_factor + "x"
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: [
                                { val: 1, label: "1x" },
                                { val: 2, label: "2x (720p)" },
                                { val: 3, label: "3x (1080p)" },
                                { val: 4, label: "4x (1440p)" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool act: view.cfg3ds.resolution_factor === modelData.val
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 6
                                color: act ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.06)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: act ? "#111111" : view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 10; bold: act }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.set3dsOption("resolution_factor", modelData.val)
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: view.cfg3ds.graphics_api === 2 ? "Vulkan" : "OpenGL"
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.set3dsOption("graphics_api", view.cfg3ds.graphics_api === 2 ? 1 : 2)
                            }
                        }
                    }
                }
            }

            // Catálogo Homebrew gratuito para baixar com 1 clique
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 210
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.02)
                border.color: view.sys.colLine
                border.width: 1
                clip: true

                ListView {
                    id: catList
                    anchors.fill: parent
                    anchors.margins: 5
                    model: view.catalog
                    spacing: 4
                    clip: true

                    delegate: Rectangle {
                        required property var modelData
                        width: catList.width
                        height: 48
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.04)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 18
                                radius: 4
                                color: view.platformColor(modelData.platform)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.platform
                                    color: "#111111"
                                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: view.sys.colFg
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.desc
                                    color: view.sys.colMuted
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }

                            Rectangle {
                                implicitWidth: dlTxt.implicitWidth + 14
                                Layout.preferredHeight: 26
                                radius: 7
                                color: modelData.installed ? Qt.rgba(1, 1, 1, 0.08) : view.sys.colOn

                                Text {
                                    id: dlTxt
                                    anchors.centerIn: parent
                                    text: view.downloadingId === modelData.id ? "…"
                                        : modelData.installed ? (view.isPt ? "▶ Jogar" : "▶ Play")
                                        : (view.isPt ? "󰇚 Baixar" : "󰇚 Get")
                                    color: modelData.installed ? view.sys.colFg : "#111111"
                                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.installed && modelData.local_path) {
                                            view.launchGame({ path: modelData.local_path, platform: modelData.platform }, false);
                                        } else {
                                            view.downloadHomebrew(modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Toast de feedback se houver
        Text {
            visible: view.statusMsg.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: view.statusMsg
            color: view.sys.colOn
            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }
    }
}
