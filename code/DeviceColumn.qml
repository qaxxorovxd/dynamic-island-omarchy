// One side of the audio picker: a list of devices, the active one marked.
//
// Each row is three things at once — click the row to make it the default,
// click the glyph to mute it, scroll anywhere on it to change its volume.
// All three act on that row's device, not on whatever happens to be default.

import QtQuick

Item {
  id: root

  required property var bar
  required property var hub
  property string title: ""
  property string glyph: ""
  property var devices: []

  signal selected(int id)

  Row {
    id: heading
    anchors { top: parent.top; left: parent.left; right: parent.right }
    height: 13
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
    anchors { top: heading.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
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

          width: parent.width
          height: 40
          radius: 10
          color: modelData.default
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
            onClicked: if (!modelData.default) root.selected(modelData.id)
          }

          WheelHandler {
            onWheel: function (event) {
              hub.setVolume(modelData.id, event.angleDelta.y > 0 ? 5 : -5)
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
            color: modelData.default ? bar.foreground : "transparent"
            border.width: modelData.default ? 0 : 1
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
              text: modelData.name
              color: modelData.default ? bar.foreground : bar.dim
              font.family: bar.fontFamily
              font.pixelSize: 10
              font.weight: modelData.default ? Font.Medium : Font.Normal
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
                  width: parent.width * Math.max(0, Math.min(1, modelData.percent / 100))
                  color: modelData.muted ? bar.urgent : bar.foreground
                  opacity: modelData.muted ? 0.8 : 0.6
                  Behavior on width { NumberAnimation { duration: 200 } }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.muted ? "muted" : modelData.percent + "%"
                color: modelData.muted ? bar.urgent : bar.dim
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
            glyph: modelData.muted ? "\uF026" : "\uF028"  // muted / audible
            glyphColor: modelData.muted ? bar.urgent : bar.dim
            tip: modelData.muted ? "Unmute" : "Mute"
            onActivated: hub.toggleMute(modelData.id)
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    text: hub.loaded ? "No devices" : "reading…"
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
    visible: root.devices.length === 0
  }
}
