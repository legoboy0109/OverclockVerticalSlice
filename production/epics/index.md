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
| [Base & Production](base-production/EPIC.md) | Core | Base & Production | design/gdd/base-production.md | 10 stories (9 Complete, 003 Superseded) | Complete |
| [Research / Tech](research-tech/EPIC.md) | Core | Research / Tech | design/gdd/research-tech.md | Not yet created | Ready |
| [Board Renderer](board-renderer/EPIC.md) | Presentation | Board Renderer (iso projection/picking/overlays) | ADR-0013 (TR-grid-008) | 5 stories (5 Complete) | Complete |
| [Command & Action Interface](command-action-interface/EPIC.md) | Presentation | Command & Action Interface | design/gdd/command-action-interface.md | 9 stories | Ready |
| [Game HUD](game-hud/EPIC.md) | Presentation | Game HUD | design/gdd/game-hud.md | 8 stories | Ready |
| [AI Opponent](ai-opponent/EPIC.md) | Feature | AI Opponent (minimal VS) | design/gdd/ai-opponent.md | 8 stories (6 Complete; 007/008 deferred to Production) | Complete (VS) |

## Layer Status

- **Foundation** (3 epics): ✅ Complete — all 11 stories done, QA APPROVED (Sprint 1).
- **Core** (5 epics): ✅ **Complete** for the VS-critical set — Unit System (10/10),
  Movement (3/3), Combat Resolution (8/8), **Base & Production (9/10 Complete, 003
  Superseded — closed 2026-07-27)**. Research/Tech still needs a story breakdown
  (`/create-stories research-tech`) and is deferred (not on the VS-critical path).
  Movement's QQ-05 perf-spike gate cleared 2026-07-25 (PASS).
- **Presentation** (3 epics — Board Renderer, Command & Action Interface, Game HUD):
  **broken into epics 2026-07-27 (Sprint 2 S2-01)**. All are hard VS dependencies (the
  slice needs a rendered board + input + HUD). **Board Renderer (ADR-0013, TR-grid-008)
  is the root** — it builds the `BoardRenderer` node that CAI's picking/overlays (Story 006)
  and the HUD glyph layer consume; sequence it first. ADR-0013/0014 iso-picking & dual-focus
  spikes both cleared PASS 2026-07-25, retiring their HIGH engine risk. CAI has 9 stories;
  Board Renderer + Game HUD still need `/create-stories`.
- **Feature** (2 systems): **AI Opponent** broken into an epic 2026-07-27 (Sprint 2
  S2-01, scoped to the minimal VS heuristic) — its QQ-06 perf-spike gate cleared PASS
  2026-07-25, so it may proceed straight to `/create-stories`. **Faction Identity**
  is deferred (designed last; not a VS-critical dependency).
