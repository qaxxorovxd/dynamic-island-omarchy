// The monitor tile: CPU, memory, disk, and whatever else this machine has to
// report. Meters only warn on disk and battery, where a high number is a
// problem rather than just activity.

import QtQuick

Card {
  id: root

  required property var hub
  title: "System"
  trailing: hub.temp !== null && hub.temp !== undefined ? Math.round(hub.temp) + "°" : ""
  trailingColor: (hub.temp || 0) >= 85 ? bar.urgent : bar.dim

  Column {
    anchors.fill: contentArea
    spacing: 6

    Meter {
      bar: root.bar
      width: parent.width
      label: "CPU"
      percent: hub.cpu.percent || 0
      value: Math.round(hub.cpu.percent || 0) + "%"
    }

    Meter {
      bar: root.bar
      width: parent.width
      label: "Memory"
      percent: hub.memory.percent || 0
      value: hub.formatBytes(hub.memory.used) + " / " + hub.formatBytes(hub.memory.total)
    }

    Meter {
      bar: root.bar
      width: parent.width
      label: "Disk"
      warnHigh: true
      percent: hub.disk.percent || 0
      value: hub.formatBytes(hub.disk.used) + " / " + hub.formatBytes(hub.disk.total)
    }

    Row {
      width: parent.width
      spacing: 10

      Text {
        text: "load " + ((hub.cpu.load || []).join(" ") || "—")
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 9
      }

      Text {
        text: hub.swap.total > 0 ? "swap " + Math.round(hub.swap.percent) + "%" : ""
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 9
        visible: text !== ""
      }

      // Both absent on a desktop; the row simply gets shorter.
      Text {
        text: hub.battery ? "bat " + hub.battery.percent + "%" : ""
        color: hub.battery && hub.battery.percent <= 15 ? bar.urgent : bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 9
        visible: text !== ""
      }

      Text {
        text: (hub.brightness !== null && hub.brightness !== undefined) ? "  " + hub.brightness + "%" : ""
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 9
        visible: text !== ""
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.run("omarchy-launch-or-focus-tui btop")
  }
}
