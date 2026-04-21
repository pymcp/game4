#!/usr/bin/env bash
# sprite_tool.sh — launch the SpritePicker with proper Godot initialization.
# Mirrors run.sh: re-imports assets and refreshes the script class cache
# when needed, then opens the SpritePicker scene.

set -euo pipefail

cd "$(dirname "$0")"

GODOT_BIN="${GODOT:-godot}"
FORCE=0

for arg in "$@"; do
	case "$arg" in
		--force|-f) FORCE=1 ;;
		--help|-h)
			cat <<EOF
Usage: ./sprite_tool.sh [--force]

  --force, -f   Re-run import + class cache refresh even if up to date.
  --help,  -h   Show this message.

Environment:
  GODOT         Path to the Godot 4.3 binary (default: 'godot' on PATH).
EOF
			exit 0
			;;
	esac
done

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: '$GODOT_BIN' not found on PATH (set GODOT=/path/to/godot)" >&2
	exit 1
fi

# ── Step 1: import assets ─────────────────────────────────────────────
NEED_IMPORT=$FORCE
if (( ! NEED_IMPORT )); then
	if [[ ! -d .godot/imported ]]; then
		NEED_IMPORT=1
	elif [[ -n "$(find assets -type f \
			\( -name '*.png' -o -name '*.jpg' -o -name '*.ogg' \
			   -o -name '*.wav' -o -name '*.ttf' \) \
			-newer .godot/imported -print -quit 2>/dev/null)" ]]; then
		NEED_IMPORT=1
	fi
fi
if (( NEED_IMPORT )); then
	echo "[sprite_tool] importing assets..."
	"$GODOT_BIN" --headless --import --quit-after 60 --path . >/tmp/godot-import.log 2>&1 || true
fi

# ── Step 2: refresh global script class cache ─────────────────────────
NEED_CACHE=$FORCE
CACHE_FILE=.godot/global_script_class_cache.cfg
if (( ! NEED_CACHE )); then
	if [[ ! -f "$CACHE_FILE" ]]; then
		NEED_CACHE=1
	elif [[ -n "$(find scripts -type f -name '*.gd' \
			-newer "$CACHE_FILE" -print -quit 2>/dev/null)" ]]; then
		NEED_CACHE=1
	fi
fi
if (( NEED_CACHE )); then
	echo "[sprite_tool] refreshing script class cache..."
	"$GODOT_BIN" --headless --editor --quit-after 60 --path . \
		>/tmp/godot-scan.log 2>&1 || true
fi

# ── Step 3: launch SpritePicker ───────────────────────────────────────
echo "[sprite_tool] launching..."
exec "$GODOT_BIN" --path . res://scenes/tools/SpritePicker.tscn
