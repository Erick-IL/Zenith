import QtQuick

// Weather icon with dots - pair to DotText.
//
// With the same grid of seven rows and the same circles as the numbers: the icon is
// with them on the same line, and any other drawing would read like an insert from
// someone else's set. The size is set by height in pixels - like text.
//
// The drawings are deliberately crude. At a height of one and a half dozen pixels details
// they are eaten anyway, but the weather is recognized by its silhouette: the cloud has two tubercles
// of different heights, the sun has a circle with rays, the rain has a cloud and drops under it.
//
// The cloud has a left tubercle lower than the right one, but there are no dots in the corners - it comes out
// slight bevel. Even corners and identical tubercles produced a brick with two
// cones; the whole difference between him and the cloud is this asymmetry.
//
// The tubercle is composed of steps: three points on top, five below them. One
// there are few steps - the transition from the top straight to the body is read as a cliff - and
// More than two cannot fit into seven rows.
//
// Right side is higher than left: in the far right column there are four dots against
// three on the left. Otherwise the cloud comes out symmetrical, and the symmetrical cloud
// read as a geometric figure.
//
// Hence the width of thirteen columns: two tubercles of five points each
// the base next to each other, and the gap between them, does not fit into eleven.
//
// The cloud of rain, snow and thunderstorm is the same: the difference between them is below, and
// a different cloud from above would be read as different weather, not different precipitation.
Item {
    id: ico

    // View code "04d" from OpenWeatherMap - there is no difference between day and night:
    // the moon instead of the sun in seven rows turns into the same circle.
    property string code: ""
    property real size: 16
    property real gapRatio: 0.22
    property color color: "#ffffff"

    readonly property real dotSize: ico.size / (7 + 6 * ico.gapRatio)
    readonly property real gap: ico.dotSize * ico.gapRatio
    readonly property real pitch: ico.dotSize + ico.gap

    readonly property var shapes: ({
        "clear":       ["0000001000000", "0001011101000", "0000111110000", "0010111110100",
                        "0000111110000", "0001011101000", "0000001000000"],
        "clear_night": ["0000011110000", "0000111111000", "0001111000000", "0001110000000",
                        "0001111000000", "0000111111000", "0000011110000"],
        "few":         ["0000000001110", "0000000011111", "0011100111110", "0111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "few_night":   ["0000000011100", "0000000111100", "0011100111000", "0111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "cloud":       ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "1111111111111", "1111111111111", "0111111111110"],
        "rain":        ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0001001001000", "0010010010000"],
        "snow":        ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0001001001000", "0000100010000"],
        "storm":       ["0000000011100", "0011100111110", "0111111111111", "1111111111111",
                        "0111111111110", "0000011100000", "0000110000000"],
        "mist":        ["0000000000000", "0001111111000", "0000000000000", "0011111111100",
                        "0000000000000", "0001111111000", "0000000000000"]
    })

    // The first two digits of the code are the weather itself, the third letter is the time of day.
    readonly property string shapeName: {
        var s = String(ico.code);
        var k = s.slice(0, 2);
        var isNight = s.length >= 3 && s[2] === "n";
        return k === "01" ? (isNight ? "clear_night" : "clear")
             : k === "02" ? (isNight ? "few_night" : "few")
             : (k === "03" || k === "04") ? "cloud"
             : (k === "09" || k === "10") ? "rain"
             : k === "11" ? "storm"
             : k === "13" ? "snow"
             : k === "50" ? "mist"
             // Unfamiliar code - cloud: the service introduced a new type of weather, and
             // A cloud lies less than an empty space or the sun.
             : "cloud";
    }

    readonly property var grid: ico.shapes[ico.shapeName]

    readonly property var cells: {
        var out = [];
        var g = ico.grid;
        if (!g) return out;
        for (var r = 0; r < g.length; r++)
            for (var c = 0; c < g[r].length; c++)
                if (g[r][c] === "1")
                    out.push({ x: c * ico.pitch, y: r * ico.pitch });
        return out;
    }

    implicitWidth: (ico.grid ? ico.grid[0].length : 13) * ico.pitch - ico.gap
    implicitHeight: 7 * ico.pitch - ico.gap

    Repeater {
        model: ico.cells

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: ico.dotSize
            height: ico.dotSize
            radius: ico.dotSize / 2
            color: ico.color
        }
    }
}
