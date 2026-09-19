# Dynamic Island for Omarchy

A macOS-style Dynamic Island in place of the Omarchy status bar.

Two floating objects sit at the top of every screen and nothing else does.

The **island** is centred: closed it is a rounded pill showing the time, and a
click grows it — one continuous animation, the clock riding from dead centre to
the top-left corner — into a panel carrying what the stock bar used to spread
across the screen: date, weather, agents, services, listening ports, system
meters, network, bluetooth, workspaces and the tray.

The **media pill** sits at the right edge and owns sound. Closed it shows the
track and the volume, and nothing else. Clicked it grows into a panel with the
cover art, a seek bar, the transport, both volumes, and the output and input
device lists.

```
  closed                          open
  ┌──────────┐                    ┌──────────────────────────────────────┐
  │  01:01   │        →           │ 01:01  Wednesday, 9 September 2026 ✕ │
  └──────────┘                    │ ┌────────┐┌────────┐┌──────────────┐ │
                                  │ │Weather ││Calendar││   Agents     │ │
                                  │ └────────┘└────────┘└──────────────┘ │
                                  │ ┌────────┐┌────────┐┌──────────────┐ │
                                  │ │ System ││Services││    Ports     │ │
                                  │ └────────┘└────────┘└──────────────┘ │
                                  │ 1 2 3            tray  󰖩 󰕾 󰂯 ⏻      │
                                  └──────────────────────────────────────┘

  ┌──────────────────────┐        ┌────────────────────────────┐
  │ ♪ Sunset · 󰕾 42%     │   →    │ NOW PLAYING          mpv ✕ │
  └──────────────────────┘        │ ┌────┐ Sunset             │
                                  │ │ ▦  │ Nujabes            │
                                  │ └────┘ Modal Soul         │
                                  │ 0:42 ──●──────────── 3:21  │
                                  │      ⤮  ⏮  ( ⏸ )  ⏭  ⟳     │
                                  │ ──────────────────────────  │
                                  │ 󰕾 ────────●──────    42%    │
                                  │ 󰍬 ──────────────●    88%    │
                                  │ ──────────────────────────  │
                                  │ [OUTPUT] [INPUT]           │
                                  │ ● USB Audio          42%   │
                                  │ ○ Built-in Audio     40%   │
                                  └────────────────────────────┘
```

Only one panel is open at a time: opening either closes the other.

## Install

```bash
./install.sh
```

Then click the clock, or the media pill. `Esc`, the ✕, a click anywhere
outside, or switching workspace closes whatever is open.

To remove it and get the stock bar back exactly as it was:

```bash
./uninstall.sh
```

## Without the pointer

Both pills expose IPC, which is worth binding to keys in
`~/.config/hypr/bindings.lua`:

```bash
omarchy-shell island toggle
omarchy-shell island open
omarchy-shell island close
omarchy-shell island audio        # the island, straight onto the device sheet

omarchy-shell island media        # the media pill
omarchy-shell island mediaOpen
omarchy-shell island mediaClose
```

All of these act on the focused monitor.

## What it shows

### The island

| Card | Contents |
|---|---|
| **Weather** | Current conditions, what it feels like, humidity and wind, plus a three-day outlook |
| **Calendar** | Month grid, Monday-first, today marked, ISO week in the corner |
| **Agents** | Coding-agent quotas, read from Omarchy's own usage snapshots |
| **System** | CPU, memory, disk meters plus load, swap, temperature, uptime, battery and backlight where present. Click opens `btop` |
| **Services** | Watched systemd units, failures sorted first |
| **Ports** | Listening TCP ports, with anything bound past loopback flagged |
| **Header** | Clock, full date, ISO week, uptime, keyboard layout, pending updates, menu, close |
| **Footer** | This monitor's workspaces, the system tray, and network / speaker / microphone / bluetooth / power |

The closed pill stays deliberately mute. The only thing it will ever add to
the time is a small dot, when a watched service has actually failed.

### The media pill

Closed, it is the track title and the output volume — the two things worth a
glance. It also takes a scroll for volume and a middle click to mute, so the
common case never needs the panel at all.

Open, it carries everything to do with sound:

| | |
|---|---|
| **Now playing** | Cover art, title, artist, album, and which player it is |
| **Seek** | Elapsed and total, draggable wherever the player allows seeking |
| **Transport** | Shuffle, previous, play/pause, next, repeat — each greyed out when the player says it cannot |
| **Volumes** | Output and input, draggable, scrollable, each with its own mute |
| **Devices** | Every output and input, with volume and mute per device; click one to make it the default |

With more than one player running, a switch button appears in the header and
cycles through them.

### Weather

Conditions come from wttr.in, and the location is Omarchy's own — the one
`omarchy-weather-location --set` writes — so the card follows whatever the
stock weather widget was set to. With nothing configured, the location is
resolved from the outbound IP address.

A reading is cached on disk for fifteen minutes, so the card is populated the
moment the panel opens and a network that is down just leaves the last reading
in place. Fahrenheit is used in the three countries that use it, and the
locale decides when the report has no country.

### Audio

Volume, mute and the device lists come straight off PipeWire, not off a poll:
a media key pressed elsewhere moves the pill in the same frame, and a slider
dragged here is a property write, not a subprocess.

The island's speaker and microphone buttons each do three things:

| | |
|---|---|
| left click | mute / unmute that device |
| right click | open the device sheet |
| scroll | volume, in 5% steps |

In any device list — the island's sheet or the media panel's lower half —
clicking a row makes that device the default, the glyph on the right mutes
just that device, and scrolling a row sets that device's volume; all on the
row's own device, not on whatever happens to be default.

## How it works

It is a `kind: "bar"` plugin for the Omarchy shell, so the host mounts it
*instead of* `omarchy.bar` rather than alongside it. Selection is one key in
`~/.config/omarchy/shell.json`:

```json
{ "bar": { "id": "island.bar" } }
```

```
code/
  manifest.json      declares id island.bar, kind "bar", entry point Bar.qml
  Bar.qml            plugin root: theme, geometry, open/close state, IPC
  IslandPanel.qml    one layer-shell surface per monitor, holding both pills
  Island.qml         the pill→panel animation and the clock that survives it
  IslandBody.qml     header, card grid, footer
  MediaPill.qml      the right-hand pill and its own pill→panel animation
  MediaBody.qml      now playing, seek, transport, volumes, device lists
  MediaButton.qml    round transport button
  VolumeRow.qml      one device's volume: mute, drag, scroll
  Card.qml           shared tile chrome
  Meter.qml          the one meter shape the System card reuses
  IconButton.qml     small glyph button
  ToolTipBubble.qml  in-surface tooltip
  *Card.qml          the six tiles
  AudioPicker.qml    the island's output/input device sheet
  DeviceColumn.qml   a device list: select, mute, scroll per device
  Data.qml           clock, PipeWire, MPRIS, weather, and the collector's output
  scripts/collect.sh one JSON blob: units, ports, cpu, memory, disk, net, …
  scripts/weather.sh conditions and a three-day outlook, cached on disk
```

### Cost

One layer-shell surface per monitor and two subprocesses, neither of them
recurring often.

`collect.sh` runs every 4s while the *island* is open and every 90s while it is
closed — the slow tick exists only to keep the failure dot honest. The media
pill deliberately does not count as open: everything in it is pushed from
PipeWire and MPRIS, so opening it costs nothing at all. Package-update counting
is confined to roughly every fifteenth slow tick and never runs while the panel
is open.

`weather.sh` is asked every five minutes and answers from its own cache; it
reaches the network at most once every fifteen. Every external probe is wrapped
in a timeout; `bluetoothctl` in particular blocks forever when `bluetoothd` is
not running.

### Screen space and input

The surface is as tall as the taller open panel but only reserves the closed
pills' height. Windows tile up under them, and a panel opens *over* them
instead of shoving them down. The input mask is the union of the two pills at
all times, so the rest of that tall transparent surface always passes clicks
through to whatever is underneath.

Panels also close on a workspace switch: leaving one hanging over another
workspace's windows is clutter, and its focus grab would keep swallowing input
over there until something else dismissed it.

Dismissal otherwise runs through `HyprlandFocusGrab`. While a panel is open
Hyprland routes input only to its window, so a click anywhere else clears the
grab and closes it — and the same grab is what gives the surface the keyboard,
which is why `Esc` works even when the panel was opened from a keybind rather
than a click.

## What install.sh changes

1. Copies `code/` to `~/.config/omarchy/plugins/island.bar/`
2. Sets `bar.id` in `~/.config/omarchy/shell.json`, after copying the original
   to `shell.json.pre-island` (written once, never overwritten)
3. Appends a marked blur rule for the `omarchy-island` layer namespace to
   `~/.config/hypr/looknfeel.lua`
4. Restarts the Omarchy shell

`uninstall.sh` reverses all four, and also clears the weather cache the card
writes at runtime (`~/.cache/omarchy-island/`). Nothing under
`/usr/share/omarchy` is touched.

## Notes

- **A full shell restart is required, not a plugin rescan.** `omarchy-shell
  shell rescanPlugins` re-reads the files but does not reliably re-bind a
  `kind: "bar"` plugin's injected properties, which leaves the island up with
  its data source unbound. Both scripts restart the shell for you.
- **Omarchy's own network / audio / bluetooth / weather panels go away with the
  stock bar.** They are `bar-widget` plugins, mounted by whichever bar is
  active, so a replacement bar cannot summon them. That is why the audio and
  weather views are built in here rather than delegated; network and bluetooth
  fall back to `nmtui` and `bluetoothctl` in a floating terminal.
- **Nerd Font glyphs are written as `\uXXXX` escapes**, never as literal
  characters. Private-use codepoints do not survive every editor and copy
  path, and a silently emptied string is invisible until the bar renders a
  blank button.
