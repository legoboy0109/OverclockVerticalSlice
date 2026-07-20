# Systems Index: OVERCLOCK

> **Status**: Approved
> **Created**: 2026-07-19
> **Last Updated**: 2026-07-20
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

OVERCLOCK is a 2D top-down sci-fi turn-based tactics game whose defining mechanic is a
**single unified action-point (AP) economy** — build, produce, move, attack, and research
all draw from one per-turn pool, and victory goes to whoever compounds tempo fastest. The
system set is therefore small and tightly coupled: a foundational board + turn + AP layer,
a core layer of gameplay systems that all spend from the one pool, a presentation layer built
around a readable pre-commit action interface (Pillar 3), and two Feature systems (AI, factions).

This index scopes GDD authoring to the **Vertical Slice** tier (the current build target — the
concept prototype already validated the core loop). Twelve systems are Vertical-Slice tier; the
persistent campaign layer is deferred to Alpha. Two guardrails from the Concept → Systems Design
gate shape the order: the **Faction Identity** system is authored LAST and kept shallow (Pillar 4
is empirically unvalidated — the prototype was symmetric), and **Base & Production** must solve the
endgame closeout-drag problem the prototype surfaced.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Grid & Terrain (inferred) | Core | Vertical Slice | Approved | design/gdd/grid-terrain.md | — (engine) |
| 2 | Game State & Turn Manager (inferred) | Core | Vertical Slice | Approved | design/gdd/game-state-turn-manager.md | Grid & Terrain |
| 3 | AP Economy | Economy | Vertical Slice | Approved | design/gdd/ap-economy.md | Game State & Turn Manager |
| 4 | Unit System | Gameplay | Vertical Slice | Approved | design/gdd/unit-system.md | Grid & Terrain, Game State, AP Economy |
| 5 | Movement System | Gameplay | Vertical Slice | In Revision (soft-cap surcharge added 2026-07-20; re-review pending) | design/gdd/movement-system.md | Grid & Terrain, Unit System, AP Economy, Game State |
| 6 | Combat Resolution | Gameplay | Vertical Slice | Not Started | — | Unit System, Grid & Terrain, AP Economy |
| 7 | Base & Production | Gameplay | Vertical Slice | Not Started | — | Grid & Terrain, AP Economy, Unit System |
| 8 | Research / Tech | Progression | Vertical Slice | Not Started | — | AP Economy, Unit System |
| 9 | Command & Action Interface | UI | Vertical Slice | Not Started | — | Movement, Combat, Base & Production, AP Economy |
| 10 | Game HUD (inferred) | UI | Vertical Slice | Not Started | — | Game State, AP Economy, all Core |
| 11 | AI Opponent | Gameplay | Vertical Slice | Not Started | — | Game State (read interface), all Core |
| 12 | Faction Identity | Gameplay | Vertical Slice | Not Started | — | AP Economy, Unit System, Base & Production, Combat |
| 13 | Persistence & Campaign | Persistence | Alpha (deferred) | Not Started | — | Game State, all Core |

> **Concept mapping**: The concept's shorthand "six faction-agnostic core systems" = AP Economy (#3),
> Movement (#5), Combat Resolution (#6), Base & Production (#7), Research (#8), Command & Action
> Interface (#9). Systems #1, #2, #10 are the foundational/UI scaffolding those six require; #11 and
> #12 are the two Feature systems the Vertical Slice needs; #13 is deferred to Alpha.

---

## Categories

| Category | Description | Systems in OVERCLOCK |
|----------|-------------|----------------------|
| **Core** | Foundation everything depends on | Grid & Terrain, Game State & Turn Manager |
| **Gameplay** | The systems that make the game fun | Unit, Movement, Combat, Base & Production, AI Opponent, Faction Identity |
| **Economy** | Resource creation/consumption | AP Economy |
| **Progression** | How the player grows | Research / Tech |
| **UI** | Player-facing information | Command & Action Interface, Game HUD |
| **Persistence** | Save state & continuity | Persistence & Campaign (deferred) |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP / Prototype** | Core loop validation — **DONE** (concept prototype, verdict PROCEED) | First playable | Complete |
| **Vertical Slice** | One polished mission end-to-end + 2 asymmetric factions + persistence across 2–3 linked missions | Vertical slice | Design FIRST (all 12 systems below) |
| **Alpha** | Full mechanical scope, rough content | Alpha | Design later (Persistence & Campaign) |
| **Full Vision** | Polish + factions 3–6 + full campaigns | Beta / Release | Design as needed |

---

## Dependency Map

### Foundation Layer (no gameplay dependencies)

1. **Grid & Terrain** — the board everything spatial sits on: tiles, coordinates, terrain types (plain + cover), occupancy lookup.
2. **Game State & Turn Manager** — depends on: Grid. The authoritative, **render-decoupled, headless-simulatable** game-state model + turn/phase loop (start turn → reset AP → act → end turn → opponent → win/loss). Determinism is enforced here. *(TD architecture seed.)*
3. **AP Economy** — depends on: Game State. The per-turn action-point pool: income formula (base 10 + 2/outpost), spend API, "unspent AP is lost." Pillar 1's heart.

### Core Layer (depends on Foundation)

1. **Unit System** — depends on: Grid, Game State. Data-driven, statically-typed unit definitions and per-unit state (hp, atk, move cost, produce cost, position, hasAttacked).
2. **Movement System** — depends on: Grid, Unit, AP. AP-costed movement + reachable-tile computation; **units path *through* friendly units** (prototype fix), stopping only on occupied tiles.
3. **Combat Resolution** — depends on: Unit, Grid, AP. Deterministic damage, cover mitigation (−1), free counterattacks, death/removal, HQ destruction = win (Pillar 2: no randomness).
4. **Base & Production** — depends on: Grid, AP, Unit. HQ + outposts, unit production with **player-chosen deploy tile** (prototype fix), outpost income, structure hp/destruction. **Owns the endgame closeout-drag problem.**
5. **Research / Tech** — depends on: AP, Unit. AP-costed upgrade tier (e.g. +1 atk); a lever for tempo swings.

### Presentation Layer (depends on Core)

1. **Command & Action Interface** — depends on: Movement, Combat, Base & Production, AP. The **Advance Wars / Fire Emblem-style pre-commit menu**: select → preview move range / targets / exact AP cost → confirm. Pillar 3-critical.
2. **Game HUD** — depends on: Game State, AP, all Core. AP/income display, turn indicator, unit info, build/research affordances, action log.

### Feature Layer (depends on Core; designed after presentation)

1. **AI Opponent** — depends on: Game State read interface, all Core. Tempo heuristic that plays the full economy; sits on the headless state layer *(TD seed)*.
2. **Faction Identity** — depends on: AP, Unit, Base & Production, Combat. Asymmetric AP rules/costs per faction. **Designed LAST and kept shallow — gated on the faction-asymmetry prototype (Pillar 4 unvalidated).**

### Polish Layer / Deferred (depends on everything)

1. **Persistence & Campaign** — depends on: Game State, all Core. Save/load + between-mission carry-over of base/research/army. **Deferred to Alpha** — not authored this phase.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Grid & Terrain | Vertical Slice | Foundation | game-designer, godot-specialist | S |
| 2 | Game State & Turn Manager | Vertical Slice | Foundation | game-designer, systems-designer | M |
| 3 | AP Economy | Vertical Slice | Foundation | systems-designer, economy-designer | M |
| 4 | Unit System | Vertical Slice | Core | game-designer, systems-designer | S |
| 5 | Movement System | Vertical Slice | Core | game-designer, systems-designer | M |
| 6 | Combat Resolution | Vertical Slice | Core | systems-designer, game-designer | M |
| 7 | Base & Production | Vertical Slice | Core | game-designer, economy-designer | L |
| 8 | Research / Tech | Vertical Slice | Core | economy-designer, systems-designer | S |
| 9 | Command & Action Interface | Vertical Slice | Presentation | ux-designer | M |
| 10 | Game HUD | Vertical Slice | Presentation | ux-designer | S |
| 11 | AI Opponent | Vertical Slice | Feature | ai-programmer, game-designer | L |
| 12 | Faction Identity | Vertical Slice | Feature | game-designer, systems-designer | M (shallow) |

> Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions.
> **Sequencing guardrails (from the Concept → Systems Design gate):** #12 Faction Identity is
> authored LAST and kept shallow (seeded by the rush/boom archetypes) until the asymmetry prototype
> validates Pillar 4. #7 Base & Production must include a closeout-pressure solution to the endgame drag.

---

## Circular Dependencies

- None found. The AP Economy is a pure Foundation system queried by all spenders (Movement, Combat,
  Base & Production, Research), and income is a read-only query over structures — no cycle.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|------------------|------------|
| Base & Production | Design | Endgame closeout-drag: HQ-as-sole-corner-producer lets a losing player spam units and drag decided games | **Required** Edge Cases section + a closeout-pressure mechanic (production cap / rising cost / forward deploy / attrition); must not add a parallel resource (Pillar 1) or clutter the board (Pillar 3) |
| AI Opponent | Technical / Design | A competent tempo-playing AI is genuinely hard | Build on the headless, queryable game-state layer; ship a simple greedy heuristic first (proven playable in the prototype), deepen later |
| Faction Identity | Design | Pillar 4 (asymmetric factions play distinctly, not reskins) is empirically unvalidated — prototype was symmetric | Author shallow now (rush/boom seed); gate full design on a dedicated faction-asymmetry prototype |
| AP Economy | Design / Balance | The single-currency balance center of the whole game | Largely de-risked by the concept prototype (no dominant opening); carry the prototype's baseline tuning values (REPORT.md) into the Formulas/Tuning sections |
| Game State & Turn Manager | Technical | Bottleneck — every system depends on it; if rendering leaks into game logic, AI + headless tests get expensive | Design as a render-decoupled, deterministic, headless-simulatable model from the start (TD seed) |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 13 |
| Design docs started | 5 |
| Design docs reviewed | 2 (AP Economy + Unit System) |
| Design docs approved | 2 (AP Economy; Unit System — accepted post-revision 2026-07-20) |
| Vertical Slice systems designed | 5 / 12 (Grid & Terrain, Game State & Turn Manager, AP Economy, Unit System, Movement System) |
| Deferred (Alpha) systems | 1 (Persistence & Campaign) |

---

## Next Steps

- [ ] Design Vertical-Slice systems in the order above (use `/design-system [system-name]` or `/map-systems next`)
- [ ] Run `/design-review design/gdd/[system].md` after each GDD is authored
- [ ] Author Faction Identity LAST — gate it on a faction-asymmetry prototype
- [ ] Run `/review-all-gdds` once the MVP/Vertical-Slice GDDs are complete
- [ ] Run `/gate-check` (Systems Design → Technical Setup) when the system set is designed and cross-reviewed
