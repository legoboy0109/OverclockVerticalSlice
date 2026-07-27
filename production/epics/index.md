# Epics Index

Last Updated: 2026-07-27
Engine: Redot 26.2 (Godot 4.6-compatible fork)

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Grid & Terrain](grid-terrain/EPIC.md) | Foundation | Grid & Terrain | design/gdd/grid-terrain.md | 4 stories (4 Complete) | Complete |
| [Game State & Turn Manager](game-state-turn-manager/EPIC.md) | Foundation | Game State & Turn Manager | design/gdd/game-state-turn-manager.md | 4 stories (4 Complete) | Complete |
| [AP Economy](ap-economy/EPIC.md) | Foundation | AP Economy | design/gdd/ap-economy.md | 3 stories (3 Complete) | Complete |
| [Unit System](unit-system/EPIC.md) | Core | Unit System | design/gdd/unit-system.md | 10 stories (10 Complete) | Complete |
| [Movement](movement/EPIC.md) | Core | Movement System | design/gdd/movement-system.md | 3 stories (3 Complete) | Complete |
| [Combat Resolution](combat-resolution/EPIC.md) | Core | Combat Resolution | design/gdd/combat-resolution.md | 8 stories (8 Complete) | Complete |
| [Base & Production](base-production/EPIC.md) | Core | Base & Production | design/gdd/base-production.md | 10 stories | Ready |
| [Research / Tech](research-tech/EPIC.md) | Core | Research / Tech | design/gdd/research-tech.md | Not yet created | Ready |

## Layer Status

- **Foundation** (3 epics): ✅ Complete — all 11 stories done, QA APPROVED (Sprint 1).
- **Core** (5 epics): In progress — the three VS-critical epics are ✅ **Complete**:
  Unit System (10/10), Movement (3/3), Combat Resolution (8/8). Base & Production now
  has a story breakdown (10 stories, none implemented yet); Research/Tech still needs
  one (`/create-stories research-tech`). Both have Accepted ADRs (0017/0018).
  VS-critical order was **Unit System → Movement → Combat Resolution** (Base & Production
  and Research/Tech follow after the vertical slice). Movement's QQ-05 perf-spike gate (Sprint 2 S2-03)
  cleared 2026-07-25 (PASS).
- **Feature** (2 systems — AI Opponent, Faction Identity): not yet broken into epics
  (`/create-epics layer:feature`).
- **Presentation** (2 systems — Command & Action Interface, Game HUD): not yet broken
  into epics (`/create-epics layer:presentation`). Both are VS dependencies — the slice
  needs a rendered board + HUD + input.
