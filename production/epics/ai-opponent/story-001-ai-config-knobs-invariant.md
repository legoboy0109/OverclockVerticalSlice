# Story 001: `AIConfig` — 15 Tunable Knobs + Cross-Knob Invariant Enforcement

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Complete (with notes — AC-3 advisory deviation)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-007`, `TR-ai-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary, §6); ADR-0006 (`gameplay_config_storage` pattern precedent)
**ADR Decision Summary**: All 15 AI scoring weights live on a `AIConfig` Resource loaded by the same thin Balance-style Autoload as the other configs; the loader enforces the cross-knob invariant `lethal_floor_bonus > economy_ceiling_score` with a release-surviving guard, never a bare `assert()`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure `Resource` config, identical pattern to shipped `EconomyConfig`/`UnitConfig`/`CombatConfig`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `AIConfig` must hold exactly 15 externally-tunable `@export` knobs, loaded by the same thin Balance-style Autoload — source: ADR-0011
- Required: `REACHABILITY_MULTIPLIER`'s fixed 3-band and `CANCEL_REFUND_RATE` must NOT be `AIConfig` fields — source: ADR-0011
- Required: The cross-knob invariant `lethal_floor_bonus > economy_ceiling_score` must be enforced at config load with a release-surviving guard, never a bare `assert()` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] `AIConfig` extends `Resource`, exposes exactly these 15 `@export` fields (ADR-0011 §6): `hp_per_ap`, `kill_denial_rate`, `economy_horizon`, `tech_value_horizon`, `economy_decay`, `max_economy_investments_per_turn`, `lethal_floor_bonus`, `pass_threshold`, `attacks_landed_per_turn_estimate`, `positional_value_per_tile_closed`, `setup_advance_bonus`, `retreat_hp_fraction`, `retreat_value_per_tile_fled`, `hq_siege_value`, `score_tie_epsilon` (`commit_pacing_sec` also lives here per ADR-0011 but is not one of the 15 GDD-named scoring knobs)
- [ ] `REACHABILITY_MULTIPLIER`'s fixed `{0.9, 1.0, 1.1}` band is a code constant inside `AI`, NOT an `AIConfig` field; `CANCEL_REFUND_RATE` is read from `BaseProductionConfig`, NOT duplicated here
- [ ] Loaded via the same thin Balance-style Autoload used for `EconomyConfig`/`UnitConfig`/`CombatConfig` — no new loader Autoload class introduced
- [ ] At load time, the loader computes `economy_ceiling_score = OUTPOST_BONUS_TIER1 × Σ_{t=1}^{economy_horizon} economy_decay^t / first_economy_outpost.build_cost` and enforces `lethal_floor_bonus > economy_ceiling_score` with a release-surviving guard (`push_error` + hard failure, NOT a bare `assert()`)
- [ ] Constructing an `AIConfig` with `economy_horizon`/`economy_decay` raised toward safe-range maxima without raising `lethal_floor_bonus` fails the load-time check (regression for TR-ai-008)
- [ ] Default values match the GDD Tuning Knobs table exactly (spot-check: `pass_threshold`=0.15, `lethal_floor_bonus`=3.5, `economy_horizon`=6, `economy_decay`=0.85, `score_tie_epsilon`=1e-6)

---

## Implementation Notes

*Derived from ADR-0011 §6:*

- File `src/gameplay/ai/ai_config.gd`, `class_name AIConfig extends Resource`. Mirror the exact `gameplay_config_storage` shape from `CombatConfig`/`EconomyConfig`.
- The invariant check belongs in the Balance-style loader Autoload (not inside `AIConfig`, which stays a pure data Resource) — confirm which Autoload currently loads `CombatConfig`/`EconomyConfig`/`UnitConfig` and add `AIConfig` loading there ("loaded by the **same** thin Balance-style Autoload").
- The `economy_ceiling_score` formula is given verbatim in the GDD's `LETHAL_FLOOR_BONUS` tuning-knob row and the `action_score` symbol table (~1.77 at defaults, ~3.81 at safe-range maxima).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The `AI.choose_action` enumeration/scoring logic — Stories 002–005
- `MAX_ECONOMY_INVESTMENTS_PER_TURN` cadence-cap *enforcement* — Story 004 (this story only stores the knob)

---

## QA Test Cases

- **AC (defaults pass)**: Given default `AIConfig` values, When loaded, Then the invariant check passes silently.
- **AC-8 (violation fails)**: Given `economy_horizon=10, economy_decay=0.95, lethal_floor_bonus=3.5`, When loaded, Then the load-time guard fails loudly (the documented ≈3.81 > 3.5 violation).
- **AC (release-surviving)**: Given the bad config, When loaded, Then the failure fires via `push_error`/hard-fail (assert the guard mechanism is not a bare `assert()` — code-level check).
- **Edge**: `economy_horizon`=4, `economy_decay`=0.7 (floors) — invariant holds trivially.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai-opponent/ai_config_invariant_test.gd` — must exist and pass

**Status**: [x] Created + passing — `tests/unit/ai-opponent/ai_config_invariant_test.gd` (6 fns, 6/6 PASS)

---

## Dependencies

- Depends on: None new (Base & Production's `CANCEL_REFUND_RATE` on `BaseProductionConfig` already exists — confirmed readable at `BaseProductionConfig.cancel_refund_pct`)
- Unlocks: Stories 002–005 (all read `AIConfig`)

---

## Completion Notes
**Completed**: 2026-07-27 (Complete with notes)
**Criteria**: 6/6 covered by automated tests — 15 `@export` knobs + `commit_pacing_sec` present at exact GDD defaults (`pass_threshold`=0.15, `lethal_floor_bonus`=3.5, `economy_horizon`=6, `economy_decay`=0.85, `score_tie_epsilon`=1e-6); load-time invariant holds at defaults (ceiling ≈1.76), fails at safe-range maxima (`horizon=10, decay=0.95` → ≈3.81 > 3.5); guard is release-surviving; `REACHABILITY_MULTIPLIER`/`CANCEL_REFUND_RATE` correctly NOT fields.
**Implementation**: `src/gameplay/ai/ai_config.gd` (pure `Resource`), `data/ai/ai_config.tres`, `src/gameplay/ai/ai_balance.gd` (new `AIBalance` Autoload holding the invariant check), `project.godot` (autoload registration). Invariant guard = `push_error()` + `OS.crash()` (survives release exports; NOT a bare `assert()` which compiles out).
**Test Evidence**: Logic — `tests/unit/ai-opponent/ai_config_invariant_test.gd` (6 fns, 6/6 PASS; full suite 524/524, no regressions).
**Deviations (ADVISORY)**: Story AC-3 / the manifest rule say "loaded via the **same** thin Balance-style Autoload... no new loader class," assuming a single shared Balance loader. The codebase actually uses **per-domain sibling autoloads** (`Balance`/`UnitBalance`/`CombatBalance`/`StructureBalance`), so a new `AIBalance` sibling is the architecturally-consistent continuation — not a new *kind* of loader. Deviation recorded in `ai_balance.gd`'s header. → Non-blocking; consider a one-line touch-up to ADR-0011 §6 / this AC's wording to reflect the per-domain reality.
**Code Review**: not separately run (specialist-authored, fully test-covered); recommend a light pass at sprint close-out.
