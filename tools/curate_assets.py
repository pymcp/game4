#!/usr/bin/env python3
"""Asset curation: copy needed Kenney sprites/audio/fonts from kenney_raw/ into assets/.

Top-down pivot version. Sources:
 - Roguelike Base Pack (overworld terrain, props)
 - Roguelike City Pack (city map tiles)
 - Roguelike Dungeon Pack (dungeon tiles)
 - Roguelike Interior Pack (house furniture)
 - Roguelike Characters Pack (players, NPCs, monsters)
 - Rune Pack (overlay runes)
 - UI Pack - Pixel Adventure (HUD/menu skin)

All Kenney roguelike sheets: 16x16 tiles with 1-px separator (no outer margin).

Run from repo root:
    python3 tools/curate_assets.py

Idempotent. Safe to re-run.
"""
import os
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RAW = REPO / "kenney_raw"
OUT = REPO / "assets"


def cp(src_rel: str, dst_rel: str) -> None:
    src = RAW / src_rel
    dst = OUT / dst_rel
    if not src.exists():
        print(f"  MISSING: {src_rel}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        for root, _, files in os.walk(src):
            for f in files:
                if f.lower().endswith((".png", ".ogg", ".ttf", ".otf", ".wav")):
                    rel = Path(root).relative_to(src) / f
                    target = dst / rel
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if not target.exists() or target.stat().st_size != (Path(root) / f).stat().st_size:
                        shutil.copy2(Path(root) / f, target)
    else:
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dst)


def main() -> None:
    print(f"Curating Kenney assets: {RAW} -> {OUT}")

    # --- Fonts ---
    print("Fonts...")
    for fnt in ("Kenney Pixel.ttf", "Kenney High.ttf", "Kenney Mini.ttf", "Kenney Bold.ttf"):
        cp(f"Other/Fonts/{fnt}", f"fonts/{fnt}")

    # --- Tile sheets (16x16, 1-px separator). Use the *_transparent.png variants. ---
    print("Tile sheet: Roguelike Base (overworld)...")
    cp("2D assets/Roguelike Base Pack/Spritesheet/roguelikeSheet_transparent.png",
       "tiles/roguelike/overworld_sheet.png")

    print("Tile sheet: Roguelike City...")
    # Roguelike City Pack uses 'tilemap.png' (with 1-px separator) at 628x475.
    cp("2D assets/Roguelike City Pack/Tilemap/tilemap.png",
       "tiles/roguelike/city_sheet.png")

    print("Tile sheet: Roguelike Dungeon...")
    cp("2D assets/Roguelike Dungeon Pack/Spritesheet/roguelikeDungeon_transparent.png",
       "tiles/roguelike/dungeon_sheet.png")

    print("Tile sheet: Roguelike Interior (house furniture)...")
    cp("2D assets/Roguelike Interior Pack/Tilesheets/roguelikeIndoor_transparent.png",
       "tiles/roguelike/interior_sheet.png")

    # --- Characters (players + NPCs + monsters from one sheet) ---
    print("Characters: Roguelike Characters Pack...")
    cp("2D assets/Roguelike Characters Pack/Spritesheet/roguelikeChar_transparent.png",
       "characters/roguelike/characters_sheet.png")

    # --- Runes (overlay layer) ---
    # Use the Black "tile" variant (16x16-ish stone slabs).
    print("Runes: Black tiles...")
    cp("2D assets/Rune Pack/Spritesheet/Black/runeBlack_tile_sheet.png",
       "tiles/runes/runes_black_tile.png")
    cp("2D assets/Rune Pack/Spritesheet/Grey/runeGrey_tile_sheet.png",
       "tiles/runes/runes_grey_tile.png")
    cp("2D assets/Rune Pack/Spritesheet/Blue/runeBlue_tile_sheet.png",
       "tiles/runes/runes_blue_tile.png")

    # --- UI (Pixel Adventure) ---
    print("UI: Pixel Adventure (small + large, both outline weights)...")
    cp("UI assets/UI Pack - Pixel Adventure/Tilesheets/Small tiles/Thin outline/tilemap.png",
       "ui/pixel_adventure/small_thin.png")
    cp("UI assets/UI Pack - Pixel Adventure/Tilesheets/Small tiles/Thick outline/tilemap.png",
       "ui/pixel_adventure/small_thick.png")
    cp("UI assets/UI Pack - Pixel Adventure/Tilesheets/Large tiles/Thin outline/tilemap.png",
       "ui/pixel_adventure/large_thin.png")
    cp("UI assets/UI Pack - Pixel Adventure/Tilesheets/Large tiles/Thick outline/tilemap.png",
       "ui/pixel_adventure/large_thick.png")
    # Also bring in the per-piece individual tile PNGs for fine-grained 9-slice.
    cp("UI assets/UI Pack - Pixel Adventure/Tiles", "ui/pixel_adventure/tiles")

    # --- Particles (mining VFX) ---
    print("Particles...")
    cp("2D assets/Particle Pack/PNG (Transparent)", "particles/pack")
    cp("2D assets/Smoke Particles/PNG", "particles/smoke")

    # --- Audio (kept from previous build) ---
    print("Audio: footsteps + impacts...")
    cp("Audio/Impact Sounds/Audio", "audio/impact")
    cp("Audio/RPG Audio/Audio", "audio/rpg")
    cp("Audio/Interface Sounds/Audio", "audio/interface")

    # --- Icons (resource icons for inventory) ---
    print("Icons: generic colored items (resources/potions)...")
    cp("2D assets/Generic Items/PNG/Colored", "icons/generic_items")

    print("Done.")


if __name__ == "__main__":
    main()
