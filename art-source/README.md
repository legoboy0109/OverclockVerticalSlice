# art-source — Layered Source Art (NOT imported by Godot)

Keep layered working files here — `.kra` / `.aseprite` / `.psd`, **one per asset family** (all iso
facings + states of a unit as layer groups in a single file), per art-bible §8.1.

This folder is deliberately **outside `assets/`** and carries a `.gdignore` so the Godot/Redot editor
never scans or imports it. Only the flat, exported **runtime PNGs** go under `assets/art/` (which the
engine imports and the game loads).

**Do not** point game code at anything in here — production code loads from `assets/`, never
`art-source/`. When exporting: flatten → PNG 8-bit+alpha (lossless) → `assets/art/<category>/` with
the §8.2 name.

Suggested organization mirrors the runtime layout:
```
art-source/
├── units/       scout.kra, trooper.kra, heavy.kra
├── structures/  hq.kra, production_outpost.kra
└── terrain/     tiles.kra
```
