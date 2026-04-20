# Coding Conventions

## Files & Naming
- File names: `snake_case.gd`, `snake_case.tscn`, `snake_case.tres`.
- Class names (`class_name`): `PascalCase`. Always declare `class_name` for any reusable script.
- Variables, functions, signals: `snake_case`.
- Constants and enums: `UPPER_SNAKE_CASE`.
- Private members: prefix with `_underscore`.

## Architecture
- **Autoloads** for cross-cutting state: `InputContext`, `PauseManager`, `WorldManager`, `GameSession`.
- Prefer **signals over polling**. Connect via code in `_ready`, not via the editor signals tab.
- Avoid static methods on `class_name` scripts that extend `Node` — known Godot 4.3 quirk where `ClassName.static_method(...)` fails from cross-script calls. Put pure helpers on `RefCounted`-derived scripts or autoload singletons.
- Use **typed GDScript** everywhere: `var foo: int = 0`, `func bar(x: float) -> Vector2:`. Untyped variables only when necessary.

## Resources & Data
- Game data (items, biomes, recipes) lives as `.tres` Resource files in `resources/`.
- Save games at `user://saves/<slot>.tres`.

## Scenes
- One scene = one purpose. Sub-scenes via `PackedScene` instancing.
- Y-sort enabled on isometric entity layers so depth sorts naturally.

## Testing
- GUT (`addons/gut/`). Tests under `tests/unit/` and `tests/integration/`.
- Run headless: `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests`.

## Asset Source
- Raw assets stay in `kenney_raw/` (gdignored from Godot via `.gdignore`).
- Curated copies live in `assets/` with stable, project-relative paths referenced from `.tres` resources.
