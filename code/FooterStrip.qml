// The footer carries what the stock bar kept at its two ends: workspaces on
// the left, tray and the stateful toggles on the right. These are controls,
// not readouts, which is why they sit apart from the cards.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
  id: root

  required property var bar
  required property var hub
  required property string screenName

  signal closeRequested()

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.08)
  }

  // --------------------------------------------------------- workspaces
  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 2
    spacing: 4

    Repeater {
      // Only this monitor's workspaces: the island is per-screen, so showing
      // another head's numbers here would be lying about what a click does.
      model: {
        var values = Hyprland.workspaces ? Hyprland.workspaces.values : []
        return values.filter(function (workspace) {
          return workspace && workspace.monitor && String(workspace.monitor.name) === root.screenName
        }).sort(function (a, b) { return a.id - b.id })
      }

      Item {
        readonly property bool focused: Hyprland.focusedWorkspace !== null
                                        && Hyprland.focusedWorkspace.id === modelData.id

        width: 22; height: 22

        Rectangle {
          anchors.fill: parent
          radius: 7
          color: parent.focused
            ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.16)
            : (workspaceMouse.containsMouse
               ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.09)
               : "transparent")
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
          anchors.centerIn: parent
          text: String(modelData.id)
          color: parent.focused ? bar.foreground : bar.dim
          font.family: bar.fontFamily
          font.pixelSize: 10
          font.weight: parent.focused ? Font.DemiBold : Font.Normal
        }

        MouseArea {
          id: workspaceMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            bar.run("hyprctl dispatch " + bar.shellQuote(
              "hl.dsp.focus({ workspace = \"" + modelData.id + "\" })"))
            root.closeRequested()
          }
        }
      }
    }
  }

  // ------------------------------------------------------- tray + toggles
  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 2
    spacing: 3

    Repeater {
      model: SystemTray.items ? SystemTray.items.values : []

      Item {
        width: 22; height: 22

        Rectangle {
          anchors.fill: parent
          radius: 7
          color: trayMouse.containsMouse
            ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.12)
            : "transparent"
        }

        Image {
          anchors.centerIn: parent
          width: 14; height: 14
          source: String(modelData.icon || "")
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        MouseArea {
          id: trayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton
          onClicked: {
            // `activate` is a no-op on menu-only items; those are best left to
            // the stock tray drawer rather than half-handled here.
            if (!modelData.onlyMenu) modelData.activate()
            root.closeRequested()
          }
        }
      }
    }

    Item { width: SystemTray.items && SystemTray.items.values.length > 0 ? 6 : 0; height: 1 }

    // Omarchy's own network/audio/bluetooth panels are `bar-widget` plugins:
    // they are mounted by whichever bar is active, so replacing the bar takes
    // them with it. These buttons therefore drive the underlying tools
    // directly rather than trying to summon panels that are not loaded.
    IconButton {
      bar: root.bar
      glyph: {
        var wifi = hub.network.wifi
        if (wifi) return "\uF1EB"                                   // wifi
        return hub.network.connections.length > 0 ? "\uF0E8"        // wired
                                                  : "\uF05E"        // offline
      }
      activeState: hub.network.connections.length > 0
      tip: {
        var wifi = hub.network.wifi
        if (wifi) return wifi.ssid + " · " + wifi.signal + "%"
        var addresses = hub.network.addresses || []
        if (addresses.length > 0) return addresses[0].iface + " · " + addresses[0].addr
        return "Offline"
      }
      onActivated: {
        bar.run("omarchy-launch-floating-terminal-with-presentation nmtui")
        root.closeRequested()
      }
    }

    IconButton {
      id: audioButton
      bar: root.bar
      glyph: hub.sinkGlyph(hub.sinkPercent, hub.sinkMuted)
      label: hub.defaultSink ? hub.sinkPercent + "%" : ""
      activeState: !!hub.defaultSink && !hub.sinkMuted
      tip: (hub.sinkLabel || "Audio") + " · right-click for devices"
      onActivated: hub.toggleNodeMute(hub.defaultSink)
      onSecondaryActivated: bar.toggleOverlay("audio")
      highlighted: bar.overlay === "audio"

      // Scroll matches the stock audio widget, which is the one interaction
      // people reach for without looking.
      WheelHandler {
        onWheel: function (event) {
          hub.nudgeNodeVolume(hub.defaultSink, event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
      }
    }

    // The microphone gets its own button rather than hiding inside the audio
    // one: muting a mic is a thing you want to confirm at a glance, and the
    // state has to be visible without opening anything.
    IconButton {
      bar: root.bar
      glyph: hub.sourceMuted ? "\uF131" : "\uF130"
      glyphColor: hub.sourceMuted ? bar.urgent : bar.dim
      activeState: !!hub.defaultSource && !hub.sourceMuted
      tip: (hub.sourceLabel || "Microphone")
           + (hub.sourceMuted ? " · muted" : "")
           + " · right-click for devices"
      onActivated: hub.toggleNodeMute(hub.defaultSource)
      onSecondaryActivated: bar.toggleOverlay("audio")
      highlighted: bar.overlay === "audio"

      WheelHandler {
        onWheel: function (event) {
          hub.nudgeNodeVolume(hub.defaultSource, event.angleDelta.y > 0 ? 0.05 : -0.05)
        }
      }
    }

    IconButton {
      bar: root.bar
      glyph: hub.bluetooth.powered ? "\uF293" : "\uF294"  // bt on / off
      label: hub.bluetooth.devices.length > 0 ? String(hub.bluetooth.devices.length) : ""
      activeState: hub.bluetooth.powered
      tip: hub.bluetooth.devices.length > 0
        ? hub.bluetooth.devices.join(", ")
        : (hub.bluetooth.powered ? "Bluetooth on" : "Bluetooth off")
      onActivated: {
        bar.run("omarchy-launch-floating-terminal-with-presentation bluetoothctl")
        root.closeRequested()
      }
    }

    IconButton {
      bar: root.bar
      glyph: "\uF011"  // power
      tip: "Power menu"
      onActivated: { bar.run("omarchy-menu summon system"); root.closeRequested() }
    }
  }
}
