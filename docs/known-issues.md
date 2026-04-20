# Known Issues & Stylistic Tradeoffs

These are deliberate tradeoffs documented during planning. Each is a "won't fix unless playtest demands."

1. **Single-facing characters** — The Kenney Isometric Miniature Dungeon character sprites have only one rendered facing direction. Players' sprites do not rotate or flip when moving in different directions. This is the tabletop-miniature aesthetic of the source pack and is preserved as a stylistic choice.

2. **Mixed-perspective NPCs** — Some NPCs and monsters use sprites from `Roguelike Characters Pack`, `Monster Builder Pack`, and `Animal Pack`, which are top-down/orthogonal rather than isometric. They will appear visually different from the iso-rendered world tiles and player characters. This is accepted as the cost of richer NPC variety.

3. **Attack animation reuses `Pickup`** — Kenney iso miniatures have Idle, Run, and Pickup animations only. The 10-frame Pickup animation is reused as the attack/mine swing.

4. **No fantasy-specific music** — Kenney's Music Loops collection skews comedic/general. Background music is deferred or supplemented from external CC0 sources.

5. **GDScript-only** — No C# / GDExtension port planned. If perf becomes a problem, optimize within GDScript (object pooling, region streaming, AStar caching).
