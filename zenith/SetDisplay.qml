import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Display. There is no screen layout here intentionally: it is moved with the mouse
// on the desktop itself, but they come here for numbers - resolution, frequency
// and scale. Settings are applied to one screen at once, without a common button:
// Otherwise, it is not clear what exactly will be applied.
ColumnLayout {
    id: page

    property var sys

    // [{ name, desc, w, h, rr, scale, transform, vrr, x, y, modes: [] }]
    property var mons: []

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pMons.running = true; page.sys.brightRefresh(false); }

    // Screen brightness. On a laptop this is the internal matrix, on a PC it is the monitor itself
    // according to DDC/CI; we combine the line from brightness.sh with a card by the name of the connector.
    // The built-in matrix has only one connector in the list and has nothing to match with,
    // Therefore, we give the single line to the single screen as is.
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
                    // StdioCollector accumulates output between runs, so it
                    // there may be several answers in a row in the text - let’s sort it out
                    // the last one, starting from the final "[".
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
                        modes: m.availableModes || []
                    }));
                } catch (e) {
                    page.mons = [];
                }
            }
        }
    }

    // We apply it through the shell: the setting is also remembered there so that
    // survive hyprctl reload and reboot - Hyprland itself does not store it.
    function apply(m, over) {
        page.sys.monApply(m.name, {
            w:  over.w  !== undefined ? over.w  : m.w,
            h:  over.h  !== undefined ? over.h  : m.h,
            rr: over.rr !== undefined ? over.rr : m.rr,
            scale: over.scale !== undefined ? over.scale : m.scale,
            transform: over.transform !== undefined ? over.transform : m.transform,
            vrr: m.vrr,
            // We always transfer the current position, not “auto”: otherwise change
            // resolution would reassemble the layout and the monitor would go away.
            pos: over.pos !== undefined ? over.pos : page.placeOf(m)
        });
        reload.restart();
    }

    Timer {
        id: reload
        interval: 700
        onTriggered: { pMons.running = false; pMons.running = true; }
    }

    // Where is the screen placed relative to the first one? We read from live coordinates,
    // rather than remembering the choice: the layout could have been changed without this window.
    function placeOf(m) {
        var base = page.mons.length ? page.mons[0] : null;
        if (!base || base.name === m.name) return "auto";
        if (m.x >= base.x + base.w) return "auto-right";
        if (m.x + m.w <= base.x)    return "auto-left";
        if (m.y >= base.y + base.h) return "auto-down";
        if (m.y + m.h <= base.y)    return "auto-up";
        return "auto";
    }

    // resolution and frequency are pulled out from the list of modes “1920x1080@144.00Hz”
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

    // ------------------------------------------------------------- island
    // On which screen should the island be shown? One screen - no card needed,
    // there is still no choice.
    SetCard {
        sys: page.sys
        visible: page.mons.length > 1

        SetLabel {
            sys: page.sys
            text: page.sys.tr("Динамический остров")
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Показывать на экране")
            options: [{ id: "auto", text: page.sys.tr("За фокусом") }].concat(
                page.mons.map(m => ({
                    id: m.name,
                    text: m.name + (m.desc.length ? " · " + m.desc : "")
                })))
            value: page.sys.cfg.pillScreen
            onPicked: id => { page.sys.cfg.pillScreen = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("«За фокусом» — остров переезжает на тот экран, где вы сейчас работаете.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.mons.length === 0
        text: page.sys.tr("Экраны не читаются: hyprctl не ответил.")
        color: page.sys.colMuted
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }

    Repeater {
        model: page.mons

        SetCard {
            id: card
            required property var modelData
            required property int index
            readonly property string res: card.modelData.w + "x" + card.modelData.h

            sys: page.sys

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: card.modelData.name
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize }
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

            SetPick {
                sys: page.sys
                label: page.sys.tr("Разрешение")
                options: page.resList(card.modelData)
                value: card.res
                onPicked: id => {
                    var wh = id.split("x");
                    // frequency from the old mode may not be supported by the new one
                    // resolution - take the highest available for it
                    var hz = page.rrList(card.modelData, id)[0];
                    page.apply(card.modelData, { w: +wh[0], h: +wh[1], rr: hz });
                }
            }

            SetPick {
                sys: page.sys
                label: page.sys.tr("Частота обновления")
                options: page.rrList(card.modelData, card.res).map(hz => ({
                    id: String(hz), text: hz.toFixed(2) + " Hz"
                }))
                value: String(page.rrList(card.modelData, card.res)
                              .find(hz => Math.abs(hz - card.modelData.rr) < 0.6)
                              || card.modelData.rr)
                onPicked: id => page.apply(card.modelData, { rr: parseFloat(id) })
            }

            // An empty mode list means that the monitor's EDID has not been read:
            // the video card runs on a generalized driver, and the system knows
            // only the mode in which it is already sitting. Usually it is 60 Hz at
            // monitor that can do more - and without explanation it looks
            // as a breakdown of the settings, and not as a missing driver.
            Text {
                Layout.fillWidth: true
                visible: (card.modelData.modes || []).length === 0
                text: page.sys.tr("Монитор не сообщил свои режимы — обычно это значит, "
                                  + "что не установлен драйвер видеокарты.")
                color: page.sys.colCrit
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            // Layout. The first screen is the starting point, the rest stand up
            // regarding him; so the very first choice has no choice.
            SetSelect {
                sys: page.sys
                visible: page.mons.length > 1 && card.index > 0
                label: page.sys.tr("Расположение") + (page.mons.length > 1
                       ? " — " + page.sys.tr("относительно") + " " + page.mons[0].name : "")
                options: [
                    { id: "auto-right", text: page.sys.tr("Справа от") },
                    { id: "auto-left",  text: page.sys.tr("Слева от") },
                    { id: "auto-up",    text: page.sys.tr("Над") },
                    { id: "auto-down",  text: page.sys.tr("Под") }
                ]
                value: page.placeOf(card.modelData)
                onPicked: id => page.apply(card.modelData, { pos: id })
            }

            // Brightness. On a PC, there are usually no brightness keys on the keyboard, and up to
            // today it was possible to turn it only with the buttons on the
            // monitor - that's why the slider is here, and not just on the keys.
            SetSlider {
                id: brightSl
                readonly property var b: page.brightOf(card.modelData.name)
                sys: page.sys
                visible: brightSl.b !== null
                label: page.sys.tr("Яркость")
                from: 1; to: 100; step: 1
                value: brightSl.b ? brightSl.b.pct : 0
                suffix: "%"
                onMoved: v => { if (brightSl.b) page.sys.brightSet(brightSl.b.id, v); }
            }

            // The monitor on the bus is visible, but does not respond to the brightness request, or
            // ddcutil is not installed at all. You cannot hide the slider silently:
            // a person will look for a setting that is not there for a reason, oh
            // which no one told him.
            Text {
                Layout.fillWidth: true
                visible: page.brightOf(card.modelData.name) === null
                         && !page.sys.batteryPresent
                text: !page.sys.ddcutilPresent
                      ? page.sys.tr("Яркостью монитора управляет ddcutil — его нет в системе. "
                                    + "Поставьте пакет ddcutil, и ползунок появится здесь.")
                      : page.sys.tr("Монитор не отвечает на запрос яркости по DDC/CI. "
                                    + "Обычно это включается в его меню пунктом DDC/CI.")
                color: page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            // Digital intensity is immediately below brightness: both are about
            // what the picture looks like, and spin them in a row. The scale is intentionally
            // the same as in the NVIDIA panel on Windows: 50 - as is, 100 -
            // maximum. There is only one setting for the whole picture, not for the screen:
            // it is calculated by the compositor on the finished frame, and not by the video card on
            // output - that’s why the second monitor does not have a slider.
            SetSlider {
                sys: page.sys
                visible: card.index === 0
                label: page.sys.tr("Цифровая интенсивность")
                from: 0; to: 100; step: 5
                value: page.sys.cfg.vibrance
                suffix: "%"
                onMoved: v => page.sys.applyVibrance(v)
            }

            SetSlider {
                sys: page.sys
                label: page.sys.tr("Масштаб")
                from: 1; to: 3; step: 0.05
                decimals: 2
                value: card.modelData.scale
                suffix: "×"
                onMoved: v => page.apply(card.modelData, { scale: v })
            }

            SetSelect {
                sys: page.sys
                label: page.sys.tr("Поворот")
                options: [
                    { id: "0", text: "0°" },
                    { id: "1", text: "90°" },
                    { id: "2", text: "180°" },
                    { id: "3", text: "270°" }
                ]
                value: String(card.modelData.transform)
                onPicked: id => page.apply(card.modelData, { transform: +id })
            }

        }
    }

    // Recalculate the list of screens: plugged in or removed the cable - Hyprland has already
    // knows, but the settings window is not there yet.
    SetCard {
        sys: page.sys

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: page.sys.tr("Обнаружить экраны")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 1 }
                }
                Text {
                    Layout.fillWidth: true
                    text: page.sys.tr("Перечитать список подключённых мониторов.")
                    color: page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 32
                radius: 10
                color: detectMa.containsMouse
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.28)
                       : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: page.sys.tr("Обновить")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
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
