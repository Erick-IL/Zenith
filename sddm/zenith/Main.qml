import QtQuick 2.15

// Zenith-style login screen: blurry system wallpaper, island capsule with
// password field, session selection and power button. Same form language as
// pills and lockscreen.
//
// Directly from ~/ the wallpaper is not readable: greeter runs as user sddm,
// and the home directory is closed (drwx------). Therefore switch_theme.sh when
// each theme change puts a ready-made blurry copy of the current wallpaper in
// /var/lib/zenith, where greeter gets it from. No file - remains
// the same gradient.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#050506"

    readonly property string fontFam: "JetBrainsMono Nerd Font"
    // An accent of the current theme placed next to the wallpaper. Default value
    // remains until there is no file - for example, until the first theme change.
    //
    // It is taken by Loader: Process is not available in greeter, and XHR is
    // file:// Qt 6 silently blocks without QML_XHR_ALLOW_FILE_READ, which
    // greeter cannot be set. Loading a tiny QML fragment works.
    Loader {
        id: accentLoader
        source: "file:///var/lib/zenith/accent.qml"
        asynchronous: false
    }
    // The palette is written by the shell itself when changing the theme - it alone knows which one
    // the topic has been chosen. We read the values one at a time and with spare ones: the file could
    // remain from the previous version, where it only had an accent.
    readonly property color accent:
        accentLoader.item ? accentLoader.item.value : "#c65a47"

    // The language comes from the same place and in the same way. The pill itself writes it when
    // language change in settings (SUPER + I): login screen should not speak
    // in Russian, if the rest of the system is switched to English.
    Loader {
        id: localeLoader
        source: "file:///var/lib/zenith/locale.qml"
        asynchronous: false
    }
    // The default is English - just like the pill, while there is no file yet.
    readonly property bool isEn:
        localeLoader.item ? localeLoader.item.lang === "en" : true

    // The key is Russian text, as in a pill: the source remains readable, but
    // A dictionary is needed only for English.
    readonly property var dictEn: ({
        "Пароль": "Password",
        "Неверный пароль": "Wrong password",
        "Сон": "Sleep",
        "Перезагрузка": "Restart",
        "Выключить": "Shut down"
    })
    readonly property var dictTr: ({
        "Пароль": "Parola",
        "Неверный пароль": "Yanlış parola",
        "Сон": "Uyku",
        "Перезагрузка": "Yeniden başlat",
        "Выключить": "Kapat"
    })
    function tr(k) {
        var language = localeLoader.item ? String(localeLoader.item.lang).split("_")[0] : "en";
        if (language === "ru") return k;
        if (language === "tr" && dictTr[k] !== undefined) return dictTr[k];
        return dictEn[k] !== undefined ? dictEn[k] : k;
    }
    readonly property color fg:
        (accentLoader.item && accentLoader.item.fg !== undefined)
            ? accentLoader.item.fg : "#f2f2f2"
    readonly property color muted:
        (accentLoader.item && accentLoader.item.muted !== undefined)
            ? accentLoader.item.muted : "#8a8a8a"
    readonly property color line: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
    // Red "wrong password" stays red on any theme: this is the color
    // failure, not decoration.
    readonly property color crit: "#ef4444"

    // Color of the inscription over the accent fill: on a light accent with white
    // White can't see anything. Brightness according to Rec. 709 - the same as in the shell.
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.bg : "#ffffff";
    }
    readonly property color bg:
        (accentLoader.item && accentLoader.item.bg !== undefined)
            ? accentLoader.item.bg : "#050506"

    // Display name. The system login goes to sddm.login() as is.
    readonly property string loginName: userModel.lastUser || "ensi"
    readonly property string nick:
        loginName.charAt(0).toUpperCase() + loginName.slice(1)

    // session names: SDDM model roles are numbered differently between versions,
    // so we take them with a regular delegate, and not through data(index, role)
    property var sessionNames: []

    Repeater {
        model: sessionModel
        Item {
            Component.onCompleted: {
                var a = root.sessionNames.slice();
                a[index] = name;
                root.sessionNames = a;
            }
        }
    }

    property string errorText: ""
    property bool busy: false

    // ------------------------------------------------------------------ background
    // The current system wallpaper, blurred in advance by the theme script.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file:///var/lib/zenith/sddm-bg.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Darkening over wallpaper: the capsule and clock should be legible even on light
    // picture. Weak - our themes are already dark, at 0.45 the login screen
    // turned into solid black and the wallpaper was not visible at all.
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.visible
        color: Qt.rgba(0, 0, 0, 0.28)
    }

    // a soft accent spot so the black isn't flat
    // (spare background when there is no picture - for example on the first load)
    Rectangle {
        anchors.fill: parent
        visible: !wallpaper.visible
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10) }
            GradientStop { position: 0.55; color: "#050506" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // ---------------------------------------------------------------- watch
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.height * 0.14)
        spacing: 6

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.fg
            font { family: root.fontFam; pixelSize: 76; bold: true }
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }
        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(1, 1, 1, 0.45)
            font { family: root.fontFam; pixelSize: 16 }
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            var d = new Date();
            clock.text = Qt.formatDateTime(d, "HH:mm");
            dateLabel.text = Qt.formatDateTime(d, "dddd, d MMMM");
        }
    }

    // -------------------------------------------------------------- center
    Column {
        anchors.centerIn: parent
        spacing: 18

        // avatar: first letter of nickname
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84; height: 84; radius: 42
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: root.line
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.nick.charAt(0)
                color: root.accent
                font { family: root.fontFam; pixelSize: 34; bold: true }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.nick
            color: root.fg
            font { family: root.fontFam; pixelSize: 20; bold: true }
        }

        // ----------------------------------------------- capsule with password
        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: 60
            radius: 30
            color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
            border.width: 1
            border.color: root.errorText.length
                          ? Qt.rgba(0.94, 0.27, 0.27, 0.75)
                          : (password.activeFocus ? Qt.rgba(root.accent.r, root.accent.g,
                                                            root.accent.b, 0.65)
                                                  : root.line)
            Behavior on border.color { ColorAnimation { duration: 200 } }

            // shaking when password is incorrect
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 12

                // An icon in its own box: Material Design glyphs
                // ink wider than advance, and one at a time only verticalCenter
                // the lock slid halfway beyond the edge of the line.
                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: capsuleIcon
                        anchors.centerIn: parent
                        visible: !root.busy
                        text: String.fromCodePoint(0xF033E)
                        color: root.errorText.length ? root.crit : root.accent
                        font { family: root.fontFam; pixelSize: 20 }
                    }

                    // The loading circle is drawn rather than taken from the font.
                    //
                    // The glyph rotated around the middle of the line, and its ink
                    // they are not sitting in the center of their box - the circle is crooked
                    // and wobbled. The arc is described around the real center and
                    // remains level in any frame.
                    Canvas {
                        id: spinner
                        anchors.centerIn: parent
                        width: 20; height: 20
                        visible: root.busy
                        antialiasing: true

                        property real angle: 0
                        property color tint: root.errorText.length ? root.crit : root.accent
                        onAngleChanged: requestPaint()
                        onTintChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var r = width / 2 - 2;
                            // backing - the entire ring so that the arc does not hang in
                            // emptiness and it was clear how much longer she had to go
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = Qt.rgba(spinner.tint.r, spinner.tint.g,
                                                      spinner.tint.b, 0.22);
                            ctx.stroke();
                            // arc itself: three quarters of a circle
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r,
                                    spinner.angle, spinner.angle + Math.PI * 1.5);
                            ctx.lineWidth = 2;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = spinner.tint;
                            ctx.stroke();
                        }

                        NumberAnimation on angle {
                            running: root.busy && spinner.visible
                            loops: Animation.Infinite
                            from: 0; to: Math.PI * 2; duration: 900
                        }
                    }
                }

                TextInput {
                    id: password
                    width: parent.width - 90
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0
                    color: root.fg
                    selectionColor: root.accent
                    clip: true
                    font { family: root.fontFam; pixelSize: 16 }
                    focus: true
                    enabled: !root.busy

                    onTextChanged: root.errorText = ""
                    onAccepted: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: root.errorText.length ? root.errorText : root.tr("Пароль")
                        color: root.errorText.length ? root.crit : Qt.rgba(1, 1, 1, 0.32)
                        font { family: root.fontFam; pixelSize: 15 }
                    }
                }

                // login button
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 20
                    color: password.text.length ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0142)
                        // The circle is filled with accent, and it is on a black and white theme
                        // white - the white arrow on it disappeared entirely, and
                        // the button looked like an empty white spot.
                        color: password.text.length ? root.fgOn(root.accent) : root.muted
                        font { family: root.fontFam; pixelSize: 16 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doLogin()
                    }
                }
            }
        }

        // ------------------------------------------------- session selection (WM)
        Rectangle {
            id: sessionBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: sessionRow.implicitWidth + 34
            height: 34
            radius: 17
            color: sessionMa.containsMouse || sessionList.visible
                   ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.line
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }

            property int index: sessionModel.lastIndex

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0379)
                    color: root.muted
                    font { family: root.fontFam; pixelSize: 13 }
                }
                Text {
                    id: sessionLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sessionNames[sessionBtn.index] || "Hyprland"
                    color: root.fg
                    font { family: root.fontFam; pixelSize: 12 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0140)
                    color: root.muted
                    font { family: root.fontFam; pixelSize: 11 }
                }
            }

            MouseArea {
                id: sessionMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionList.visible = !sessionList.visible
            }

            // list of available window managers
            Rectangle {
                id: sessionList
                visible: false
                width: 260
                // Высота по числу строк самого списка, а не по
                // sessionModel.rowCount(): rowCount у QAbstractItemModel не
                // помечен Q_INVOKABLE, и в Qt 6 вызов из QML бросает
                // TypeError — привязка обрывалась, список оставался нулевой
                // высоты, и выбрать сеанс было нечем.
                height: Math.min(sessionView.count, 6) * 34 + 12
                radius: 16
                color: Qt.rgba(0.04, 0.04, 0.05, 0.97)
                border.color: root.line
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8

                ListView {
                    id: sessionView
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: sessionModel
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 34
                        radius: 10
                        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                             : (index === sessionBtn.index ? Qt.rgba(1, 1, 1, 0.06)
                                                           : "transparent")

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: model.name
                            color: index === sessionBtn.index ? root.fg : root.muted
                            font {
                                family: root.fontFam; pixelSize: 12
                                bold: index === sessionBtn.index
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            visible: index === sessionBtn.index
                            text: String.fromCodePoint(0xF012C)
                            color: root.accent
                            font { family: root.fontFam; pixelSize: 12 }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sessionBtn.index = index;
                                sessionLabel.text = model.name;
                                sessionList.visible = false;
                                password.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- food
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        spacing: 14

        Repeater {
            model: [
                // The dream is drawn in letters, as in the shell nutrition menu: at the month
                // Nerd Font has no pairing with the others - it's about the night, not about
                // sleep, and next to rebooting and shutting down was read by strangers.
                { glyph: "", sleep: true, tip: root.tr("Сон"),          act: "suspend" },
                { glyph: String.fromCodePoint(0xF0709), tip: root.tr("Перезагрузка"), act: "reboot"  },
                { glyph: String.fromCodePoint(0xF0425), tip: root.tr("Выключить"),    act: "power"   }
            ]

            Rectangle {
                width: 46; height: 46; radius: 23
                // The background and outline are more noticeable than before: on a black background
                // five percent fill with twelve percent frame
                // read as empty space and three buttons at the bottom of the screen
                // they simply weren’t there with the eye.
                color: pwrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18)
                                           : Qt.rgba(1, 1, 1, 0.09)
                border.color: pwrMa.containsMouse
                              ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.45)
                              : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                scale: pwrMa.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 130 } }

                // Three "z" with a triangle - the same design as in the menu
                // shell power supply: small on top in the center, large below
                // left, middle right.
                Item {
                    anchors.centerIn: parent
                    width: 26; height: 26
                    visible: modelData.sleep === true
                    opacity: pwrMa.containsMouse ? 1 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        x: 0; y: 9
                        text: "Z"
                        color: root.fg
                        font { family: root.fontFam; pixelSize: 15; bold: true }
                    }
                    Text {
                        x: 11; y: 0
                        text: "z"
                        color: root.fg
                        font { family: root.fontFam; pixelSize: 8; bold: true }
                    }
                    Text {
                        x: 16; y: 5
                        text: "z"
                        color: root.fg
                        font { family: root.fontFam; pixelSize: 11; bold: true }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: modelData.sleep !== true
                    text: modelData.glyph
                    // Icon at full brightness and without hover: dimmed
                    // it merged with the substrate. Hover now shows
                    // the button itself, and not the loss of its contents.
                    color: root.fg
                    opacity: pwrMa.containsMouse ? 1 : 0.75
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    font { family: root.fontFam; pixelSize: 18 }
                }

                MouseArea {
                    id: pwrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var a = modelData.act;
                        if (a === "suspend") sddm.suspend();
                        else if (a === "reboot") sddm.reboot();
                        else sddm.powerOff();
                    }
                }
            }
        }
    }

    // The keyboard layout is a small thing, but without it it’s easy to enter the password in the wrong one.
    //
    // With flipping, not replacing letters: the layout is switched blindly,
    // Having already started typing, you should notice the confirmation out of the corner of your eye.
    // A fixed inscription changes imperceptibly - and the price of an unnoticed change
    // There's a whole failed login attempt here.
    Item {
        id: kbBox
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        width: kbText.implicitWidth
        height: kbText.implicitHeight
        clip: true

        // Индекс проверяем отдельно от длины: на машине без настроенных
        // раскладок currentLayout приходит равным -1, и обращение по нему
        // роняло привязку целиком, унося с собой и надпись, и её анимацию.
        readonly property string value: {
            var l = keyboard.layouts;
            if (!l || l.length === 0) return "";
            var i = keyboard.currentLayout;
            if (i < 0 || i >= l.length || !l[i] || !l[i].shortName) return "";
            return String(l[i].shortName).toUpperCase();
        }
        property string shown: kbBox.value

        onValueChanged: if (kbBox.value !== kbBox.shown) kbFlip.restart()

        Text {
            id: kbText
            text: kbBox.shown
            color: root.fg
            opacity: 0.75
            font { family: root.fontFam; pixelSize: 12; bold: true; letterSpacing: 1 }
        }

        SequentialAnimation {
            id: kbFlip
            NumberAnimation { target: kbText; property: "opacity"; to: 0; duration: 90 }
            NumberAnimation { target: kbText; property: "y"
                              to: -kbBox.height; duration: 0 }
            ScriptAction { script: kbBox.shown = kbBox.value }
            NumberAnimation { target: kbText; property: "y"; to: 0
                              duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: kbText; property: "opacity"; to: 0.75
                              duration: 150 }
        }
    }

    // --------------------------------------------------------------- login
    function doLogin() {
        if (root.busy || password.text.length === 0) return;
        root.errorText = "";
        root.busy = true;
        sddm.login(root.loginName, password.text, sessionBtn.index);
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false;
            root.errorText = "";
        }
        function onLoginFailed() {
            root.busy = false;
            root.errorText = root.tr("Неверный пароль");
            password.text = "";
            shake.restart();
            password.forceActiveFocus();
        }
        function onInformationMessage(message) {
            root.busy = false;
            root.errorText = message;
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
