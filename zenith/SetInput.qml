import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Mouse. The pointer speed and overclocking are controlled by libinput via
// the linker, not the shell, so there are only two handles, but those
// the ones that people usually go into the config with their hands.
//
// The keyboard is not included here intentionally: layouts and repeat live in the system
// settings in Hyprland, and combinations in their own window via Super+/.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys
        visible: Compositor.isHyprland

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Disposição do Teclado (Layouts)" : page.sys.tr("Раскладки клавиатуры") }
        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "Selecione um preset rápido ou configure códigos XKB. Alterne o layout com Alt+Shift (ou configure abaixo)."
                  : page.sys.tr("Коды XKB через запятую, например us,tr. Сочетания клавиш меняются отдельно по Super+/.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Presets rápidos (1-clique para ABNT2 Brasil, US, etc.)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SetButton {
                sys: page.sys
                text: "[BR] ABNT2 (Brasil)"
                primary: layoutsField.text === "br" && variantsField.text === "abnt2"
                onClicked: {
                    layoutsField.text = "br";
                    variantsField.text = "abnt2";
                    modelField.text = "abnt2";
                    page.sys.applyKeyboardLayouts("br", "abnt2", optionsField.text, "abnt2");
                }
            }

            SetButton {
                sys: page.sys
                text: "[BR+US] ABNT2 + US"
                primary: layoutsField.text === "br,us"
                onClicked: {
                    layoutsField.text = "br,us";
                    variantsField.text = "abnt2,";
                    modelField.text = "abnt2";
                    page.sys.applyKeyboardLayouts("br,us", "abnt2,", optionsField.text, "abnt2");
                }
            }

            SetButton {
                sys: page.sys
                text: "[US+BR] US + ABNT2"
                primary: layoutsField.text === "us,br"
                onClicked: {
                    layoutsField.text = "us,br";
                    variantsField.text = ",abnt2";
                    modelField.text = "abnt2";
                    page.sys.applyKeyboardLayouts("us,br", ",abnt2", optionsField.text, "abnt2");
                }
            }

            SetButton {
                sys: page.sys
                text: "[US] US Intl"
                primary: layoutsField.text === "us" && variantsField.text === "intl"
                onClicked: {
                    layoutsField.text = "us";
                    variantsField.text = "intl";
                    modelField.text = "";
                    page.sys.applyKeyboardLayouts("us", "intl", optionsField.text, "");
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: (page.sys && page.sys.isPt) ? "Layouts (ex: br,us):" : "Layouts:"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                TextField {
                    id: layoutsField
                    Layout.fillWidth: true
                    placeholderText: "br,us"
                    text: page.sys.cfg.keyboardLayouts || "br,us"
                    color: page.sys.colFg
                    placeholderTextColor: page.sys.colMuted
                    selectByMouse: true
                    selectionColor: page.sys.colOn
                    leftPadding: 8; rightPadding: 8; topPadding: 6; bottomPadding: 6
                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                        border.color: layoutsField.activeFocus ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                    }
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: (page.sys && page.sys.isPt) ? "Variantes (ex: abnt2,):" : "Variants:"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                TextField {
                    id: variantsField
                    Layout.fillWidth: true
                    placeholderText: "abnt2,"
                    text: page.sys.cfg.keyboardVariants || "abnt2,"
                    color: page.sys.colFg
                    placeholderTextColor: page.sys.colMuted
                    selectByMouse: true
                    selectionColor: page.sys.colOn
                    leftPadding: 8; rightPadding: 8; topPadding: 6; bottomPadding: 6
                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                        border.color: variantsField.activeFocus ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                    }
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: (page.sys && page.sys.isPt) ? "Modelo (ex: abnt2):" : "Model:"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                TextField {
                    id: modelField
                    Layout.fillWidth: true
                    placeholderText: "abnt2"
                    text: page.sys.cfg.keyboardModel || "abnt2"
                    color: page.sys.colFg
                    placeholderTextColor: page.sys.colMuted
                    selectByMouse: true
                    selectionColor: page.sys.colOn
                    leftPadding: 8; rightPadding: 8; topPadding: 6; bottomPadding: 6
                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                        border.color: modelField.activeFocus ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                    }
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: (page.sys && page.sys.isPt) ? "Opção de Troca:" : "Switch Option:"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
                TextField {
                    id: optionsField
                    Layout.fillWidth: true
                    placeholderText: "grp:alt_shift_toggle"
                    text: page.sys.cfg.keyboardOptions || "grp:alt_shift_toggle"
                    color: page.sys.colFg
                    placeholderTextColor: page.sys.colMuted
                    selectByMouse: true
                    selectionColor: page.sys.colOn
                    leftPadding: 8; rightPadding: 8; topPadding: 6; bottomPadding: 6
                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                        border.color: optionsField.activeFocus ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                    }
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.keyboardInputError.length > 0
            text: page.sys.keyboardInputError
            color: page.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetButton {
            sys: page.sys
            primary: true
            text: (page.sys && page.sys.isPt) ? "Salvar e Aplicar Teclado" : page.sys.tr("Применить раскладки")
            onClicked: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text, modelField.text)
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Compositor.isNiri
        text: page.sys.tr("В Niri раскладки задаются в ~/.config/niri/config.kdl; этот файл сохраняется при обновлении.")
        color: page.sys.colMuted
        wrapMode: Text.WordWrap
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Ponteiro do Mouse" : page.sys.tr("Указатель") }

        // libinput scale: -1 - slowest, 0 - as is, 1 - fastest
        SetSlider {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Velocidade do Ponteiro" : page.sys.tr("Скорость указателя")
            from: -1; to: 1; step: 0.05
            decimals: 2
            value: page.sys.cfg.mouseSens
            onMoved: v => { page.sys.cfg.mouseSens = v; page.sys.applyInput(); }
        }

        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "0 — velocidade padrão do sensor do mouse. Esquerda mais lento, direita mais rápido."
                  : page.sys.tr("0 — скорость как её отдаёт мышь. Влево медленнее, вправо быстрее.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Entrada Direta (Sem Aceleração)" : page.sys.tr("Прямой ввод")
            sub: (page.sys && page.sys.isPt)
                 ? "Sem curva de aceleração: a mesma distância no mousepad sempre produz o mesmo deslocamento na tela (ideal para jogos)."
                 : page.sys.tr("Без разгона: одно и то же движение по столу всегда даёт одно и то же расстояние по экрану. То, ради чего в играх выключают повышенную точность указателя.")
            on: page.sys.cfg.mouseRaw
            onToggled: v => { page.sys.cfg.mouseRaw = v; page.sys.applyInput(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Restaurar" : page.sys.tr("Сброс") }

        SetButton {
            sys: page.sys
            text: (page.sys && page.sys.isPt) ? "Restaurar Padrões" : page.sys.tr("Вернуть заводские")
            onClicked: {
                page.sys.cfg.mouseSens = 0;
                page.sys.cfg.mouseRaw = false;
                page.sys.applyInput();
            }
        }
    }
}
