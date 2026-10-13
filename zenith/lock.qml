//@ pragma UseQApplication
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Themes.js" as Themes

// Dynamic island style lock screen.
//
// Two states:
//   peace - current wallpaper is sharp, clock and lock in the center
//   input - the background goes into blur, a capsule with password dots emerges from below
//
// Run as a separate process: quickshell --path ~/.config/zenith/lock.qml
// While the process is alive, ext-session-lock keeps the session closed.
ShellRoot {
    id: root

    // ------------------------------------------------------------- condition
    // The password lives here, and not in the TextInput: the field lies inside the component
    // surface (one for each screen) and the id is not visible from the outside.
    property string password: ""
    property bool authMode: false          // input capsule shown
    property bool checking: false          // PAM checks password
    property string errorText: ""
    property int attempts: 0

    readonly property string user: Quickshell.env("USER") || "user"
    // Nickname for greeting: Ensi instead of system ensi
    readonly property string nick:
        user.charAt(0).toUpperCase() + user.slice(1)

    readonly property string fontFam: "JetBrainsMono Nerd Font"

    // Lock screen is a separate program, it does not have access to the state
    // shells. We read the settings from the same file: only those that are needed here.
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/zenith/settings.json"
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property int  lockBlur: 32
            property bool lockShowMedia: true
            property bool lockShowNotif: true
            property string lockHint: ""
        }
    }
    readonly property var cfg: cfgFile.adapter

    // Emergency unlock for debugging: only enabled when
    // who started the process with PANACEA_LOCK_TEST=1. In combat launch
    // there is no such channel.
    readonly property bool testMode: Quickshell.env("PANACEA_LOCK_TEST") === "1"

    // ------------------------------------------------- wallpaper and accent from the theme
    property string wallpaper: ""

    // The palette comes from the same theme as the skin. Previously screen
    // blocking lived its own life: the accent he read from hypr/palette.conf, and
    // With a black and white theme, the shell was greeted with a terracotta input circle.
    //
    // The theme is read from settings.json with the same parsing as the language, and the table
    // general colors - Themes.js. You cannot keep your copy here: it
    // would have diverged from the shell on the very first edit of the palette.
    property string themeId: "default"
    readonly property var theme: Themes.of(root.themeId)
    // with “default” the emphasis remains on the settings, as in the shell
    property color cfgOn: "#3b82f6"
    readonly property color accent: root.themeId === "default" ? root.cfgOn
                                                               : root.theme.on
    readonly property color colFg:   root.theme.fg
    readonly property color colCrit: root.theme.crit
    // The background is needed for inscriptions on top of the filled accent: on a light accent
    // White can't see anything on white, but the Nothing theme is just white.
    readonly property color colBg:   root.theme.bg
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    // ------------------------------------------------------------------ language
    // The lock screen is a separate process and does not reach the settings of the pill,
    // so it reads the same settings.json itself. Without this he remained
    // Russian-speaking even with an English interface.
    property bool isEn: true
    function tr(k) { return root.isEn && root.dictEn[k] !== undefined ? root.dictEn[k] : k; }
    readonly property var dictEn: ({
        "Слишком много попыток": "Too many attempts",
        "Неверный пароль": "Wrong password",
        "Ошибка проверки": "Verification error",
        "PAM недоступен": "PAM unavailable",
        "Нажмите Enter": "Press Enter",
        "Пароль": "Password"
    })

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/zenith/settings.json"
        blockLoading: true
    }

    FileView {
        id: wallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        // we read synchronously: wallpaper is needed in the first frame, otherwise
        // black screen flashes for seconds
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            var cfg = JSON.parse(settingsFile.text() || "{}");
            if (cfg && typeof cfg.lang === "string") root.isEn = cfg.lang !== "ru";
            if (cfg && typeof cfg.themeId === "string") root.themeId = cfg.themeId;
            if (cfg && typeof cfg.colOn === "string") root.cfgOn = cfg.colOn;
        } catch (e) { /* there are no settings - we remain in English and the default theme */ }

        // scripts/lock.sh gives a copy of the wallpaper already compressed under the screen
        var cached = Quickshell.env("PANACEA_LOCK_BG") || "";
        if (cached.length) { root.wallpaper = cached; }

        var w = /^\$wallpaper\s*=\s*(.+)$/m.exec(wallFile.text() || "");
        if (w && !cached.length) {
            var p = w[1].trim();
            if (p.indexOf("~") === 0) p = Quickshell.env("HOME") + p.slice(1);
            root.wallpaper = (p === "black" || p.length === 0) ? "" : p;
        }
    }

    // ------------------------------------------------------------------ watch
    property string timeText: "--:--"
    property string dateText: ""
    function tick() {
        var d = new Date();
        root.timeText = Qt.formatDateTime(d, "HH:mm");
        root.dateText = Qt.formatDateTime(d, "dddd, d MMMM");
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.tick()
    }

    // ------------------------------------------------------------------- PAM
    PamContext {
        id: pam
        // /etc/pam.d/swaylock - standard profile for lock screens
        config: "swaylock"
        user: root.user

        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.password = "";
                lock.locked = false;
                quitTimer.start();
            } else {
                root.attempts++;
                root.errorText = result === PamResult.MaxTries
                                 ? root.tr("Слишком много попыток")
                                 : root.tr("Неверный пароль");
                root.password = "";
            }
        }
        onError: {
            root.checking = false;
            root.errorText = root.tr("Ошибка проверки");
            root.password = "";
        }
    }

    // we give the composer a frame to remove the blocking, then we leave
    Timer { id: quitTimer; interval: 220; onTriggered: Qt.quit() }

    function submit() {
        if (root.checking) return;
        if (!root.password.length) return;
        root.errorText = "";
        root.checking = true;
        if (!pam.start()) {
            root.checking = false;
            root.errorText = root.tr("PAM недоступен");
        }
    }

    IpcHandler {
        target: "lock"
        // works only in test run, see testMode
        function unlock(): void {
            if (!root.testMode) return;
            lock.locked = false;
            quitTimer.start();
        }
        // also just for debugging: see input mode without keyboard
        function auth(): void {
            if (!root.testMode) return;
            root.authMode = true;
        }
    }

    // ---------------------------------------------------------------- screens
    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            Item {
                anchors.fill: parent

                // ---------------------------------------------------- background
                Image {
                    id: bg
                    anchors.fill: parent
                    source: root.wallpaper.length ? "file://" + root.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: false
                    // Wallpapers come in tens of megapixels (ember_stripes.jpg - 10667x7111),
                    // and Qt refuses to decode them: the limit is 256 MB per image.
                    // sourceSize causes the JPEG to be decoded immediately reduced;
                    // double margin for the screen size - so that the crop does not lather.
                    sourceSize: Qt.size(surface.width * 2, surface.height * 2)
                    layer.enabled: true
                    layer.smooth: true
                }

                // blur is enabled only in input mode
                MultiEffect {
                    anchors.fill: parent
                    source: bg
                    visible: bg.status === Image.Ready
                    blurEnabled: true
                    // Blur strength is set in the Lock Screen tab
                    blurMax: root.cfg ? root.cfg.lockBlur : 32
                    blurMultiplier: 0.85
                    blur: root.authMode ? 1.0 : 0.0
                    Behavior on blur {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                }

                // darkening: slight at rest, more noticeable when typing
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: root.authMode ? 0.55 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 420 } }
                }

                // ------------------------------------------------ clock and lock
                Column {
                    id: idleBlock
                    anchors.centerIn: parent
                    spacing: 18
                    // when you type, the block moves up and turns pale
                    y: parent.height / 2 - height / 2 - (root.authMode ? 60 : 0)
                    Behavior on y {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }

                    // castle in a matte circle
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96; height: 96; radius: 48
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        opacity: root.authMode ? 0 : 1
                        scale: root.authMode ? 0.9 : 1
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on scale { NumberAnimation { duration: 300 } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF033E)
                            color: "#ffffff"
                            font { family: root.fontFam; pixelSize: 40 }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.timeText
                        color: "#ffffff"
                        font { family: root.fontFam; pixelSize: 84; bold: true }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dateText
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font { family: root.fontFam; pixelSize: 17 }
                    }

                    // Own line of the owner of the machine: whose computer is this, where
                    // call if found. Empty - it simply doesn’t exist.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        text: root.cfg ? root.cfg.lockHint : ""
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font { family: root.fontFam; pixelSize: 14 }
                    }

                    // the hint flashes until you start typing
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.tr("Нажмите Enter")
                        color: Qt.rgba(1, 1, 1, 0.40)
                        opacity: root.authMode ? 0 : 1
                        visible: opacity > 0.01
                        font { family: root.fontFam; pixelSize: 13; letterSpacing: 1 }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        SequentialAnimation on scale {
                            running: !root.authMode
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.04; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 1100; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // ------------------------------------------------- input capsule
                Item {
                    id: island
                    width: root.authMode ? 420 : 150
                    height: 62
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 + 130
                    opacity: root.authMode ? 1 : 0
                    visible: opacity > 0.01
                    scale: root.authMode ? 1 : 0.92

                    Behavior on width {
                        NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                    }
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Behavior on scale {
                        NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                    }

                    // shaking if the password is incorrect: move the transform to
                    // don't fight with anchors.horizontalCenter
                    transform: Translate { id: shakeT }
                    SequentialAnimation {
                        id: shake
                        loops: 2
                        NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
                    }
                    Connections {
                        target: root
                        function onErrorTextChanged() {
                            if (root.errorText.length) shake.restart();
                        }
                    }

                    Rectangle {
                        id: capsule
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(0.04, 0.04, 0.05, 0.92)
                        border.width: 1
                        border.color: root.errorText.length
                                      ? Qt.rgba(0.94, 0.27, 0.27, 0.75)
                                      : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 14

                            // lock/tick/spinner
                            Item {
                                width: 26; height: 26
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    visible: !root.checking
                                    text: String.fromCodePoint(0xF033E)
                                    color: root.errorText.length ? root.colCrit : root.accent
                                    font { family: root.fontFam; pixelSize: 19 }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    id: spinner
                                    anchors.centerIn: parent
                                    visible: root.checking
                                    text: String.fromCodePoint(0xF0772)
                                    color: root.accent
                                    font { family: root.fontFam; pixelSize: 19 }
                                    RotationAnimator on rotation {
                                        running: spinner.visible
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 900
                                    }
                                }
                            }

                            // dots based on the number of characters entered
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                Repeater {
                                    model: Math.min(root.password.length, 16)
                                    Rectangle {
                                        width: 9; height: 9; radius: 5
                                        color: "#ffffff"
                                        opacity: 0.9
                                        // each point appears with a bounce
                                        scale: 0
                                        Component.onCompleted: scale = 1
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 180; easing.type: Easing.OutBack
                                            }
                                        }
                                    }
                                }
                                // empty field - hint instead of dots
                                Text {
                                    visible: root.password.length === 0
                                    text: root.errorText.length ? root.errorText : root.tr("Пароль")
                                    color: root.errorText.length
                                           ? root.colCrit : Qt.rgba(1, 1, 1, 0.35)
                                    font { family: root.fontFam; pixelSize: 14 }
                                }
                            }
                        }
                    }
                }

                // username under capsule
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: island.y + island.height + 16
                    text: root.nick
                    color: Qt.rgba(1, 1, 1, 0.55)
                    opacity: root.authMode ? 1 : 0
                    visible: opacity > 0.01
                    font { family: root.fontFam; pixelSize: 14; letterSpacing: 1 }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                // ------------------------------------------------------- input
                // The real field is hidden: we draw the points ourselves, and the layouts
                // Let TextInput handle backspace and insertion.
                TextInput {
                    id: pwInput
                    focus: true
                    width: 1; height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    activeFocusOnPress: false

                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: {
                        root.password = text;
                        if (text.length) root.errorText = "";
                    }
                    onAccepted: root.submit()

                    // cleaning is initiated by the root (after password verification)
                    Connections {
                        target: root
                        function onPasswordChanged() {
                            if (root.password === "" && pwInput.text !== "") pwInput.text = "";
                        }
                    }

                    Keys.onEscapePressed: {
                        if (root.authMode && !root.checking) {
                            pwInput.text = "";
                            root.errorText = "";
                            root.authMode = false;
                        }
                    }
                    Keys.onPressed: event => {
                        if (root.checking) { event.accepted = true; return; }
                        if (!root.authMode) {
                            root.authMode = true;
                            // Enter only opens the capsule, should not print
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space)
                                event.accepted = true;
                        }
                    }
                }

                // focus should not be lost under any circumstances
                Timer {
                    interval: 400; running: true; repeat: true
                    onTriggered: if (!pwInput.activeFocus) pwInput.forceActiveFocus()
                }
            }
        }
    }
}
