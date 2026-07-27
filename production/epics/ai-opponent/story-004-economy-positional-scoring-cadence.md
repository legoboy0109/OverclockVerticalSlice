# Story 004: Verb Scoring — `economy_value`, `research_value` (Stubbed), Positional/Retreat/Cancel-Build, Cadence Cap

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-006` (remainder), `TR-ai-017` (positional/retreat scoring completion)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary, §1 `economy_investments_committed` parameter, §2 helper dispatch)
**ADR Decision Summary**: Economy, positional/retreat, and cancel-build scoring complete the verb set; the cadence cap is enforced via a caller-passed `economy_investments_committed` counter (never internal AI state); positional value is tiles-normalized (not per-AP).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure arithmetic (geometric decay sums) + already-live `manhattan_distance`/`reachable`. **`research_value` depends on `legal_research_targets` (Research/Tech epic — NOT implemented yet); stub the enumeration source to return no candidates until Research lands.**

**Control Manifest Rules (this layer)**:
- Required: The `economy_investments_committed: int` cadence-cap counter must be an explicit caller-passed parameter, never internal `AI` state — source: ADR-0011
- Required: Each per-verb enumeration helper must call only the approved query surface and `AIConfig` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] `economy_value(build_action)` = `raw_immediate_value(0) + Σ_{t=1}^{ECONOMY_HORIZON} marginal_ap_income(t) × ECONOMY_DECAY^t`, uncapped
- [ ] Worked example: player's 1st Economy Outpost, no Economy Tech → `economy_value` ≈ 7.06, `action_score` (cost 4) ≈ 1.765 (AC-15)
- [ ] Tier-1 vs tier-2 outpost: a tier-1 candidate (+2 AP/turn) strictly outscores a tier-2 candidate (+1 AP/turn) — no flattening (AC-16)
- [ ] **[STUBBED pending Research epic]** `research_value(tech)` formula implemented per spec (Attack/Defense on `TECH_VALUE_HORIZON`, Economy on `ECONOMY_HORIZON`, `projected_completed_outposts` counting in-flight outposts) but `_score_research_candidates` returns zero candidates until `Research.legal_research_targets` exists — documented gap, re-enable when Research lands
- [ ] Positional move-only scoring: `action_score = POSITIONAL_VALUE_PER_TILE_CLOSED × max(0, dist_before − dist_after) / tiles_moved` (tiles-normalized, NOT `/ move_path_cost`), distance to nearest live enemy; `+ SETUP_ADVANCE_BONUS` when `sets_up_attack_next_turn(dest)` is true
- [ ] Worked example: a Heavy (move_cost 3) and a Scout (move_cost 1) each advancing 3 tiles with no setup bonus both score **identically** ≈0.16 (AC-20)
- [ ] Retreat scoring: a unit at/below `RETREAT_HP_FRACTION` AND inside enemy next-turn threat range generates **only** a retreat candidate (`RETREAT_VALUE_PER_TILE_FLED × max(0, threat_dist_after − threat_dist_before) / tiles_moved`), never an advance/`SETUP_ADVANCE_BONUS` candidate (anti-oscillation) (AC-31)
- [ ] `cancel_build_value = CANCEL_REFUND_RATE × build_cost(structure)`, `action_score(cancel_build) = cancel_build_value` directly (no AP-cost division) (AC-22)
- [ ] Cadence cap: once `economy_investments_committed >= AIConfig.max_economy_investments_per_turn`, economy-build and research-start candidates are excluded from this pass's enumeration entirely (not merely down-scored) (AC-30, single-pass)

---

## Implementation Notes

*Derived from ADR-0011 §1/§2 + GDD Formulas/Edge Cases:*

- `_score_build_and_economy_candidates` dispatches `production_value`-style scoring (Story 003) for non-economy structures vs `economy_value` for Economy Outposts, gated by `economy_investments_committed >= AIConfig.max_economy_investments_per_turn`.
- `_score_research_candidates` — implement the math now (so it's ready) but gate the enumeration source (`Research.legal_research_targets`) behind a documented stub returning `[]`. **Surface this explicitly to the user/lead-programmer as a deferred integration point**, not silently skip it.
- `_score_move_and_attack_candidates` (extended from Story 002/003) adds the positional/retreat two-term model reading `GridState.manhattan_distance` + `Movement.reachable`'s frontier — `sets_up_attack_next_turn` reuses the reachability/target machinery already computed this loop (no separate lookahead search).
- Wounded-unit exclusion must be checked **before** generating advance candidates (an excluded unit generates zero advance candidates, not a suppressed one).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Actual Research epic implementation (owned elsewhere — this is the stub's re-enable point)
- The tie-break comparator — Story 005
- `AITurnDriver`'s cadence-counter *increment* logic — Story 006 (this story only consumes the passed-in counter)
- Deferred OQ items: opponent-aware weighting (OQ-7), baitability counter-check (OQ-8), cancel-build threat-awareness (OQ-3)

---

## QA Test Cases

- **AC-15**: Given the worked Economy Outpost #1 example, Then `economy_value`≈7.06, `action_score`≈1.765.
- **AC-16**: Given a tier-1 and a tier-2 outpost candidate, Then tier-1's `economy_value` is strictly greater.
- **AC-20**: Given a Heavy and a Scout each making a full-distance standing-start advance, Then both compute the same `action_score`.
- **AC-32**: Given a setup move vs a non-setup move, Then the setup move scores strictly higher via `+SETUP_ADVANCE_BONUS`.
- **AC-31**: Given a wounded (≤`RETREAT_HP_FRACTION`), threatened unit, Then only a retreat candidate is generated, no advance.
- **AC-22**: Given an under-construction structure, Then `action_score(cancel_build) = CANCEL_REFUND_RATE × build_cost` with no cost division.
- **AC-30 (single-pass)**: Given more than `MAX_ECONOMY_INVESTMENTS_PER_TURN` clearing economy/research candidates, Then at most that many are enumerated as economy/research candidates this pass.
- **Edge (research stub)**: Given a Lab and a tech target pre-Research-epic, When `_score_research_candidates` runs, Then it returns no candidates without error (documented gap, not a silent wrong value).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai-opponent/ai_economy_positional_scoring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002/003. **Research-dependent enumeration is stubbed** (Research/Tech epic not implemented — flag raised for re-enable).
- Unlocks: Story 005 (comparator needs the full verb set scored)
