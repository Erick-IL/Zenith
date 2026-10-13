import QtQuick

// The concave angle of contact with the edge of the screen is similar to the cutout on macOS.
//
// The fill occupies a square r×r, from which a quarter of a circle is cut
// centered on the lower outer corner. This results in a smooth transition from
// the top edge of the screen to the side of the pill, without a “step”.
Canvas {
    id: corner

    // "left" - the corner to the left of the pill (the notch faces left and down)
    // "right" - mirrored
    property string side: "left"
    property color fill: "#000000"
    property real r: 12

    width: r
    height: r

    onFillChanged: requestPaint()
    onRChanged: requestPaint()
    onSideChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = corner.fill;
        ctx.beginPath();

        if (side === "left") {
            // cutout center - at point (0, r): lower outer corner
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.lineTo(r, r);
            ctx.arc(0, r, r, 0, -Math.PI / 2, true);
        } else {
            // mirrored: center of cut at (r, r)
            ctx.moveTo(r, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, -Math.PI / 2, false);
        }

        ctx.closePath();
        ctx.fill();
    }
}
