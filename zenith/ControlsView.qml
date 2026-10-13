import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Opened panel without music: Wi-Fi and Bluetooth.
//
// Three pages inside one panel (sys.page):
//   main - two switch tiles
//   wifi - list of networks + enter password
//   bt - list of devices
Item {
    id: view
    property var sys

    // Layout for the settings tab: the same panel, only inanimate. Shows
    // always the main page and listens not to the saved layout, but to the one
    // that the person is moving the mouse right now.
    property bool preview: false
    property var ccOrderOverride: null

    // ------------------------------------------------- panel block order
    // Empty setting - factory order. Unknown names (left over from
    // previous version) are discarded, forgotten ones are added to the end: layout
    // survives both updating the shell and editing the file manually.
    readonly property var ccDefault: ["clock", "toggles", "sliders", "media", "power", "quick", "tray"]
    readonly property var ccOrder: {
        if (view.ccOrderOverride) return view.ccOrderOverride;
        var saved = String(view.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        var out = saved.filter(id => view.ccDefault.indexOf(id) >= 0);
        view.ccDefault.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        return out;
    }
    // block rectangle in panel coordinates - the layout places it on it
    // drag pad
    function ccBlock(id) {
        for (var i = 0; i < mainPage.children.length; i++)
            if (mainPage.children[i].objectName === "cc-" + id) return mainPage.children[i];
        return null;
    }
    function ccRow(id) {
        var i = view.ccOrder.indexOf(id);
        return i < 0 ? view.ccDefault.indexOf(id) : i;
    }

    // "m:ss" for duration bar; the clock appears only if needed
    function fmtTime(sec) {
        var t = Math.max(0, Math.floor(sec));
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        var mm = h > 0 && m < 10 ? "0" + m : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : String(s));
    }

    implicitHeight: stack.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()

    // Return to tiles. Moved to a function because Escape is not always
    // gets here: the focus can sit in the Wi-Fi password field or in the list, and
    // then the event pops up past - to Loader in shell.qml. He's calling
    // goBack() itself, and the subpage is closed instead of the entire panel.
    function goBack() {
        // from the network menu we return to the list, and not to the tiles: the person has arrived
        // here from the list and back there waiting
        if (view.sys.page === "netmenu") {
            view.sys.page = "wifi";
            return true;
        }
        if (view.sys.page === "wifi" || view.sys.page === "bt"
            || view.sys.page === "battery") {
            view.sys.page = "main";
            return true;
        }
        if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
            return true;
        }
        return false;
    }

    Keys.onEscapePressed: {
        // from subpages Esc returns back, from the main page it closes the panel
        if (!view.goBack()) view.sys.collapse();
    }

    // ------------------------------------------------------- common components

    // Power mode selection segment: icon + caption, active is highlighted
    component PowerSeg: Rectangle {
        property string icon: ""
        property string label: ""
        property string profile: ""
        property color accent: view.sys.colOn
        readonly property bool active: view.sys.powerProfile === profile

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 14
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                      : (segMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09)
                                             : Qt.rgba(1, 1, 1, 0.05))
        border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        scale: segMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: parent.parent.active ? parent.parent.accent : "#ffffff"
                font { family: view.sys.fontFam; pixelSize: 17 }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 11; bold: parent.parent.active }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.setPowerProfile(parent.profile)
        }
    }

    // Tile: icon on the left (switches), title on the right (opens the list)
    component Tile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        signal iconClicked()
        signal bodyClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.05)
        border.color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            // round icon button - turn on/off
            Rectangle {
                id: iconBtn
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: parent.parent.on ? parent.parent.accent : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: iconMa.pressed ? 0.9 : (iconMa.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: iconBtn.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconBtn.parent.parent.iconClicked()
                }
            }

            // signature - opens the list
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Text {
                text: ""
                color: bodyMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            anchors.leftMargin: 58     // do not overlap the round button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Bottom row icon button: lock, notifications, settings.
    // The tooltip is the same black capsule that pops up above the tray icons.
    component IconBtn: Rectangle {
        property string glyph: ""
        property string tip: ""
        property color glyphColor: view.sys.colMuted
        property color activeColor: view.sys.colFg
        property bool active: false
        property int badge: 0
        signal act()

        implicitWidth: 44
        implicitHeight: 44
        radius: 13
        z: ibMa.containsMouse ? 10 : 0
        color: ibMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        border.color: active ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        scale: ibMa.pressed ? 0.9 : (ibMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Glyph {
            anchors.fill: parent
            glyph: parent.glyph
            color: parent.active ? parent.activeColor
                 : ibMa.containsMouse ? view.sys.colFg : parent.glyphColor
            fontFam: view.sys.fontFam
            size: view.sys.iconSize - 2
        }

        // unread counter - only at the bell
        Rectangle {
            width: 15; height: 15; radius: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            visible: parent.badge > 0
            color: view.sys.colOn
            Text {
                anchors.centerIn: parent
                text: parent.parent.badge > 9 ? "9+" : parent.parent.badge
                // the circle is filled with an accent: there is a white number on a light accent
                // disappears entirely
                color: view.sys.fgOn(view.sys.colOn)
                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }

        Rectangle {
            id: ibTip
            visible: opacity > 0.01
            opacity: (ibMa.containsMouse && parent.tip.length) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            width: ibTipText.implicitWidth + 20
            height: 26
            radius: 13
            x: (parent.width - width) / 2
            y: -height - 8
            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
            border.color: view.sys.colLine
            border.width: 1

            scale: ibMa.containsMouse ? 1 : 0.92
            transformOrigin: Item.Bottom
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
            }

            Text {
                id: ibTipText
                anchors.centerIn: parent
                text: ibTip.parent.tip
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

    // Wave “charging”: two asynchronous sinusoids, filled to the level
    // charge and slowly creeping sideways. We draw the rounding directly in the outline and
    // We use it as a mask - the usual Item clip is only rectangular.
    component ChargeWave: Canvas {
        property color tint: view.sys.colOk
        property real level: 0.5        // fraction of the height to which it is poured
        property real radius: 14
        property bool running: false
        property real phase: 0

        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        onPhaseChanged: requestPaint()
        onLevelChanged: requestPaint()
        // Without this, the wave remains the same color as it was drawn in the first
        // once: the outline does not redraw itself, but the color comes from the theme and
        // changes on the fly - after switching to Nothing the fill remained
        // green from the previous topic.
        onTintChanged: requestPaint()

        Timer {
            interval: 45
            running: parent.running && parent.visible
            repeat: true
            onTriggered: parent.phase += 0.16
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;

            // mask - a rounded rectangle of a tile
            var r = Math.min(radius, Math.min(width, height) / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
            ctx.closePath();
            ctx.clip();

            // Keep the level away from the edges: there is a wave at the very top
            // is cut off with a mask and looks like an even strip.
            var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
            var amp = 3.2;

            for (var w = 0; w < 2; w++) {
                var off = w === 0 ? 0 : Math.PI * 0.7;
                var k = w === 0 ? 0.055 : 0.041;
                ctx.beginPath();
                ctx.moveTo(0, height);
                for (var x = 0; x <= width; x += 3) {
                    var y = base + amp * Math.sin(k * x + phase + off)
                                 + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                    if (x === 0) ctx.lineTo(0, y); else ctx.lineTo(x, y);
                }
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, w === 0 ? 0.16 : 0.11);
                ctx.fill();
            }
        }
    }

    // Compact tile for the top line: Wi-Fi and Bluetooth are next to each other,
    // and not two stripes under each other. The icon is smaller, the signature is two
    // lines, the chevron was removed - by a third of the width it only ate up space.
    component MiniTile: Rectangle {
        id: tile
        property string icon: ""
        // A figure icon instead of a font sign. Needed where suitable
        // there is simply no glyph: a wired network in Nerd Font is drawn as a tree with
        // the crossbar is wider than the squares themselves, and at these sizes it is readable
        // stripe across the icon. Empty - icon is taken as before.
        property Component iconItem: null
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        // the battery tile fills with a wave while charging is in progress
        property bool wave: false
        property real waveLevel: 0.5
        signal iconClicked()
        signal bodyClicked()

        // On the Nothing theme, the included tile is filled with accent as a whole, and
        // it is not illuminated by one sixth. There's no color you can use
        // “hint”: the difference between on and off is maintained
        // only on brightness, and translucent backlighting white on black
        // reads like “the tile is a little lighter” rather than “it works.”
        //
        // The circle of the icon turns black and turns inside out
        // with tiles, otherwise white on white merges into a stain.
        // The tile does not become filled as long as a wave passes over it: the wave is
        // an indication that it was charging, and it disappeared on the white fill -
        // it is drawn translucent on top of the background, and not white on top of white
        // nothing visible. There is no need for two indications of the same thing.
        readonly property bool solid: view.sys.themeNothing && tile.on && !tile.wave
        // color of the signatures: on the filled tiles they are dark
        readonly property color ink: tile.solid ? view.sys.fgOn(tile.accent)
                                                : view.sys.colFg

        // implicitWidth is required: the content is pressed by anchors, so its
        // the tile has no width, and the RowLayout gave the entire row to its neighbor - three
        // the cards collapsed on top of each other at point 0.0.
        implicitWidth: 140
        implicitHeight: 56
        radius: 14
        color: solid ? accent
             : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                  : Qt.rgba(1, 1, 1, 0.05)
        border.color: solid ? accent
                    : on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35)
                         : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // below the content: the wave should not overlap the captions
        ChargeWave {
            anchors.fill: parent
            radius: parent.radius
            tint: parent.accent
            level: parent.waveLevel
            running: parent.wave
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                id: miniIcon
                // larger than the previous 30: in line with the lock and gear
                // small circles looked depressed
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: tile.solid ? view.sys.colBg
                     : tile.on ? tile.accent
                               : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: miniIconMa.pressed ? 0.9 : (miniIconMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                // The icon lies directly on the mug, and the color is taken from it: on
                // in an accent mug, white on white is not visible at all, but on
                // turned black - on the contrary, only white is visible.
                readonly property color ink: tile.solid ? "#ffffff"
                                           : tile.on ? view.sys.fgOn(tile.accent)
                                                     : "#ffffff"

                Text {
                    anchors.centerIn: parent
                    visible: tile.iconItem === null
                    text: tile.icon
                    color: miniIcon.ink
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    active: tile.iconItem !== null
                    sourceComponent: tile.iconItem
                }

                // The color of the figure is the same as that of the sign. Separate
                // Binding, not assignment in onLoaded: the color changes,
                // when the tile is turned on, and there is no one-time recording when loading
                // that would be enough.
                Binding {
                    target: iconLoader.item
                    property: "color"
                    value: miniIcon.ink
                    when: iconLoader.item !== null
                }
                MouseArea {
                    id: miniIconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniIcon.parent.parent.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: tile.ink
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: tile.sub
                    // On the filled tile we mute it not with a general colMuted - that
                    // built on the color of the theme text, that is, white, and on
                    // white background fades into nothingness.
                    color: tile.solid
                           ? Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.6)
                           : view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: 44     // do not overlap the round button
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Small plate with a number on the battery page
    component BattStat: Rectangle {
        property string label: ""
        property string value: ""

        implicitWidth: 90
        implicitHeight: 44
        Layout.fillWidth: true
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 10 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
        }
    }

    // Round player control button in the track card.
    component MediaBtn: Rectangle {
        property string icon: ""
        property bool primary: false
        property bool enabledAction: true
        signal act()

        implicitWidth: primary ? 36 : 28
        implicitHeight: primary ? 36 : 28
        radius: width / 2
        color: primary ? view.sys.colOn
              : (mbMa.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.08))
        opacity: enabledAction ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mbMa.pressed ? 0.9 : (mbMa.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.primary ? "#111111" : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: parent.primary ? 15 : 12 }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    // Sound card of the same height: device name on top, below it
    // the slider is right in the tile - the volume is adjusted without going to the page.
    // Slider track: filling is the handle, as in iOS - a separate circle
    // at such a height there would be nowhere to put it. One for volume and brightness:
    // they appear side by side on the same line, and any discrepancy in behavior between
    // adjacent sliders reads like a breakdown of one of them.
    component Track: Item {
        id: trk

        property real pos: 0                  // 0..1 — what to show
        property string icon: ""              // icon on the left, on top of the fill
        property string valueText: ""         // number on the right
        property real wheelStep: 0.05
        property bool dim: false              // off (no sound)

        signal setFrac(real frac)
        signal iconClicked()

        implicitHeight: 22

        readonly property real padL: trk.icon.length ? 22 : 0
        function fracAt(x) {
            return Math.max(0, Math.min(1, (x + trk.padL) / Math.max(1, trk.width)));
        }

        // The fill does not animate in two cases: while it is being dragged, it must
        // stand exactly under the cursor, otherwise catch-up is read as an input delay;
        // and in the first moments after creation - meaning comes after
        // him, and the strip would move from zero to its place each time
        // in front of the person who opened the panel.
        property bool live: false
        Component.onCompleted: liveTimer.start()
        Timer { id: liveTimer; interval: 260; onTriggered: trk.live = true }

        // Your mark for the time of a series of wheel scrolls, see onWheel below.
        property real wheelFrom: -1
        Timer { id: wheelIdle; interval: 260; onTriggered: trk.wheelFrom = -1 }

        // While the person is spinning, we show exactly what he asked, not
        // waiting for confirmation. Volume confirms Pipewire with a signal,
        // monitor brightness via I2C in tens of milliseconds; if you draw
        // only confirmed, when scrolling quickly, a bar and a number
        // jump back to the previous value. I let go and everything settled down -
        // back to the present.
        property real held: -1
        readonly property real shown: trk.held >= 0 ? trk.held : trk.pos
        Timer { id: heldIdle; interval: 400; onTriggered: trk.held = -1 }
        function put(frac) {
            trk.held = Math.max(0, Math.min(1, frac));
            heldIdle.restart();
            trk.setFrac(trk.held);
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)
            clip: true

            Rectangle {
                width: Math.max(parent.height, parent.width * trk.shown)
                height: parent.height
                radius: height / 2
                color: view.sys.colFg
                opacity: trk.dim ? 0.45 : 1
                Behavior on width {
                    enabled: trk.live && !trkMa.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: trk.icon.length > 0
            text: trk.icon
            color: view.sys.colBg
            font { family: view.sys.fontFam; pixelSize: 15 }
        }

        Text {
            id: trkVal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: trk.valueText
            // The fill is the handle, so the number turns out to be light,
            // then on the dark one: repaint it at the border, otherwise it disappears.
            color: (trk.width * trk.shown) > (trk.width - trkVal.width - 12)
                   ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }

        MouseArea {
            id: trkMa
            anchors.fill: parent
            // click on the icon itself - do not drag, but click on it
            anchors.leftMargin: trk.padL
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => trk.put(trk.fracAt(mouse.x))
            onPositionChanged: mouse => { if (pressed) trk.put(trk.fracAt(mouse.x)); }
            // Wheel on top of track. On a keyboard without media keys
            // this is the only way to adjust the value without aiming the mouse at
            // a thin strip - and a habit from any other shell.
            //
            // We count from our own mark, and not from pos: both volume and
            // brightness is not confirmed immediately - Pipewire responds with a signal,
            // monitor via I2C and even in tens of milliseconds. With fast
            // scrolling, the next division had not yet been read
            // updated value, and the number jumped back and forth instead of
            // to grow. The mark lives until a pause in scrolling, then again
            // let's take the real meaning.
            onWheel: wheel => {
                var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                if (d === 0) return;
                var base = trk.wheelFrom >= 0 ? trk.wheelFrom : trk.shown;
                // Exactly by divisions: otherwise, from the fractional beginning, all further
                // Scrolling goes past round numbers.
                var steps = Math.round(base / trk.wheelStep) + (d > 0 ? 1 : -1);
                var next = Math.max(0, Math.min(1, steps * trk.wheelStep));
                trk.wheelFrom = next;
                wheelIdle.restart();
                trk.put(next);
            }
        }

        MouseArea {
            width: 22
            height: parent.height
            visible: trk.icon.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: trk.iconClicked()
        }
    }

    component VolCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            // Bottom is larger than top: the track is thinner than the title and with equal
            // indentation sat on the edge of the card, reading like its edge.
            anchors.bottomMargin: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Звук")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                // The device name occupies the rest of the line and is truncated at
                // him. A constant 130 pixels was fine as long as the name was short:
                // "OnePlus Buds 3" did not fit in them and went over the edge
                // cards - there is nothing to trim if the width is specified by a number,
                // which is more than the available space.
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: view.sys.sinkName.length ? view.sys.sinkName
                                                   : view.sys.tr("Нет устройств")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            // Level is a number: the bar shows the volume only approximately, but
            // the exact number has so far only been in the key pad
            // volume - call it on a keyboard without multimedia buttons
            // there was nothing, and there was nowhere to get the exact meaning.
            Track {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.sinkAudio

                pos: vol.a ? vol.a.volume : 0
                dim: vol.a ? vol.a.muted : true
                icon: !vol.a ? String.fromCodePoint(0xF075F)
                    : vol.a.muted ? String.fromCodePoint(0xF075F)
                    : vol.a.volume < 0.34 ? String.fromCodePoint(0xF057F)
                    : vol.a.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                          : String.fromCodePoint(0xF057E)
                valueText: !vol.a ? "—"
                    : vol.a.muted ? view.sys.tr("Без звука")
                                  : Math.round(vol.shown * 100) + "%"
                // 5% step, same as multimedia keys
                onSetFrac: f => { if (vol.a) vol.a.volume = Math.round(f * 20) / 20; }
                onIconClicked: if (vol.a) vol.a.muted = !vol.a.muted
            }
        }
    }

    component MicCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: (view.sys.srcAudio && !view.sys.srcAudio.muted)
                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3)
                      : view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: (view.sys && view.sys.isPt) ? "Microfone" : view.sys.tr("Микрофон")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: (view.sys.sourceName && view.sys.sourceName.length)
                          ? view.sys.sourceName
                          : ((view.sys && view.sys.isPt) ? "Padrão" : view.sys.tr("Микрофон"))
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            Track {
                id: mic
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.srcAudio

                pos: mic.a ? mic.a.volume : 0
                dim: mic.a ? mic.a.muted : true
                icon: !mic.a ? "󰍭"
                    : mic.a.muted ? "󰍭"
                    : "󰍬"
                valueText: !mic.a ? "—"
                    : mic.a.muted ? ((view.sys && view.sys.isPt) ? "Mudo" : view.sys.tr("Без звука"))
                                  : Math.round(mic.shown * 100) + "%"
                onSetFrac: f => { if (mic.a) mic.a.volume = Math.round(f * 20) / 20; }
                onIconClicked: if (mic.a) mic.a.muted = !mic.a.muted
            }
        }
    }

    // Brightness is a card of exactly the same composition as the sound: they stand next to each other
    // in one line. We keep our own value, rather than asking the monitor for each
    // frame: DDC responds tens of milliseconds, and the slider waiting for the bus twitched
    // would be at hand.
    component BrightCard: Rectangle {
        id: brCard
        property string bid: ""
        property int    bpct: 0
        property string bname: ""

        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Яркость")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.maximumWidth: 130
                    // A screen name is needed only when there are several of them: on one
                    // there is nothing to sign on the monitor.
                    visible: brCard.bname.length > 0
                    text: brCard.bname
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }

            Track {
                id: brTrk
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                pos: Math.max(0, Math.min(1, brCard.bpct / 100))
                icon: String.fromCodePoint(0xF00DD)   // sun
                valueText: Math.round(brTrk.shown * 100) + "%"
                // 5% steps, same as brightness keys
                onSetFrac: f => view.sys.brightSet(brCard.bid, Math.round(f * 20) * 5)
            }
        }
    }

    // List page header: back + title + refresh
    component Header: RowLayout {
        property string title: ""
        property bool busy: false
        signal back()
        signal refresh()

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: backMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                anchors.centerIn: parent; text: ""
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            MouseArea {
                id: backMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.back()
            }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
        }
        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: refMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                id: refIcon
                anchors.centerIn: parent; text: "󰑐"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
                RotationAnimator on rotation {
                    running: refIcon.parent.parent.busy
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            MouseArea {
                id: refMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.refresh()
            }
        }
    }

    // List string
    component Row1: Rectangle {
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        signal activated()
        // Right button: for networks, it hides the disconnect and “forget” button.
        // The line itself does not know anything about them - it only reports about the press.
        signal menuRequested(real mx, real my)

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 12
        color: rowMa.containsMouse ? view.sys.colHover
             : (highlight ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 10
            Text {
                text: rowMa.parent.icon
                color: rowMa.parent.highlight ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 15 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: rowMa.parent.title
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: rowMa.parent.highlight }
                }
                Text {
                    text: rowMa.parent.sub
                    visible: text.length > 0
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
            Text {
                visible: rowMa.parent.highlight
                text: "󰄬"
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    var p = mapToItem(wifiPage, mouse.x, mouse.y);
                    parent.menuRequested(p.x, p.y);
                } else {
                    parent.activated();
                }
            }
        }
    }

    // Wired network icon figure. One for the entire panel: Loader creates
    // your copy where you need it.
    Component {
        id: lanShape
        LanGlyph { width: 13; height: 13 }
    }

    // Number: dotted on Nothing, regular font on other topics.
    //
    // The panel layout of the themes is the same, only the style is different, so
    // the choice is hidden here, and not spread out in each place with a number. Skittle
    // font is taken with a margin of the height of the dot digit: that is the height
    // the entire height, and for a letter the pixelSize is calculated over the entire line.
    component Num: Item {
        id: num
        property string value: ""
        property real size: 12
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  nDots.implicitWidth
        implicitHeight: nDots.implicitHeight

        DotText {
            id: nDots
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
    }

    // ------------------------------------------------------------ recording
    // Recording plate for the Nothing theme: round button, signature and timer.
    //
    // A regular tile showed the frame rate at this point until the recording
    // coming. The number is from the settings, they change it once in a lifetime, and the places it
    // takes as long as the countdown. Here they always stand instead
    // Recording hours: until the beginning at zero, then they go.
    component RecordCard: Rectangle {
        id: recCard

        radius: 14
        color: recBodyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.recActive
                      ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g,
                                view.sys.colCrit.b, 0.45)
                      : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // the body opens the recording page, the button starts and stops
        MouseArea {
            id: recBodyMa
            anchors.fill: parent
            anchors.leftMargin: 52
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.togglePage("record")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                id: recBtn
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                // Recording is in progress - the button is red, which means “press to
                // stop." It stands as a regular circle with a triangle.
                color: view.sys.recActive ? view.sys.colCrit : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: recBtnMa.pressed ? 0.9 : (recBtnMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF040A)
                    color: view.sys.recActive
                           ? view.sys.fgOn(view.sys.colCrit) : "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: recBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.toggleRecord()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Запись")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: 9
                        capitalization: Font.AllUppercase; letterSpacing: 1.2
                    }
                }

                // Counting in dots is like other numbers in the topic. No entry yet
                // walks, it is muted: the zeros at full brightness would be read as
                // “it goes and stands at zero.”
                Num {
                    Layout.alignment: Qt.AlignLeft
                    value: view.sys.recTimeText
                    size: view.sys.dotHSmall + 3
                    color: !view.sys.recActive ? view.sys.colMuted
                         : view.sys.recPaused ? view.sys.colWarn
                                              : view.sys.colFg
                }
            }
        }
    }

    // ------------------------------------------------- machine load
    // Three lines: processor, memory, video. Percentages - stripes and numbers
    // at once: the bar shows “a lot or a little” at a glance, the number
    // answers “to what extent exactly,” and one does not replace the other.
    component LoadRow: RowLayout {
        id: lrow
        property string glyph: ""
        property string name: ""
        property int pct: -1
        property int temp: -1

        // There is nothing to measure with - there is no line at all. The bar at zero would read as
        // “stands idle,” which is a different statement.
        visible: lrow.pct >= 0
        spacing: 8

        Glyph {
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            glyph: lrow.glyph
            color: view.sys.colMuted
            fontFam: view.sys.fontFam
            size: 12
        }

        Text {
            Layout.preferredWidth: 30
            text: lrow.name
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: 9; letterSpacing: 0.6 }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            Layout.alignment: Qt.AlignVCenter
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, lrow.pct)) / 100
                height: parent.height
                radius: parent.radius
                color: view.sys.colFg
                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        // We reserve the width for the number at “100%”, otherwise the stripe is on the left
        // I would twitch at every ten crossing.
        //
        // We measure with a real invisible number, and not with a round number by eye:
        // the width of a dot sign depends on the height, and on the gaps, and on
        // how many grid columns "%" has. The previous 30 pixels were
        // Almost twice as little as needed - the number showed up on the strip.
        Item {
            Layout.preferredWidth: pctRuler.implicitWidth
            Layout.preferredHeight: pctRuler.implicitHeight

            Num {
                id: pctRuler
                visible: false
                value: "100%"
                size: view.sys.dotHTiny
            }

            Num {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: lrow.pct + "%"
                size: view.sys.dotHTiny
                color: view.sys.colFg
            }
        }

        // Not everyone has a sensor: the processor almost always has one, the video -
        // How lucky are you with the driver?
        RowLayout {
            spacing: 3
            visible: lrow.temp >= 0

            Glyph {
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                glyph: String.fromCodePoint(0xF0E01)
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
                fontFam: view.sys.fontFam
                size: 10
            }
            Num {
                Layout.alignment: Qt.AlignVCenter
                value: lrow.temp + "°"
                size: view.sys.dotHTiny
                color: lrow.temp >= 80 ? view.sys.colCrit : view.sys.colMuted
            }
        }
    }

    component LoadCard: Rectangle {
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 4

            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0EE0); name: "CPU"
                pct: view.sys.loadCpu; temp: view.sys.loadTempCpu
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF035B); name: "RAM"
                pct: view.sys.loadMem
            }
            LoadRow {
                Layout.fillWidth: true
                glyph: String.fromCodePoint(0xF0379); name: "GPU"
                pct: view.sys.loadGpu; temp: view.sys.loadTempGpu
            }
        }
    }

    // ------------------------------------------------------------- pages
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SetScroll { sys: view.sys }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                var max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - d));
            }
        }

        Item {
            id: stack
            width: flick.width
        implicitHeight: (view.preview || view.sys.page === "main") ? mainPage.implicitHeight
                      : view.sys.page === "wifi" ? wifiPage.implicitHeight
                      : view.sys.page === "netmenu" ? netMenuPage.implicitHeight
                      : view.sys.page === "traymenu" ? trayPage.implicitHeight
                      : view.sys.page === "battery" ? battPage.implicitHeight
                      : btPage.implicitHeight
        // The height is animated by the capsule itself in shell.qml. Second animation here
        // folded with it: the capsule caught up with the already animated value,
        // and the panel expanded noticeably longer than necessary.

        // ---------------------------------------------------------- home
        // A grid in one column, not a column: only it can provide an explicit number
        // lines for each child. The order of blocks is set in the tab
        // Control Center and comes here with a line from the settings - transfer
        // The block code itself was not necessary for this.
        GridLayout {
            id: mainPage
            width: parent.width
            columns: 1
            columnSpacing: 0
            rowSpacing: 9
            opacity: (view.preview || view.sys.page === "main") ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // header with gear: quick access to settings
            RowLayout {
                objectName: "cc-clock"
                Layout.row: view.ccRow("clock")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 10

                // clock: click opens calendar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: clockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        spacing: 10

                        Text {
                            visible: !view.sys.themeNothing
                            text: view.sys.timeText
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 8; bold: true }
                        }

                        // Nothing: large hours with dots, seconds with small ones
                        // number on the side. Seconds are always here, no matter
                        // “show seconds” settings: the one about the clock in
                        // line, and this is a separate number next to them.
                        RowLayout {
                            visible: view.sys.themeNothing
                            spacing: 5

                            DotText {
                                Layout.alignment: Qt.AlignVCenter
                                value: view.sys.timeText
                                size: view.sys.dotHBig
                                color: view.sys.colFg
                            }
                            DotText {
                                // along the top edge, not in the center: shallow
                                // the number in the middle of the large clock would read
                                // as part of them
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1
                                // Only when there are no seconds in the watch itself. C
                                // with the “show seconds” setting enabled
                                // they are already in timeText, and this is the number
                                // repeated them a second time: “19:36:42 42.”
                                visible: !view.sys.cfg.clockSeconds
                                value: view.sys.secText
                                size: view.sys.dotHSmall
                                color: view.sys.colMuted
                            }
                        }
                        ColumnLayout {
                            spacing: -1
                            Text {
                                text: view.sys.dateLong
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                visible: view.sys.cfg.featCalendar
                                text: view.sys.tr("Календарь")
                                color: clockMa.containsMouse ? view.sys.colOn
                                                            : Qt.rgba(1, 1, 1, 0.28)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: view.sys.cfg.featCalendar
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("cal")
                    }
                }

                // Weather Card (lado contrário da hora)
                Rectangle {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: weatherRow.implicitWidth + 24
                    radius: 12
                    color: weatherMa.containsMouse
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                           : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.08)
                    border.color: weatherMa.containsMouse
                                  ? view.sys.colOn
                                  : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: weatherRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: (view.sys.weatherCond === "Clear" ? "󰖙"
                                 : view.sys.weatherCond === "Clouds" ? "󰖐"
                                 : view.sys.weatherCond === "Rain" ? "󰖗"
                                 : view.sys.weatherCond === "Snow" ? "󰼶"
                                 : view.sys.weatherCond === "Thunderstorm" ? "󰙾" : "󰖐")
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 18 }
                        }

                        Text {
                            text: view.sys.weatherReady ? (view.sys.weatherTemp + "°" + view.sys.weatherUnitLetter) : "--°"
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
                        }

                        Text {
                            visible: view.sys.weatherReady && view.sys.weatherDesc.length > 0
                            text: view.sys.weatherDesc
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            elide: Text.ElideRight
                            Layout.maximumWidth: 95
                        }
                    }

                    MouseArea {
                        id: weatherMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("weather")
                    }
                }
            }

            // ------------------------------- Wi-Fi · Bluetooth · in-line audio
            // The three most frequent switches occupied three consecutive lanes.
            // Now it's one line, and the volume is adjusted directly in the tile.
            RowLayout {
                objectName: "cc-toggles"
                Layout.row: view.ccRow("toggles")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                // Wi-Fi and Bluetooth split the line equally. Previously next to them
                // There was also a sound, and three tiles in a row pressed each one to
                // width that did not fit the network name.
                // A cable is plugged in - the tile shows a wired network: connection
                // goes along it, and the Wi-Fi antenna is on top of the working cable
                // would be misleading. The cable was removed - the tile itself
                // returns to Wi-Fi. The same on a laptop and on a PC: there,
                // where there is no wireless adapter at all, it just always
                // wired.
                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    // The cable is drawn as a figure, Wi-Fi remains a font symbol:
                    // The antenna in Nerd Font is well made, but the network tree is without
                    // There simply isn’t a full-width crossbar there.
                    iconItem: view.sys.wiredOn ? lanShape : null
                    icon: (view.sys.wifiConnecting || (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length)) ? "󰤩"
                        : view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                           : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    // connected - the network name is in the header, otherwise the usual “Wi-Fi”
                    label: view.sys.wiredOn ? ((view.sys && view.sys.isPt) ? "Rede Cabeada" : view.sys.tr("Проводная сеть"))
                         : (view.sys.wifiOn && view.sys.wifiSsid.length)
                           ? view.sys.wifiSsid
                         : (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length)
                           ? view.sys.wifiConnectingSsid : "Wi-Fi"
                    sub: view.sys.wiredOn ? view.sys.wiredName
                       : !view.sys.wifiOn ? ((view.sys && view.sys.isPt) ? "Desativado" : view.sys.tr("Выключен"))
                       : (view.sys.wifiSsid.length)
                         ? view.sys.wifiQuality + "%"
                       : (view.sys.wifiConnecting || (view.sys.wifiConnectingSsid && view.sys.wifiConnectingSsid.length))
                         ? ((view.sys && view.sys.isPt) ? "Conectando…" : view.sys.tr("Подключение…"))
                       : ((view.sys && view.sys.isPt) ? "Desconectado" : view.sys.tr("Не подключено"))
                    on: view.sys.wiredOn || view.sys.wifiOn
                    accent: view.sys.colOn
                    // The cable icon doesn't switch anything: wired network
                    // turn it off with a cable, not a button. Wi-Fi remains
                    // accessible from the body of the tile - it could be needed nearby
                    // with cable.
                    onIconClicked: if (!view.sys.wiredOn) view.sys.toggleWifi()
                    onBodyClicked: {
                        // The networks page may have been disabled by the installer -
                        // then the tile only switches wifi
                        if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                        view.sys.openSub("wifi");
                        view.sys.refreshWifiList();
                        view.sys.scanWifi();
                    }
                }

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 56
                    icon: view.sys.btOn ? "󰂯" : "󰂲"
                    // device is connected - its name instead of “Bluetooth”
                    label: (view.sys.btOn && view.sys.btConnectedName.length)
                           ? view.sys.btConnectedName : "Bluetooth"
                    sub: !view.sys.btOn ? ((view.sys && view.sys.isPt) ? "Desativado" : view.sys.tr("Выключен"))
                       : (view.sys.btConnectedName.length
                          ? (view.sys.btConnectedBattery >= 0
                             ? "󰥉 " + view.sys.btConnectedBattery + "%"
                             : ((view.sys && view.sys.isPt) ? "Conectado" : view.sys.tr("Подключено")))
                          : ((view.sys && view.sys.isPt) ? "Nenhum dispositivo" : view.sys.tr("Нет подключений")))
                    on: view.sys.btOn
                    accent: view.sys.colOn
                    onIconClicked: view.sys.toggleBt()
                    onBodyClicked: {
                        if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                        view.sys.openSub("bt");
                        view.sys.scanBt();
                    }
                }

            }

            // ------------------------------------------- volume, microphone and brightness
            ColumnLayout {
                objectName: "cc-sliders"
                Layout.row: view.ccRow("sliders")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.cfg.featAudio || ((view.sys.brightList || []).length > 0)

                // Volume e Microfone lado a lado
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: view.sys.cfg.featAudio

                    VolCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 56
                    }

                    MicCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 56
                    }
                }

                // Brilho
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: (view.sys.brightList || []).length > 0

                    Repeater {
                        model: view.sys.brightList

                        BrightCard {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 56
                            bid:  modelData.id
                            bpct: modelData.pct
                            bname: (view.sys.brightList || []).length > 1 ? modelData.name : ""
                        }
                    }
                }
            }

            // ----------------------------------------------- playing track
            // Stands under the switches: while something is playing, a track with buttons
            // and a full-width equalizer replaces a separate page
            // player, which previously opened on hover.
            Rectangle {
                objectName: "cc-media"
                Layout.row: view.ccRow("media")
                Layout.column: 0
                id: mediaCard
                property bool showWave: false
                readonly property var p: view.sys.player
                readonly property string playerSource: {
                    if (!mediaCard.p) return "Media Player";
                    var id = String(mediaCard.p.identity || mediaCard.p.entry || "").toLowerCase();
                    if (id.indexOf("youtube") >= 0) return "YouTube Music";
                    if (id.indexOf("spotify") >= 0) return "Spotify";
                    if (id.indexOf("firefox") >= 0) return "Firefox";
                    if (id.indexOf("chrome") >= 0 || id.indexOf("chromium") >= 0) return "Chrome";
                    if (id.indexOf("vlc") >= 0) return "VLC";
                    return mediaCard.p.identity || "Media Player";
                }

                visible: view.sys.mediaActive && view.sys.cfg.featPlayer
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Capa quadrada com cantos arredondados (114x114)
                    Rectangle {
                        Layout.preferredWidth: 114
                        Layout.preferredHeight: 114
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.08)
                        clip: true

                        Image {
                            id: cardArt
                            anchors.fill: parent
                            source: view.sys.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 220
                            sourceSize.height: 220
                            visible: false
                            layer.enabled: true
                        }
                        Item {
                            id: cardArtMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: 12; color: "#ffffff" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: cardArt
                            maskEnabled: true
                            maskSource: cardArtMask
                            visible: cardArt.status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: cardArt.status !== Image.Ready
                            text: "󰝚"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 28 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mediaCard.p) mediaCard.p.togglePlaying()
                        }
                    }

                    // Coluna de informações e controles
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        // Linha superior: Badge e Botão Wave Toggle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: Math.max(48, badgeTxt.implicitWidth + 14)
                                radius: 9
                                color: Qt.rgba(1, 1, 1, 0.10)

                                Text {
                                    id: badgeTxt
                                    anchors.centerIn: parent
                                    text: mediaCard.playerSource
                                    color: Qt.rgba(1, 1, 1, 0.70)
                                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Botão Wave Toggle
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 20
                                radius: 10
                                color: mediaCard.showWave ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: mediaCard.showWave ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐫"
                                    color: mediaCard.showWave ? view.sys.colOn : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 11 }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: mediaCard.showWave = !mediaCard.showWave
                                }
                            }
                        }

                        // Título da faixa
                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.p ? (mediaCard.p.trackTitle || "Nenhuma faixa") : ""
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 14; bold: true }
                        }

                        // Artista em cor de destaque (colOn)
                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.p ? (mediaCard.p.trackArtist || "Artista desconhecido") : ""
                            color: view.sys.colOn
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }

                        // Barra de progresso + Timestamps
                        Item {
                            id: seek
                            readonly property var p: mediaCard.p
                            readonly property real dur: seek.p ? Math.max(0, seek.p.length) : 0
                            readonly property bool usable: seek.p !== null && seek.dur > 0 && seek.p.positionSupported && seek.p.canSeek
                            readonly property real frac: seek.dur > 0 ? Math.max(0, Math.min(1, seek.pos / seek.dur)) : 0
                            property real pos: 0
                            property bool dragging: false
                            property bool primed: false

                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            visible: seek.p !== null

                            Behavior on pos {
                                enabled: seek.primed && !seek.dragging
                                NumberAnimation { duration: 520; easing.type: Easing.Linear }
                            }
                            Timer {
                                interval: 500
                                repeat: true
                                running: seek.visible && seek.p !== null
                                triggeredOnStart: true
                                onTriggered: {
                                    if (seek.p === null) return;
                                    seek.p.positionChanged();
                                    if (seek.dragging) return;
                                    seek.pos = seek.p.position;
                                    seek.primed = true;
                                }
                            }
                            Connections {
                                target: mediaCard.p
                                ignoreUnknownSignals: true
                                function onTrackTitleChanged() {
                                    seek.dragging = false;
                                    seek.primed = false;
                                    seek.pos = 0;
                                }
                            }

                            function fracOf(x) {
                                return Math.max(0, Math.min(1, x / Math.max(1, seek.width)));
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 3
                                radius: 1.5
                                color: Qt.rgba(1, 1, 1, 0.15)

                                Rectangle {
                                    width: parent.width * seek.frac
                                    height: parent.height
                                    radius: 1.5
                                    color: view.sys.colOn
                                }
                            }

                            MouseArea {
                                id: seekMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                preventStealing: true
                                enabled: seek.usable
                                cursorShape: seek.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: mouse => {
                                    seek.dragging = true;
                                    seek.pos = seek.fracOf(mouse.x) * seek.dur;
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    seek.pos = seek.fracOf(mouse.x) * seek.dur;
                                }
                                onReleased: mouse => {
                                    if (seek.usable) seek.p.position = seek.pos;
                                    seek.dragging = false;
                                }
                                onCanceled: seek.dragging = false
                            }
                        }

                        // Timestamps (0:15 e 3:13)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: -4
                            visible: seek.visible && seek.dur > 0

                            Text {
                                text: view.fmtTime(seek.pos)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 9 }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: view.fmtTime(seek.dur)
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font { family: view.sys.fontFam; pixelSize: 9 }
                            }
                        }

                        // Linha de controles (visível apenas quando showWave for false)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10
                            visible: !mediaCard.showWave

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒝"
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                    opacity: (mediaCard.p && mediaCard.p.shuffle) ? 1.0 : 0.4
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (mediaCard.p && mediaCard.p.shuffle !== undefined) mediaCard.p.shuffle = !mediaCard.p.shuffle
                                }
                            }

                            MediaBtn {
                                icon: "󰒮"
                                enabledAction: mediaCard.p ? mediaCard.p.canGoPrevious : false
                                onAct: if (mediaCard.p) mediaCard.p.previous()
                            }

                            MediaBtn {
                                icon: mediaCard.p && mediaCard.p.isPlaying ? "󰏤" : "󰐊"
                                primary: true
                                enabledAction: mediaCard.p ? mediaCard.p.canTogglePlaying : false
                                onAct: if (mediaCard.p) mediaCard.p.togglePlaying()
                            }

                            MediaBtn {
                                icon: "󰒭"
                                enabledAction: mediaCard.p ? mediaCard.p.canGoNext : false
                                onAct: if (mediaCard.p) mediaCard.p.next()
                            }

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑖"
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                    opacity: (mediaCard.p && mediaCard.p.loopStatus && mediaCard.p.loopStatus !== "None") ? 1.0 : 0.4
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (mediaCard.p && mediaCard.p.loopStatus !== undefined) {
                                            if (mediaCard.p.loopStatus === "None") mediaCard.p.loopStatus = "Playlist";
                                            else if (mediaCard.p.loopStatus === "Playlist") mediaCard.p.loopStatus = "Track";
                                            else mediaCard.p.loopStatus = "None";
                                        }
                                    }
                                }
                            }
                        }

                        // Espectro de áudio animado (visível apenas quando showWave for true)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            visible: mediaCard.showWave

                            WaveBars {
                                anchors.fill: parent
                                barCount: 36
                                gap: 2
                                barColor: view.sys.colOn
                                active: mediaCard.p ? mediaCard.p.isPlaying : false
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mediaCard.p) mediaCard.p.togglePlaying()
                            }
                        }
                    }
                }
            }

            // ------------------------------- Screen recording Battery mode
            // Power modes no longer occupy a separate bar of three
            // segments: they went to the battery page, and one came here
            // tile next to the entry.
            RowLayout {
                id: powerRow
                objectName: "cc-power"
                Layout.row: view.ccRow("power")
                Layout.column: 0
                Layout.fillWidth: true
                spacing: 8

                // On the Nothing topic in this line there is also a load summary in
                // three lines - the tiles grow under it, otherwise the neighbors would be
                // would be different heights.
                readonly property int tileH: 76

                // Shares, not free growth. RowLayout gives away extra space
                // in proportion to the desired width, and the tiles have their own (140),
                // whereas the summary has zero: its contents are pressed down by anchors.
                // Without explicit shares, the tile took the entire line, and from the summary
                // there was a strip of several pixels at the very edge.
                // On the Nothing theme, instead of a tile there is a tile with a button and
                // countdown: frame rate that the tile was showing before
                // the beginning of recording, comes from the settings and changes once in a lifetime.
                RecordCard {
                    visible: view.sys.cfg.featRecord
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                }


                // Battery tile. On a PC it is not there at all: there is no charge, but
                // Power profiles without battery show the same thing - tile
                // with the eternal inscription “Off the network” took up space in vain.
                MiniTile {
                    visible: view.sys.showBattery || view.sys.showPowerProfiles
                    Layout.fillWidth: true
                    // Half with the entry: two cards in a row divide it
                    // equally. The previous share of 1.35 repeated the width of the summary
                    // load, but next to the entry it read simply as
                    // skew - one card is noticeably wider than the other for no reason.
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: powerRow.tileH
                    icon: view.sys.batteryPresent ? view.sys.batteryLevelIcon
                                                  : String.fromCodePoint(0xF0241)
                    label: view.sys.batteryPresent
                           ? view.sys.batteryPct + "%" : view.sys.tr("Батарея")
                    // signature - power status and current mode, without
                    // forecasts “how much is left”: UPower is lying before our eyes
                    sub: view.sys.batteryCharging ? view.sys.tr("Заряжается")
                       : view.sys.acOnline ? view.sys.tr("От сети")
                                           : view.sys.profileLabel
                    on: view.sys.batteryCharging || view.sys.acOnline
                    wave: view.sys.batteryCharging
                    waveLevel: view.sys.batteryPct / 100
                    accent: view.sys.batteryPct <= 15 && !view.sys.acOnline
                            ? view.sys.colCrit : view.sys.colOk
                    onIconClicked: view.sys.openSub("battery")
                    onBodyClicked: view.sys.openSub("battery")
                }

                // Load Summary is only available on a desktop machine. On
                // on a laptop, its place is taken by the battery: the charge there changes itself
                // and decides what to do next, but the CPU load does not.
                // Three cards in a row compresses each one to the point of being unreadable.
                //
                // The fraction is greater than one: there are three lines with stripes, and they
                // need more width than a record tile with two short ones
                // signatures.
                LoadCard {
                    visible: !view.sys.batteryPresent
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.35
                    Layout.preferredHeight: powerRow.tileH
                }
            }

            // -------------------------------- stay awake + icon buttons
            // The lock, notifications and settings have moved here from the top right
            // corner: one bottom stripe instead of icons arguing with the clock.
            RowLayout {
                objectName: "cc-quick"
                Layout.row: view.ccRow("quick")
                Layout.column: 0
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: awakeRow
                // Amber “don’t sleep” is the color of coffee, and on other topics it is
                // place. There is no color accent at all on Nothing, and one
                // the orange stripe at the bottom of the black and white panel rushes into
                // the eyes are stronger than the regime itself is worth.
                readonly property color tint: view.sys.themeNothing
                                              ? view.sys.colOn : "#f59e0b"

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: view.sys.keepAwake
                       ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.16)
                       : (awakeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: view.sys.keepAwake
                              ? Qt.rgba(awakeRow.tint.r, awakeRow.tint.g, awakeRow.tint.b, 0.40)
                              : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 11

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: String.fromCodePoint(view.sys.keepAwake ? 0xF0176 : 0xF0177)
                        color: view.sys.keepAwake ? awakeRow.tint : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Coffee mode"
                        color: view.sys.keepAwake ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                            bold: view.sys.keepAwake
                        }
                    }
                    // switch
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 21
                        radius: 11
                        color: view.sys.keepAwake ? awakeRow.tint : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            width: 17; height: 17; radius: 9
                            y: 2
                            x: view.sys.keepAwake ? parent.width - width - 2 : 2
                            // on the white path the white circle disappears
                            color: view.sys.keepAwake
                                   ? view.sys.fgOn(awakeRow.tint) : "#ffffff"
                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                MouseArea {
                    id: awakeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.keepAwake = !view.sys.keepAwake
                }
            }

            // password manager: lock open when vault is unlocked
            IconBtn {
                glyph: String.fromCodePoint(0xF0425)
                tip: view.sys.tr("Питание")
                activeColor: view.sys.colCrit
                onAct: view.sys.togglePage("power")
            }

            // Bell: active notifications and history
            IconBtn {
                visible: view.sys.cfg.featNotifications
                glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                tip: view.sys.dnd ? view.sys.tr("Не беспокоить") : view.sys.tr("Уведомления")
                badge: view.sys.notifications.count
                onAct: view.sys.togglePage("notif")
            }

            IconBtn {
                glyph: String.fromCodePoint(0xF0493)
                tip: view.sys.tr("Настройки")
                onAct: view.sys.togglePage("settings")
            }
            }

            // ------------------------------------------------ system tray
            RowLayout {
                objectName: "cc-tray"
                Layout.row: view.ccRow("tray")
                Layout.column: 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                visible: view.sys.trayItems.values.length > 0

                Text {
                    text: view.sys.tr("Трей")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                Repeater {
                    model: view.sys.trayItems

                    Rectangle {
                        id: trayBtn
                        required property var modelData

                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        z: trayMa.containsMouse ? 10 : 0
                        radius: 10
                        color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: trayMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            source: String(trayBtn.modelData.icon || "")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                // RMB - application context menu (Telegram, etc.)
                                if (mouse.button === Qt.RightButton) {
                                    if (!trayBtn.modelData.hasMenu) return;
                                    view.sys.trayMenuItem = trayBtn.modelData;
                                    view.sys.page = "traymenu";
                                    view.sys.holdOpen = true;
                                    return;
                                }
                                if (mouse.button === Qt.MiddleButton)
                                    trayBtn.modelData.secondaryActivate();
                                else
                                    trayBtn.modelData.activate();
                                view.sys.collapse();
                            }
                        }

                        // Your own tooltip instead of the system one: the same black capsule,
                        // which is the whole pill.
                        Rectangle {
                            id: tip
                            readonly property string label:
                                String(trayBtn.modelData.tooltipTitle
                                       || trayBtn.modelData.title || "")

                            visible: opacity > 0.01
                            opacity: (trayMa.containsMouse && label.length) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            width: tipText.implicitWidth + 20
                            height: 26
                            radius: 13
                            x: (parent.width - width) / 2
                            y: -height - 8
                            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
                            border.color: view.sys.colLine
                            border.width: 1

                            scale: trayMa.containsMouse ? 1 : 0.92
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: tip.label
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ---------------------------------------------------------- battery
        // Power modes plus everything UPower knows about charge: how much
        // work remaining (or until fully charged), capacity and wear.
        ColumnLayout {
            id: battPage
            width: parent.width
            spacing: 8
            opacity: view.sys.page === "battery" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Батарея")
                onBack: view.sys.page = "main"
            }

            // large status bar: percentage and what's happening now
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                readonly property color tint:
                    view.sys.batteryCharging || view.sys.acOnline ? view.sys.colOk
                  : view.sys.batteryPct <= 15 ? view.sys.colCrit
                  : view.sys.colFg

                // while charging is connected, the die is filled with a living wave
                ChargeWave {
                    anchors.fill: parent
                    radius: parent.radius
                    tint: view.sys.colOk
                    level: view.sys.batteryPct / 100
                    running: view.sys.batteryCharging
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: view.sys.batteryLevelIcon
                        color: parent.parent.tint
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 3
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: view.sys.batteryPct + "%"
                            color: parent.parent.parent.tint
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.sys.batteryCharging
                                  ? view.sys.tr("Заряжается")
                                  : view.sys.acOnline ? view.sys.tr("От сети")
                                                      : view.sys.profileLabel
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    // Power indicator instead of time forecasts: lightning,
                    // when charging, plug - when just plugged in.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 15
                        visible: view.sys.batteryCharging || view.sys.acOnline
                        color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g,
                                       view.sys.colOk.b, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(
                                      view.sys.batteryCharging ? 0xF0241 : 0xF06A5)
                            color: view.sys.colOk
                            font { family: view.sys.fontFam; pixelSize: 15 }
                            // While charging, lightning gently pulsates
                            SequentialAnimation on opacity {
                                running: view.sys.batteryCharging
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }
            }

            // diets - those same three segments now live here
            RowLayout {
                visible: view.sys.showPowerProfiles
                Layout.fillWidth: true
                spacing: 8

                PowerSeg {
                    icon: "󰾆"
                    label: view.sys.tr("Экономия")
                    profile: "power-saver"
                    accent: view.sys.colOk
                }
                PowerSeg {
                    icon: "󰾅"
                    label: view.sys.tr("Баланс")
                    profile: "balanced"
                    accent: view.sys.colOn
                }
                PowerSeg {
                    icon: "󰓅"
                    label: view.sys.tr("Максимум")
                    profile: "performance"
                    accent: view.sys.colWarn
                }
            }

            // small numbers - capacity, wear and current consumption, in one strip
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.batteryPresent

                BattStat {
                    label: view.sys.tr("Ёмкость")
                    value: view.sys.batteryCapacity > 0
                           ? view.sys.batteryCapacity.toFixed(1) + " Wh" : "—"
                }
                BattStat {
                    label: view.sys.tr("Износ")
                    value: view.sys.batteryHealth > 0
                           ? view.sys.batteryHealth + "%" : "—"
                }
                BattStat {
                    label: view.sys.batteryCharging ? "󰐥" : "󰚥"
                    value: Math.abs(view.sys.batteryRate) > 0.05
                           ? Math.abs(view.sys.batteryRate).toFixed(1) + " W" : "—"
                }
            }
        }

        // ------------------------------------------------------------ Wi-Fi
        ColumnLayout {
            id: wifiPage
            width: parent.width
            spacing: 7

            // What kind of network is selected with the right button and what can be done with it.
            property string menuSsid: ""
            property bool menuConnected: false
            property bool menuKnown: false

            opacity: view.sys.page === "wifi" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Сети Wi-Fi")
                busy: view.sys.wifiBusy
                onBack: { view.sys.page = "main"; passwordFor = ""; }
                onRefresh: view.sys.scanWifi()
            }

            // entering the password for the selected network
            property string passwordFor: ""
            property string passwordSecurity: "psk"

            TextField {
                id: userField
                Layout.fillWidth: true
                visible: wifiPage.passwordFor.length > 0 && wifiPage.passwordSecurity === "eap"
                placeholderText: view.sys.tr("Имя пользователя")
                color: view.sys.colFg
                placeholderTextColor: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 12 }
                onAccepted: pwField.forceActiveFocus()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                visible: wifiPage.passwordFor.length > 0
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 7
                    spacing: 8

                    Text {
                        text: "󰌾"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Пароль от «") + wifiPage.passwordFor + "»"
                        echoMode: TextInput.Password
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        background: null
                        onAccepted: connectBtn.go()
                    }
                    Rectangle {
                        id: connectBtn
                        function go() {
                            if (!pwField.text.length || (wifiPage.passwordSecurity === "eap" && !userField.text.length)) return;
                            view.sys.connectWifi(wifiPage.passwordFor, pwField.text, userField.text, wifiPage.passwordSecurity);
                            wifiPage.passwordFor = "";
                            pwField.text = "";
                            userField.text = "";
                            view.sys.holdOpen = false;
                        }
                        Layout.preferredWidth: 34; Layout.preferredHeight: 32
                        radius: 10
                        color: pwField.text.length && (wifiPage.passwordSecurity !== "eap" || userField.text.length)
                               ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent; text: "󰁕"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.go()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiError.length > 0
                text: view.sys.wifiError
                color: view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            // list of networks
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.wifiNetworks
                    Row1 {
                        required property var model
                        readonly property bool isConnecting: view.sys.wifiConnectingSsid.length > 0 && model.ssid === view.sys.wifiConnectingSsid
                        icon: isConnecting ? "󰤩" : (model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟")
                        title: model.ssid
                        sub: isConnecting ? view.sys.tr("Подключение…")
                             : ((model.security === "open" ? view.sys.tr("Открытая") : model.security === "eap" ? view.sys.tr("Корпоративная") : view.sys.tr("Защищённая"))
                              + " · " + model.quality + "%"
                              + (model.known ? view.sys.tr(" · сохранена") : ""))
                        highlight: model.connected || isConnecting
                        onActivated: {
                            if (model.connected || isConnecting) return;
                            if (model.security === "open" || model.known) {
                                view.sys.connectWifi(model.ssid, "");
                            } else {
                                wifiPage.passwordFor = model.ssid;
                                wifiPage.passwordSecurity = model.security;
                                view.sys.holdOpen = true;
                                pwFocus.restart();
                            }
                        }
                        onMenuRequested: (mx, my) => {
                            // the menu only makes sense where there is something to do:
                            // You can disconnect from the current one, forget the saved one
                            if (!model.connected && !model.known) return;
                            wifiPage.menuSsid = model.ssid;
                            wifiPage.menuConnected = model.connected;
                            wifiPage.menuKnown = model.known;
                            view.sys.page = "netmenu";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiNetworks.count === 0
                text: view.sys.wifiBusy ? view.sys.tr("Поиск сетей…") : view.sys.tr("Сети не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            Timer { id: pwFocus; interval: 80; onTriggered: (wifiPage.passwordSecurity === "eap" ? userField : pwField).forceActiveFocus() }

        }

        // ------------------------------------------------- network menu
        // A separate page, like a tray menu: the panel is narrow, and a pop-up window
        // on top of the list would have to be moved so that it does not go off the edge.
        // The page opens with the right button on the network and can do exactly what
        // not on the list itself: disconnect and forget.
        ColumnLayout {
            id: netMenuPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "netmenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: wifiPage.menuSsid.length ? wifiPage.menuSsid : view.sys.tr("Сеть")
                busy: view.sys.wifiBusy
                onBack: view.sys.page = "wifi"
                onRefresh: {}
            }

            Row1 {
                visible: wifiPage.menuConnected
                icon: "󰖪"
                title: view.sys.tr("Отключиться")
                sub: view.sys.tr("Связь разорвётся, сеть останется сохранённой")
                onActivated: {
                    view.sys.disconnectWifi();
                    view.sys.page = "wifi";
                }
            }

            Row1 {
                visible: wifiPage.menuKnown
                icon: "󰅖"
                title: view.sys.tr("Забыть сеть")
                sub: view.sys.tr("Больше не подключаться самому")
                onActivated: {
                    view.sys.forgetWifi(wifiPage.menuSsid);
                    view.sys.page = "wifi";
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !wifiPage.menuConnected && !wifiPage.menuKnown
                text: view.sys.tr("Для этой сети ничего не сохранено.")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // ------------------------------------------- tray context menu
        ColumnLayout {
            id: trayPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "traymenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // chain of nested submenus: the last element is the current menu
            property var chain: []
            readonly property var rootHandle:
                view.sys.trayMenuItem ? view.sys.trayMenuItem.menu : null
            readonly property var handle:
                chain.length > 0 ? chain[chain.length - 1] : rootHandle

            // new icon - start from its root menu.
            // We assign only when there is something to discard: otherwise QML sees
            // the cycle chain -> handle -> chain and swears at every opening.
            onRootHandleChanged: if (chain.length > 0) chain = []

            QsMenuOpener {
                id: menuOpener
                menu: trayPage.handle
            }

            Header {
                title: view.sys.trayMenuItem
                       ? String(view.sys.trayMenuItem.tooltipTitle
                                || view.sys.trayMenuItem.title || view.sys.tr("Меню"))
                       : view.sys.tr("Меню")
                busy: false
                onBack: {
                    if (trayPage.chain.length > 0) {
                        var c = trayPage.chain.slice();
                        c.pop();
                        trayPage.chain = c;
                    } else {
                        view.sys.page = "main";
                        view.sys.trayMenuItem = null;
                    }
                }
                onRefresh: {}
            }

            Repeater {
                model: menuOpener.children

                // separator and regular item - in one delegate: Repeater
                // cannot select a component based on model data
                Item {
                    id: entry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colLine
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && entry.modelData.enabled
                               ? view.sys.colHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            // check mark/radio for toggle items
                            Text {
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                text: entry.modelData.checkState === Qt.Checked
                                      ? "󰄬" : "󰝦"
                                color: entry.modelData.checkState === Qt.Checked
                                       ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Image {
                                visible: String(entry.modelData.icon || "").length > 0
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: String(entry.modelData.icon || "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(entry.modelData.text || "")
                                color: entry.modelData.enabled
                                       ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            // arrow at submenu
                            Text {
                                visible: entry.modelData.hasChildren
                                text: ""
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    var c = trayPage.chain.slice();
                                    c.push(entry.modelData);
                                    trayPage.chain = c;
                                    return;
                                }
                                entry.modelData.triggered();
                                view.sys.collapse();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !menuOpener.children || menuOpener.children.values.length === 0
                text: view.sys.tr("Меню пустое")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // -------------------------------------------------------- Bluetooth
        ColumnLayout {
            id: btPage
            width: parent.width
            spacing: 7
            opacity: view.sys.page === "bt" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Устройства Bluetooth")
                busy: view.sys.btAdapter ? view.sys.btAdapter.discovering : false
                onBack: view.sys.page = "main"
                onRefresh: view.sys.scanBt()
            }

            Process { id: pBtRemove }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.btDevices
                    RowLayout {
                        id: btDevRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Row1 {
                            id: row1
                            Layout.fillWidth: true
                            icon: (modelData.icon === "audio-headset" || modelData.icon === "audio-headphones") ? "󱡏"
                                : modelData.icon === "input-mouse" ? "󰦋"
                                : modelData.icon === "input-keyboard" ? "󰌌"
                                : (modelData.icon === "audio-speakers" || modelData.icon === "audio-speaker") ? "󰓃"
                                : modelData.icon === "input-gaming" ? "󰊴"
                                : (modelData.icon === "phone" || modelData.icon === "smartphone") ? "󰄞"
                                : modelData.icon === "watch" ? "󰖄" : "󰂯"
                            title: modelData.name || modelData.address
                            sub: modelData.pairing ? view.sys.tr("Сопряжение…")
                               : modelData.state === BluetoothDeviceState.Connecting ? view.sys.tr("Подключение…")
                               : modelData.connected ? view.sys.tr("Подключено")
                               : (modelData.paired || modelData.bonded ? view.sys.tr("Сопряжено") : view.sys.tr("Доступно"))
                                 + (modelData.batteryAvailable
                                    ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                            highlight: modelData.connected || modelData.pairing
                                       || modelData.state === BluetoothDeviceState.Connecting
                            onActivated: {
                                if (modelData.connected) {
                                    if (view.sys.disconnectBt) view.sys.disconnectBt(modelData.address);
                                    modelData.disconnect();
                                    return;
                                }
                                if (view.sys.connectBt) view.sys.connectBt(modelData.address);
                                modelData.trusted = true;
                                if (modelData.paired || modelData.bonded) modelData.connect();
                                else modelData.pair();
                            }
                            property var dev: modelData
                            Connections {
                                target: row1.dev
                                function onPairedChanged() {
                                    if (row1.dev.paired && !row1.dev.connected) row1.dev.connect();
                                }
                            }
                        }

                        // Botão Esquecer / Desemparelhar dispositivo
                        Rectangle {
                            visible: modelData.paired || modelData.bonded
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: unpairMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: unpairMa.containsMouse ? "#ff6666" : view.sys.colLine
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: unpairMa.containsMouse ? "#ff6666" : view.sys.colMuted
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: unpairMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pBtRemove.command = ["bluetoothctl", "remove", modelData.address];
                                    pBtRemove.running = true;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !view.sys.btDevices || view.sys.btDevices.values.length === 0
                text: (view.sys.btAdapter && view.sys.btAdapter.discovering)
                      ? view.sys.tr("Поиск устройств…") : view.sys.tr("Устройства не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

    }
}
