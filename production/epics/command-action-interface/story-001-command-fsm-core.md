# Story 001: CommandFSM Core — States, Transitions, Menu Model, Pass-Through Enforcement

> **Epic**: Command & Action Interface
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-001`, `TR-cmdui-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Command & Action Interface FSM (primary)
**ADR Decision Summary**: The Command interface is a headless pure `CommandFSM` (`RefCounted`: `next_state`, `menu_model`, D-1/D-2/D-3 derivations) driven by a Presentation `CommandInterface` `Node` — mirroring the `AI`/`AITurnDriver` split. The FSM holds zero balance constants (Pass-Through Invariant) and commits only through `apply_action`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `command_fsm.gd` is a headless `RefCounted` — no engine API surface. ADR-0015's MEDIUM risk is entirely in the Node-driven parts (later stories), not the pure core. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `CommandFSM` (pure `RefCounted` core: `next_state`, `menu_model`, D-1/D-2/D-3) must be split from `CommandInterface` (Presentation `Node` that drives it), mirroring the `AI`/`AITurnDriver` split — source: ADR-0015
- Required: `menu_model()` must reach cost/legality data only by calling an owning system's side-effect-free query — never hold or reference a balance constant by name — source: ADR-0015
- Forbidden: Never build a single `CommandInterface` Node holding transitions + rendering + input with no separable pure core — source: ADR-0015

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN an owned unit with ≥1 legal action, WHEN selected, THEN the menu opens and every enabled verb independently satisfies `is_legal AND can_afford`; no failing verb appears enabled (AC-1)
- [ ] GIVEN an enemy/neutral entity, WHEN clicked or hovered, THEN the interface exposes read-only inspection data and never enters ENTITY_SELECTED (no command menu opens), in any phase (AC-2)
- [ ] GIVEN Entity A selected, WHEN the player clicks empty terrain / ESC / a different owned entity B, THEN selection clears / clears / switches to B, menu re-filtered accordingly (AC-3)
- [ ] GIVEN a target both out-of-range AND unaffordable, WHEN Attack is evaluated, THEN Attack is disabled and both failure reasons are surfaced (AC-8)
- [ ] GIVEN an empty `reachable` or `legal_targets` set, WHEN selected, THEN the verb is disabled with its specific reason, not hidden or erroring (AC-9)
- [ ] GIVEN a fully-spent entity / producer with `production_cap` exhausted / no legal deploy tile, WHEN selected, THEN it still selects, verbs disabled-with-reason, Wait clickable (AC-10)
- [ ] `next_state()` is exhaustively table-tested — every (state, trigger) pair returns the GDD States-table target; `GAME_OVER` is absorbing for every trigger
- [ ] A grep of `command_fsm.gd` finds zero owning-system balance-constant names (`move_cost`, `SOFT_MOVE_PENALTY`, `attack_cost`, `COVER_DR`, `CANCEL_REFUND_RATE`, etc.) — Pass-Through lint

---

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- Create `command_fsm.gd` — `class_name CommandFSM extends RefCounted`, with `enum State { IDLE, ENTITY_SELECTED, PREVIEW_MOVE, PREVIEW_ATTACK, PREVIEW_PRODUCE, PREVIEW_BUILD, GAME_OVER }` and `enum Trigger { SELECT_OWN, SELECT_ENEMY_OR_EMPTY, PICK_MOVE, PICK_ATTACK, PICK_PRODUCE, PICK_BUILD_CMD, COMMIT, BACK_OUT, WAIT, END_TURN, OBSERVE_GAME_OVER }` exactly as ADR-0015 §1/§2 specifies.
- `static func next_state(current: State, trigger: Trigger, state: GameState) -> State` must be pure and total; transcribe the GDD's States table directly — do not invent transitions.
- `GAME_OVER` is absorbing: `next_state()` returns `GAME_OVER` for any trigger once already in `GAME_OVER`. This story implements the transition function only; the Node-side "how it observes `match_status`" wiring is Story 008.
- `static func menu_model(state: GameState, entity: EntityState) -> Array[VerbEntry]` — the CR-4 contextual menu builder. It reaches cost/legality data **only** by calling owning-system queries (`Movement.reachable`, `Combat.legal_targets`, `AP.can_afford`, `BaseProduction.legal_*`/`production_cap`) — the structural enforcement of the Pass-Through Invariant.
- Implement `VerbEntry` as a small typed struct/Resource: `{verb: int, enabled: bool, reason: int}`. When both legality and affordability fail, surface both reasons (D-2, AC-8), not just the first failing conjunct.
- This story does NOT wire D-1/D-2/D-3 against live dependency queries (that is Story 003's consumption contracts); it establishes the pure function shapes only, using the corpus's existing stub convention (`tests/helpers/stubs/`).
- Register the Pass-Through lint as a candidate grep check per ADR-0015 §4 — a manual grep at story-done satisfies this AC until a CI lint exists.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Four-tier recompute timing — Story 002 (this FSM decides *what* the menu/transition logic computes given a snapshot, not *when* queries fire)
- D-1/D-2/D-3 wired against real Movement/Combat/AP/BaseProduction — Story 003
- Cancel-Build hold gesture — Story 004
- BoardCursor — Story 005
- GAME_OVER Node-side observation / both-instances convergence — Story 008

---

## QA Test Cases

- **AC (next_state totality)**: Given the full 7 states × 11 triggers cross-product, When `next_state()` is invoked per pair, Then the result matches the GDD States table exactly. Edge cases: every trigger from `GAME_OVER` returns `GAME_OVER`.
- **AC-1**: Given an owned unit with `reachable()` non-empty and affordable, When `menu_model()` runs, Then Move appears `enabled=true`. Edge cases: `reachable()` empty → Move `enabled=false` with the specific reason (`NO_AFFORDABLE_MOVES`/`NO_OPEN_TILES`).
- **AC-8**: Given a target both out-of-range and unaffordable, When `menu_model()` evaluates Attack, Then both reasons appear in the returned `VerbEntry`. Edge cases: only one conjunct fails → only that reason appears.
- **AC-10**: Given a fully-spent entity, When selected, Then all AP verbs `enabled=false` plus Wait `enabled=true`. Edge cases: producer with `production_cap` exhausted reads "production limit reached this turn."
- **AC-10 (Pass-Through)**: Given `command_fsm.gd` source, When greped for `SOFT_MOVE_PENALTY|COVER_DR|CANCEL_REFUND_RATE|attack_cost`, Then zero matches.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/command-action-interface/command_fsm_test.gd` — must exist and pass

**Status**: [x] Created & passing — 26 test functions (26/26 green)

---

## Dependencies

- Depends on: None (first story — the epic's foundation)
- Unlocks: Story 002 (recompute tiers test against this FSM), Story 003 (dependency wiring calls `menu_model`), Story 008 (GAME_OVER convergence)

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 8/8 passing (0 deferred). Full suite 642/642, CAI suite 26/26 — 0 failures, 0 orphans, 55/55 suites.
**Deviations**:
- OUT-OF-SCOPE (coordinator-approved, behavior-preserving): promoted `Combat._attack_cost_for` → public `Combat.attack_cost_for(attacker)` in `src/core/combat/combat.gd` so the Pass-Through-constrained FSM can price a unit attack via a query rather than reading `CombatConfig.attack_cost` by name. **New cross-epic seam: CAI → `Combat.attack_cost_for`.**
- ADVISORY (logged to `docs/tech-debt-register.md`): stale `_attack_cost_for` doc refs at `ai.gd:578` + `base_production.gd:322` (now public); AI attack-cost dispatch dedup opportunity.
**Test Evidence**: Logic — `tests/unit/command-action-interface/command_fsm_test.gd` (26 test functions).
**Code Review**: Complete — godot-gdscript-specialist (MINOR ISSUES → doc nit fixed) + qa-tester (GAPS → 3 tests added: structure-attacker cost path ×2, Produce happy-path, structure Move `OUT_OF_RANGE` reason). Consolidated **APPROVED**.
**Implementation note**: `next_state` implements the entity-agnostic base "To state" table only; the per-commit `→ IDLE` refinements (actor destroyed / no legal action remaining / new-structure landing) are AC-32/AC-33 (Integration) = Story 008, per the coordinator-approved scoping. New `class_name` file required a `./redot --headless --import` to register in the global class cache (known tooling gotcha, already in the tech-debt register).
