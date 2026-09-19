// The media panel's contents: what is playing on top, what it comes out of
// underneath.
//
// The split is deliberate. The upper half changes with the track and is where
// the eye goes first; the lower half is the machine's audio state, which is
// the same whether or not anything is playing — so it stays put, and the
// upper half is what collapses to a placeholder when no player is running.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
  id: root

  required property var bar
  required property var hub
  required property var pill

  signal closeRequested()

  readonly property int pad: pill.pad
  readonly property var player: hub.player

  // Which device list the lower half is showing. Output first: it is the one
  // people open this panel to change.
  property string deviceTab: "output"

  readonly property bool hasLength: !!player && player.lengthSupported && Number(player.length) > 0
  readonly property real progress: hasLength
    ? Math.max(0, Math.min(1, Number(player.position) / Number(player.length))) : 0

  // MPRIS players announce a position once and then leave it to the client to
  // work out how far it has moved. Re-reading it every second while playing is
  // what makes the elapsed time and the bar advance.
  Timer {
    interval: 1000
    repeat: true
    running: hub.hasMedia && hub.playing && root.player.positionSupported
    onTriggered: root.player.positionChanged()
  }

  // ------------------------------------------------------------------ header
  Item {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
    height: 24

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "Now playing"
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
      font.letterSpacing: 1.1
      font.capitalization: Font.AllUppercase
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 130)
        text: hub.playerName
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 9
        elide: Text.ElideRight
        visible: text !== ""
      }

      // Only worth a button when there is somewhere else to go.
      IconButton {
        bar: root.bar
        glyph: "\uF0EC"  // exchange
        tip: "Switch player"
        visible: hub.candidates.length > 1
        onActivated: hub.cyclePlayer()
      }

      IconButton {
        bar: root.bar
        glyph: "\uF00D"  // close
        tip: "Close"
        onActivated: root.closeRequested()
      }
    }
  }

  // -------------------------------------------------------------------- hero
  Item {
    id: hero
    anchors {
      top: header.bottom
      topMargin: 12
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }
    height: 78
    visible: hub.hasMedia

    Rectangle {
      id: art
      width: 78; height: 78
      radius: 12
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)
      clip: true

      Image {
        anchors.fill: parent
        source: hub.trackArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Cover art arrives at whatever size the player felt like; asking for
        // the drawn size keeps a 1500px JPEG from being held at full scale.
        sourceSize.width: 156
        sourceSize.height: 156
        visible: status === Image.Ready
      }

      // Falls back to a glyph whenever the player exposes no art, which is
      // most browser-hosted players.
      Text {
        anchors.centerIn: parent
        text: "\uF001"  // music note
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 24
        visible: hub.trackArt === ""
      }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Text {
        width: parent.width
        text: hub.trackTitle !== "" ? hub.trackTitle : "Unknown track"
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: hub.trackArtist
        color: bar.foreground
        opacity: 0.75
        font.family: bar.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        visible: text !== ""
      }
      Text {
        width: parent.width
        text: hub.trackAlbum
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
        visible: text !== ""
      }
    }
  }

  // -------------------------------------------------------------------- seek
  Item {
    id: seek
    anchors {
      top: hero.bottom
      topMargin: 10
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }
    height: 22
    visible: hub.hasMedia && root.hasLength

    Text {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 34
      text: root.player ? hub.formatClock(root.player.position) : ""
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
    }

    Text {
      id: total
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 34
      horizontalAlignment: Text.AlignRight
      text: root.player ? hub.formatClock(root.player.length) : ""
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
    }

    Item {
      id: seekTrack
      anchors.left: elapsed.right
      anchors.leftMargin: 10
      anchors.right: total.left
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)

        Rectangle {
          id: seekFill
          height: parent.height
          radius: parent.radius
          width: parent.width * root.progress
          color: bar.foreground
          opacity: 0.8
          // A second of playback at a time, so the bar creeps rather than
          // stepping; a seek lands hard, which is what a seek should do.
          Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
        }
      }

      Rectangle {
        width: 9; height: 9; radius: 4.5
        antialiasing: true
        x: Math.max(0, Math.min(seekTrack.width - width, seekFill.width - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: bar.foreground
        visible: !!root.player && root.player.canSeek
        opacity: seekMouse.containsMouse ? 1 : 0.85
        scale: seekMouse.containsMouse ? 1.2 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        id: seekMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !!root.player && root.player.canSeek
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: function (event) { hub.seekTo(event.x / Math.max(1, width)) }
        onPositionChanged: function (event) { if (pressed) hub.seekTo(event.x / Math.max(1, width)) }
      }
    }
  }

  // --------------------------------------------------------------- transport
  Row {
    id: transport
    anchors.top: seek.bottom
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    height: 38
    spacing: 10
    visible: hub.hasMedia

    MediaButton {
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: "\uF074"  // shuffle
      size: 28
      enabled: !!root.player && root.player.shuffleSupported
      activeState: !!root.player && root.player.shuffle
      tip: (!!root.player && root.player.shuffle) ? "Shuffle on" : "Shuffle off"
      onActivated: hub.toggleShuffle()
    }

    MediaButton {
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: "\uF048"  // previous
      size: 30
      glyphSize: 13
      enabled: !!root.player && root.player.canGoPrevious
      tip: "Previous"
      onActivated: hub.mediaAction("previous")
    }

    MediaButton {
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: hub.playing ? "\uF04C" : "\uF04B"  // pause / play
      size: 38
      glyphSize: 15
      filled: true
      enabled: !!root.player && root.player.canTogglePlaying
      tip: hub.playing ? "Pause" : "Play"
      onActivated: hub.mediaAction("toggle")
    }

    MediaButton {
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: "\uF051"  // next
      size: 30
      glyphSize: 13
      enabled: !!root.player && root.player.canGoNext
      tip: "Next"
      onActivated: hub.mediaAction("next")
    }

    MediaButton {
      id: loopButton
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      glyph: "\uF01E"  // repeat
      size: 28
      enabled: !!root.player && root.player.loopSupported
      activeState: !!root.player && root.player.loopState !== MprisLoopState.None
      tip: {
        if (!root.player) return "Repeat"
        if (root.player.loopState === MprisLoopState.Track) return "Repeat track"
        if (root.player.loopState === MprisLoopState.Playlist) return "Repeat all"
        return "Repeat off"
      }
      onActivated: hub.cycleLoop()

      // Repeating one track and repeating the whole playlist are the same
      // glyph everywhere; the badge is what tells them apart.
      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 1
        anchors.topMargin: 1
        text: "1"
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: 7
        font.weight: Font.Bold
        visible: !!root.player && root.player.loopState === MprisLoopState.Track
      }
    }
  }

  // Stands in for the whole upper half when there is no player at all, so the
  // panel keeps its shape instead of collapsing around the volume rows.
  Item {
    id: upperRegion
    anchors {
      top: header.bottom
      bottom: upperRule.top
      left: parent.left
      right: parent.right
    }
  }

  Column {
    anchors.centerIn: upperRegion
    spacing: 8
    visible: !hub.hasMedia

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "\uF001"  // music note
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.20)
      font.family: bar.fontFamily
      font.pixelSize: 30
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Nothing playing"
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 10
    }
  }

  // ----------------------------------------------------------------- volumes
  Rectangle {
    id: upperRule
    anchors {
      top: transport.bottom
      topMargin: 12
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }
    height: 1
    color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.08)
  }

  Column {
    id: volumes
    anchors {
      top: upperRule.bottom
      topMargin: 10
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }
    spacing: 4

    VolumeRow {
      width: parent.width
      bar: root.bar
      hub: root.hub
      node: hub.defaultSink
      glyph: "\uF028"        // speaker
      mutedGlyph: "\uF026"   // speaker muted
      tip: hub.sinkLabel !== "" ? hub.sinkLabel : "Output"
    }

    VolumeRow {
      width: parent.width
      bar: root.bar
      hub: root.hub
      node: hub.defaultSource
      glyph: "\uF130"        // microphone
      mutedGlyph: "\uF131"   // microphone muted
      tip: hub.sourceLabel !== "" ? hub.sourceLabel : "Input"
    }
  }

  Rectangle {
    id: lowerRule
    anchors {
      top: volumes.bottom
      topMargin: 10
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }
    height: 1
    color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.08)
  }

  // ----------------------------------------------------------------- devices
  Row {
    id: tabs
    anchors.top: lowerRule.bottom
    anchors.topMargin: 10
    anchors.left: parent.left
    anchors.leftMargin: root.pad
    height: 22
    spacing: 6

    Repeater {
      model: ["output", "input"]

      Rectangle {
        id: tab

        readonly property bool current: root.deviceTab === modelData

        width: tabLabel.implicitWidth + 24
        height: 22
        radius: 8
        color: current
          ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.14)
          : (tabMouse.containsMouse
             ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.07)
             : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
          id: tabLabel
          anchors.centerIn: parent
          spacing: 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData === "output" ? "\uF028" : "\uF130"  // speaker / mic
            color: tab.current ? bar.foreground : bar.dim
            font.family: bar.fontFamily
            font.pixelSize: 10
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData === "output" ? "Output" : "Input"
            color: tab.current ? bar.foreground : bar.dim
            font.family: bar.fontFamily
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
            font.capitalization: Font.AllUppercase
          }
        }

        MouseArea {
          id: tabMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.deviceTab = modelData
        }
      }
    }
  }

  DeviceColumn {
    anchors {
      top: tabs.bottom
      topMargin: 8
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      leftMargin: root.pad
      rightMargin: root.pad
      bottomMargin: root.pad
    }

    bar: root.bar
    hub: root.hub
    devices: root.deviceTab === "output" ? hub.sinks : hub.sources
    defaultNode: root.deviceTab === "output" ? hub.defaultSink : hub.defaultSource
    onSelected: function (node) { hub.makeDefault(node) }
  }
}
