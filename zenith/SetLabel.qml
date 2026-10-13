import QtQuick
import QtQuick.Layouts

// Group heading inside the card: “TYPE”, “SHAPE & DEPTH”.
// Small, sparse, muted - he divides the card, but does not argue
// with settings lines.
Text {
    id: cap

    property var sys

    Layout.fillWidth: true
    Layout.topMargin: 4
    color: Qt.rgba(cap.sys.colFg.r, cap.sys.colFg.g, cap.sys.colFg.b, 0.35)
    font {
        family: cap.sys.fontBody
        pixelSize: cap.sys.fontSize - 5
        letterSpacing: 1.4
        capitalization: Font.AllUppercase
        bold: true
    }
}
