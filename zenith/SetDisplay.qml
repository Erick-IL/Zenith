import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Display & Multi-Monitor Management.
// Provides full control for: Mirroring (Espelhar) vs Extending (Expandir),
// Primary Monitor (Tela Principal), Resolution, Refresh Rate, Scale, and Orientation.
ColumnLayout {
    id: page

    property var sys

    // [{ name, desc, w, h, rr, scale, transform, vrr, x, y, mirrorOf, modes: [] }]
    property var mons: []

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pMons.running = true; page.sys.brightRefresh(false); }

    Process { id: pQuick }

    // Screen brightness
    function brightOf(name) {
        var l = page.sys.brightList || [];
        for (var i = 0; i < l.length; i++)
            if (l[i].name === name) return l[i];
        if (l.length === 1 && page.sys.brightBackend === "backlight") return l[0];
        return null;
    }

    Process {
        id: pMons
        command: ["sh", "-c", "hyprctl -j monitors all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text.slice(text.lastIndexOf("[{")));
                    page.mons = raw.map(m => ({
                        name: m.name,
                        desc: m.description || "",
                        w: m.width, h: m.height,
                        rr: m.refreshRate,
                        scale: m.scale,
                        transform: m.transform,
                        vrr: !!m.vrr,
                        x: m.x, y: m.y,
                        mirrorOf: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : "",
                        modes: m.availableModes || []
                    }));
                } catch (e) {
                    page.mons = [];
                }
            }
        }
    }

    function getMirror(m) {
        var saved = (page.sys && page.sys.monMap ? page.sys.monMap()[m.name] : null) || {};
        if (saved.mirror !== undefined && saved.mirror !== null && saved.mirror !== "") return saved.mirror;
        if (m.mirrorOf && m.mirrorOf !== "none") return m.mirrorOf;
        return "";
    }

    function isPrimary(name) {
        if (page.sys && page.sys.cfg && page.sys.cfg.primaryMonitor)
            return page.sys.cfg.primaryMonitor === name;
        return page.mons.length > 0 && page.mons[0].name === name;
    }

    function setPrimary(name) {
        if (!page.sys) return;
        page.sys.cfg.primaryMonitor = name;
        page.sys.saveCfg();
        var m = page.mons.find(x => x.name === name);
        if (m) {
            page.apply(m, { pos: "0x0", mirror: "" });
        }
        pQuick.command = ["sh", "-c", "hyprctl dispatch focusmonitor " + name];
        pQuick.running = false;
        pQuick.running = true;
        reload.restart();
    }

    function otherMons(name) {
        var out = [];
        for (var i = 0; i < page.mons.length; i++) {
            if (page.mons[i].name !== name) out.push(page.mons[i]);
        }
        return out;
    }

    function apply(m, over) {
        page.sys.monApply(m.name, {
            w:  over.w  !== undefined ? over.w  : m.w,
            h:  over.h  !== undefined ? over.h  : m.h,
            rr: over.rr !== undefined ? over.rr : m.rr,
            scale: over.scale !== undefined ? over.scale : m.scale,
            transform: over.transform !== undefined ? over.transform : m.transform,
            vrr: m.vrr,
            pos: over.pos !== undefined ? over.pos : page.placeOf(m),
            mirror: over.mirror !== undefined ? over.mirror : page.getMirror(m)
        });
        reload.restart();
    }

    Timer {
        id: reload
        interval: 700
        onTriggered: { pMons.running = false; pMons.running = true; }
    }

    function placeOf(m) {
        var base = page.mons.length ? page.mons[0] : null;
        if (!base || base.name === m.name) return "auto";
        if (m.x >= base.x + base.w) return "auto-right";
        if (m.x + m.w <= base.x)    return "auto-left";
        if (m.y >= base.y + base.h) return "auto-down";
        if (m.y + m.h <= base.y)    return "auto-up";
        return "auto";
    }

    function resList(m) {
        var seen = {}, out = [];
        (m.modes || []).forEach(s => {
            var r = s.split("@")[0];
            if (!seen[r]) { seen[r] = true; out.push(r); }
        });
        if (!out.length) out.push(m.w + "x" + m.h);
        return out;
    }

    function rrList(m, res) {
        var out = [];
        (m.modes || []).forEach(s => {
            var p = s.split("@");
            if (p[0] !== res) return;
            var hz = parseFloat(p[1]);
            if (out.indexOf(hz) < 0) out.push(hz);
        });
        if (!out.length) out.push(m.rr);
        return out.sort((a, b) => b - a);
    }

    // ------------------------------------------------------------- Dynamic Island (Pill)
    SetCard {
        sys: page.sys
        visible: page.mons.length > 1

        SetLabel {
            sys: page.sys
            text: (page.sys && page.sys.isPt) ? "Dynamic Island (Pill)" : page.sys.tr("Динамический остров")
        }

        SetPick {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Exibir na tela" : page.sys.tr("Показывать на экране")
            options: [
                { id: "auto", text: (page.sys && page.sys.isPt) ? "Seguir o foco (onde você estiver)" : page.sys.tr("За фокусом") },
                { id: "primary", text: (page.sys && page.sys.isPt) ? "Sempre na tela principal" : "На главном экране" }
            ].concat(
                page.mons.map(m => ({
                    id: m.name,
                    text: m.name + (m.desc.length ? " · " + m.desc : "")
                })))
            value: page.sys.cfg.pillScreen || "auto"
            onPicked: id => { page.sys.cfg.pillScreen = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "Em «Seguir o foco», a pill acompanha a tela onde seu cursor ou janela ativa estiver (em telas estendidas). Quando houver espelhamento, ela permanece ancorada de forma limpa na tela principal sem sumir nem duplicar."
                  : page.sys.tr("«За фокусом» — остров переезжает на тот экран, где вы сейчас работаете.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.mons.length === 0
        text: (page.sys && page.sys.isPt)
              ? "Nenhum monitor detectado pelo compositor."
              : page.sys.tr("Экраны не читаются: hyprctl не ответил.")
        color: page.sys.colMuted
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }

    // ------------------------------------------------------------- Lista de Monitores
    Repeater {
        model: page.mons

        SetCard {
            id: card
            required property var modelData
            required property int index
            readonly property string res: card.modelData.w + "x" + card.modelData.h
            readonly property bool isPrimary: page.isPrimary(card.modelData.name)
            readonly property string mirrorTarget: page.getMirror(card.modelData)
            readonly property bool isMirror: mirrorTarget.length > 0

            sys: page.sys

            // Header com Nome, Descrição e Badge de Principal
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        spacing: 8
                        Text {
                            text: card.modelData.name
                            color: page.sys.colFg
                            font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize; bold: true }
                        }

                        // Badge de Tela Principal
                        Rectangle {
                            visible: card.isPrimary
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: primaryBadgeTxt.implicitWidth + 14
                            radius: 6
                            color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                            border.color: page.sys.colOn
                            border.width: 1
                            Text {
                                id: primaryBadgeTxt
                                anchors.centerIn: parent
                                text: "★ " + ((page.sys && page.sys.isPt) ? "Principal" : "Primary")
                                color: page.sys.colOn
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4; bold: true }
                            }
                        }

                        // Botão para tornar Principal
                        Rectangle {
                            visible: !card.isPrimary && page.mons.length > 1
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: makePriTxt.implicitWidth + 14
                            radius: 6
                            color: priMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                            Text {
                                id: makePriTxt
                                anchors.centerIn: parent
                                text: (page.sys && page.sys.isPt) ? "Tornar Principal" : "Make Primary"
                                color: page.sys.colFg
                                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            }
                            MouseArea {
                                id: priMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setPrimary(card.modelData.name)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.modelData.desc.length > 0
                        text: card.modelData.desc
                        color: page.sys.colMuted
                        elide: Text.ElideRight
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }
                }

                Text {
                    text: card.res + " · " + Number(card.modelData.rr).toFixed(0) + " Hz"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }
            }

            // Modo da Tela: Expandir vs Espelhar (quando há múltiplos monitores)
            SetSelect {
                sys: page.sys
                visible: page.mons.length > 1
                label: (page.sys && page.sys.isPt) ? "Modo de Exibição" : page.sys.tr("Режим экрана")
                options: [
                    { id: "extend", text: (page.sys && page.sys.isPt) ? "Expandir (Estender área de trabalho)" : page.sys.tr("Расширить") },
                    { id: "mirror", text: (page.sys && page.sys.isPt) ? "Espelhar (Duplicar exibição)" : page.sys.tr("Дублировать") }
                ]
                value: card.isMirror ? "mirror" : "extend"
                onPicked: id => {
                    if (id === "mirror") {
                        var others = page.otherMons(card.modelData.name);
                        var tgt = others.length ? others[0].name : "";
                        if (tgt) page.apply(card.modelData, { mirror: tgt, pos: "auto" });
                    } else {
                        page.apply(card.modelData, { mirror: "", pos: "auto-right" });
                    }
                }
            }

            // Se estiver espelhado: Selecionar qual tela espelhar
            SetPick {
                sys: page.sys
                visible: page.mons.length > 1 && card.isMirror
                label: (page.sys && page.sys.isPt) ? "Espelhar qual tela" : "Дублировать экран"
                options: page.otherMons(card.modelData.name).map(o => ({
                    id: o.name,
                    text: o.name + (o.desc.length ? " · " + o.desc : "")
                }))
                value: card.mirrorTarget
                onPicked: id => page.apply(card.modelData, { mirror: id, pos: "auto" })
            }

            // Se for estendido e não for a tela principal: Posicionamento Relativo
            SetSelect {
                sys: page.sys
                visible: page.mons.length > 1 && !card.isMirror && !card.isPrimary
                label: (page.sys && page.sys.isPt) ? "Posicionamento da tela" : (page.sys.tr("Расположение") + (page.mons.length > 1 ? " — " + page.sys.tr("относительно") + " " + page.mons[0].name : ""))
                options: [
                    { id: "auto-right", text: (page.sys && page.sys.isPt) ? "À direita da principal" : page.sys.tr("Справа от") },
                    { id: "auto-left",  text: (page.sys && page.sys.isPt) ? "À esquerda da principal" : page.sys.tr("Слева от") },
                    { id: "auto-up",    text: (page.sys && page.sys.isPt) ? "Acima da principal" : page.sys.tr("Над") },
                    { id: "auto-down",  text: (page.sys && page.sys.isPt) ? "Abaixo da principal" : page.sys.tr("Под") }
                ]
                value: page.placeOf(card.modelData)
                onPicked: id => page.apply(card.modelData, { pos: id, mirror: "" })
            }

            // Resolução
            SetPick {
                sys: page.sys
                label: (page.sys && page.sys.isPt) ? "Resolução" : page.sys.tr("Разрешение")
                options: page.resList(card.modelData)
                value: card.res
                onPicked: id => {
                    var wh = id.split("x");
                    var hz = page.rrList(card.modelData, id)[0];
                    page.apply(card.modelData, { w: +wh[0], h: +wh[1], rr: hz });
                }
            }

            // Taxa de atualização
            SetPick {
                sys: page.sys
                label: (page.sys && page.sys.isPt) ? "Taxa de atualização" : page.sys.tr("Частота обновления")
                options: page.rrList(card.modelData, card.res).map(hz => ({
                    id: String(hz), text: hz.toFixed(2) + " Hz"
                }))
                value: String(page.rrList(card.modelData, card.res)
                              .find(hz => Math.abs(hz - card.modelData.rr) < 0.6)
                              || card.modelData.rr)
                onPicked: id => page.apply(card.modelData, { rr: parseFloat(id) })
            }

            Text {
                Layout.fillWidth: true
                visible: (card.modelData.modes || []).length === 0
                text: (page.sys && page.sys.isPt)
                      ? "O monitor não informou modos disponíveis — verifique o cabo ou driver de vídeo."
                      : page.sys.tr("Монитор не сообщил свои режимы — обычно это значит, что не установлен драйвер видеокарты.")
                color: page.sys.colCrit
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            // Brilho (se suportado)
            SetSlider {
                id: brightSl
                readonly property var b: page.brightOf(card.modelData.name)
                sys: page.sys
                visible: brightSl.b !== null
                label: (page.sys && page.sys.isPt) ? "Brilho" : page.sys.tr("Яркость")
                from: 1; to: 100; step: 1
                value: brightSl.b ? brightSl.b.pct : 0
                suffix: "%"
                onMoved: v => { if (brightSl.b) page.sys.brightSet(brightSl.b.id, v); }
            }

            Text {
                Layout.fillWidth: true
                visible: page.brightOf(card.modelData.name) === null && !page.sys.batteryPresent
                text: !page.sys.ddcutilPresent
                      ? ((page.sys && page.sys.isPt)
                         ? "Brilho externo via DDC/CI requer o pacote 'ddcutil'."
                         : page.sys.tr("Яркостью монитора управляет ddcutil — его нет в системе. Поставьте пакет ddcutil, и ползунок появится здесь."))
                      : ((page.sys && page.sys.isPt)
                         ? "O monitor não respondeu ao comando DDC/CI (ative DDC/CI no menu físico do monitor)."
                         : page.sys.tr("Монитор не отвечает на запрос яркости по DDC/CI. Обычно это включается в его меню пунктом DDC/CI."))
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            // Intensidade digital (no primeiro monitor / tela principal)
            SetSlider {
                sys: page.sys
                visible: card.isPrimary || card.index === 0
                label: (page.sys && page.sys.isPt) ? "Intensidade digital (Saturação)" : page.sys.tr("Цифровая интенсивность")
                from: 0; to: 100; step: 5
                value: page.sys.cfg.vibrance
                suffix: "%"
                onMoved: v => page.sys.applyVibrance(v)
            }

            // Escala com Presets
            SetSlider {
                sys: page.sys
                label: (page.sys && page.sys.isPt) ? "Escala da interface (Zoom)" : page.sys.tr("Масштаб")
                from: 1; to: 2.5; step: 0.05
                decimals: 2
                value: card.modelData.scale
                suffix: "×"
                onMoved: v => page.apply(card.modelData, { scale: v })
            }

            // Botões de Escala Rápida (100%, 125%, 150%, 175%, 200%)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { s: 1.0, label: "100%" },
                        { s: 1.25, label: "125%" },
                        { s: 1.5, label: "150%" },
                        { s: 1.75, label: "175%" },
                        { s: 2.0, label: "200%" }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 8
                        readonly property bool active: Math.abs(card.modelData.scale - modelData.s) < 0.03
                        color: active ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.24)
                                      : (sMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: active ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.active ? page.sys.colOn : page.sys.colFg
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: parent.active }
                        }
                        MouseArea {
                            id: sMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.apply(card.modelData, { scale: parent.modelData.s })
                        }
                    }
                }
            }

            // Rotação / Orientação
            SetSelect {
                sys: page.sys
                label: (page.sys && page.sys.isPt) ? "Orientação / Rotação" : page.sys.tr("Поворот")
                options: [
                    { id: "0", text: (page.sys && page.sys.isPt) ? "0° (Padrão)" : "0°" },
                    { id: "1", text: (page.sys && page.sys.isPt) ? "90° (Vertical)" : "90°" },
                    { id: "2", text: (page.sys && page.sys.isPt) ? "180° (Invertido)" : "180°" },
                    { id: "3", text: (page.sys && page.sys.isPt) ? "270° (Vertical invertido)" : "270°" }
                ]
                value: String(card.modelData.transform)
                onPicked: id => page.apply(card.modelData, { transform: +id })
            }
        }
    }

    // Detecção e Atualização de Telas
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: (page.sys && page.sys.isPt) ? "Detectar Monitores" : page.sys.tr("Обнаружить экраны")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: (page.sys && page.sys.isPt)
                          ? "Reconectar saídas de vídeo e atualizar a lista de monitores."
                          : page.sys.tr("Перечитать список подключённых мониторов.")
                    color: page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            Rectangle {
                Layout.preferredWidth: 124
                Layout.preferredHeight: 32
                radius: 10
                color: detectMa.containsMouse
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: (page.sys && page.sys.isPt) ? "Atualizar" : page.sys.tr("Обновить")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3; bold: true }
                }
                MouseArea {
                    id: detectMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pMons.running = false; pMons.running = true; }
                }
            }
        }
    }
}
