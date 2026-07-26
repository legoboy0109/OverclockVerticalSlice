# Story 003: AP reset_turn & discard — Start-of-Turn Freeze / End-of-Turn Discard

> **Epic**: AP Economy
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/ap-economy.md`
**Requirement**: `TR-apecon-004`, `TR-apecon-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: AP Economy Data Model & Spend Contract
**ADR Decision Summary**: `AP.reset_turn(state, player)` writes the frozen `income_this_turn` snapshot (`= income(state, player)`) and sets `current_ap` to it — evaluated once per start-of-turn, held fixed for the whole turn (no mid-turn recompute). `AP.discard(state, player)` hard-writes `current_ap := 0` (end-of-turn, no banking). Both are invoked by ADR-0008's start-of-turn sequence at the correct point (after the build-timer advance).

**Secondary ADRs**:
- ADR-0008 (Start-of-turn sequencing): `reset_turn` is step 4 of `GameState.start_turn` — it runs *after* step 3's build/research timer advances, so a just-completed Economy Outpost counts toward income this same turn. `discard` is called by `EndTurnAction.apply()` before switching players.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff — integer field writes on `PlayerState`.

**Control Manifest Rules (this layer)**:
- Required: "`AP.reset_turn()`/`AP.discard()` must be called only from the start-of-turn sequence" — source: ADR-0006
- Required: "`AP` must be a static utility class with only pure/static functions taking `GameState` explicitly" — source: ADR-0006
- Required: "The step-4 income snapshot must observe structures/techs completed in step 3 this same turn (never reorder step 4 before step 3)" — source: ADR-0008
- Forbidden: "Never put `income()`/`spend()`/`can_afford()` directly on `GameState`/`PlayerState`" — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/ap-economy.md`, scoped to this story:*

- [ ] **GIVEN** a player's start-of-turn reset, **WHEN** `reset_turn` runs, **THEN** `income_this_turn` is set to `income(state, player)` and `current_ap` is set equal to it (frozen snapshot).
- [ ] **GIVEN** an outpost completes before a player's reset, **WHEN** `reset_turn` runs, **THEN** the new `income_this_turn` includes that outpost's tiered bonus (snapshot observes the completed count).
- [ ] **GIVEN** an outpost is built *this* turn (now under construction), **WHEN** income is evaluated for the current turn, **THEN** `income_this_turn` is unchanged — no mid-turn recompute; only completed outposts count.
- [ ] **GIVEN** a player's `income_this_turn` was frozen at 18 and one of those outposts is destroyed during the opponent's turn, **WHEN** `income_this_turn` is read again before this player's next reset, **THEN** it still returns 18; only the **next** `reset_turn` drops it (frozen income is immune to same-turn increase **and** decrease).
- [ ] **GIVEN** a player ends their turn with `current_ap = 4`, **WHEN** `discard` resolves, **THEN** `current_ap` is set to **0** (not merely "irrelevant") and remains 0 through the opponent's turn until this player's next reset.
- [ ] **GIVEN** a player ends the turn with unspent AP, **WHEN** the next turn begins via `reset_turn`, **THEN** it starts at `income`, never `income + leftover` (no banking).
- [ ] **GIVEN** `reset_turn` is called twice for the same player in the same turn with no intervening `discard`, **WHEN** the second call runs, **THEN** it re-evaluates `income()` fresh and overwrites both `income_this_turn` and `current_ap` with the new snapshot (last-write-wins; no accumulation, no banking across the two calls) — e.g. first call freezes 18, an outpost then completes, second call overwrites to 24, not 42.

---

## Implementation Notes

*Derived from ADR-0006 Key Interfaces:*

```gdscript
static func reset_turn(state: GameState, player: int) -> void:
    var ps: PlayerState = state.per_player[player]
    ps.income_this_turn = income(state, player)   # frozen snapshot for the whole turn (Story 001's income())
    ps.current_ap = ps.income_this_turn

static func discard(state: GameState, player: int) -> void:
    state.per_player[player].current_ap = 0        # end-of-turn discard, no banking
```

- `reset_turn` calls Story 001's `income()` exactly once and stores the result in `income_this_turn` — this is the **freeze**. Nothing recomputes income mid-turn; the HUD breakdown (Story 001) decomposes this frozen snapshot, not a live re-eval.
- `discard` is a hard, observable write to 0 (the GDD is explicit it must be literally 0, not just "treated as irrelevant") so no stale positive balance survives into the opponent's turn.
- These two functions are the **writers** that ADR-0008's `GameState.start_turn` (step 4) and `EndTurnAction.apply()` call — implementing them here **unblocks GS Story 003** (which references `AP.reset_turn`/`AP.discard`). This story implements the AP-side functions only; the *timing* (when they're called) is owned by GS Story 003.
- Testing: exercise the freeze by setting the stubbed `completed_outpost_count` to 4, calling `reset_turn` (income frozen at 18), then flipping the stub to 5 and asserting `income_this_turn` is still 18 until the next `reset_turn` (mirror for a decrease to 3 → still 18 until next reset). No real Base&Production/Research needed — use the same stubs as Story 001.
- Integer only; no RNG.
- **Performance**: O(1). `reset_turn` is two field writes on `PlayerState` plus one `income()` call (itself O(1) per Story 001 — bounded outpost/tech term, no scan); `discard` is a single field write. Both run **once per player per turn** via ADR-0008 step 4 and `EndTurnAction`, not on any per-action or per-frame path — no performance budget concern. (Contrast Story 002's `spend`/`can_afford`, which *are* the hot per-action AP path.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `income`/`ap_income_breakdown`/`EconomyConfig`/`Balance` (this story calls `income()`).
- Story 002: `spend`/`can_afford`.
- The *timing* of when `reset_turn`/`discard` are called — owned by GS Story 003's `start_turn`/`EndTurnAction` (ADR-0008). This story provides the functions; GS wires the calls.

---

## QA Test Cases

**Test file**: `tests/unit/ap_reset_discard_test.gd` (~9 unit tests)
**Requires shared fixtures**: `BaseProduction`/`Research` stubs — see
`production/qa/qa-plan-sprint-1-2026-07-26.md` "Shared Test Fixtures Required".

- `reset_turn` sets `income_this_turn = income(state, player)` and `current_ap` equal to it
  (frozen snapshot).
- Outpost completes before reset → new `income_this_turn` includes its tiered bonus.
- Outpost built *this* turn (under construction) → `income_this_turn` unchanged this turn.
- **Frozen-immune-to-increase**: `income_this_turn` frozen at 18; stub flips completed count up
  mid-turn → still reads 18 until the *next* `reset_turn`.
- **Frozen-immune-to-decrease**: `income_this_turn` frozen at 18; an outpost is destroyed
  (stub count drops) during the opponent's turn → still reads 18 until this player's next reset.
- `discard` sets `current_ap` to exactly **0** and it stays 0 through the opponent's turn until
  this player's next `reset_turn`.
- No banking: player ends turn with unspent AP → next turn starts at `income`, never
  `income + leftover`.

Edge case: `reset_turn` called twice in a row without an intervening `discard` — second
call overwrites (last-write-wins); assert no accumulation of `income_this_turn`/`current_ap`.

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/ap_reset_discard_test.gd` — must exist and pass

**Status**: [x] Created — 12 tests, all passing

---

## Dependencies

- Depends on: Story 001 (`income()`), **GS Story 001** (PlayerState.current_ap/income_this_turn). Uses the same forward-declared `BaseProduction`/`Research` stubs as Story 001.
- Unlocks: **GS Story 003** (Turn FSM `start_turn`/`EndTurnAction` call these writers)

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 7/7 passing (all COVERED, none deferred)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/ap_reset_discard_test.gd` (12 tests, full suite 130/130 pass, exit 0)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS; both suggestions (discard-on-zero idempotence, interposed-spend-then-reset) applied and re-verified before close
