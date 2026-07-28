# Story 005: Deterministic Tie-Break Comparator + Cross-Verb `action_score` Comparison (`_is_better`)

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (2h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Deterministic Simulation (primary — Rule 4, deterministic tie-break); ADR-0011 (secondary — §2 `_is_better` comparator shape)
**ADR Decision Summary**: Selection is fully deterministic — no RNG; the highest `action_score` wins regardless of verb, and ties within `SCORE_TIE_EPSILON` break by lowest `ap_cost`, then lowest `entity_id`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure comparator logic, float epsilon comparison, integer tie-break keys. No engine API.

**Control Manifest Rules (this layer)**:
- Required: The tie-break comparator must resolve ties within `score_tie_epsilon` by lowest `ap_cost`, then lowest `entity_id` — source: ADR-0011
- Forbidden: No engine RNG anywhere in the tie-break; ties are integer-keyed, never randomized — source: ADR-0003

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] `_is_better(score, ap_cost, entity_id, best_score, best_ap_cost, best_entity_id)` implements exactly: `score > best_score + SCORE_TIE_EPSILON → true`; `score < best_score − SCORE_TIE_EPSILON → false`; else (tied within epsilon) → `ap_cost != best_ap_cost ? ap_cost < best_ap_cost : entity_id < best_entity_id`
- [ ] Given candidates of ≥3 different verbs (move, attack, produce) with distinct `action_score` in the same evaluate step, the highest-scoring candidate is selected regardless of verb — never a fixed verb-priority order (AC-4)
- [ ] Given two candidates whose scores differ by less than `SCORE_TIE_EPSILON` (incl. two lethal attacks both floored to identical `LETHAL_FLOOR_BONUS`), the lower-`ap_cost` one is selected; on a further `ap_cost` tie, the lower `entity_id` (AC-23)
- [ ] Given the five-candidate cross-verb scenario (lethal 3.50 → Outpost 1.765 → Production 1.10 → non-lethal 1.00 → Attack Tech 0.236), the comparator selects them in that exact score-descending order across successive calls (AC-18, comparator slice)
- [ ] Replaying an identical tie scenario on the same build always selects the same candidate (no randomness)

---

## Implementation Notes

*Derived from ADR-0011 §2 + ADR-0003 Rule 4:*

- This is the `_is_better` static comparator, used by every per-verb helper's running-best fold.
- Because entity IDs come from a monotonic counter, an exact tie resolves to the *oldest* eligible entity — document this as intentional (per the GDD Edge Cases), not a latent bug.
- This story does NOT run the full evaluate→commit *loop* (Story 006) — it validates the comparator in isolation across a single enumeration pass with pre-scored candidates, plus the cross-verb worked-example ordering as a multi-call sequence.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The `while` loop / re-cloning / commit mechanics — Story 006
- `apply_action` rejection handling — Story 006

---

## QA Test Cases

- **AC-4**: Given two candidates scoring 1.00 (attack) and 2.00 (produce), Then the comparator selects the produce candidate (no verb-priority bias).
- **AC-23 (ap_cost)**: Given two lethal attacks both floored to 3.50 with `ap_cost` 2 and 3, Then the `ap_cost`=2 candidate is selected.
- **AC-23 (entity_id)**: Given two candidates tied on score and `ap_cost`, `entity_id` 7 and 3, Then `entity_id`=3 is selected.
- **AC-18**: Given the five-candidate GDD scenario, Then the ordering is exactly lethal→Outpost→Production→non-lethal→AttackTech.
- **Edge**: two scores differing by exactly `SCORE_TIE_EPSILON` — confirm which side of the tie line this lands on (`>` not `>=`) and document the boundary in the test.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai-opponent/ai_tiebreak_determinism_test.gd` — must exist and pass

**Status**: [x] Created + passing — `tests/unit/ai-opponent/ai_tiebreak_determinism_test.gd` (10 fns, 10/10 PASS)

---

## Dependencies

- Depends on: Stories 003/004 (needs real multi-verb scores to compare)
- Unlocks: Story 006 (the loop calls this comparator every enumeration step)

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: `_is_better` implements the exact three-tier logic (AC-1: `score > best+ε` → true; `< best−ε` → false; else `ap_cost` then `entity_id`) and is wired into all six `_score_*` running-best folds (replacing bare `score > best.score`). AC-4 (highest score wins regardless of verb — comparator is verb-agnostic by construction); AC-23 (within-ε tie → lower ap_cost, then lower/oldest entity_id, incl. two lethal both floored to 3.50); AC-18 (five-candidate cross-verb scenario resolves in exact descending order lethal 3.50 → Outpost 1.765 → Production 1.10 → non-lethal 1.00 → AttackTech 0.236, order-independent); determinism (pure, no RNG — ADR-0003 Rule 4); ε boundary (a score exactly +`score_tie_epsilon` is a TIE, not strictly better — the `>` is strict).
**Implementation**: `src/gameplay/ai/ai.gd` — `_is_better(score, ap_cost, entity_id, best_score, best_ap_cost, best_entity_id)` + wiring into every helper's fold + the empty-best case.
**Test Evidence**: Logic — `tests/unit/ai-opponent/ai_tiebreak_determinism_test.gd` (10 fns, 10/10 PASS; full suite 611/611, no regressions). *Test authored by the orchestrator after the implementing agent truncated before writing it; implementation + wiring by ai-programmer, verified 601→611 green.*
**Deviations**: None. ai-002/003/004 scoring + contracts unchanged.
**Code Review**: not separately run (test-covered against the exact AC-1 spec); recommend a light pass at sprint close-out.
