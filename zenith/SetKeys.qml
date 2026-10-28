import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Shortcut keys. Opens as a separate window via Super + /, not as a section
// settings: this is a reference book that is accessed in the middle of work, and a sidebar
// with a list of sections it would only get in the way.
//
// Edits accumulate in the draft and go to Hyprland using “Apply”. Not right away
// we use it on purpose: a half-empty combination written down while typing could
// to take away the key from the one with whom it is controlled.
ColumnLayout {
    id: page

    property var sys

    // ---------------------------------------------------- draft combinations
    property var bindDraft: ({})
    property int bindRev: 0          // counter so that the bindings are reread
    readonly property bool dirty: {
        bindRev;
        for (var id in page.bindDraft) return true;
        return false;
    }

    function bindCombo(id) {
        bindRev;                     // dependency for recalculation
        var raw = page.bindDraft[id] !== undefined
                  ? String(page.bindDraft[id]) : String(page.sys.cfg["bind_" + id] || "");
        return page.prettyCombo(raw);
    }
    function bindRaw(id) {
        bindRev;
        return page.bindDraft[id] !== undefined
               ? String(page.bindDraft[id]) : String(page.sys.cfg["bind_" + id] || "");
    }

    // Hyprland knows the keys by name (slash, comma, period...), and to a person
    // the sign itself is more familiar. We show the sign, the name is in the settings.
    readonly property var keySigns: ({
        slash: "/", backslash: "\\", comma: ",", period: ".",
        semicolon: ";", apostrophe: "'", grave: "`", minus: "-", equal: "=",
        bracketleft: "[", bracketright: "]", space: "Espaço", delete: "Del",
        return: "Enter", prior: "PgUp", next: "PgDn", escape: "Esc"
    })
    function prettyCombo(raw) {
        var parts = String(raw).split("+");
        for (var i = 0; i < parts.length; i++) {
            var k = parts[i].trim();
            var sign = page.keySigns[k.toLowerCase()];
            parts[i] = sign !== undefined ? sign : k;
        }
        return parts.join(" + ");
    }
    function bindChanged(id) {
        bindRev;
        return page.bindDraft[id] !== undefined;
    }
    function setBind(id, combo) {
        page.bindDraft[id] = combo;
        page.bindRev++;
    }
    function clearBind(id) { page.setBind(id, ""); }
    function discardBinds() { page.bindDraft = ({}); page.bindRev++; }

    function applyBinds() {
        var touched = false;
        for (var id in page.bindDraft) {
            page.sys.cfg["bind_" + id] = page.bindDraft[id];
            touched = true;
        }
        page.discardBinds();
        // applyBinds itself saves the settings and rebuilds binds_data.lua
        if (touched) page.sys.applyBinds();
    }
    // “Reset” returns the factory combinations, rather than simply undoing the edits:
    // We put everything that now differs from the default values into the draft.
    function resetBinds() {
        var o = {};
        var def = page.sys.defaultBinds;
        for (var id in def) {
            if (String(page.sys.cfg["bind_" + id] || "") !== def[id]) o[id] = def[id];
        }
        page.bindDraft = o;
        page.bindRev++;
    }

    // ------------------------------------------------------------- capture
    property string capturingKey: ""

    // What has already been pressed right now is shown in the line as you type.
    property bool  mMeta:  false
    property bool  mCtrl:  false
    property bool  mAlt:   false
    property bool  mShift: false
    property string pendingName: ""

    readonly property string capturePreview: {
        var m = [];
        if (mMeta)  m.push("SUPER");
        if (mCtrl)  m.push("CTRL");
        if (mAlt)   m.push("ALT");
        if (mShift) m.push("SHIFT");
        if (pendingName.length) m.push(pendingName);
        return m.join(" + ");
    }

    // While the capture is in progress, Hyprland is moved to an empty submap: otherwise, press
    // worked as an already existing combination and did not reach the panel.
    Process { id: pCapture }
    function grabKeys(on) {
        // Restarting explicitly: assigning a command to a running Process
        // does not take effect, and the next entry into the submap silently disappears.
        pCapture.running = false;
        pCapture.command = ["sh", "-c",
            page.sys.scriptDir + "/capture.sh " + (on ? "on" : "off")];
        pCapture.running = true;
    }

    function clearHeld() {
        page.mMeta = false; page.mCtrl = false; page.mAlt = false; page.mShift = false;
        page.pendingName = "";
    }

    function startCapture(key) {
        page.capturingKey = key;
        page.clearHeld();
        page.forceActiveFocus();
        page.grabKeys(true);
        captureTimeout.restart();
    }
    function stopCapture() {
        if (page.capturingKey.length === 0) return;   // already stopped
        page.capturingKey = "";
        page.clearHeld();
        captureTimeout.stop();
        page.grabKeys(false);
    }

    // insurance: do not leave the system without hotkeys
    Timer {
        id: captureTimeout
        interval: 8000
        onTriggered: page.stopCapture()
    }

    Connections {
        target: page.sys
        // comes from capture.sh off; if the grip has already been removed, we do nothing
        function onCancelCaptureRequested() {
            if (page.capturingKey.length) page.stopCapture();
        }
    }

    readonly property var modKeys: [
        Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
        Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_CapsLock
    ]

    function isMeta(k)  { return k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R; }
    function isCtrl(k)  { return k === Qt.Key_Control; }
    function isAlt(k)   { return k === Qt.Key_Alt || k === Qt.Key_AltGr; }
    function isShift(k) { return k === Qt.Key_Shift; }

    // Name of a regular key in Hyprland terms
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
        switch (k) {
            case Qt.Key_Space:  return "Space";
            case Qt.Key_Return:
            case Qt.Key_Enter:  return "Return";
            case Qt.Key_Tab:    return "Tab";
            case Qt.Key_Left:   return "left";
            case Qt.Key_Right:  return "right";
            case Qt.Key_Up:     return "up";
            case Qt.Key_Down:   return "down";
            case Qt.Key_Comma:  return "comma";
            case Qt.Key_Period: return "period";
            case Qt.Key_Slash:  return "slash";
            case Qt.Key_Minus:  return "minus";
            case Qt.Key_Equal:  return "equal";
            case Qt.Key_BracketLeft:  return "bracketleft";
            case Qt.Key_BracketRight: return "bracketright";
            case Qt.Key_Semicolon:    return "semicolon";
            case Qt.Key_Apostrophe:   return "apostrophe";
            case Qt.Key_Backslash:    return "backslash";
            case Qt.Key_Delete:       return "delete";
            case Qt.Key_Insert:       return "insert";
            case Qt.Key_Home:         return "home";
            case Qt.Key_End:          return "end";
            case Qt.Key_PageUp:       return "Page_Up";
            case Qt.Key_PageDown:     return "Page_Down";
            case Qt.Key_Backspace:    return "BackSpace";
            case Qt.Key_Print:        return "Print";
            case Qt.Key_Pause:        return "Pause";
            case Qt.Key_Menu:         return "Menu";
        }
        return "";
    }

    focus: true

    Keys.onPressed: event => {
        if (page.capturingKey.length === 0) {
            if (event.key === Qt.Key_Escape) {
                page.sys.keysWindowOpen = false;
                event.accepted = true;
                return;
            }
            // Super + / closes the window with the same combination that opened it. Before
            // Hyprland it does not reach: while the window is on the screen, the layer holds
            // the keyboard is exclusive, and compositor binding does not work -
            // so we catch the combination here.
            if (event.key === Qt.Key_Slash && (event.modifiers & Qt.MetaModifier)) {
                page.sys.keysWindowOpen = false;
                event.accepted = true;
            }
            return;
        }
        event.accepted = true;
        captureTimeout.restart();

        if (event.key === Qt.Key_Escape) { page.stopCapture(); return; }

        // We mark modifiers immediately - they appear in the line as you click.
        // Qt does not yet show it in the event of the modifier itself, so
        // We look at both the key code and the mask.
        page.mMeta  = page.mMeta  || page.isMeta(event.key)  || (event.modifiers & Qt.MetaModifier)    !== 0;
        page.mCtrl  = page.mCtrl  || page.isCtrl(event.key)  || (event.modifiers & Qt.ControlModifier) !== 0;
        page.mAlt   = page.mAlt   || page.isAlt(event.key)   || (event.modifiers & Qt.AltModifier)     !== 0;
        page.mShift = page.mShift || page.isShift(event.key) || (event.modifiers & Qt.ShiftModifier)   !== 0;

        if (page.modKeys.indexOf(event.key) >= 0) return;   // waiting for a real key

        var n = page.keyName(event.key);
        if (n.length === 0) return;
        page.pendingName = n;

        // the combination is collected - save it as a draft, it will be applied by “Apply”
        var target = page.capturingKey;
        var combo = page.capturePreview;
        page.stopCapture();
        page.setBind(target, combo);
    }

    Keys.onReleased: event => {
        if (page.capturingKey.length === 0) return;
        event.accepted = true;
        if (page.isMeta(event.key))  page.mMeta = false;
        if (page.isCtrl(event.key))  page.mCtrl = false;
        if (page.isAlt(event.key))   page.mAlt = false;
        if (page.isShift(event.key)) page.mShift = false;
    }

    Component.onCompleted: page.forceActiveFocus()
    Component.onDestruction: {
        // do not leave the system without hotkeys
        if (page.capturingKey.length) page.grabKeys(false);
    }

    // ------------------------------------------------------------ lines
    component BindRow: RowLayout {
        id: brow
        property string bindId: ""
        property string label: ""
        property bool manual: false
        readonly property bool capturing: page.capturingKey === brow.bindId
        readonly property string combo: page.bindCombo(brow.bindId)
        readonly property bool edited: page.bindChanged(brow.bindId)

        // The rows divide the column height among themselves: the card takes up almost
        // the entire screen, and without stretching the list would be strayed to the top edge,
        // leaving an empty field underneath. The ceiling is needed so that it is high
        // on the screen, the lines did not disperse into a sparse list.
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: 14

        Rectangle {
            id: box
            Layout.preferredWidth: 180
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 9
            color: brow.capturing
                   ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                   : (bMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
            border.color: brow.capturing ? page.sys.colOn : page.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            SequentialAnimation {
                running: brow.capturing
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: box; property: "opacity"; to: 0.45; duration: 520 }
                NumberAnimation { target: box; property: "opacity"; to: 1.0;  duration: 520 }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                // during capture we show what has already been pressed
                text: brow.capturing
                      ? (page.capturePreview.length ? page.capturePreview
                                                    : page.sys.tr("Pressione o atalho…"))
                      : (brow.combo.length ? brow.combo : "—")
                color: brow.combo.length || brow.capturing ? page.sys.colFg : page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.fontSize - 4; bold: true }
            }

            // dot-mark: combination changed but not yet applied
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                visible: brow.edited
                color: page.sys.colOk
            }

            MouseArea {
                id: bMa
                anchors.fill: parent
                enabled: !brow.manual
                hoverEnabled: true
                cursorShape: brow.manual ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: page.startCapture(brow.bindId)
            }
        }

        Text {
            Layout.fillWidth: true
            text: brow.label
            color: page.sys.colMuted
            elide: Text.ElideRight
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }

        Text {
            text: "×"
            visible: !brow.manual && brow.combo.length > 0
            color: cMa.containsMouse ? page.sys.colCrit : page.sys.colMuted
            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize + 2 }
            Behavior on color { ColorAnimation { duration: 150 } }
            MouseArea {
                id: cMa
                anchors.fill: parent
                anchors.margins: -6
                enabled: !brow.manual
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.clearBind(brow.bindId)
            }
        }
    }


    // Group title. Not SetLabel: that one is designed for a settings card, but
    // here the columns are a continuous list, and it needs an indent at the top.
    component Head: Text {
        Layout.fillWidth: true
        Layout.topMargin: 8
        color: page.sys.colMuted
        font {
            family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4
            bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
        }
    }

    // =========================================================== layout
    // Only what can be reassigned: Hyprland's permanent combinations
    // (tables by numbers, focus with arrows, mouse) are removed from here - in the window where
    // every row is clickable, there is nothing to show rows that are not clickable.
    //
    // There is no scrolling: two columns of fifteen lines each fit entirely, and
    // the lines are stretched along the height of the card, rather than being pressed to the top edge.
    Layout.fillWidth: true
    spacing: 10

    Text {
        Layout.fillWidth: true
        text: page.sys.tr("Clique no atalho para alterar. × remove a tecla.")
        color: Qt.rgba(1, 1, 1, 0.32)
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }

    Flickable {
        id: bindScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: bindColumns.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SetScroll { sys: page.sys }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var max = Math.max(0, bindScroll.contentHeight - bindScroll.height);
                bindScroll.contentY = Math.max(0, Math.min(max, bindScroll.contentY - event.angleDelta.y));
            }
        }

    RowLayout {
        id: bindColumns
        width: bindScroll.width - 12
        spacing: 26

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1     // divide equally, not according to content
            spacing: 9

            Head { text: "Recursos & Zenith" }
            BindRow { bindId: "pillFeatures";  label: "Recursos & Ferramentas" }
            BindRow { bindId: "pillEmulator";  label: (page.sys && page.sys.isPt) ? "Emulador Retro (GBA/DS/3DS)" : "Retro Emulator (GBA/DS/3DS)" }
            BindRow { bindId: "pillDocker";    label: "Docker" }
            BindRow { bindId: "pillCalc";      label: "Calculadora" }
            BindRow { bindId: "pillTerminals"; label: (page.sys && page.sys.isPt) ? "Terminais em Segundo Plano" : "Background Terminals" }
            BindRow { bindId: "pillTasks";     label: (page.sys && page.sys.isPt) ? "Gerenciador de Tarefas" : "Task Manager" }
            BindRow { bindId: "pillRegex";     label: (page.sys && page.sys.isPt) ? "Gerador de Regex (IA)" : "Regex Generator (AI)" }
            BindRow { bindId: "pillPicker";    label: (page.sys && page.sys.isPt) ? "Seletor de Cores & Ícones" : "Color & Icon Picker" }
            BindRow { bindId: "pillCheat";     label: "Cheat Sheet & TLDR" }
            BindRow { bindId: "pillProfile";   label: "GitHub Profile" }
            BindRow { bindId: "pillCalendar";  label: "Calendário" }
            BindRow { bindId: "pillWeather";   label: "Previsão do Tempo" }
            BindRow { bindId: "pillLauncher";  label: "Lançador de Aplicativos" }
            BindRow { bindId: "overview";      label: "Visão Geral de Áreas" }
            BindRow { bindId: "pillControls";  label: "Painel de Controle" }
            BindRow { bindId: "pillSettings";  label: "Configurações" }
            BindRow { bindId: "pillShortcuts"; label: "Atalhos do Sistema" }
            BindRow { bindId: "pillWifi";      label: "Redes Wi-Fi" }
            BindRow { bindId: "pillBt";        label: "Dispositivos Bluetooth" }
            BindRow { bindId: "pillClip";      label: "Área de Transferência" }
            BindRow { bindId: "pillPower";     label: "Menu de Energia" }
            BindRow { bindId: "pillRecord";    label: "Gravação de Tela" }
            BindRow { bindId: "pillVault";     label: "Cofre de Senhas" }
            BindRow { bindId: "pillNotif";     label: "Notificações" }
            BindRow { bindId: "fileManager";   label: "Gerenciador de Arquivos" }
            BindRow { bindId: "voxDictate";    label: "Voz para Texto"; manual: true }

            Head { text: "Sistema" }
            BindRow { bindId: "lockScreen";   label: "Bloquear Tela" }
            BindRow { bindId: "screenOff";    label: "Apagar Tela" }
            BindRow { bindId: "exitHypr";     label: "Sair do Hyprland" }
            BindRow { bindId: "themeSwitch";  label: "Trocar Papel de Parede" }

            Head { text: "Aplicativos" }
            BindRow { bindId: "terminal";       label: "Terminal Principal" }
            BindRow { bindId: "terminalAlt";    label: "Terminal Alternativo" }
            BindRow { bindId: "browser";        label: "Navegador Web" }
            BindRow { bindId: "fileManagerTui"; label: "Arquivos no Terminal" }
            BindRow { bindId: "notes";          label: "Bloco de Notas" }
            BindRow { bindId: "screenshot";     label: "Captura de Tela" }

            Head { text: "Tampa do Notebook" }
            BindRow { bindId: "lidOn";  label: "Fechar Tampa"; manual: true }
            BindRow { bindId: "lidOff"; label: "Abrir Tampa"; manual: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 9

            Head { text: "Gerenciamento de Janelas" }
            BindRow { bindId: "closeWindow";        label: "Fechar Janela" }
            BindRow { bindId: "fullscreen";         label: "Tela Cheia" }
            BindRow { bindId: "floatToggle";        label: "Janela Flutuante" }
            BindRow { bindId: "floatCenter";        label: "Centralizar Flutuante" }
            BindRow { bindId: "toggleSplit";        label: "Alternar Divisão (Split)" }
            BindRow { bindId: "closeMouse";         label: "Fechar com Botão do Meio"; manual: true }
            BindRow { bindId: "dragWindow";         label: "Arrastar Janela"; manual: true }
            BindRow { bindId: "resizeWindowMouse";  label: "Redimensionar com Mouse"; manual: true }

            Head { text: "Navegação por Janelas" }
            BindRow { bindId: "focusLeft";   label: "Foco para Esquerda" }
            BindRow { bindId: "focusRight";  label: "Foco para Direita" }
            BindRow { bindId: "focusUp";     label: "Foco para Cima" }
            BindRow { bindId: "focusDown";   label: "Foco para Baixo" }
            BindRow { bindId: "moveLeft";    label: "Mover para Esquerda" }
            BindRow { bindId: "moveRight";   label: "Mover para Direita" }
            BindRow { bindId: "moveUp";      label: "Mover para Cima" }
            BindRow { bindId: "moveDown";    label: "Mover para Baixo" }
            BindRow { bindId: "resizeLeft";  label: "Diminuir Largura" }
            BindRow { bindId: "resizeRight"; label: "Aumentar Largura" }
            BindRow { bindId: "resizeUp";    label: "Diminuir Altura" }
            BindRow { bindId: "resizeDown";  label: "Aumentar Altura" }

            Head { text: "Mídia & Volume" }
            BindRow { bindId: "volumeUp";          label: "Aumentar Volume"; manual: true }
            BindRow { bindId: "volumeDown";        label: "Diminuir Volume"; manual: true }
            BindRow { bindId: "volumeMute";        label: "Silenciar Áudio"; manual: true }
            BindRow { bindId: "micMute";           label: "Silenciar Microfone"; manual: true }
            BindRow { bindId: "brightnessUp";      label: "Aumentar Brilho"; manual: true }
            BindRow { bindId: "brightnessDown";    label: "Diminuir Brilho"; manual: true }
            BindRow { bindId: "mediaPlay";         label: "Reproduzir"; manual: true }
            BindRow { bindId: "mediaPause";        label: "Pausar"; manual: true }
            BindRow { bindId: "mediaNext";         label: "Próxima Faixa"; manual: true }
            BindRow { bindId: "mediaPrevious";     label: "Faixa Anterior"; manual: true }
            BindRow { bindId: "mediaNextAlt";      label: "Próxima Faixa (Alt)"; manual: true }
            BindRow { bindId: "mediaPreviousAlt";  label: "Faixa Anterior (Alt)"; manual: true }
        }
    }
    }

    // ------------------------------------------------------------- buttons
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 12

        Item { Layout.fillWidth: true }

        SetButton {
            sys: page.sys
            text: "Restaurar"
            onClicked: page.resetBinds()
        }

        SetButton {
            sys: page.sys
            text: "Aplicar"
            primary: true
            enabled: page.dirty
            onClicked: page.applyBinds()
        }
    }
}
