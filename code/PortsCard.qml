// Listening TCP ports. Ports bound past loopback are marked: on a dev box
// that is the one fact worth surfacing, and it is easy to leave one open by
// accident.

import QtQuick

Card {
  id: root

  required property var hub
  title: "Ports"
  trailing: hub.loaded
    ? (hub.exposedCount > 0 ? hub.exposedCount + " exposed" : String(hub.ports.length))
    : ""
  trailingColor: hub.exposedCount > 0 ? bar.urgent : bar.dim

  // Exposed first — the reason to open this card at all.
  readonly property var ranked: {
    var list = hub.ports.slice()
    list.sort(function (a, b) {
      if (a.exposed !== b.exposed) return a.exposed ? -1 : 1
      return a.port - b.port
    })
    return list
  }

  Flickable {
    anchors.fill: contentArea
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: 4

      Repeater {
        model: root.ranked

        Row {
          width: parent.width
          spacing: 7

          Text {
            id: portNumber
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: String(modelData.port)
            color: modelData.exposed ? bar.urgent : bar.foreground
            font.family: bar.fontFamily
            font.pixelSize: 10
            font.weight: Font.Medium
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - 7
            text: modelData.proc !== "" ? modelData.proc : modelData.addr
            color: bar.dim
            font.family: bar.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: contentArea
    text: hub.loaded ? "Nothing listening" : "reading…"
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
    visible: root.ranked.length === 0
  }
}
