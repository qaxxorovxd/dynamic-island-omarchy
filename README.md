# Dynamic Island for Omarchy

A macOS-style Dynamic Island in place of the Omarchy status bar.

Closed, it is a rounded pill at the top centre of every screen showing the
time and nothing else. Click it and it grows — one continuous animation, the
clock riding from dead centre to the top-left corner — into a panel carrying
everything the stock bar used to spread across the screen: date, media,
agents, services, listening ports, system meters, network, audio, bluetooth,
workspaces and the tray.

```
  closed                          open
  ┌──────────┐                    ┌──────────────────────────────────────┐
  │  01:01   │        →           │ 01:01  Wednesday, 9 September 2026 ✕ │
  └──────────┘                    │ ┌────────┐┌────────┐┌──────────────┐ │
                                  │ │ Media  ││Calendar││   Agents     │ │
                                  │ └────────┘└────────┘└──────────────┘ │
                                  │ ┌────────┐┌────────┐┌──────────────┐ │
                                  │ │ System ││Services││    Ports     │ │
                                  │ └────────┘└────────┘└──────────────┘ │
                                  │ 1 2 3            tray  󰖩 󰕾 󰂯 ⏻      │
                                  └──────────────────────────────────────┘
```

## Install

```bash
./install.sh
```

Then click the clock. `Esc`, the ✕, a click anywhere outside, or switching
workspace closes it.

To remove it and get the stock bar back exactly as it was:

```bash
./uninstall.sh
```

## Without the pointer

The island exposes an IPC target, which is worth binding to a key in
`~/.config/hypr/bindings.lua`:

```bash
omarchy-shell island toggle
omarchy-shell island open
omarchy-shell island close
omarchy-shell island audio   # opens straight onto the device picker
```

All of these act on the focused monitor.

## What it shows

| Card | Contents |
|---|---|
| **Media** | Cover art, track, artist, and transport, straight off MPRIS |
| **Calendar** | Month grid, Monday-first, today marked, ISO week in the corner |
| **Agents** | Coding-agent quotas, read from Omarchy's own usage snapshots |
| **System** | CPU, memory, disk meters plus load, swap, temperature, uptime, battery and backlight where present. Click opens `btop` |
| **Services** | Watched systemd units, failures sorted first |
| **Ports** | Listening TCP ports, with anything bound past loopback flagged |
| **Header** | Clock, full date, ISO week, uptime, keyboard layout, pending updates, menu, close |
| **Footer** | This monitor's workspaces, the system tray, and network / speaker / microphone / bluetooth / power |

### Audio

The speaker and microphone buttons each do three things:

| | |
|---|---|
| left click | mute / unmute that device |
| right click | open the device picker |
| scroll | volume, in 5% steps |

The picker is a sheet over the cards, listing outputs and inputs side by side
with the active one marked. Inside it, clicking a row makes that device the
default, the glyph on the right mutes just that device, and scrolling a row
sets that device's volume — all on the row's own device, not on whatever
happens to be default. Ids come from `wpctl status`, which is also what
`wpctl set-default` takes.

The closed pill stays deliberately mute. The only thing it will ever add to
the time is a small dot, when a watched service has actually failed.

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
  IslandPanel.qml    one layer-shell surface per monitor
  Island.qml         the pill→panel animation and the clock that survives it
  IslandBody.qml     header, card grid, footer
  Card.qml           shared tile chrome
  Meter.qml          the one meter shape the System card reuses
  IconButton.qml     small glyph button
  ToolTipBubble.qml  in-surface tooltip
  *Card.qml          the six tiles
  AudioPicker.qml    output/input device sheet
  DeviceColumn.qml   one side of it: select, mute, scroll per device
  Data.qml           clock, MPRIS, and the collector's output
  scripts/collect.sh one JSON blob: units, ports, cpu, memory, disk, net, …
```

### Cost

One layer-shell surface per monitor and one subprocess. `collect.sh` runs
every 4s while the panel is open and every 90s while it is closed — the slow
tick exists only to keep the failure dot honest. Package-update counting is
the one probe that touches the network, so it is confined to roughly every
fifteenth slow tick and never runs while the panel is open. Every external
probe is wrapped in a timeout; `bluetoothctl` in particular blocks forever
when `bluetoothd` is not running.

### Screen space and input

The surface is as tall as the open panel but only reserves the closed pill's
height. Windows tile up under the pill, and the panel opens *over* them
instead of shoving them down. The input mask is clipped to the island itself
at all times, so the rest of that tall transparent surface always passes
clicks through to whatever is underneath.

The panel also closes on a workspace switch: leaving it hanging over another
workspace's windows is clutter, and its focus grab would keep swallowing input
over there until something else dismissed it.

Dismissal otherwise runs through `HyprlandFocusGrab`. While the panel is open Hyprland
routes input only to its window, so a click anywhere else clears the grab and
closes it — and the same grab is what gives the surface the keyboard, which is
why `Esc` works even when the panel was opened from a keybind rather than a
click.

## What install.sh changes

1. Copies `code/` to `~/.config/omarchy/plugins/island.bar/`
2. Sets `bar.id` in `~/.config/omarchy/shell.json`, after copying the original
   to `shell.json.pre-island` (written once, never overwritten)
3. Appends a marked blur rule for the `omarchy-island` layer namespace to
   `~/.config/hypr/looknfeel.lua`
4. Restarts the Omarchy shell

`uninstall.sh` reverses all four. Nothing under `/usr/share/omarchy` is
touched.

## Notes

- **A full shell restart is required, not a plugin rescan.** `omarchy-shell
  shell rescanPlugins` re-reads the files but does not reliably re-bind a
  `kind: "bar"` plugin's injected properties, which leaves the island up with
  its data source unbound. Both scripts restart the shell for you.
- **Omarchy's own network / audio / bluetooth panels go away with the stock
  bar.** They are `bar-widget` plugins, mounted by whichever bar is active, so
  a replacement bar cannot summon them. That is why the audio picker is built
  in here rather than delegated; network and bluetooth fall back to `nmtui`
  and `bluetoothctl` in a floating terminal.
- **Nerd Font glyphs are written as `\uXXXX` escapes**, never as literal
  characters. Private-use codepoints do not survive every editor and copy
  path, and a silently emptied string is invisible until the bar renders a
  blank button.
