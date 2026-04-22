"""Shared utilities for sprite processing tools."""

try:
    from PIL import Image
except ImportError:
    raise ImportError("Pillow is required.  pip install Pillow")

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
