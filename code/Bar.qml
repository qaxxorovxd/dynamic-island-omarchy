// Dynamic Island — a full replacement for the Omarchy bar.
//
// The whole surface is one floating island centred at the top of each screen.
// Closed it is a clock pill and nothing else. Clicked, it grows into a panel
// carrying everything the stock bar spreads along its width: date, media,
// agents, services, ports, system meters, network, audio, workspaces, tray.
//
// This is a `kind: "bar"` plugin, so the host mounts it *instead of*
// omarchy.bar and hands it the same injected properties. It owns its own
// layer-shell windows; nothing of the stock bar is reused.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons

Item {
  id: root

  // ---- injected by the omarchy-shell host (see shell.qml configureBar) ----
  //
  // None of these may be `required`. The host loads a plugin bar through
  // `Loader { source: url }` and only assigns properties afterwards, in
  // onLoaded — a required property has to be set at construction, so marking
  // any of them required makes the bar fail to load and silently fall back to
  // omarchy.bar. Defaults here stand in for the gap before onLoaded runs.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: null
  property var shell: null
  property var manifest: null

  property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/island.bar"

  // ------------------------------------------------------------- geometry
  // The window is always tall enough to hold the open panel; only the closed
  // pill height is ever reserved from the workspace, so windows tile right up
  // under the island and the panel opens *over* them.
  readonly property int topMargin: 6
  readonly property int collapsedHeight: 30
  readonly property int expandedWidth: 760
  readonly property int expandedHeight: 440
  readonly property int reservedHeight: collapsedHeight + topMargin * 2
  readonly property int windowHeight: expandedHeight + topMargin * 2 + 24

  // ---------------------------------------------------------------- state
  // One island is open at a time, across every monitor. `openScreen` names
  // which surface owns it; the others stay collapsed.
  property string openScreen: ""
  function isOpen(name) { return openScreen === String(name) }
  function toggle(name) { openScreen = isOpen(name) ? "" : String(name) }
  function close() { openScreen = ""; overlay = "" }

  // A named sheet covering the card grid — currently only "audio". Kept on the
  // bar rather than inside the panel so closing the island clears it too, and
  // so it cannot outlive the surface that drew it.
  property string overlay: ""
  function toggleOverlay(name) { overlay = overlay === name ? "" : String(name) }

  // Switching workspace means the user has moved on. Leaving the panel hanging
  // over a different workspace's windows is just clutter, and the focus grab
  // would keep swallowing input over there until something else dismissed it.
  //
  // Bound to a local property rather than hooked with Connections so the change
  // signal is the property's own — it fires for every reassignment, including
  // the workspace object being replaced with an equivalent one.
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  onFocusedWorkspaceChanged: close()

  // ---------------------------------------------------------------- theme
  property string fontFamily: Style.font.family
  property color foreground: Color.bar.text
  property color background: Color.bar.background
  property color urgent: Color.bar.active
  property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.45)
  property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)

  // The island paints its own ground rather than borrowing the bar's configured
  // alpha: a floating object needs to read as one object. It is darkened below
  // the theme background so light card content stays legible, and left slightly
  // translucent because install.sh adds a Hyprland blur rule for the
  // `omarchy-island` namespace — frost, not a hole.
  readonly property color islandBackground: Qt.rgba(
    Color.background.r * 0.5, Color.background.g * 0.5, Color.background.b * 0.5, 0.88)

  Behavior on foreground { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

  // Widgets and cards call these; they mirror the stock bar's contract so the
  // card code reads the same as first-party widget code.
  function run(command) {
    if (!command) return
    Quickshell.execDetached(["bash", "-lc", String(command)])
  }
  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  // ----------------------------------------------------------------- data
  // Named `hub`, not `data`: `data` is Item's default property and binding a
  // var of that name onto a child silently fights the object hierarchy.
  Data {
    id: dataHub
    pluginDir: root.pluginDir
    // Poll hard only while someone is looking at it.
    active: root.openScreen !== ""
  }


  // Lets the island be driven from a keybind or a script, and is how the
  // panel can be opened without a pointer:
  //     omarchy-shell island toggle
  IpcHandler {
    target: "island"

    function toggle(): void {
      // No screen named means the focused one, which is what a keybind wants.
      var name = Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name) : ""
      if (Hyprland.focusedMonitor) name = String(Hyprland.focusedMonitor.name)
      root.openScreen = root.openScreen === name ? "" : name
    }
    function open(): void {
      var name = Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name) : ""
      if (Hyprland.focusedMonitor) name = String(Hyprland.focusedMonitor.name)
      root.openScreen = name
    }
    function close(): void { root.openScreen = "" }

    // Opens the panel straight onto the audio device sheet, so picking an
    // output can be a single keybind rather than open-then-right-click.
    function audio(): void {
      var name = Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name) : ""
      if (Hyprland.focusedMonitor) name = String(Hyprland.focusedMonitor.name)
      root.openScreen = name
      root.overlay = "audio"
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      IslandPanel {
        required property var modelData

        screen: modelData
        bar: root
        hub: dataHub
      }
    }
  }
}
