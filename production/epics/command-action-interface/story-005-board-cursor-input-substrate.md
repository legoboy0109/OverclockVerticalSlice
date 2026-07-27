# Story 005: BoardCursor Input Substrate — Grid-Axis Nav, Cycle/Jump, Mouse-vs-Cursor Precedence

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-018`, `TR-cmdui-019`, `TR-cmdui-020`, `TR-cmdui-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: Input & Focus Architecture (primary); ADR-0015 (secondary — the `CommandInterface` Node that instantiates/drives `BoardCursor`)
**ADR Decision Summary**: A headless `BoardCursor` (`RefCounted`, grid-space) provides keyboard/gamepad board navigation distinct from Control focus; mouse-hover vs cursor precedence is last-updated-wins with no timestamp comparison; every core interaction is reachable without a mouse.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `BoardCursor` value object is pure `RefCounted` (no engine API). The input-consumption-order arbitration it relies on is ADR-0014's HIGH-risk item, already spiked PASS 2026-07-25.

**Control Manifest Rules (this layer)**:
- Required: `BoardCursor` must be a headless `RefCounted` value object — no scene-tree reference, no input-polling of its own, no game rules — source: ADR-0014
- Required: `BoardCursor.step(direction, grid)` must map to grid-axis directions, never screen-axis/iso-visual directions — source: ADR-0014
- Required: Mouse-hover vs `BoardCursor` precedence must use last-updated-wins via `active_locus`/`active_tile` — no timestamp/frame-delta comparison — source: ADR-0014

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] Every core interaction (select/commit/cancel/menu-verb/End Turn) is reachable via keyboard/gamepad + mouse; no hover-only interactions (TR-cmdui-024)
- [ ] `BoardCursor.step()` never sets `grid_pos` outside `[0, GRID_WIDTH) × [0, GRID_HEIGHT)` for any direction/starting-position combination
- [ ] `jump_to_next()` over a fixed candidate set visits every candidate exactly once per full cycle, in ascending tile-index order, wrapping from last to first
- [ ] A scripted sequence (mouse move → key press → mouse move) leaves `active_locus` reflecting the last input processed, in dispatch order, with no timestamp comparison in the code
- [ ] D-pad cursor stepping maps to grid axes, never screen-axis/iso-visual directions (TR-cmdui-019)

---

## Implementation Notes

*Derived from ADR-0014 Implementation Guidelines:*

- `board_cursor.gd`: `class_name BoardCursor extends RefCounted`, holding only `var grid_pos: Vector2i`. `step(direction: Vector2i, grid: GridState) -> bool` maps `NORTH/SOUTH/EAST/WEST` directly to grid `(x,y)` axes (`ui_up → NORTH → y-1`, etc.) — never a screen-axis direction. Returns false and leaves `grid_pos` unchanged if out of bounds.
- `jump_to_next(candidates: Array[Vector2i], grid: GridState) -> void` cycles in deterministic ascending tile-index order (`y*GRID_WIDTH+x`), wrapping last→first, matching ADR-0003's iteration-order convention. No-op if candidates empty.
- Bind `BoardCursor` stepping to the same `ui_up`/`ui_down`/`ui_left`/`ui_right` actions the menu's `Control` nodes consume for `focus_neighbor` traversal, read in `_unhandled_input` — the zero-arbitration answer to OQ-6: a focused `Control` consumes the event first in the GUI pass and it never reaches `_unhandled_input`; when no `Control` holds focus (every `PREVIEW_*` state), the keypress drives `BoardCursor`.
- `board_cursor_cycle` is a dedicated input action (shoulder-button primary), distinct from `ui_focus_next`/Tab, so a future menu re-authoring can never accidentally shadow cycle-jump.
- Mouse-hover vs `BoardCursor` precedence (TR-cmdui-020): `active_locus`/`active_tile` fields on the owning Node, updated last-handler-wins — `_on_mouse_moved_to_tile(tile)` sets `active_locus = MOUSE`; `_on_board_locus_moved(cursor)` sets `active_locus = BOARD_CURSOR`. No timestamp/frame-delta comparison — Godot's synchronous single-threaded dispatch already makes "whichever handler ran last" correct.
- `jump_to_next`'s candidate set is caller-supplied per preview mode: the `reachable()` frontier in Move preview, `legal_targets` in Attack preview, legal tiles in Build/Deploy — this story implements the mechanism and its per-state candidate wiring (a mechanical consequence of Story 001/003 data).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The pixel rendering of the cursor indicator glyph (art-bible gap; not blocking)
- `Control` dual-focus StyleBox/traversal order itself — Story 009 (UI)
- `INPUT_LOCK_MS` debounce mechanism — Story 007

---

## QA Test Cases

- **AC (bounds)**: Given `grid_pos` at a boundary tile, When `step()` is called toward out-of-bounds, Then `grid_pos` is unchanged and `step()` returns false. Edge cases: repeated out-of-bounds steps never corrupt `grid_pos`.
- **AC (cycle)**: Given a candidate set of 5 tiles, When `jump_to_next()` is called 5 times, Then every candidate is visited exactly once in ascending tile-index order, and the 6th call wraps to the first. Edge cases: an empty candidate set is a no-op (no crash).
- **AC (precedence)**: Given a scripted sequence (mouse→A, `ui_up`, mouse→B), When `active_locus`/`active_tile` are read after each step, Then they reflect MOUSE→A, BOARD_CURSOR→(cursor pos), MOUSE→B in that order — with no `Time`/frame-count read in the implementation.
- **AC (grid-axis)**: Given `ui_up` is pressed, When `step()` resolves it, Then `grid_pos.y` decreases by 1 regardless of camera/iso orientation.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/command-action-interface/board_cursor_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the `CommandInterface` Node shape this cursor plugs into)
- Unlocks: Story 006 (iso picking consumes `BoardCursor` anchor), Story 004 cross-check (hold gesture must be reachable via non-mouse input)
