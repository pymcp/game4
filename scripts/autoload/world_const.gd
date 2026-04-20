## WorldConst
##
## Single source of truth for top-down rendering constants. Tile size, zoom,
## region size, and derived helpers all live here so we can rescale the whole
## game by changing one number.
##
## Autoloaded as `WorldConst` (see project.godot).
extends Node

## Native pixel size of a single tile sprite (Kenney 16×16).
const TILE_PX: int = 16

## Render scale applied to the world's root TileMapLayers. 4× makes a
## 16-px tile occupy 64 screen pixels.
const RENDER_ZOOM: int = 4

## Effective on-screen tile size after RENDER_ZOOM. Use this for camera /
## viewport math.
const TILE_SCREEN_PX: int = TILE_PX * RENDER_ZOOM

## Side length (in tiles) of an overworld region.
const REGION_SIZE: int = 128

## Default side length (in tiles) of a procedural dungeon floor.
const DUNGEON_SIZE: int = 64

## Default side length (in tiles) of a city map.
const CITY_SIZE: int = 96

## Default footprint (in tiles) of a procedural house interior.
const HOUSE_SIZE: int = 16

## Tilesheet margin around each tile in the source PNG (Kenney = 1 px).
const TILESHEET_MARGIN: int = 1
