import QtQuick

// The numbers with dots are the numbers of the Nothing theme.
//
// Why not a font? The NothingOS (NDot) style is not present in the system.
// there are no repositories, but to require a person to put someone else’s font by hand
// for the sake of one topic - a bad price. Here the numbers are typed in a 5x7 grid and laid out
// circles: they are accurate in any size, are painted like a regular element and do not
// depend on what is installed on the machine.
//
// Circles, not squares: NothingOS has numbers made up of round dots, from
// square, it reads like a regular eighties pixel font.
//
// He only knows the numbers and what stands next to them on the island: the colon,
// percentage, degree, point and minus. The letters were not asked for here - in the layout
// signatures are typed in regular font, and there is a mix of two styles in one word
// no need.
Item {
    id: dt

    property string value: ""

    // The height of a number in pixels is the same as that used to measure regular text. Previously
    // the diameter of the point was specified, and the height was five times greater than it:
    // it was impossible to pick it out by eye, the numbers came out twice as large
    // signatures nearby. Now pixelSize is replaced by a comparable number.
    property real size: 14
    // The clearance between points as a fraction of their diameter is also known as saturation.
    // There is nothing else to set the boldness of a dotted figure: there are no lines, there are
    // just dots, and "thicker" means "tighter". The smaller the clearance, the
    // The larger the dot at the same height, the denser and brighter the number.
    //
    //   0.4 sparse, points stand apart
    //   0.22 regular style - here
    //   0.1 almost close, the thickest
    property real gapRatio: 0.22
    property color color: "#ffffff"

    // From height back to diameter. The number occupies seven rows, between them
    // six clearances: size = 7 d + 6 (d r).
    readonly property real dotSize: dt.size / (7 + 6 * dt.gapRatio)
    readonly property real gap: dt.dotSize * dt.gapRatio

    // clearance between signs; default is one empty grid column
    property real charGap: dt.dotSize + dt.gap

    readonly property real pitch: dt.dotSize + dt.gap

    // The grid is seven lines high. The width of the characters is different: a colon is five
    // columns would look like a hole between the numbers.
    readonly property var glyphs: ({
        // zero without a diagonal through it: Nothing has a smooth oval, while
        // the slash inside is a sign of terminal fonts, not this topic
        "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ":": ["0", "0", "1", "0", "0", "1", "0"],
        ".": ["0", "0", "0", "0", "0", "0", "1"],
        "-": ["000", "000", "000", "111", "000", "000", "000"],
        "%": ["11001", "11010", "00100", "00100", "00100", "01011", "10011"],
        "°": ["111", "101", "111", "000", "000", "000", "000"],
        " ": ["00", "00", "00", "00", "00", "00", "00"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
        "a": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "p": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "m": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"]
    })

    // List of lit points: {x, y} in pixels. We count once per shift
    // lines, and do not hold Repeater for all 35 cells of each sign - at the clock
    // these are two hundred rectangles, of which a quarter is on fire.
    readonly property var cells: {
        var out = [];
        var s = String(dt.value);
        var cx = 0;
        for (var i = 0; i < s.length; i++) {
            var g = dt.glyphs[s[i]];
            // We don’t draw an unfamiliar sign, but we leave space for it: otherwise
            // the line would jump back and forth on an unexpected character
            var w = g ? g[0].length : 3;
            if (g) {
                for (var r = 0; r < g.length; r++)
                    for (var c = 0; c < w; c++)
                        if (g[r][c] === "1")
                            out.push({ x: cx + c * dt.pitch, y: r * dt.pitch });
            }
            cx += w * dt.pitch;
            if (i < s.length - 1) cx += dt.charGap;
        }
        return out;
    }

    // We calculate the width using the same formula, and not according to the right edge of the last one
    // lit dot: the sign with the last column empty (“1”, “7”) has a line
    // otherwise it would be shorter by a column and the neighbors would crawl.
    implicitWidth: {
        var s = String(dt.value);
        if (!s.length) return 0;
        var w = 0;
        for (var i = 0; i < s.length; i++) {
            var g = dt.glyphs[s[i]];
            w += (g ? g[0].length : 3) * dt.pitch;
        }
        return w + (s.length - 1) * dt.charGap - dt.gap;
    }
    implicitHeight: 7 * dt.pitch - dt.gap

    Repeater {
        model: dt.cells

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: dt.dotSize
            height: dt.dotSize
            radius: dt.dotSize / 2
            color: dt.color
        }
    }
}
