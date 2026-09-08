#!/usr/bin/env bash
#
# One JSON blob describing the machine, for the Dynamic Island bar plugin.
#
# Everything here is read-only and cheap: /proc, a couple of sysfs files, one
# `systemctl show`, one `ss`, and short-circuited `wpctl` / `nmcli` /
# `bluetoothctl` calls. Nothing is started, nothing is installed. The island
# runs this on a timer only while it is open, plus one slow tick while closed
# so the collapsed pill can show a failure dot.
#
#   --updates   also count pending package updates. Left off by default: it is
#               the one probe here that syncs a temp pacman db and touches the
#               network, so the island asks for it on a slow tick, not on the
#               refresh that runs while the panel is open.
#   $@          optional extra systemd unit names to watch, on top of the list.

set -uo pipefail
export LC_ALL=C

WANT_UPDATES=0
if [ "${1:-}" = "--updates" ]; then
  WANT_UPDATES=1
  shift
fi

# Every external probe goes through this. A hung helper must never hold the
# panel open on a spinner: `bluetoothctl` in particular blocks forever when
# bluetoothd is not running, which is the default on a desktop with no adapter.
run() {
  local limit="$1"; shift
  timeout -k 1 "$limit" "$@" 2>/dev/null
}

# Candidates in display order. Units that are not installed are dropped, so
# this list can stay generous without cluttering the panel.
UNITS=(
  postgresql "PostgreSQL"
  mariadb    "MariaDB"
  mysqld     "MySQL"
  mongodb    "MongoDB"
  redis      "Redis"
  valkey     "Valkey"
  memcached  "Memcached"
  clickhouse-server "ClickHouse"
  rabbitmq   "RabbitMQ"
  elasticsearch "Elasticsearch"
  minio      "MinIO"
  docker     "Docker"
  containerd "containerd"
  podman     "Podman"
  libvirtd   "libvirt"
  nginx      "nginx"
  httpd      "Apache"
  caddy      "Caddy"
  ollama     "Ollama"
  sshd       "SSH"
  tailscaled "Tailscale"
  bluetooth  "Bluetooth"
  NetworkManager "NetworkManager"
)

for extra in "$@"; do
  UNITS+=("$extra" "$extra")
done

names=()
for ((i = 0; i < ${#UNITS[@]}; i += 2)); do names+=("${UNITS[$i]}.service"); done

states="$(systemctl show --property=Id --property=LoadState --property=ActiveState \
            --property=SubState -- "${names[@]}" 2>/dev/null)"
ports="$(ss -H -tlnp 2>/dev/null)"

# ---------------------------------------------------------------- hardware
meminfo="$(cat /proc/meminfo 2>/dev/null)"
stat1="$(grep -m1 '^cpu ' /proc/stat 2>/dev/null)"
# A 120ms window is long enough for a stable percentage and short enough that
# the panel still feels instant when it opens.
sleep 0.12
stat2="$(grep -m1 '^cpu ' /proc/stat 2>/dev/null)"
loadavg="$(cat /proc/loadavg 2>/dev/null)"
uptime_s="$(cut -d' ' -f1 /proc/uptime 2>/dev/null)"
diskline="$(df -B1 --output=size,used,target / 2>/dev/null | tail -1)"

temp=""
for zone in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$zone" ] || continue
  type_file="${zone%/temp}/type"
  zone_type="$(cat "$type_file" 2>/dev/null)"
  case "$zone_type" in
    *x86_pkg_temp*|*acpitz*|*cpu*|*k10temp*|*coretemp*) temp="$(cat "$zone" 2>/dev/null)"; break ;;
  esac
done
[ -z "$temp" ] && temp="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"

# Battery and backlight are absent on desktops; both stay null there.
bat_pct=""; bat_state=""
for supply in /sys/class/power_supply/BAT*; do
  [ -d "$supply" ] || continue
  bat_pct="$(cat "$supply/capacity" 2>/dev/null)"
  bat_state="$(cat "$supply/status" 2>/dev/null)"
  break
done

bright=""; bright_max=""
for bl in /sys/class/backlight/*; do
  [ -d "$bl" ] || continue
  bright="$(cat "$bl/brightness" 2>/dev/null)"
  bright_max="$(cat "$bl/max_brightness" 2>/dev/null)"
  break
done

# ---------------------------------------------------------------- services
audio="$(run 2 wpctl get-volume @DEFAULT_AUDIO_SINK@)"
audio_src="$(run 2 wpctl get-volume @DEFAULT_AUDIO_SOURCE@)"
sink_name="$(run 2 wpctl inspect @DEFAULT_AUDIO_SINK@ | sed -n 's/.*node.description = "\(.*\)".*/\1/p' | head -1)"
source_name="$(run 2 wpctl inspect @DEFAULT_AUDIO_SOURCE@ | sed -n 's/.*node.description = "\(.*\)".*/\1/p' | head -1)"
# The device list comes from `wpctl status` rather than pactl: its ids are the
# WirePlumber ids that `wpctl set-default` takes, and it has already filtered
# out monitor sources, which are never something you want to pick as a mic.
wp_status="$(run 3 wpctl status)"

net="$(run 3 nmcli -t -f NAME,TYPE,DEVICE connection show --active)"
wifi="$(run 3 nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --rescan no | grep '^\*' | head -1)"
ipaddr="$(run 2 ip -4 -o addr show scope global | awk '{print $2" "$4}' | head -2)"

# Guarded twice over: no adapter in sysfs means bluetoothd has nothing to talk
# to, and even with an adapter the CLI can sit waiting on a dead daemon.
bt_power=""; bt_devices=""
if compgen -G "/sys/class/bluetooth/*" >/dev/null 2>&1; then
  bt_power="$(run 2 bluetoothctl show | sed -n 's/.*Powered: \(.*\)/\1/p' | head -1)"
  bt_devices="$(run 2 bluetoothctl devices Connected | sed 's/^Device [^ ]* //')"
fi

updates=""
if [ "$WANT_UPDATES" = "1" ] && command -v checkupdates >/dev/null 2>&1; then
  updates="$(run 20 checkupdates | wc -l)"
fi

kbd="$(run 2 hyprctl -j devices | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit
for k in d.get("keyboards", []):
    if k.get("main"):
        print(k.get("active_keymap",""))
        break
' 2>/dev/null)"

python3 - "$states" "$ports" "$meminfo" "$stat1" "$stat2" "$loadavg" "$uptime_s" \
          "$diskline" "$temp" "$bat_pct" "$bat_state" "$bright" "$bright_max" \
          "$audio" "$audio_src" "$sink_name" "$source_name" "$wp_status" \
          "$net" "$wifi" "$ipaddr" \
          "$bt_power" "$bt_devices" "$updates" "$kbd" "${UNITS[@]}" <<'PY'
import json, re, sys

(raw_states, raw_ports, raw_mem, stat1, stat2, loadavg, uptime_s, diskline,
 temp, bat_pct, bat_state, bright, bright_max, audio, audio_src, sink_name,
 source_name, wp_status, net, wifi, ipaddr, bt_power, bt_devices, updates,
 kbd) = sys.argv[1:26]
pairs = sys.argv[26:]

labels = {pairs[i]: pairs[i + 1] for i in range(0, len(pairs) - 1, 2)}
order = [pairs[i] for i in range(0, len(pairs) - 1, 2)]

out = {}

# ------------------------------------------------------------- systemd units
units = {}
for block in raw_states.split("\n\n"):
    fields = {}
    for line in block.splitlines():
        key, _, value = line.partition("=")
        fields[key] = value
    unit_id = fields.get("Id", "")
    if unit_id.endswith(".service"):
        units[unit_id[: -len(".service")]] = fields

services = []
for name in order:
    fields = units.get(name)
    if not fields or fields.get("LoadState") in (None, "", "not-found", "masked"):
        continue
    active = fields.get("ActiveState", "")
    sub = fields.get("SubState", "")
    if active == "active":
        state = "up"
    elif active == "failed" or sub == "failed":
        state = "failed"
    elif active == "activating":
        state = "starting"
    else:
        state = "down"
    services.append({"name": name, "label": labels.get(name, name),
                     "state": state, "detail": sub})
out["services"] = services

# ------------------------------------------------------------ listening ports
PROC = re.compile(r'\("([^"]+)",pid=(\d+)')
LOCAL_ONLY = ("127.", "[::1]", "::1")
seen, port_rows = set(), []
for line in raw_ports.splitlines():
    cols = line.split(None, 5)
    if len(cols) < 4:
        continue
    addr, _, port = cols[3].rpartition(":")
    if not port.isdigit():
        continue
    match = PROC.search(cols[5]) if len(cols) > 5 else None
    proc = match.group(1) if match else ""
    key = (port, proc)
    if key in seen:
        continue
    seen.add(key)
    port_rows.append({
        "port": int(port), "addr": addr, "proc": proc,
        "exposed": not addr.startswith(LOCAL_ONLY),
    })
port_rows.sort(key=lambda entry: entry["port"])
out["ports"] = port_rows

# --------------------------------------------------------------------- memory
mem = {}
for line in raw_mem.splitlines():
    key, _, value = line.partition(":")
    digits = value.strip().split(" ")[0]
    if digits.isdigit():
        mem[key] = int(digits) * 1024
total = mem.get("MemTotal", 0)
available = mem.get("MemAvailable", 0)
swap_total = mem.get("SwapTotal", 0)
swap_free = mem.get("SwapFree", 0)
out["memory"] = {
    "total": total,
    "used": total - available,
    "percent": round((total - available) / total * 100, 1) if total else 0,
}
out["swap"] = {
    "total": swap_total,
    "used": swap_total - swap_free,
    "percent": round((swap_total - swap_free) / swap_total * 100, 1) if swap_total else 0,
}

# ------------------------------------------------------------------------ cpu
def cpu_fields(line):
    parts = line.split()[1:]
    return [int(p) for p in parts if p.isdigit()]

cpu_percent = 0.0
try:
    a, b = cpu_fields(stat1), cpu_fields(stat2)
    if a and b:
        idle_a, idle_b = a[3] + (a[4] if len(a) > 4 else 0), b[3] + (b[4] if len(b) > 4 else 0)
        total_a, total_b = sum(a), sum(b)
        dt, di = total_b - total_a, idle_b - idle_a
        if dt > 0:
            cpu_percent = round((dt - di) / dt * 100, 1)
except Exception:
    pass
out["cpu"] = {"percent": cpu_percent, "load": loadavg.split()[:3] if loadavg else []}

try:
    out["uptime"] = int(float(uptime_s))
except Exception:
    out["uptime"] = 0

# ----------------------------------------------------------------------- disk
disk = {}
parts = diskline.split()
if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
    size, used = int(parts[0]), int(parts[1])
    disk = {"total": size, "used": used, "mount": parts[2],
            "percent": round(used / size * 100, 1) if size else 0}
out["disk"] = disk

out["temp"] = round(int(temp) / 1000.0, 1) if temp.strip().isdigit() else None

# -------------------------------------------------------- battery / backlight
out["battery"] = ({"percent": int(bat_pct), "state": bat_state}
                  if bat_pct.strip().isdigit() else None)
out["brightness"] = (round(int(bright) / int(bright_max) * 100)
                     if bright.strip().isdigit() and bright_max.strip().isdigit()
                     and int(bright_max) > 0 else None)

# ---------------------------------------------------------------------- audio
def parse_volume(raw):
    # `wpctl get-volume` prints e.g. "Volume: 0.65 [MUTED]".
    match = re.search(r'([0-9]*\.?[0-9]+)', raw)
    if not match:
        return None
    return {"percent": round(float(match.group(1)) * 100),
            "muted": "MUTED" in raw}

def parse_devices(text):
    """Pull the Sinks and Sources tables out of `wpctl status`.

    Rows look like:  │  *   59. USB Audio Device Analog Stereo   [vol: 1.00 MUTED]
    The leading box-drawing characters vary with terminal width, so the row
    regex anchors on the id rather than on the tree glyphs.
    """
    row = re.compile(r"(\*)?\s*(\d+)\.\s+(.*?)\s*\[vol:\s*([\d.]+)([^\]]*)\]")
    sinks, sources, section = [], [], None
    for line in text.splitlines():
        stripped = line.strip("\u2502\u251c\u2514\u2500 \t")
        if stripped.startswith("Sinks:"):
            section = sinks; continue
        if stripped.startswith("Sources:"):
            section = sources; continue
        # Any other heading ends the current table.
        if stripped.endswith(":") and not stripped[:1].isdigit():
            section = None; continue
        if section is None:
            continue
        match = row.search(line)
        if not match:
            continue
        section.append({
            "id": int(match.group(2)),
            "name": match.group(3).strip(),
            "percent": round(float(match.group(4)) * 100),
            "muted": "MUTED" in match.group(5),
            "default": match.group(1) == "*",
        })
    return sinks, sources

sinks, sources = parse_devices(wp_status)
out["audio"] = {"sink": parse_volume(audio), "source": parse_volume(audio_src),
                "sinkName": sink_name, "sourceName": source_name,
                "sinks": sinks, "sources": sources}

# -------------------------------------------------------------------- network
connections = []
for line in net.splitlines():
    fields = line.split(":")
    if len(fields) >= 3 and fields[1] != "loopback":
        connections.append({"name": fields[0], "type": fields[1], "device": fields[2]})
wifi_row = None
if wifi:
    fields = wifi.split(":")
    if len(fields) >= 3:
        wifi_row = {"ssid": fields[1], "signal": int(fields[2]) if fields[2].isdigit() else 0}
addresses = []
for line in ipaddr.splitlines():
    fields = line.split()
    if len(fields) == 2:
        addresses.append({"iface": fields[0], "addr": fields[1]})
out["network"] = {"connections": connections, "wifi": wifi_row, "addresses": addresses}

# ------------------------------------------------------------------ bluetooth
out["bluetooth"] = {
    "powered": bt_power.strip() == "yes",
    "devices": [d for d in bt_devices.splitlines() if d.strip()],
}

out["updates"] = int(updates) if updates.strip().isdigit() else None
out["keyboardLayout"] = kbd.strip()

# --------------------------------------------------------------------- agents
# Omarchy's agent plugin already refreshes these snapshots on its own schedule;
# the island only reads whatever is on disk, so it never triggers a fetch or
# needs the agent plugin to be enabled.
import glob, os
agents = []
usage_dir = os.path.expanduser(
    os.environ.get("XDG_STATE_HOME", "~/.local/state") + "/omarchy/agents/usage")
for path in sorted(glob.glob(usage_dir + "/*.json")):
    try:
        with open(path) as handle:
            record = json.load(handle)
    except Exception:
        continue
    limits = []
    for limit in record.get("limits") or []:
        try:
            limits.append({"label": str(limit.get("label", "")),
                           "percent": float(limit.get("percent") or 0)})
        except Exception:
            continue
    agents.append({
        "id": record.get("id", ""),
        "name": record.get("name", record.get("id", "")),
        "ready": bool(record.get("ready")),
        "limits": limits,
        "todayPrompts": record.get("todayPrompts") or 0,
        "activeDays": record.get("activeDays") or 0,
        "statusText": record.get("usageStatusText") or "",
    })
out["agents"] = agents

json.dump(out, sys.stdout)
PY
