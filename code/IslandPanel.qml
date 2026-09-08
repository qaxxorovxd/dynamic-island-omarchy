// One layer-shell surface per monitor, holding one island.
//
// The surface spans the full screen width and stays as tall as the *open*
// panel needs, but only reserves the closed pill's height. That split is what
// lets the panel animate out over the windows below instead of shoving them
// down, while tiled windows still start just under the collapsed pill.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: win

  required property var bar
  required property var hub

  readonly property string screenName: screen ? String(screen.name) : ""
  readonly property bool open: bar.isOpen(screenName)

  color: "transparent"
  surfaceFormat.opaque: false

  anchors { top: true; left: true; right: true }
  implicitHeight: bar.windowHeight

  exclusionMode: ExclusionMode.Normal
  exclusiveZone: bar.reservedHeight

  WlrLayershell.namespace: "omarchy-island"
  WlrLayershell.layer: WlrLayer.Top
  // The focus grab below is what actually hands this surface the keyboard
  // while it is open; OnDemand is merely the mode that permits it. Exclusive
  // would take the keyboard whether or not the island had asked for it.
  WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Only the island itself ever takes input, open or closed. The rest of this
  // tall surface stays transparent to the windows underneath, and a click that
  // lands out there is exactly what should dismiss the panel — which the focus
  // grab reports as `onCleared`.
  mask: Region {
    x: Math.round(island.x)
    y: Math.round(island.y)
    width: Math.round(island.width)
    height: Math.round(island.height)
  }

  // While active, Hyprland routes input only to this window and a click
  // anywhere else clears the grab. That is both the outside-click dismissal
  // and the reason Esc reaches the island however it was opened — including
  // from `omarchy-shell island open`, where no click ever gave it focus.
  HyprlandFocusGrab {
    active: win.open
    windows: [win]
    onCleared: bar.close()
  }

  Item {
    anchors.fill: parent
    focus: win.open
    Keys.onEscapePressed: bar.close()

    Island {
      id: island

      bar: win.bar
      hub: win.hub
      open: win.open
      screenName: win.screenName

      anchors.horizontalCenter: parent.horizontalCenter
      y: bar.topMargin

      onToggleRequested: bar.toggle(win.screenName)
      onCloseRequested: bar.close()
    }
  }
}
