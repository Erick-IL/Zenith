import QtQuick
import QtQuick.Layouts

// Motion. Durations live separately because they are ruled by different things: movement
// islands, color development and response to pointing interfere at one “speed”
// animation" is not possible - this either slows down the panel or causes the backlight to twitch.
ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Уменьшить анимацию")
            sub: page.sys.tr("Оболочка перестаёт двигаться совсем: длительности считаются нулевыми.")
            on: page.sys.cfg.reduceMotion
            onToggled: value => { page.sys.cfg.reduceMotion = value; page.sys.saveCfg(); }
        }

        // When the movement is turned off, we do not hide the sliders, but turn them off: otherwise
        // the card collapses and the settings seem to disappear forever.
        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Движение (размер и положение)")
            from: 80; to: 900; step: 10
            value: page.sys.cfg.animMove
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animMove = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Плавное появление и цвет")
            from: 40; to: 600; step: 10
            value: page.sys.cfg.animFade
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animFade = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Реакция на наведение")
            from: 20; to: 400; step: 10
            value: page.sys.cfg.animHover
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animHover = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Отскок")
            from: 0; to: 100; step: 1
            value: page.sys.cfg.animBounce
            suffix: "%"
            onMoved: v => { page.sys.cfg.animBounce = v; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.detailsOpen
            text: page.sys.tr("Bounce — насколько смоделированный осциллятор перелетает цель, прежде чем осесть на ней.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
