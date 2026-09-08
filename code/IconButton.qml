// A small square glyph button with an optional trailing count. Used in the
// header and footer strips; the cards use their own inline affordances.

import QtQuick

Item {
  id: root

  required property var bar
  property string glyph: ""
  property string label: ""
  property string tip: ""
  // `activeState` means the thing behind the button is on; `highlighted` means
  // this button's own sheet is currently open. They are separate so a muted
  // microphone can still show that it is the one holding the picker open.
  property bool activeState: false
  property bool highlighted: false
  property color glyphColor: activeState ? bar.foreground : bar.dim

  signal activated()
  signal secondaryActivated()

  implicitWidth: Math.max(26, row.implicitWidth + 14)
  implicitHeight: 26
  width: implicitWidth
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: root.highlighted
      ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.16)
      : (mouse.containsMouse
         ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)
         : (root.activeState
            ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.07)
            : "transparent"))

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.glyphColor
      font.family: bar.fontFamily
      font.pixelSize: 12
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.glyphColor
      font.family: bar.fontFamily
      font.pixelSize: 10
      font.weight: Font.Medium
      visible: text !== ""
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function (event) {
      if (event.button === Qt.RightButton) root.secondaryActivated()
      else root.activated()
    }
  }

  ToolTipBubble {
    bar: root.bar
    text: root.tip
    shown: mouse.containsMouse && root.tip !== ""
    target: root
  }
}
