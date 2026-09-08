// Coding-agent usage, read from the snapshots Omarchy's agent plugin already
// keeps in ~/.local/state/omarchy/agents/usage. Nothing here fetches.

import QtQuick

Card {
  id: root

  required property var hub
  title: "Agents"
  trailing: {
    var ready = hub.agents.filter(function (a) { return a.ready })
    return ready.length > 0 ? ready.length + "/" + hub.agents.length : ""
  }

  // Agents with real limit data first: an agent reporting nothing should not
  // push the one with a live quota out of the card.
  readonly property var ranked: {
    var list = hub.agents.slice()
    list.sort(function (a, b) {
      var aHas = (a.limits || []).length > 0 ? 0 : 1
      var bHas = (b.limits || []).length > 0 ? 0 : 1
      return aHas - bHas
    })
    return list
  }

  Column {
    anchors.fill: contentArea
    spacing: 7
    visible: root.ranked.length > 0

    Repeater {
      model: root.ranked.slice(0, 3)

      Item {
        id: agentRow

        width: parent.width
        height: worst ? 26 : 13

        readonly property var limits: modelData.limits || []
        // The tightest quota is the one that will actually stop you.
        readonly property var worst: {
          if (limits.length === 0) return null
          var top = limits[0]
          for (var i = 1; i < limits.length; i++)
            if (limits[i].percent > top.percent) top = limits[i]
          return top
        }
        readonly property real fraction: worst ? Math.max(0, Math.min(1, worst.percent)) : 0
        readonly property bool tight: worst !== null && worst.percent >= 0.9

        Text {
          anchors.left: parent.left
          anchors.top: parent.top
          width: parent.width - quota.implicitWidth - 8
          text: modelData.name
          color: modelData.ready ? bar.foreground : bar.dim
          font.family: bar.fontFamily
          font.pixelSize: 10
          font.weight: Font.Medium
          elide: Text.ElideRight
        }

        Text {
          id: quota
          anchors.right: parent.right
          anchors.top: parent.top
          text: agentRow.worst
            ? Math.round(agentRow.worst.percent * 100) + "%"
            : (modelData.todayPrompts > 0 ? modelData.todayPrompts + " today" : "—")
          color: agentRow.tight ? bar.urgent : bar.dim
          font.family: bar.fontFamily
          font.pixelSize: 10
        }

        Rectangle {
          id: track
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 4
          radius: 2
          color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)
          visible: agentRow.worst !== null

          Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(3, track.width * agentRow.fraction)
            color: agentRow.tight ? bar.urgent : bar.foreground
            opacity: 0.75

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: contentArea
    text: hub.loaded ? "No agents reporting" : "reading…"
    color: bar.dim
    font.family: bar.fontFamily
    font.pixelSize: 10
    visible: root.ranked.length === 0
  }
}
