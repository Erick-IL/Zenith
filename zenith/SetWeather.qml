import QtQuick
import QtQuick.Layouts

// Weather. The data is taken from OpenWeatherMap, and everyone has their own key to it:
// it's free, but it's sent by email and linked to your account, so
// It is impossible to enter here a general one for everyone.
//
// The page is needed only for desktop widgets - more weather in the shell
// there is nowhere to show it - and this is said directly, so as not to look for where it is
// will appear after filling out the fields.
ColumnLayout {
    id: page

    property var sys

    // Reason for refusal in words. The codes come from scripts/weather.sh; here them
    // the only place of translation into human speech.
    function errText(e) {
        return e === "no-key"        ? page.sys.tr("Ключ не вписан")
             : e === "no-city"       ? page.sys.tr("Город не вписан")
             : e === "bad-key"       ? page.sys.tr("Ключ не подошёл — проверьте, что скопирован целиком")
             : e === "no-such-city"  ? page.sys.tr("Такого города сервис не знает")
             : e === "rate-limit"    ? page.sys.tr("Слишком часто спрашиваем — ключ на пределе обращений")
             : e === "network"       ? page.sys.tr("Не дозвонились до сервиса")
             : e === "no-curl"       ? page.sys.tr("Нет curl")
             : e === "no-jq"         ? page.sys.tr("Нет jq")
             : e === "bad-answer"    ? page.sys.tr("Ответ сервиса не разобрать")
             : page.sys.tr("Сервис ответил отказом") + " (" + e + ")";
    }

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- key
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Ключ OpenWeatherMap") }

        // The key is hidden in dots. He opens someone else's paid account, and the window
        // settings are opened both in front of strangers and with the demonstration turned on
        // screen - there is no need to show it every time you look here
        // change city.
        //
        // The eye button next to it is required: 32 characters entered blindly are useless
        // check, and “the key did not fit” looks the same even if there is a typo,
        // and when the key is not activated.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            property bool shown: false

            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 12
                // space for the button on the right
                anchors.rightMargin: 38
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherKey
                echoMode: parent.shown ? TextInput.Normal : TextInput.Password
                // Dots, not asterisks: asterisk in monospace font
                // sits above the middle of the row, and a row of them looks
                // superscript.
                passwordCharacter: "•"
                // We show the whole thing at once, without the last one running through
                // sign: the key is inserted from the buffer, and not typed by hand.
                passwordMaskDelay: 0
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherKey = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: keyInput.text.length === 0
                    text: page.sys.tr("Строка из 32 знаков со страницы API keys")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: keyInput.font
                }
            }

            Text {
                id: eye
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(parent.shown ? 0xF0209 : 0xF0208)
                color: eyeMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.iconSize - 2 }
                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: eyeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: eye.parent.shown = !eye.parent.shown
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Заводится на openweathermap.org — бесплатно. Новый ключ начинает отвечать не сразу, обычно через час-другой.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // It’s said directly: the key is in settings.json as it is. A person has the right
        // know this before you enter it, and not find out later.
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Хранится в settings.json открытым текстом.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------ city
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Город") }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            TextInput {
                id: cityInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherCity
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherCity = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: cityInput.text.length === 0
                    text: page.sys.tr("Название или индекс: Moscow,RU или 101000")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: cityInput.font
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Годится и почтовый индекс — сплошные цифры оболочка отличает от названия сама и без страны считает российскими. Одинаковых названий на свете много: если нашёлся не тот город, допишите через запятую страну — Moscow,RU. По названию сервис ищет надёжнее, чем по индексу.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Separate from desktop widgets: the island is always visible, but the table
        // closed with windows, and they are not turned on at the same time.
        SetToggle {
            sys: page.sys
            label: page.sys.tr("Погода в острове")
            sub: page.sys.tr("Значок и градусы в свёрнутом острове, рядом с рабочими столами.")
            on: page.sys.cfg.weatherOnIsland
            onToggled: v => {
                page.sys.cfg.weatherOnIsland = v;
                page.sys.saveCfg();
                if (v) page.sys.refreshWeather();
            }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Шкала")
            options: [
                { id: "metric",   text: page.sys.tr("Цельсий") },
                { id: "imperial", text: page.sys.tr("Фаренгейт") }
            ]
            value: page.sys.cfg.weatherUnits
            onPicked: id => {
                page.sys.cfg.weatherUnits = id;
                page.sys.saveCfg();
                page.sys.refreshWeather();
            }
        }
    }

    // ---------------------------------------------------------- check
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сейчас") }

        Text {
            Layout.fillWidth: true
            text: page.sys.weatherBusy
                  ? page.sys.tr("Спрашиваем…")
                  : page.sys.weatherErr.length
                    ? page.errText(page.sys.weatherErr)
                    : page.sys.weatherReady
                      ? page.sys.weatherPlace + " · " + page.sys.weatherTemp + "°"
                        + page.sys.weatherUnitLetter + " · " + page.sys.weatherDesc
                      : page.sys.tr("Ещё не спрашивали")
            color: page.sys.weatherErr.length ? page.sys.colCrit : page.sys.colFg
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.weatherReady
            text: page.sys.tr("Влажность") + " " + page.sys.weatherHumidity + "% · "
                  + page.sys.tr("Ветер") + " " + page.sys.weatherWind + " "
                  + page.sys.weatherWindUnit + " · "
                  + page.sys.tr("Ощущается как") + " " + page.sys.weatherFeels + "°"
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Обновить")
                primary: true
                enabled: !page.sys.weatherBusy
                onClicked: page.sys.refreshWeather()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Сама оболочка спрашивает погоду раз в четверть часа. Показывается она в настольных виджетах — включаются во вкладке Appearance.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
