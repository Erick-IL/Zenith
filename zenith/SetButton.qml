import QtQuick
import QtQuick.Layouts

// Button at the bottom of the settings page: “Apply” next to “Reset”.
//
// Two types. The primary is filled with accent and outlined by it - it
// confirm; an ordinary transparent one with a thin frame - it is canceled. Difference
// only in this: identical buttons next to each other would force both to be read, so that
// understand which one is the main one.
//
// The inactive button does not disappear, but goes out: the disappearing button changes the width of the row,
// and the next one jumps under the cursor.
Rectangle {
    id: btn

    property var sys
    property string text: ""
    property bool primary: false
    // false - the button is visible, but cannot be pressed: there is nothing to apply
    property bool enabled: true

    signal clicked()

    // Width according to the inscription, but not narrower than the previous 112: short buttons - “Apply”,
    // “Reset” - they stand in pairs, and the disparity in their width could be read as carelessness.
    // Previously, the long inscription simply crawled out of the edges: the width was set
    // number, but the text is unlimited.
    Layout.preferredWidth: Math.max(112, btnLabel.implicitWidth + 26)
    Layout.preferredHeight: 32
    radius: 10
    opacity: btn.enabled ? 1 : 0.4

    color: btn.primary
           ? (ma.containsMouse
              ? Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.34)
              : Qt.rgba(btn.sys.colOn.r, btn.sys.colOn.g, btn.sys.colOn.b, 0.22))
           : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
    border.width: 1
    border.color: btn.primary ? btn.sys.colOn : btn.sys.colLine

    Behavior on color { ColorAnimation { duration: btn.sys.animFade } }
    Behavior on opacity { NumberAnimation { duration: btn.sys.animFade } }

    Text {
        id: btnLabel
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? btn.sys.colFg : btn.sys.colMuted
        font {
            family: btn.sys.fontBody
            pixelSize: btn.sys.fontSize - 3
            bold: btn.primary
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
