// A labelled horizontal meter — the one readout shape the system card reuses
// for every quantity, so CPU, memory and disk stay visually comparable.

import QtQuick

Item {
  id: root

  required property var bar
  property string label: ""
  property real percent: 0
  property string value: ""
  // Meters go warm only where the number actually matters; a disk at 90% is
  // worth noticing, a CPU spike at 90% is just work happening.
  property bool warnHigh: false

  implicitHeight: 26

  readonly property real clamped: Math.max(0, Math.min(100, Number(percent) || 0))
  readonly property bool hot: warnHigh && clamped >= 90

  Text {
    id: name
    anchors.left: parent.left
    anchors.top: parent.top
    text: root.label
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
  }

  Text {
    anchors.right: parent.right
    anchors.top: parent.top
    text: root.value
    color: root.hot ? bar.urgent : bar.foreground
    font.family: bar.fontFamily
    font.pixelSize: 10
    font.weight: Font.Medium
  }

  Rectangle {
    id: track
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 4
    radius: 2
    color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)

    Rectangle {
      height: parent.height
      radius: parent.radius
      width: Math.max(root.clamped > 0 ? 3 : 0, parent.width * root.clamped / 100)
      color: root.hot ? bar.urgent : bar.foreground
      opacity: root.hot ? 1 : 0.75

      Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
  }
}
