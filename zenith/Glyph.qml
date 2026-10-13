import QtQuick

// Nerd Font icon, centered on the actual borders of the design.
//
// Regular Text is centered within its frame, which is the width of the glyph's advance. At the icons
// Material Design ink is wider than advance and sits in it asymmetrically: for example,
// the gear has pixelSize 16 advance = 9.6, and the image itself is 13 px wide.
// Therefore, anchors.centerIn noticeably moves the icon to the side.
//
// TextMetrics returns boundingRect and tightBoundingRect RELATIVE TO BASE
// LINES (y negative up) rather than relative to the top left corner
// element. We recalculate Text into local coordinates and combine the center
// ink with the center of the element.
Item {
    id: glyph

    property string glyph: ""
    property color color: "#ffffff"
    property string fontFam: "monospace"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    TextMetrics {
        id: tm
        font { family: glyph.fontFam; pixelSize: glyph.size }
        text: glyph.glyph
    }

    // baseline inside Text frame
    readonly property real baselineY: -tm.boundingRect.y
    // ink center at Text coordinates
    readonly property real inkX: tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2
    readonly property real inkY: baselineY + tm.tightBoundingRect.y
                                 + tm.tightBoundingRect.height / 2

    Text {
        text: glyph.glyph
        color: glyph.color
        font {
            family: glyph.fontFam; pixelSize: glyph.size
            // at small sizes the glyph without hinting blurs
            hintingPreference: Font.PreferFullHinting
        }

        // round the position: on fractional coordinates the icon is blurred
        // by subpixels and looks dirty
        x: Math.round(glyph.width  / 2 - glyph.inkX)
        y: Math.round(glyph.height / 2 - glyph.inkY)

        Behavior on color { ColorAnimation { duration: 160 } }
    }
}
