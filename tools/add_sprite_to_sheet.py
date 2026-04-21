#!/usr/bin/env python3
"""Add a 16×16 sprite to the overworld atlas sheet.

Places a custom sprite PNG into an empty cell on overworld_sheet.png and
records the cell coordinates in resources/custom_sprite_cells.json.

Usage:
    python3 tools/add_sprite_to_sheet.py <source_png> <sprite_name>

Example:
    python3 tools/add_sprite_to_sheet.py assets/icons/items/fennel_root.png fennel_root
    # prints: [36, 29]

The tool is idempotent — re-running with the same sprite_name re-pastes
the source image into the previously assigned cell.
"""

import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required.  pip install Pillow", file=sys.stderr)
    sys.exit(1)

REPO = Path(__file__).resolve().parent.parent
SHEET_PATH = REPO / "assets" / "tiles" / "roguelike" / "overworld_sheet.png"
MANIFEST_PATH = REPO / "resources" / "custom_sprite_cells.json"
TILE_SIZE = 16
GUTTER = 1
STRIDE = TILE_SIZE + GUTTER  # 17
MAGENTA = (255, 0, 255)


def magenta_to_alpha(img: Image.Image) -> Image.Image:
    """Replace all #FF00FF pixels with full transparency."""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = pixels[x, y]
            if (r, g, b) == MAGENTA:
                pixels[x, y] = (0, 0, 0, 0)
    return img


def load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        with open(MANIFEST_PATH) as f:
            return json.load(f)
    return {"cells": {}}


def save_manifest(manifest: dict) -> None:
    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")


def find_empty_cell(sheet: Image.Image, cols: int, rows: int) -> tuple[int, int] | None:
    """Scan bottom-up, left-to-right for a fully-transparent 16×16 cell."""
    for r in range(rows - 1, -1, -1):
        for c in range(cols):
            x, y = c * STRIDE, r * STRIDE
            if x + TILE_SIZE > sheet.width or y + TILE_SIZE > sheet.height:
                continue
            tile = sheet.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))
            if all(p[3] == 0 for p in tile.getdata()):
                return (c, r)
    return None


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <source_png> <sprite_name>", file=sys.stderr)
        sys.exit(1)

    source_path = Path(sys.argv[1])
    sprite_name = sys.argv[2]

    if not source_path.exists():
        print(f"ERROR: source file not found: {source_path}", file=sys.stderr)
        sys.exit(1)

    # Load and validate source sprite; strip magenta background if present.
    sprite = magenta_to_alpha(Image.open(source_path))
    if sprite.size != (TILE_SIZE, TILE_SIZE):
        print(
            f"ERROR: sprite must be {TILE_SIZE}×{TILE_SIZE}, got {sprite.size[0]}×{sprite.size[1]}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Load sheet (must be RGBA)
    if not SHEET_PATH.exists():
        print(f"ERROR: sheet not found: {SHEET_PATH}", file=sys.stderr)
        sys.exit(1)
    sheet = Image.open(SHEET_PATH).convert("RGBA")
    cols = sheet.width // STRIDE
    rows = sheet.height // STRIDE

    manifest = load_manifest()

    # Helper: extract (col, row) from manifest entry (legacy or new format).
    def _cell_from_entry(entry):
        if isinstance(entry, dict):
            return tuple(entry["cell"])
        return tuple(entry)

    overworld_res = "res://assets/tiles/roguelike/overworld_sheet.png"

    # Check if already placed on THIS sheet (idempotent update)
    if sprite_name in manifest["cells"]:
        existing = manifest["cells"][sprite_name]
        existing_sheet = ""
        existing_cell = None
        if isinstance(existing, dict):
            existing_sheet = existing.get("sheet", "")
            existing_cell = existing.get("cell")
        elif isinstance(existing, list):
            existing_cell = existing
        # Re-paste into the same cell only if it was on the overworld sheet.
        if existing_cell and (existing_sheet == overworld_res or existing_sheet == ""):
            col, row = int(existing_cell[0]), int(existing_cell[1])
            px, py = col * STRIDE, row * STRIDE
            clear = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
            sheet.paste(clear, (px, py))
            sheet.paste(sprite, (px, py))
            sheet.save(SHEET_PATH)
            manifest["cells"][sprite_name] = {"cell": [col, row], "sheet": overworld_res}
            save_manifest(manifest)
            print(f"[{col}, {row}]")
            return

    # Find an empty cell
    cell = find_empty_cell(sheet, cols, rows)
    if cell is None:
        print("ERROR: no empty cells found on the sheet", file=sys.stderr)
        sys.exit(1)

    col, row = cell
    px, py = col * STRIDE, row * STRIDE
    sheet.paste(sprite, (px, py))
    sheet.save(SHEET_PATH)

    # Update manifest (new format)
    manifest["cells"][sprite_name] = {
        "cell": [col, row],
        "sheet": f"res://assets/tiles/roguelike/overworld_sheet.png",
    }
    save_manifest(manifest)

    print(f"[{col}, {row}]")


if __name__ == "__main__":
    main()
