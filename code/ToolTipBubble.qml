// A tooltip drawn inside the island rather than in its own popup window.
//
// The island surface is already much taller than the panel, so a bubble that
// overflows the panel's bottom edge still lands on real surface and still
// takes clicks-through correctly. A PopupWindow here would mean a second
// layer-shell surface per hover, which is a lot of machinery for one line.

import QtQuick

Item {
  id: root

  required property var bar
  property string text: ""
  property bool shown: false
  property var target: parent

  anchors.horizontalCenter: parent.horizontalCenter
  anchors.top: parent.bottom
  anchors.topMargin: 6

  width: bubble.width
  height: bubble.height
  visible: opacity > 0.01
  opacity: shown && text !== "" ? 1 : 0
  z: 999

  Behavior on opacity { NumberAnimation { duration: 120 } }

  Rectangle {
    id: bubble
    width: label.implicitWidth + 16
    height: label.implicitHeight + 10
    radius: 7
    color: Qt.rgba(bar.islandBackground.r, bar.islandBackground.g, bar.islandBackground.b, 0.98)
    border.width: 1
    border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      color: bar.foreground
      font.family: bar.fontFamily
      font.pixelSize: 10
    }
  }
}
