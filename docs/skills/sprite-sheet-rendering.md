# Sprite Sheet Rendering Convention

Use when adding any code that:
- Loads a PNG spritesheet and builds a `Sprite2D` or `AtlasTexture` from it
- Computes `region_rect` from a `(col, row)` cell coordinate
- Needs a sprite to render at the correct world size (1 tile = 16 game px)

---

## The Two Key Formulas

### 1. Cell origin (always use `stride`, never `tile_px`)

```gdscript
var spec: SheetSpec = SheetSpecReader.read(sheet_path)

sprite.region_rect = Rect2(
    float(cell.x * spec.stride),   # ← stride = tile_px + margin_px
    float(cell.y * spec.stride),
    float(spec.tile_px),           # ← size is tile_px (not stride)
    float(spec.tile_px))
```

`stride = tile_px + margin_px`. For a 1px-guttered Kenney sheet (16px tiles): stride=17. For a hires sheet (64px tiles, 1px gutter): stride=65.

**Do NOT use `tile_px` for the origin.** Only the region *size* uses `tile_px`. The origin must skip the gutter.

### 2. Scale (always apply `scale_factor()` when != 1.0)

```gdscript
var sf: float = spec.scale_factor()   # = WorldConst.TILE_PX / tile_px
if sf != 1.0:
    sprite.scale = Vector2(sf, sf)
```

`scale_factor()` converts the sprite's source pixels to game-space pixels. A 64px hires tile needs scale 0.25 so it occupies 16 game px. The World node is then zoomed 4× for display, giving 64 screen px — exactly one tile.

**If you skip this**, a 64px hires sprite renders at 256 screen px (4× too large).

---

## Reading `_spec.json`

Every sheet directory can contain a `_spec.json` sidecar:

```json
{ "tile_px": 64, "margin_px": 1 }
```

Both keys are optional. Defaults: `tile_px=16, margin_px=1` (matching classic Kenney sheets).

```gdscript
var spec: SheetSpec = SheetSpecReader.read("res://assets/icons/hires/items.png")
# spec.tile_px  = 64
# spec.margin_px = 1
# spec.stride   = 65
# spec.scale_factor() = 0.25
```

`SheetSpecReader.read()` looks for `_spec.json` in the same directory as the PNG. If absent, returns defaults.

---

## Complete Reference Implementation

Copy this pattern exactly. From `scripts/entities/character_builder.gd`:

```gdscript
static func _make_sprite(sheet_path: String, cell: Vector2i,
        height_tiles: int = 1) -> Sprite2D:
    var tex: Texture2D = load(sheet_path) as Texture2D
    if tex == null:
        return null
    var spec: SheetSpec = SheetSpecReader.read(sheet_path)
    var spr := Sprite2D.new()
    spr.texture = tex
    spr.region_enabled = true
    spr.region_rect = Rect2(
            float(cell.x * spec.stride),
            float(cell.y * spec.stride),
            float(spec.tile_px),
            float(spec.tile_px * height_tiles))
    spr.centered = true
    var sf: float = spec.scale_factor()
    if sf != 1.0:
        spr.scale = Vector2(sf, sf)
    return spr
```

---

## Resolving the Sheet Path

For sprites mapped via the GameEditor (tile mappings, caravan wagon, etc.), always resolve via `TilesetCatalog.get_sheet_path()` rather than hardcoding:

```gdscript
var sheet_path: String = TilesetCatalog.get_sheet_path(&"my_mapping_field")
# Respects sheet_overrides set in the GameEditor dropdown
```

Default sheets are defined in `TilesetCatalog._DEFAULT_SHEETS`. If your mapping field is not in that dict, add it.

---

## Sheet Directories and Their `_spec.json`

| Directory | tile_px | margin_px | stride | Notes |
|-----------|---------|-----------|--------|-------|
| `assets/tiles/roguelike/` | 16 | 1 | 17 | No `_spec.json` — uses SheetSpec defaults |
| `assets/tiles/runes/` | 16 | 1 | 17 | No `_spec.json` — uses SheetSpec defaults |
| `assets/characters/roguelike/` | 16 | 1 | 17 | No `_spec.json` — uses SheetSpec defaults |
| `assets/icons/hires/` | 64 | 1 | 65 | Has `_spec.json`: `{ "tile_px": 64, "margin_px": 1 }` |

---

## Common Mistakes Checklist

Before committing any sprite-building code, check:

- [ ] Using `spec.stride` for region origin (not `spec.tile_px`, not a hardcoded `17`)
- [ ] Using `spec.tile_px` for region *size* (not stride)
- [ ] Calling `spec.scale_factor()` and applying to `sprite.scale` when != 1.0
- [ ] Loading `spec` via `SheetSpecReader.read(sheet_path)` (not hardcoding `tile_px = 16`)
- [ ] Resolving sheet path via `TilesetCatalog.get_sheet_path(&"field")` for GameEditor-managed sprites
- [ ] Confirming a `_spec.json` exists in the sheet's directory if `tile_px != 16` or `margin_px != 1`

---

## What This Convention Does NOT Cover

- **`CreatureSpriteRegistry`** (`scripts/data/creature_sprite_registry.gd`) — uses raw `[x, y, w, h]` pixel coords from JSON, not cell coords. Has its own `_detect_gutter()` + `_composite_region()` pipeline. Do not apply this convention there.
- **`CharacterAtlas` / `WeaponAtlas` / `ArmorAtlas`** — hardcode `STRIDE=17` and `TILE=16` as constants. Correct for the characters sheet, but not spec-driven. Safe for current sheets.
- **`HiresIconRegistry`** — builds `AtlasTexture` (not `Sprite2D`) for item icons. Uses `SheetSpecReader` and `spec.stride`. Correct since fix in commit `ad1d362`.
