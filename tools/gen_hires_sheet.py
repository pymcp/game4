#!/usr/bin/env python3
"""gen_hires_sheet.py

Generates category-specific 64×64 hires spritesheets and patches the
corresponding game JSON files so the game immediately points at the new sheets.

Sheet layout:  8 columns × N rows, 64×64 px tiles, 1 px gutter.
  stride = 65 px
  sheet width = 8 * 65 - 1 = 519 px

Multi-tile creatures
--------------------
Add  "sprite_tiles": [2, 2]  to a creature entry in creature_sprites.json to
make it occupy a 2×2 block of cells (128+1=129 px square).  The region is
computed automatically.  Scale [0.25, 0.25] still applies (129×0.25≈32 px =
2 game tiles).

Categories
----------
  items     — resources/items.json entries (effective slot: none / "")
  weapons   — resources/items.json entries (effective slot: weapon)
  armor     — resources/items.json entries (effective slot: head/body/feet/off_hand)
  creatures — resources/creature_sprites.json entries WITHOUT is_pet flag
  pets      — resources/creature_sprites.json entries WITH is_pet: true

Re-run behaviour
----------------
Cell assignments are persisted in  assets/icons/hires/<category>_cells.json
(format: {entity_id: {"cell": [col, row], "size": [w, h]}}).
On re-run, new entities get fresh cells appended in row-major order while
existing assignments are kept stable.

To detect real art vs. stub: each category has a unique sentinel background
colour.  A cell that still has that colour in its top-left interior pixel is
considered a stub and is re-generated.  Any other colour means real art has
been pasted in → the pixels are copied unchanged from the existing PNG.

Game file patching (runs on every invocation)
---------------------------------------------
  items / weapons / armor  →  resources/items.json
                               hires_sheet = "<category>"
                               hires_cell  = [col, row]

  creatures                →  resources/creature_sprites.json
                               sheet        = "res://assets/icons/hires/creatures.png"
                               region       = computed from cell + sprite_tiles size
                               anchor_ratio = [0.5, 0.95]   (removes old "anchor" key)
                               scale        = preserved if set, else [0.25, 0.25]

Usage
-----
  python3 tools/gen_hires_sheet.py <category>
  python3 tools/gen_hires_sheet.py all

Requires: Pillow  (pip install Pillow)
"""

import json
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit("Pillow is required:  pip install Pillow")

# ── Paths ─────────────────────────────────────────────────────────────────────
REPO           = Path(__file__).resolve().parents[1]
HIRES_DIR      = REPO / "assets" / "icons" / "hires"
ITEMS_JSON     = REPO / "resources" / "items.json"
CREATURES_JSON = REPO / "resources" / "creature_sprites.json"

# ── Sheet geometry ────────────────────────────────────────────────────────────
TILE   = 64          # px per tile
MARGIN = 1           # px gutter between tiles
STRIDE = TILE + MARGIN  # = 65
COLS   = 8

# ── Stub sentinel colours (RGB) ───────────────────────────────────────────────
# Unique per category so stub detection works across category re-runs.
SENTINEL = {
    "items":     (45,  95,  55),   # forest green
    "weapons":   (100, 45,  45),   # dark crimson
    "armor":     (40,  65, 110),   # steel blue
    "creatures": (70,  30, 100),   # deep purple
    "pets":      (60, 100,  60),   # olive green
}

ARMOR_SLOTS = {"head", "body", "feet", "off_hand"}

# ── Slot resolution ───────────────────────────────────────────────────────────

def _resolve_slot(items, item_id, visited=None):
    """Walk the parent chain in items.json to find the effective slot."""
    if visited is None:
        visited = set()
    if item_id in visited:
        return "none"
    visited.add(item_id)
    data = items.get(item_id, {})
    if "slot" in data:
        return data["slot"]
    parent = data.get("parent", "")
    if parent:
        return _resolve_slot(items, parent, visited)
    return "none"

# ── Cell-assignment spec helpers ──────────────────────────────────────────────

def _load_cells(category):
    """Return {entity_id: {"cell": [col, row], "size": [w, h]}} from cells JSON.

    Automatically migrates the old flat [col, row] format.
    """
    path = HIRES_DIR / f"{category}_cells.json"
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    result = {}
    for k, v in raw.items():
        if isinstance(v, list):
            # Old flat format: [col, row] → migrate
            result[k] = {"cell": v, "size": [1, 1]}
        else:
            result[k] = v
    return result


def _save_cells(category, cells):
    path = HIRES_DIR / f"{category}_cells.json"
    path.write_text(
        json.dumps(cells, indent="\t", sort_keys=True) + "\n",
        encoding="utf-8",
    )

# ── Stub tile renderer ────────────────────────────────────────────────────────

def _make_stub(entity_id, sentinel, width_px=None, height_px=None):
    """Render a stub tile.  Defaults to TILE×TILE if no dimensions given."""
    if width_px is None:
        width_px = TILE
    if height_px is None:
        height_px = TILE
    bg_inner = tuple(min(255, int(c * 1.3)) for c in sentinel) + (255,)
    border   = tuple(max(0,   int(c * 0.55)) for c in sentinel) + (255,)

    img  = Image.new("RGBA", (width_px, height_px), (*sentinel, 255))
    draw = ImageDraw.Draw(img)
    draw.rectangle([2, 2, width_px - 3, height_px - 3], fill=bg_inner)
    draw.rectangle([0, 0, width_px - 1, height_px - 1], outline=border, width=2)

    # Font (fall back gracefully)
    font = None
    for fp in [
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, 10)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    # Wrap label at underscores
    words = entity_id.split("_")
    if len(words) <= 2:
        label = "\n".join(words)
    else:
        mid   = len(words) // 2
        label = "_".join(words[:mid]) + "\n" + "_".join(words[mid:])

    bbox = draw.textbbox((0, 0), label, font=font)
    tw   = bbox[2] - bbox[0]
    th   = bbox[3] - bbox[1]
    tx   = (width_px - tw) // 2
    ty   = (height_px - th) // 2 - bbox[1]

    draw.multiline_text((tx + 1, ty + 1), label, font=font,
                        fill=(0, 0, 0, 160), align="center")
    draw.multiline_text((tx, ty),           label, font=font,
                        fill=(240, 240, 240, 255), align="center")
    return img

# ── Stub detection ────────────────────────────────────────────────────────────

def _is_stub_cell(img, col, row, sentinel, tol=30):
    """
    Sample the interior pixel at (col*stride+4, row*stride+4).
    Returns True when the colour is within *tol* of the sentinel (= stub).
    """
    px = col * STRIDE + 4
    py = row * STRIDE + 4
    if px >= img.width or py >= img.height:
        return True   # cell doesn't exist in old PNG → treat as stub
    pixel = img.getpixel((px, py))
    r, g, b = pixel[:3]
    return all(abs(v - s) <= tol for v, s in zip((r, g, b), sentinel))

# ── Sheet builder ─────────────────────────────────────────────────────────────

def _build_sheet(entity_sizes, cells, sentinel, existing_img):
    """
    Build a new sheet PNG.

    *entity_sizes*: {id: [w, h]} — sprite tile dimensions (usually [1,1] or [2,2]).
    *cells*: {id: {"cell": [col, row], "size": [w, h]}} — updated in-place with
             new assignments for entities not already present.
    *existing_img*: previous PNG (None on first run) — used for real-art preservation.

    Returns the new Image.
    """
    # Build the set of all currently-occupied (col, row) slots.
    used = set()
    for info in cells.values():
        col, row = info["cell"]
        sw, sh = info["size"]
        for dc in range(sw):
            for dr in range(sh):
                used.add((col + dc, row + dr))

    # Assign cells for new entities in row-major order.
    for eid in sorted(entity_sizes.keys()):
        if eid in cells:
            continue
        size_w, size_h = entity_sizes[eid]
        for idx in range(10000):
            col = idx % COLS
            row = idx // COLS
            if col + size_w > COLS:
                continue   # block would overflow the right edge
            block = [(col + dc, row + dr) for dr in range(size_h) for dc in range(size_w)]
            if all(c not in used for c in block):
                cells[eid] = {"cell": [col, row], "size": [size_w, size_h]}
                used.update(block)
                break

    if not cells:
        return Image.new("RGBA", (STRIDE * COLS - MARGIN, TILE), (0, 0, 0, 0))

    # Sheet height = one row past the bottom-most occupied row.
    max_bottom = max(info["cell"][1] + info["size"][1] for info in cells.values())
    sheet_w = COLS * STRIDE - MARGIN
    sheet_h = max_bottom * STRIDE - MARGIN
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    for eid, info in cells.items():
        col, row = info["cell"]
        size_w, size_h = info["size"]
        px = col * STRIDE
        py = row * STRIDE
        stub_w = size_w * TILE + (size_w - 1) * MARGIN   # e.g. 2×64+1 = 129
        stub_h = size_h * TILE + (size_h - 1) * MARGIN

        # Copy real art from existing sheet if the top-left cell is not a stub.
        if existing_img is not None:
            ex_w, ex_h = existing_img.size
            if (px + stub_w <= ex_w) and (py + stub_h <= ex_h):
                if not _is_stub_cell(existing_img, col, row, sentinel):
                    region = existing_img.crop((px, py, px + stub_w, py + stub_h))
                    sheet.paste(region, (px, py))
                    continue

        # Stub (new entity, missing from old sheet, or sentinel colour detected).
        sheet.paste(_make_stub(eid, sentinel, stub_w, stub_h), (px, py))

    return sheet

# ── Category runners ──────────────────────────────────────────────────────────

def _run_item_category(category, slot_filter):
    """Build / refresh a sheet for an items.json-based category."""
    items = json.loads(ITEMS_JSON.read_text(encoding="utf-8"))
    entity_ids = sorted(
        eid for eid in items if slot_filter(_resolve_slot(items, eid))
    )
    entity_sizes = {eid: [1, 1] for eid in entity_ids}

    cells = _load_cells(category)
    png_path = HIRES_DIR / f"{category}.png"
    existing = Image.open(str(png_path)).convert("RGBA") if png_path.exists() else None

    sheet = _build_sheet(entity_sizes, cells, SENTINEL[category], existing)
    sheet.save(str(png_path))
    _save_cells(category, cells)

    # Patch items.json — write hires_sheet + hires_cell for each item.
    patched = 0
    for eid in entity_ids:
        if eid in items and eid in cells:
            items[eid]["hires_sheet"] = category
            items[eid]["hires_cell"]  = cells[eid]["cell"]
            patched += 1

    ITEMS_JSON.write_text(
        json.dumps(items, indent="\t", ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"  {category}.png  ({sheet.width}×{sheet.height} px)  "
          f"{len(entity_ids)} entities  |  patched {patched} in items.json")


def _run_creatures():
    """Build / refresh creatures.png and patch creature_sprites.json.

    Skips entries tagged ``is_pet: true`` — those belong on pets.png.
    """
    creatures  = json.loads(CREATURES_JSON.read_text(encoding="utf-8"))
    entity_ids = sorted(
        eid for eid in creatures if not creatures[eid].get("is_pet", False)
    )

    # Read sprite_tiles field from each entry (default [1,1]).
    entity_sizes = {
        eid: creatures[eid].get("sprite_tiles", [1, 1])
        for eid in entity_ids
    }

    cells = _load_cells("creatures")
    png_path = HIRES_DIR / "creatures.png"
    existing = Image.open(str(png_path)).convert("RGBA") if png_path.exists() else None

    sheet = _build_sheet(entity_sizes, cells, SENTINEL["creatures"], existing)
    sheet.save(str(png_path))
    _save_cells("creatures", cells)

    # Patch creature_sprites.json.
    patched = 0
    for eid in entity_ids:
        if eid not in cells:
            continue
        col, row   = cells[eid]["cell"]
        size_w, size_h = cells[eid]["size"]
        stub_w = size_w * TILE + (size_w - 1) * MARGIN
        stub_h = size_h * TILE + (size_h - 1) * MARGIN

        entry = creatures[eid]
        entry["sheet"]        = "res://assets/icons/hires/creatures.png"
        entry["region"]       = [col * STRIDE, row * STRIDE, stub_w, stub_h]
        entry["anchor_ratio"] = [0.5, 0.95]
        # Preserve explicit scale if already set; default 0.25 otherwise.
        if "scale" not in entry:
            entry["scale"] = [0.25, 0.25]
        # Remove old flat anchor key if present (anchor_ratio supersedes it).
        entry.pop("anchor", None)
        patched += 1

    CREATURES_JSON.write_text(
        json.dumps(creatures, indent="\t", ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"  creatures.png  ({sheet.width}×{sheet.height} px)  "
          f"{len(entity_ids)} entities  |  patched {patched} in creature_sprites.json")


def _run_pets():
    """Build / refresh pets.png and patch creature_sprites.json entries tagged is_pet."""
    creatures  = json.loads(CREATURES_JSON.read_text(encoding="utf-8"))
    entity_ids = sorted(
        eid for eid in creatures if creatures[eid].get("is_pet", False)
    )

    entity_sizes = {
        eid: creatures[eid].get("sprite_tiles", [1, 1])
        for eid in entity_ids
    }

    cells = _load_cells("pets")
    png_path = HIRES_DIR / "pets.png"
    existing = Image.open(str(png_path)).convert("RGBA") if png_path.exists() else None

    sheet = _build_sheet(entity_sizes, cells, SENTINEL["pets"], existing)
    sheet.save(str(png_path))
    _save_cells("pets", cells)

    # Patch creature_sprites.json — same field set as _run_creatures but pets.png.
    patched = 0
    for eid in entity_ids:
        if eid not in cells:
            continue
        col, row       = cells[eid]["cell"]
        size_w, size_h = cells[eid]["size"]
        stub_w = size_w * TILE + (size_w - 1) * MARGIN
        stub_h = size_h * TILE + (size_h - 1) * MARGIN

        entry = creatures[eid]
        entry["sheet"]        = "res://assets/icons/hires/pets.png"
        entry["region"]       = [col * STRIDE, row * STRIDE, stub_w, stub_h]
        entry["anchor_ratio"] = [0.5, 0.95]
        if "scale" not in entry:
            entry["scale"] = [0.25, 0.25]
        entry.pop("anchor", None)
        patched += 1

    CREATURES_JSON.write_text(
        json.dumps(creatures, indent="\t", ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"  pets.png  ({sheet.width}×{sheet.height} px)  "
          f"{len(entity_ids)} entities  |  patched {patched} in creature_sprites.json")

# ── Global _spec.json ─────────────────────────────────────────────────────────

def _ensure_global_spec():
    """Write (or correct) the directory-wide _spec.json read by HiresIconRegistry."""
    spec_path = HIRES_DIR / "_spec.json"
    target = '{ "tile_px": 64, "margin_px": 1 }\n'
    if not spec_path.exists() or spec_path.read_text(encoding="utf-8").strip() != target.strip():
        spec_path.write_text(target, encoding="utf-8")
        print("  updated _spec.json  (tile_px=64, margin_px=1)")

# ── Dispatch table ────────────────────────────────────────────────────────────

CATEGORIES = {
    "items":     lambda: _run_item_category(
                     "items",
                     lambda s: s not in ({"weapon"} | ARMOR_SLOTS)),
    "weapons":   lambda: _run_item_category(
                     "weapons",
                     lambda s: s == "weapon"),
    "armor":     lambda: _run_item_category(
                     "armor",
                     lambda s: s in ARMOR_SLOTS),
    "creatures": _run_creatures,
    "pets":      _run_pets,
}

# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2 or sys.argv[1] in {"-h", "--help"}:
        print(__doc__)
        print("Valid categories:", ", ".join(CATEGORIES))
        sys.exit(0)

    arg     = sys.argv[1].lower()
    targets = list(CATEGORIES) if arg == "all" else [arg]

    for cat in targets:
        if cat not in CATEGORIES:
            print(f"Unknown category '{cat}'.  Valid: {', '.join(CATEGORIES)}")
            sys.exit(1)

    HIRES_DIR.mkdir(parents=True, exist_ok=True)
    _ensure_global_spec()
    print()

    for cat in targets:
        CATEGORIES[cat]()

    print("\nDone.  Replace stub tiles with real art — the game JSON files are already patched.")


if __name__ == "__main__":
    main()
