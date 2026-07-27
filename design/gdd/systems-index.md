# Systems Index: OVERCLOCK

> **Status**: Approved
> **Created**: 2026-07-19
> **Last Updated**: 2026-07-21
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

OVERCLOCK is a 2D isometric sci-fi turn-based tactics game whose defining mechanic is a
**single unified action-point (AP) economy** — build, produce, move, attack, and research
all draw from one per-turn pool, and victory goes to whoever compounds tempo fastest. The
system set is therefore small and tightly coupled: a foundational board + turn + AP layer,
a core layer of gameplay systems that all spend from the one pool, a presentation layer built
around a readable pre-commit action interface (Pillar 3), and two Feature systems (AI, factions).

> **Projection note (2026-07-25):** The board renders in **2:1 isometric (dimetric)** projection
> (revised from the original "top-down" framing) — see `design/art/art-bible.md` and
> `docs/architecture/change-impact-2026-07-23-isometric-projection.md`. A view-layer decision only:
> all system rules and coordinates are computed in projection-invariant grid space. The
> Board Renderer / grid→screen transform is a Presentation-layer concern (ADR-0013), not a rules change.

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
| 3 | AP Economy | Economy | Vertical Slice | Approved (2026-07-22: the dominant-strategy blocker that flagged this — the Economy-Tech + boom + large-map composition — is **resolved by pinning the VS board to a fixed 14×16** (grid-terrain.md); the map-size "Bimodal meta" Open Question is closed and the last owed Turn-Manager start-of-turn cite added. Building-count cap `MAX_OUTPOST_COUNT` deliberately left disabled pending sim/playtest, per user. Full `/review-all-gdds` re-run queued to confirm corpus) | design/gdd/ap-economy.md | Game State & Turn Manager |
| 4 | Unit System | Gameplay | Vertical Slice | Approved (re-flagged Needs Revision by `/review-all-gdds` 2026-07-22 for 3 stale "Movement In Revision" / stale own-status cross-references — fixed same session; reverted to Approved) | design/gdd/unit-system.md | Grid & Terrain, Game State, AP Economy, Research (buff flags) |
| 5 | Movement System | Gameplay | Vertical Slice | Approved (re-reviewed 2026-07-21; formula confirmed sound, 3 blocking AC/precondition gaps fixed in-file; numbers spike-gated. **Additive contract 2026-07-22 via #9 propagation:** `reachable()` return now `{tile, min_cost, is_surcharged}` — purely additive, verdict unchanged) | design/gdd/movement-system.md | Grid & Terrain, Unit System, AP Economy, Game State |
| 6 | Combat Resolution | Gameplay | Vertical Slice | Approved (re-flagged Needs Revision by `/review-all-gdds` 2026-07-22 for sharing the undefined Research-Lab-destruction trigger path — fixed same session with a cross-doc note pointing to research-tech.md's new trigger-mechanism clarification; reverted to Approved. **Additive contract 2026-07-22 via #9 propagation:** new `legal_targets(unit, from_tile)` hypothetical-tile overload — purely additive, verdict unchanged) | design/gdd/combat-resolution.md | Unit System, Grid & Terrain, AP Economy |
| 7 | Base & Production | Gameplay | Vertical Slice | Approved (re-flagged Needs Revision by `/review-all-gdds` 2026-07-22 for a non-reciprocal dependency vs. research-tech.md — fixed same session: added Research/Tech as a Hard downstream dependent + reworded stale Provisional tag; reverted to Approved) | design/gdd/base-production.md | Grid & Terrain, AP Economy, Unit System |
| 8 | Research / Tech | Progression | Vertical Slice | Approved (2026-07-22: doc header was already Approved; the systems-index flag was the shared Economy-Tech + boom + large-map dominant-strategy composition, now **resolved via the 14×16 board pin** — see #3. The separate "which tech" Economy-Tech-vs-Attack/Defense choice concern remains a documented, non-blocking, playtest-routed Open Question — it never blocked approval. Full `/review-all-gdds` re-run queued to confirm) | design/gdd/research-tech.md | AP Economy, Unit System, Base & Production |
| 9 | Command & Action Interface | UI | Vertical Slice | Approved | design/gdd/command-action-interface.md | Movement, Combat, Base & Production, AP Economy |
| 10 | Game HUD (inferred) | UI | Vertical Slice | Approved (re-review 2026-07-22, full 8-specialist + creative-director: the 5 first-pass blockers confirmed closed; 2 new blockers found — CR-3a whose-AP/turn-boundary/GameOver rules + audio total priority order — both **fixed in-file same session** along with 9 recommended items (OQ-5 closed via Redot binary verification, OQ-8 downgraded, AC-1 split, CR-11 coverage, etc.). CD verdict: Approved once the 2 blockers close, no third spin needed) | design/gdd/game-hud.md | Game State, AP Economy, all Core |
| 11 | AI Opponent | Gameplay | Vertical Slice | Approved (confirmation re-review 2026-07-22, full 6-specialist + creative-director: prior pass's 5 blocking clusters confirmed held with zero constant drift; 3 new blockers found — LETHAL_FLOOR_BONUS cross-knob invariant, AC-20/"forward entity" contradiction, standing-start passivity — all **fixed in-file same session** (positional/retreat scoring re-normalized by tiles-traversed; nearest-enemy simplification; economy-ceiling invariant guard) + ~12 recommended items folded in. CD verdict: APPROVED once the 3 close, no further pass needed. No registry/shared-fact changes) | design/gdd/ai-opponent.md | Game State (read interface), all Core |
| 12 | Faction Identity | Gameplay | Vertical Slice | **Approved** (2026-07-22 confirmation re-review, 2nd full 6-specialist + creative-director pass: prior deciding blocker — the `ap_income` formula omitting AP Economy's Economy-Tech term + `ECONOMY_TECH_TIER_THRESHOLD` cap — **confirmed fully resolved** [corrected to the full 4-term form; verified byte-for-byte vs ap-economy.md by economy-designer + systems-designer independently]. 2 new blockers found + fixed in-file same session: (a) `production_cap` cap-0 boundary gap — a faction delta on a base-cap-0 non-producer (Research Lab / Defensive Structure) was undefined and would have forced cap 0→1; now inert, so a faction delta crosses the produces/doesn't-produce boundary in **neither** direction [Formulas 4c, CR-2.4, Edge Cases, AC-12]; (b) FSM had no pre-lock preview sub-state for the AC-27 acknowledgment + AC-28 preview contracts — added a **SELECTING** sub-state [States, AC-26]. Plus 2 cleanups: AC-4a "executable today" softened; Overview provisional-framework marker + OQ-9 reopen-trigger. User accepted the fixes and marked Approved without a 3rd pass. **Framework-only — all Rush/Boom values remain prototype-gated. The 10th and final VS system Approved.** See design/gdd/reviews/faction-identity-review-log.md. Additive `effective_X` contracts owed to 5 upstream GDDs via `/propagate-design-change`, deferrable — no-op under the Neutral default the VS ships) | design/gdd/faction-identity.md | AP Economy, Unit System, Base & Production, Combat |
| 13 | Persistence & Campaign | Persistence | Alpha (deferred) | Not Started | — | Game State, all Core |
| 14 | Vehicle & Mech Tier | Gameplay | Full Vision (deferred) | Not Started | — | Base & Production (new production structure), Unit System, AP Economy, Movement |

> **#14 note (2026-07-23):** Surfaced during art-bible authoring. A future unit tier — **piloted vehicles/mechs** added via a **new production structure + a piloting mechanic** — larger than the VS infantry roster. Deferred to Full Vision; **NOT in VS scope**. The art bible already forward-specs its visual rules (`design/art/art-bible.md` §5.0/§5.5: larger silhouettes, same Mass Distribution Bias faction families, scaled-up neon budget, same LOD order). Mechanically undesigned — captured here only so it isn't lost.

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

1. **Unit System** — depends on: Grid, Game State, AP Economy. Data-driven, statically-typed unit definitions and per-unit state (hp, atk, move cost, produce cost, position, hasAttacked). *(Owns the AP cost values Movement/Base & Production spend — matches the systems table above and the Unit GDD's Hard dependency on AP Economy.)*
2. **Movement System** — depends on: Grid, Unit, AP. AP-costed movement + reachable-tile computation; **units path *through* friendly units** (prototype fix), stopping only on occupied tiles.
3. **Combat Resolution** — depends on: Unit, Grid, AP. Deterministic damage (`max(1, effective_attack − cover −1 − defense)`), death/removal, HQ destruction = win (Pillar 2: no randomness). Counterattacks are a per-unit-type `can_counterattack` trait, **off by default for all VS units** (overrides the prototype's free counters); defense and an area/indirect targeting profile ship as off-by-default infrastructure. Ranged/counter/defense/area numbers are spike-gated.
4. **Base & Production** — depends on: Grid, AP, Unit. HQ + outposts, unit production with **player-chosen deploy tile** (prototype fix), outpost income, structure hp/destruction. **Owns the endgame closeout-drag problem.**
5. **Research / Tech** — depends on: AP, Unit, Base & Production. AP-costed **Research Lab** (5th structure, built via Base & Production) unlocks 3 flat permanent techs — Attack (+1 atk), Defense (+1 def), Economy (+1 AP/turn income per completed Economy Outpost, capped at 6 outposts); a lever for tempo swings.

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
| 9 | Command & Action Interface | Vertical Slice | Presentation | ux-designer | M |  ← **Approved 2026-07-22** (full `/design-review` + re-review; 11 + 3 blockers fixed in-file). 📌 UX Flag: run `/ux-design` for the action menu + pre-commit flow before epics.
| 10 | Game HUD | Vertical Slice | Presentation | ux-designer | S |  ← **Approved 2026-07-22** (full `/design-review` + re-review; 5 + 2 blockers fixed in-file). 📌 UX Flag: run `/ux-design` for `hud.md` *together with* #9's flow (shared screen + 3 seams).
| 11 | AI Opponent | Vertical Slice | Feature | ai-programmer, game-designer | L |  ← **Approved 2026-07-22** (full `/design-review` + confirmation re-review; 5 + 3 blockers fixed in-file)
| 12 | Faction Identity | Vertical Slice | Feature | game-designer, systems-designer | M (shallow) |  ← **Designed 2026-07-22** (framework-only, values prototype-gated; pending `/design-review`). 📌 UX Flag: run `/ux-design` for a setup-screen faction picker before epics.

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
| Design docs started | 12 (all VS systems authored — Faction Identity #12 designed 2026-07-22, framework-only, pending `/design-review`) |
| Design docs reviewed | **12 / 12** — all Vertical-Slice systems have completed design-review (AP Economy + Unit System + Movement System + Combat Resolution + Base & Production + Research / Tech + Command & Action Interface + Game HUD + **AI Opponent** + **Faction Identity** — plus Grid & Terrain + Game State & Turn Manager as Approved foundations). Game HUD re-reviewed + Approved 2026-07-22 (first pass NEEDS REVISION [5 blockers], re-review found + fixed 2 more). AI Opponent #11 and Faction Identity #12 each completed a confirmation re-review 2026-07-22 (see Design docs approved row for detail). |
| Design docs approved | **12 / 12** — all Vertical-Slice systems Approved (Grid & Terrain + Game State & Turn Manager + AP Economy + Unit System + Movement System + Combat Resolution + Base & Production + Research / Tech + Command & Action Interface + Game HUD + AI Opponent + **Faction Identity**). Research #8 approved 2026-07-21 (4 blockers fixed; Economy Tech retuned to a per-outpost income bonus). **All re-reviews owed from the Research retune are now resolved (2026-07-22):** AP Economy #3 (untiered income term found to cancel its own diminishing-returns brake, fixed with an `ECONOMY_TECH_TIER_THRESHOLD` cap, ceiling 38→32) and Base & Production #7 (discount-hook removal confirmed clean, 1 regression-guard AC added). **Command & Action Interface #9 approved 2026-07-22** after a full `/design-review` (11 blockers fixed) + re-review (3 blockers fixed: CR-10 four-tier rewrite, win-check terminal FSM state, CR-6a gesture input-shape constraint). No re-reviews currently owed for #9. **AP Economy #3 and Research #8 returned to Approved 2026-07-22** — the dominant-strategy composition risk that flagged them (Economy-Tech + boom + large-map) was resolved by a user design decision: **pin the VS board to a fixed 14×16** (grid-terrain.md), defusing the map-size half of the composition; the separate non-blocking "which tech" Economy-Tech-dominance concern stays a documented playtest-routed Open Question. Building-count cap left deliberately disabled pending sim/playtest. **AI Opponent #11 approved 2026-07-22** (confirmation re-review: 5 prior + 3 new blockers all fixed in-file). **Faction Identity #12 approved 2026-07-22** (2nd full confirmation re-review: deciding `ap_income` blocker confirmed resolved + 2 new blockers fixed in-file; framework-only, values prototype-gated). A full `/review-all-gdds` re-run across all 12 authored systems is queued to confirm the corpus now that the set is complete. |
| Vertical Slice systems designed | **12 / 12** — ALL VS systems authored (Grid & Terrain, Game State & Turn Manager, AP Economy, Unit System, Movement System, Combat Resolution, Base & Production, Research / Tech, Command & Action Interface, Game HUD, AI Opponent, **Faction Identity** [#12, framework-only, values prototype-gated]). **All 12 Approved.** |
| Deferred (Alpha) systems | 1 (Persistence & Campaign) |
| Deferred (Full Vision) systems | 1 (Vehicle & Mech Tier — captured 2026-07-23, mechanically undesigned) |

---

## Next Steps

- [ ] Design Vertical-Slice systems in the order above (use `/design-system [system-name]` or `/map-systems next`)
- [ ] Run `/design-review design/gdd/[system].md` after each GDD is authored
- [ ] Author Faction Identity LAST — gate it on a faction-asymmetry prototype
- [ ] Run `/review-all-gdds` once the MVP/Vertical-Slice GDDs are complete
- [ ] Run `/gate-check` (Systems Design → Technical Setup) when the system set is designed and cross-reviewed
