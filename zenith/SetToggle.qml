import QtQuick
import QtQuick.Layouts

// Line with toggle switch: signature on the left, switch on the right.
// The explanation under the signature is optional - without it, the line remains in one
// line and does not move in height.
RowLayout {
    id: row

    property var sys
    property string label: ""
    property string sub: ""
    property bool on: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: row.label
            color: row.sys.colFg
            elide: Text.ElideRight
            font { family: row.sys.fontBody; pixelSize: row.sys.fontSize - 1 }
        }
        Text {
            Layout.fillWidth: true
            visible: row.sub.length > 0
            text: row.sub
            color: row.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: row.sys.fontBody; pixelSize: row.sys.fontSize - 4 }
        }
    }

    Rectangle {
        id: track
        Layout.preferredWidth: 46
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter
        radius: height / 2
        color: row.on ? row.sys.colOn
                      : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.10)
        Behavior on color { ColorAnimation { duration: row.sys.animFade } }

        Rectangle {
            id: knob
            width: 20
            height: 20
            radius: height / 2
            y: 3
            x: row.on ? track.width - width - 3 : 3
            color: row.on ? row.sys.colBg
                          : Qt.rgba(row.sys.colFg.r, row.sys.colFg.g, row.sys.colFg.b, 0.55)
            Behavior on x { NumberAnimation { duration: row.sys.animHover; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: row.sys.animFade } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled(!row.on)
        }
    }
}
