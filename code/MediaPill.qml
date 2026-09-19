// The media pill: the island's smaller sibling, parked at the right edge.
//
// Closed it says two things and no more — what is playing, and how loud the
// machine is. Clicked it grows downward into a panel holding every control
// that has anything to do with sound: transport, seek, volumes, and the
// output and input device lists.
//
// It is built like Island.qml on purpose. One rounded rectangle owns the
// animation, width, height and corner radius interpolate on the same curve,
// and the closed row is the thing that sizes the collapsed shape.

import QtQuick
import Quickshell

Item {
  id: root

  required property var bar
  required property var hub
  required property bool open

  signal toggleRequested()
  signal closeRequested()

  readonly property int pad: 16

  implicitWidth: width
  implicitHeight: height

  width: open ? bar.mediaExpandedWidth
              : Math.min(bar.mediaExpandedWidth, Math.max(84, collapsedRow.implicitWidth + 24))
  height: open ? bar.mediaExpandedHeight : bar.collapsedHeight

  Behavior on width {
    NumberAnimation { duration: 280; easing.type: root.open ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 0.7 }
  }
  Behavior on height {
    NumberAnimation { duration: 280; easing.type: root.open ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 0.7 }
  }

  Rectangle {
    anchors.fill: parent
    color: bar.islandBackground
    radius: root.open ? 26 : height / 2
    antialiasing: true

    Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    border.width: 1
    border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.10)
  }

  // --------------------------------------------------------- closed content
  //
  // Both the label and the measuring stick: the collapsed width above reads
  // this row's implicit width, which is why it keeps its layout while the
  // panel is open even though nothing is drawn.
  Row {
    id: collapsedRow

    anchors.centerIn: parent
    spacing: 7
    opacity: root.open ? 0 : 1
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: root.open ? 100 : 200 } }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "\uF001"  // music note
      color: hub.playing ? bar.foreground : bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 11
      visible: hub.hasMedia
    }

    Text {
      id: pillTitle
      anchors.verticalCenter: parent.verticalCenter
      // Long titles are trimmed rather than allowed to push the pill across
      // the screen; the panel below has room for the whole thing.
      width: Math.min(implicitWidth, 190)
      text: hub.trackTitle !== "" ? hub.trackTitle : hub.playerName
      color: bar.foreground
      font.family: bar.fontFamily
      font.pixelSize: 12
      font.weight: Font.Medium
      elide: Text.ElideRight
      visible: hub.hasMedia && text !== ""
    }

    // Separates the two halves of the pill without drawing a line through it.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 3; height: 3; radius: 1.5
      color: bar.faint
      visible: pillTitle.visible
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: hub.sinkGlyph(hub.sinkPercent, hub.sinkMuted)
      color: hub.sinkMuted ? bar.urgent : bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 11
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: hub.sinkMuted ? "muted" : hub.sinkPercent + "%"
      color: hub.sinkMuted ? bar.urgent : bar.foreground
      font.family: bar.fontFamily
      font.pixelSize: 12
      font.weight: Font.Medium
    }
  }

  // ----------------------------------------------------------- open content
  Loader {
    anchors.fill: parent
    active: root.open || body.opacity > 0.01
    sourceComponent: bodyComponent
  }

  QtObject {
    id: body
    property real opacity: root.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.open ? 220 : 120; easing.type: Easing.OutCubic } }
  }

  Component {
    id: bodyComponent

    Item {
      anchors.fill: parent
      opacity: body.opacity
      // Content that is fading out must not keep swallowing clicks.
      enabled: root.open

      MediaBody {
        anchors.fill: parent
        bar: root.bar
        hub: root.hub
        pill: root
        onCloseRequested: root.closeRequested()
      }
    }
  }

  // ------------------------------------------------------------ interaction
  MouseArea {
    anchors.fill: parent
    enabled: !root.open
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: function (event) {
      // The pill is a volume control before it is a button: muting is the one
      // thing worth having without opening anything.
      if (event.button === Qt.MiddleButton) hub.toggleNodeMute(hub.defaultSink)
      else root.toggleRequested()
    }
  }

  // Scrolling the closed pill is the interaction people reach for without
  // looking, and it matches the footer's audio button.
  WheelHandler {
    enabled: !root.open
    onWheel: function (event) {
      hub.nudgeNodeVolume(hub.defaultSink, event.angleDelta.y > 0 ? 0.05 : -0.05)
    }
  }

  HoverHandler {
    id: hover
    enabled: !root.open
  }
  scale: (!root.open && hover.hovered) ? 1.04 : 1.0
  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
}
