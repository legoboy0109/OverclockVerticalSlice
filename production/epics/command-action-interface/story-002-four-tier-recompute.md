# Story 002: Four-Tier Recompute Discipline (Tier 1–4)

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-005`, `TR-cmdui-006`, `TR-cmdui-007`, `TR-cmdui-008`, `TR-cmdui-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Command & Action Interface FSM (primary)
**ADR Decision Summary**: The four-tier recompute strategy fires preview queries at fixed points — Tier-1 once per preview entry (re-issued on board change), Tier-2 batched once per PREVIEW_MOVE entry, Tier-3 O(1) hover reads, Tier-4 commit-time re-validation inside the owning `apply_action`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Tier logic is pure dictionary bookkeeping; the one engine-touching part (tile-change-gated `InputEventMouseMotion`) reuses ADR-0013/0014 primitives already spiked PASS 2026-07-25. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: The four-tier recompute strategy must fire at fixed points — Tier-1 once per preview entry + re-issued on `action_applied`; Tier-2 once per `PREVIEW_MOVE` entry only, never per hover; Tier-3 O(1) dict lookups; Tier-4 only inside the owning `apply_action` — source: ADR-0015
- Required: Raw `InputEventMouseMotion` must be tile-change-gated — source: ADR-0015
- Forbidden: Never re-run `reachable()` on every hover instead of holding the Tier-1 set — source: ADR-0015

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN a blocker dies to a committed attack, WHEN re-entering Move preview for an affected unit, THEN the reachable overlay reflects the new board state — no reselect trick / reload (AC-19)
- [ ] GIVEN a tile becomes illegal between preview entry and the commit click, WHEN clicked, THEN the commit is rejected, no AP spent, overlay refreshes, player stays in menu (AC-20)
- [ ] GIVEN current_ap=9, a Scout, a reachable tile costing 3 with a legal enemy target in range from it (attack_cost 2), WHEN previewing the move, THEN that tile shows the D-3 attack-possible marker; a reachable tile with no target in range, and an 8-cost tile, do not (AC-11)
- [ ] A hover sweep across the reachable frontier issues zero `reachable()`/`legal_targets()` calls after the Tier-1 entry query (spy/counter on the query functions)
- [ ] A commit on a tile made illegal since preview entry returns `ActionResult.ok == false`, spends 0 AP, and leaves the FSM in the menu with a refreshed overlay

---

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- Implement the held recompute sets on the `CommandInterface` Node per ADR-0015 §1/§3: `_reachable: Dictionary` (Tier-1/3), `_targets: Dictionary` (Tier-1/3), `_after_move_attackable: Dictionary` (Tier-2).
- **Tier 1**: `Movement.reachable(state, unit)` / `Combat.legal_targets(state, unit)` fire once on `PREVIEW_MOVE`/`PREVIEW_ATTACK` entry, re-issued whenever `action_applied` fires while a preview is open.
- **Tier 2**: `Combat.legal_targets_from(state, unit, from_tile)` batched across every tile in the just-computed `reachable()` frontier, once per `PREVIEW_MOVE` entry (and per board-change re-issue) — not per hover.
- **Tier 3**: hover reads are O(1) dict lookups (`_reachable[tile]`/`_targets[tile]`/`_after_move_attackable[tile]`) on every `active_tile` change — no query re-run.
- **Tier 4**: the commit click is not a recompute — it is a single-option legality re-validation inside the owning system's `apply_action`; the FSM only reads `ActionResult.ok`. On reject: swallow, re-issue Tier-1, stay in menu.
- Tile-change gating (TR-cmdui-005): read `InputEventMouseMotion`, compute `_renderer.pick_at(event.position).tile`, and only call `_on_mouse_moved_to_tile(tile)` when the resolved tile differs from the last.
- Board-change is defined against the logical `GameState` model (`entities()`, `entity_at`), never scene-tree node presence — per the GDD's hard implementation constraint.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Query signatures/wiring against real Movement/Combat return types — Story 003
- Iso `pick_at`/`screen_to_grid` implementation itself — the Board Renderer (ADR-0013); this story only *consumes* `pick_at`
- BoardCursor's own tile-stepping — Story 005

---

## QA Test Cases

- **AC (Tier-1)**: Given a `PREVIEW_MOVE` entry, When `reachable()` is spied, Then it is called exactly once at entry. Edge cases: a board-change (`action_applied`) while the preview is open → exactly one additional call, not per-hover.
- **AC (Tier-2)**: Given the same entry, When `Combat.legal_targets_from` is spied, Then it is called exactly once, batched across the whole reachable frontier — not per tile/hover.
- **AC (Tier-3)**: Given a populated `_reachable` dict, When the mouse sweeps 10 frontier tiles, Then `reachable`/`legal_targets` call counts stay at 1 each — only dict reads occur.
- **AC-19**: Given a prior commit removes a blocker mid-preview (`action_applied` fires), When re-hovered, Then `_reachable` is recomputed fresh (Tier-1 re-issue) before the next hover read.
- **AC-20 (Tier-4)**: Given a commit on a tile illegal since Tier-1 entry, When clicked, Then `ActionResult.ok == false`, `current_ap` unchanged, FSM stays in menu with `_reachable` refreshed.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/command-action-interface/recompute_tiers_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the FSM states this discipline attaches to)
- Unlocks: Story 003 (dependency wiring uses these tiers to decide when queries fire), Story 006 (iso picking's tile-change gating is the same mechanism)
