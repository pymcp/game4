#!/usr/bin/env python3
"""process_sprite.py — Convert a Gemini-generated sprite into a game-ready icon.

Takes a PNG with #FF00FF magenta background, converts magenta to transparency,
crops to content, and resizes/pads to 16×16 using nearest-neighbour interpolation.

Usage:
    python3 tools/process_sprite.py <input_png> <item_id>

Output:
    assets/icons/items/<item_id>.png  (16×16 RGBA)
"""
import sys
import os

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required.  pip install Pillow", file=sys.stderr)
    sys.exit(1)

from sprite_utils import magenta_to_alpha

TARGET_SIZE = 16
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "items")


def crop_to_content(img: Image.Image) -> Image.Image:
    """Crop to the bounding box of non-transparent pixels."""
    bbox = img.getbbox()
    if bbox is None:
        return img
    return img.crop(bbox)


def fit_to_target(img: Image.Image, size: int) -> Image.Image:
    """Resize the largest dimension to `size`, then centre-pad to size×size.

    Uses NEAREST resampling to preserve pixel-art crispness.
    """
    w, h = img.size
    if w == 0 or h == 0:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    scale = size / max(w, h)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    resized = img.resize((new_w, new_h), Image.NEAREST)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y))
    return canvas


def process(input_path: str, item_id: str) -> str:
    """Full pipeline: load → magenta→alpha → crop → fit → save."""
    if not os.path.isfile(input_path):
        print(f"ERROR: input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(input_path)
    img = magenta_to_alpha(img)
    img = crop_to_content(img)
    img = fit_to_target(img, TARGET_SIZE)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"{item_id}.png")
    img.save(out_path, "PNG")
    return out_path


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_png> <item_id>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    item_id = sys.argv[2]

    out = process(input_path, item_id)
    print(f"OK — saved {out}  ({TARGET_SIZE}×{TARGET_SIZE} RGBA)")


if __name__ == "__main__":
    main()
