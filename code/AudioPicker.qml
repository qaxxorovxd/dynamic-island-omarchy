// Output and input device selection, as a sheet over the card grid.
//
// It covers the cards rather than opening a second window: the island already
// holds a focus grab, and a popup surface would either fight it or need its
// own. The media pill carries the same two lists in its lower half; this
// sheet stays because the island's footer is where a hand already is when the
// output turns out to be wrong.

import QtQuick

Item {
  id: root

  required property var bar
  required property var hub

  signal closeRequested()

  // Fully opaque, and a touch lighter than the island. A sheet that lets the
  // cards behind it show through reads as a rendering fault, not as depth —
  // and the island is already translucent against the desktop, so any alpha
  // here compounds with that one.
  Rectangle {
    anchors.fill: parent
    radius: 14
    color: Qt.rgba(
      Math.min(1, bar.islandBackground.r + 0.05),
      Math.min(1, bar.islandBackground.g + 0.05),
      Math.min(1, bar.islandBackground.b + 0.05), 1.0)
    border.width: 1
    border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)

    // Swallows clicks that miss a row so they cannot reach the cards below.
    MouseArea { anchors.fill: parent }
  }

  Item {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
    height: 14

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "Audio devices"
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
      font.letterSpacing: 1.1
      font.capitalization: Font.AllUppercase
    }

    IconButton {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: "\uF00D"  // close
      tip: "Back"
      onActivated: root.closeRequested()
    }
  }

  Row {
    anchors {
      top: header.bottom
      topMargin: 10
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      leftMargin: 14
      rightMargin: 14
      bottomMargin: 14
    }
    spacing: 14

    DeviceColumn {
      bar: root.bar
      hub: root.hub
      width: (parent.width - 14) / 2
      height: parent.height
      title: "Output"
      glyph: "\uF028"  // speaker
      devices: hub.sinks
      defaultNode: hub.defaultSink
      onSelected: function (node) { hub.makeDefault(node) }
    }

    DeviceColumn {
      bar: root.bar
      hub: root.hub
      width: (parent.width - 14) / 2
      height: parent.height
      title: "Input"
      glyph: "\uF130"  // microphone
      devices: hub.sources
      defaultNode: hub.defaultSource
      onSelected: function (node) { hub.makeDefault(node) }
    }
  }
}
