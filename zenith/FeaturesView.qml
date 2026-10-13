import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// FeaturesView: Exclusive search engine for the system’s customized tools and features

FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight
    property string query: ""
    property int index: 0
    readonly property int maxRows: 7

    function focusInput() {
        input.forceActiveFocus();
    }

    readonly property var allFeatures: [
        {
            id: "docker",
            name: "Docker Manager",
            desc: (view.sys && view.sys.isPt) ? "Containers, imagens e logs do Docker" : "Docker containers, images and logs",
            glyph: "󰡨",
            shortcut: "SUPER + D",
            keys: "docker containers container compose imagens images podman"
        },
        {
            id: "calc",
            name: (view.sys && view.sys.isPt) ? "Calculadora" : "Calculator",
            desc: (view.sys && view.sys.isPt) ? "Cálculos matemáticos e conversor rápido" : "Math calculations and quick converter",
            glyph: "󰪚",
            shortcut: "SUPER + C",
            keys: "calc calculadora conta math somar multiplicar dividir conversao"
        },
        {
            id: "terminals",
            name: (view.sys && view.sys.isPt) ? "Terminais em Segundo Plano" : "Background Terminals",
            desc: (view.sys && view.sys.isPt) ? "Processos e comandos persistentes de fundo" : "Persistent background terminal commands",
            glyph: "󰆍",
            shortcut: "SUPER + SHIFT + Return",
            keys: "terminals terminal background runner tarefas processos comandos runner fundo"
        },
        {
            id: "tasks",
            name: (view.sys && view.sys.isPt) ? "Gerenciador de Tarefas" : "Task Manager",
            desc: (view.sys && view.sys.isPt) ? "Monitor de CPU, RAM e processos ativos" : "CPU, RAM and system process monitor",
            glyph: "󰇄",
            shortcut: "CTRL + SHIFT + Esc",
            keys: "task manager gerenciador de tarefas processos process monitor cpu ram memoria top htop btop"
        },
        {
            id: "regex",
            name: (view.sys && view.sys.isPt) ? "Gerador de Regex (IA)" : "Regex Generator (AI)",
            desc: (view.sys && view.sys.isPt) ? "Criação, explicação e teste de expressões regulares" : "AI regular expression generator and tester",
            glyph: "󰘦",
            shortcut: "SUPER + R",
            keys: "regex gerador regular expression regex ia ai pattern expressao"
        },
        {
            id: "picker",
            name: (view.sys && view.sys.isPt) ? "Seletor de Cores & Ícones" : "Color & Icon Picker",
            desc: (view.sys && view.sys.isPt) ? "Conta-gotas de tela e busca de ícones Nerd Font" : "Screen color picker & Nerd Font icon search",
            glyph: "󰏘",
            shortcut: "SUPER + .",
            keys: "picker cor color hex rgb icon icone nerd font conta gotas"
        },
        {
            id: "cheat",
            name: "Cheat Sheet & TLDR",
            desc: (view.sys && view.sys.isPt) ? "Comandos rápidos, cheatsheet e manuais tldr" : "Quick command cheatsheet and tldr docs",
            glyph: "󱓷",
            shortcut: "SUPER + SHIFT + C",
            keys: "cheat sheet tldr docs comandos linux bash git docker curl"
        },
        {
            id: "vault",
            name: (view.sys && view.sys.isPt) ? "Cofre de Senhas & TOTP" : "Password Vault & TOTP",
            desc: (view.sys && view.sys.isPt) ? "Gerenciador de senhas e autenticação de 2 fatores" : "Password manager and 2-factor TOTP codes",
            glyph: "󰌆",
            shortcut: "SUPER + SHIFT + P",
            keys: "vault cofre senhas password totp 2fa auth seguranca"
        },
        {
            id: "agents",
            name: (view.sys && view.sys.isPt) ? "Agentes de IA & Limites" : "AI Agents & Quotas",
            desc: (view.sys && view.sys.isPt) ? "Planos e consumo do Claude, Antigravity (AGY), Codex" : "Plans and limits of installed AI agents",
            glyph: "󰚩",
            shortcut: "SUPER + G",
            keys: "agents agent ai claude codex agy antigravity gemini copilot cursor limits"
        },
        {
            id: "weather",
            name: (view.sys && view.sys.isPt) ? "Previsão do Tempo" : "Weather Forecast",
            desc: (view.sys && view.sys.isPt) ? "Clima atual, temperatura, vento e chuva" : "Current weather, temperature, wind and rain",
            glyph: "󰖐",
            shortcut: "",
            keys: "weather tempo clima temperatura previsao chuva"
        },
        {
            id: "cal",
            name: (view.sys && view.sys.isPt) ? "Calendário & Agenda" : "Calendar & Agenda",
            desc: (view.sys && view.sys.isPt) ? "Mês atual, compromissos e datas" : "Monthly calendar and events",
            glyph: "󰸗",
            shortcut: "",
            keys: "calendar cal calendario data mes agenda dia"
        },
        {
            id: "profile",
            name: "GitHub Profile & Status",
            desc: (view.sys && view.sys.isPt) ? "Dashboard, contribuições e updates" : "GitHub profile dashboard, heatmap and updates",
            glyph: "󰊤",
            shortcut: "SUPER + SHIFT + U",
            keys: "github profile status updates contributions heatmap"
        },
        {
            id: "gamemode",
            name: (view.sys && view.sys.isPt) ? "Modo Gaming" : "Gaming Mode",
            desc: (view.sys && view.sys.isPt) ? "Desempenho máximo, tearing e foco no jogo" : "Maximum performance, tearing and focus on game",
            glyph: "󰊖",
            shortcut: "SUPER + SHIFT + G",
            keys: "gaming game jogo modo gamemode performance fps tearing otimizacao foco"
        }
    ]

    readonly property var results: {
        var q = view.query.trim().toLowerCase();
        if (q.length === 0) return view.allFeatures;
        return view.allFeatures.filter(function(item) {
            return item.name.toLowerCase().indexOf(q) >= 0
                || item.desc.toLowerCase().indexOf(q) >= 0
                || item.keys.toLowerCase().indexOf(q) >= 0;
        });
    }

    onResultsChanged: {
        if (view.index >= view.results.length) view.index = Math.max(0, view.results.length - 1);
    }

    function openItem(item) {
        if (!item) return;
        if (item.id === "gamemode") {
            view.sys.toggleGameMode();
            return;
        }
        view.sys.togglePage(item.id);
    }

    function launch() {
        if (view.results.length === 0) return;
        var item = view.results[view.index];
        view.openItem(item);
    }

    function move(delta) {
        if (view.results.length === 0) return;
        view.index = Math.max(0, Math.min(view.results.length - 1, view.index + delta));
        list.positionViewAtIndex(view.index, ListView.Contain);
    }

    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------ Search Bar

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 13
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: input.activeFocus ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 9

                Text {
                    text: "󰍉"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                TextField {
                    id: input
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: (view.sys && view.sys.isPt) ? "Pesquisar ferramentas e recursos…" : "Search system features…"
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 13 }
                    background: null
                    onTextChanged: view.query = text

                    Keys.onDownPressed:   view.move(1)
                    Keys.onUpPressed:     view.move(-1)
                    Keys.onReturnPressed: view.launch()
                    Keys.onEnterPressed:  view.launch()
                    Keys.onEscapePressed: view.sys.collapse()
                    Keys.onTabPressed:    view.move(1)
                }

                Text {
                    visible: view.results.length > 0
                    text: view.results.length + " / " + view.allFeatures.length
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // ------------------------------------------------------------ Lista de Recursos
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(view.results.length * 48 + 8, view.maxRows * 48 + 8)
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.02)
            border.color: view.sys.colLine
            border.width: 1
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 4
                model: view.results
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: view.results.length > view.maxRows ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    width: 4
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isSel: row.index === view.index

                    width: list.width
                    height: 44
                    radius: 9
                    color: isSel ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                 : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Resource icon


                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 8
                            color: row.isSel ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.glyph
                                color: row.isSel ? "#ffffff" : view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 15 }
                            }
                        }

                        // Name and description


                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: row.isSel ? "#ffffff" : view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: row.isSel }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.desc
                                color: row.isSel ? Qt.rgba(1, 1, 1, 0.8) : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                        }

                        // Keyboard shortcut

                        Rectangle {
                            visible: row.modelData.shortcut && row.modelData.shortcut.length > 0
                            implicitWidth: scText.implicitWidth + 12
                            implicitHeight: 20
                            radius: 5
                            color: Qt.rgba(1, 1, 1, row.isSel ? 0.20 : 0.06)

                            Text {
                                id: scText
                                anchors.centerIn: parent
                                text: row.modelData.shortcut
                                color: row.isSel ? "#ffffff" : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.index = row.index;
                            view.openItem(row.modelData);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: view.results.length === 0
                    text: (view.sys && view.sys.isPt) ? "Nenhum recurso encontrado" : "No features found"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }
            }
        }
    }
}
