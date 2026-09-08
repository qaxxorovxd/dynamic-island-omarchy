// Watched systemd units. Failed ones sort to the top and are the only rows
// that take a colour, so the card is scannable without reading it.

import QtQuick

Card {
  id: root

  required property var hub
  title: "Services"
  trailing: hub.loaded ? hub.upCount + "/" + hub.services.length : ""
  trailingColor: hub.failedCount > 0 ? bar.urgent : bar.dim

  readonly property var ranked: {
    var rank = { failed: 0, starting: 1, up: 2, down: 3 }
    var list = hub.services.slice()
    list.sort(function (a, b) { return (rank[a.state] || 9) - (rank[b.state] || 9) })
    return list
  }

  function stateColor(state) {
    if (state === "failed") return bar.urgent
    if (state === "up") return bar.foreground
    if (state === "starting") return bar.foreground
    return Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.30)
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

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 5; height: 5; radius: 2.5
            color: root.stateColor(modelData.state)
            opacity: modelData.state === "down" ? 0.5 : 1
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 12 - detail.implicitWidth - 14
            text: modelData.label
            color: modelData.state === "down" ? bar.dim : bar.foreground
            font.family: bar.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
          }

          Text {
            id: detail
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.detail
            color: modelData.state === "failed" ? bar.urgent : bar.dim
            font.family: bar.fontFamily
            font.pixelSize: 9
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: contentArea
    text: "reading…"
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
    visible: !hub.loaded
  }
}
