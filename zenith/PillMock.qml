import QtQuick
import QtQuick.Layouts

// Island for Settings Layouts: Same Set of Segments, Same Rules
// roundings and the same concave junction corners as on the live screen.
//
// Lives as a separate component, because there are already two layouts - the desktop in
// tab “Pill” and the explorer mode slider, - and the island in them should
// look the same, otherwise one layout starts to lie.
Item {
    id: mock
    property var sys
    property string pos: "top"          // top | bottom | left | right
    property color fgCol: "#ffffff"
    property color onCol: "#3b82f6"
    // How many times is the layout smaller than the real screen?
    property real k: 0.4
    // readability margin: 1:1 at this scale gives an unreadable 8 px
    property real boost: 1.5

    readonly property bool side: mock.pos === "left" || mock.pos === "right"
    readonly property real thick: Math.max(20, (mock.sys ? mock.sys.pillH : 38)
                                               * mock.k * mock.boost)
    readonly property real fs: Math.max(9, (mock.sys ? mock.sys.fontSize : 15)
                                            * mock.k * mock.boost)
    readonly property real cr: Math.max(5, (mock.sys ? mock.sys.cornerR : 14)
                                             * mock.k * mock.boost)

    Rectangle {
        id: pill
        readonly property real len: mock.side
                ? vertRow.implicitHeight + mock.thick * 0.7
                : horizRow.implicitWidth + mock.thick * 0.9

        width:  mock.side ? mock.thick : pill.len
        height: mock.side ? pill.len : mock.thick
        // There is no stroke: a real island has border.width = 0, and with it the corners
        // can be read with separate stickers.
        color: mock.sys ? mock.sys.colBg : "#0a0a0a"

        // the corners of the pressed edge are cut off - like a living island
        readonly property real freeR: mock.thick / 2
        topLeftRadius:     mock.pos === "top"    || mock.pos === "left"  ? 0 : pill.freeR
        topRightRadius:    mock.pos === "top"    || mock.pos === "right" ? 0 : pill.freeR
        bottomLeftRadius:  mock.pos === "bottom" || mock.pos === "left"  ? 0 : pill.freeR
        bottomRightRadius: mock.pos === "bottom" || mock.pos === "right" ? 0 : pill.freeR

        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : (mock.width - width) / 2
        y: mock.pos === "top"    ? 0
         : mock.pos === "bottom" ? mock.height - height
                                 : (mock.height - height) / 2
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // --- horizontal view
        RowLayout {
            id: horizRow
            anchors.centerIn: parent
            // Transparency, not visible: hidden layout stops counting
            // width, and the island collapses into an empty capsule.
            opacity: mock.side ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
            spacing: mock.thick * 0.3

            Text {
                text: mock.sys ? mock.sys.dayText : ""
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.timeText : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                text: mock.sys ? String(mock.sys.wsId) : "1"
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.kbLayout : "US"
                color: (mock.sys && mock.sys.kbLayout === "RU") ? mock.sys.tint("#7FB3FF")
                     : Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 2; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.batteryIcon : ""
                color: mock.onCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs }
            }
            Text {
                text: (mock.sys ? mock.sys.batteryPct : 0) + "%"
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 2 }
            }
        }

        // --- vertical view: column, straight text
        ColumnLayout {
            id: vertRow
            anchors.centerIn: parent
            opacity: mock.side ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            spacing: mock.thick * 0.14

            // day of the week - letter below the letter
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -2
                Repeater {
                    model: String(mock.sys ? mock.sys.dayText : "").split("")
                    Text {
                        required property string modelData
                        text: modelData
                        color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                        font { family: mock.sys ? mock.sys.fontFam : "monospace"
                               pixelSize: mock.fs - 2; bold: true }
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? (mock.sys.timeText.split(":")[0] || "") : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys
                      ? (mock.sys.timeText.split(":")[1] || "").replace(/[^0-9]/g, "") : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? String(mock.sys.wsId) : "1"
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.kbLayout : "US"
                color: (mock.sys && mock.sys.kbLayout === "RU") ? mock.sys.tint("#7FB3FF")
                     : Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 3; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.batteryIcon : ""
                color: mock.onCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 1 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.batteryPct : ""
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 3 }
            }
        }
    }

    // Concave corners of abutment: stand on both sides of the island and cling to
    // the same edge. The side is selected so that the fill is pressed against the edge
    // screen, vertical reflection makes Scale.
    NotchShape {
        id: notchA
        side: mock.side ? (mock.pos === "left" ? "right" : "left") : "left"
        fill: mock.sys ? mock.sys.colBg : "#0a0a0a"
        r: mock.cr
        transform: Scale {
            origin.y: mock.cr / 2
            yScale: mock.side ? -1 : (mock.pos === "bottom" ? -1 : 1)
        }
        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : pill.x - width
        y: mock.side ? pill.y - height
         : mock.pos === "bottom" ? mock.height - height : 0
    }
    NotchShape {
        id: notchB
        side: mock.side ? (mock.pos === "left" ? "right" : "left") : "right"
        fill: mock.sys ? mock.sys.colBg : "#0a0a0a"
        r: mock.cr
        transform: Scale {
            origin.y: mock.cr / 2
            yScale: mock.side ? 1 : (mock.pos === "bottom" ? -1 : 1)
        }
        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : pill.x + pill.width
        y: mock.side ? pill.y + pill.height
         : mock.pos === "bottom" ? mock.height - height : 0
    }
}
