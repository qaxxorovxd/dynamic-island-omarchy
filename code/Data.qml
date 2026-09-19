// Everything the island and the media pill show, in one place.
//
// Four sources feed it:
//
//   · the clock, local and ticking on a timer;
//   · one `collect.sh` run returning a single JSON blob for the machine
//     readouts — deliberately the only recurring subprocess, because a panel
//     that shells out once per card would spend its whole open animation
//     forking;
//   · PipeWire, live, for everything audio. Volume and mute have to be
//     correct the instant a slider moves and the instant a media key is
//     pressed, which a 4-second poll can never be;
//   · `weather.sh`, on its own slow timer, because it is the one probe that
//     leaves the machine.
//
// Cadence is tied to whether anyone is looking. Open, the collector refreshes
// every few seconds. Closed, it drops to a slow tick that exists only so the
// pill can show a dot when a watched unit has failed — and that slow tick is
// also where the one expensive local probe, the package-update count, is
// allowed to run.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

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

  // -------------------------------------------------------------- audio
  //
  // Straight off PipeWire rather than off `wpctl`: the readings are pushed,
  // not polled, so a slider reflects a change the frame it happens and a
  // volume key pressed elsewhere moves the pill without waiting for a tick.
  //
  // Node ids here are PipeWire global ids — the same numbers `wpctl` prints —
  // but nothing shells out to wpctl any more: volume, mute and the default
  // device are all writable properties.
  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function isAudioSink(node) {
    return !!node && node.isSink && !node.isStream
           && (node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink
  }
  function isAudioSource(node) {
    return !!node && !node.isSink && !node.isStream
           && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource
  }

  readonly property var sinks: pwNodes.filter(isAudioSink)
  readonly property var sources: pwNodes.filter(isAudioSource)

  // A node reports nothing — not even its own volume — until something binds
  // it. Every device the panels can show is bound, which is a handful of
  // objects, not a subscription to the whole graph.
  property var audioTracker: PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  readonly property var defaultSink: Pipewire.defaultAudioSink
  readonly property var defaultSource: Pipewire.defaultAudioSource

  function nodeLabel(node) {
    if (!node) return ""
    return String(node.description || node.nickname || node.name || "")
  }
  function nodeVolume(node) {
    return (node && node.audio) ? Number(node.audio.volume) || 0 : 0
  }
  function nodePercent(node) {
    return Math.round(nodeVolume(node) * 100)
  }
  function nodeMuted(node) {
    return !!(node && node.audio && node.audio.muted)
  }
  // Volume is capped at 100%. PipeWire happily accepts more, but software
  // gain above unity is the shortest path to a blown-out speaker, and nothing
  // in this panel is the right place to reach for it.
  function setNodeVolume(node, fraction) {
    if (!node || !node.audio) return
    node.audio.volume = Math.max(0, Math.min(1, Number(fraction) || 0))
  }
  function nudgeNodeVolume(node, delta) {
    if (!node || !node.audio) return
    setNodeVolume(node, nodeVolume(node) + delta)
    // Nudging a muted device and hearing nothing reads as a broken control.
    if (delta > 0 && node.audio.muted) node.audio.muted = false
  }
  function toggleNodeMute(node) {
    if (!node || !node.audio) return
    node.audio.muted = !node.audio.muted
  }
  function makeDefault(node) {
    if (!node) return
    if (node.isSink) Pipewire.preferredDefaultAudioSink = node
    else Pipewire.preferredDefaultAudioSource = node
  }

  // Shorthands for the two devices the strips and the pill actually show.
  readonly property int sinkPercent: nodePercent(defaultSink)
  readonly property bool sinkMuted: nodeMuted(defaultSink)
  readonly property string sinkLabel: nodeLabel(defaultSink)
  readonly property int sourcePercent: nodePercent(defaultSource)
  readonly property bool sourceMuted: nodeMuted(defaultSource)
  readonly property string sourceLabel: nodeLabel(defaultSource)

  function sinkGlyph(percent, muted) {
    if (muted) return "\uF026"                 // muted
    if (percent >= 50) return "\uF028"         // high
    return percent > 0 ? "\uF027" : "\uF026" // low / silent
  }

  // -------------------------------------------------------------- media
  //
  // Straight off MPRIS rather than through the omarchy.media service, so the
  // island does not depend on that plugin being loaded.
  readonly property var players: Mpris.players ? Mpris.players.values : []

  // Players worth offering: anything that has told us what it is playing.
  readonly property var candidates: players.filter(function (p) {
    return p && (p.trackTitle || p.trackArtist)
  })

  // Set by the pill's player switch; cleared automatically when that player
  // goes away, because the lookup below simply fails to find it.
  property string preferredPlayer: ""

  readonly property var player: {
    if (candidates.length === 0) return null
    if (preferredPlayer !== "") {
      for (var i = 0; i < candidates.length; i++) {
        if (String(candidates[i].dbusName) === preferredPlayer) return candidates[i]
      }
    }
    // A player that is actually making sound wins over one merely loaded.
    for (var j = 0; j < candidates.length; j++) {
      if (candidates[j].isPlaying) return candidates[j]
    }
    return candidates[0]
  }

  readonly property bool hasMedia: player !== null
  readonly property string trackTitle: player ? String(player.trackTitle || "") : ""
  readonly property string trackArtist: player ? String(player.trackArtist || "") : ""
  readonly property string trackAlbum: player ? String(player.trackAlbum || "") : ""
  readonly property string trackArt: player ? String(player.trackArtUrl || "") : ""
  readonly property string playerName: player ? String(player.identity || "") : ""
  readonly property bool playing: player ? player.isPlaying === true : false

  function mediaAction(action) {
    if (!player) return
    if (action === "toggle") { if (player.canTogglePlaying) player.togglePlaying() }
    else if (action === "next" && player.canGoNext) { player.next() }
    else if (action === "previous" && player.canGoPrevious) { player.previous() }
  }

  // Cycles through every player that has metadata. One button rather than a
  // list: two players is the common case and a list of one is just chrome.
  function cyclePlayer() {
    if (candidates.length < 2) return
    var index = 0
    for (var i = 0; i < candidates.length; i++) {
      if (candidates[i] === player) { index = i; break }
    }
    preferredPlayer = String(candidates[(index + 1) % candidates.length].dbusName)
  }

  function toggleShuffle() {
    if (player && player.shuffleSupported) player.shuffle = !player.shuffle
  }
  // None → whole playlist → this track → none, which is the order every other
  // player cycles it in.
  function cycleLoop() {
    if (!player || !player.loopSupported) return
    if (player.loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist
    else if (player.loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track
    else player.loopState = MprisLoopState.None
  }
  function seekTo(fraction) {
    if (!player || !player.canSeek || !player.lengthSupported) return
    var length = Number(player.length) || 0
    if (length <= 0) return
    player.position = Math.max(0, Math.min(1, fraction)) * length
  }

  function formatClock(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var mins = Math.floor(total / 60)
    var secs = total % 60
    if (mins >= 60) {
      return Math.floor(mins / 60) + ":" + ("0" + (mins % 60)).slice(-2)
             + ":" + ("0" + secs).slice(-2)
    }
    return mins + ":" + ("0" + secs).slice(-2)
  }

  // ------------------------------------------------------------- weather
  //
  // `weather.sh` owns the network call and the on-disk cache; this side only
  // asks for it and reads what comes back, so a dead link or a rate limit
  // leaves the last good reading on screen instead of a blank card.
  property var weather: ({ ok: false })
  readonly property bool hasWeather: !!weather && weather.ok === true

  // Three countries measure temperature in Fahrenheit; everywhere else the
  // locale is a better guide than anything this panel could ask for.
  readonly property bool imperial: {
    var country = String((weather && weather.country) || "").toLowerCase()
    if (country !== "") {
      if (country.indexOf("united states") === 0 || country === "usa"
          || country === "liberia" || country === "myanmar" || country === "burma")
        return true
      return false
    }
    var locale = String(Qt.locale().name || "").replace(".", "_")
    return /^en_US($|[_-])/.test(locale) || /^en_LR($|[_-])/.test(locale) || /^my($|[_-])/.test(locale)
  }

  readonly property string weatherTemp: hasWeather
    ? String(imperial ? weather.tempF : weather.tempC) + "°" : ""
  readonly property string weatherFeels: hasWeather
    ? String(imperial ? weather.feelsF : weather.feelsC) + "°" : ""
  readonly property string weatherWind: hasWeather
    ? (imperial ? weather.windMph + " mph" : weather.windKmph + " km/h") : ""
  readonly property string weatherIcon: hasWeather
    ? weatherGlyph(weather.code, weather.isDay === false) : ""
  readonly property var weatherDays: (hasWeather && weather.days) ? weather.days : []

  function dayTemp(day, which) {
    if (!day) return ""
    var value = imperial ? (which === "max" ? day.maxF : day.minF)
                         : (which === "max" ? day.maxC : day.minC)
    return (value === undefined || value === null || value === "") ? "" : String(value) + "°"
  }

  // Short weekday for a forecast column; today is named rather than numbered.
  function dayLabel(dateString) {
    var parsed = new Date(String(dateString) + "T12:00:00")
    if (isNaN(parsed.getTime())) return ""
    var today = new Date()
    if (parsed.getFullYear() === today.getFullYear()
        && parsed.getMonth() === today.getMonth()
        && parsed.getDate() === today.getDate()) return "Today"
    return Qt.formatDateTime(parsed, "ddd")
  }

  // World Weather Online condition codes to Nerd Font weather glyphs. Same
  // mapping the stock Omarchy weather widget uses, so both agree on what a
  // given sky looks like.
  function weatherGlyph(code, night) {
    switch (parseInt(String(code || "0"), 10)) {
      case 113: return night ? "\uE32B" : "\uE30D"                     // clear
      case 116: return night ? "\uE32E" : "\uE302"                     // partly cloudy
      case 119: case 122: return "\uE33D"                              // cloudy, overcast
      case 143: case 248: case 260: return night ? "\uE346" : "\uE313"  // mist, fog
      case 176: case 263: case 353: return night ? "\uE333" : "\uE308"  // light showers
      case 179: case 227: case 230: case 323: case 326: case 368:
        return night ? "\uE327" : "\uE30A"                             // snow showers
      case 182: case 185: case 281: case 284: case 311: case 314:
      case 317: case 320: case 350: case 362: case 365: case 374: case 377:
        return "\uE3AD"                                                // sleet, freezing rain
      case 200: case 386: case 389: case 392: case 395: return "\uE31D"  // thunder
      case 266: case 293: case 296: case 299: case 302: case 305: case 308:
      case 356: case 359: return "\uE318"                              // rain
      case 329: case 332: case 335: case 338: case 371: return "\uE31A"  // snow
      default: return "\uE33D"
    }
  }

  function refreshWeather(force) {
    if (weatherProc.running || pluginDir === "") return
    var args = [pluginDir + "/scripts/weather.sh"]
    if (force) args.push("--force")
    weatherProc.command = args
    weatherProc.running = true
  }

  property var weatherProc: Process {
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "{}")
          if (parsed && parsed.ok) root.weather = parsed
        } catch (e) {
          // Keep the last good reading rather than blanking the card.
        }
      }
    }
  }

  // The script serves its cache without touching the network, so this tick is
  // a fork and a file read except once every fifteen minutes.
  property var weatherTimer: Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshWeather(false)
  }

  // ------------------------------------------------------------ collection
  property int slowTicks: 0

  function refresh(withUpdates) {
    if (collector.running || pluginDir === "") return
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
  onActiveChanged: if (active) { refresh(false); refreshWeather(false) }
}
