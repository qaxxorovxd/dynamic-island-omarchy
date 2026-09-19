// Current conditions and the next three days, in the slot the media card used
// to hold. Media moved out to its own pill at the right edge; the weather is
// what a panel you open to check the time should have been showing all along.
//
// Everything here comes from `weather.sh`, which caches on disk — so the card
// is populated the moment the panel opens, with or without a network.

import QtQuick

Card {
  id: root

  required property var hub
  title: "Weather"
  trailing: hub.hasWeather ? String(hub.weather.location || "") : ""

  Item {
    anchors.fill: contentArea
    visible: hub.hasWeather

    Row {
      id: current
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: 10

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: hub.weatherIcon
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: 26
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          text: hub.weatherTemp
          color: bar.foreground
          font.family: bar.fontFamily
          font.pixelSize: 21
          font.weight: Font.DemiBold
        }
        Text {
          text: "feels " + hub.weatherFeels
          color: bar.dim
          font.family: bar.fontFamily
          font.pixelSize: 9
        }
      }
    }

    // One line for the sky and the two numbers that decide what to wear.
    Text {
      id: summary
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: current.bottom
      anchors.topMargin: 7
      text: String(hub.weather.desc || "") + "  ·  " + hub.weather.humidity + "%  ·  " + hub.weatherWind
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 9
      elide: Text.ElideRight
    }

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 40

      Repeater {
        model: hub.weatherDays

        Column {
          width: (summary.width - 2) / 3
          spacing: 2

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: hub.dayLabel(modelData.date)
            color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.35)
            font.family: bar.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            // Forecast glyphs are always the daytime ones: a day is not a
            // moment, and a moon over Thursday says nothing about Thursday.
            text: hub.weatherGlyph(modelData.code, false)
            color: bar.dim
            font.family: bar.fontFamily
            font.pixelSize: 13
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: hub.dayTemp(modelData, "max") + " " + hub.dayTemp(modelData, "min")
            color: bar.foreground
            opacity: 0.7
            font.family: bar.fontFamily
            font.pixelSize: 9
          }
        }
      }
    }
  }

  Column {
    anchors.centerIn: contentArea
    spacing: 6
    visible: !hub.hasWeather

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "\uE33D"  // cloud
      color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.20)
      font.family: bar.fontFamily
      font.pixelSize: 22
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "No weather"
      color: bar.dim
      font.family: bar.fontFamily
      font.pixelSize: 10
    }
  }
}
