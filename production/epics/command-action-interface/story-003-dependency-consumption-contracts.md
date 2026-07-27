# Story 003: Dependency Consumption Contracts — Movement, Combat, Base & Production, AP, Turn Manager

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-011`, `TR-cmdui-012`, `TR-cmdui-013`, `TR-cmdui-014`, `TR-cmdui-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Command & Action Interface FSM (primary)
**ADR Decision Summary**: The FSM consumes each owning system's side-effect-free previews and commits only through `apply_action`, deducting no AP itself; D-1/D-2/D-3 are literal pass-throughs against those live queries.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Wires real query/commit calls into the Story 001/002 scaffolding; no new engine surface. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: The FSM must commit only via `GameState.apply_action` — never write state, deduct AP, or re-validate legality itself; on reject it swallows, re-issues Tier-1, stays in the menu — source: ADR-0015
- Required: Consume `reachable()` → `{tile, min_cost, is_surcharged}`, render in-cap/over-cap split from `is_surcharged`, never infer — source: ADR-0015 (TR-cmdui-011)
- Forbidden: Never let this layer reach cost/legality data any way except by calling an owning-system query — source: ADR-0015

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN any previewed action showing exact value N, WHEN committed, THEN the resource (AP or HP) changes by exactly N — tested once per action family (move/attack/build) (AC-4)
- [ ] GIVEN current_ap=9 and a previewed move costing 6, THEN `projected_remaining_ap` displays 3; a separate attack preview costing 2 independently displays 7 (never summed) (AC-5)
- [ ] GIVEN current_ap=1 and an attack costing 2, WHEN the menu renders, THEN Attack is disabled with reason "insufficient AP" and is not clickable (AC-6)
- [ ] GIVEN a unit with has_attacked=true, WHEN selected, THEN Attack is disabled with reason "already attacked," regardless of AP (AC-7)
- [ ] GIVEN the Build command in Action phase, THEN each structure type shows `build_cost`+`build_time`, is affordability-gated, and placement preview restricts to `legal_build_tiles` with the two exclusion reasons distinguishable (AC-16, Logic portion)
- [ ] GIVEN a Defensive Structure actor, WHEN previewing its attack, THEN the cost shown and subtracted is the queried `DEFENSIVE_ATTACK_COST` (1), not `attack_cost` (2) (AC-26)
- [ ] GIVEN the opponent's turn / a resolution phase, WHEN clicking/hovering any entity, THEN inspection shows but no menu opens and nothing commits; command input resumes only in own Action phase (AC-21)

---

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- Movement: `reachable(state, unit) -> Array[ReachableTile{tile, min_cost, is_surcharged}]` for Tier-1; render in-cap vs over-cap **from the `is_surcharged` flag directly** — never infer from `min_cost`. Commit via `MoveAction` through `apply_action`.
- Combat: `legal_targets`/`legal_targets_from`/`preview_damage`/`blocked_reason` for the Tier-1 attack set, Tier-2 D-3 batch, exact post-mitigation damage, and the three blocked-shot states. Commit via `AttackAction`.
- Base & Production: `legal_build_tiles`/`legal_deploy_tiles`/`completed_outpost_count`/per-producer `production_cap` for build/deploy overlays and pickers. Commit via `Build`/`Produce`/`CancelBuild` actions. (Base & Production is Complete this session — these query/commit surfaces exist now; confirm exact method signatures at implementation time.)
- AP Economy: `can_afford`/`current_ap`/`income` for affordability gating and `projected_remaining_ap` (D-1) — the FSM never deducts AP itself (`spend()` runs inside each system's `apply()`).
- Turn Manager/GameState: read `active_player`/`match_status`; route every commit through `apply_action`; input is live only during the local player's Action phase (the Node ignores input triggers otherwise, staying inspection-only).
- Wire D-1 (`projected_remaining_ap = current_ap(player) − previewed_cost`) and D-2 (`action_enabled = is_legal AND can_afford`) as literal pass-throughs against these now-real queries, replacing Story 001's test doubles.
- D-3 (`attack_possible_after_move`) composes `Combat.legal_targets_from` + `AP.can_afford` exactly as ADR-0015 §1 specifies — where the Tier-2 batch from Story 002 gets its real Combat call.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Cancel-Build's own hold gesture — Story 004
- BoardCursor/input routing — Story 005
- Iso picking/overlay rendering itself — Story 006
- Commit-flash↔AP-tick shared signal — Story 007 (this story establishes the `apply_action`/`action_applied` plumbing Story 007 hangs the flash off)

---

## QA Test Cases

- **AC-5**: Given a Trooper with `current_ap=9` and a reachable tile at `min_cost=6`, When the move preview renders, Then `projected_remaining_ap == 3`. Edge cases: a separate attack preview at `attack_cost=2` shows `7`, never `9-6-2=1`.
- **AC-6**: Given `current_ap=1` and `attack_cost=2` with target in range, When Attack is evaluated, Then `enabled=false, reason="insufficient AP (needs 2, have 1)"`.
- **AC-7**: Given `has_attacked=true`, When selected, Then Attack shows `enabled=false, reason="already attacked"` regardless of `current_ap`.
- **AC-26**: Given a Defensive Structure attacker, When its attack is previewed, Then the displayed cost equals the queried `DEFENSIVE_ATTACK_COST=1`, asserted against the query return, not a hardcoded `2`.
- **AC-21**: Given the opponent's Action phase, When the local player clicks/hovers any entity, Then a read-only inspection renders, no `ENTITY_SELECTED` transition occurs, and no `apply_action` call is made.
- **AC-4**: Given a Move commit at `min_cost=6`, When resolved, Then `current_ap` decreases by exactly 6 (previewed value matches committed delta byte-for-byte).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/command-action-interface/dependency_consumption_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002
- Unlocks: Story 004 (Cancel-Build needs `BaseProduction.cancel_build` wired), Story 007 (post-commit chaining needs the full commit path), Story 008 (GAME_OVER needs `apply_action`/win-check routing live)
