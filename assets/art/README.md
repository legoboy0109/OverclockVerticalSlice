# assets/art — Runtime Sprite Assets

Drop **generated runtime PNGs** here, by category. Layered **source** working files
(`.kra`/`.aseprite`/`.psd`) live OUTSIDE `assets/` in `art-source/` so Godot never imports them.

## Layout
```
assets/art/
├── units/       infantry sprites (Scout, Trooper, Heavy)
├── structures/  HQ + Production Outpost
└── terrain/     floor + cover tiles
```

## Naming — art-bible §8.2 (the S4-03 entity renderer loads by this convention)

| Category | Pattern | Example |
|----------|---------|---------|
| Units | `unit_[archetype]_[faction]_[facing]_[state]_[frame].png` | `unit_scout_rush_s_idle_01.png` |
| Structures | `struct_[name]_[faction]_[state].png` | `struct_hq_boom_idle.png` |
| Terrain | `tile_[terrain-type]_[variant].png` | `tile_plain_clean.png` |

Tokens: faction `rush` / `boom` / `neutral` · facing `n` / `s` / `e` / `w` (`w` = h-flip of `e`) ·
state `idle` / `move` / `attack` / `hit` / `destroyed` · frames `01`…`NN`.

## What to drop (VS set — full spec: `design/assets/specs/vs-entities-assets.md`)

Prioritize **rush + boom** (the board wires those; neutral is optional, for menus).
- `units/` — `scout`, `trooper`, `heavy` (× facings × states × hues)
- `structures/` — `hq`, `production_outpost` (× states × hues; Production Outpost is pre-placed → no construction sprites)
- `terrain/` — `tile_plain`, `tile_cover` (+ wear variants; cover ships as a floor cell + a Y-sorted prop, §8.8)

## Format & git
- **Format:** PNG **8-bit + alpha**, lossless, mipmaps off (§8.1/§8.6). No JPEG.
- **Commit PNGs directly** — they're not gitignored at VS scale (LFS lines in `.gitignore` are off; enable only if the set grows large).
- After dropping files, run `./redot --headless --import` (or open the editor) to generate the
  **`.png.import`** sidecars, then **commit the PNGs + their `.import` sidecars** (keeps imports
  reproducible). The `.godot/` cache stays ignored.
