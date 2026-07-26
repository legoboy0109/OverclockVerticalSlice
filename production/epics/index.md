# Epics Index

Last Updated: 2026-07-26
Engine: Redot 26.2 (Godot 4.6-compatible fork)

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Grid & Terrain](grid-terrain/EPIC.md) | Foundation | Grid & Terrain | design/gdd/grid-terrain.md | 4 stories (4 Complete) | Complete |
| [Game State & Turn Manager](game-state-turn-manager/EPIC.md) | Foundation | Game State & Turn Manager | design/gdd/game-state-turn-manager.md | 4 stories (4 Complete) | Complete |
| [AP Economy](ap-economy/EPIC.md) | Foundation | AP Economy | design/gdd/ap-economy.md | 3 stories (3 Complete) | Complete |
| [Unit System](unit-system/EPIC.md) | Core | Unit System | design/gdd/unit-system.md | Not yet created | Ready |
| [Movement](movement/EPIC.md) | Core | Movement System | design/gdd/movement-system.md | Not yet created | Ready |
| [Combat Resolution](combat-resolution/EPIC.md) | Core | Combat Resolution | design/gdd/combat-resolution.md | Not yet created | Ready |
| [Base & Production](base-production/EPIC.md) | Core | Base & Production | design/gdd/base-production.md | Not yet created | Ready |
| [Research / Tech](research-tech/EPIC.md) | Core | Research / Tech | design/gdd/research-tech.md | Not yet created | Ready |

## Layer Status

- **Foundation** (3 epics): ✅ Complete — all 11 stories done, QA APPROVED (Sprint 1).
- **Core** (5 epics): Ready — epics defined 2026-07-26; stories not yet created.
  VS-critical order: **Unit System → Movement → Combat Resolution** (Base & Production
  and Research/Tech follow after the vertical slice). Gate Movement story creation on
  the QQ-05 perf spike (Sprint 2 S2-03).
- **Feature** (2 systems — AI Opponent, Faction Identity): not yet broken into epics
  (`/create-epics layer:feature`).
- **Presentation** (2 systems — Command & Action Interface, Game HUD): not yet broken
  into epics (`/create-epics layer:presentation`). Both are VS dependencies — the slice
  needs a rendered board + HUD + input.
