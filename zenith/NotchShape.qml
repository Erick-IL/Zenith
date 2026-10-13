import QtQuick
import QtQuick.Shapes

// Same concave corner as NotchCorner, but drawn
// geometry, not Canvas.
//
// Why the second component: in settings layouts, the content lies inside
// invisible layer (visible: false + layer.enabled) - this is how the rounded one works
// mask. Canvas in such a layer does not receive a request to draw and remains
// empty: the corners simply did not appear in the layout. Shape is the geometry in the graph
// scene, it does not need a separate drawing pass.
Shape {
    id: corner

    // "left" — fill along the top edge and right side (bottom left cutout)
    // "right" - mirrored: top and left side (cutout bottom right)
    property string side: "left"
    property color fill: "#000000"
    property real r: 12

    width: corner.r
    height: corner.r
    // Insurance: the path must not extend beyond the corner under any circumstances.
    // layout - otherwise the filling will spread beyond the pill.
    clip: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: corner.fill
        strokeWidth: 0
        strokeColor: "transparent"

        // Both figures are a square r×r, from which a quarter of a circle is cut out with
        // centered in the outer bottom corner.
        startX: corner.side === "left" ? 0 : corner.r
        startY: 0

        PathLine { x: corner.side === "left" ? corner.r : 0; y: 0 }
        PathLine { x: corner.side === "left" ? corner.r : 0; y: corner.r }
        PathArc {
            x: corner.side === "left" ? 0 : corner.r
            y: 0
            radiusX: corner.r
            radiusY: corner.r
            // Short arc, not long: screen coordinates go down,
            // so “inside the square” is counterclockwise for left
            // corner and clockwise for the right one. With reverse direction
            // an arc of 270° was drawn, and the corner turned into a wide block
            // behind the island.
            useLargeArc: false
            direction: corner.side === "left" ? PathArc.Counterclockwise
                                              : PathArc.Clockwise
        }
    }
}
