#!/usr/bin/env bash
#
# Current conditions and a three-day outlook, as one small JSON object.
#
# This is the only probe in the plugin that leaves the machine, so it is also
# the only one that caches. A reading is kept for fifteen minutes and served
# straight off disk until it expires; the island may therefore ask as often as
# it likes without ever becoming a load on wttr.in.
#
#   --force   fetch even if the cached reading is still fresh.
#
# The location comes from Omarchy's own weather setting
# (~/.local/state/omarchy/settings/weather.json, owned by
# omarchy-weather-location), so `omarchy-weather-location --set …` moves this
# card too. With nothing configured, wttr.in resolves the location from the
# outbound IP address.
#
# Output is always a JSON object on stdout. `ok` is false when there is
# nothing to show — the caller keeps whatever it had rather than blanking.

set -uo pipefail
export LC_ALL=C

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/settings"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-island"
MAX_AGE=900

fail() { printf '{"ok":false}\n'; exit 0; }

command -v curl >/dev/null 2>&1 || fail
command -v python3 >/dev/null 2>&1 || fail

# The stored location is coordinates when the picker wrote them and a bare
# name when the file was hand-edited; either is a valid wttr.in path segment.
# Anything unreadable means auto-detect, which is the empty segment.
QUERY="$(python3 - "$STATE_DIR/weather.json" <<'PY' 2>/dev/null
import json, sys
from urllib.parse import quote

try:
    with open(sys.argv[1]) as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit

if not isinstance(data, dict):
    raise SystemExit

try:
    latitude = float(data.get("latitude"))
    longitude = float(data.get("longitude"))
    print("%s,%s" % (latitude, longitude))
    raise SystemExit
except (TypeError, ValueError):
    pass

name = str(data.get("name") or "").strip()
if name:
    print(quote(name))
PY
)"

mkdir -p "$CACHE_DIR" 2>/dev/null || fail

# One cache file per location, so changing the location cannot serve the old
# city's numbers from a file that merely looks fresh.
KEY="$(printf '%s' "$QUERY" | md5sum | cut -c1-12)"
CACHE="$CACHE_DIR/weather-$KEY.json"

if [ "$FORCE" = "0" ] && [ -f "$CACHE" ]; then
  MTIME="$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)"
  if [ $(( $(date +%s) - MTIME )) -lt "$MAX_AGE" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

# Abandoned locations, swept on the way past. A cache file nobody has asked
# for in a day is a city the user has moved away from.
find "$CACHE_DIR" -maxdepth 1 -name 'weather-*.json' -mtime +1 -delete 2>/dev/null

RAW="$(curl -fsS --max-time 10 -H 'Accept-Language: en' \
        "https://wttr.in/${QUERY}?format=j1" 2>/dev/null)"

if [ -z "$RAW" ]; then
  # Offline, or wttr.in is having a day. A stale reading beats an empty card.
  [ -f "$CACHE" ] && { cat "$CACHE"; exit 0; }
  fail
fi

DISTILLED="$(python3 - "$RAW" <<'PY' 2>/dev/null
import json, sys, time


def number(value, default=None):
    try:
        return int(round(float(str(value).strip())))
    except (TypeError, ValueError):
        return default


def clock_minutes(value):
    """'06:08 AM' -> minutes since midnight, or None."""
    text = str(value or "").strip().upper()
    parts = text.replace("AM", "").replace("PM", "").strip().split(":")
    if len(parts) != 2:
        return None
    hours, minutes = number(parts[0]), number(parts[1])
    if hours is None or minutes is None:
        return None
    if "PM" in text and hours != 12:
        hours += 12
    if "AM" in text and hours == 12:
        hours = 0
    return hours * 60 + minutes


try:
    report = json.loads(sys.argv[1])
    current = report["current_condition"][0]
except Exception:
    raise SystemExit(1)

area = (report.get("nearest_area") or [{}])[0]


def area_value(key):
    entries = area.get(key) or []
    return str(entries[0].get("value", "")) if entries else ""


days = []
for day in (report.get("weather") or [])[:3]:
    # A whole day gets one glyph, and the middle of the day is the one worth
    # showing: a forecast row that says "rain" because of a 3am shower is
    # technically right and useless.
    hourly = day.get("hourly") or [{}]
    days.append({
        "date": str(day.get("date", "")),
        "code": number(hourly[len(hourly) // 2].get("weatherCode"), 119),
        "maxC": number(day.get("maxtempC")),
        "minC": number(day.get("mintempC")),
        "maxF": number(day.get("maxtempF")),
        "minF": number(day.get("mintempF")),
    })

# wttr.in reports no day/night flag, so it is derived from today's astronomy
# and the clock — the difference between a sun glyph and a moon glyph.
astronomy = ((report.get("weather") or [{}])[0].get("astronomy") or [{}])[0]
sunrise = clock_minutes(astronomy.get("sunrise"))
sunset = clock_minutes(astronomy.get("sunset"))
local = time.localtime()
minutes = local.tm_hour * 60 + local.tm_min
is_day = True if sunrise is None or sunset is None else sunrise <= minutes < sunset

description = (current.get("weatherDesc") or [{}])[0].get("value", "")

json.dump({
    "ok": True,
    "updated": int(time.time()),
    "location": area_value("areaName"),
    "region": area_value("region"),
    "country": area_value("country"),
    "code": number(current.get("weatherCode"), 119),
    "desc": " ".join(str(description).split()),
    "isDay": is_day,
    "tempC": number(current.get("temp_C"), 0),
    "tempF": number(current.get("temp_F"), 0),
    "feelsC": number(current.get("FeelsLikeC"), 0),
    "feelsF": number(current.get("FeelsLikeF"), 0),
    "humidity": number(current.get("humidity"), 0),
    "windKmph": number(current.get("windspeedKmph"), 0),
    "windMph": number(current.get("windspeedMiles"), 0),
    "windDir": str(current.get("winddir16Point", "")),
    "uv": number(current.get("uvIndex"), 0),
    "sunrise": str(astronomy.get("sunrise", "")),
    "sunset": str(astronomy.get("sunset", "")),
    "days": days,
}, sys.stdout)
PY
)"

if [ -z "$DISTILLED" ]; then
  [ -f "$CACHE" ] && { cat "$CACHE"; exit 0; }
  fail
fi

# Written through a temporary file so a reader can never catch a half-written
# cache — the island parses whatever it gets and would drop a truncated blob.
TMP="$CACHE.$$"
printf '%s' "$DISTILLED" > "$TMP" 2>/dev/null && mv -f "$TMP" "$CACHE" 2>/dev/null
rm -f "$TMP" 2>/dev/null

printf '%s' "$DISTILLED"
