// One layer-shell surface per monitor, holding the island and the media pill.
//
// The surface spans the full screen width and stays as tall as the taller of
// the two open panels needs, but only reserves the closed pills' height. That
// split is what lets a panel animate out over the windows below instead of
// shoving them down, while tiled windows still start just under the pills.

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
  readonly property bool mediaOpen: bar.isMediaOpen(screenName)
  readonly property bool anyOpen: open || mediaOpen

  color: "transparent"
  surfaceFormat.opaque: false

  anchors { top: true; left: true; right: true }
  implicitHeight: bar.windowHeight

  exclusionMode: ExclusionMode.Normal
  exclusiveZone: bar.reservedHeight

  WlrLayershell.namespace: "omarchy-island"
  WlrLayershell.layer: WlrLayer.Top
  // The focus grab below is what actually hands this surface the keyboard
  // while something is open; OnDemand is merely the mode that permits it.
  // Exclusive would take the keyboard whether or not it had asked for it.
  WlrLayershell.keyboardFocus: win.anyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Only the two pills ever take input, open or closed. The rest of this tall
  // surface stays transparent to the windows underneath, and a click that
  // lands out there is exactly what should dismiss whatever is open — which
  // the focus grab reports as `onCleared`.
  //
  // A region with children is the union of them, so this is "the island, plus
  // the media pill", with nothing in between.
  mask: Region {
    Region {
      x: Math.round(island.x)
      y: Math.round(island.y)
      width: Math.round(island.width)
      height: Math.round(island.height)
    }
    Region {
      x: Math.round(mediaPill.x)
      y: Math.round(mediaPill.y)
      width: Math.round(mediaPill.width)
      height: Math.round(mediaPill.height)
    }
  }

  // While active, Hyprland routes input only to this window and a click
  // anywhere else clears the grab. That is both the outside-click dismissal
  // and the reason Esc reaches the panel however it was opened — including
  // from `omarchy-shell island open`, where no click ever gave it focus.
  HyprlandFocusGrab {
    active: win.anyOpen
    windows: [win]
    onCleared: bar.close()
  }

  Item {
    anchors.fill: parent
    focus: win.anyOpen
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

    // Declared after the island so that if the two ever do overlap — a narrow
    // screen mid-animation, as one closes and the other opens — the one the
    // user just asked for is the one on top.
    MediaPill {
      id: mediaPill

      bar: win.bar
      hub: win.hub
      open: win.mediaOpen

      anchors.right: parent.right
      anchors.rightMargin: bar.edgeGap
      y: bar.topMargin

      onToggleRequested: bar.toggleMedia(win.screenName)
      onCloseRequested: bar.closeMedia()
    }
  }
}
