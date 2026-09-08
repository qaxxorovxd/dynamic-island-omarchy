// Everything the island shows, in one place.
//
// Two sources feed it. The clock is local and ticks on a timer; everything
// else comes from one `collect.sh` run that returns a single JSON blob. That
// script is deliberately the only subprocess: a panel that shells out once per
// card would spend its whole open animation forking.
//
// Cadence is tied to whether anyone is looking. Open, it refreshes every few
// seconds. Closed, it drops to a slow tick that exists only so the pill can
// show a dot when a watched unit has failed — and that slow tick is also where
// the one expensive probe, the package-update count, is allowed to run.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

QtObject {
  id: root

  property string pluginDir: ""
  property bool active: false

  // ------------------------------------------------------------------ clock
  property date now: new Date()
  readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
  readonly property string dateText: Qt.formatDateTime(now, "dddd, d MMMM yyyy")
  readonly property string weekText: "W" + weekNumber(now)

  function weekNumber(value) {
    // ISO-8601: week 1 is the week holding the first Thursday.
    var d = new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()))
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7))
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
  }

  // ----------------------------------------------------------- collected
  property var payload: ({})
  property bool loaded: false

  readonly property var services: payload.services || []
  readonly property var ports: payload.ports || []
  readonly property var agents: payload.agents || []
  readonly property var cpu: payload.cpu || ({ percent: 0, load: [] })
  readonly property var memory: payload.memory || ({ percent: 0, total: 0, used: 0 })
  readonly property var swap: payload.swap || ({ percent: 0, total: 0, used: 0 })
  readonly property var disk: payload.disk || ({ percent: 0, total: 0, used: 0 })
  readonly property var network: payload.network || ({ connections: [], addresses: [] })
  readonly property var audio: payload.audio || ({})
  readonly property var sinks: (payload.audio && payload.audio.sinks) || []
  readonly property var sources: (payload.audio && payload.audio.sources) || []
  readonly property var bluetooth: payload.bluetooth || ({ powered: false, devices: [] })
  readonly property var battery: payload.battery || null
  readonly property var brightness: payload.brightness
  readonly property var temp: payload.temp
  readonly property var updates: payload.updates
  readonly property int uptime: payload.uptime || 0
  readonly property string keyboardLayout: payload.keyboardLayout || ""

  readonly property int failedCount: services.filter(function (s) { return s.state === "failed" }).length
  readonly property int upCount: services.filter(function (s) { return s.state === "up" }).length
  readonly property int exposedCount: ports.filter(function (p) { return p.exposed }).length

  function formatBytes(value) {
    var bytes = Number(value) || 0
    var units = ["B", "K", "M", "G", "T"]
    var index = 0
    while (bytes >= 1024 && index < units.length - 1) { bytes /= 1024; index++ }
    return (bytes >= 10 || index === 0 ? Math.round(bytes) : bytes.toFixed(1)) + units[index]
  }

  function formatUptime(seconds) {
    var total = Number(seconds) || 0
    var days = Math.floor(total / 86400)
    var hours = Math.floor((total % 86400) / 3600)
    var mins = Math.floor((total % 3600) / 60)
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + "h " + mins + "m"
    return mins + "m"
  }

  // -------------------------------------------------------------- media
  //
  // Straight off MPRIS rather than through the omarchy.media service, so the
  // island does not depend on that plugin being loaded.
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var candidates = players.filter(function (p) { return p && (p.trackTitle || p.trackArtist) })
    if (candidates.length === 0) return null
    // A player that is actually making sound wins over one merely loaded.
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i].isPlaying) return candidates[i]
    }
    return candidates[0]
  }
  readonly property bool hasMedia: player !== null
  readonly property string trackTitle: player ? String(player.trackTitle || "") : ""
  readonly property string trackArtist: player ? String(player.trackArtist || "") : ""
  readonly property string trackArt: player ? String(player.trackArtUrl || "") : ""
  readonly property bool playing: player ? player.isPlaying === true : false

  // WirePlumber ids, straight from `wpctl status`. Setting a default moves both
  // new streams and — because WirePlumber's default policy follows the default
  // node — anything currently playing that has not pinned a target.
  function setDefaultSink(id) { runWpctl(["set-default", String(id)]) }
  function setDefaultSource(id) { runWpctl(["set-default", String(id)]) }
  function toggleMute(id) { runWpctl(["set-mute", String(id), "toggle"]) }
  function setVolume(id, delta) {
    runWpctl(["set-volume", "-l", "1.0", String(id), Math.abs(delta) + "%" + (delta > 0 ? "+" : "-")])
  }

  property var wpctl: Process { }
  function runWpctl(args) {
    if (wpctl.running) return
    wpctl.command = ["wpctl"].concat(args)
    wpctl.running = true
    // Re-read straight after so the picker reflects the change without waiting
    // for the next poll tick.
    audioSettle.restart()
  }
  property var audioSettle: Timer {
    interval: 180
    onTriggered: root.refresh(false)
  }

  function mediaAction(action) {
    if (!player) return
    if (action === "toggle") { player.togglePlaying() }
    else if (action === "next" && player.canGoNext) { player.next() }
    else if (action === "previous" && player.canGoPrevious) { player.previous() }
  }

  // ------------------------------------------------------------ collection
  property int slowTicks: 0

  function refresh(withUpdates) {
    if (collector.running) return
    var args = [pluginDir + "/scripts/collect.sh"]
    if (withUpdates) args.push("--updates")
    collector.command = args
    collector.running = true
  }

  property var collector: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "{}")
          // `updates` is absent on fast ticks; carrying the last known count
          // forward stops the badge blinking out between slow ticks.
          if (parsed.updates === null || parsed.updates === undefined)
            parsed.updates = root.payload ? root.payload.updates : null
          root.payload = parsed
          root.loaded = true
        } catch (e) {
          // A malformed blob means the script is missing or broke mid-write.
          // Keep the last good reading rather than blanking the panel.
        }
      }
    }
  }

  property var clockTimer: Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  property var pollTimer: Timer {
    // 4s while open is fast enough for meters to feel live and slow enough to
    // stay invisible in `top`. 90s closed is only there for the failure dot.
    interval: root.active ? 4000 : 90000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var slow = !root.active
      if (slow) root.slowTicks++
      // Roughly every 15 minutes of closed time, and never while open.
      root.refresh(slow && root.slowTicks % 10 === 1)
    }
  }

  // Opening should show current numbers, not whatever the last slow tick left.
  onActiveChanged: if (active) refresh(false)
}
