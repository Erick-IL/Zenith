import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Selecting wallpaper in full screen: a carousel where the selected wallpaper is in the center,
// and the neighboring ones go deeper on the sides. Previously it was a narrow list under the pill
// — the picture in it was almost invisible, but you still choose wallpaper with your eyes.
//
// A carousel move is counted in fractional “positions” (pos): each card knows
// its distance to the center and uses it to decide how much to decrease,
// turn pale and move the picture inside the frame. The latter gives parallax:
// the frame moves faster than its contents.
Item {
    id: view
    property var sys

    // fractional carousel position; target - target, animation between them
    property real pos: 0
    property int  target: 0
    Behavior on pos {
        NumberAnimation { duration: 420; easing.type: Easing.OutQuint }
    }
    onTargetChanged: view.pos = view.target

    property string applying: ""
    // wallpaper that now expands to fill the entire screen when selected
    property string flying: ""
    // Thumbnail of the selected wallpaper: it is already decoded, so the spread
    // starts with a picture, not a black rectangle.
    property string flyingThumb: ""
    // Did the person leaf through it himself? Not yet - we keep the focus on the current wallpaper, even
    // if the list has been updated: when opening the menu, they look for exactly what it costs.
    property bool userScrolled: false

    // Tab: "still" - regular wallpaper, "live" - video. Model, script and
    // the captions change along with it, the carousel remains the same.
    property string mode: "still"
    // Wheel drive: the mouse and touchpad sprinkle dozens of small events, and
    // one card for each, the tape flew past. We only walk when
    // accumulated per click (120 units), and no more than one step per pause.
    property real wheelAcc: 0
    readonly property bool live: view.mode === "live"
    // Is the menu open? A separate property, not directly sys.wallsOpen: for now
    // the selected wallpaper is inserted, the menu is already “closed” for animations, but the window
    // still alive - otherwise it would blink back before disappearing.
    readonly property bool open: view.sys.wallsOpen && view.applying.length === 0

    readonly property int cardW: Math.round(Math.min(width * 0.44, 760))
    readonly property int cardH: Math.round(cardW * 9 / 16)
    // step between cards: less width, so neighbors peep from behind the edges
    readonly property real step: cardW * 0.62

    ListModel { id: walls }

    focus: true
    Component.onCompleted: {
        reload(); jumpToActive(); forceActiveFocus(); warmDelay.restart();
    }

    Keys.onEscapePressed: view.sys.closeWalls()
    Keys.onLeftPressed:   view.move(-1)
    Keys.onRightPressed:  view.move(1)
    Keys.onUpPressed:     view.move(-1)
    Keys.onDownPressed:   view.move(1)
    Keys.onReturnPressed: view.activate()
    Keys.onEnterPressed:  view.activate()
    Keys.onSpacePressed:  view.activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { view.target = 0; event.accepted = true; }
        else if (event.key === Qt.Key_End) {
            view.target = Math.max(0, walls.count - 1); event.accepted = true;
        }
    }

    function move(d) {
        if (walls.count === 0) return;
        view.userScrolled = true;
        view.target = Math.max(0, Math.min(walls.count - 1, view.target + d));
    }
    function activate() {
        if (view.target < 0 || view.target >= walls.count) return;
        var w = walls.get(view.target);
        if (w.wActive) { view.sys.closeWalls(); return; }
        view.flyingThumb = w.wThumb;
        view.apply(w.wPath);
    }

    // Updating the model in place: we only edit the matching lines, the extra ones
    // remove from the end. Cards are not recreated, so the pictures do not blink
    // and do not load again, and scrolling does not reset to the first wallpaper.
    function applyRows(rows, act) {
        var first = walls.count === 0;
        for (var i = 0; i < rows.length; i++) {
            if (i < walls.count) walls.set(i, rows[i]);
            else                 walls.append(rows[i]);
        }
        while (walls.count > rows.length) walls.remove(walls.count - 1);
        // While we haven’t flipped through it, we’re standing on the current wallpaper. The list is updated on
        // opening, and after warming up the miniatures, and before the focus after that
        // went to an unknown place.
        if ((first || !view.userScrolled) && act >= 0) {
            view.target = act;
            view.pos = act;
        } else if (view.target >= walls.count) {
            view.target = Math.max(0, walls.count - 1);
        }
    }

    // The list is read by the root (sys.wallList / sys.liveList) - here only
    // put it into a model. The discovery is therefore immediate: the data is already there.
    //
    // The mode can be passed explicitly. This is important when switching tabs: inside
    // the onModeChanged handler, the live binding still returns the PREVIOUS value, and
    // the list was taken from the old tab - pictures on “live” ones and vice versa.
    function reload(liveOverride) {
        var isLive = liveOverride === undefined ? view.live : liveOverride;
        var rows = (isLive ? view.sys.liveList : view.sys.wallList) || [];
        var act = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].wActive) act = i;
        view.applyRows(rows, act);
    }
    Connections {
        target: view.sys
        function onWallListChanged() { if (!view.live) view.reload(); }
        function onLiveListChanged() { if (view.live)  view.reload(); }
    }
    onModeChanged: {
        var isLive = view.mode === "live";
        view.userScrolled = false;
        view.reload(isLive);
        view.jumpToActive();
        if (isLive) liveWarmDelay.restart();
    }

    // Warming up thumbnails for new wallpapers - after the carousel
    // opened and showed something. When he finishes, we re-read the list: those
    // cards that were loaded from sources will be moved to miniatures.
    Process {
        id: pWarm
        command: ["sh", "-c", view.sys.scriptDir + "/themes.sh warm"]
        // While the warm-up is underway, we pick up ready-made miniatures: wait for everything
        // three hundred ffmpeg before the first update is minutes.
        onRunningChanged: {
            if (running) warmPoll.restart();
            else { warmPoll.stop(); view.sys.refreshWalls(); }
        }
    }
    Timer {
        id: warmPoll
        interval: 2500
        repeat: true
        onTriggered: if (view.sys.wallsOpen) view.sys.refreshWalls();
                     else pWarm.running = false;
    }
    Timer {
        id: warmDelay
        interval: 900
        onTriggered: pWarm.running = true
    }

    // Video posters: a shot from the middle of each. Also after opening -
    // pulling frames from dozens of files synchronously means waiting.
    Process {
        id: pLiveWarm
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "warm"]
        onRunningChanged: if (!running) view.sys.refreshLiveWalls()
    }
    Timer {
        id: liveWarmDelay
        interval: 700
        onTriggered: pLiveWarm.running = true
    }

    Process {
        id: pSet
        // The wallpaper is already in place: turn off the crossfade and close the window. Self
        // “applying” is held until the end - otherwise the menu was shown per frame
        // back before closing.
        onRunningChanged: {
            if (running) return;
            view.sys.endThemeFade();
            closeAfter.restart();
        }
    }
    Timer {
        id: closeAfter
        // we wait until the card reaches the edges: close it earlier - and it’s visible
        // jump, window disappears in the middle of the movement
        interval: 560
        onTriggered: view.sys.closeWalls()
    }
    // For each opening we stand on the current wallpaper: return to the place
    // where you flipped through the last time, there is no need - with your eyes they look for “what is standing now.”
    // We reset the application state only when the window is no longer visible.
    Connections {
        target: view.sys
        function onWallsOpenChanged() {
            if (view.sys.wallsOpen) { view.userScrolled = false; view.jumpToActive(); }
            else                    resetAfterClose.restart();
        }
    }
    function jumpToActive() {
        for (var i = 0; i < walls.count; i++) {
            if (walls.get(i).wActive) { view.target = i; view.pos = i; return; }
        }
    }
    Timer {
        id: resetAfterClose
        interval: 400
        onTriggered: { view.applying = ""; view.flying = ""; view.flyingThumb = ""; }
    }

    // Apply by full path, not by name: names in wallpaper subdirectories
    // are repeated, and it was possible to put the wrong picture by name.
    function apply(path) {
        view.applying = path;
        view.flying = path;
        // a snapshot of the current wallpaper BEFORE the script: after it there is a new path on the disk
        view.sys.startThemeFade();
        pSet.command = view.live
            ? ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/live_wallpaper.sh",
               "set", path]
            : ["sh", "-c", view.sys.scriptDir + "/themes.sh set \"$1\"", "_", path];
        pSet.running = true;
    }

    // readable name: dark_mountains -> Dark mountains
    function pretty(n) {
        var s = String(n).replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Turning the island into a menu: the backing starts exactly where it hangs
    // pill (it is hidden for this time), and stretches to the edges. Therefore
    // the menu reads like an expanded island rather than a separate window.
    Rectangle {
        id: morph
        color: view.sys.colBg
        z: -1
        x:      view.open ? 0 : view.sys.pillRectX
        y:      view.open ? 0 : view.sys.pillRectY
        width:  view.open ? view.width  : Math.max(8, view.sys.pillRectW)
        height: view.open ? view.height : Math.max(8, view.sys.pillRectH)
        radius: view.open ? 0 : Math.min(width, height) / 2
        opacity: view.open ? 0.30 : 0.96
        visible: view.sys.wallsOpen

        Behavior on x      { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on y      { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on width  { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on radius { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
    }

    // clicking on an empty space closes it - like the table review
    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.closeWalls()
        onWheel: wheel => {
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            if (d === 0) return;
            // when changing direction, save again, otherwise the previous balance
            // first moves the tape in the same direction
            if ((d > 0) !== (view.wheelAcc > 0)) view.wheelAcc = 0;
            // we limit the stock: a sharp jerk should not put you in a queue
            // ten steps, which then play out on their own
            view.wheelAcc = Math.max(-240, Math.min(240, view.wheelAcc + d));
            if (wheelCool.running || Math.abs(view.wheelAcc) < 120) return;
            view.wheelAcc += view.wheelAcc > 0 ? -120 : 120;
            view.move(view.wheelAcc > 0 ? -1 : (view.wheelAcc < 0 ? 1 : (d > 0 ? -1 : 1)));
            wheelCool.restart();
        }
    }

    // pause between steps: the card manages to reach the center
    Timer { id: wheelCool; interval: 130 }

    // ------------------------------------------------------------- title
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(view.height * 0.09)
        spacing: 2
        opacity: view.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.live ? view.sys.tr("Живые обои") : view.sys.tr("Обои")
            color: view.sys.colFg
            font {
                family: view.sys.fontFam
                pixelSize: view.sys.fontSize + 12; bold: true
            }
        }
        // Tabs: pictures and videos. Their carousel is the same - it changes
        // only the source of the strings and the script that sets the background.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 8

            Repeater {
                model: [
                    { m: "still", t: view.sys.tr("Обои") },
                    { m: "live",  t: view.sys.tr("Живые обои") }
                ]
                Rectangle {
                    id: tabBtn
                    required property var modelData
                    readonly property bool picked: view.mode === tabBtn.modelData.m

                    Layout.preferredWidth: tabTxt.implicitWidth + 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: tabBtn.picked
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                     view.sys.colOn.b, 0.24)
                           : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12)
                                                  : Qt.rgba(1, 1, 1, 0.06))
                    border.color: tabBtn.picked ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Text {
                        id: tabTxt
                        anchors.centerIn: parent
                        text: tabBtn.modelData.t
                        color: tabBtn.picked ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: tabBtn.picked
                        }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.mode = tabBtn.modelData.m
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: walls.count
                  ? (view.target + 1) + " / " + walls.count
                  : (view.live ? view.sys.liveListReady : view.sys.wallListReady)
                    ? (view.live ? view.sys.tr("Папка живых обоев пуста")
                                 : view.sys.tr("Обоев не найдено"))
                    : view.sys.tr("Читаю…")
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }

    // -------------------------------------------------------------- carousel
    Item {
        id: reel
        anchors.fill: parent
        // Appears behind the substrate, and when applied melts on the screen
        // All that remains is the card, which expands to full screen.
        opacity: view.open ? 1 : 0
        scale: view.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
        Behavior on scale {
            NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutQuint }
        }

        Repeater {
            model: walls

            Item {
                id: card
                required property int    index
                required property string wName
                required property string wThumb
                required property bool   wActive
                required property bool   wOwn
                required property string wPath

                // distance to the center in cards: fractional, while the move is in progress
                readonly property real d: card.index - view.pos
                readonly property real ad: Math.abs(card.d)
                readonly property bool centered: card.ad < 0.5

                width: view.cardW
                height: view.cardH
                x: reel.width / 2 - width / 2 + card.d * view.step
                y: reel.height / 2 - height / 2
                // distant cards are smaller and paler - this creates depth
                scale: Math.max(0.5, 1 - card.ad * 0.16)
                opacity: Math.max(0, 1 - card.ad * 0.34)
                visible: card.ad < 4.2
                z: Math.round(100 - card.ad * 10)

                // clip on a rectangle cuts along its FRAME, and not along its radius:
                // The sharp corners of the wallpaper protruded from the rounded card. Therefore
                // the content is drawn into an invisible layer and covered with a mask
                // with a rounding, and the frame lies on top.
                Item {
                    id: frame
                    anchors.fill: parent
                    readonly property int r: 22
                    z: 1

                    Item {
                        id: shot
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle { anchors.fill: parent; color: "#000000" }

                    // Parallax: the picture is wider than the frame and goes in the opposite direction.
                    // The frame went to step, the picture went only to part of it, and
                    // the contents seem to lag behind the movement.
                    Image {
                        id: img
                        width: frame.width * 1.28
                        height: frame.height
                        x: -(frame.width * 0.14) + card.d * (view.step * 0.22)
                        // We load only what is visible near the center: otherwise Qt
                        // undertakes to decode all three hundred at once, and the discovery
                        // lasts for seconds.
                        source: (card.ad < 5 && card.wThumb.indexOf("/") === 0)
                                ? "file://" + card.wThumb : ""
                        fillMode: Image.PreserveAspectCrop
                        // While there is no thumbnail, here comes the 4K source and
                        // more. Without sourceSize, Qt would keep hundreds in memory
                        // full-size frames - one per card.
                        sourceSize.width: Math.round(view.cardW * 1.4)
                        asynchronous: true
                        cache: true
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                    }

                    // while the image is loading - soft pulsation instead of emptiness
                    Rectangle {
                        id: pulse
                        anchors.fill: parent
                        visible: img.status === Image.Loading
                        color: Qt.rgba(1, 1, 1, 0.06)
                        // specifically by id: inside the animation parent is null
                        SequentialAnimation on opacity {
                            running: pulse.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 620 }
                            NumberAnimation { to: 1.0;  duration: 620 }
                        }
                    }

                    // darkening on the sides: the center should be read as the main one
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: Math.min(0.55, card.ad * 0.3)
                    }
                    }

                    // mask: white where the picture is visible
                    Item {
                        id: cardMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.r
                            color: "#ffffff"
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: shot
                        maskEnabled: true
                        maskSource: cardMask
                    }

                    // frame on top of the mask: underneath it would be cut off along with
                    // picture and looked thinner on the fillets
                    Rectangle {
                        anchors.fill: parent
                        radius: frame.r
                        color: "transparent"
                        border.color: card.wActive ? view.sys.colOn
                                    : card.centered ? Qt.rgba(1, 1, 1, 0.55)
                                                    : Qt.rgba(1, 1, 1, 0.10)
                        border.width: card.centered || card.wActive ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    // signature - only at the central one, so as not to ripple.
                    // Lives outside the mask: inside it, the buttons would not receive clicks.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 62
                        radius: frame.r
                        opacity: card.centered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            anchors.bottomMargin: 4
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: view.pretty(card.wName)
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize + 1; bold: true
                                }
                            }

                            // mark “standing now”
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                visible: card.wActive && view.applying.length === 0
                                color: view.sys.colOn
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF012C)
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }
                            }

                            // basket - only for your wallpaper
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                visible: card.wOwn && !card.wActive
                                color: delMa.containsMouse ? view.sys.colCrit
                                                           : Qt.rgba(1, 1, 1, 0.12)
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF01B4)
                                    color: delMa.containsMouse ? "#ffffff" : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 13 }
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.removeWall(card.wName)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // We first place the side one in the center, and only then apply it
                    onClicked: {
                        if (card.centered) view.activate();
                        else { view.userScrolled = true; view.target = card.index; }
                    }
                }
            }
        }
    }

    // The selected wallpaper flies across the entire screen: while the script is running, the card
    // grows to the edges and melts - there is a new background under it.
    Rectangle {
        id: burst
        visible: view.flying.length > 0
        anchors.centerIn: parent
        width: view.flying.length ? view.width : view.cardW
        height: view.flying.length ? view.height : view.cardH
        radius: view.flying.length ? 0 : 22
        clip: true
        // not black: while the large picture is being decoded, black fill
        // flashed across the entire screen
        color: "transparent"
        opacity: view.applying.length ? 1 : 0
        z: 200
        Behavior on width   { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on height  { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on radius  { NumberAnimation { duration: 520; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        // below is a finished miniature, above is the same picture in full size;
        // the second appears when it is decoded, and the substitution is not visible
        Image {
            id: burstThumb
            anchors.fill: parent
            source: view.flyingThumb.length ? "file://" + view.flyingThumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
        }
        Image {
            anchors.fill: parent
            source: view.flying.length ? "file://" + view.flying : ""
            fillMode: Image.PreserveAspectCrop
            // without limitation Qt refuses to decode dozens of wallpapers
            // megapixels: it has a limit of 256 MB per image
            sourceSize.width: view.width
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }

    // --------------------------------------------------------------- tips
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(view.height * 0.08)
        spacing: 22
        opacity: view.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        Repeater {
            model: [
                { k: "← →",   t: view.sys.tr("выбрать") },
                { k: "Enter", t: view.sys.tr("поставить") },
                { k: "Esc",   t: view.sys.tr("закрыть") }
            ]
            RowLayout {
                required property var modelData
                spacing: 7
                Rectangle {
                    Layout.preferredWidth: hintKey.implicitWidth + 16
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        id: hintKey
                        anchors.centerIn: parent
                        text: modelData.k
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }
                }
                Text {
                    text: modelData.t
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
        }

        // Live wallpaper folder: you need to put the video there, so it’s
        // opens the explorer - no need to find the path with your hands.
        Rectangle {
            visible: view.live
            // Width according to the contents, but not narrower than before: it was selected for
            // eye under the Russian inscription, and in another language the text crawled out behind
            // edges of the die.
            Layout.preferredWidth: Math.max(196, liveRow.implicitWidth + 24)
            Layout.preferredHeight: 38
            radius: 13
            color: folderMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
            border.color: folderMa.containsMouse ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                id: liveRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: String.fromCodePoint(0xF024B)
                    color: folderMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                Text {
                    text: view.sys.tr("Папка живых обоев")
                    color: folderMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
            MouseArea {
                id: folderMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys.openLiveFolder()
            }
        }

        // your wallpaper - through the explorer, as before
        Rectangle {
            visible: !view.live
            // Width according to the contents, but not narrower than before: it was selected for
            // eye under the Russian inscription, and in another language the text crawled out behind
            // edges of the die.
            Layout.preferredWidth: Math.max(156, ownRow.implicitWidth + 24)
            Layout.preferredHeight: 38
            radius: 13
            color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
            border.color: addMa.containsMouse ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                id: ownRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: String.fromCodePoint(0xF0415)
                    color: addMa.containsMouse ? view.sys.colOn : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 16 }
                }
                Text {
                    text: view.sys.tr("Свои обои")
                    color: addMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.sys.startWallpaperPick()
            }
        }
    }

    // ------------------------------------------------------ deleting your
    Process { id: pDel }
    function removeWall(name) {
        pDel.command = ["sh", "-c",
            view.sys.scriptDir + "/themes.sh del \"$1\"", "_", name];
        pDel.running = true;
        delTimer.restart();
    }
    Timer {
        id: delTimer
        interval: 250
        onTriggered: view.sys.refreshWalls()
    }

    // Your wallpaper comes from the explorer already on the way - there is no need to ask the name,
    // it is taken from the file name.
    Process {
        id: pAdd
        onRunningChanged: if (!running) { view.sys.wallpaperPick = ""; view.sys.refreshWalls(); }
    }
    onVisibleChanged: if (visible) view.takePick()
    function takePick() {
        if (view.sys.wallpaperPick.length === 0) return;
        pAdd.command = ["sh", "-c",
            view.sys.scriptDir + "/themes.sh add \"$1\"", "_", view.sys.wallpaperPick];
        pAdd.running = true;
    }
    Connections {
        target: view.sys
        function onWallpaperPickChanged() { view.takePick(); }
    }
}
