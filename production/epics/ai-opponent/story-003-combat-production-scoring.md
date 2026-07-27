# Story 003: Verb Scoring — `combat_value`, `production_value`, `action_score`, Lethal Floor, HQ Siege

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-006` (partial — combat/production dispatch)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary, §1 `action_score` dispatch)
**ADR Decision Summary**: Each verb scores into one normalized `action_score` (AP-equivalent-value / AP-cost) via verb-dispatch (no hardcoded priority); a post-hoc lethal floor overrides the score of immediately-lethal actions.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure arithmetic over already-live queries (`preview_damage`, `legal_targets`, `legal_targets_from`, `legal_deploy_tiles`). No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: Each per-verb enumeration helper must call only the approved query surface and `AIConfig` — source: ADR-0011
- Required: `choose_action` must be pure, headless, side-effect-free — source: ADR-0011
- Required: The lethal floor must be a post-hoc override after scoring, never a pre-filter that short-circuits enumeration (CR-7) — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] `combat_value(attacker, target)` = `ap_cost_opponent_paid_for(target) × (hp_removed / target_max_hp) + (is_kill ? KILL_DENIAL_RATE × ap_cost_opponent_paid_for(target) : 0)`, reading `ap_cost_opponent_paid_for` **live** from the target's own `produce_cost`/`build_cost`, with `HQ_SIEGE_VALUE` (12) substituted only for the HQ (no `build_cost`)
- [ ] Worked Example 1 (non-lethal): Trooper atk 3 vs full-hp enemy Trooper hp 6 produce_cost 4 → `combat_value` = exactly 2.0, `action_score` (cost 2) = exactly 1.00 (AC-11)
- [ ] Worked Example 2 (lethal): same attack, target at 3/6 hp → `combat_value` = exactly 4.0, `base_score` = 2.00, floored `action_score` = exactly 3.50 (since 2.00 < `LETHAL_FLOOR_BONUS` 3.5) (AC-12)
- [ ] Worked Example 3 (HQ siege): Sniper eff-atk 7 vs HQ hp 40 def 2, non-lethal → `combat_value` ≈ 1.5, `action_score` (cost 2) ≈ 0.75, above `PASS_THRESHOLD` (AC-29)
- [ ] `production_value(unit_type, deploy_tile)` = `produce_cost(unit_type) × REACHABILITY_MULTIPLIER`, the multiplier selected by the 3-way deterministic contact-state test (reachable-this-turn=1.1, in-contact=1.0, isolated=0.9)
- [ ] Worked example: Trooper produce_cost 4, reachable-this-turn → `production_value` = 4.4, `action_score` (cost 4) = exactly 1.10 (AC-14)
- [ ] `action_score(action) = is_immediately_lethal(action) ? max(base_score, LETHAL_FLOOR_BONUS) : base_score`, applied post-hoc, never as a pre-filter (CR-7)
- [ ] Two competing lethal candidates are both scored normally first, THEN floored — verified by two lethal attacks with different `base_score` both flooring to the identical `LETHAL_FLOOR_BONUS` (feeds Story 005's tie-break)

---

## Implementation Notes

*Derived from ADR-0011 §1 + GDD Formulas:*

- These land inside `_score_move_and_attack_candidates` (combat_value, incl. the move+attack combo scored via `Combat.legal_targets_from(lookahead, unit, tile)` at `move_path_cost + attack_cost`) and `_score_production_candidates` (production_value) from Story 002's skeleton.
- `ap_cost_opponent_paid_for` must read the field live (`target.type.produce_cost` / `target.type.build_cost`), never a memorized/hardcoded table (GDD warns against drift). `HQ_SIEGE_VALUE` (12, from `AIConfig`) is the dedicated substitute — confirm the HQ is identifiable (a `StructureState` with no `build_cost`) before dispatching.
- `REACHABILITY_MULTIPLIER`'s 3-band is a code constant in `ai.gd`, not `AIConfig` (per Story 001). `is_immediately_lethal` is true only when `combat_value`'s inner `is_kill` is true.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `economy_value`/`research_value`/positional-move scoring — Story 004
- The tie-break comparator — Story 005; cadence-cap gating — Story 004
- AC-33's full-turn ordering scenario — Story 006 (once all verbs coexist)

---

## QA Test Cases

- **AC-11**: Given the worked non-lethal fixture, Then `combat_value`/`action_score` = exactly 2.0 / 1.00.
- **AC-12**: Given the worked lethal fixture, Then `combat_value`=4.0, `base_score`=2.00, floored `action_score`=3.50.
- **AC-29**: Given the HQ siege fixture, Then `ap_cost_opponent_paid_for(HQ)` resolves to `HQ_SIEGE_VALUE` (never 0/undefined), `combat_value`≈1.5, `action_score`≈0.75.
- **AC-14**: Given a unit at each of the three `REACHABILITY_MULTIPLIER` bands, Then `production_value` = `produce_cost×0.9`, `×1.0`, `×1.1` respectively.
- **AC-21 (value only)**: Given a move+attack combo candidate, Then it's scored via `legal_targets_from` at combined cost.
- **Edge**: `hp_removed` at the `MIN_DAMAGE=1` floor on a full-hp target → `combat_value` still strictly positive, never 0.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai-opponent/ai_combat_production_scoring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (enumeration skeleton)
- Unlocks: Story 004 (economy/research/positional completes the verb set), Story 005 (comparator needs real scores)
