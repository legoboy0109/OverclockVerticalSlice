# Story 008: Integration — Real `apply_action` End-to-End, Move-Then-Attack, HQ Destruction, Real-Grid LoF

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-005` (integration half), `TR-combat-008` (end-to-end composition)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: This story wires no new logic — it proves everything Stories 001–007 built (damage, targeting, the attack pipeline, destruction, counter, determinism) composes correctly through the **real** `GameState.apply_action()` dispatch, with a **real** `GridState`, **real** `AP`, and (where relevant) a real Movement combo, rather than direct `Combat.validate()`/`Combat.apply()` calls against hand-built fixtures. This is the epic's Integration gate — GDD-required as **BLOCKING** (same as the Pure Logic gate) because it exercises real dependencies the Logic gate deliberately fakes.

**Secondary ADRs**: ADR-0002 (`apply_action`'s full 7-step pipeline, including `run_win_check` and the `action_applied` signal), ADR-0009 (Movement — the move-then-attack/attack-then-move composition), ADR-0005 (real `GridState` LoF)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: No new engine API surface — this story exercises already-verified engine-safe code paths end-to-end.
**Performance**: N/A — no new production code. This is a test-only integration pass composing already-shipped, already-budgeted `GameState.apply_action()`, `Combat.*`, `AP.*`, and `Movement.*` calls end-to-end; their performance is covered by the ADR-0002 / ADR-0009 / ADR-0010 Performance sections. The tests use `GameStateFactory`-built states over a real `GridState` (no large-map generation, no per-frame path).

**Control Manifest Rules (this layer)**:
- No new rules — this story is a composition/integration proof over rules already enforced by Stories 001–007 and by `GameState.apply_action`'s existing 7-step pipeline (ADR-0002).

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story (the Integration gate):*

- [ ] A legal, affordable attack, routed through `apply_action` → AP pool, `has_attacked`, and target hp all reflect one atomic commit
- [ ] An unaffordable attack, routed through `apply_action` → the real pool and Grid are unchanged
- [ ] Enough AP to move and attack → both **move-then-attack** and **attack-then-move** succeed the same turn with correct AP deduction
- [ ] An enemy HQ at hp = the attacker's damage → the attack resolves, HQ hp → 0, Turn Manager's win-check fires `GameOver(winner = opponent)` **in the same action**, and any subsequent action (either side) is rejected
- [ ] A real Grid with a real ally 1 tile away and a real enemy 2 tiles away → a Trooper (range 2) targeting down that line returns no target (LoF holds against the real Grid, not a fixture)
- [ ] A real fixture where a `can_counterattack` defender survives an in-range attack, resolved through the real pipeline → both primary and counter hp changes are present in the authoritative state after `apply_action` returns

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Register `Action.Verb.ATTACK` was already done in Story 004 (`GameState._ensure_dispatch_registered()`); this story adds no new registration — it only calls `state.apply_action(action)` with a real `AttackAction` instead of calling `Combat.validate`/`Combat.apply` directly.
- Use `GameStateFactory` (`tests/helpers/game_state_factory.gd`, already shipped — used throughout the Unit/Movement/GS test suites) to build a real state with a real `GridState`, real `UnitState`/`UnitTypeDef` entities (the actual VS roster via `UnitTypes.SCOUT`/`.TROOPER`/etc., not throwaway fixtures — this is the Integration gate's point: real registry-backed data, not injected doubles), and real `PlayerState`/AP pools.
- Move-then-attack / attack-then-move: construct one `MoveAction` and one `AttackAction` (using the same unit, same turn) and submit both through `state.apply_action()` in each order, asserting both orders succeed with the AP pool correctly reflecting `move_cost + attack_cost` regardless of sequence — this directly exercises the GDD's Rule 2 ("movement is never gated by has_attacked, and attacking never sets movement state").
- HQ-destruction end-to-end: place a real HQ-like fixture as the defender (this story can use the same extended `structure_state_stub.gd` from Story 005 — the real `StructureState` still doesn't exist since Base & Production hasn't landed; "real" in this story's scope means "real `GameState`/`GridState`/`apply_action` dispatch," not "real Base & Production entity classes," which remain out of scope project-wide until that epic ships). Set the HQ's `current_hp` equal to the attacker's precomputed `Combat.damage(...)` value, submit the `AttackAction` through `apply_action`, and assert: `result.ok == true`, `state.match_status == GameState.MatchStatus.GAME_OVER`, `state.winner` is the attacker's owner, and a **second** `apply_action` call (either player) is rejected with `Action.Reason.GAME_OVER` and an empty events array — mirroring `win_check_terminal_test.gd`'s existing `test_hq_destroyed_through_apply_action_end_to_end_...` test shape, but driven by the *real* Combat pipeline instead of a throwaway registered verb.
- Real-Grid LoF: build an actual 3-tile cardinal line in a real `GridState` (ally at distance 1, enemy at distance 2, attacker at distance 0, a Trooper with `attack_range = 2`), call `Combat.legal_targets()` (or route the whole thing through `apply_action` with an `AttackAction` targeting the enemy and assert `validate()`'s rejection) against the real grid, proving the LoF walk correctly reads real `GridState.occupant_at`/`terrain_at`, not a mocked grid.
- Counter through the real pipeline: reuse Story 006's counter-fixture shape (a throwaway `can_counterattack = true` `UnitTypeDef`) but drive it through `state.apply_action(attack_action)` rather than a direct `Combat.apply()` call, then assert both `target.current_hp` (primary) and the *original attacker's* `current_hp` (counter) reflect the expected post-pipeline values by reading them back off `state.entities_by_id`, proving the counter's effects are visible in the authoritative state after the full `apply_action` round-trip (not just in a locally-returned events array).
- This story's tests belong in `tests/integration/combat/` (mirroring `tests/integration/movement/movement_determinism_test.gd`'s placement) — this is the one Combat test file that legitimately exercises real cross-system composition rather than injected fixtures, consistent with the project's Logic-vs-Integration test-directory convention (`tests/README.md`).

---

## Out of Scope

*Nothing further to defer — this is the epic's final story. Any gap discovered here that traces back to a genuine bug in Stories 001–007 should be fixed in this story with a note referencing which earlier story's code changed, not worked around here.*

---

## QA Test Cases

- **AC-1 (atomic commit via real apply_action)**: Given a legal, affordable `AttackAction` submitted via `state.apply_action()`, When it resolves, Then `result.ok == true` and the real AP pool, `has_attacked`, and target `current_hp` all reflect the single commit.

- **AC-2 (unaffordable attack leaves real state untouched)**: Given an `AttackAction` submitted with insufficient real AP, When `state.apply_action()` resolves, Then `result.ok == false`, and the real AP pool / Grid / target hp are all byte-for-byte unchanged from before the call.

- **AC-3 (move-then-attack and attack-then-move, both orders)**: Given a unit with enough AP for both a move and an attack this turn, When a `MoveAction` then an `AttackAction` are submitted (and, separately, the reverse order), Then both orders succeed and the final AP pool is identical regardless of order.

- **AC-4 (HQ destruction → GameOver → lockout, real pipeline)**: Given a real HQ-stand-in fixture at `current_hp == damage`, When the killing `AttackAction` is submitted via `apply_action`, Then `match_status` becomes `GAME_OVER` with the correct winner in that same call, and a subsequent `apply_action` call from either player is rejected `Action.Reason.GAME_OVER` with empty events.

- **AC-5 (real-Grid LoF)**: Given a real 3-tile line (attacker, ally at 1, enemy at 2) with a range-2 Trooper, When `legal_targets()`/`validate()` is evaluated against the real `GridState`, Then no target is returned/the attack is rejected — the ally genuinely blocks via real grid occupancy, not a fixture stand-in.

- **AC-6 (counter visible in authoritative state post-apply_action)**: Given a `can_counterattack` defender fixture that survives an in-range attack submitted via `apply_action`, When the call returns, Then both the target's hp-loss (primary) and the original attacker's hp-loss (counter) are readable directly off `state.entities_by_id` — not just present in a locally-scoped events array.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/combat/combat_apply_action_integration_test.gd` — must exist and pass

**Status**: [x] Created and passing (8 tests, full suite 343/343)

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003, Story 004, Story 005, Story 006, Story 007 (all must be DONE — this story composes the complete pipeline)
- Unlocks: None within this epic — this is the epic's closing story. Downstream: Command & Action Interface (#9)/Game HUD (#10)/AI Opponent (#11) may now build against a fully-implemented `legal_targets`/`preview_damage`/`attack` surface.

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 6/6 passing (all COVERED by tests, no deferrals)
**Deviations**: None — no new production code required; `apply_action`/`Combat`/`Movement`/`AP` already composed correctly as designed
**Test Evidence**: Integration — `tests/integration/combat/combat_apply_action_integration_test.gd` (8 test functions: 6 AC-covering + 1 strengthened AC-4 lockout proof + 1 supporting `NOT_ACTIVE_PLAYER` orchestration test); full suite 343/343 passing
**Code Review**: Complete — `/code-review` initial verdict APPROVED WITH SUGGESTIONS; both suggestions (strengthened AC-4 lockout proof, added `NOT_ACTIVE_PLAYER` test) applied and re-verified → final verdict APPROVED

**Epic status**: Combat Resolution epic is now 8/8 Complete.
