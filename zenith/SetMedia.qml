import QtQuick
import QtQuick.Layouts

// Media. There are few settings here: the player is either there or not, and everything else
// - what exactly does it show in the folded island.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Плеер") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Страница медиа")
            sub: page.sys.tr("Обложка, перемотка и переключение источника звука.")
            on: page.sys.cfg.featMedia
            onToggled: v => { page.sys.cfg.featMedia = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Что играет — в свёрнутом острове")
            on: page.sys.cfg.featPlayer
            onToggled: v => { page.sys.cfg.featPlayer = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звук") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Громкость и устройства")
            on: page.sys.cfg.featAudio
            onToggled: v => { page.sys.cfg.featAudio = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Показывать всплеск при смене громкости")
            sub: page.sys.tr("Полоска поверх экрана на клавиши громкости и яркости.")
            on: page.sys.cfg.featOsd
            onToggled: v => { page.sys.cfg.featOsd = v; page.sys.saveCfg(); }
        }
    }

    // There are no recording settings here intentionally: frame rate, system sound
    // and the microphone are adjusted directly on the recording page, where they can be seen during
    // work. A double in the settings would only diverge from it.
}
