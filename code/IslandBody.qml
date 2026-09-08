// The open panel's contents: a header the clock slides into, two rows of
// cards, and a footer strip carrying the small stateful controls.
//
// The clock itself is not here — it belongs to Island.qml, because it is the
// one element that exists in both states. This layout just leaves it room.

import QtQuick
import Quickshell

Item {
  id: root

  required property var bar
  required property var hub
  required property var island
  required property string screenName

  signal closeRequested()

  readonly property int pad: island.pad
  readonly property int gap: island.gap
  // The clock lands at `pad`; this is how much of the header it claims before
  // the date is allowed to start.
  readonly property int clockReserve: 92

  // ------------------------------------------------------------------ header
  Item {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.pad }
    height: island.headerHeight

    Column {
      anchors.left: parent.left
      anchors.leftMargin: root.clockReserve
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Text {
        text: hub.dateText
        color: bar.foreground
        font.family: bar.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
      }
      Text {
        text: hub.weekText + "  ·  up " + hub.formatUptime(hub.uptime)
              + (hub.keyboardLayout ? "  ·  " + hub.keyboardLayout : "")
        color: bar.dim
        font.family: bar.fontFamily
        font.pixelSize: 10
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      // Pending updates: a count, not a nag. Click runs the same upgrade the
      // stock widget does.
      IconButton {
        bar: root.bar
        glyph: "\uF021"  // update
        label: hub.updates > 0 ? String(hub.updates) : ""
        visible: hub.updates !== null && hub.updates !== undefined && hub.updates > 0
        tip: hub.updates + " updates pending"
        onActivated: { bar.run("omarchy-launch-floating-terminal-with-presentation omarchy update"); root.closeRequested() }
      }

      IconButton {
        bar: root.bar
        glyph: "\uF0C9"  // menu
        tip: "Omarchy menu"
        onActivated: { bar.run("omarchy-menu"); root.closeRequested() }
      }

      IconButton {
        bar: root.bar
        glyph: "\uF00D"  // close
        tip: "Close"
        onActivated: root.closeRequested()
      }
    }
  }

  // ------------------------------------------------------------------- cards
  Grid {
    id: grid

    anchors {
      top: header.bottom
      topMargin: root.gap
      left: parent.left
      right: parent.right
      leftMargin: root.pad
      rightMargin: root.pad
    }

    columns: 3
    rows: 2
    columnSpacing: root.gap
    rowSpacing: root.gap

    readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns
    readonly property real cellHeight: 150

    MediaCard    { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
    CalendarCard { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
    AgentsCard   { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
    SystemCard   { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
    ServicesCard { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
    PortsCard    { bar: root.bar; hub: root.hub; width: grid.cellWidth; height: grid.cellHeight }
  }

  // ------------------------------------------------------------- overlay sheet
  Loader {
    anchors.fill: grid
    active: bar.overlay === "audio"
    z: 5

    sourceComponent: audioPickerComponent
  }

  Component {
    id: audioPickerComponent

    AudioPicker {
      bar: root.bar
      hub: root.hub
      onCloseRequested: root.bar.overlay = ""
    }
  }

  // ------------------------------------------------------------------ footer
  FooterStrip {
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      leftMargin: root.pad
      rightMargin: root.pad
      bottomMargin: root.pad
    }
    height: island.footerHeight

    bar: root.bar
    hub: root.hub
    screenName: root.screenName
    onCloseRequested: root.closeRequested()
  }
}
