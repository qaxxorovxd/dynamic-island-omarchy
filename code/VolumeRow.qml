// One device's volume: a mute button, a draggable track, and the number.
//
// The track writes straight to the PipeWire node on every pointer move. That
// is only reasonable because nothing shells out — setting a property is
// cheap enough to do per frame, which is what makes the drag feel attached to
// the pointer rather than to a poll.
//
// While the pointer owns the track, the drawn value comes from the drag and
// not from the node. They agree within a frame anyway, but reading back a
// value that is still settling makes the knob stutter under the finger.

import QtQuick

Item {
  id: root

  required property var bar
  required property var hub
  // A PwNode, or null when nothing is default yet.
  property var node: null
  property string glyph: ""
  property string mutedGlyph: ""
  property string tip: ""

  implicitHeight: 32
  height: implicitHeight

  readonly property real value: hub.nodeVolume(node)
  readonly property bool muted: hub.nodeMuted(node)
  property real dragValue: -1
  readonly property real shown: dragValue >= 0 ? dragValue : value
  readonly property int shownPercent: Math.round(shown * 100)

  function applyAt(x) {
    var span = Math.max(1, track.width)
    var fraction = Math.max(0, Math.min(1, x / span))
    root.dragValue = fraction
    hub.setNodeVolume(root.node, fraction)
  }

  IconButton {
    id: muteButton
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    glyph: root.muted ? root.mutedGlyph : root.glyph
    glyphColor: root.muted ? bar.urgent : bar.dim
    tip: root.tip
    onActivated: hub.toggleNodeMute(root.node)
  }

  Text {
    id: readout
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 42
    horizontalAlignment: Text.AlignRight
    text: root.muted ? "muted" : root.shownPercent + "%"
    color: root.muted ? bar.urgent : bar.foreground
    font.family: bar.fontFamily
    font.pixelSize: 10
    font.weight: Font.Medium
  }

  Item {
    id: track

    anchors.left: muteButton.right
    anchors.leftMargin: 10
    anchors.right: readout.left
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    height: parent.height

    Rectangle {
      id: groove
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: 5
      radius: 2.5
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)

      Rectangle {
        id: fill
        height: parent.height
        radius: parent.radius
        width: Math.max(root.shown > 0 ? height : 0, parent.width * root.shown)
        color: root.muted ? bar.urgent : bar.foreground
        opacity: root.muted ? 0.55 : 0.8
        // No animation while dragging: the knob has to sit under the pointer,
        // not chase it.
        Behavior on width {
          enabled: root.dragValue < 0
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }

    Rectangle {
      id: knob
      width: 11
      height: 11
      radius: 5.5
      antialiasing: true
      x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
      anchors.verticalCenter: parent.verticalCenter
      color: root.muted ? bar.urgent : bar.foreground
      opacity: (trackMouse.containsMouse || trackMouse.pressed) ? 1 : 0.85
      scale: (trackMouse.containsMouse || trackMouse.pressed) ? 1.15 : 1.0

      Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on x {
        enabled: root.dragValue < 0
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: trackMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      // The pointer keeps the track even when the drag wanders off it, which
      // is what makes dragging to 0% or 100% possible without aiming.
      preventStealing: true
      onPressed: function (event) { root.applyAt(event.x) }
      onPositionChanged: function (event) { if (pressed) root.applyAt(event.x) }
      onReleased: root.dragValue = -1
      onCanceled: root.dragValue = -1
    }

    WheelHandler {
      onWheel: function (event) {
        hub.nudgeNodeVolume(root.node, event.angleDelta.y > 0 ? 0.05 : -0.05)
      }
    }
  }
}
