import QtQuick
import QtQuick.Layouts

// Slider with caption on top: name on the left, value with unit on the right,
// underneath them is a full-width path. The value can be changed by dragging,
// and single click on the track.
ColumnLayout {
    id: sl

    property var sys
    property string label: ""
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property string suffix: ""
    // how many decimal places to show in value
    property int decimals: 0
    // The text of the value can be replaced entirely - for example, “off” at zero
    property string valueText: sl.value.toFixed(sl.decimals) + (sl.suffix ? " " + sl.suffix : "")
    signal moved(real value)

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: sl.label
            color: sl.sys.colFg
            elide: Text.ElideRight
            font { family: sl.sys.fontBody; pixelSize: sl.sys.fontSize - 1 }
        }
        Text {
            text: sl.valueText
            color: sl.sys.colMuted
            font { family: sl.sys.fontBody; pixelSize: sl.sys.fontSize - 2 }
        }
    }

    Item {
        id: bar
        Layout.fillWidth: true
        implicitHeight: 18

        // Protection against division by zero, not “not less than one”.
        //
        // Math.max(1, ...) broke any slider with a range narrower than one:
        // transparency from 0.5 to 1.0 was divided by 1 instead of 0.5, and the right edge
        // the scale turned out to be its middle - the handle rested halfway and
        // I didn't go any further. The muted text with its 0.2…1.0 also suffered.
        readonly property real span: Math.max(1e-6, sl.to - sl.from)
        readonly property real frac: Math.max(0, Math.min(1, (sl.value - sl.from) / span))

        function pick(px) {
            var f = Math.max(0, Math.min(1, px / Math.max(1, bar.width)));
            var raw = sl.from + f * span;
            var snapped = Math.round(raw / sl.step) * sl.step;
            sl.moved(Math.max(sl.from, Math.min(sl.to, snapped)));
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(sl.sys.colFg.r, sl.sys.colFg.g, sl.sys.colFg.b, 0.10)

            Rectangle {
                width: parent.width * bar.frac
                height: parent.height
                radius: parent.radius
                color: sl.sys.colOn
            }
        }

        // The handle circle does not extend beyond the edges of the track: at minimum and maximum
        // it rests against them, and does not hang half outward.
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(bar.width - width, bar.width * bar.frac - width / 2))
            color: sl.sys.colOn
            border.width: 2
            border.color: Qt.lighter(sl.sys.colOn, 1.6)
        }

        // The click area is wider than the track: get into the six-pixel strip
        // It's hard to use the mouse. We translate the coordinate into the track system - otherwise
        // the extension would shift the value by its own width.
        MouseArea {
            id: grab
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            // Dragging the handle belongs entirely to the slider: without this
            // scrolling the page took away the gesture on the first vertical
            // trembling of the hand, and the slider froze in place.
            preventStealing: true
            onPressed: mouse => bar.pick(mouse.x + grab.x)
            onPositionChanged: mouse => { if (pressed) bar.pick(mouse.x + grab.x); }
        }
    }
}
