import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Regular Expression Generator with Local AI (Ollama)


// Natively integrated into the Capsule (Dynamic Island)


FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property string generatedRegex: ""
    property var isMatched: null
    property string errorMessage: ""
    property string copyToast: ""

    Process {
        id: pGen
        stdout: SplitParser {
            onRead: text => {
                try {
                    var data = JSON.parse(text);
                    if (data.ok) {
                        view.generatedRegex = data.regex;
                        view.isMatched = data.matched;
                        view.errorMessage = "";
                        // Auto-copy to clipboard

                        pCopyDirect.command = ["wl-copy", data.regex];
                        pCopyDirect.running = true;
                        view.copyToast = view.sys.isPt ? "Copiado para o clipboard!" : "Copied to clipboard!";
                    } else {
                        view.errorMessage = data.error || (view.sys.isPt ? "Erro desconhecido na geração" : "Unknown generation error");
                    }
                } catch (e) {
                    view.errorMessage = view.sys.isPt ? "Resposta inválida do modelo" : "Invalid model response";
                }
            }
        }
    }

    Process { id: pCopyDirect }
    Process { id: pPaste }

    function generate() {
        if (!descInput.text.trim().length) return;
        view.errorMessage = "";
        view.generatedRegex = "";
        view.isMatched = null;
        view.copyToast = "";
        pGen.command = ["python3", view.sys.scriptDir + "/regex_worker.py", descInput.text.trim(), sampleInput.text.trim()];
        pGen.running = false;
        pGen.running = true;
    }

    function copyAndClose(autoPaste) {
        if (!view.generatedRegex.length) return;
        var r = view.generatedRegex;
        if (autoPaste) {
            pPaste.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy && (sleep 0.15; command -v wtype >/dev/null 2>&1 && wtype -M ctrl -k v -m ctrl) &", "_", r];
            pPaste.running = false;
            pPaste.running = true;
            view.sys.collapse();
        } else {
            pCopyDirect.command = ["wl-copy", r];
            pCopyDirect.running = false;
            pCopyDirect.running = true;
            view.copyToast = view.sys.isPt ? "Regex copiado!" : "Regex copied!";
        }
    }

    FocusGrabber { target: descInput }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ------------------------------------------------------------- Cabecalho

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 28; height: 28; radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: "󰘦"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: view.sys.isPt ? "Gerador de Regex (IA Local)" : "Regex Generator (Local AI)"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                }

                Text {
                    text: view.sys.isPt ? "qwen2.5-coder:7b • Ollama" : "qwen2.5-coder:7b • Ollama"
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                }
            }

            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: 26
                radius: 6
                color: rCloseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                MouseArea {
                    id: rCloseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.collapse()
                }
            }
        }

        // ------------------------------------------------------------- Campo 1: O que capturar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: descInput.activeFocus ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "󰘦"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                }

                TextField {
                    id: descInput
                    focus: true
                    Layout.fillWidth: true
                    placeholderText: view.sys.isPt ? "Descreva o que capturar (ex: telefone com DDD, email, hash)..."
                                                   : "Describe what to match (e.g. phone with area code, email)..."
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    background: null
                    Keys.onEscapePressed: view.sys.collapse()
                    Keys.onReturnPressed: {
                        if (sampleInput.text.length > 0 || !descInput.text.length) {
                            view.generate();
                        } else {
                            sampleInput.forceActiveFocus();
                        }
                    }
                }

                Text {
                    text: "×"
                    visible: descInput.text.length > 0
                    color: cMa1.containsMouse ? view.sys.colCrit : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2 }
                    MouseArea {
                        id: cMa1
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: descInput.text = ""
                    }
                }
            }
        }

        // ------------------------------------------------------------- Campo 2: Texto de teste
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: sampleInput.activeFocus ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "󰈙"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                }

                TextField {
                    id: sampleInput
                    Layout.fillWidth: true
                    placeholderText: view.sys.isPt ? "Texto de teste opcional (ex: (11) 98765-4321)..."
                                                   : "Optional test sample (e.g. (11) 98765-4321)..."
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    background: null
                    Keys.onEscapePressed: view.sys.collapse()
                    Keys.onReturnPressed: view.generate()
                }

                Text {
                    text: "×"
                    visible: sampleInput.text.length > 0
                    color: cMa2.containsMouse ? view.sys.colCrit : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2 }
                    MouseArea {
                        id: cMa2
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sampleInput.text = ""
                    }
                }
            }
        }

        // ------------------------------------------------------------- Generate/Loading button


        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 10
                color: pGen.running ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                    : (btnMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.90)
                                                           : view.sys.colOn)
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: pGen.running ? "󱑒" : "󰐊"
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                        RotationAnimation on rotation {
                            running: pGen.running
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }

                    Text {
                        text: pGen.running ? (view.sys.isPt ? "Gerando com IA local..." : "Generating with local AI...")
                                           : (view.sys.isPt ? "Gerar Regex" : "Generate Regex")
                        color: "#ffffff"
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                    }
                }

                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !pGen.running
                    onClicked: view.generate()
                }
            }
        }

        // ------------------------------------------------------------- Mensagem de Erro
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 8
            visible: view.errorMessage.length > 0
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

        // ------------------------------------------------------------- Card de Resultado
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.generatedRegex.length > 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.35)
                border.color: view.isMatched === true ? view.sys.colOk
                             : view.isMatched === false ? view.sys.colCrit
                             : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.50)
                border.width: 1.5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: view.isMatched === true ? (view.sys.isPt ? "󰄬 Match confirmado no teste!" : "󰄬 Match confirmed in sample!")
                                : view.isMatched === false ? (view.sys.isPt ? "󰀦 Atenção: Não casou com o texto de teste" : "󰀦 Warning: Did not match sample")
                                : (view.sys.isPt ? "Expressão Regular:" : "Regular Expression:")
                            color: view.isMatched === true ? view.sys.colOk
                                 : view.isMatched === false ? "#f59e0b"
                                 : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: view.copyToast.length ? view.copyToast : (view.sys.isPt ? "Clique para copiar" : "Click to copy")
                            color: view.copyToast.length ? view.sys.colOk : view.sys.colMuted
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 4 }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: view.generatedRegex
                        color: "#60a5fa"
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.copyAndClose(false)
                }
            }

            // Quick copy actions


            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: view.sys.colLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰅍"; color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 } }
                        Text { text: view.sys.isPt ? "Copiar Regex" : "Copy Regex"; color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true } }
                    }
                    MouseArea {
                        id: copyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.copyAndClose(false)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 8
                    color: pasteMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.30)
                                                 : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.18)
                    border.color: view.sys.colOk
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰆏"; color: view.sys.colOk; font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 } }
                        Text { text: view.sys.isPt ? "Colar no Editor" : "Paste in Editor"; color: view.sys.colOk; font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true } }
                    }
                    MouseArea {
                        id: pasteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.copyAndClose(true)
                    }
                }
            }
        }
    }
}
