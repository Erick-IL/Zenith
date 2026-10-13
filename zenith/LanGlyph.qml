import QtQuick

// Wired network icon: three squares connected by a tree.
//
// Drawn, not taken from a font. The design of the finished Nerd Font glyphs is the same
// the same, but the crossbar there is wider than the squares themselves and at these sizes
// read as a solid stripe across the icon. The thickness of the lines in the glyph is not
// correct, this is part of its shape - and here the crossbar comes straight from
// the middle of one bottom square to the middle of the other.
//
// Branches at an angle, not obliquely: we tried inclined ones, but it turned out worse.
//
// Here the thickness is set separately from the size, so the figure remains
// legible both in the quick settings tile and in the collapsed island where it
// twice as small. At the same time, it clearly fits the pixels at any scale, which
// You can't get it from a font glyph at 15 pixels.
Item {
    id: lan

    property color color: "#ffffff"
    // Line thickness is an integer number of pixels, not a fraction of the height: fractional
    // the stroke is smeared by smoothing, and with the size of the island the figure from
    // thin lines turns into a gray spot. The threshold was selected based on two
    // places where the icon is located: in the tile it is large, in the island it is twice as small.
    property real stroke: lan.height <= 20 ? 1 : 2

    implicitWidth: 18
    implicitHeight: 18

    // Squares of the same width: the top one in the center, two at the bottom along the edges.
    // The width is two-fifths of the icon - then there is a gap between the lower ones, and
    // the crossbar is visible as a crossbar, and not as their common cover.
    readonly property real boxW: lan.width * 0.40
    readonly property real boxH: lan.height * 0.26

    // Upper square
    Rectangle {
        x: (lan.width - lan.boxW) / 2
        y: 0
        width: lan.boxW
        height: lan.boxH
        color: "transparent"
        border.color: lan.color
        border.width: lan.stroke
        radius: lan.stroke
    }

    // The process down from the top square is the vertical of the inverted Y
    Rectangle {
        x: (lan.width - lan.stroke) / 2
        y: lan.boxH
        width: lan.stroke
        height: lan.height / 2 - lan.boxH
        color: lan.color
    }

    // Crossbar. It goes exactly from the middle of the lower left square to
    // middle of the right and does not go beyond them: overlap and would turn it into
    // stripe across the icon.
    Rectangle {
        x: lan.boxW / 2 - lan.stroke / 2
        y: lan.height / 2 - lan.stroke / 2
        width: lan.width - lan.boxW + lan.stroke
        height: lan.stroke
        color: lan.color
    }

    // Descents to the bottom squares - the ends of the inverted Y
    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? lan.boxW / 2 - lan.stroke / 2
                               : lan.width - lan.boxW / 2 - lan.stroke / 2
            y: lan.height / 2
            width: lan.stroke
            height: lan.height - lan.boxH - lan.height / 2
            color: lan.color
        }
    }

    // Bottom squares
    Repeater {
        model: [0, 1]
        Rectangle {
            required property int modelData
            x: modelData === 0 ? 0 : lan.width - lan.boxW
            y: lan.height - lan.boxH
            width: lan.boxW
            height: lan.boxH
            color: "transparent"
            border.color: lan.color
            border.width: lan.stroke
            radius: lan.stroke
        }
    }
}
