#!/usr/bin/env bash
#
# Put the stock Omarchy bar back.
#
# Restores ~/.config/omarchy/shell.json from the copy install.sh made, and
# removes the plugin directory. If that backup is gone, it falls back to just
# dropping `bar.id`, which is the only key the installer added — so the bar
# returns either way.

set -euo pipefail

PLUGIN_ID="island.bar"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
PLUGIN_DIR="$CONFIG_DIR/plugins/$PLUGIN_ID"
SHELL_JSON="$CONFIG_DIR/shell.json"
BACKUP="$CONFIG_DIR/shell.json.pre-island"

say() { printf '  %s\n' "$*"; }

printf '\nRemoving the Dynamic Island\n\n'

# --------------------------------------------------------------- shell.json
if [ -f "$BACKUP" ]; then
  # Keep whatever the island-era file was, in case the user edited other bar
  # settings while it was installed and wants them back.
  if [ -f "$SHELL_JSON" ]; then
    cp "$SHELL_JSON" "$CONFIG_DIR/shell.json.island-last"
  fi
  mv "$BACKUP" "$SHELL_JSON"
  say "restored shell.json from backup"
  say "the island-era file is kept as shell.json.island-last"
elif [ -f "$SHELL_JSON" ]; then
  python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, sys

path, plugin_id = sys.argv[1], sys.argv[2]
with open(path) as handle:
    config = json.load(handle)

bar = config.get("bar")
# Only clear the key if it still points at us; a different custom bar selected
# since installing is not ours to remove.
if isinstance(bar, dict) and bar.get("id") == plugin_id:
    bar.pop("id", None)
    config["bar"] = bar

with open(path, "w") as handle:
    json.dump(config, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
  say "no backup found; cleared bar.id instead"
else
  say "no shell.json to clean up"
fi

# ------------------------------------------------------------------- plugin
if [ -d "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  say "removed $PLUGIN_DIR"
else
  say "plugin directory already gone"
fi

# --------------------------------------------------------------------- blur
# Lift out exactly the marked block install.sh appended, leaving any other
# layer rules in the file untouched.
LOOKNFEEL="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/looknfeel.lua"
if [ -f "$LOOKNFEEL" ] && grep -q 'dynamic-island-omarchy' "$LOOKNFEEL"; then
  python3 - "$LOOKNFEEL" <<'PY'
import re, sys

path = sys.argv[1]
text = open(path).read()
# Also swallow the blank line the installer left before the block.
cleaned = re.sub(
    r"\n*^-- >>> dynamic-island-omarchy >>>$.*?^-- <<< dynamic-island-omarchy <<<$\n?",
    "\n",
    text,
    flags=re.S | re.M,
)
open(path, "w").write(cleaned)
PY
  say "removed the blur rule from looknfeel.lua"
  hyprctl reload >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------- reload
if omarchy restart shell >/dev/null 2>&1; then
  say "restarted the Omarchy shell"
else
  say "could not restart the shell; run: omarchy restart shell"
fi

cat <<'EOF'

Done — the stock Omarchy bar is back.

  If it has not reappeared:
      omarchy restart shell

EOF
