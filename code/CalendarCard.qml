// A compact month grid with today marked. Monday-first, matching the ISO week
// numbers the header shows.

import QtQuick

Card {
  id: root

  required property var hub
  title: Qt.formatDateTime(hub.now, "MMMM yyyy")
  trailing: hub.weekText

  readonly property int year: hub.now.getFullYear()
  readonly property int month: hub.now.getMonth()
  readonly property int today: hub.now.getDate()
  readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
  // getDay() is Sunday-based; shift so Monday is column 0.
  readonly property int leading: (new Date(year, month, 1).getDay() + 6) % 7

  Column {
    anchors.fill: contentArea
    spacing: 3

    Row {
      width: parent.width
      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]
        Text {
          width: contentArea.width / 7
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.30)
          font.family: bar.fontFamily
          font.pixelSize: 8
          font.weight: Font.DemiBold
        }
      }
    }

    Grid {
      columns: 7
      spacing: 0

      Repeater {
        model: root.leading + root.daysInMonth

        Item {
          readonly property int day: index - root.leading + 1
          readonly property bool isToday: day === root.today

          width: contentArea.width / 7
          height: 15

          Rectangle {
            anchors.centerIn: parent
            width: 15; height: 15; radius: 5
            color: bar.foreground
            visible: parent.isToday
          }

          Text {
            anchors.centerIn: parent
            text: parent.day > 0 ? String(parent.day) : ""
            color: parent.isToday ? bar.islandBackground : bar.foreground
            opacity: parent.isToday ? 1 : 0.62
            font.family: bar.fontFamily
            font.pixelSize: 9
            font.weight: parent.isToday ? Font.Bold : Font.Normal
          }
        }
      }
    }
  }
}
