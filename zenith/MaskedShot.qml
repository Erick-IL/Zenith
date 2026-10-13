import QtQuick
import QtQuick.Effects

// Content clipped to a rounded mask.
//
// Rectangle's clip cuts along its FRAME, and not along its radius: the picture is inside
// The rounded card had sharp corners sticking out. Therefore the content is drawn in
// invisible layer (src), mask - second layer with rounded white
// rectangle (mask), and here they are added.
MultiEffect {
    property Item src
    property Item mask

    source: shot.src
    maskEnabled: true
    maskSource: shot.mask

    // we refer to ourselves by id: inside the bindings the parent is no longer the same
    id: shot
}
