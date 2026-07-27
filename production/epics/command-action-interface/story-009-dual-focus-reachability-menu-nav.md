# Story 009: Dual-Focus Reachability, Menu Keyboard Nav & Cancel-Build Gesture Feel

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S (2h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-021`, `TR-cmdui-024` (manual UI-level verification of reachability — the human-facing counterpart to Story 005's automated coverage)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: Input & Focus Architecture (primary)
**ADR Decision Summary**: Godot 4.6's dual-focus model (separate mouse-click focus and keyboard/gamepad focus) is used directly — `grab_click_focus()`/`grab_focus()`, distinct `hover`/`focus` StyleBoxes, `FOCUS_NONE` for inert controls, `FOCUS_CLICK` when keyboard nav is disabled.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: The dual-focus API surface and input-consumption-order claim are already spiked PASS 2026-07-25 (both asymmetric cases). This story's risk is confined to wiring the confirmed APIs into the actual menu Controls, not any unverified engine behavior. Re-confirm live against this project's menu scene per the 2026-07-22 `game-hud.md` ClassDB check.

**Control Manifest Rules (this layer)**:
- Required: Every interactive `Control` must use `grab_click_focus()` for mouse-click focus and `grab_focus()` for keyboard/gamepad focus — distinct methods, distinct `hover`/`focus` StyleBoxes, no custom focus-ring wiring — source: ADR-0014
- Required: Present-but-inert controls must set `focus_mode = FOCUS_NONE` — never hand-roll per-frame focus-ring suppression — source: ADR-0014
- Required: When `menu_keyboard_nav_enabled = false`, interactive Controls must use `focus_mode = FOCUS_CLICK` — source: ADR-0014

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] Every core interaction (select/commit/cancel/menu-verb/End Turn) is reachable via keyboard/gamepad + mouse; no hover-only interactions (TR-cmdui-024, re-verified at the UI/manual level here)
- [ ] The contextual action menu is fully keyboard/gamepad navigable when `MENU_KEYBOARD_NAV = on` (Tuning Knob default)
- [ ] Present-but-inert controls (opponent's Action phase, GAME_OVER) show `focus_mode = FOCUS_NONE` and are visibly non-interactive without relying on color alone
- [ ] When `MENU_KEYBOARD_NAV = false`, interactive Controls still register mouse clicks (`FOCUS_CLICK`) while Tab/`ui_focus_next` traversal is suppressed
- [ ] A focused menu verb shows a keyboard-focus indicator visually distinct from mouse-hover (the Godot 4.6 dual-focus split — both can be visible/active at once and must read as different states)

---

## Implementation Notes

*Derived from ADR-0014 Implementation Guidelines:*

- Every interactive `Control` (action-menu verbs) uses `grab_click_focus()` for mouse-click focus and `grab_focus()` for keyboard/gamepad focus — distinct methods, distinct `hover`/`focus` StyleBoxes on the default Theme, no custom focus-ring wiring.
- Keyboard traversal order via `focus_neighbor_top/bottom/left/right` or `focus_next`/`focus_previous` — this story decides the *specific* traversal order across the action menu's verb list (a UX call ADR-0014 explicitly deferred: "the specific order... is a `/ux-design` call; this ADR fixes only the mechanism").
- Present-but-inert controls (opponent's turn, GAME_OVER) set `focus_mode = FOCUS_NONE` — never hand-roll per-frame focus-ring suppression.
- `MENU_KEYBOARD_NAV = false` sets interactive Controls to `focus_mode = FOCUS_CLICK` rather than `FOCUS_NONE` — mouse click must still register even with keyboard/gamepad traversal disabled.
- Re-confirm (manual sanity pass) `grab_click_focus()`/`grab_focus()`, `gui_get_hovered_control()`/`gui_get_focus_owner()`, and the `focus`/`hover` StyleBox slots behave as the 2026-07-22 ClassDB check found, live in this project's actual menu scene.
- Verify the Cancel-Build hold (Story 004) is reachable identically via keyboard/gamepad `Input.is_action_pressed` polling — no mouse-only code path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The pixel-level StyleBox art itself — art bible
- The underlying dual-focus API confirmation — already done (ADR-0014 formalizes it as an accepted fact); this story is about *this project's* menu scene using it correctly

---

## QA Test Cases

*Manual verification (UI-typed):*

- **AC-024 (reachability)**: Setup: open the action menu with only a keyboard/gamepad (no mouse input). Verify: every menu verb, End Turn, and the Cancel-Build affordance is reachable and activatable via Tab/D-pad + confirm. Pass condition: 100% of core interactions reachable, no dead ends.
- **AC (dual-focus distinct)**: Setup: hover a menu verb with the mouse while a different verb holds keyboard focus. Verify: both indicators are visible at once. Pass condition: a color-desaturated screenshot still shows the two states as distinguishable (shape/weight, not hue).
- **AC (inert)**: Setup: enter the opponent's Action phase. Verify: attempt to Tab into any control. Pass condition: no control receives focus; all read `focus_mode = FOCUS_NONE`.
- **AC (FOCUS_CLICK)**: Setup: set `MENU_KEYBOARD_NAV = false`. Verify: attempt Tab-traversal (should fail) and mouse-click a verb (should succeed). Pass condition: click registers; Tab traversal suppressed.
- **AC (gamepad hold)**: Setup: hold the Cancel-Build affordance via a gamepad button. Verify: hold-to-confirm timing matches Story 004's `cancel_build_hold_ms`. Pass condition: refund commits at the same threshold, gamepad or mouse.

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/dual-focus-reachability-evidence.md` — manual walkthrough doc + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (menu model to navigate), Story 004 (Cancel-Build gesture to give feel/timing to), Story 005 (BoardCursor, for the "menu closed during preview" precedence check)
- Unlocks: None (leaf polish story)
