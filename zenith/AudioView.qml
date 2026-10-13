import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Sound: volume, microphone, output device selection and 8-band graphic equalizer.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    // Abas: 0 = Volume & Dispositivos, 1 = Equalizador
    property int currentTab: 0

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        pStreams.running = true;
        pEqStatus.running = true;
    }
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var srcAudio: source ? source.audio : null

    // -------------------------------------------------- Equalizador 8 Bandas (PipeWire)
    property bool eqEnabled: false
    property var eqGains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    readonly property var eqFreqs: ["60Hz", "150Hz", "400Hz", "1kHz", "2.4k", "6kHz", "12k", "16k"]
    property string eqCurrentPreset: "Flat"
    readonly property var eqPresetsList: ["Flat", "Bass Boost", "Treble Boost", "Vocal", "Rock", "Pop", "Electronic", "Acoustic"]
    readonly property var eqPresetsMap: ({
        "Flat": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "Bass Boost": [6.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0],
        "Treble Boost": [0.0, 0.0, 0.0, 1.0, 2.0, 4.0, 6.0, 7.0],
        "Vocal": [-2.0, -1.0, 2.0, 4.0, 3.0, 1.0, 0.0, -1.0],
        "Rock": [5.0, 3.0, -1.0, -2.0, 1.0, 3.0, 5.0, 5.0],
        "Pop": [1.0, 2.0, 4.0, 3.0, 0.0, 2.0, 3.0, 2.0],
        "Electronic": [6.0, 5.0, 2.0, 0.0, 1.0, 3.0, 5.0, 6.0],
        "Acoustic": [3.0, 2.0, 1.0, 2.0, 3.0, 3.0, 2.0, 1.0]
    })

    Process {
        id: pEqStatus
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/equalizer.py", "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var st = JSON.parse(data.trim());
                    if (st && st.running !== undefined) {
                        view.eqEnabled = st.running;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pEqAction
    }

    Timer {
        id: eqApplyTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (!view.eqEnabled) {
                pEqAction.command = ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/equalizer.py", "stop"];
            } else {
                var gainsStr = JSON.stringify(view.eqGains);
                pEqAction.command = ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/equalizer.py", "apply", gainsStr];
            }
            pEqAction.running = true;
        }
    }

    function triggerEqApply() {
        eqApplyTimer.restart();
    }

    function setBandGain(idx, val) {
        var newG = view.eqGains.slice();
        newG[idx] = val;
        view.eqGains = newG;
        view.eqCurrentPreset = "Custom";
        view.triggerEqApply();
    }

    function selectPreset(pName) {
        if (view.eqPresetsMap[pName]) {
            view.eqCurrentPreset = pName;
            view.eqGains = view.eqPresetsMap[pName].slice();
            view.eqEnabled = true;
            view.triggerEqApply();
        }
    }

    // -------------------------------------------------- Mixer de aplicativos (pactl)
    property var streamsList: []
    property bool isUserDragging: false

    Process {
        id: pStreams
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/audio_streams.sh list"]
        stdout: SplitParser {
            onRead: data => {
                if (view.isUserDragging) return;
                try {
                    var parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        view.streamsList = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: streamsTimer
        interval: 1000
        repeat: true
        running: view.visible
        onTriggered: {
            if (!view.isUserDragging && !pStreams.running) pStreams.running = true;
        }
    }

    Process {
        id: pStreamAction
    }

    function setAppVolume(streamId, pct) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/zenith/scripts/audio_streams.sh set-volume "
                                 + streamId + " " + pct];
        pStreamAction.running = true;
    }

    function toggleAppMute(streamId) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/zenith/scripts/audio_streams.sh toggle-mute "
                                 + streamId];
        pStreamAction.running = true;
        quickRefresh.restart();
    }

    Timer {
        id: quickRefresh
        interval: 150
        onTriggered: {
            if (!pStreams.running) pStreams.running = true;
        }
    }

    function getStreamIcon(name, bin, icon) {
        var s = (String(name || "") + " " + String(bin || "") + " " + String(icon || "")).toLowerCase();
        if (s.indexOf("telegram") >= 0) return String.fromCodePoint(0xF2C6);
        if (s.indexOf("spotify") >= 0) return String.fromCodePoint(0xF1BC);
        if (s.indexOf("firefox") >= 0) return String.fromCodePoint(0xF269);
        if (s.indexOf("chrome") >= 0 || s.indexOf("chromium") >= 0 || s.indexOf("brave") >= 0 || s.indexOf("zen") >= 0) return String.fromCodePoint(0xF268);
        if (s.indexOf("discord") >= 0 || s.indexOf("vesktop") >= 0 || s.indexOf("webcord") >= 0) return String.fromCodePoint(0xF392);
        if (s.indexOf("steam") >= 0) return String.fromCodePoint(0xF1B6);
        if (s.indexOf("vlc") >= 0 || s.indexOf("mpv") >= 0 || s.indexOf("video") >= 0 || s.indexOf("player") >= 0 || s.indexOf("music") >= 0) return String.fromCodePoint(0xF144);
        if (s.indexOf("game") >= 0 || s.indexOf("retroarch") >= 0 || s.indexOf("wine") >= 0 || s.indexOf("lutris") >= 0) return String.fromCodePoint(0xF11B);
        return String.fromCodePoint(0xF028);
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SetScroll { sys: view.sys }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                var max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - d));
            }
        }

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 12

            // Top Header: Voltar + Título
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 10
                    color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF004D)
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.page = "main"
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: (view.sys && view.sys.isPt) ? "Áudio & Volume" : view.sys.tr("Звук")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
                }
            }

            // Barra de Abas (Volume vs Equalizador)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    // Aba 1: Volume & Microfone
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 9
                        readonly property bool active: view.currentTab === 0
                        color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                      : (volTabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        border.color: active ? view.sys.colOn : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰕾"
                                color: parent.parent.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Volume" : view.sys.tr("Громкость")
                                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: parent.parent.active }
                            }
                        }
                        MouseArea {
                            id: volTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.currentTab = 0
                        }
                    }

                    // Aba 2: Equalizador
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 9
                        readonly property bool active: view.currentTab === 1
                        color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                      : (eqTabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        border.color: active ? view.sys.colOn : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰓃"
                                color: parent.parent.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Equalizador" : view.sys.tr("Эквалайзер")
                                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: parent.parent.active }
                            }
                        }
                        MouseArea {
                            id: eqTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.currentTab = 1
                        }
                    }
                }
            }

            // =========================================================================
            // CONTEÚDO DA ABA 1: VOLUME & DISPOSITIVOS & MICROFONE
            // =========================================================================
            ColumnLayout {
                id: tabVolumeCol
                Layout.fillWidth: true
                spacing: 14
                visible: view.currentTab === 0

                // ----------------------- SEÇÃO 1: VOLUME PRINCIPAL (SAÍDA)
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: view.sys.colLine
                    border.width: 1
                    implicitHeight: volCardCol.implicitHeight + 20

                    ColumnLayout {
                        id: volCardCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "󰕾"
                                color: view.sinkAudio && !view.sinkAudio.muted ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Saída de Áudio (Alto-falantes)" : view.sys.tr("Устройство вывода")
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: view.sinkAudio ? (view.sinkAudio.muted ? ((view.sys && view.sys.isPt) ? "Mudo" : "Muted") : Math.round(view.sinkAudio.volume * 100) + "%") : "—"
                                color: view.sinkAudio && view.sinkAudio.muted ? view.sys.colMuted : view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                            }
                        }

                        // Slider de Saída
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: outMuteMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)

                                Text {
                                    anchors.centerIn: parent
                                    text: !view.sinkAudio ? String.fromCodePoint(0xF075F)
                                        : view.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                                        : view.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                                        : view.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                                       : String.fromCodePoint(0xF057E)
                                    color: view.sinkAudio && view.sinkAudio.muted ? view.sys.colMuted : view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                                }
                                MouseArea {
                                    id: outMuteMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (view.sinkAudio) view.sinkAudio.muted = !view.sinkAudio.muted
                                }
                            }

                            Item {
                                id: slOut
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24

                                readonly property real pos: view.sinkAudio ? Math.max(0, Math.min(1, view.sinkAudio.volume)) : 0
                                readonly property real usable: width - knobOut.width

                                function setFromX(x) {
                                    if (!view.sinkAudio) return;
                                    var r = Math.max(0, Math.min(1, (x - knobOut.width / 2) / Math.max(1, usable)));
                                    view.sinkAudio.volume = Math.round(r * 20) / 20;
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: knobOut.width / 2
                                    width: parent.usable
                                    height: 6
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                    Rectangle {
                                        width: parent.width * slOut.pos
                                        height: parent.height
                                        radius: 3
                                        color: view.sinkAudio && view.sinkAudio.muted ? view.sys.colMuted : view.sys.colOn
                                    }
                                }
                                Rectangle {
                                    id: knobOut
                                    width: 16; height: 16; radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: slOut.pos * slOut.usable
                                    color: "#ffffff"
                                    border.color: view.sys.colBg
                                    border.width: 2
                                    scale: dragOut.pressed ? 1.25 : (dragOut.containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: dragOut
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => slOut.setFromX(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) slOut.setFromX(mouse.x); }
                                }
                            }
                        }
                    }
                }

                // ----------------------- SEÇÃO 2: CONTROLE DE MICROFONE (ENTRADA)
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: (view.srcAudio && !view.srcAudio.muted) ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3) : view.sys.colLine
                    border.width: 1
                    implicitHeight: micCardCol.implicitHeight + 20

                    ColumnLayout {
                        id: micCardCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: view.srcAudio && !view.srcAudio.muted ? "󰍬" : "󰍭"
                                color: view.srcAudio && !view.srcAudio.muted ? view.sys.colOn : "#ff5555"
                                font { family: view.sys.fontFam; pixelSize: 14 }
                            }
                            Text {
                                text: (view.sys && view.sys.isPt) ? "Microfone (Entrada de Áudio)" : view.sys.tr("Микрофон")
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: view.srcAudio ? (view.srcAudio.muted ? ((view.sys && view.sys.isPt) ? "Mutado" : "Muted") : Math.round(view.srcAudio.volume * 100) + "%") : "—"
                                color: view.srcAudio && view.srcAudio.muted ? "#ff7777" : view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                            }
                        }

                        // Slider do Microfone
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: micMuteMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: view.srcAudio && view.srcAudio.muted ? "#ff5555" : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: view.srcAudio && !view.srcAudio.muted ? "󰍬" : "󰍭"
                                    color: view.srcAudio && !view.srcAudio.muted ? view.sys.colOn : "#ff5555"
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }
                                MouseArea {
                                    id: micMuteMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (view.srcAudio) view.srcAudio.muted = !view.srcAudio.muted
                                }
                            }

                            Item {
                                id: slMic
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24

                                readonly property real pos: view.srcAudio ? Math.max(0, Math.min(1, view.srcAudio.volume)) : 0
                                readonly property real usable: width - knobMic.width

                                function setFromX(x) {
                                    if (!view.srcAudio) return;
                                    var r = Math.max(0, Math.min(1, (x - knobMic.width / 2) / Math.max(1, usable)));
                                    view.srcAudio.volume = Math.round(r * 20) / 20;
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: knobMic.width / 2
                                    width: parent.usable
                                    height: 6
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                    Rectangle {
                                        width: parent.width * slMic.pos
                                        height: parent.height
                                        radius: 3
                                        color: view.srcAudio && view.srcAudio.muted ? "#884444" : view.sys.colOn
                                    }
                                }
                                Rectangle {
                                    id: knobMic
                                    width: 16; height: 16; radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: slMic.pos * slMic.usable
                                    color: view.srcAudio && view.srcAudio.muted ? "#ff7777" : "#ffffff"
                                    border.color: view.sys.colBg
                                    border.width: 2
                                    scale: dragMic.pressed ? 1.25 : (dragMic.containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: dragMic
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => slMic.setFromX(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) slMic.setFromX(mouse.x); }
                                }
                            }
                        }

                        // Nome do microfone ativo
                        Text {
                            Layout.fillWidth: true
                            text: view.source ? (view.source.description || view.source.name || "Microfone Padrão") : "Nenhum microfone detectado"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }
                }

                // ----------------------- SEÇÃO 3: SELEÇÃO DE DISPOSITIVOS DE SAÍDA
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: (view.sys && view.sys.isPt) ? "Dispositivos de Reprodução" : view.sys.tr("Устройство вывода")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: view.sys.audioSinks

                        Rectangle {
                            id: dev
                            required property var modelData
                            readonly property bool here: view.sink && (view.sink === dev.modelData || view.sink.id === dev.modelData.id)

                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 10
                            color: here
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                   : (devMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: here ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: dev.here ? "󰓃" : "󰕾"
                                    color: dev.here ? view.sys.colOn : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: dev.modelData.description || dev.modelData.name || "Sink"
                                    color: dev.here ? view.sys.colFg : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: dev.here }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: dev.here
                                    text: "󰄬"
                                    color: view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                                }
                            }

                            MouseArea {
                                id: devMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.setSink(dev.modelData)
                            }
                        }
                    }
                }

                // ----------------------- SEÇÃO 4: MIXER DE APLICATIVOS
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Text {
                        text: (view.sys && view.sys.isPt) ? "Mixer de Aplicativos" : view.sys.tr("Громкость приложений")
                        color: view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                            bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                        }
                    }

                    Rectangle {
                        visible: view.streamsList.length > 0
                        Layout.preferredHeight: 16
                        Layout.preferredWidth: streamCountText.implicitWidth + 10
                        radius: 8
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.2)

                        Text {
                            id: streamCountText
                            anchors.centerIn: parent
                            text: String(view.streamsList.length)
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Repeater {
                    model: view.streamsList

                    Rectangle {
                        id: strCard
                        required property var modelData
                        required property int index

                        property int currentVolPct: modelData.volume_pct !== undefined ? modelData.volume_pct : Math.round((modelData.volume || 1.0) * 100)
                        property bool isMuted: modelData.muted || false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.sys.colLine
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: view.getStreamIcon(strCard.modelData.name, strCard.modelData.binary, strCard.modelData.icon)
                                    color: strCard.isMuted ? view.sys.colMuted : view.sys.colOn
                                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: strCard.modelData.name || strCard.modelData.binary || ((view.sys && view.sys.isPt) ? "Aplicativo" : view.sys.tr("Приложение"))
                                    color: view.sys.colFg
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                                }

                                Text {
                                    text: strCard.currentVolPct + "%"
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                }

                                Text {
                                    text: strCard.isMuted ? String.fromCodePoint(0xF075F)
                                        : strCard.currentVolPct < 34 ? String.fromCodePoint(0xF057F)
                                        : strCard.currentVolPct < 67 ? String.fromCodePoint(0xF0580)
                                                                     : String.fromCodePoint(0xF057E)
                                    color: strCard.isMuted ? view.sys.colMuted : view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            strCard.isMuted = !strCard.isMuted;
                                            view.toggleAppMute(strCard.modelData.id);
                                        }
                                    }
                                }
                            }

                            Item {
                                id: appSl
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18

                                readonly property real pos: Math.max(0, Math.min(1, strCard.currentVolPct / 100))
                                readonly property real usable: width - appKnob.width

                                function setFromX(x) {
                                    var r = Math.max(0, Math.min(1, (x - appKnob.width / 2) / Math.max(1, usable)));
                                    var pct = Math.round(r * 100);
                                    strCard.currentVolPct = pct;
                                    view.setAppVolume(strCard.modelData.id, pct);
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: appKnob.width / 2
                                    width: parent.usable
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                    Rectangle {
                                        width: parent.width * appSl.pos
                                        height: parent.height
                                        radius: 2
                                        color: strCard.isMuted ? view.sys.colMuted : view.sys.colOn
                                    }
                                }

                                Rectangle {
                                    id: appKnob
                                    width: 14; height: 14; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: appSl.pos * appSl.usable
                                    color: "#ffffff"
                                    border.color: view.sys.colBg
                                    border.width: 2
                                    scale: appDrag.pressed ? 1.25 : (appDrag.containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: appDrag
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => {
                                        view.isUserDragging = true;
                                        appSl.setFromX(mouse.x);
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            view.isUserDragging = true;
                                            appSl.setFromX(mouse.x);
                                        }
                                    }
                                    onReleased: { view.isUserDragging = false; }
                                    onCanceled: { view.isUserDragging = false; }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: view.streamsList.length === 0
                    text: (view.sys && view.sys.isPt) ? "Nenhum aplicativo reproduzindo áudio no momento" : view.sys.tr("Нет активных приложений со звуком")
                    color: view.sys.colMuted
                    horizontalAlignment: Text.AlignHCenter
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; italic: true }
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }
            }

            // =========================================================================
            // CONTEÚDO DA ABA 2: EQUALIZADOR DE 8 BANDAS (REFINADO E MODERNO)
            // =========================================================================
            ColumnLayout {
                id: tabEqCol
                Layout.fillWidth: true
                spacing: 14
                visible: view.currentTab === 1

                // Barra de Controle e Presets do Equalizador
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: view.eqEnabled ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35) : view.sys.colLine
                    border.width: 1
                    implicitHeight: 46

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        // Presets Rápidos
                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            contentWidth: presetChipsRow.implicitWidth
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            RowLayout {
                                id: presetChipsRow
                                spacing: 6

                                Repeater {
                                    model: view.eqPresetsList
                                    Rectangle {
                                        required property string modelData
                                        Layout.preferredHeight: 26
                                        Layout.preferredWidth: prChipTxt.implicitWidth + 18
                                        radius: 13
                                        readonly property bool selected: view.eqCurrentPreset === modelData
                                        color: selected
                                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)
                                               : (pChipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                                        border.color: selected ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            id: prChipTxt
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: selected ? view.sys.colFg : view.sys.colMuted
                                            font { family: view.sys.fontFam; pixelSize: 10; bold: selected }
                                        }

                                        MouseArea {
                                            id: pChipMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.selectPreset(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // Botão Flat (0 dB)
                        Rectangle {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: flatBtnTxt.implicitWidth + 18
                            radius: 13
                            color: flatBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            Text {
                                id: flatBtnTxt
                                anchors.centerIn: parent
                                text: "Flat (0 dB)"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }
                            MouseArea {
                                id: flatBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.selectPreset("Flat")
                            }
                        }

                        // Master Switch ON / OFF
                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 24
                            radius: 12
                            color: view.eqEnabled ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                            Behavior on color { ColorAnimation { duration: 160 } }

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: view.eqEnabled ? parent.width - width - 3 : 3
                                color: "#ffffff"
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.eqEnabled = !view.eqEnabled;
                                    view.triggerEqApply();
                                }
                            }
                        }
                    }
                }

                // Card do Gráfico da Curva de Resposta em Frequência (Canvas Visualizer)
                Rectangle {
                    id: eqGraphCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    radius: 16
                    color: Qt.rgba(0, 0, 0, 0.32)
                    border.color: view.eqEnabled ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : view.sys.colLine
                    border.width: 1
                    clip: true

                    // Grade de referência em dB
                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        // Linha de 0 dB (Centro)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.16)
                        }

                        // Linha +6 dB
                        Rectangle {
                            y: parent.height * 0.25
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.05)
                        }

                        // Linha -6 dB
                        Rectangle {
                            y: parent.height * 0.75
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.05)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            text: "+12dB"
                            color: Qt.rgba(1, 1, 1, 0.3)
                            font { family: view.sys.fontFam; pixelSize: 8; bold: true }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -6
                            text: "0dB"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font { family: view.sys.fontFam; pixelSize: 8; bold: true }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: "-12dB"
                            color: Qt.rgba(1, 1, 1, 0.3)
                            font { family: view.sys.fontFam; pixelSize: 8; bold: true }
                        }
                    }

                    Canvas {
                        id: eqCanvas
                        anchors.fill: parent
                        opacity: view.eqEnabled ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Connections {
                            target: view
                            function onEqGainsChanged() { eqCanvas.requestPaint(); }
                            function onEqEnabledChanged() { eqCanvas.requestPaint(); }
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var w = width;
                            var h = height;
                            if (w <= 0 || h <= 0) return;

                            var gains = view.eqGains || [0,0,0,0,0,0,0,0];
                            var count = 8;
                            var pts = [];

                            var padX = 30;
                            var usableW = w - padX * 2;
                            var midY = h * 0.5;

                            for (var i = 0; i < count; i++) {
                                var g = (gains.length > i) ? gains[i] : 0.0;
                                var px = padX + (i / (count - 1)) * usableW;
                                var py = midY - (g / 12.0) * (midY * 0.76);
                                pts.push({ x: px, y: py, gain: g });
                            }

                            // Gradiente de preenchimento sob a curva
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, midY);
                            ctx.lineTo(pts[0].x, pts[0].y);

                            for (var i = 0; i < pts.length - 1; i++) {
                                var p0 = (i > 0) ? pts[i - 1] : pts[i];
                                var p1 = pts[i];
                                var p2 = pts[i + 1];
                                var p3 = (i + 2 < pts.length) ? pts[i + 2] : p2;

                                var cp1x = p1.x + (p2.x - p0.x) / 5.0;
                                var cp1y = p1.y + (p2.y - p0.y) / 5.0;
                                var cp2x = p2.x - (p3.x - p1.x) / 5.0;
                                var cp2y = p2.y - (p3.y - p1.y) / 5.0;

                                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                            }

                            ctx.lineTo(pts[pts.length - 1].x, midY);
                            ctx.closePath();

                            var grad = ctx.createLinearGradient(0, 0, 0, h);
                            var col = view.sys.colOn;
                            grad.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.42));
                            grad.addColorStop(0.5, Qt.rgba(col.r, col.g, col.b, 0.16));
                            grad.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.02));
                            ctx.fillStyle = grad;
                            ctx.fill();

                            // Linha de contorno da resposta
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            for (var i = 0; i < pts.length - 1; i++) {
                                var p0 = (i > 0) ? pts[i - 1] : pts[i];
                                var p1 = pts[i];
                                var p2 = pts[i + 1];
                                var p3 = (i + 2 < pts.length) ? pts[i + 2] : p2;

                                var cp1x = p1.x + (p2.x - p0.x) / 5.0;
                                var cp1y = p1.y + (p2.y - p0.y) / 5.0;
                                var cp2x = p2.x - (p3.x - p1.x) / 5.0;
                                var cp2y = p2.y - (p3.y - p1.y) / 5.0;

                                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
                            }
                            ctx.strokeStyle = view.eqEnabled ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.4);
                            ctx.lineWidth = 2.4;
                            ctx.stroke();

                            // Nós nas frequências com halo
                            for (var i = 0; i < pts.length; i++) {
                                var pt = pts[i];
                                ctx.beginPath();
                                ctx.arc(pt.x, pt.y, 4.5, 0, 2 * Math.PI);
                                ctx.fillStyle = view.eqEnabled ? Qt.rgba(col.r, col.g, col.b, 0.35) : Qt.rgba(1, 1, 1, 0.15);
                                ctx.fill();

                                ctx.beginPath();
                                ctx.arc(pt.x, pt.y, 2.5, 0, 2 * Math.PI);
                                ctx.fillStyle = view.eqEnabled ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.7);
                                ctx.fill();
                            }
                        }
                    }
                }

                // Card do Banco de Faders de Frequência do Equalizador
                Rectangle {
                    Layout.fillWidth: true
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.045)
                    border.color: view.sys.colLine
                    border.width: 1
                    implicitHeight: 235

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        // Grid dos 8 Faders de Estúdio
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            Repeater {
                                model: 8
                                Rectangle {
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: Math.abs(currentGain) > 0.4 ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.08) : Qt.rgba(1, 1, 1, 0.025)
                                    border.color: Math.abs(currentGain) > 0.4 ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1

                                    readonly property real currentGain: (view.eqGains && view.eqGains.length > index) ? view.eqGains[index] : 0.0

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6

                                        // Badge de valor em dB (+3dB, 0dB, -2dB)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            radius: 6
                                            color: Math.abs(currentGain) > 0.4
                                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                                   : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Math.abs(currentGain) > 0.4
                                                          ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                                                          : Qt.rgba(1, 1, 1, 0.1)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (currentGain > 0 ? "+" : "") + currentGain.toFixed(1)
                                                color: Math.abs(currentGain) > 0.4 ? view.sys.colOn : view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9; bold: Math.abs(currentGain) > 0.4 }
                                            }
                                        }

                                        // Trilho vertical de estúdio
                                        Item {
                                            id: sTrack
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.minimumHeight: 120

                                            // Trilho de canal rebaixado
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 10
                                                height: parent.height
                                                radius: 5
                                                color: Qt.rgba(0, 0, 0, 0.45)
                                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                                border.width: 1
                                            }

                                            // Marcas de referência laterais (ticks: +12, +6, 0, -6, -12)
                                            Repeater {
                                                model: [-12, -6, 0, 6, 12]
                                                Rectangle {
                                                    required property real modelData
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    y: (1.0 - (modelData + 12.0) / 24.0) * (sTrack.height - 18) + 9
                                                    width: modelData === 0 ? Math.min(sTrack.width - 8, 28) : Math.min(sTrack.width - 14, 18)
                                                    height: 1
                                                    color: modelData === 0 ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.15)
                                                }
                                            }

                                            // Barra de preenchimento dinâmico a partir do centro (0 dB)
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                property real centerRatio: 0.5
                                                property real posRatio: 1.0 - (currentGain + 12.0) / 24.0
                                                y: Math.min(centerRatio, posRatio) * (sTrack.height - 18) + 9
                                                height: Math.max(2, Math.abs(posRatio - centerRatio) * (sTrack.height - 18))
                                                width: 8
                                                radius: 4
                                                color: view.eqEnabled
                                                       ? (currentGain >= 0 ? view.sys.colOn : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.7))
                                                       : Qt.rgba(1, 1, 1, 0.25)
                                            }

                                            // Knob / Cap de Fader de Hardware
                                            Rectangle {
                                                id: knob
                                                width: Math.min(sTrack.width - 6, 36); height: 16; radius: 5
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: (1.0 - (currentGain + 12.0) / 24.0) * (sTrack.height - 18) + 1
                                                color: eqSlMa.pressed ? "#ffffff" : (eqSlMa.containsMouse ? "#f1f5f9" : "#e2e8f0")
                                                border.color: eqSlMa.pressed ? view.sys.colOn : Qt.rgba(0, 0, 0, 0.4)
                                                border.width: 1

                                                // Linha central indicadora no cap
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 12
                                                    height: 2
                                                    radius: 1
                                                    color: eqSlMa.pressed ? view.sys.colOn : Qt.rgba(0, 0, 0, 0.6)
                                                }

                                                scale: eqSlMa.pressed ? 1.12 : (eqSlMa.containsMouse ? 1.05 : 1.0)
                                                Behavior on scale { NumberAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                id: eqSlMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                preventStealing: true
                                                cursorShape: Qt.PointingHandCursor
                                                onPressed: mouse => updateY(mouse.y)
                                                onPositionChanged: mouse => { if (pressed) updateY(mouse.y); }
                                                onDoubleClicked: {
                                                    view.setBandGain(index, 0.0);
                                                }

                                                function updateY(my) {
                                                    var clampedY = Math.max(0, Math.min(sTrack.height - 18, my - 9));
                                                    var ratio = 1.0 - (clampedY / Math.max(1, sTrack.height - 18));
                                                    var g = Math.round((ratio * 24.0 - 12.0) * 2) / 2;
                                                    view.setBandGain(index, Math.max(-12.0, Math.min(12.0, g)));
                                                }
                                            }
                                        }

                                        // Badge de frequência embaixo
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            radius: 6
                                            color: Qt.rgba(1, 1, 1, 0.05)

                                            Text {
                                                anchors.centerIn: parent
                                                text: view.eqFreqs[index]
                                                color: view.sys.colMuted
                                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 10 }
        }
    }
}
