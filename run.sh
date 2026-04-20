#!/usr/bin/env bash
# run.sh — launch the game with proper Godot initialization.
#
# What "proper" means here:
#   1. Make sure the import cache is up to date (re-import any changed
#      assets), otherwise textures / shaders fail to load on first launch.
#   2. Make sure the global script class cache is current, otherwise
#      newly-added `class_name`-registered scripts can't be resolved by
#      type from sibling scripts.
#   3. Then launch the project itself.
#
# Steps 1 + 2 are skipped automatically when nothing has changed since the
# last run, so this stays cheap on a warm tree. Pass `--force` to redo
# both unconditionally.

set -euo pipefail

cd "$(dirname "$0")"

GODOT_BIN="${GODOT:-godot}"
FORCE=0
EXTRA_ARGS=()

for arg in "$@"; do
	case "$arg" in
		--force|-f) FORCE=1 ;;
		--help|-h)
			cat <<EOF
Usage: ./run.sh [--force] [-- <godot args>]

  --force, -f   Re-run import + class cache refresh even if up to date.
  --help,  -h   Show this message.

Environment:
  GODOT         Path to the Godot 4.3 binary (default: 'godot' on PATH).
EOF
			exit 0
			;;
		*) EXTRA_ARGS+=("$arg") ;;
	esac
done

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: '$GODOT_BIN' not found on PATH (set GODOT=/path/to/godot)" >&2
	exit 1
fi

# ── Step 1: import assets ─────────────────────────────────────────────
# `--import` walks the project, generates `.import` siblings + transcoded
# files under `.godot/imported/`, and exits. Only needed when assets have
# actually changed.
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
	echo "[run] importing assets..."
	"$GODOT_BIN" --headless --import --quit-after 60 --path . >/tmp/godot-import.log 2>&1 || true
fi

# ── Step 2: refresh global script class cache ─────────────────────────
# `class_name` registrations live in `.godot/global_script_class_cache.cfg`;
# the editor refreshes it on full project scan. We boot the editor headless
# just long enough for that scan to complete.
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
	echo "[run] refreshing script class cache..."
	"$GODOT_BIN" --headless --editor --quit-after 60 --path . \
		>/tmp/godot-scan.log 2>&1 || true
fi

# ── Step 3: launch the game ───────────────────────────────────────────
echo "[run] launching..."
exec "$GODOT_BIN" --path . "${EXTRA_ARGS[@]}"
