#!/usr/bin/env bash
#
# Install the Dynamic Island as this system's Omarchy bar.
#
# Two things change, and both are reversible by uninstall.sh:
#
#   1. code/ is copied to ~/.config/omarchy/plugins/island.bar/
#   2. `bar.id` in ~/.config/omarchy/shell.json is pointed at island.bar
#
# The original shell.json is copied to shell.json.pre-island once, and never
# overwritten after that, so repeated installs cannot lose the true original.
# Nothing under /usr/share/omarchy is touched.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="island.bar"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
PLUGIN_DIR="$CONFIG_DIR/plugins/$PLUGIN_ID"
SHELL_JSON="$CONFIG_DIR/shell.json"
BACKUP="$CONFIG_DIR/shell.json.pre-island"

say() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

printf '\nDynamic Island for Omarchy\n\n'

# ------------------------------------------------------------------ preflight
[ -d "$SOURCE_DIR/code" ] || die "code/ not found next to this script"
[ -f "$SOURCE_DIR/code/manifest.json" ] || die "code/manifest.json missing"
command -v python3 >/dev/null || die "python3 is required"
command -v omarchy >/dev/null || die "this does not look like an Omarchy system"

mkdir -p "$CONFIG_DIR/plugins"

# The shell falls back to the packaged defaults when the user has no file yet.
# Materialise it first so there is always something to edit and restore.
if [ ! -f "$SHELL_JSON" ]; then
  DEFAULTS="${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json"
  [ -f "$DEFAULTS" ] || die "no shell.json and no packaged default at $DEFAULTS"
  cp "$DEFAULTS" "$SHELL_JSON"
  say "created $SHELL_JSON from Omarchy defaults"
fi

# ------------------------------------------------------------------- backup
# Written once. A second install must not capture an already-islanded config
# as the "original" to restore to.
if [ ! -f "$BACKUP" ]; then
  cp "$SHELL_JSON" "$BACKUP"
  say "backed up shell.json -> $(basename "$BACKUP")"
else
  say "keeping existing backup $(basename "$BACKUP")"
fi

# ------------------------------------------------------------------- plugin
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR"
cp -r "$SOURCE_DIR/code/." "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/scripts/collect.sh"
say "installed plugin -> $PLUGIN_DIR"

# --------------------------------------------------------------- shell.json
python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, sys

path, plugin_id = sys.argv[1], sys.argv[2]
with open(path) as handle:
    config = json.load(handle)

bar = config.get("bar")
if not isinstance(bar, dict):
    bar = {}
# `id` is how the shell picks a `kind: "bar"` plugin over the built-in bar.
# Everything else in the bar subtree (position, layout, transparency) is left
# untouched so uninstall can simply drop this key.
bar["id"] = plugin_id
config["bar"] = bar

with open(path, "w") as handle:
    json.dump(config, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
say "set bar.id = $PLUGIN_ID in shell.json"

# -------------------------------------------------------------------- blur
# The island is translucent; without a blur rule for its layer namespace it
# reads as a hole in the screen rather than as frosted glass. Written between
# markers so uninstall.sh can lift exactly this block back out.
LOOKNFEEL="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/looknfeel.lua"
if [ -f "$LOOKNFEEL" ]; then
  if grep -q 'dynamic-island-omarchy' "$LOOKNFEEL"; then
    say "blur rule already present in looknfeel.lua"
  else
    cat >> "$LOOKNFEEL" <<'RULE'

-- >>> dynamic-island-omarchy >>>
-- ignore_alpha keeps the blur off the fully transparent parts of the island's
-- layer surface, which spans the whole screen width.
hl.layer_rule({ match = { namespace = "^omarchy-island$" }, blur = true, ignore_alpha = 0.05 })
-- <<< dynamic-island-omarchy <<<
RULE
    say "added blur rule to looknfeel.lua"
  fi
  hyprctl reload >/dev/null 2>&1 || true
else
  say "no looknfeel.lua found; skipping the blur rule"
fi

# ------------------------------------------------------------------- reload
# A full restart, not `rescanPlugins`. Hot-reload re-reads a plugin's files but
# does not reliably re-instantiate a `kind: "bar"` plugin's injected
# properties, which leaves the island up with its data source unbound.
if omarchy restart shell >/dev/null 2>&1; then
  say "restarted the Omarchy shell"
else
  say "could not restart the shell; run: omarchy restart shell"
fi

cat <<'EOF'

Done.

  Click the clock to open the island. Esc, the ✕, a click outside, or a
  workspace switch closes it.

  In the footer, the speaker and microphone buttons take a left click to mute,
  a right click for the device picker, and a scroll for volume.

  It can also be driven without the pointer, which is worth a keybind:
      omarchy-shell island toggle
      omarchy-shell island open
      omarchy-shell island close
      omarchy-shell island audio

  To go back to the stock Omarchy bar:
      ./uninstall.sh

EOF
