# Story 004: Cancel-Build Destructive Gesture (Hold-to-Confirm)

> **Epic**: Command & Action Interface
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Command & Action Interface FSM (primary)
**ADR Decision Summary**: Cancel-Build is a destructive action guarded by a bounded hold-to-confirm sub-condition **inside** ENTITY_SELECTED — never a new top FSM state and never a plain single/double click.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `_process`-delta accumulator + `Input.is_action_pressed` poll — both stable pre-4.3 APIs; no new post-cutoff surface.

**Control Manifest Rules (this layer)**:
- Required: Cancel-Build must be a bounded hold sub-condition inside `ENTITY_SELECTED`, never a new top FSM state: accumulate `_cancel_hold_elapsed_ms += delta*1000` in `_process` and poll `Input.is_action_pressed` for release — source: ADR-0015
- Forbidden: Never implement Cancel-Build as an affordance + separate confirm click — source: ADR-0015 (rejected alternative)

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN the player performs the distinct Cancel-Build gesture (hold ≥ `cancel_build_hold_ms`), THEN `current_ap` increases by exactly the previewed refund and the interface returns to ENTITY_SELECTED (refreshed) or IDLE; AND a bare single left-click never triggers Cancel Build (AC-18)
- [ ] GIVEN the player selects an under-construction structure they own, THEN the menu offers only Cancel Build (showing the exact `floor(build_cost × CANCEL_REFUND_RATE)` refund) — the structure is inert until complete
- [ ] A Completed structure is never offered Cancel Build (it can only be destroyed in combat, which refunds nothing)
- [ ] Releasing the hold before `cancel_build_hold_ms` aborts with no refund and no state change
- [ ] The hold is tracked entirely within `ENTITY_SELECTED` — no new top-level FSM state is added (TR-cmdui-002's binding structural constraint)

---

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- Mechanism per ADR-0015 §2: while the affordance is held, accumulate `_cancel_hold_elapsed_ms += delta * 1000.0` in `_process` and poll `Input.is_action_pressed(&"cancel_build")` for release — chosen over `await create_timer` because per-frame polling detects a release-before-threshold abort for free.
- This `_process` cost is active only while the hold sub-condition is live (a bounded ~500 ms window, one selected entity) — not a steady-state per-frame cost; do not add a general `_process` loop to `CommandInterface` for this alone.
- `InputConfig.cancel_build_hold_ms: int = 500` is the new field ADR-0015 adds to ADR-0014's `InputConfig` Resource — add it there, not a second config Resource. **Note: this is an unpinned feel value owed to `/ux-design`; 500 is a placeholder pending a playtest.**
- The refund shown before the gesture is `BaseProduction`'s own `cancel_build` preview return — never re-derive `CANCEL_REFUND_RATE` locally (Pass-Through Invariant).
- A rapid double-click cannot produce a sustained hold, so it structurally cannot trigger the refund-destroy — satisfying the GDD's CR-6a input-shape constraint (a plain double-click of the same `InputEventMouseButton` the universal single-click uses is explicitly disallowed as a valid gesture; a hold trivially is not that).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The exact visual/audio treatment of the hold-in-progress state — Story 009 (feel)
- BoardCursor-driven (non-mouse) invocation — Story 005 establishes the input substrate; `Input.is_action_pressed` is input-method-agnostic by construction, so no separate re-implementation here

---

## QA Test Cases

- **AC-18**: Given an under-construction structure selected, When the Cancel-Build affordance is held exactly `cancel_build_hold_ms`, Then `cancel_build()` commits, `current_ap` increases by the previewed refund, and the FSM returns to ENTITY_SELECTED (refreshed) or IDLE.
- **AC-18 (negative)**: Given the same setup, When the affordance receives only a bare single click (no hold), Then no state changes and no refund applies. Edge cases: a rapid double-click also produces no commit.
- **AC (abort)**: Given the hold is released at `cancel_build_hold_ms - 1ms`, When release is polled, Then the hold aborts with zero refund and zero state change.
- **AC (completed)**: Given a Completed structure selected, When the menu renders, Then no Cancel Build option appears.
- **AC (menu)**: Given an under-construction structure selected, When the menu renders, Then only Cancel Build appears, and the refund shown equals `BaseProduction.cancel_build`'s preview return exactly.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/command-action-interface/cancel_build_gesture_test.gd` — must exist and pass

**Status**: [x] Created & passing — 8 test functions (8/8 green)

---

## Dependencies

- Depends on: Story 001 (ENTITY_SELECTED state), Story 003 (`BaseProduction.cancel_build` commit wired)
- Unlocks: None (leaf within the epic)

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 5/5 ACs covered. Full suite 680/680 — 0 failures, 0 orphans, 58/58 suites.
**Implementation**: NEW `src/ui/input_config.gd` (`InputConfig` Resource, `cancel_build_hold_ms: int = 500` — unpinned feel placeholder owed to /ux-design; cai-005 extends this same Resource). `command_fsm.gd`: `Verb += CANCEL_BUILD`, `Reason += NOT_UNDER_CONSTRUCTION`, `_cancel_build_entry` (enabled iff under-construction StructureState owned by active player — a Completed structure/unit/enemy is never offered it), `cancel_build_preview` (refund via `BaseProduction.cancel_refund(effective_build_cost)` — Pass-Through-clean, no `.build_cost` read); `menu_model` now returns a fixed **5** rows (Cancel-Build appended 5th — `menu[Verb.X]` indexing preserved). `command_interface.gd`: testable `tick_cancel_hold(delta_ms, is_pressed, state, structure) -> CancelHoldResult{CONTINUE,COMMITTED,ABORTED}` accumulator (commits `CancelBuildAction` via the cai-003 `commit()` at ≥ `cancel_build_hold_ms`; release-before-threshold aborts + resets) + thin `_process`/`begin_cancel_hold` glue (active only during a live hold, not steady-state). **No new `CommandFSM.State`** — the hold is a sub-condition of ENTITY_SELECTED (TR-cmdui-002 verified: State enum stays 7).
**Deviations**: None out-of-scope (no `src/core` change). Updated cai-001's `menu_model` "four rows" test → "five rows" (+ a Cancel-Build assertion on the under-construction case).
**Deferrals (logged to `docs/tech-debt-register.md`)**: (1) `cancel_build_preview` uses `effective_build_cost` while `apply_cancel` refunds off the raw base cost — identical under the VS Neutral roster (AC-18 exact), divergent only non-Neutral (BP-009 pattern). (2) The `cancel_build` InputMap action is not bound in `project.godot` (the gesture is unpinned/`/ux-design`; the unit test drives `tick_cancel_hold` directly and needs no binding).
**Test Evidence**: Logic — `tests/unit/command-action-interface/cancel_build_gesture_test.gd` (8 test functions; hold driven with synthetic delta_ms/is_pressed, real `apply_action` commit).
**Code Review**: orchestrator implemented + reviewed (finished after agent truncation): Pass-Through lint green, no core change (`git diff src/core` empty), menu indexing preserved, no new FSM state. APPROVED.
