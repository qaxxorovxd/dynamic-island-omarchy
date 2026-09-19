// Dynamic Island — a full replacement for the Omarchy bar.
//
// Two floating objects sit at the top of each screen. The island is centred:
// closed it is a clock pill and nothing else, clicked it grows into a panel
// carrying everything the stock bar spreads along its width — date, weather,
// agents, services, ports, system meters, network, workspaces, tray.
//
// The media pill is parked at the right edge and owns sound: closed it shows
// the track and the volume, clicked it grows into a panel with the transport,
// the seek bar, both volumes, and the output and input device lists.
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
  //
  // The gap *below* the pill is not the reserved leftover alone: Hyprland lays
  // the first tiled window out `general:gaps_out` under the exclusive zone, so
  // reserving `topMargin` on both sides makes the bottom read a whole gaps_out
  // heavier than the top. Instead the pill sits `edgeGap` from the screen edge
  // and the zone reserves only what Hyprland's own gap does not already
  // provide — top and bottom then measure the same. `Style.gapsOut` is half of
  // Hyprland's value (the shell halves it for panel-to-edge distance), so it is
  // doubled back here; the floor keeps the pill off the bezel when gaps are
  // toggled off entirely.
  readonly property int windowGap: Style.gapsOut * 2
  readonly property int edgeGap: Math.max(6, windowGap)

  readonly property int topMargin: edgeGap
  readonly property int collapsedHeight: 26
  readonly property int expandedWidth: 760
  readonly property int expandedHeight: 440

  // Both closed pills are the same height; the clock is simply given this much
  // width beyond the time it holds, so the centre reads as the larger object.
  readonly property int clockExtraWidth: 80

  // The media pill shares the collapsed height so the two closed pills read as
  // one row, and is narrow enough to open beside the island rather than over
  // it on any ordinary screen. Opening one closes the other regardless, which
  // is what keeps them from colliding on a small one.
  readonly property int mediaExpandedWidth: 420
  readonly property int mediaExpandedHeight: 480

  readonly property int reservedHeight: topMargin + collapsedHeight + Math.max(0, edgeGap - windowGap)
  readonly property int windowHeight: Math.max(expandedHeight, mediaExpandedHeight) + topMargin * 2 + 24

  // ---------------------------------------------------------------- state
  // One island is open at a time, across every monitor. `openScreen` names
  // which surface owns it; the others stay collapsed.
  property string openScreen: ""
  function isOpen(name) { return openScreen === String(name) }
  function toggle(name) {
    var target = isOpen(name) ? "" : String(name)
    openScreen = target
    // Two panels open at once would overlap on a narrow screen, and there is
    // nothing to read in the one behind anyway.
    if (target !== "") mediaScreen = ""
  }
  function close() { openScreen = ""; overlay = ""; mediaScreen = "" }

  // The media pill keeps its own open screen for the same reason: one panel
  // at a time, across every monitor.
  property string mediaScreen: ""
  function isMediaOpen(name) { return mediaScreen === String(name) }
  function toggleMedia(name) {
    var target = isMediaOpen(name) ? "" : String(name)
    mediaScreen = target
    if (target !== "") { openScreen = ""; overlay = "" }
  }
  function closeMedia() { mediaScreen = "" }

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

  // Which screen a keybind means: the focused monitor, falling back to the
  // first one so an IPC call still lands when Hyprland has not said yet.
  function focusedScreenName() {
    if (Hyprland.focusedMonitor) return String(Hyprland.focusedMonitor.name)
    return Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name) : ""
  }

  // ----------------------------------------------------------------- data
  // Named `hub`, not `data`: `data` is Item's default property and binding a
  // var of that name onto a child silently fights the object hierarchy.
  Data {
    id: dataHub
    pluginDir: root.pluginDir
    // Poll hard only while someone is looking at the island. The media pill
    // deliberately does not count: everything in it is pushed from PipeWire
    // and MPRIS, so opening it needs no subprocess at all.
    active: root.openScreen !== ""
  }


  // Lets the island be driven from a keybind or a script, and is how the
  // panel can be opened without a pointer:
  //     omarchy-shell island toggle
  IpcHandler {
    target: "island"

    function toggle(): void { root.toggle(root.focusedScreenName()) }
    function open(): void {
      root.openScreen = root.focusedScreenName()
      root.mediaScreen = ""
    }
    function close(): void { root.close() }

    // Opens the island straight onto the audio device sheet, so picking an
    // output can be a single keybind rather than open-then-right-click.
    function audio(): void {
      root.openScreen = root.focusedScreenName()
      root.mediaScreen = ""
      root.overlay = "audio"
    }

    // The media pill's own three, so the panel that owns playback and volume
    // is reachable without touching the pointer.
    function media(): void { root.toggleMedia(root.focusedScreenName()) }
    function mediaOpen(): void {
      root.mediaScreen = root.focusedScreenName()
      root.openScreen = ""
      root.overlay = ""
    }
    function mediaClose(): void { root.closeMedia() }
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
