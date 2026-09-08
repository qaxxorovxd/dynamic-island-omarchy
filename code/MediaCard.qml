// Now playing: cover art, track, and transport. Straight off MPRIS.

import QtQuick

Card {
  id: root

  required property var hub
  title: "Media"
  trailing: hub.hasMedia && hub.player ? String(hub.player.identity || "") : ""

  Item {
    anchors.fill: contentArea
    visible: hub.hasMedia

    Rectangle {
      id: art
      width: 54; height: 54
      radius: 8
      anchors.left: parent.left
      anchors.top: parent.top
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)
      clip: true

      Image {
        anchors.fill: parent
        source: hub.trackArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
      }

      // Falls back to a glyph whenever the player exposes no art, which is
      // most browser-hosted players.
      Text {
        anchors.centerIn: parent
        text: "\uF001"  // music note
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 18
        visible: hub.trackArt === ""
      }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: 4
      spacing: 3

      Text {
        width: parent.width
        text: hub.trackTitle
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: hub.trackArtist
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
      }
    }

    Row {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      spacing: 2

      IconButton {
        bar: root.bar
        glyph: "\uF048"  // prev
        tip: "Previous"
        onActivated: hub.mediaAction("previous")
      }
      IconButton {
        bar: root.bar
        glyph: hub.playing ? "\uF04C" : "\uF04B"  // pause / play
        glyphColor: bar.foreground
        tip: hub.playing ? "Pause" : "Play"
        onActivated: hub.mediaAction("toggle")
      }
      IconButton {
        bar: root.bar
        glyph: "\uF051"  // next
        tip: "Next"
        onActivated: hub.mediaAction("next")
      }
    }
  }

  Column {
    anchors.centerIn: contentArea
    spacing: 6
    visible: !hub.hasMedia

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "\uF001"  // music note
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.20)
      font.family: bar.fontFamily
      font.pixelSize: 22
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Nothing playing"
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 10
    }
  }
}
