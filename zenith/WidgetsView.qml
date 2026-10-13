import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Widgets de Área de Trabalho Premium no estilo Nothing OS / Cyberpunk Bento-Grid
// Design futurista, ultra-funcional e interativo:
// 1. Relógio Master & Calendário (Digital Dot-Matrix / Dial Analógico Nothing OS)
// 2. Bento Duplo: Previsão do Tempo em Tempo Real + Telemetria de Hardware (CPU/RAM/SSD)
// 3. Cyber Media Player Dinâmico (Capa, Equalizador animado, Controles) / Atalhos Rápidos
// 4. Barra de Progresso do Dia (24h) & Ano (365d) com cálculo exato e sem bugs
Item {
    id: view

    property var sys

    // Geometria Bento-Grid
    readonly property real col: 168
    readonly property real gap: 12
    readonly property real fullW: view.col * 2 + view.gap

    implicitWidth: view.fullW
    implicitHeight: stack.implicitHeight

    // Modos dos widgets (persistem nas configurações)
    readonly property string clockMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetClockMode)
                                        ? view.sys.cfg.widgetClockMode : "digital"
    readonly property string rightMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetRightMode)
                                        ? view.sys.cfg.widgetRightMode : "system"
    readonly property string progressMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetProgressMode)
                                           ? view.sys.cfg.widgetProgressMode : "day"
    readonly property bool isPt: view.sys ? view.sys.isPt : true

    // Estado do relógio em tempo real
    property var now: new Date()
    property real animPhase: 0.0
    property real pulseOpacity: 1.0

    Timer {
        interval: 1000
        repeat: true
        running: view.visible
        triggeredOnStart: true
        onTriggered: {
            view.now = new Date();
            if (view.clockMode === "analog" && typeof clockCanvas !== "undefined") {
                clockCanvas.requestPaint();
            }
        }
    }

    Timer {
        interval: 60
        repeat: true
        running: view.visible && (view.sys && view.sys.player && view.sys.player.isPlaying)
        onTriggered: view.animPhase += 0.35
    }

    SequentialAnimation on pulseOpacity {
        loops: Animation.Infinite
        running: view.visible
        NumberAnimation { from: 0.40; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.40; duration: 900; easing.type: Easing.InOutSine }
    }

    // Variáveis de tempo e calendário
    readonly property int curHours: view.now.getHours()
    readonly property int curMinutes: view.now.getMinutes()
    readonly property int curSeconds: view.now.getSeconds()
    readonly property int curDay: view.now.getDate()
    readonly property int curMonthIdx: view.now.getMonth()
    readonly property int curYear: view.now.getFullYear()
    readonly property int curDayOfWeek: view.now.getDay()

    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    readonly property string timeStr: pad2(curHours) + ":" + pad2(curMinutes)
    readonly property string secStr: pad2(curSeconds)

    readonly property var dayNamesPt: ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
    readonly property var dayShortPt: ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"]
    readonly property var monthNamesPt: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var monthShortPt: ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"]

    readonly property string dayNameFull: isPt ? dayNamesPt[curDayOfWeek] : (view.sys ? view.sys.dayText : "")
    readonly property string dayShort: isPt ? dayShortPt[curDayOfWeek] : (view.sys ? view.sys.dayText : "")
    readonly property string monthNameFull: isPt ? monthNamesPt[curMonthIdx] : (view.sys ? view.sys.monthText : "")
    readonly property string monthShort: isPt ? monthShortPt[curMonthIdx] : (view.sys ? view.sys.monthText : "")
    readonly property bool isWeekend: curDayOfWeek === 0 || curDayOfWeek === 6

    // Cálculos de progresso do dia e ano (100% bug-free)
    readonly property int dayPct: Math.round(((curHours * 60 + curMinutes) / 1440) * 100)
    readonly property int remainDayHours: 23 - curHours
    readonly property int remainDayMins: Math.max(0, 59 - curMinutes)
    readonly property string remainDayText: remainDayHours + "h " + remainDayMins + "m"

    readonly property var startOfYear: new Date(curYear, 0, 1)
    readonly property var endOfYear: new Date(curYear + 1, 0, 1)
    readonly property int yearPct: Math.round(((view.now - startOfYear) / (endOfYear - startOfYear)) * 100)
    readonly property int remainYearDays: Math.max(0, Math.ceil((endOfYear - view.now) / 86400000))
    readonly property string remainYearText: remainYearDays + (isPt ? " dias" : " days")

    // Launcher de atalhos em segundo plano
    Process { id: pQuick }
    function launch(cmd) {
        pQuick.command = ["sh", "-c", cmd + " &"];
        pQuick.running = false;
        pQuick.running = true;
    }

    // Componente base de Cartão Bento Glass
    component Card: Rectangle {
        radius: 20
        color: Qt.rgba(0.08, 0.08, 0.09, 0.88)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
    }

    // Componente Numérico com fontes Nothing Dot
    component Num: Item {
        id: num
        property string value: ""
        property real size: 14
        property real gapRatio: 0.22
        property color color: view.sys ? view.sys.colFg : "#ffffff"

        implicitWidth: dots.implicitWidth
        implicitHeight: dots.implicitHeight

        DotText {
            id: dots
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
    }

    // Ícone meteorológico Dot
    component WIcon: Item {
        id: wico
        property real size: 20
        property color color: view.sys ? view.sys.colFg : "#ffffff"

        implicitWidth: wdots.implicitWidth
        implicitHeight: wdots.implicitHeight

        DotIcon {
            id: wdots
            code: (view.sys && view.sys.weatherIcon) ? view.sys.weatherIcon : "01d"
            size: wico.size
            color: wico.color
        }
    }

    // Assinatura de legenda em maiúsculas
    component Caption: Text {
        color: view.sys ? view.sys.colMuted : "#888888"
        elide: Text.ElideRight
        font {
            family: view.sys ? view.sys.fontFam : "sans-serif"
            pixelSize: 9
            capitalization: Font.AllUppercase
            letterSpacing: 1.1
            bold: true
        }
    }

    // =========================================================================
    // PILHA VERTICAL DE WIDGETS
    // =========================================================================
    ColumnLayout {
        id: stack
        width: view.fullW
        spacing: view.gap

        // ---------------------------------------------------------------------
        // 1. HERO MASTER CARD: RELÓGIO & DATA (348 x 142)
        // ---------------------------------------------------------------------
        Card {
            id: heroClockCard
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 142
            color: clockMa.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.94) : Qt.rgba(0.08, 0.08, 0.09, 0.88)
            border.color: clockMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Modo 1: Relógio Digital com Matriz de Pontos e Calendário Lateral
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14
                visible: view.clockMode === "digital"

                // Coluna Esquerda: Hora Digital e Segundeiro
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Num {
                            value: view.timeStr
                            size: 46
                            gapRatio: 0.14
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }

                        // Ponto pulsante Nothing OS
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: view.sys ? view.sys.colOn : "#d71921"
                            opacity: view.pulseOpacity
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Barra de Segundos em tempo real (0 a 60s)
                    RowLayout {
                        Layout.preferredWidth: 170
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                width: parent.width * (view.curSeconds / 59.0)
                                height: parent.height
                                radius: 2
                                color: view.sys ? view.sys.colOn : "#d71921"
                            }
                        }

                        Text {
                            text: view.secStr + "s"
                            color: view.sys ? view.sys.colMuted : "#888888"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; bold: true }
                        }
                    }
                }

                // Divisor Vertical Sutil
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Coluna Direita: Bloco de Data e Semana
                ColumnLayout {
                    Layout.preferredWidth: 110
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: 8
                        Text {
                            text: String(view.curDay)
                            color: view.sys ? view.sys.colFg : "#ffffff"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 34; bold: true }
                        }

                        ColumnLayout {
                            spacing: 1
                            Rectangle {
                                radius: 5
                                color: view.isWeekend
                                       ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.20)
                                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                border.color: view.isWeekend ? view.sys.colCrit : view.sys.colOn
                                border.width: 1
                                implicitWidth: dayBadgeTxt.implicitWidth + 8
                                implicitHeight: 18

                                Text {
                                    id: dayBadgeTxt
                                    anchors.centerIn: parent
                                    text: view.dayShort
                                    color: view.isWeekend ? view.sys.colCrit : view.sys.colOn
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 9; bold: true }
                                }
                            }

                            Caption {
                                text: view.monthShort
                                font.pixelSize: 10
                                color: view.sys ? view.sys.colFg : "#ffffff"
                            }
                        }
                    }

                    Caption {
                        text: view.isPt ? "BRASIL · GMT-3" : "LOCAL TIME"
                        font.pixelSize: 8
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }
                }
            }

            // Modo 2: Relógio Analógico Nothing OS com Mostrador de Precisão
            Item {
                anchors.fill: parent
                visible: view.clockMode === "analog"

                Canvas {
                    id: clockCanvas
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var cx = 76;
                        var cy = height / 2;
                        var r = 50;

                        // Mostrador com 12 índices pontilhados Nothing OS
                        for (var i = 0; i < 12; i++) {
                            var ang = i * (Math.PI / 6) - Math.PI / 2;
                            var x = cx + Math.cos(ang) * r;
                            var y = cy + Math.sin(ang) * r;
                            ctx.beginPath();
                            if (i % 3 === 0) {
                                ctx.arc(x, y, 2.5, 0, Math.PI * 2);
                                ctx.fillStyle = "#ffffff";
                            } else {
                                ctx.arc(x, y, 1.4, 0, Math.PI * 2);
                                ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                            }
                            ctx.fill();
                        }

                        var hr = (view.curHours % 12) + (view.curMinutes / 60.0);
                        var mn = view.curMinutes + (view.curSeconds / 60.0);
                        var sc = view.curSeconds;

                        // Ponteiro das Horas (branco robusto)
                        var hAng = hr * (Math.PI / 6) - Math.PI / 2;
                        ctx.beginPath();
                        ctx.lineWidth = 4;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(cx + Math.cos(hAng) * (r * 0.55), cy + Math.sin(hAng) * (r * 0.55));
                        ctx.stroke();

                        // Ponteiro dos Minutos (branco elegante)
                        var mAng = mn * (Math.PI / 30) - Math.PI / 2;
                        ctx.beginPath();
                        ctx.lineWidth = 2.5;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = "#ffffff";
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(cx + Math.cos(mAng) * (r * 0.82), cy + Math.sin(mAng) * (r * 0.82));
                        ctx.stroke();

                        // Ponteiro dos Segundos (vermelho / cor do sistema com contrapeso)
                        var sAng = sc * (Math.PI / 30) - Math.PI / 2;
                        var sCol = view.sys ? String(view.sys.colOn) : "#d71921";
                        ctx.beginPath();
                        ctx.lineWidth = 1.5;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = sCol;
                        // Contrapeso para trás
                        ctx.moveTo(cx - Math.cos(sAng) * (r * 0.22), cy - Math.sin(sAng) * (r * 0.22));
                        ctx.lineTo(cx + Math.cos(sAng) * (r * 0.88), cy + Math.sin(sAng) * (r * 0.88));
                        ctx.stroke();

                        // Ponto central
                        ctx.beginPath();
                        ctx.arc(cx, cy, 3.5, 0, Math.PI * 2);
                        ctx.fillStyle = sCol;
                        ctx.fill();
                    }
                }

                // Bloco informativo à direita do mostrador analógico
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 154
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: view.timeStr + ":" + view.secStr
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 24; bold: true }
                    }

                    Text {
                        text: view.dayNameFull
                        color: view.isWeekend ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colOn : "#ffffff")
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                    }

                    Text {
                        text: view.curDay + " de " + view.monthNameFull
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                    }
                }
            }

            // Indicador de modo no canto superior direito
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                width: 20
                height: 20
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: view.clockMode === "digital" ? "󱑎" : "󱑑"
                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                    color: view.sys ? view.sys.colMuted : "#888888"
                }
            }

            MouseArea {
                id: clockMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.sys && view.sys.cfg) {
                        view.sys.cfg.widgetClockMode = (view.clockMode === "digital" ? "analog" : "digital");
                        view.sys.saveCfg();
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. BENTO DUPLO: CLIMA AO VIVO (168px) + TELEMETRIA DO SISTEMA (168px)
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // -------------------------------------------------- CARD DO CLIMA
            Card {
                id: weatherBento
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 160
                color: wMa.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.94) : Qt.rgba(0.08, 0.08, 0.09, 0.88)
                border.color: wMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // Topo: Ícone e Temperatura Grande
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        WIcon {
                            size: 26
                            color: view.sys ? view.sys.colOn : "#ffffff"
                        }

                        Text {
                            text: (view.sys && view.sys.weatherReady) ? (view.sys.weatherTemp + "°") : "--°"
                            color: view.sys ? view.sys.colFg : "#ffffff"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                        }

                        Item { Layout.fillWidth: true }

                        // Tag do local
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Text {
                                anchors.centerIn: parent
                                text: "󰖐"
                                color: view.sys ? view.sys.colOn : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                            }
                        }
                    }

                    // Estado do tempo em português (com quebra de linha elegante)
                    Text {
                        Layout.fillWidth: true
                        text: (view.sys && view.sys.weatherReady && view.sys.weatherDesc) ? view.sys.weatherDesc : "Carregando..."
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    // Cidade com ícone de pin
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "󰍎"
                            color: view.sys ? view.sys.colMuted : "#888888"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (view.sys && view.sys.weatherPlace) ? view.sys.weatherPlace : "Local"
                            color: view.sys ? view.sys.colMuted : "#888888"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10 }
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Platôs inferiores: Umidade e Vento
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Pílula Umidade
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰖖"
                                    color: view.sys ? view.sys.colOn : "#888"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                                }
                                Text {
                                    text: ((view.sys && view.sys.weatherHumidity) ? view.sys.weatherHumidity : "--") + "%"
                                    color: view.sys ? view.sys.colFg : "#fff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; bold: true }
                                }
                            }
                        }

                        // Pílula Vento
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰖝"
                                    color: view.sys ? view.sys.colMuted : "#888"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                                }
                                Text {
                                    text: ((view.sys && view.sys.weatherWind) ? view.sys.weatherWind : "--") + (view.sys ? (" " + view.sys.weatherWindUnit) : "")
                                    color: view.sys ? view.sys.colFg : "#fff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; bold: true }
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: wMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys) view.sys.openWeatherDetails();
                    }
                }
            }

            // -------------------------------------------------- CARD DE TELEMETRIA
            Card {
                id: telemetryBento
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 160
                color: telemMa.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.94) : Qt.rgba(0.08, 0.08, 0.09, 0.88)
                border.color: telemMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // Cabeçalho da Telemetria
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Caption {
                            Layout.fillWidth: true
                            text: "SISTEMA"
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: view.sys ? view.sys.colOk : "#22c55e"
                            opacity: view.pulseOpacity
                        }
                    }

                    // Medidor Radial Concêntrico Central (Canvas)
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 76
                        height: 76

                        Canvas {
                            id: ringsCanvas
                            anchors.fill: parent

                            Connections {
                                target: view.sys
                                function onLoadCpuChanged() { ringsCanvas.requestPaint(); }
                                function onLoadMemChanged() { ringsCanvas.requestPaint(); }
                                function onLoadDiskChanged() { ringsCanvas.requestPaint(); }
                            }

                            Timer {
                                interval: 2000
                                repeat: true
                                running: view.visible
                                onTriggered: ringsCanvas.requestPaint()
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;

                                var cpu = (view.sys && view.sys.loadCpu >= 0) ? view.sys.loadCpu : 0;
                                var mem = (view.sys && view.sys.loadMem >= 0) ? view.sys.loadMem : 0;

                                // Anel Externo: CPU (Raio 31, Largura 4)
                                var r1 = 31;
                                ctx.lineWidth = 4;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.arc(cx, cy, r1, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                                ctx.stroke();

                                if (cpu > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, cpu) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r1, aStart, aEnd);
                                    ctx.strokeStyle = cpu > 85 ? (view.sys ? String(view.sys.colCrit) : "#ef4444") : (view.sys ? String(view.sys.colOn) : "#8b5cf6");
                                    ctx.stroke();
                                }

                                // Anel Interno: RAM (Raio 21, Largura 4)
                                var r2 = 21;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r2, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.06)";
                                ctx.stroke();

                                if (mem > 0) {
                                    ctx.beginPath();
                                    var mStart = -Math.PI / 2;
                                    var mEnd = mStart + (Math.min(100, mem) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r2, mStart, mEnd);
                                    ctx.strokeStyle = mem > 85 ? (view.sys ? String(view.sys.colCrit) : "#ef4444") : "rgba(255, 255, 255, 0.90)";
                                    ctx.stroke();
                                }
                            }
                        }

                        // Número central do uso de CPU
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (view.sys && view.sys.loadCpu >= 0) ? (view.sys.loadCpu + "%") : "--%"
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "CPU"
                                color: view.sys ? view.sys.colMuted : "#888"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 8; bold: true }
                            }
                        }
                    }

                    // Estatísticas em linha na base
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // RAM
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (view.sys && view.sys.loadMem >= 0) ? (view.sys.loadMem + "%") : "--%"
                                color: view.sys ? view.sys.colFg : "#fff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { text: "RAM"; font.pixelSize: 8 }
                        }

                        Item { Layout.fillWidth: true }

                        // Temp / GPU se houver
                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                text: (view.sys && view.sys.loadTempCpu >= 0) ? (view.sys.loadTempCpu + "°C") : "--"
                                color: view.sys ? view.sys.colOn : "#fff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { text: "TEMP"; font.pixelSize: 8 }
                        }

                        Item { Layout.fillWidth: true }

                        // SSD
                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignRight
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: (view.sys && view.sys.loadDisk >= 0) ? (view.sys.loadDisk + "%") : "--%"
                                color: view.sys ? view.sys.colFg : "#fff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { Layout.alignment: Qt.AlignRight; text: "SSD"; font.pixelSize: 8 }
                        }
                    }
                }

                MouseArea {
                    id: telemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys) view.sys.togglePage("docker");
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 3. CARD DINÂMICO: CYBER MEDIA PLAYER / ATALHOS RÁPIDOS (348 x 106)
        // ---------------------------------------------------------------------
        Card {
            id: dynamicCard
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 106
            readonly property bool hasMedia: view.sys && view.sys.player && view.sys.player.trackTitle && view.sys.player.trackTitle.length > 0
            color: dynMa.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.94) : Qt.rgba(0.08, 0.08, 0.09, 0.88)
            border.color: dynMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // ESTADO A: MÚSICA TOCANDO
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                visible: dynamicCard.hasMedia

                // Capa do Álbum com cantos arredondados
                Rectangle {
                    Layout.preferredWidth: 62
                    Layout.preferredHeight: 62
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (view.sys && view.sys.mediaArt) ? view.sys.mediaArt : ((view.sys && view.sys.player && view.sys.player.trackArtUrl) ? view.sys.player.trackArtUrl : "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Fallback Vinil girando
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26 }
                        color: view.sys ? view.sys.colOn : "#ffffff"
                        visible: !parent.children[0].visible
                    }
                }

                // Info da Faixa & Equalizador
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Caption {
                            Layout.fillWidth: true
                            text: (view.sys && view.sys.player && view.sys.player.isPlaying) ? "REPRODUZINDO" : "PAUSADO"
                            color: view.sys ? view.sys.colOn : "#888"
                        }

                        // Equalizador gráfico animado com 5 barras
                        RowLayout {
                            spacing: 3
                            height: 14
                            visible: view.sys && view.sys.player && view.sys.player.isPlaying

                            Repeater {
                                model: [10, 14, 8, 12, 9]
                                Rectangle {
                                    required property int modelData
                                    required property int index
                                    width: 2.5
                                    height: Math.max(3, Math.min(modelData, 3 + Math.sin(view.animPhase + index * 1.3) * (modelData - 3) * 0.5 + (modelData - 3) * 0.5))
                                    radius: 1.2
                                    color: view.sys ? view.sys.colOn : "#ffffff"
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (view.sys && view.sys.player && view.sys.player.trackTitle) ? view.sys.player.trackTitle : "Faixa"
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13; bold: true }
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (view.sys && view.sys.player && view.sys.player.trackArtist) ? view.sys.player.trackArtist : ((view.sys && view.sys.player) ? view.sys.player.identity : "")
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10 }
                        elide: Text.ElideRight
                    }
                }

                // Controles de Mídia
                RowLayout {
                    spacing: 4

                    // Anterior
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (view.sys && view.sys.player) view.sys.player.previous()
                        }
                    }

                    // Play / Pause
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: view.sys ? view.sys.colOn : "#d71921"
                        scale: ppMa.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: (view.sys && view.sys.player && view.sys.player.isPlaying) ? "󰏤" : "󰐊"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 16 }
                            color: "#ffffff"
                        }
                        MouseArea {
                            id: ppMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (view.sys && view.sys.player) view.sys.player.playPause()
                        }
                    }

                    // Próxima
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (view.sys && view.sys.player) view.sys.player.next()
                        }
                    }
                }
            }

            // ESTADO B: ATALHOS RÁPIDOS QUANDO NÃO HÁ MÚSICA TOCANDO
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                visible: !dynamicCard.hasMedia

                RowLayout {
                    Layout.fillWidth: true
                    Caption {
                        Layout.fillWidth: true
                        text: "ACESSO RÁPIDO"
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }
                    Text {
                        text: "󱐋"
                        color: view.sys ? view.sys.colOn : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { id: "term",  icon: "󰞷", label: "Term",  cmd: "foot || alacritty || kitty" },
                            { id: "code",  icon: "󰨞", label: "Code",  cmd: "code" },
                            { id: "web",   icon: "󰈹", label: "Web",   cmd: "firefox" },
                            { id: "files", icon: "󰉋", label: "Files", cmd: "thunar || dolphin" },
                            { id: "calc",  icon: "󱖦", label: "Calc",  cmd: "kcalc || gnome-calculator" }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 48
                            radius: 12
                            color: btnMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                            border.color: btnMa.containsMouse ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 16 }
                                    color: btnMa.containsMouse ? view.sys.colOn : (view.sys ? view.sys.colFg : "#ffffff")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 8; bold: true }
                                    color: view.sys ? view.sys.colMuted : "#888888"
                                }
                            }

                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id === "files" && view.sys) {
                                        view.sys.togglePage("files");
                                    } else if (modelData.id === "calc" && view.sys) {
                                        view.sys.togglePage("calc");
                                    } else {
                                        view.launch(modelData.cmd);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: dynMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                visible: dynamicCard.hasMedia
                onClicked: {
                    if (view.sys) view.sys.togglePage("media");
                }
            }
        }

        // ---------------------------------------------------------------------
        // 4. BARRA DE PROGRESSO DO DIA & ANO (348 x 70)
        // ---------------------------------------------------------------------
        Card {
            id: progressCard
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 70
            color: progMa.containsMouse ? Qt.rgba(0.12, 0.12, 0.14, 0.94) : Qt.rgba(0.08, 0.08, 0.09, 0.88)
            border.color: progMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 6

                // Linha de Cabeçalho: Título e Porcentagem
                RowLayout {
                    Layout.fillWidth: true

                    Caption {
                        Layout.fillWidth: true
                        text: view.progressMode === "day"
                              ? (view.isPt ? "PROGRESSO DO DIA" : "DAY PROGRESS")
                              : (view.isPt ? "PROGRESSO DO ANO" : "YEAR PROGRESS")
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }

                    Text {
                        text: (view.progressMode === "day" ? view.dayPct : view.yearPct) + "%"
                        color: view.sys ? view.sys.colOn : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                    }
                }

                // Segmentos Gráficos de 24 Horas do Dia
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 3
                    visible: view.progressMode === "day"

                    Repeater {
                        model: 24
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curHours
                                   ? Qt.rgba(1, 1, 1, 0.85)
                                   : (index === view.curHours
                                      ? (view.sys ? view.sys.colOn : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.10))
                            opacity: index === view.curHours ? view.pulseOpacity : 1.0
                        }
                    }
                }

                // Segmentos Gráficos dos 12 Meses do Ano
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 5
                    visible: view.progressMode === "year"

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curMonthIdx
                                   ? Qt.rgba(1, 1, 1, 0.85)
                                   : (index === view.curMonthIdx
                                      ? (view.sys ? view.sys.colOn : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.10))
                            opacity: index === view.curMonthIdx ? view.pulseOpacity : 1.0
                        }
                    }
                }

                // Rodapé informativo com tempo restante exato
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: (view.isPt ? "Restante: " : "Remaining: ") +
                              (view.progressMode === "day" ? view.remainDayText : view.remainYearText)
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10 }
                    }

                    Caption {
                        text: "󰔛 " + (view.progressMode === "day" ? "24H" : "365D")
                        font.pixelSize: 8
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.45) : "#666666"
                    }
                }
            }

            MouseArea {
                id: progMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.sys && view.sys.cfg) {
                        view.sys.cfg.widgetProgressMode = (view.progressMode === "day" ? "year" : "day");
                        view.sys.saveCfg();
                    }
                }
            }
        }
    }
}
