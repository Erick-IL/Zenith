import QtQuick
import QtQuick.Layouts

// Section card: dark square with a rounding, inside there are settings lines.
// There are no dividing lines between the lines; the rhythm is determined only by the indentation step.
Rectangle {
    id: card

    property var sys
    default property alias content: inner.data
    property alias spacing: inner.spacing
    property int pad: 16

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + pad * 2
    radius: 18
    color: Qt.rgba(card.sys.colFg.r, card.sys.colFg.g, card.sys.colFg.b, 0.045)

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: card.pad
        spacing: 14
    }
}
