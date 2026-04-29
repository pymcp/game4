#!/usr/bin/env python3
"""gen_terrain_transitions.py

Generates the terrain-transition tile sheet used for seamless blending
between biome terrain types (secondary blobs + biome borders).

Each row = one terrain pair (e.g. grass+dirt).
Each row has 13 tiles:

  Index  Name        Shape
  -----------------------------------------------------------------------
    0    nw_outer    Mostly primary, secondary rounds into NW corner
    1    n_edge      Primary on bottom half, secondary on top
    2    ne_outer    Mostly primary, secondary rounds into NE corner
    3    w_edge      Primary on right half, secondary on left
    4    center      All secondary (plain fill)
    5    e_edge      Primary on left half, secondary on right
    6    sw_outer    Mostly primary, secondary rounds into SW corner
    7    s_edge      Primary on top half, secondary on bottom
    8    se_outer    Mostly primary, secondary rounds into SE corner
    9    inner_nw  * Mostly secondary, primary rounds into NW corner  [NEW]
   10    inner_ne  * Mostly secondary, primary rounds into NE corner  [NEW]
   11    inner_sw  * Mostly secondary, primary rounds into SW corner  [NEW]
   12    inner_se  * Mostly secondary, primary rounds into SE corner  [NEW]

Tiles 0-8 are drawn with PIL as opaque approximations of the intended blend.
Tiles 9-12 (*) are brand-new shapes; they also get PIL approximations but
have a magenta sentinel pixel at (1, 1) so stub detection can find them.

Outputs
-------
  assets/tiles/roguelike/terrain_transitions_sheet.png   <- game sheet
  tmp/terrain_transitions_reference.png                  <- 4x scaled + labels
  resources/tilesets/terrain_transitions_cells.json      <- atlas coord map

Usage
-----
  python3 tools/gen_terrain_transitions.py

Requires: Pillow  (pip install Pillow)
"""

import json
import os
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit("Pillow is required:  pip install Pillow")

# -- Paths -----------------------------------------------------------------
REPO      = Path(__file__).resolve().parents[1]
OUT_SHEET = REPO / "assets" / "tiles" / "roguelike" / "terrain_transitions_sheet.png"
OUT_REF   = REPO / "tmp" / "terrain_transitions_reference.png"
OUT_JSON  = REPO / "resources" / "tilesets" / "terrain_transitions_cells.json"

# -- Sheet geometry (must match overworld_sheet.png: 16px tiles, 1px gutter)
TILE   = 16
MARGIN = 1
STRIDE = TILE + MARGIN   # = 17

COLS = 13  # tiles per row

# -- Tile index -> name (order is canonical; engine will reference by index) -
TILE_NAMES = [
    "nw_outer", "n_edge",   "ne_outer",
    "w_edge",   "center",   "e_edge",
    "sw_outer", "s_edge",   "se_outer",
    "inner_nw", "inner_ne", "inner_sw", "inner_se",
]
assert len(TILE_NAMES) == COLS

# Indices 9-12 are the new inner corners that need final pixel art.
NEW_TILE_INDICES = {9, 10, 11, 12}

# Magenta sentinel placed at pixel (1,1) of each inner-corner tile so
# stub detection can distinguish placeholders from finished art.
STUB_SENTINEL_RGB = (255, 0, 255)

# -- Terrain pairs ---------------------------------------------------------
# (primary_name, secondary_name, primary_rgb, secondary_rgb, pair_key)
# Colors are close approximations of the actual Kenney sheet pixels.
PAIRS = [
    # Within-biome secondary blobs
    # TerrainCodes: GRASS/SNOW/SWAMP=3/6/7 all map to "grass" tile.
    # ROCK=5 maps to "stone". DIRT=4 maps to "dirt". SAND=2 maps to "sand".
    ("grass",  "dirt",  ( 87, 135,  50), (138,  90,  50), "grass_dirt"),   # row 0 - grass biome
    ("sand",   "dirt",  (200, 170,  90), (138,  90,  50), "sand_dirt"),    # row 1 - desert biome
    ("stone",  "dirt",  (120, 115, 110), (138,  90,  50), "stone_dirt"),   # row 2 - rocky biome
    # Snow biome: primary=SNOW(6)->"grass", secondary=ROCK(5)->"stone".
    # Transition key is "grass_stone" — also covers grass-meets-rocky border.
    ("grass",  "stone", ( 87, 135,  50), (120, 115, 110), "grass_stone"),  # row 3 - snow secondary + grass/rocky border
    # Swamp biome: primary=SWAMP(7)->"grass", secondary=WATER(1).
    # Water secondary is handled by the existing water-border system.
    # Clay+water row kept for future upgrade of that system.
    ("clay",   "water", (175, 110,  75), ( 55,  95, 160), "clay_water"),   # row 4 - swamp (future)
    # Cross-biome bleed: grass biome region bordering desert region
    ("grass",  "sand",  ( 87, 135,  50), (200, 170,  90), "grass_sand"),   # row 5 - grass/desert border
]
ROWS = len(PAIRS)

# Quarter-circle radius.  At 16px, R=10 fills ~40% of a tile edge.
R = 10


# -- Tile drawing ----------------------------------------------------------

def _rgba(rgb):
    return (*rgb, 255)

def _darken(rgb, f=0.6):
    return tuple(max(0, int(c * f)) for c in rgb)

def _stamp_stub(img):
    """Mark pixel (1,1) magenta so unfinished tiles are easy to spot."""
    img.putpixel((1, 1), (*STUB_SENTINEL_RGB, 255))


def draw_tile(index, primary_rgb, secondary_rgb):
    """
    Render one 16x16 RGBA tile.

    primary   = terrain on the OUTSIDE of the blob (background for outer tiles)
    secondary = terrain on the INSIDE of the blob  (background for inner tiles)
    """
    T   = TILE
    pri = _rgba(primary_rgb)
    sec = _rgba(secondary_rgb)

    # Background: primary for outer shapes (0-3, 5-8), secondary for inner/center
    bg_rgb = secondary_rgb if (index == 4 or index >= 9) else primary_rgb
    img  = Image.new("RGBA", (T, T), _rgba(bg_rgb))
    draw = ImageDraw.Draw(img)

    if index == 0:    # NW outer: primary bg, secondary quarter in NW
        draw.ellipse((-R, -R, R, R), fill=sec)
    elif index == 1:  # N edge: secondary top half
        draw.rectangle((0, 0, T - 1, T // 2 - 1), fill=sec)
    elif index == 2:  # NE outer: secondary quarter in NE
        draw.ellipse((T - 1 - R, -R, T - 1 + R, R), fill=sec)
    elif index == 3:  # W edge: secondary left half
        draw.rectangle((0, 0, T // 2 - 1, T - 1), fill=sec)
    elif index == 4:  # center: all secondary (already the bg)
        pass
    elif index == 5:  # E edge: secondary right half
        draw.rectangle((T // 2, 0, T - 1, T - 1), fill=sec)
    elif index == 6:  # SW outer: secondary quarter in SW
        draw.ellipse((-R, T - 1 - R, R, T - 1 + R), fill=sec)
    elif index == 7:  # S edge: secondary bottom half
        draw.rectangle((0, T // 2, T - 1, T - 1), fill=sec)
    elif index == 8:  # SE outer: secondary quarter in SE
        draw.ellipse((T - 1 - R, T - 1 - R, T - 1 + R, T - 1 + R), fill=sec)
    elif index == 9:  # * NW inner: secondary bg, primary quarter in NW
        draw.ellipse((-R, -R, R, R), fill=pri)
        _stamp_stub(img)
    elif index == 10: # * NE inner: secondary bg, primary quarter in NE
        draw.ellipse((T - 1 - R, -R, T - 1 + R, R), fill=pri)
        _stamp_stub(img)
    elif index == 11: # * SW inner: secondary bg, primary quarter in SW
        draw.ellipse((-R, T - 1 - R, R, T - 1 + R), fill=pri)
        _stamp_stub(img)
    elif index == 12: # * SE inner: secondary bg, primary quarter in SE
        draw.ellipse((T - 1 - R, T - 1 - R, T - 1 + R, T - 1 + R), fill=pri)
        _stamp_stub(img)

    # Subtle 1px border so tile boundaries are visible in an image editor
    draw = ImageDraw.Draw(img)
    border_base = secondary_rgb if index >= 4 else primary_rgb
    border = _darken(border_base, 0.55)
    draw.rectangle((0, 0, T - 1, T - 1), outline=(*border, 200))

    return img


# -- Sheet assembly --------------------------------------------------------

def make_sheet():
    W = COLS * STRIDE - MARGIN
    H = ROWS * STRIDE - MARGIN
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for row, (_pn, _sn, pc, sc, _key) in enumerate(PAIRS):
        for col in range(COLS):
            tile = draw_tile(col, pc, sc)
            sheet.paste(tile, (col * STRIDE, row * STRIDE))
    return sheet


def make_reference(sheet):
    """4x scaled sheet with row labels and column indices for artist use."""
    SCALE   = 4
    LABEL_W = 90
    HEAD_H  = 22

    sw = sheet.width  * SCALE
    sh = sheet.height * SCALE
    ref = Image.new("RGBA", (LABEL_W + sw, HEAD_H + sh), (30, 30, 30, 255))

    ref.paste(sheet.resize((sw, sh), Image.NEAREST), (LABEL_W, HEAD_H))
    draw = ImageDraw.Draw(ref)

    font = None
    for fp in [
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, 9)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    WHITE = (255, 255, 255, 255)
    GRAY  = (160, 160, 160, 255)
    GOLD  = (255, 210,  60, 255)

    # Column headers
    for col in range(COLS):
        x = LABEL_W + col * STRIDE * SCALE + 1
        label = str(col) if col < 9 else f"*{col}"
        color = GOLD if col in NEW_TILE_INDICES else GRAY
        draw.text((x, 3), label, font=font, fill=color)

    # Row labels with color swatches
    for row, (pname, sname, pc, sc, _key) in enumerate(PAIRS):
        y = HEAD_H + row * STRIDE * SCALE + 2
        draw.rectangle(( 2, y,  7, y + 5), fill=_rgba(pc))
        draw.rectangle(( 9, y, 14, y + 5), fill=_rgba(sc))
        draw.text((17, y     ), pname,          font=font, fill=WHITE)
        draw.text((17, y + 10), "+ " + sname,   font=font, fill=GRAY)

    # Gold vertical divider before inner-corner section
    div_x = LABEL_W + 9 * STRIDE * SCALE - 1
    draw.line((div_x, 0, div_x, ref.height), fill=GOLD, width=1)
    draw.text((div_x + 2, 3), "* new inner corners", font=font, fill=GOLD)

    return ref


# -- Atlas JSON ------------------------------------------------------------

def make_cells_json():
    out = {}
    for row, (_pn, _sn, _pc, _sc, key) in enumerate(PAIRS):
        pair_dict = {}
        for col, name in enumerate(TILE_NAMES):
            pair_dict[name] = {
                "cell": [col, row],
                "is_stub": col in NEW_TILE_INDICES,
            }
        out[key] = pair_dict
    return out


# -- Entry point -----------------------------------------------------------

def main():
    print("Generating terrain transition tile sheet...")

    sheet = make_sheet()

    OUT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_SHEET, optimize=False)
    print(f"  Game sheet  -> {OUT_SHEET.relative_to(REPO)}")

    OUT_REF.parent.mkdir(parents=True, exist_ok=True)
    ref = make_reference(sheet)
    ref.save(OUT_REF, optimize=False)
    print(f"  Reference   -> {OUT_REF.relative_to(REPO)}")

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    cells = make_cells_json()
    OUT_JSON.write_text(
        json.dumps(cells, indent="\t", sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"  Atlas JSON  -> {OUT_JSON.relative_to(REPO)}")

    total   = ROWS * COLS
    new_cnt = ROWS * len(NEW_TILE_INDICES)
    print(f"\n  {total} tiles  ({ROWS} pairs x {COLS} per row)")
    print(f"  {total - new_cnt} PIL-approximated opaque blends")
    print(f"  {new_cnt} new inner corners (* magenta sentinel at px 1,1)")


if __name__ == "__main__":
    main()
