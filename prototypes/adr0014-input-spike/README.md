# ADR-0014 Pre-Accepted Engine Spike: Input & Focus Architecture

## Hypothesis Under Test

ADR-0014 §2 claims Godot's own input-consumption order arbitrates
`BoardCursor` vs. `Control` focus traversal "for free," with **zero
arbitration code**: bind `BoardCursor` stepping to the same `ui_up`/
`ui_down`/`ui_left`/`ui_right` actions a focused `Control`'s
`focus_neighbor_*` traversal consumes, read in `_unhandled_input`. Because a
`Control` that consumes an event in the GUI pass marks it handled, the claim
is that `_unhandled_input` **never** sees that keypress while a `Control`
holds focus, and **always** sees it when no `Control` holds focus.

The engine-reference corpus (`docs/engine-reference/godot/modules/input.md`,
`modules/ui.md`, `breaking-changes.md`) confirms Godot 4.6 introduced a
**dual-focus split** (mouse/touch focus is now separate from keyboard/gamepad
focus) but says **nothing** about how that split interacts with
`focus_neighbor_*` consumption order. That interaction — specifically the two
asymmetric cases below — is this spike's actual unknown. This **cannot be
verified headlessly**: `InputEvent`s do not propagate in `--headless` mode.
This spike must be run windowed, with real keypresses, by a human.

## Files

- `InputFocusSpike.tscn` — the spike scene (windowed `Control` root).
- `input_focus_spike.gd` — driving script: builds the board grid, wires
  `focus_neighbor_*`, logs which handler (`_unhandled_input` vs. GUI
  focus/`_gui_input`) fired last, and shows live `gui_get_focus_owner()` /
  `gui_get_hovered_control()` readouts.
- `board_cursor.gd` — verbatim port of ADR-0014 §1's `BoardCursor`
  (`class_name BoardCursor extends RefCounted`). Headless, no scene-tree
  dependency. Throwaway spike copy — the real one is ADR-0015's to author in
  `src/` against the real `GridState`.
- `grid_stub.gd` — minimal bounds-only stand-in for ADR-0005's `GridState`
  (same "stub, not the real thing" convention as `prototypes/qq05-reachable-bench`
  and `prototypes/spikes/qq06_ai_loop_bench.gd`).

## `project.godot` Change

Added a new `[input]` section defining **`board_cursor_cycle`** (bound to
`[` and `]` keys as a keyboard fallback), per the task's explicit grant of
`project.godot` ownership for this spike. `ui_up`/`ui_down`/`ui_left`/
`ui_right`/`ui_focus_next`/`ui_focus_prev` were **not** redefined — confirmed
present as Godot's built-in engine defaults (verified via
`InputMap.has_action()` against the pinned Redot 26.2 binary; the project's
`project.godot` had no prior `[input]` section at all). `board_cursor_cycle`
is a dedicated action, distinct from `ui_focus_next` (Tab), per ADR-0014 §2's
explicit reasoning for keeping cycle-jump un-shadowable by future Tab-based
menu traversal. The shoulder-button primary binding ADR-0014's Risks section
flags as unassigned remains unassigned — out of scope for this spike.

## Scene Contents

- **Button A** — plain `Control`, in a `focus_neighbor_top/bottom` vertical
  chain with Button B. Used for the keyboard-focus-only asymmetric case
  (grab focus via Tab/click, never hover it with the mouse afterward).
- **Button B** — same chain, positioned below Button A. Used for the
  mouse-hover-only asymmetric case (hover it with the mouse, but do not click
  or Tab to it — so it never holds keyboard focus).
- **Button C ("FOCUS_CLICK only")** — chained below Button B
  (`focus_neighbor_bottom`), with `focus_mode = Control.FOCUS_CLICK` set in
  code. Tests whether `FOCUS_CLICK` suppresses arrow-key/Tab traversal *into*
  it while still allowing mouse-click focus — the `MENU_KEYBOARD_NAV = false`
  fallback path.
- **"Release All Focus" button** — `focus_mode = FOCUS_NONE`, so it can be
  clicked (mouse clicks fire `pressed` regardless of `focus_mode`) but can
  never itself become the keyboard focus owner. Its handler calls
  `release_focus()` on whichever `Control` `gui_get_focus_owner()` currently
  returns. This is the **deterministic way to reach the "no Control holds
  focus" state** — clicking empty space does not reliably clear focus in
  Godot, so this button exists specifically to make Check 2 unambiguous.
- **5x5 board grid** (`ColorRect` tiles) — the cursor tile is highlighted
  lime-green; all others are dim gray.
- **Live readout labels**:
  - **Last Handler** (large, color-coded) — the single most important
    readout. Green text = `_unhandled_input -> BoardCursor moved/jumped`.
    Orange text = GUI-side event (`GUI focus_neighbor traversal -> gained
    focus` or `GUI _gui_input -> received key`). Gray = manual focus release.
  - **`_unhandled_input` directional count** — increments only when
    `_unhandled_input` actually handles `ui_up/down/left/right` or
    `board_cursor_cycle`. If this counter is frozen while you keep pressing
    arrow keys, that is direct proof the `Control` layer is consuming the
    event before `_unhandled_input` ever sees it.
  - **Keyboard focus owner** — live `gui_get_focus_owner()` name (or "(none)").
  - **Mouse-hovered control** — live `gui_get_hovered_control()` name.
  - **`BoardCursor.grid_pos`** — current cursor grid position.

## Interactive Run Protocol

### Launch

```
./redot --path . prototypes/adr0014-input-spike/InputFocusSpike.tscn
```

(Run from the repo root. This launches the scene directly in the editor's
runtime, windowed, without needing to set it as the project's main scene.)

Before each check below, click **"Release All Focus"** to guarantee a known
starting state (no `Control` holds keyboard focus).

---

### Check 1 — Focused Control consumes arrow keys; `BoardCursor` never moves

**Sequence:**
1. Click "Release All Focus."
2. Press `Tab` (or click directly on) **Button A** so it holds keyboard focus.
   Confirm "Keyboard focus owner: ButtonA" appears.
3. Press the **Down arrow key** (`ui_down`) several times.

**PASS readout:** "Last Handler" shows orange
`GUI focus_neighbor traversal -> ButtonB gained keyboard focus` (focus moves
A -> B -> back to A, since the chain wraps), "Keyboard focus owner" alternates
between ButtonA/ButtonB, and the **`_unhandled_input` directional count does
NOT increment**. `BoardCursor.grid_pos` never changes and the highlighted
board tile never moves.

**FAIL readout:** the directional counter increments, or "Last Handler" ever
shows green `_unhandled_input -> BoardCursor moved`, while a Button holds
focus.

---

### Check 2 — No Control focused; arrow keys drive `BoardCursor`

**Sequence:**
1. Click "Release All Focus." Confirm "Keyboard focus owner: (none)."
2. Press **Up / Down / Left / Right** a few times each.

**PASS readout:** "Last Handler" shows green
`_unhandled_input -> BoardCursor moved to (x, y) (via ui_up/down/left/right)`,
the `_unhandled_input` directional counter increments on every press, and the
highlighted tile on the 5x5 grid visibly moves one tile per press along grid
axes (never diagonally). Pressing `[` or `]` (`board_cursor_cycle`) makes
"Last Handler" show `BoardCursor jumped to (x, y) (via board_cursor_cycle)`,
cycling the four board corners in order.

**FAIL readout:** arrow keys produce no green readout / no counter increment
(i.e., something is still consuming them even with no focus owner), or the
tile moves diagonally / off the grid-axis mapping.

---

### Check 3a — Keyboard-focus-only Control (asymmetric case)

**Sequence:**
1. Click "Release All Focus."
2. Press `Tab` to move focus to **Button A** (keyboard/gamepad focus only —
   do **not** click it, do **not** hover it with the mouse; move the mouse
   cursor away from the button entirely, e.g. park it over the board grid).
3. Confirm readout: "Keyboard focus owner: ButtonA", "Mouse-hovered control:
   (none)" (or showing a board tile, not ButtonA).
4. Press the **Down arrow key** (`ui_up`/`ui_down`).

**PASS readout (ADR's predicted behavior):** despite the mouse never having
touched Button A, focus still traverses (orange `GUI focus_neighbor
traversal -> ButtonB gained keyboard focus`), and the `_unhandled_input`
counter does not increment. This confirms keyboard-focus-only is sufficient
for a `Control` to intercept `ui_up`/`ui_down` — mouse hover is irrelevant to
this interception.

**FAIL readout:** the arrow key reaches `_unhandled_input` anyway (green
readout, counter increments, `BoardCursor` moves) despite Button A holding
keyboard focus. This would falsify the ADR's arbitration-free claim for the
keyboard-focus-only case and require a design revisit.

---

### Check 3b — Mouse-hover-only Control (asymmetric case, the one most likely to surprise)

**Sequence:**
1. Click "Release All Focus." Confirm "Keyboard focus owner: (none)."
2. Move the mouse to hover over **Button B** — do **not** click it and do
   **not** Tab to it. Confirm readout: "Mouse-hovered control: ButtonB",
   "Keyboard focus owner: (none)."
3. While still hovering Button B (don't move the mouse away), press the
   **Down arrow key** (`ui_down`) several times.

**PASS readout (ADR's predicted behavior):** "Last Handler" shows green
`_unhandled_input -> BoardCursor moved`, the counter increments, and the
board cursor tile moves — i.e., **hover alone does NOT intercept the arrow
key**, because Button B holds no keyboard focus. This is the case the ADR
explicitly flags as the one most likely to diverge from training-data
assumptions, since pre-4.6 Godot conflated hover and focus more closely in
some contexts.

**FAIL readout:** Button B's `focus_entered` or `_gui_input` fires (orange
readout) purely from mouse hover, or the `_unhandled_input` counter fails to
increment despite no `Control` holding keyboard focus. This would mean 4.6's
dual-focus split does *not* cleanly separate hover from keyboard-consumption
as the ADR assumes, and the arbitration-free claim would need revision
(e.g. an explicit `mouse_filter` adjustment).

---

### Check 4 — `FOCUS_CLICK` traversal suppression (`MENU_KEYBOARD_NAV = false` path)

**Sequence:**
1. Click "Release All Focus."
2. Press `Tab` (or arrow-key-traverse) to focus **Button B**.
3. Continue pressing **Down arrow** / `Tab` repeatedly, trying to reach
   **Button C ("FOCUS_CLICK only")**, which sits directly below Button B in
   the `focus_neighbor_bottom` chain.
4. Separately: click **Button C** directly with the mouse.

**PASS readout:** Step 3 never produces "Keyboard focus owner: ButtonC" —
focus traversal skips over or refuses to land on Button C via arrow
keys/Tab (exact skip-vs-refuse behavior is part of what to observe and
report — the ADR only asserts *some* suppression, not the precise
mechanism). Step 4 **does** succeed — "Keyboard focus owner: ButtonC" after
a direct mouse click, confirming `FOCUS_CLICK` still allows click-to-focus.

**FAIL readout:** arrow-key/Tab traversal successfully lands keyboard focus
on Button C in step 3 (i.e., `FOCUS_CLICK` does not suppress traversal-in),
or mouse click in step 4 fails to grant it focus at all (i.e., `FOCUS_CLICK`
blocks click-focus too, which would defeat its purpose for the
`MENU_KEYBOARD_NAV = false` fallback).

---

## Godot-Specialist Assessment: Likely 4.6 Outcome

**What I can assert directly from the reference docs (`docs/engine-reference/
godot/modules/input.md`, `modules/ui.md`, `breaking-changes.md`,
`deprecated-apis.md`) without needing the live run:**

- Godot's fundamental input-dispatch order — GUI pass (focused `Control`
  gets first refusal via its internal `_gui_input`, including
  `focus_neighbor_*` traversal) before `_unhandled_input` — is **pre-4.3,
  pre-cutoff, stable behavior**, not something 4.6 touched. Nothing in
  `breaking-changes.md`'s 4.4/4.5/4.6 rows mentions any change to *this*
  ordering; the only 4.6 UI/input change listed is the dual-focus split
  itself. This makes **Check 1 and Check 2 very likely to PASS** as
  written — they exercise the ordering mechanism, not the dual-focus split.
- `grab_focus()` in 4.6 affects **keyboard/gamepad focus only** — this is
  stated plainly and repeatedly in both `modules/input.md` and `modules/
  ui.md` ("be aware: mouse hover focus != keyboard focus in 4.6",
  "Assuming `grab_focus()` affects mouse focus (it only affects keyboard/
  gamepad in 4.6)"). This directly supports **Check 3a passing**: a
  `Control` that holds keyboard focus (via Tab, matching what `grab_focus()`
  grants) should still intercept `ui_up`/`ui_down` regardless of mouse
  position, because keyboard-focus consumption was never mouse-gated even
  pre-4.6 — the dual-focus split only changed what mouse *hover* does, not
  what keyboard *focus* does.

**What genuinely needs the live keypress to confirm (cannot be asserted from
docs) — in descending order of how surprising a FAIL would be:**

- **Check 3b is the spike's actual point of highest uncertainty.** The docs
  confirm hover and keyboard-focus are now *tracked* separately, but say
  nothing about whether Godot's internal `_gui_input`/focus-neighbor
  dispatch path was re-scoped to key off "the Control currently under the
  mouse" for *any* input category in 4.6 as part of implementing the split.
  If the dual-focus implementation introduced any hover-conditioned
  short-circuit into the GUI input pass (plausible, since 4.6 needed some
  new internal notion of "which Control does a given InputEvent's *input
  method* route to"), a hovered-but-unfocused Button could theoretically
  intercept arrow keys it never used to. My prior, based on the docs'
  framing (hover and focus are described as fully independent, parallel
  tracking, not a routing change to `_unhandled_input`'s trigger
  condition), is that **Check 3b will PASS as the ADR predicts** — but this
  is the one case where I'd genuinely flag non-trivial (not high, but
  non-trivial) risk of surprise, which is exactly why the ADR scoped it as
  the spike's primary target rather than treating it as settled.
- **Check 4 (`FOCUS_CLICK`)** is asserted from general Godot `FocusMode`
  semantics (long-stable pre-4.3 enum), not confirmed against 4.6
  specifically anywhere in the reference corpus. My prior is it will PASS
  (arrow/Tab traversal skips `FOCUS_CLICK` controls; direct click still
  grants focus) — this is `FOCUS_CLICK`'s documented pre-4.6 purpose and
  nothing in `breaking-changes.md` suggests the enum's traversal semantics
  changed — but "documented pre-4.6 purpose, unconfirmed against the pinned
  4.6 build" is precisely the gap the ADR flags in its Risks section, and
  is exactly why this check exists rather than being asserted outright.

**Overall verdict on "does the arbitration-free claim hold?":** likely yes,
with Check 3b as the one cell of the 2x2 (keyboard-focus x mouse-hover) that
is not fully derivable from the reference corpus and must be watched most
closely during the live run. Checks 1, 2, and 3a rest on input-dispatch
ordering that predates 4.6 and is unaffected by the dual-focus split per the
docs. Check 4 rests on long-stable `FocusMode` semantics not specifically
re-verified for 4.6 in the corpus, making it a legitimate but lower-risk spot
check.

## API Caveats

- `Control.release_focus()` (called on the current `gui_get_focus_owner()`
  by the "Release All Focus" button) is **not present in the
  engine-reference corpus** — it predates the 4.3 cutoff and is not flagged
  in `deprecated-apis.md` or `breaking-changes.md`, so it is asserted from
  stable pre-cutoff Godot knowledge, not the pinned-version docs. Low risk,
  but flagging per this agent's standing instruction to name anything not
  independently confirmed against `docs/engine-reference/godot/`.
- The ADR's own flagged unconfirmed item — the exact 4.5+ "recursive Control
  disable" property identifier — is **not used anywhere in this spike**
  (this spike only needs `FOCUS_NONE`/`FOCUS_CLICK`/`FOCUS_ALL` on individual
  Controls, not hierarchy-wide disabling), so it remains exactly as
  unconfirmed as the ADR already states. `game-hud.md`'s Input notes name
  `focus_behavior_recursive` as the likely 4.5+ property, which is a
  reasonable lead for whoever eventually needs to verify it, but this spike
  does not exercise or confirm it.
- `board_cursor_cycle`'s keyboard binding (`[`/`]`) is a spike-only
  placeholder — the ADR's Risks section already flags the real
  shoulder-button primary binding as unassigned; this spike does not resolve
  that, only adds a keyboard fallback sufficient to test `jump_to_next()`
  interactively.
- Verified live (not just from docs) during this session: `ui_up`/`ui_down`/
  `ui_left`/`ui_right`/`ui_focus_next`/`ui_focus_prev` all exist as Godot
  built-in default actions on this pinned Redot 26.2 binary even with no
  prior `[input]` section in `project.godot` (`InputMap.has_action()`
  checked directly), and the new `board_cursor_cycle` action registers
  correctly after the `project.godot` edit — both confirmed via a headless
  `--import` cache rebuild + `InputMap` query. Scene load/instantiate/one
  `_process()` frame all run without script or scene errors (headless-safe
  checks only — this does NOT touch the actual input-arbitration question,
  which remains genuinely unverified pending the live windowed run above).

## Is ADR-0014 on Track to Accept?

Yes, pending your live confirmation of the checks above. Nothing in this
spike's construction surfaced a reason to expect the ADR's design to need
revision — the scene builds and runs cleanly, the `BoardCursor`/`GridStub`
port behaves as specified (bounds-checked stepping, deterministic
tile-index cycling), and the input-dispatch mechanism the ADR relies on
(GUI pass before `_unhandled_input`) is stable, pre-cutoff Godot behavior
unaffected by the 4.6 dual-focus split per the reference corpus. The one
real open question is Check 3b (mouse-hover-only Control vs. arrow-key
interception) — if that fails, the ADR's §2 "zero arbitration code" claim
would need a fallback (e.g., explicitly setting `mouse_filter =
MOUSE_FILTER_PASS` or clearing `focus_neighbor_*` during
`PREVIEW_*` states), which the ADR does not currently name but could adopt
without disturbing its other decisions (§1/§3/§4/§5 are independent of this
question). I have not touched the ADR's Status field or its content — that
remains yours to update once you've run the live checks.
