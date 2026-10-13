import QtQuick
import QtQuick.Layouts

// Notifications. The main thing here is “do not disturb” and the card’s lifetime.
// By default, important notifications do not go away on their own: they are answered.
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
            label: page.sys.tr("Служба уведомлений")
            sub: page.sys.tr("Выключить, если в системе уже стоит свой демон уведомлений.")
            on: page.sys.cfg.featNotifications
            onToggled: v => { page.sys.cfg.featNotifications = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Som de notificação" : page.sys.tr("Звук уведомлений")
            sub: (page.sys && page.sys.isPt)
                 ? "Tocar efeito sonoro ao receber novas notificações."
                 : page.sys.tr("Воспроизводить звук при поступлении уведомления.")
            on: page.sys.cfg.notifSound !== false
            onToggled: v => { page.sys.cfg.notifSound = v; page.sys.saveCfg(); if (v) page.sys.playSound("notification"); }
        }

        // “Do not disturb” is toggled with a button in quick settings -
        // This is a state for every day, not a setting.
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Время и количество") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Сколько висит обычное")
            from: 1000; to: 20000; step: 500
            value: page.sys.cfg.notifTimeout
            valueText: (page.sys.cfg.notifTimeout / 1000).toFixed(1) + " s"
            onMoved: v => { page.sys.cfg.notifTimeout = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Сколько висит важное")
            visible: page.detailsOpen
            from: 0; to: 60000; step: 1000
            value: page.sys.cfg.notifCritTimeout
            // zero - the card does not go out on its own, and this must be said in a word
            valueText: page.sys.cfg.notifCritTimeout === 0
                       ? page.sys.tr("до ответа")
                       : (page.sys.cfg.notifCritTimeout / 1000).toFixed(0) + " s"
            onMoved: v => { page.sys.cfg.notifCritTimeout = v; page.sys.saveCfg(); }
        }

        SetButton {
            sys: page.sys
            text: page.detailsOpen ? page.sys.tr("Скрыть подробности") : page.sys.tr("Подробные настройки")
            onClicked: page.detailsOpen = !page.detailsOpen
        }

    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Содержимое") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Показывать текст в карточке")
            sub: page.sys.tr("Выключено — видно только приложение и заголовок.")
            on: page.sys.cfg.notifPreview
            onToggled: v => { page.sys.cfg.notifPreview = v; page.sys.saveCfg(); }
        }

    }
}
