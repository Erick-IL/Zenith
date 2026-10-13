import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Overview of desktops (Super+Tab).
//
// Previews are not drawn: each window is shown as a live frame through
// ScreencopyView, so the cards continue to contain videos and animations.
// We take the window geometry from lastIpcObject - the same JSON that gives
// hyprctl clients, - and simply compress it to the size of a card.
FocusScope {
    id: view
    property var sys

    // Without focus: true, the keyboard remains at the root of the window, and Enter is in the overlay
    // he just didn’t come anywhere - the table didn’t switch.
    focus: true

    // We store the selection by table number, and not by index in the list: list
    // arrives asynchronously and is still empty on the first frame, so the index
    // counted in onCompleted, pointed in the wrong direction - the overlay opened
    // with a dedicated second table instead of the current one.
    property int currentWs: 0
    readonly property int current: {
        for (var i = 0; i < wsList.length; i++)
            if (wsList[i].id === view.currentWs) return i;
        return 0;
    }

    readonly property var mon: Compositor.isNiri ? Compositor.focusedMonitor : Hyprland.focusedMonitor
    readonly property real monW: mon ? mon.width : 1920
    readonly property real monH: mon ? mon.height : 1080

    // Tables in numerical order. We also show empty ones: people switch to them
    // no less often than for employed people.
    readonly property var wsList: {
        var out = [];
        if (Compositor.isNiri) return Compositor.workspaces;
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (!w || w.id < 0) continue;      // We don’t show special tables
            out.push(w);
        }
        out.sort(function (a, b) { return a.id - b.id; });
        return out;
    }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        // The table from which they opened: the pill knows it exactly and without questioning -
        // she listens to Hyprland events constantly.
        view.currentWs = view.sys.wsId;
        view.forceActiveFocus();
    }
    FocusGrabber { target: view }

    // ------------------------------------------------------------ keys
    function move(d) {
        if (wsList.length === 0) return;
        var i = Math.max(0, Math.min(wsList.length - 1, view.current + d));
        view.currentWs = wsList[i].id;
    }
    Keys.onLeftPressed:  view.move(-1)
    Keys.onRightPressed: view.move(1)
    Keys.onUpPressed:    view.move(-view.columns)
    Keys.onDownPressed:  view.move(view.columns)
    Keys.onEscapePressed: view.sys.closeOverview()
    Keys.onReturnPressed: view.pick(view.current)
    Keys.onEnterPressed:  view.pick(view.current)
    Keys.onSpacePressed:  view.pick(view.current)
    Keys.onTabPressed:    view.move(1)
    Keys.onBacktabPressed: view.move(-1)
    Keys.onPressed: event => {
        // number - directly to the desired table
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var n = event.key - Qt.Key_0;
            for (var i = 0; i < view.wsList.length; i++) {
                if (view.wsList[i].id !== n) continue;
                view.pick(i);
                event.accepted = true;
                return;
            }
        }
    }

    // ------------------------------------------------------------- choice
    // There is no transition animation here: the overlay simply goes away, and the table
    // is replaced by standard Hyprland scrolling - the same as for Super+1 and gestures.
    function pick(i) {
        if (i < 0 || i >= wsList.length) return;
        view.currentWs = wsList[i].id;
        view.sys.gotoWorkspace(wsList[i].id);
        view.sys.closeOverview();
    }

    // ------------------------------------------------------------ layout
    readonly property int columns: Math.min(3, Math.max(1, wsList.length))
    // The card takes up as much as it fits: both in width and height -
    // otherwise, on three columns, the bottom row went off the screen.
    readonly property real cardW: Math.min(
        (view.width - 140) / columns - 20,
        ((view.height - 210) / Math.max(1, Math.ceil(wsList.length / columns)) - 20)
            * (monW / monH))
    readonly property real cardH: cardW * (monH / monW)

    MouseArea {
        anchors.fill: parent
        onClicked: view.sys.closeOverview()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Рабочие столы")
            color: Qt.rgba(1, 1, 1, 0.55)
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 2
            }
        }

        GridLayout {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            columns: view.columns
            rowSpacing: 20
            columnSpacing: 20

            Repeater {
                model: view.wsList

                Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    readonly property bool picked: view.current === card.index
                    readonly property bool live: view.sys.wsId === card.modelData.id

                    Layout.preferredWidth: view.cardW
                    Layout.preferredHeight: view.cardH
                    radius: 16
                    color: Qt.rgba(0.06, 0.06, 0.07, 0.92)
                    border.color: card.picked ? view.sys.colOn
                                : card.live ? Qt.rgba(1, 1, 1, 0.35)
                                            : Qt.rgba(1, 1, 1, 0.12)
                    border.width: card.picked ? 2 : 1
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    scale: card.picked ? 1.04 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 170; easing.type: Easing.OutBack }
                    }

                    // ---------------------------------------- window table
                    // Separate layer with indentation: the card has rounded corners,
                    // and the window, lying close to the edge, was cut off by them.
                    Item {
                        id: winLayer
                        anchors.fill: parent
                        anchors.margins: 7

                    Repeater {
                        model: view.sys.overviewToplevels

                        Item {
                            id: win
                            required property var modelData
                            readonly property var geo: modelData.geo

                            visible: win.geo.ws === card.modelData.id
                            // The window coordinates in the monitor system are compressed to
                            // cards. Hyprland header and frames are not included here
                            // enter - we take the client’s clean geometry.
                            x: (win.geo.x - (view.mon ? view.mon.x : 0)) * winLayer.width / view.monW
                            y: (win.geo.y - (view.mon ? view.mon.y : 0)) * winLayer.height / view.monH
                            width:  win.geo.w * winLayer.width / view.monW
                            height: win.geo.h * winLayer.height / view.monH

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                clip: true

                                // Live window frame: video and animation in preview
                                // keep going because it's the same
                                // a buffer, not a snapshot.
                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.wayland
                                    live: true
                                    paintCursor: false
                                    visible: hasContent
                                    // The window frame is compressed several times, and without
                                    // smoothing the edges of the text crumbled
                                    // into a pixelated mess.
                                    smooth: true
                                    antialiasing: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true
                                }

                                // while there is no frame - application class in text
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.children.length > 0
                                             && !parent.children[0].hasContent
                                    text: String(win.geo.cls || "")
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    elide: Text.ElideRight
                                    width: parent.width - 12
                                    horizontalAlignment: Text.AlignHCenter
                                    font { family: view.sys.fontFam; pixelSize: 11 }
                                }
                            }
                        }
                    }

                    }

                    // ------------------------------------------ signature
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: wsNum.implicitWidth + 18
                        height: 24
                        radius: 12
                        color: card.picked
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.85)
                               : Qt.rgba(0, 0, 0, 0.6)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: wsNum
                            anchors.centerIn: parent
                            text: card.modelData.name
                            color: "#ffffff"
                            font {
                                family: view.sys.fontFam; pixelSize: 12
                                bold: card.picked || card.live
                            }
                        }
                    }

                    // "here you are now" point
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        width: 8; height: 8; radius: 4
                        visible: card.live
                        color: view.sys.colOk
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: view.currentWs = card.modelData.id
                        onClicked: view.pick(card.index)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: view.sys.tr("Стрелки — выбрать · Enter — перейти · Esc — закрыть")
            color: Qt.rgba(1, 1, 1, 0.30)
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }
    }

}
