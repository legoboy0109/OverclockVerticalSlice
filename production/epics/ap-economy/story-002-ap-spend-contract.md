# Story 002: AP Spend Contract — can_afford & spend

> **Epic**: AP Economy
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/ap-economy.md`
**Requirement**: `TR-apecon-001`, `TR-apecon-006`, `TR-apecon-007`, `TR-apecon-008`, `TR-apecon-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: AP Economy Data Model & Spend Contract
**ADR Decision Summary**: `AP.can_afford(state, player, amount)` is a pure query (no mutation, no active-player gate — safe to ask about any player). `AP.spend(state, player, amount)` is the sole mutator of `current_ap`: atomic, active-player-gated (Rule 7), rejects `amount < 0` and `amount > current_ap`, treats `amount == 0` as a no-op success. `AP.current_ap(state, player)` is a thin read facade over `PlayerState.current_ap`. `current_ap` is written by exactly two paths — the start-of-turn reset (Story 003) and `spend()`.

**Secondary ADRs**:
- ADR-0003 (Determinism): spends are sequential within the single-action path; same income + ordered spends → identical trajectory; no RNG; integer only.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff — pure integer field mutation on `PlayerState`.

**Control Manifest Rules (this layer)**:
- Required: "`AP.can_afford()` must stay a pure query; `AP.spend()` must be the sole AP mutator, atomic, gated to `player == active_player`, called only from inside a verb handler's `apply()`" — source: ADR-0006
- Required: "Non-negativity must be enforced by construction (`spend()` bounds checks)" — source: ADR-0006
- Required: "`AP` must be a static utility class with only pure/static functions taking `GameState` explicitly" — source: ADR-0006
- Forbidden: "Never put `income()`/`spend()`/`can_afford()` directly on `GameState`/`PlayerState`" — source: ADR-0006
- Forbidden: "Never make AP Economy an instance-based service object" — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/ap-economy.md`, scoped to this story:*

- [ ] **GIVEN** `current_ap = 5`, **WHEN** `spend(3)`, **THEN** returns true and `current_ap = 2`; **WHEN** `spend(6)` from `current_ap = 5`, **THEN** returns false and `current_ap` unchanged.
- [ ] **GIVEN** any pool, **WHEN** `spend(0)`, **THEN** returns true and nothing changes; **WHEN** `spend(-1)`, **THEN** returns false and nothing changes.
- [ ] **GIVEN** `current_ap = 5`, **WHEN** `spend(5)` (spend to exactly zero), **THEN** returns true, `current_ap = 0`, and a subsequent `can_afford(player, 1)` returns false.
- [ ] **GIVEN** Player A is active with `current_ap_A = 5` and Player B (inactive) has `current_ap_B = 10`, **WHEN** A `spend(A, 3)`, **THEN** `current_ap_A = 2` and `current_ap_B` unchanged; **WHEN** `spend(B, 1)` is attempted (B not active), **THEN** returns false and no pool changes (Rule 7).
- [ ] **GIVEN** `current_ap = 5`, **WHEN** `can_afford(player, 3)`, **THEN** returns true and `current_ap` remains 5 (pure query, no mutation); **WHEN** `can_afford(player, -1)`, **THEN** false.
- [ ] **GIVEN** `current_ap = 0`, **WHEN** `can_afford(player, amount)` for any `amount > 0`, **THEN** returns false and `current_ap` unchanged.
- [ ] **GIVEN** any sequence of valid spends within a turn, **WHEN** applied, **THEN** the invariant `0 ≤ current_ap ≤ income_this_turn` holds at every observable point.

---

## Implementation Notes

*Derived from ADR-0006 Key Interfaces:*

```gdscript
static func current_ap(state: GameState, player: int) -> int:
    return state.per_player[player].current_ap          # read facade (mirrors GameState.current_ap)

static func can_afford(state: GameState, player: int, amount: int) -> bool:
    return amount >= 0 and amount <= state.per_player[player].current_ap   # pure; NO active-player gate

static func spend(state: GameState, player: int, amount: int) -> bool:
    if player != state.active_player: return false      # Rule 7 — only active player's pool mutable
    if amount < 0:                    return false      # malformed, no change
    if amount == 0:                   return true       # no-op success
    var ps: PlayerState = state.per_player[player]
    if amount > ps.current_ap:        return false      # reject, no change
    ps.current_ap -= amount
    return true                                          # atomic deduction
```

- `can_afford` is deliberately **ungated** on active-player (safe for AI eval / HUD to ask about any player); only `spend` enforces the active-player gate. Keep them distinct — do not add a gate to `can_afford`.
- `spend` is atomic: it validates ALL conditions before the single `-=` write, so a rejected spend never partially mutates. No rollback needed.
- `spend` is called only from inside a verb handler's `apply()` (ADR-0002 step 5) — but this story only implements `spend` itself; it does not wire callers (those are the Movement/Combat/etc. epics).
- The `0 ≤ current_ap ≤ income_this_turn` invariant is structural: `spend`'s `amount ≤ current_ap` lower-bounds it at 0; the upper bound is established by `reset_turn` (Story 003) and never exceeded because `spend` only decreases. Test the invariant across a spend sequence.
- Integer only; no RNG.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `income`, `ap_income_breakdown`, `EconomyConfig`, `Balance` autoload.
- Story 003: `reset_turn` (sets the upper bound / `income_this_turn`), `discard`.
- Wiring `spend`/`can_afford` into actual action verb handlers (Movement/Combat/Base&Production/Research epics).

---

## QA Test Cases

**Test file**: `tests/unit/ap_spend_test.gd` (~10 unit tests)

- `spend(3)` from 5 → true, `current_ap = 2`; `spend(6)` from 5 → false, unchanged.
- `spend(0)` → true, no-op; `spend(-1)` → false, unchanged.
- `spend(5)` from 5 (spend to exactly zero) → true, `current_ap = 0`, subsequent
  `can_afford(player, 1)` → false.
- Per-player pool isolation: active Player A spends, Player B's pool unaffected; inactive Player B
  attempting `spend` → false, no pool changes (Rule 7 active-player gate).
- `can_afford(player, 3)` from `current_ap=5` → true, unchanged (pure query, no mutation);
  `can_afford(player, -1)` → false.
- `can_afford` at `current_ap=0` for any positive amount → false.
- Invariant `0 ≤ current_ap ≤ income_this_turn` holds across a sequence of valid spends.
- `can_afford` is deliberately ungated on active-player — assert it can be called for the
  *inactive* player and still returns a correct answer (AI-eval/HUD use case).

Edge cases: `spend` called with `amount` exactly equal to `current_ap` — assert no off-by-one
leaves `current_ap` at 1 or -1.

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/ap_spend_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (shares `ap.gd`), **GS Story 001** (PlayerState.current_ap, active_player) must be DONE.
- Unlocks: Story 003
