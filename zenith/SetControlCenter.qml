import QtQuick
import QtQuick.Layouts

// Control Center. The layout contains the panel itself, and not its drawing: the same
// ControlsView, only inanimate. The copy would sooner or later be sold out
// the original - and so a person moves exactly what he sees later.
//
// The order is stored as a string of identifiers separated by commas. Empty string
// means “as from the factory” - so the reset does not have to be described separately, and
// new blocks in future versions will fall into place on their own.
ColumnLayout {
    id: page

    property var sys

    readonly property var blocks: [
        { id: "clock",   name: page.sys.tr("Часы и дата") },
        { id: "toggles", name: page.sys.tr("Wi-Fi · Bluetooth") },
        { id: "sliders", name: page.sys.tr("Громкость и яркость") },
        { id: "media",   name: page.sys.tr("Что играет") },
        { id: "power",   name: page.sys.tr("Запись и режим батареи") },
        { id: "quick",   name: page.sys.tr("Не спать и кнопки") },
        { id: "tray",    name: page.sys.tr("Системный трей") }
    ]
    readonly property var defOrder: page.blocks.map(b => b.id)

    // draft: applied with a button so that the panel does not jump on each shift
    property var order: []
    property bool dirty: false

    function load() {
        var saved = String(page.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        // We check the identifiers with the list of blocks: the setting could remain
        // from the version where there were fewer blocks or they were called differently.
        var out = saved.filter(id => page.defOrder.indexOf(id) >= 0);
        page.defOrder.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        page.order = out;
        page.dirty = false;
    }
    function nameOf(id) {
        for (var i = 0; i < page.blocks.length; i++)
            if (page.blocks[i].id === id) return page.blocks[i].name;
        return id;
    }
    function move(from, to) {
        if (to < 0 || to >= page.order.length || from === to) return;
        var a = page.order.slice();
        a.splice(to, 0, a.splice(from, 1)[0]);
        page.order = a;
        page.dirty = true;
    }

    Component.onCompleted: load()

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Раскладка панели") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Возьмите блок и перетащите — панель встанет в этом порядке после «Применить».")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // The panel itself is full width. If there is less space in the window than
        // occupies the panel, the layout is compressed entirely - proportions are more important
        // natural size.
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            readonly property real scale: Math.min(1, width / Math.max(1, page.sys.panelW))
            implicitHeight: mock.implicitHeight * stage.scale

            ControlsView {
                id: mock
                sys: page.sys
                preview: true
                // the panel listens to the draft, not the saved order:
                // dragged - saw, even before “Apply”
                ccOrderOverride: page.order
                width: page.sys.panelW
                height: implicitHeight
                // non-living: no tile inside should be pressed
                enabled: false
                transformOrigin: Item.TopLeft
                scale: stage.scale
            }

            // Overlays on top of blocks: the panel itself does not know them, you need to move them
            // here. They are placed exactly along the rectangle of their block.
            Repeater {
                model: page.order

                Item {
                    id: grip
                    required property int index
                    required property string modelData
                    readonly property var blk: mock.ccBlock(grip.modelData)
                    property bool held: false

                    // until the block is built, there is nothing to cover the lining
                    visible: grip.blk !== null && grip.blk.height > 0
                    width: stage.width
                    height: grip.blk ? grip.blk.height * stage.scale : 0
                    y: grip.blk ? grip.blk.y * stage.scale : 0
                    z: grip.held ? 10 : 1

                    Behavior on y {
                        enabled: !grip.held
                        NumberAnimation { duration: page.sys.animFade; easing.type: Easing.OutCubic }
                    }

                    // Highlighting only under the cursor and when dragging: otherwise
                    // the overlays would paint over the panel and there would be nothing to see.
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: grip.held
                               ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                               : (gripMa.containsMouse
                                  ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
                                  : "transparent")
                        border.width: grip.held ? 1 : 0
                        border.color: page.sys.colOn
                        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: gripMa.containsMouse || grip.held
                            text: String.fromCodePoint(0xF01DD)   // drag handle
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
                        }
                    }

                    MouseArea {
                        id: gripMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: grip.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: grip
                        drag.axis: Drag.YAxis
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, stage.height - grip.height)

                        onPressed: grip.held = true
                        onReleased: {
                            grip.held = false;
                            page.move(grip.index, page.dropIndex(grip.y + grip.height / 2));
                            // Drag assigned y directly and tore
                            // binding to the block location. We return it: otherwise
                            // the pad will remain where you left it.
                            grip.y = Qt.binding(() => grip.blk ? grip.blk.y * stage.scale : 0);
                        }
                    }
                }
            }
        }
    }

    // Where will a block thrown at height y land: we count by the middles of themselves
    // blocks, and not in equal shares - they are of different heights.
    function dropIndex(y) {
        for (var i = 0; i < page.order.length; i++) {
            var b = mock.ccBlock(page.order[i]);
            if (!b) continue;
            if (y < (b.y + b.height / 2) * mockScale()) return i;
        }
        return page.order.length - 1;
    }
    function mockScale() { return mock.scale; }

    // ------------------------------------------------------------- buttons
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Сбросить")
            onClicked: {
                page.sys.cfg.ccLayout = "";
                page.sys.saveCfg();
                page.load();
            }
        }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Применить")
            primary: true
            enabled: page.dirty
            onClicked: {
                page.sys.cfg.ccLayout = page.order.join(",");
                page.sys.saveCfg();
                page.dirty = false;
            }
        }
    }
}
