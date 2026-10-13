import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Seletor Local Nativo no Dynamic Island:
// - Hex screen colors (hyprpicker)

// - Emojis rendered in high definition vector SVG


// - Developer Glyphs and Icons (NerdFont)


FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    // Abas: "emojis" | "colors" | "nerd"
    property string activeTab: "emojis"
    property string searchQuery: ""
    property var allEmojis: []
    property var recentColors: []
    property string toastText: ""

    onActiveTabChanged: view.sys.hideTip()
    onSearchQueryChanged: view.sys.hideTip()
    Component.onDestruction: view.sys.hideTip()

    readonly property var presetColors: [
        "#3b82f6", "#2563eb", "#1d4ed8", "#60a5fa",
        "#8b5cf6", "#7c3aed", "#a855f7", "#c084fc",
        "#ec4899", "#f43f5e", "#ef4444", "#f97316",
        "#eab308", "#84cc16", "#10b981", "#06b6d4",
        "#0f172a", "#1e293b", "#334155", "#64748b",
        "#f8fafc", "#e2e8f0", "#94a3b8", "#475569"
    ]

    readonly property var allNerdIcons: [
        { glyph: "", name: "Docker", tag: "container podman devops infra" },
        { glyph: "󰊢", name: "Git Branch", tag: "branch git commit repo code" },
        { glyph: "", name: "GitHub", tag: "github git pull issue octocat" },
        { glyph: "", name: "GitLab", tag: "gitlab ci cd devops" },
        { glyph: "󱄅", name: "NixOS", tag: "nix flake nixpkgs linux" },
        { glyph: "", name: "Arch Linux", tag: "arch linux pacman aur" },
        { glyph: "", name: "Debian", tag: "debian ubuntu apt deb" },
        { glyph: "", name: "Apple", tag: "macos ios mac apple" },
        { glyph: "", name: "Windows", tag: "win win32 microsoft windows" },
        { glyph: "", name: "Terminal", tag: "shell bash fish zsh cli prompt console" },
        { glyph: "󰘦", name: "Code Braces", tag: "syntax code dev prog chaves" },
        { glyph: "", name: "Python", tag: "python py django flask fastapi" },
        { glyph: "", name: "Rust", tag: "rust cargo crate rustc" },
        { glyph: "", name: "JavaScript", tag: "js javascript node web es6" },
        { glyph: "", name: "TypeScript", tag: "ts typescript types web" },
        { glyph: "", name: "Lua", tag: "lua neovim config nvim" },
        { glyph: "", name: "NodeJS", tag: "node npm npx backend" },
        { glyph: "", name: "React", tag: "react jsx tsx components" },
        { glyph: "", name: "Vue", tag: "vue vuejs front frontend" },
        { glyph: "", name: "C++", tag: "cpp clang gcc cplusplus" },
        { glyph: "", name: "C", tag: "c clang gcc kernel linux" },
        { glyph: "", name: "Java", tag: "jvm java spring gradle maven" },
        { glyph: "", name: "Go", tag: "golang go goroutine google" },
        { glyph: "", name: "Linux Tux", tag: "tux kernel gnu linux os" },
        { glyph: "", name: "Neovim", tag: "nvim vim editor terminal" },
        { glyph: "󰙅", name: "Database", tag: "sql postgres mysql redis banco de dados" },
        { glyph: "󰒋", name: "Server", tag: "cloud host vps servidor maquina" },
        { glyph: "󰉋", name: "Folder", tag: "pasta directory path diretorio" },
        { glyph: "󰈙", name: "File", tag: "arquivo documento doc text log" },
        { glyph: "󰛄", name: "Search", tag: "lupa buscar find query procurar" },
        { glyph: "󰅐", name: "Clock", tag: "relogio time timer data hora tempo" },
        { glyph: "󰄬", name: "Check", tag: "ok feito sucesso sim certo checkmark" },
        { glyph: "󰅖", name: "Close", tag: "fechar cancelar x nao erro excluir" },
        { glyph: "󰚌", name: "Wrench", tag: "ajuste config tool ferramenta chave" },
        { glyph: "󰋜", name: "Home", tag: "inicio casa root principal" },
        { glyph: "󰍹", name: "Monitor", tag: "tela display video resolucao monitor" },
        { glyph: "󰌌", name: "Keyboard", tag: "teclado key shortcut atalho teclas" },
        { glyph: "󰖩", name: "Wi-Fi", tag: "wifi internet rede wireless conexao" },
        { glyph: "󰂯", name: "Bluetooth", tag: "bt fone wireless sem fio conexao" },
        { glyph: "󰁹", name: "Battery", tag: "bateria carga energia porcentagem" },
        { glyph: "󰋑", name: "Heart", tag: "coracao amor favorito like vida" },
        { glyph: "󰋞", name: "Star", tag: "estrela destaque favorito nota avaliacao" },
        { glyph: "󰞋", name: "Help", tag: "ajuda duvida info interrogacao" },
        { glyph: "󰀝", name: "Rocket", tag: "foguete deploy turbo acelerar" },
        { glyph: "󰒲", name: "Sleep", tag: "dormir soneca pause suspensao zzz" },
        { glyph: "󰐊", name: "Play", tag: "executar tocar iniciar rodar play" },
        { glyph: "󰓛", name: "Stop", tag: "parar encerrar abortar stop" }
    ]

    // SVG Emoji Catalog Reader


    FileView {
        id: emojiFile
        path: Quickshell.env("HOME") + "/.config/zenith/assets/emojis.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                var txt = String(emojiFile.text()).trim();
                view.allEmojis = txt.length ? JSON.parse(txt) : [];
            } catch (e) {
                view.allEmojis = [];
            }
        }
    }

    // hyprpicker color history reader


    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.cache/zenith/colors.txt"
        watchChanges: true
        printErrors: false
        onLoaded: {
            var txt = String(colorsFile.text()).trim();
            view.recentColors = txt.length ? txt.split("\n").filter(function(c) { return c.trim().length > 0; }) : [];
        }
    }

    Process { id: pColorPicker; command: ["bash", view.sys.scriptDir + "/pick_color.sh"] }
    Process { id: pCopy }
    Process { id: pPaste }

    function pickColorFromScreen() {
        view.sys.collapse();
        pColorPicker.running = false;
        pColorPicker.running = true;
    }

    function copyAndPaste(val, label) {
        if (!val || !val.length) return;
        pPaste.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy && (sleep 0.15; command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k v -m ctrl) &", "_", val];
        pPaste.running = false;
        pPaste.running = true;
        view.sys.collapse();
    }

    function copyOnly(val, label) {
        if (!val || !val.length) return;
        pCopy.command = ["wl-copy", val];
        pCopy.running = false;
        pCopy.running = true;
        view.toastText = (view.sys.isPt ? "Copiado: " : "Copied: ") + val;
    }

    readonly property var filteredEmojis: {
        if (!view.allEmojis) return [];
        var q = view.searchQuery.toLowerCase().trim();
        if (!q.length) return view.allEmojis;
        return view.allEmojis.filter(function(item) {
            return (item.name && item.name.toLowerCase().indexOf(q) >= 0) ||
                   (item.tags && item.tags.toLowerCase().indexOf(q) >= 0) ||
                   (item.char && item.char.indexOf(q) >= 0);
        });
    }

    readonly property var filteredNerdIcons: {
        var q = view.searchQuery.toLowerCase().trim();
        if (!q.length) return view.allNerdIcons;
        return view.allNerdIcons.filter(function(item) {
            return (item.name && item.name.toLowerCase().indexOf(q) >= 0) ||
                   (item.tag && item.tag.toLowerCase().indexOf(q) >= 0);
        });
    }

    FocusGrabber { target: searchField }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------- Header & Tabs


        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: "󰏘"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
                }
            }

            Text {
                text: view.sys.isPt ? "Seletor Local" : "Local Picker"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
            }

            Item { Layout.fillWidth: true }

            // Abas
            RowLayout {
                spacing: 4

                component TabBtn: Rectangle {
                    id: tBtn
                    property string tabId: ""
                    property string tabLabel: ""
                    property string tabIcon: ""
                    readonly property bool active: view.activeTab === tabId

                    height: 26
                    width: tRow.implicitWidth + 16
                    radius: 7
                    color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                  : (tMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                    border.color: active ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: tRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: tBtn.tabIcon
                            color: tBtn.active ? "#ffffff" : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                        Text {
                            text: tBtn.tabLabel
                            color: tBtn.active ? "#ffffff" : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: tBtn.active }
                        }
                    }

                    MouseArea {
                        id: tMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.activeTab = tBtn.tabId
                    }
                }

                TabBtn { tabId: "emojis"; tabIcon: "󰞅"; tabLabel: "Emojis (SVG)" }
                TabBtn { tabId: "colors"; tabIcon: "󰏘"; tabLabel: view.sys.isPt ? "Cores" : "Colors" }
                TabBtn { tabId: "nerd";   tabIcon: "󰞋"; tabLabel: "NerdFont" }

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 6
                    color: pCloseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                    }
                    MouseArea {
                        id: pCloseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.collapse()
                    }
                }
            }
        }

        // ------------------------------------------------------------- Search Field (for Emojis and NerdFont)

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            visible: view.activeTab !== "colors"
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: searchField.activeFocus ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "󰛄"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: view.activeTab === "emojis"
                                     ? (view.sys.isPt ? "Buscar emoji por nome, tag ou reação (ex: fogo, foguete, bug, joinha)..."
                                                      : "Search emoji by name or tag...")
                                     : (view.sys.isPt ? "Buscar ícone NerdFont (ex: docker, git, rust, terminal, pasta)..."
                                                      : "Search NerdFont icon...")
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    background: null
                    onTextEdited: view.searchQuery = text
                    Keys.onEscapePressed: view.sys.collapse()
                }

                Text {
                    text: "×"
                    visible: searchField.text.length > 0
                    color: cMaS.containsMouse ? view.sys.colCrit : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2 }
                    MouseArea {
                        id: cMaS
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { searchField.text = ""; view.searchQuery = ""; }
                    }
                }
            }
        }

        // ------------------------------------------------------------- Toast informativo
        Text {
            Layout.fillWidth: true
            visible: view.toastText.length > 0
            text: view.toastText
            color: view.sys.colOk
            horizontalAlignment: Text.AlignRight
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
        }

        // ============================================================= TAB 1: EMOJIS (WITH SVGs)

        ColumnLayout {
            Layout.fillWidth: true
            visible: view.activeTab === "emojis"
            spacing: 8

            GridView {
                id: emojiGrid
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(320, Math.ceil(view.filteredEmojis.length / 8) * 44)
                cellWidth: Math.floor(width / 8)
                cellHeight: 44
                clip: true
                model: view.filteredEmojis
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: emojiGrid.cellWidth - 4
                    height: 40
                    radius: 8
                    color: eMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.30)
                                             : Qt.rgba(1, 1, 1, 0.04)
                    border.color: eMa.containsMouse ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Image {
                        id: svgImg
                        anchors.centerIn: parent
                        width: 24; height: 24
                        sourceSize: Qt.size(48, 48)
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        source: "file://" + Quickshell.env("HOME") + "/.config/zenith/" + modelData.svg
                    }

                    // Fallback to unicode character if SVG fails

                    Text {
                        anchors.centerIn: parent
                        visible: svgImg.status !== Image.Ready
                        text: modelData.char || ""
                        font { pixelSize: 20 }
                    }

                    MouseArea {
                        id: eMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        readonly property string tipName: (modelData.name || "") + " (" + (modelData.char || "") + ")"
                        onEntered: {
                            var pt = eMa.mapToItem(null, 0, 0);
                            view.sys.showTip(tipName, pt.x, pt.y);
                        }
                        onExited: view.sys.hideTip(tipName)
                        onClicked: mouse => {
                            view.sys.hideTip();
                            if (mouse.button === Qt.RightButton) {
                                view.copyOnly(modelData.char, "Emoji");
                            } else {
                                view.copyAndPaste(modelData.char, "Emoji");
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (view.filteredEmojis.length) + (view.sys.isPt ? " emojis vetoriais (SVG)" : " vector SVGs")
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: view.sys.isPt ? "Clique: cola • Direito: só copia" : "Click: paste • Right click: copy"
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }

        // ============================================================= TAB 2: COLORS (COLOR PICKER)

        ColumnLayout {
            Layout.fillWidth: true
            visible: view.activeTab === "colors"
            spacing: 12

            // Main Screenshot Button


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 12
                color: pickScreenMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                                  : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                border.color: view.sys.colOn
                border.width: 1.5
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "󰏘"
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize + 2 }
                    }

                    Text {
                        text: view.sys.isPt ? "Capturar Cor da Tela (Conta-gotas Hyprpicker)"
                                           : "Pick Color from Screen (Hyprpicker Eyedropper)"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                    }
                }

                MouseArea {
                    id: pickScreenMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.pickColorFromScreen()
                }
            }

            // History of recently captured colors


            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: view.recentColors.length > 0

                Text {
                    text: view.sys.isPt ? "Cores Recentes:" : "Recent Colors:"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: view.recentColors.slice(0, 14)
                        Rectangle {
                            height: 32
                            width: 110
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: rColMa.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Rectangle {
                                    width: 22; height: 22; radius: 6
                                    color: modelData
                                    border.color: Qt.rgba(1, 1, 1, 0.20)
                                    border.width: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                                }
                            }

                            MouseArea {
                                id: rColMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyAndPaste(modelData, "Cor")
                            }
                        }
                    }
                }
            }

            // Development color pattern palette


            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: view.sys.isPt ? "Paleta Rápida (Hex):" : "Quick Palette (Hex):"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                }

                GridView {
                    id: presetGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    cellWidth: Math.floor(width / 12)
                    cellHeight: 32
                    model: view.presetColors
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: presetGrid.cellWidth - 4
                        height: 28
                        radius: 6
                        color: modelData
                        border.color: pMa.containsMouse ? "#ffffff" : Qt.rgba(0, 0, 0, 0.30)
                        border.width: pMa.containsMouse ? 2 : 1

                        MouseArea {
                            id: pMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.copyAndPaste(modelData, "Cor")
                        }
                    }
                }
            }
        }

        // ============================================================= ABA 3: NERD FONT & ICONS
        ColumnLayout {
            Layout.fillWidth: true
            visible: view.activeTab === "nerd"
            spacing: 8

            GridView {
                id: nerdGrid
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(320, Math.ceil(view.filteredNerdIcons.length / 4) * 44)
                cellWidth: Math.floor(width / 4)
                cellHeight: 44
                clip: true
                model: view.filteredNerdIcons
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: nerdGrid.cellWidth - 4
                    height: 40
                    radius: 8
                    color: nMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.30)
                                             : Qt.rgba(1, 1, 1, 0.04)
                    border.color: nMa.containsMouse ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: modelData.glyph || ""
                            color: nMa.containsMouse ? "#ffffff" : view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize + 2 }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                    }

                    MouseArea {
                        id: nMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                view.copyOnly(modelData.glyph, "Ícone");
                            } else {
                                view.copyAndPaste(modelData.glyph, "Ícone");
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (view.filteredNerdIcons.length) + (view.sys.isPt ? " ícones e glifos NerdFont" : " NerdFont glyphs")
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: view.sys.isPt ? "Clique: cola • Direito: só copia" : "Click: paste • Right click: copy"
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }
    }
}
