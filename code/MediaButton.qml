// A round transport button. Bigger and quieter than IconButton, which is a
// square chip built for dense strips; this one sits in open space where a
// circle reads better and the hit target can afford to be generous.
//
// `enabled` is the ordinary Item property: a player that cannot skip back
// gets a dimmed button that ignores the pointer, rather than a missing one —
// a transport row that changes shape between tracks is hard to aim at.

import QtQuick

Item {
  id: root

  required property var bar
  property string glyph: ""
  property int size: 28
  property int glyphSize: 12
  // The one primary action in the row — play/pause — is filled rather than
  // outlined, so the eye lands on it without reading any of the glyphs.
  property bool filled: false
  property bool activeState: false
  property string tip: ""

  signal activated()

  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  opacity: enabled ? 1 : 0.3
  Behavior on opacity { NumberAnimation { duration: 140 } }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    antialiasing: true
    color: {
      if (root.filled)
        return mouse.containsMouse
          ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 1.0)
          : Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.88)
      if (mouse.containsMouse)
        return Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.14)
      return root.activeState
        ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)
        : "transparent"
    }

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Text {
    anchors.centerIn: parent
    text: root.glyph
    // On the filled button the glyph is cut out of the fill, which is why it
    // takes the island's own ground colour rather than a dimmed foreground.
    color: root.filled ? bar.islandBackground
                       : (root.activeState ? bar.foreground : bar.dim)
    font.family: bar.fontFamily
    font.pixelSize: root.glyphSize
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  ToolTipBubble {
    bar: root.bar
    text: root.tip
    shown: mouse.containsMouse && root.tip !== ""
    target: root
  }
}
