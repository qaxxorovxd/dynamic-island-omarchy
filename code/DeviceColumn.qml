// A list of audio devices, the active one marked.
//
// Each row is three things at once — click the row to make it the default,
// click the glyph to mute it, scroll anywhere on it to change its volume.
// All three act on that row's device, not on whatever happens to be default.
//
// The model is PipeWire nodes, not a snapshot: a device appearing, vanishing,
// or changing volume behind the panel's back updates the row in place. With
// `title` left empty the heading disappears and the list fills the whole
// item, which is how the media panel uses it under its own tabs.

import QtQuick

Item {
  id: root

  required property var bar
  required property var hub
  property string title: ""
  property string glyph: ""
  // PwNode objects, from hub.sinks or hub.sources.
  property var devices: []
  property var defaultNode: null

  signal selected(var node)

  readonly property bool showHeading: title !== ""

  Row {
    id: heading
    anchors { top: parent.top; left: parent.left; right: parent.right }
    height: root.showHeading ? 13 : 0
    visible: root.showHeading
    spacing: 6

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 10
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
      font.weight: Font.DemiBold
      font.letterSpacing: 1.1
      font.capitalization: Font.AllUppercase
    }
  }

  Flickable {
    anchors {
      top: heading.bottom
      topMargin: root.showHeading ? 8 : 0
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: 4

      Repeater {
        model: root.devices

        Rectangle {
          id: row

          readonly property bool isDefault: root.defaultNode === modelData
          readonly property bool isMuted: hub.nodeMuted(modelData)

          width: parent.width
          height: 40
          radius: 10
          color: isDefault
            ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.14)
            : (rowMouse.containsMouse
               ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.07)
               : "transparent")

          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!row.isDefault) root.selected(modelData)
          }

          WheelHandler {
            onWheel: function (event) {
              hub.nudgeNodeVolume(modelData, event.angleDelta.y > 0 ? 0.05 : -0.05)
            }
          }

          // The active device gets a filled dot; the rest get a hollow ring.
          // Cheaper to read at a glance than a checkmark glyph.
          Rectangle {
            id: marker
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: row.isDefault ? bar.foreground : "transparent"
            border.width: row.isDefault ? 0 : 1
            border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.35)
          }

          Column {
            anchors.left: marker.right
            anchors.leftMargin: 9
            anchors.right: muteButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              width: parent.width
              text: hub.nodeLabel(modelData)
              color: row.isDefault ? bar.foreground : bar.dim
              font.family: bar.fontFamily
              font.pixelSize: 10
              font.weight: row.isDefault ? Font.Medium : Font.Normal
              elide: Text.ElideRight
            }

            Row {
              spacing: 6

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 3; radius: 1.5
                color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.14)

                Rectangle {
                  height: parent.height
                  radius: parent.radius
                  width: parent.width * Math.max(0, Math.min(1, hub.nodeVolume(modelData)))
                  color: row.isMuted ? bar.urgent : bar.foreground
                  opacity: row.isMuted ? 0.8 : 0.6
                  Behavior on width { NumberAnimation { duration: 200 } }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.isMuted ? "muted" : hub.nodePercent(modelData) + "%"
                color: row.isMuted ? bar.urgent : bar.dim
                font.family: bar.fontFamily
                font.pixelSize: 9
              }
            }
          }

          IconButton {
            id: muteButton
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            glyph: row.isMuted ? "\uF026" : "\uF028"  // muted / audible
            glyphColor: row.isMuted ? bar.urgent : bar.dim
            tip: row.isMuted ? "Unmute" : "Mute"
            onActivated: hub.toggleNodeMute(modelData)
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    text: "No devices"
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
    visible: root.devices.length === 0
  }
}
