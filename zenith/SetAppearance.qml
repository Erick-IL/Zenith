import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Appearance. The theme sets the palette for the entire shell and nothing else
// depends: the wallpaper changes on its own, the color on its own.
ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: true
    property var localeOptions: [{ id: "pt_BR", text: "Português (Brasil)" }, { id: "en", text: "English" }, { id: "ru", text: "Русский" }, { id: "tr", text: "Türkçe" }]

    Process {
        command: [page.sys.scriptDir + "/locale.sh", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var options = [];
                var lines = String(text).trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length !== 2 || !parts[0].length) continue;
                    var locale = Qt.locale(parts[0]);
                    var nativeName = locale && locale.name !== "C" ? locale.nativeLanguageName : "";
                    options.push({ id: parts[0], text: nativeName ? nativeName + " · " + parts[0] : parts[1] });
                }
                if (options.length) page.localeOptions = options;
            }
        }
    }
    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- Idioma do Sistema
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Idioma do Sistema" : page.sys.tr("Язык") }

        SetPick {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Idioma da interface" : page.sys.tr("Язык системы")
            options: page.localeOptions
            searchable: true
            value: page.sys.cfg.lang
            onPicked: id => page.sys.setLang(id)
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.sysLangPending
                  ? ((page.sys && page.sys.isPt) ? "Alterando idioma do sistema…" : page.sys.tr("Меняем язык системы…"))
                  : (!page.sys.systemLocaleMatches
                     ? ((page.sys && page.sys.isPt) ? "A interface da Zenith já está no novo idioma. Aplicativos externos aplicarão após novo login." : page.sys.tr("Оболочка уже на новом языке. Приложения и меню читают язык при входе — они переключатся после перезахода."))
                     : ((page.sys && page.sys.isPt) ? "A interface atualiza instantaneamente. Aplicativos externos requerem novo login para ler as variáveis de ambiente." : page.sys.tr("Оболочка переключается сразу. Приложения и меню — после перезахода: язык они читают при входе.")))
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- Papel de Parede (Wallpaper)
    SetCard {
        sys: page.sys

        SetLabel {
            sys: page.sys
            text: (page.sys && page.sys.isPt) ? "Papel de Parede da Área de Trabalho" : page.sys.tr("Обои")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Miniatura do wallpaper atual
            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 64
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.4)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    source: page.sys.wallCurrentThumb ? ("file://" + page.sys.wallCurrentThumb) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !page.sys.wallCurrentThumb
                    text: "󰋩"
                    color: page.sys.colMuted
                    font { family: page.sys.fontFam; pixelSize: 22 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: (page.sys && page.sys.isPt)
                          ? "Navegue pela coleção de papéis de parede ou escolha uma nova imagem para seu fundo."
                          : page.sys.tr("Коллекция обоев и оформление рабочего стола.")
                    color: page.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }

                RowLayout {
                    spacing: 8

                    SetButton {
                        sys: page.sys
                        text: (page.sys && page.sys.isPt) ? "Galeria de Wallpapers 󰋩" : page.sys.tr("Галерея обоев 󰋩")
                        onClicked: page.sys.toggleWalls()
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- Tema Visual (Theme)
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Tema do Sistema" : page.sys.tr("Тема") }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: page.sys.themes

                Rectangle {
                    id: swatch
                    required property var modelData
                    readonly property bool active: page.sys.cfg.themeId === swatch.modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 14
                    color: swatch.modelData.bg
                    border.width: swatch.active ? 2 : 1
                    border.color: swatch.active
                                  ? swatch.modelData.on
                                  : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b,
                                            swatchMa.containsMouse ? 0.30 : 0.12)
                    Behavior on border.color { ColorAnimation { duration: page.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9

                        Repeater {
                            model: [swatch.modelData.on, swatch.modelData.fg, swatch.modelData.crit]
                            Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: modelData
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        text: swatch.modelData.name
                        color: swatch.modelData.fg
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }

                    MouseArea {
                        id: swatchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { page.sys.cfg.themeId = swatch.modelData.id; page.sys.saveCfg(); }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- Cor Principal (Accent)
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Cor Principal de Destaque" : page.sys.tr("Основной цвет акцента") }

        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "Escolha a cor primária que ilumina botões, barras de progresso, player e widgets."
                  : page.sys.tr("Выберите цвет акцента для кнопок, ползунков, плеера и виджетов.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Paleta rápida de amostras de cores
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { name: "Roxo", hex: "#a855f7" },
                    { name: "Azul", hex: "#3b82f6" },
                    { name: "Ciano", hex: "#06b6d4" },
                    { name: "Esmeralda", hex: "#10b981" },
                    { name: "Âmbar", hex: "#f59e0b" },
                    { name: "Laranja", hex: "#f97316" },
                    { name: "Rosa", hex: "#ec4899" },
                    { name: "Vermelho", hex: "#ef4444" },
                    { name: "Branco", hex: "#ffffff" }
                ]

                Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: modelData.hex
                    border.color: (page.sys.cfg.colOn === modelData.hex) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.2)
                    border.width: (page.sys.cfg.colOn === modelData.hex) ? 2 : 1
                    scale: cMa.pressed ? 0.9 : (cMa.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: page.sys.cfg.colOn === parent.modelData.hex
                        width: 8; height: 8; radius: 4
                        color: (parent.modelData.hex === "#ffffff") ? "#000000" : "#ffffff"
                    }

                    MouseArea {
                        id: cMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.sys.cfg.colOn = parent.modelData.hex;
                            page.sys.saveCfg();
                            hexField.text = parent.modelData.hex;
                        }
                    }
                }
            }

            // Botão "Padrão do Tema"
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: themeDefTxt.implicitWidth + 14
                radius: 14
                color: (!page.sys.cfg.colOn || page.sys.cfg.colOn === "theme")
                       ? Qt.rgba(1, 1, 1, 0.20) : (tDefMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: (!page.sys.cfg.colOn || page.sys.cfg.colOn === "theme") ? "#ffffff" : page.sys.colLine
                border.width: 1

                Text {
                    id: themeDefTxt
                    anchors.centerIn: parent
                    text: (page.sys && page.sys.isPt) ? "Tema" : "Тема"
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: 11 }
                }

                MouseArea {
                    id: tDefMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.sys.cfg.colOn = "theme";
                        page.sys.saveCfg();
                        hexField.text = "";
                    }
                }
            }
        }

        // Campo Hexadecimal + Botão Conta-gotas (Hyprpicker)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Preview redondo da cor atual
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: page.sys.colOn
                border.color: Qt.rgba(1, 1, 1, 0.3)
                border.width: 1
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                placeholderText: page.sys.colOn.toString() || "#3b82f6"
                text: (page.sys.cfg.colOn && page.sys.cfg.colOn !== "theme") ? page.sys.cfg.colOn : ""
                color: page.sys.colFg
                placeholderTextColor: page.sys.colMuted
                selectByMouse: true
                selectionColor: page.sys.colOn
                selectedTextColor: "#ffffff"
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                    border.color: hexField.activeFocus ? page.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    var val = hexField.text.trim();
                    if (/^#[0-9A-Fa-f]{6}$/.test(val) || /^#[0-9A-Fa-f]{8}$/.test(val)) {
                        page.sys.cfg.colOn = val;
                        page.sys.saveCfg();
                    }
                }
            }

            // Botão Conta-gotas (Eyedropper)
            SetButton {
                sys: page.sys
                text: (page.sys && page.sys.isPt) ? "Conta-gotas 󰈊" : "Пипетка 󰈊"
                onClicked: pPickColor.running = true
            }

            Process {
                id: pPickColor
                command: [page.sys.scriptDir + "/pick_color.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        var picked = String(text).trim();
                        if (/^#[0-9A-Fa-f]{6}$/.test(picked)) {
                            page.sys.cfg.colOn = picked;
                            page.sys.saveCfg();
                            hexField.text = picked;
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- Saturação e Vibratilidade (Vibrance)
    SetCard {
        sys: page.sys

        SetLabel {
            sys: page.sys
            text: (page.sys && page.sys.isPt) ? "Saturação de Cores (Digital Vibrance)" : page.sys.tr("Цифровая интенсивность")
        }

        SetSlider {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Intensidade digital de saturação" : page.sys.tr("Цифровая интенсивность")
            from: 0; to: 100; step: 1
            suffix: "%"
            value: page.sys.cfg.vibrance !== undefined ? page.sys.cfg.vibrance : 50
            onMoved: v => page.sys.setVibrance(v)
        }

        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "50% é o nível natural. Acima de 50% as cores tornam-se mais vívidas e vibrantes através de shader Wayland; abaixo de 50% reduz a saturação até o monocromático."
                  : page.sys.tr("50 — нейтральный цвет без изменений. Выше — картинка насыщеннее; ниже — глушит до ч/б.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- Widgets da Área de Trabalho
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Widgets na Área de Trabalho" : page.sys.tr("Настольные виджеты") }

        SetToggle {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Ativar widgets no papel de parede" : page.sys.tr("Виджеты на рабочем столе")
            sub: (page.sys && page.sys.isPt)
                 ? "Cartões estilo Nothing OS no papel de parede: relógio analógico ou digital, clima, monitor de sistema e barra de progresso."
                 : page.sys.tr("Карточки Nothing OS на обоях: дата, часы, погода, системный монитор и шкала прогресса. Клик по карточкам переключает режимы.")
            on: page.sys.cfg.featWidgets
            onToggled: v => { page.sys.cfg.featWidgets = v; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Estilo do relógio" : page.sys.tr("Стиль часов")
            options: [
                { id: "analog", text: (page.sys && page.sys.isPt) ? "Analógico Nothing OS" : page.sys.tr("Аналоговые Nothing") },
                { id: "digital", text: (page.sys && page.sys.isPt) ? "Digital de pontos" : page.sys.tr("Цифровые точечные") }
            ]
            value: page.sys.cfg.widgetClockMode || "analog"
            onPicked: id => { page.sys.cfg.widgetClockMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Bloco de informações" : page.sys.tr("Информационный блок")
            options: [
                { id: "weather", text: (page.sys && page.sys.isPt) ? "Clima (vento e umidade)" : page.sys.tr("Погода (ветер и влажность)") },
                { id: "system", text: (page.sys && page.sys.isPt) ? "Sistema (RAM e SSD)" : page.sys.tr("Система (RAM и SSD)") }
            ]
            value: page.sys.cfg.widgetRightMode || "weather"
            onPicked: id => { page.sys.cfg.widgetRightMode = id; page.sys.saveCfg(); }
        }

        SetSelect {
            visible: page.sys.cfg.featWidgets
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Barra de progresso" : page.sys.tr("Шкала прогресса")
            options: [
                { id: "day", text: (page.sys && page.sys.isPt) ? "Progresso do dia (24 horas)" : page.sys.tr("Прогресс дня (24 часа)") },
                { id: "year", text: (page.sys && page.sys.isPt) ? "Progresso do ano (365 dias)" : page.sys.tr("Прогресс года (365 дней)") }
            ]
            value: page.sys.cfg.widgetProgressMode || "day"
            onPicked: id => { page.sys.cfg.widgetProgressMode = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.cfg.featWidgets && (!page.sys.cfg.weatherKey || page.sys.cfg.weatherKey.length === 0)
            text: (page.sys && page.sys.isPt)
                  ? "Dica: insira a chave de API e cidade na aba 'Clima' para exibir a previsão completa no widget."
                  : page.sys.tr("Впишите ключ и город во вкладке Weather, иначе карточка погоды останется пустой.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    // ------------------------------------------------------------- Terminal
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Terminal" : page.sys.tr("Терминал") }

        SetSlider {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Opacidade do fundo do terminal" : page.sys.tr("Прозрачность терминала")
            from: 0.5; to: 1.0; step: 0.01
            decimals: 2
            value: page.sys.cfg.termAlpha
            onMoved: v => {
                page.sys.cfg.termAlpha = v;
                page.sys.saveCfg();
                page.sys.applyTermAlpha();
            }
        }

        Text {
            Layout.fillWidth: true
            text: (page.sys && page.sys.isPt)
                  ? "1.00 — fundo totalmente opaco. Valores menores trazem transparência translúcida com desfoque de fundo."
                  : page.sys.tr("1.00 — сплошной фон. Действует сразу; если нет — терминал держит свои настройки с прошлого входа, и его серверу нужен перезапуск.")
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
                text: (page.sys && page.sys.isPt) ? "Reiniciar Servidor do Terminal" : page.sys.tr("Перезапустить терминал")
                onClicked: page.sys.restartTerminalServer()
            }
        }
    }

    // ------------------------------------------------------------- Tipografia e Fontes
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Tipografia e Ícones" : page.sys.tr("Шрифты") }

        SetSlider {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Tamanho do texto" : page.sys.tr("Размер текста")
            from: 10; to: 24; step: 1
            value: page.sys.cfg.fontSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.fontSize = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Tamanho dos ícones" : page.sys.tr("Размер иконок")
            from: 12; to: 28; step: 1
            value: page.sys.cfg.iconSize
            suffix: "px"
            onMoved: v => { page.sys.cfg.iconSize = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Fonte de texto do sistema" : page.sys.tr("Шрифт текста")
            options: page.sys.fontList
            value: page.sys.cfg.fontBody || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontBody = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Fonte dos títulos e cabeçalhos" : page.sys.tr("Шрифт заголовков")
            options: page.sys.fontList
            value: page.sys.cfg.fontDisplay || page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontDisplay = id; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Fonte de símbolos e ícones (Nerd Font)" : page.sys.tr("Шрифт значков")
            options: page.sys.fontList
            value: page.sys.cfg.fontFam
            onPicked: id => { page.sys.cfg.fontFam = id; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- Ilha Dinâmica
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Ilha Dinâmica & Status" : page.sys.tr("Остров") }

        SetToggle {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Exibir uso de CPU e RAM na ilha" : page.sys.tr("Показывать нагрузку CPU и RAM")
            sub: (page.sys && page.sys.isPt)
                 ? "Exibe as porcentagens de CPU e memória RAM na cápsula recolhida."
                 : page.sys.tr("Показывает проценты процессора и памяти в свернутом острове.")
            on: page.sys.cfg.systemLoadOnIsland !== false
            onToggled: value => {
                page.sys.cfg.systemLoadOnIsland = value;
                page.sys.saveCfg();
            }
        }
    }

    // ------------------------------------------------------------- Efeitos Sonoros
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: (page.sys && page.sys.isPt) ? "Efeitos Sonoros do Sistema" : page.sys.tr("Звуки") }

        SetToggle {
            sys: page.sys
            label: (page.sys && page.sys.isPt) ? "Ativar efeitos sonoros" : page.sys.tr("Звуковые эффекты системы")
            sub: (page.sys && page.sys.isPt)
                 ? "Feedback sonoro ao conectar carregador, parear Bluetooth, tirar captura de tela ou ditar por voz."
                 : page.sys.tr("Зарядка, подключение Bluetooth, скриншоты, голосовой ввод")
            on: page.sys.cfg.uiSounds !== false
            onToggled: value => {
                page.sys.cfg.uiSounds = value;
                page.sys.saveCfg();
                if (value) page.sys.playSound("connect");
            }
        }

        // Botões de prévia sonora
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            visible: page.sys.cfg.uiSounds !== false

            Repeater {
                model: [
                    { id: "charge",       label: (page.sys && page.sys.isPt) ? "Carregador" : page.sys.tr("Зарядка"),     icon: "󰂄" },
                    { id: "connect",      label: "Bluetooth",                                                               icon: "󰂯" },
                    { id: "disconnect",   label: (page.sys && page.sys.isPt) ? "Desconexão" : page.sys.tr("Отключение"),  icon: "󰂲" },
                    { id: "screenshot",   label: (page.sys && page.sys.isPt) ? "Captura" : page.sys.tr("Скриншот"),        icon: "󰄀" },
                    { id: "notification", label: (page.sys && page.sys.isPt) ? "Notificação" : page.sys.tr("Уведомление"), icon: "󰂚" },
                    { id: "voice_start",  label: (page.sys && page.sys.isPt) ? "Voz" : page.sys.tr("Голос"),               icon: "󰍬" }
                ]

                Rectangle {
                    id: sndBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: sndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: sndMa.containsMouse ? page.sys.colOn : page.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            color: sndMa.containsMouse ? page.sys.colOn : page.sys.colMuted
                            font { family: page.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: modelData.label
                            color: sndMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.sys.playSound(modelData.id)
                    }
                }
            }
        }
    }
}
