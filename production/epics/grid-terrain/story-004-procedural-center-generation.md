# Story 004: Procedural Center Terrain Generation & Self-Correcting Reachability

> **Epic**: Grid & Terrain
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/grid-terrain.md`
**Requirement**: `TR-grid-009`, `TR-grid-010` (Procedural half), `TR-grid-011` (Procedural mode), `TR-grid-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Grid Representation & Map-Definition Format
**ADR Decision Summary**: `generate_procedural` consumes a dedicated seeded `RandomNumberGenerator` (never the engine's global RNG) to place Cover/Impassable features in a central band, honoring `PROC_SYMMETRIC` mirroring. Reachability is guaranteed via a deterministic self-correction: on BFS failure, thin Impassable features in a fixed seed-stable order and re-test, repeating until connected; if even a fully-thinned band can't connect, clamp density to the maximum that stays connected and log the clamp. No re-roll — the correction is a pure function of the failed layout.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` seeded-instance usage is stable pre-cutoff. No post-cutoff verification needed.

**Control Manifest Rules (this layer)**:
- Required: "RNG must be isolated to Grid map generation only, run once at load, via a dedicated seeded `RandomNumberGenerator` (seed = map definition's `PROC_SEED`)" — source: ADR-0003
- Required: "Fractional gameplay coefficients must be stored as scaled integers (e.g. `PENALTY_X10 = 15`) and computed via integer ceil/floor-division" — source: ADR-0003 (`proc_density_x100`, `proc_feature_mix_x100`)
- Required: "Authored maps failing HQ-to-HQ reachability must be rejected at load; procedural maps must self-correct via seed-stable-order thinning (no re-roll), clamping density and logging if still unconnectable" — source: ADR-0005
- Forbidden: "Never call global `randi()`/`randf()`/`randi_range()`/`randf_range()`/`randomize()`/`seed()` anywhere in the project" — source: ADR-0003
- Forbidden: "Never rely on best-effort determinism (seed once, allow floats in state, rely on ordered dictionaries)" — source: ADR-0003
- Guardrail: `generate_procedural` runs once at map load; the thinning self-correction re-runs the O(W·H) BFS per thinning step (bounded by band feature count) — load-time only, no per-frame cost — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/grid-terrain.md`, scoped to this story:*

- [ ] **GIVEN** a Procedural Center map with a fixed `PROC_SEED` and config, **WHEN** the map is generated twice, **THEN** the two terrain layouts are byte-identical (seeded determinism).
- [ ] **GIVEN** a Procedural Center map with `PROC_SYMMETRIC = true`, **WHEN** it is generated, **THEN** the layout is mirror-symmetric across the board center, and both HQs remain mutually reachable across passable tiles.
- [ ] **GIVEN** a Procedural Center config whose density would wall off the HQs, **WHEN** the map is generated, **THEN** the generator clamps density to preserve HQ-to-HQ reachability and never emits an unplayable map.
- [ ] **GIVEN** Procedural Center generation is asked to place features on HQ or deploy tiles, **WHEN** candidates are selected, **THEN** those tiles are excluded from the candidate set.
- [ ] **GIVEN** `PROC_BAND_WIDTH` ≥ the board's smaller dimension, **WHEN** the band is computed, **THEN** it is clamped to the board (whole-board scatter), still honoring HQ/deploy exclusions and reachability.

---

## Implementation Notes

*Derived from ADR-0005 Decision (`generate_procedural`) and GDD Edge Cases:*

- Seed a dedicated `RandomNumberGenerator` instance with `map_def.proc_seed` — never the engine's global RNG functions.
- Place features only within a central band of `proc_band_width` tiles, oriented perpendicular to the HQ-to-HQ axis, centered on the board. Exclude HQ tiles and their immediate deploy area from the candidate set entirely (never overwritten).
- `proc_density_x100` (scaled int, e.g. `30` = 0.30) sets the fraction of band tiles receiving a feature; `proc_feature_mix_x100` (e.g. `70` = 0.70) sets the Cover-vs-Impassable split.
- If `proc_symmetric` (default true), mirror the generated layout across the board's center so neither side gets a positional advantage.
- **Reachability self-correction** (reuse Story 003's BFS validator unchanged):
  1. Run the BFS validator after initial generation.
  2. On failure, remove Impassable features from the band in a **fixed, seed-stable order** (thinning) and re-test. Repeat until reachable.
  3. There is **no re-roll** — the correction is a pure function of the failed layout, so the same seed+config always yields the same corrected map.
  4. If `PROC_DENSITY` is set so high that even a fully-thinned layout can't keep the HQs connected, fall back to the maximum density that still guarantees reachability and **log the clamp** — never emit an unplayable map.
- If `PROC_BAND_WIDTH` ≥ the board's smaller dimension, clamp the band to the board (treat as whole-board scatter) while still honoring HQ/deploy exclusions and reachability.
- Wire this into `build_grid`'s step 2/3 `PROCEDURAL` branches left as placeholders by Story 003.

---

## Out of Scope

*Nothing further in this epic — this is the last Grid & Terrain story. Downstream consumption (Board Renderer reading `GridState` for iso projection, AI Opponent's positional queries) belongs to other epics.*

---

## QA Test Cases

*Test cases not yet defined — run `/qa-plan` to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/grid_procedural_generation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 must be DONE
- Unlocks: None (last story in this epic)

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 5/5 passing (no deferred items)
**Deviations**: None. Advisory backlog (non-blocking):
- `proc_density_x100=0` boundary test (validates the integer-division density formula's lower bound).
- Non-symmetric determinism on the *no-thinning* happy path (only the thinning fixture covers non-symmetric determinism today).
- `test_generate_procedural_different_seeds_generally_differ` is a statistical (not structural) guarantee — negligible real flake risk.
- **Carry-forward from Story 003 (still open)**: W2 — `build_grid` places HQs with placeholder entity ids `0`/`1`; resolve in the GameState-wiring story (move HQ placement to `GameState.start_match()` with real `next_entity_id` values).
**Test Evidence**: Logic — `tests/unit/grid_procedural_generation_test.gd` (17 procedural cases; 75 total suite; 0 failures; exit 0). Code-review-added beyond the ACs: symmetric-thinning-determinism, all-Cover-high-density-skips-thinning; the terminal density-clamp branch was documented as a defensive backstop (unreachable under current invariants, kept per ADR-0005 TR-grid-012).
**Code Review**: Complete — `/code-review` run 2026-07-25, APPROVED WITH SUGGESTIONS. godot-gdscript-specialist ran a full determinism audit (seeded-instance-only RNG, draw-free mirroring, RNG-free ascending-index thinning — all clean, no blocking); qa-tester empirically confirmed the density-clamp test genuinely triggers thinning (60→54 Impassable, non-vacuous). Top set (1-3) applied; remainder backlogged above.
**Note**: Also removed the now-obsolete `test_build_grid_procedural_mode_returns_null_stub` from `tests/unit/grid_build_authored_test.gd` — that Story 003 stub-guard correctly began failing once the PROCEDURAL branch was implemented; procedural behavior is now covered by this story's test suite.
