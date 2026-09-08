// Shared chrome for every tile in the open panel: a faint fill, a small caps
// title, and a content area. Cards never draw their own border — inside an
// already-bordered island a second outline just adds noise.
//
// Content is placed by anchoring to `contentArea` rather than through a
// `default property alias`. An alias would also capture the chrome declared
// here, since QML routes *every* child in this file into the default property,
// and the background would end up parented inside its own content area.

import QtQuick

Item {
  id: root

  required property var bar
  property string title: ""
  property string trailing: ""
  property color trailingColor: bar.dim

  // Cards anchor their content to this. It draws nothing; it is geometry.
  readonly property alias contentArea: body

  Rectangle {
    anchors.fill: parent
    radius: 14
    color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.045)
  }

  Item {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
    height: root.title === "" ? 0 : 13
    visible: root.title !== ""

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - (trailingLabel.visible ? trailingLabel.implicitWidth + 8 : 0)
      text: root.title
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
      font.letterSpacing: 1.1
      font.capitalization: Font.AllUppercase
      elide: Text.ElideRight
    }

    Text {
      id: trailingLabel
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.trailing
      color: root.trailingColor
      font.family: bar.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
      visible: text !== ""
    }
  }

  Item {
    id: body
    anchors {
      top: root.title === "" ? parent.top : header.bottom
      topMargin: root.title === "" ? 12 : 9
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      leftMargin: 12
      rightMargin: 12
      bottomMargin: 12
    }
  }
}
