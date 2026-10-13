import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Cheat Sheet Nativo no Dynamic Island (tldr + cheat.sh)
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property string activeQuery: "docker"
    property string cmdDescription: ""
    property string cmdSource: ""
    property var examplesList: []
    property string errorMessage: ""
    property string copyToast: ""

    readonly property var popularChips: [
        "docker", "docker-compose", "tar", "git", "curl", "jq", "ssh", "rsync", "ffmpeg", "systemctl", "find"
    ]

    Process {
        id: pCheat
        stdout: SplitParser {
            onRead: text => {
                try {
                    var data = JSON.parse(text);
                    if (data.ok) {
                        view.cmdDescription = data.description || "";
                        view.cmdSource = data.source || "";
                        view.examplesList = data.examples || [];
                        view.errorMessage = "";
                    } else {
                        view.examplesList = [];
                        view.errorMessage = data.error || (view.sys.isPt ? "Nenhum exemplo encontrado" : "No examples found");
                    }
                } catch (e) {
                    view.errorMessage = view.sys.isPt ? "Erro ao ler resposta" : "Error reading response";
                }
            }
        }
    }

    Process { id: pCopy }
    Process { id: pPaste }

    function search(q) {
        var term = q.trim();
        if (!term.length) return;
        view.activeQuery = term;
        view.errorMessage = "";
        view.copyToast = "";
        pCheat.command = ["python3", view.sys.scriptDir + "/cheat_worker.py", term];
        pCheat.running = false;
        pCheat.running = true;
    }

    function copyCmd(cmd, andPaste) {
        if (!cmd.length) return;
        if (andPaste) {
            pPaste.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy && (sleep 0.15; command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k v -m ctrl) &", "_", cmd];
            pPaste.running = false;
            pPaste.running = true;
            view.sys.collapse();
        } else {
            pCopy.command = ["wl-copy", cmd];
            pCopy.running = false;
            pCopy.running = true;
            view.copyToast = (view.sys.isPt ? "Copiado: " : "Copied: ") + (cmd.length > 25 ? cmd.substring(0, 25) + "..." : cmd);
        }
    }

    Component.onCompleted: view.search("docker")
    FocusGrabber { target: searchInput }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ------------------------------------------------------------- Cabecalho

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: "󰞋"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: view.sys.isPt ? "Cheat Sheet de Comandos" : "Command Cheat Sheet"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                }

                Text {
                    text: view.cmdSource.length ? (view.cmdSource + " • " + view.activeQuery) : (view.sys.isPt ? "Sintaxe rápida sem anúncios" : "Quick clean syntax")
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
            }

            Text {
                text: view.copyToast
                visible: view.copyToast.length > 0
                color: view.sys.colOk
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 6
                color: cCloseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                MouseArea {
                    id: cCloseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.collapse()
                }
            }
        }

        // ------------------------------------------------------------- Search Field

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: searchInput.activeFocus ? view.sys.colOn : view.sys.colLine
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
                    id: searchInput
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.isPt ? "Buscar comando ou sintaxe (ex: docker, tar, git, python/for)..."
                                                   : "Search command or syntax (e.g. docker, tar, git, curl)..."
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    background: null
                    Keys.onEscapePressed: view.sys.collapse()
                    Keys.onReturnPressed: view.search(text)
                }

                Text {
                    text: "×"
                    visible: searchInput.text.length > 0
                    color: cMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2 }
                    MouseArea {
                        id: cMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                    }
                }
            }
        }

        // ------------------------------------------------------------- Chips / Quick Tips


        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            contentWidth: chipRow.width
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: chipRow
                spacing: 6

                Repeater {
                    model: view.popularChips
                    Rectangle {
                        height: 24
                        width: chipTxt.implicitWidth + 16
                        radius: 6
                        color: view.activeQuery === modelData
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                               : (chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: view.activeQuery === modelData ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Text {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: modelData
                            color: view.activeQuery === modelData ? "#ffffff" : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = modelData;
                                view.search(modelData);
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------- Command overview


        Text {
            Layout.fillWidth: true
            visible: view.cmdDescription.length > 0 && !pCheat.running
            text: view.cmdDescription
            color: view.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
        }

        // ------------------------------------------------------------- Loading / Erro
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 8
            visible: pCheat.running
            color: Qt.rgba(1, 1, 1, 0.03)

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "󱑒"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
                    RotationAnimation on rotation {
                        running: pCheat.running
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }
                }
                Text {
                    text: view.sys.isPt ? "Consultando sintaxe..." : "Fetching syntax..."
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 8
            visible: view.errorMessage.length > 0 && !pCheat.running
            color: Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.15)
            border.color: view.sys.colCrit
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Text { text: "󰅖"; color: view.sys.colCrit; font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 } }
                Text { text: view.errorMessage; color: view.sys.colCrit; Layout.fillWidth: true; elide: Text.ElideRight; font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 } }
            }
        }

        // ------------------------------------------------------------- List of Examples

        ListView {
            id: exList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 330)
            clip: true
            model: view.examplesList
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: exCard
                width: exList.width
                height: cardCol.implicitHeight + 16
                radius: 10
                color: itemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.color: itemMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40) : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    id: cardCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: modelData.desc || ""
                        color: view.sys.colMuted
                        elide: Text.ElideRight
                        font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.35)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: "$ "
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.cmd || ""
                                color: "#93c5fd"
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }

                            Text {
                                text: "󰅍"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                            }
                        }
                    }
                }

                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            view.copyCmd(modelData.cmd, false);
                        } else {
                            view.copyCmd(modelData.cmd, true);
                        }
                    }
                }
            }
        }
    }
}
