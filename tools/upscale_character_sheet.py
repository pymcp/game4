#!/usr/bin/env python3
"""Upscale the 16x16 character sheet to 64x64 (4x nearest-neighbor).

Reads  assets/characters/roguelike/characters_sheet.png
Writes assets/characters/hires/characters_sheet.png
       assets/characters/hires/_spec.json

The output sheet mirrors the original layout (54 cols x 12 rows) but at
64px tiles with 1px gutters (65px stride).  Weapon cells (rows that are
2 tiles tall, 16x33) become 64x129.

This produces placeholder art — upscaled pixels — which can be
incrementally replaced with proper AI-generated 64x64 pixel art.
"""

import json
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required.  pip install Pillow", file=sys.stderr)
    sys.exit(1)

# ── constants ──────────────────────────────────────────────────────
SRC_TILE = 16
SRC_MARGIN = 1
SRC_STRIDE = SRC_TILE + SRC_MARGIN  # 17

DST_TILE = 64
DST_MARGIN = 1
DST_STRIDE = DST_TILE + DST_MARGIN  # 65

SCALE = DST_TILE // SRC_TILE  # 4

COLS = 54
ROWS = 12

REPO = Path(__file__).resolve().parent.parent
SRC_PATH = REPO / "assets" / "characters" / "roguelike" / "characters_sheet.png"
DST_DIR = REPO / "assets" / "characters" / "hires"
DST_PATH = DST_DIR / "characters_sheet.png"
SPEC_PATH = DST_DIR / "_spec.json"


def upscale_cell(src: Image.Image, col: int, row: int,
                 height_tiles: int = 1) -> Image.Image:
    """Extract one cell from the source sheet and upscale it 4x."""
    x = col * SRC_STRIDE
    y = row * SRC_STRIDE
    w = SRC_TILE
    h = SRC_TILE * height_tiles + SRC_MARGIN * (height_tiles - 1)
    cell = src.crop((x, y, x + w, y + h))
    return cell.resize((w * SCALE, h * SCALE), Image.NEAREST)


def main() -> None:
    if not SRC_PATH.exists():
        print(f"ERROR: source sheet not found: {SRC_PATH}", file=sys.stderr)
        sys.exit(1)

    src = Image.open(SRC_PATH).convert("RGBA")
    print(f"Source: {src.size[0]}x{src.size[1]}  ({COLS} cols x {ROWS} rows, "
          f"{SRC_TILE}px tiles, {SRC_MARGIN}px margin)")

    # Destination dimensions.
    dst_w = COLS * DST_STRIDE - DST_MARGIN  # last col has no trailing margin
    dst_h = ROWS * DST_STRIDE - DST_MARGIN
    dst = Image.new("RGBA", (dst_w, dst_h), (0, 0, 0, 0))

    for row in range(ROWS):
        for col in range(COLS):
            cell = upscale_cell(src, col, row, 1)
            dx = col * DST_STRIDE
            dy = row * DST_STRIDE
            dst.paste(cell, (dx, dy))

    print(f"Destination: {dst.size[0]}x{dst.size[1]}  ({COLS} cols x {ROWS} rows, "
          f"{DST_TILE}px tiles, {DST_MARGIN}px margin)")

    DST_DIR.mkdir(parents=True, exist_ok=True)
    dst.save(str(DST_PATH))
    print(f"Wrote: {DST_PATH}")

    spec = {"tile_px": DST_TILE, "margin_px": DST_MARGIN}
    SPEC_PATH.write_text(json.dumps(spec, indent=2) + "\n")
    print(f"Wrote: {SPEC_PATH}")


if __name__ == "__main__":
    main()
