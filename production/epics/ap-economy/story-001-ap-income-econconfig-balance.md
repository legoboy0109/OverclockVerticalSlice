# Story 001: AP Income Formula, EconomyConfig & Balance Autoload

> **Epic**: AP Economy
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/ap-economy.md`
**Requirement**: `TR-apecon-002`, `TR-apecon-003`, `TR-apecon-009`, `TR-apecon-010`, `TR-apecon-012`, `TR-apecon-013`, `TR-apecon-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: AP Economy Data Model & Spend Contract
**ADR Decision Summary**: `AP` is a static utility class (`class_name AP extends RefCounted`, no instance fields) whose functions take `GameState` explicitly. Tuning constants live in an `EconomyConfig` Resource (`.tres`), loaded once at boot by a thin logic-free `Balance` autoload and read via `Balance.economy` — never stored on `GameState` (so it never rides `duplicate_deep()`). `income()` = sum of `ap_income_breakdown()`'s three terms (base / outpost / econ_tech); `completed_outpost_count` and `economy_tech_income_bonus` are forward-declared cross-system calls.

**Secondary ADRs**:
- ADR-0012 (Faction identity fold): `ap_income` folds each player's additive faction income deltas (`Δ_base`/`Δ_tier1`/`Δ_tier2`) gated by a `BASE_INCOME_FLOOR` guard — no-op under the VS Neutral default (all deltas 0).
- ADR-0003 (Determinism): identical income inputs + ordered actions → bit-identical AP trajectory; no RNG; integer arithmetic only.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `EconomyConfig extends Resource` + `.tres` authoring is stable pre-cutoff. No post-cutoff API. `Balance` autoload mirrors the `MatchService` logic-free-lookup idiom (ADR-0001).

**Control Manifest Rules (this layer)**:
- Required: "`AP` must be a static utility class (`class_name AP extends RefCounted`) with only pure/static functions taking `GameState` explicitly — no instance fields" — source: ADR-0006
- Required: "Tuning constants must live in a dedicated `EconomyConfig` Resource (`.tres`), never as GDScript `const`s and never on `GameState`" — source: ADR-0006
- Required: "A thin, logic-free `Balance` Autoload must load `EconomyConfig` once at boot and expose it by reference — never mutating/validating/interpreting" — source: ADR-0006
- Required: "`Research.economy_tech_income_bonus()` returns the fully-capped term; callers must add it verbatim and never re-apply `ECONOMY_TECH_TIER_THRESHOLD`" — source: ADR-0006
- Required: "Non-negativity must be enforced by construction (`max(0, n)` floor)" — source: ADR-0006
- Required: "Fractional gameplay coefficients must be stored as scaled integers and computed via integer arithmetic" — source: ADR-0003 (all income terms are integer)
- Guardrail: "`AP.income()`/`ap_income_breakdown()` are O(1) integer arithmetic + two O(1) forward-declared reads; called a small constant number of times per turn (turn-reset, AI per-turn eval, HUD on start-of-turn), never per-frame or per-candidate — no perf concern" — source: ADR-0006, ADR-0003, ADR-0011, ADR-0016
- Forbidden: "Never use one shared `BalanceConfig` Resource for all systems' tuning constants" — source: ADR-0006
- Forbidden: "Never hardcode tuning constants as GDScript `const`s" — source: ADR-0006
- Forbidden: "Never thread an explicit `config: EconomyConfig` parameter through every `AP` call site" — source: ADR-0006 (`income(player)`, not `income(player, config)`)
- Forbidden: "Never have AP Economy iterate `entities_by_id` directly to count outposts" — source: ADR-0006 (call `BaseProduction.completed_outpost_count`)
- Forbidden: "Never call global `randi()`/`randf()`/… anywhere" — source: ADR-0003

---

## Acceptance Criteria

*From GDD `design/gdd/ap-economy.md`, scoped to this story:*

- [ ] **GIVEN** `n = 0` completed outposts, **WHEN** income is computed, **THEN** it returns 10 (floor `BASE_INCOME`).
- [ ] **GIVEN** `n = 4`, **THEN** income is 18; **GIVEN** `n = 5`, **THEN** 19 (5th outpost adds +1, not +2); **GIVEN** `n = 8`, **THEN** 22; **GIVEN** `n = 2`, **THEN** 14; **GIVEN** `n = 12`, **THEN** 26 (no Economy Tech).
- [ ] **GIVEN** `has_economy_tech = true` and `n = 4`, **THEN** income is 22 (base 18 + tech `min(4,6)=4`); **GIVEN** `n = 2`, **THEN** 16; **GIVEN** `n = 12`, **THEN** 32.
- [ ] **GIVEN** `has_economy_tech = true`, `n = 6` vs `n = 7`, **THEN** income is 26 vs 27 — the tech term stays capped at `×6`, proving the cap re-engages diminishing returns past the threshold.
- [ ] **GIVEN** `has_economy_tech = false` and `n = 8`, **THEN** income is 22 — the tech term contributes exactly 0 when the flag is false (regression guard against defaulting true / ignoring the flag).
- [ ] **GIVEN** `completed_outpost_count` returns a negative value (caller bug), **WHEN** income is computed, **THEN** `n` clamps to 0 and income returns 10, never below.
- [ ] **GIVEN** the income breakdown is read, **THEN** `base + outpost + econ_tech` equals `income()` exactly (the breakdown and total never drift), and it decomposes the frozen snapshot's terms.
- [ ] **GIVEN** the VS Neutral default (all faction deltas 0), **WHEN** income is computed, **THEN** the faction fold is a no-op (shipped numbers unchanged); a subtractive delta can never drive income below `BASE_INCOME_FLOOR`.

---

## Implementation Notes

*Derived from ADR-0006 Key Interfaces:*

```gdscript
# ap.gd — class_name AP extends RefCounted (no instance state)
static func ap_income_breakdown(state: GameState, player: int) -> Dictionary:
    var cfg: EconomyConfig = Balance.economy
    var n: int = max(0, BaseProduction.completed_outpost_count(state, player))
    var base: int = cfg.base_income
    var outpost: int = cfg.outpost_bonus_tier1 * min(n, cfg.tier_threshold) \
        + cfg.outpost_bonus_tier2 * max(0, n - cfg.tier_threshold)
    var econ_tech: int = Research.economy_tech_income_bonus(state, player)  # already capped; add verbatim
    return { "base": base, "outpost": outpost, "econ_tech": econ_tech }

static func income(state: GameState, player: int) -> int:
    var b: Dictionary = ap_income_breakdown(state, player)
    return b["base"] + b["outpost"] + b["econ_tech"]

# economy_config.gd — class_name EconomyConfig extends Resource
@export var base_income: int = 10
@export var outpost_bonus_tier1: int = 2
@export var outpost_bonus_tier2: int = 1
@export var tier_threshold: int = 4
@export var economy_tech_tier_threshold: int = 6
# (ECONOMY_TECH_INCOME_BONUS is Research-owned; lives in Research's config, not here.)

# balance.gd — Autoload, logic-free:
#   var economy: EconomyConfig = preload("res://.../economy_config.tres")  (or load once in _ready)
#   No methods beyond exposing `economy` by reference. No mutation/validation.
```

- **CRITICAL — do not double-apply the Economy Tech cap.** `Research.economy_tech_income_bonus()` already returns the fully-tiered, `has_economy_tech`-guarded, `ECONOMY_TECH_TIER_THRESHOLD`-capped term. AP adds it *verbatim*. Re-applying `min(n, threshold)` here squares the tier factor (the 2026-07-24 architecture-review C3 bug: bonus was 36 at n=6 instead of 6). Add, don't re-cap.
- **Faction fold (ADR-0012)**: fold `Δ_base`/`Δ_tier1`/`Δ_tier2` from the player's `FactionDef` into the respective terms, then apply the `BASE_INCOME_FLOOR` guard so a subtractive delta can't push income below the floor. Under Neutral all deltas are 0 → identity. Read the faction from `state.per_player[player].faction` (ADR-0001).
- **⚠️ Forward-declared cross-system calls (stub strategy — GDD Test Strategy + TR-apecon-014):** `BaseProduction.completed_outpost_count(state, player)` and `Research.economy_tech_income_bonus(state, player)` are owned by systems not yet built (ADR-0007 impl). In GDScript a call to an absent `class_name` won't parse, so create **thin stub classes** (`BaseProduction`/`Research` with just these static functions) that the unit test controls — e.g. `completed_outpost_count` returns a test-settable value, `economy_tech_income_bonus` computes the capped term from `has_economy_tech` + a stubbed count. Every AC above is testable *now* against these stubs; the real bodies replace them when those epics land. `has_economy_tech` is a `PlayerState` field (ADR-0001) — read directly, no call.
- All arithmetic is integer; no RNG anywhere.
- **Performance contract.** `income()` and `ap_income_breakdown()` are **O(1)** — a fixed handful of integer `+`/`×`/`min`/`max` ops over the tiered formula's terms, plus exactly one O(1) call each to the forward-declared `BaseProduction.completed_outpost_count(state, player)` and `Research.economy_tech_income_bonus(state, player)`, plus a constant-size faction fold (`Δ_base`/`Δ_tier1`/`Δ_tier2` read off one `FactionDef`). No loops, no allocation, no per-entity scan. They are called a **small constant number of times per turn** — the start-of-turn income snapshot (Story 003, once per player-turn), the AI's per-turn economic evaluation (ADR-0011 lists `AP.income(state, player)` among its per-turn reads), and the HUD income-breakdown panel (ADR-0016, driven by the `start_turn` signal, not per-frame) — never per-frame and never on the AI's per-candidate `clone()` path. No performance concern at any Vertical-Slice scale; turn-based play has no per-frame simulation deadline.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `can_afford`, `current_ap` facade, `spend`.
- Story 003: `reset_turn` (freeze snapshot), `discard`.
- The real `BaseProduction.completed_outpost_count` / `Research.economy_tech_income_bonus` bodies (entity-schema / Research epics) — this story uses stubs.
- The experiential "never quite enough" playtest AC and the Base&Production/Research integration test (separately tracked, not this epic's DoD).

---

## QA Test Cases

**Test file**: `tests/unit/ap_income_test.gd` (~15 unit tests)
**Requires shared fixtures**: `BaseProduction`/`Research` stubs — see
`production/qa/qa-plan-sprint-1-2026-07-26.md` "Shared Test Fixtures Required".

Every value below is a worked example from the GDD Formulas section
(`design/gdd/ap-economy.md` lines 122–165) — not invented:

- No Economy Tech: n=0→10, n=2→14, n=4→18, n=5→19 (tier boundary: 5th outpost adds +1 not +2),
  n=8→22, n=12→26.
- Economy Tech held: n=2→16, n=4→22, n=6→26, n=7→27 (tech term stays capped at ×6 — proves the
  cap re-engages diminishing returns past `ECONOMY_TECH_TIER_THRESHOLD`), n=8→28, n=12→32.
- Economy Tech flag false at n=8 → 22 (regression guard: tech term contributes exactly 0 when the
  flag is false, not silently defaulting true).
- `completed_outpost_count` returns a negative value → `n` clamps to 0, income returns 10.
- `ap_income_breakdown` — `base + outpost + econ_tech` equals `income()` exactly.
- VS Neutral faction default (all deltas 0) → faction fold is a no-op; a subtractive delta can
  never drive income below `BASE_INCOME_FLOOR`.
- **Regression guard for the 2026-07-24 architecture-review C3 bug**: tech term is added
  *verbatim*, never re-capped by AP — the n=6 vs n=7 test (26 vs 27, not 36 vs 6) is the direct
  regression test.

Edge cases: `n` exactly at `TIER_THRESHOLD` (4) and exactly at `ECONOMY_TECH_TIER_THRESHOLD` (6) —
boundary values are the point (coding-standard's boundary-value exception).

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/ap_income_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/ap_income_test.gd` (17 tests; 104/104 suite green)

---

## Dependencies

- Depends on: **GS Story 001** (GameState/PlayerState data model — `per_player[].faction`/`has_economy_tech`, `active_player`) must be DONE. **Stub dependency**: thin `BaseProduction`/`Research` stub classes for the two forward-declared calls (see note above).
- Unlocks: Story 002, Story 003

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 7/8 fully passing; AC-8 partial — its Neutral-default half (exactly 3 income terms, no fourth) is covered, its faction income-delta fold + `BASE_INCOME_FLOOR` half is DEFERRED per the governing ADR-0006 Risks section (explicitly punts the fold + floor to the Alpha faction-asymmetry prototype / ADR-0012). Building them now would contradict the ADR. Confirmed with the user before implementation.
**Deviations**:
- ADR-compliant partial-defer of AC-8 (above) — the implementation deliberately builds *less* than the story text to obey the governing ADR.
- `project.godot` `[autoload]` registration of `Balance` (outside the story's listed file set) — architecturally required by ADR-0006 (`AP` reads `Balance.economy` as a bare global, never a threaded config param). Valid, not scope creep.
- AC-5 layering: `AP.income()` never reads `has_economy_tech` (the flag-default guard lives in `Research` per ADR-0006). This story's test only proves AP is flag-agnostic/purely additive; the real "flag must not default true" regression belongs to the future Research epic's test suite.
**Test Evidence**: Logic — `tests/unit/ap_income_test.gd` (17 tests; full suite 104/104, exit 0). Includes the C3 double-cap regression guard (n6 vs n7 → 26/27) and a per-player-index guard added during code review.
**Code Review**: Complete — `/code-review` verdict APPROVED WITH SUGGESTIONS (godot-gdscript-specialist: CLEAN; qa-tester: solid coverage). Both convergent findings fixed pre-close: retargeted the misnamed flag-false test + added the player-index coverage test.
**Files**: `src/core/economy/{ap,economy_config,balance}.gd`, `data/balance/economy_config.tres`, `project.godot` (autoload line), `tests/unit/ap_income_test.gd`.
