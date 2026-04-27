#!/usr/bin/env python3
"""seed_hires_icons.py

Generate 64x64 px placeholder PNG icons for every item in resources/items.json
and write them to assets/icons/hires/<id>.png.

Each placeholder shows the item's short ID as text on a colored background.
Colors are chosen by slot category so weapon/armor/resource items are visually
distinct even before real art is added.

Run from the repo root:
    python3 tools/seed_hires_icons.py

Requires: Pillow  (pip install Pillow)
"""

import json
import os
import re

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit("Pillow is required: pip install Pillow")

# ── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_JSON = os.path.join(REPO_ROOT, "resources", "items.json")
OUT_DIR = os.path.join(REPO_ROOT, "assets", "icons", "hires")

ICON_SIZE = 64  # px

# ── Category colour palette ───────────────────────────────────────────────────
# (R, G, B) background colours keyed on item slot or keyword in the ID.
SLOT_COLORS = {
    "weapon": (160,  55,  55),
    "tool":   (140,  90,  50),
    "head":   ( 55,  90, 160),
    "body":   ( 50, 120, 160),
    "feet":   ( 70, 160, 140),
    "off_hand": (100, 100, 180),
}
DEFAULT_COLOR = (70, 130,  80)   # green-ish for resources/misc

KEYWORD_COLORS = {
    "sword": SLOT_COLORS["weapon"],
    "axe":   SLOT_COLORS["weapon"],
    "bow":   SLOT_COLORS["weapon"],
    "staff": SLOT_COLORS["weapon"],
    "dagger": SLOT_COLORS["weapon"],
    "spear": SLOT_COLORS["weapon"],
    "arrow": SLOT_COLORS["weapon"],
    "hammer": SLOT_COLORS["tool"],
    "pickaxe": SLOT_COLORS["tool"],
    "helmet": SLOT_COLORS["head"],
    "armor":  SLOT_COLORS["body"],
    "shield": SLOT_COLORS["off_hand"],
    "boots":  SLOT_COLORS["feet"],
    "ore":    (120, 100,  60),
    "wood":   (120,  85,  50),
    "stone":  (110, 110, 110),
    "fiber":  ( 80, 150,  80),
    "herb":   ( 80, 160,  90),
    "gold":   (200, 170,  40),
}


def _bg_color(item_id: str, slot: str) -> tuple:
    slot_norm = slot.lower().replace("_", "")
    if slot_norm in SLOT_COLORS:
        return SLOT_COLORS[slot_norm]
    for kw, col in KEYWORD_COLORS.items():
        if kw in item_id.lower():
            return col
    return DEFAULT_COLOR


def _label_for(item_id: str) -> str:
    """Shorten ID to at most 2 lines of ≤8 chars each for the placeholder."""
    words = item_id.replace("_", " ").split()
    if len(words) == 1:
        w = words[0]
        return w[:8] if len(w) <= 8 else w[:7] + "…"
    # Try to fit two words on two lines.
    line1 = words[0][:8]
    line2 = (" ".join(words[1:]))[:8]
    return f"{line1}\n{line2}"


def make_placeholder(item_id: str, slot: str) -> Image.Image:
    bg = _bg_color(item_id, slot)
    img = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (*bg, 255))
    draw = ImageDraw.Draw(img)

    # Border
    border_color = tuple(max(0, c - 40) for c in bg) + (255,)
    draw.rectangle([0, 0, ICON_SIZE - 1, ICON_SIZE - 1],
                   outline=border_color, width=3)

    # Label — use default font (no external font needed)
    label = _label_for(item_id)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 12)
    except Exception:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (ICON_SIZE - tw) // 2
    ty = (ICON_SIZE - th) // 2
    # Shadow
    draw.multiline_text((tx + 1, ty + 1), label, font=font,
                        fill=(0, 0, 0, 180), align="center")
    # Text
    draw.multiline_text((tx, ty), label, font=font,
                        fill=(240, 240, 240, 255), align="center")
    return img


def main() -> None:
    with open(ITEMS_JSON, "r", encoding="utf-8") as f:
        items = json.load(f)

    os.makedirs(OUT_DIR, exist_ok=True)

    created = 0
    skipped = 0
    for item_id, data in sorted(items.items()):
        out_path = os.path.join(OUT_DIR, f"{item_id}.png")
        if os.path.exists(out_path):
            skipped += 1
            continue
        slot = data.get("slot", "none")
        # Resolve parent slot if needed (skip base_ entries that have no slot).
        if slot == "none" and "parent" in data:
            parent = items.get(data["parent"], {})
            slot = parent.get("slot", "none")
        img = make_placeholder(item_id, slot)
        img.save(out_path)
        created += 1
        print(f"  created {item_id}.png")

    print(f"\nDone — {created} created, {skipped} already existed.")
    print(f"Output: {OUT_DIR}")


if __name__ == "__main__":
    main()
