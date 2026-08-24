# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-24
> **Template**: Interaction Pattern Library

---

## Overview

This library catalogs the reusable interaction patterns for OVERCLOCK's in-match interface — the shared vocabulary every future screen/HUD spec should reference rather than reinvent. Because no per-screen UX specs exist yet, this initial catalog was built directly from the 12 system GDDs' UI Requirements sections and the four governing architecture decisions (ADR-0013 board rendering/picking, ADR-0014 input & focus, ADR-0015 command FSM, ADR-0016 HUD) rather than extracted from existing specs. As `/ux-design` authors individual screens (HUD, faction picker, etc.), those specs should cite patterns by name from here, and any new pattern they introduce should be added back to this library rather than left as a one-off.

---

## Pattern Catalog

| Pattern | Category | One-line summary |
|---|---|---|
| Board Cursor Navigation | Navigation | Keyboard/gamepad grid-axis cursor stepping — the non-mouse equivalent of hover |
| Salient-Tile Cycle/Jump | Navigation | Jump directly between only the relevant tiles instead of stepping one at a time |
| Three-State Focus Indicator | Feedback | Mouse-hover / board-cursor / menu-focus, each visually distinct, precedence = most-recently-moved |
| Hover-Preview-Commit Loop | Modal/Overlay | The core select→preview→commit flow shared by Move/Attack/Build/Produce/Research |
| Board Overlay Taxonomy | Overlay / Data Display | The 9-class tile-highlight vocabulary for legality/affordability/outcome |
| Inline Cost/Damage Readout | Data Display | The single exact-value preview number, anchored to the active locus |
| AP Counter Current→Projected Echo | Data Display | The HUD's AP counter shows `current → projected` live during preview |
| Standard Cancel | Input | Right-click/ESC backs out one preview level, always free |
| Hold-to-Confirm Refund | Input / Modal | Press-and-hold gate for destructive refund actions (double-click-proof) |
| Affordability Dimming | Feedback | Dim/hatch unavailable options — never hide, never color-code red |
| Pip-vs-Numeric Display Branch | Data Display | Low-max stats show as pips, high-max stats show as numeric `current/max` |
| Snap, Never Tween | Feedback (base convention) | Committed values snap instantly; only previews use static (non-motion) differentiation |
| Standard Button | Input (base control) | Base clickable-control state set (default/hover/keyboard-focus/pressed/inert) other patterns compose with |
| Scroll List | Data Display / Input | Read-only, append-driven scrollable list (newest on top, oldest drops at capacity) |
| Value Slider | Input | Continuous numeric setting with a live-applied value and a readable numeric echo |
| Setting Toggle | Input | Binary on/off setting, applied immediately, labelled by state not by colour |

---

## Patterns

### Board Cursor Navigation

**Category**: Navigation
**Used In**: The board, during any preview state (Move/Attack/Build/Deploy target selection) — the keyboard/gamepad equivalent of mouse-hover

**Description**: A free grid cursor, distinct from Godot's `Control` focus system, that steps one tile at a time along the logical grid's axes in response to D-pad/arrow-key/gamepad-stick input. It exists because the board isn't made of discrete focusable widgets — it's a free 2D surface — so native UI focus traversal doesn't apply. The cursor position *is* "hover" for players without a mouse.

**Specification**:
- Input: `ui_up`/`ui_down`/`ui_left`/`ui_right` step the cursor one tile per press, along **grid axes** — never the iso screen's visually-diagonal directions (a press always means "one tile toward my faction's forward/back/left/right," regardless of how that renders on the isometric board).
- The cursor can only occupy in-bounds tiles; a step toward an out-of-bounds tile is a no-op (cursor holds position, no wraparound).
- When a menu `Control` currently holds keyboard focus, the same arrow-key input drives that menu's focus traversal instead — the board cursor and menu focus never both react to one keypress (see *Three-State Focus Indicator* for the precedence rule).
- Visual/audio feedback: the cursor renders its own on-board glyph, anchored to the tile like every other on-board glyph — distinct from the mouse-hover treatment (they usually coincide but can diverge; both must be visible simultaneously without being confusable).
- Accessibility: this pattern *is* the accessibility requirement — it's what makes every board interaction reachable without a mouse. No motion/timing constraint (steps are discrete, self-paced).

**When to Use**: Any screen or mode with a free grid surface a player must target (the game board, and any future grid-like screen).
**When NOT to Use**: Menus, lists, or any UI made of discrete widgets — use native `Control` focus traversal there instead (see *Three-State Focus Indicator*).

**Reference**: On-board glyph appearance is an art-bible gap (not yet designed) — noted as an open item.

---

### Salient-Tile Cycle/Jump

**Category**: Navigation
**Used In**: The board, during any preview state — a keyboard/gamepad-only accelerator layered on top of Board Cursor Navigation

**Description**: One-tile-at-a-time stepping is too slow for a distant target on a large board. This pattern gives keyboard/gamepad players a dedicated jump input that skips the cursor directly between *salient* tiles only — the reachable-move frontier, legal attack targets, or legal build/deploy tiles, depending on what's currently being previewed — so a distant target is one press away instead of twenty.

**Specification**:
- Input: a dedicated shoulder-button (or Tab) — **not** the same binding as menu focus traversal, so re-authoring one never silently shadows the other.
- Behavior: jumps to the next salient tile in a fixed, deterministic order (not "nearest first" — consistent, repeatable ordering so players can learn it), wrapping from the last candidate back to the first.
- Only active when a candidate set exists (a preview is open with at least one salient tile); a press with no candidates is a no-op.
- No-op is silent — no error state needed, since there's nothing to cycle to.

**When to Use**: Any preview state with a salient-tile set worth accelerating to (reachable tiles, legal targets, legal build/deploy tiles).
**When NOT to Use**: `IDLE`/no-selection state — there's no candidate set to cycle.

**Reference**: None yet.

---

### Three-State Focus Indicator

**Category**: Feedback
**Used In**: Every screen with both a board and menu/HUD controls — i.e., the core in-match view

**Description**: The interface has three architecturally distinct "what am I pointing at" concepts that must never be visually confused with each other: mouse-hover (pointer position), board cursor (keyboard/gamepad grid position), and menu keyboard-focus (the highlighted verb in a `Control`-based menu). Only one drives the active preview/cost-readout at a time, but a player needs to be able to tell *which* input source is currently "live" at a glance.

**Specification**:
- Three visually distinct treatments, each **non-hue-redundant** (per the art bible's Non-Hue Semantic Layer — never rely on color alone to distinguish them, since faction hues and state colors already own that channel).
- Precedence rule: whichever input source moved most recently owns the active locus. A mouse motion takes over from the board cursor; the next directional key-press hands it back. This is automatic — the player doesn't need to "switch modes."
- The active locus drives the single cost/damage readout and any D-3-style hypothetical preview — there is never more than one live preview target, so there's no ambiguity about which glyph set is "the real one" even if mouse and board-cursor point at different tiles.
- Menu keyboard-focus uses the engine's native focus-ring styling (a distinct `StyleBox` from hover), so it's automatically visually separate from board-space indicators.
- Accessibility: this pattern directly satisfies "no hover-only interaction" — every preview reachable by mouse-hover is also reachable by moving the board cursor onto the same tile.

**When to Use**: Universal — this is a base convention every board+menu screen inherits, not an opt-in choice.
**When NOT to Use**: N/A — always applies where both board and menu focus coexist.

**Reference**: None yet — the concrete glyph/StyleBox treatments are an art-bible/implementation gap.

---

### Hover-Preview-Commit Loop

**Category**: Modal/Overlay (core interaction flow)
**Used In**: Move, Attack, Build, Produce, and Research — every AP-costed action in the game shares this exact flow

**Description**: The interface's single unifying interaction pattern, and the mechanical expression of the game's "see the cost before you pay it" pillar. A player selects an entity, picks a verb from a contextual menu, the board enters a preview mode showing an overlay (legal destinations/targets/tiles) plus a live, exact cost/outcome readout that updates as the active locus (mouse or board cursor) moves, and a single click/confirm on a highlighted option commits the action. Every verb (Move, Attack, Build, Produce, Research) is a different *skin* on this same loop — same overlay-then-preview-then-commit shape, different data underneath.

**Specification**:
- Flow: Select entity → contextual menu (only legal + affordable verbs shown as available) → pick verb → board enters preview (overlay renders + cost/outcome readout tracks the active locus) → confirm on a highlighted option → commit (state updates, menu re-filters for the same entity) → repeat or back out.
- The preview is a **guarantee, not an estimate** — because the underlying systems are deterministic, the number shown before commit is exactly what happens after commit. No hedging language, no ranges.
- Every preview value is a live read from the owning system at render time — never a locally cached or re-derived number (this is what keeps the preview trustworthy: it can't drift out of sync with what commit will actually do).
- Cancel (right-click/ESC) exits the current preview back to the menu, or the menu back to no-selection, at every step — see *Standard Cancel*.
- A rejected commit (something changed the board between preview and click) never spends anything; the interface swallows the rejection, refreshes the preview data, and stays where the player was.
- Accessibility: fully keyboard/gamepad-navigable via Board Cursor Navigation + menu focus traversal — no step in this loop is mouse-only.

**When to Use**: Every AP-costed player action, without exception — this is the canonical loop, not a per-verb special case.
**When NOT to Use**: Never skip it for an AP-costed action; a "free" or instant action that bypasses preview would violate the game's core promise that costs are always visible before commit.

**Reference**: None yet.

---

### Board Overlay Taxonomy

**Category**: Overlay / Data Display
**Used In**: Move, Attack, Build, and Deploy preview states — the on-board visual language for "what can I do from here"

**Description**: A fixed set of nine tile-highlight classes that every board-space preview draws from. Rather than each verb inventing its own highlight language, all of them share one vocabulary — a player who learns what "in-cap reachable" looks like for Move already knows what it means for Deploy. The classes: in-cap (affordable) reachable/target, over-cap (surcharged but still reachable) tile, legal attack target, blocked-by-friendly, out-of-range, AREA-attack dead-zone, legal build/deploy tile, cancel-refund indicator, and the D-3 "attack-possible-after-this-move" hypothetical echo.

**Specification**:
- Exactly one overlay mode is active at a time (state-machine-driven — the current preview state determines which classes can appear together; e.g. Move preview never shows attack-target classes).
- Each class has a distinct visual treatment that does **not** rely on hue alone — the Non-Hue Semantic Layer applies here as everywhere (in-cap vs. over-cap is a fill/hatch distinction, not a color distinction; the three blocked-shot reasons — blocked-by-friendly, out-of-range, inside-dead-zone — read as distinct from each other, not just "grayed out").
- Overlays render on the grid itself, drawn at the tile's exact screen position — never offset or approximated.
- The D-3 hypothetical echo (attack-possible-after-this-move) is a *preview inside a preview* — it appears during a Move preview to answer "if I move here, could I then attack?" without the player needing to commit the move first to find out.
- Accessibility: overlay classes must remain distinguishable for colorblind players by construction, since they're never color-only to begin with.

**When to Use**: Any board-space preview that needs to communicate legality/affordability/outcome across multiple tiles at once.
**When NOT to Use**: Single-target readouts that don't need a multi-tile highlight (see *Inline Cost/Damage Readout* for the single-value case).

**Reference**: None yet — exact per-class visual treatment (fill patterns, hatch density, ring style) is an art-bible gap.

---

### Inline Cost/Damage Readout

**Category**: Data Display
**Used In**: Every Hover-Preview-Commit Loop instance — the single "what will this cost/do" number

**Description**: Rather than a fixed panel showing preview costs, the readout anchors to the currently-hovered tile or target — the number appears where the player's eye already is. It's the single source of truth for "what happens if I commit right now," always exact (never a range or estimate), and always tracks whichever input source (mouse or board cursor) currently owns the active locus.

**Specification**:
- Position: anchored to the active-locus tile, not a fixed screen location — moves with hover/cursor.
- Update behavior: **snaps** on every locus change, zero interpolation — the readout must never lag behind the input, since the "see the cost before you pay it" promise breaks if the number is stale even for a frame.
- Unaffordable case: shows the current (real) value plus an "insufficient" indication via dimming/hatching on the arrow or delta — never a negative number, never a red numeral (Non-Hue Semantic Layer).
- Exempt from value-dimming itself: even when the *action* is unaffordable, the cost/damage number stays at full brightness and full weight — dimming applies to affordances (the greyed-out menu verb), never to the quantity a player needs to read to decide.
- Accessibility: reachable by both mouse-hover and board-cursor position (inherits from Three-State Focus Indicator) — never a mouse-only readout.

**When to Use**: Any point in the Hover-Preview-Commit Loop where a single tile/target's cost or outcome needs to be shown.
**When NOT to Use**: Multi-tile legality communication — use Board Overlay Taxonomy for that instead; this pattern is for the one active number, not the highlight set.

**Reference**: None yet.

---

### AP Counter Current→Projected Echo

**Category**: Data Display
**Used In**: The HUD's AP counter, live during any preview state

**Description**: The single most important number on screen (the game's unified action-point pool) shows both its real, committed value and — when a preview is open — what it would become if the current preview were committed, in the format `current → projected`. This is the HUD-level expression of the same "see the cost before you pay it" promise the board-space readout gives per-tile, but for the one number that matters across the whole turn.

**Specification**:
- Format: committed value at full weight, projected value at a lighter weight of the *same* size and font — never a separate color-coded widget, never a second location on screen.
- The echo **snaps** in and out as the preview opens/closes — inert weight-differentiated typography, no glow, no tween. A fast mouse-sweep across tiles must never produce visual chatter.
- Force-cleared synchronously on any turn transition, *before* the next turn's fill animation is evaluated — this closes a race where the interface's exit-to-no-selection and the HUD's turn-start fill could otherwise be driven by unordered signals.
- The committed value itself only ever moves on a real commit — it never counts up/down, it snaps directly to the new number with a fast flare-and-decay riding on top (the "this really happened" signature).
- The AP counter is always the single largest numeral on the HUD — no other number may match or exceed it (this is a cross-pattern constraint every other numeric display must respect).
- Accessibility: the glow/flare behaviors are reinforcing, never the sole carrier of state — the number, weight, and (where present) icon state always independently communicate AP-available vs. AP-spent.

**When to Use**: Whenever a preview is open (any state in the Hover-Preview-Commit Loop) and the local player's own AP is being spent.
**When NOT to Use**: Never appears over the opponent's AP counter — only the local player's live preview drives an echo.

**Reference**: None yet — exact typography/weight values are an art-bible/type-selection gap.

---

### Standard Cancel

**Category**: Input
**Used In**: Every preview state in the Hover-Preview-Commit Loop (Move/Attack/Build/Produce/Research)

**Description**: The universal "back out" gesture — right-click or ESC — that exits the current preview one level at a time without spending anything. It's the same input everywhere, so a player never has to relearn how to back out of a mistake regardless of which verb they're in.

**Specification**:
- Input: right-click (mouse) or ESC (keyboard) or the equivalent gamepad Cancel/B button.
- Behavior: exits exactly one level — a live preview backs out to the contextual menu; the menu (with nothing previewed) backs out to no-selection. It never skips levels or exits the whole flow in one press.
- Always spends zero AP and makes zero state changes — cancel is always free, at every step.
- Available at any point during a preview *except* mid-commit-flash (the brief window right after a commit, where the previous preview no longer exists to cancel out of).
- Accessibility: available via both mouse and keyboard/gamepad equally — this is not a mouse-only affordance.

**When to Use**: Every preview-capable state, as the default "I changed my mind" exit.
**When NOT to Use**: Destructive actions that need a stronger confirmation gate than a simple preview — see *Hold-to-Confirm Refund* for that distinct case.

**Reference**: None yet.

---

### Hold-to-Confirm Refund

**Category**: Input / Modal
**Used In**: Cancelling an Under-Construction structure (and any future destructive AP-refund action)

**Description**: Destroying an in-progress build for a partial refund is destructive in a way a normal preview-and-commit isn't — there's no "undo" once the structure is gone, and the action is bound to the same selection state a rapid double-click could otherwise stumble into. Instead of a second confirm click (which a double-click could still produce), the player must press-and-hold the affordance for a fixed duration to commit it.

**Specification**:
- Input: press-and-hold (mouse or keyboard/gamepad equivalent) for a fixed threshold duration.
- Releasing before the threshold aborts with no refund and no state change — the hold must complete, not just begin.
- The refund amount is shown **before** the hold completes, not just after — same "see the cost before you commit" promise as every other pattern, applied to a negative-outcome action.
- Structurally double-click-proof: a rapid double-click cannot sustain a hold long enough to cross the threshold, so the destructive path can never be triggered by a mis-click.
- This is a bounded sub-condition of the entity's normal selected state, not a separate confirmation screen or modal — the player never leaves their current context to do this.
- Accessibility: the hold duration is a fixed, generous threshold (not a twitch-timing requirement) — and the affordance is reachable by keyboard/gamepad hold, not just a mouse press-and-hold.

**When to Use**: Any action that destroys committed progress/investment for a partial refund, where a single click would be too easy to trigger accidentally.
**When NOT to Use**: Reversible actions with no loss (use *Standard Cancel* instead) — this pattern is reserved for genuinely destructive, refund-bearing actions.

**Reference**: None yet — exact hold duration is a tuning value, not yet locked.

---

### Affordability Dimming

**Category**: Feedback
**Used In**: Every menu verb, build option, research option, and any other selectable-but-conditionally-available UI element

**Description**: When an action is illegal or unaffordable, it's shown dimmed and/or hatched — never hidden, and never recolored (e.g. red). This keeps the full option space visible at all times (a player always knows what exists, even if they can't currently afford it) while still making unavailability unambiguous without relying on color.

**Specification**:
- Unavailable options render at reduced value/brightness, optionally with a hatch pattern overlay — the same vocabulary the board overlay taxonomy uses for over-cap/blocked states.
- Never hidden: an unaffordable Build option, an in-progress or completed Research tech, a legally-blocked attack — all stay visible with their unavailability reason attached (not just "greyed out with no explanation").
- Never color-coded red or any other hue-based "danger" signal — dimming/hatching is the entire vocabulary (Non-Hue Semantic Layer).
- The reason for unavailability is distinguishable where multiple reasons exist (e.g. "already researched" vs. "in progress elsewhere" vs. "can't afford" are shown as distinct states, not collapsed into one generic "unavailable").
- Accessibility: because this never depends on color, it's colorblind-safe by construction; the reason text/icon should also be readable at standard UI text-scaling.

**When to Use**: Any selectable option that can be conditionally unavailable (cost, legality, or already-consumed state).
**When NOT to Use**: Never use a red/color-only "disabled" treatment anywhere in the game — this is the one and only vocabulary for unavailability.

**Reference**: None yet — exact dim percentage / hatch density is an art-bible gap.

---

### Pip-vs-Numeric Display Branch

**Category**: Data Display
**Used In**: HP display (and any future stat with a similarly wide value range across entity types)

**Description**: A stat display branches between two presentations based on its maximum value: below a fixed threshold, it renders as discrete pips (individual marks that drain one at a time on damage); at or above the threshold, it renders as a numeric `current/max` pair, stepping in whole integers. This keeps low-HP infantry readable at a glance (a few pips) while keeping high-HP structures from needing forty pips crammed into a small space.

**Specification**:
- Branch point: a single configured threshold value — entities with max stat value below it use pips, at-or-above use numeric. The boundary is inclusive on the numeric side (a value exactly at the threshold renders numeric, not pips).
- Pip mode: pips drain one at a time as damage is taken — never a fractional/partial pip.
- Numeric mode: always whole integers, never a smoothly animating bar — consistent with the project-wide "snap, never tween" convention (see *Snap, Never Tween*).
- Both modes update on the same event-driven basis (a real state change), never polled or interpolated.
- Accessibility: numeric mode is inherently screen-reader/text-scaling friendly; pip mode should carry an accessible numeric equivalent on request (e.g. hover/inspect readout) rather than requiring the player to count pips visually.

**When to Use**: Any stat where the value range spans small (single-digit, pip-friendly) to large (structure-scale, numeric-friendly) across different entity types.
**When NOT to Use**: A stat with a narrow, consistent range across all entities that carry it — a single display mode may suffice without needing the branch.

**Reference**: None yet — exact threshold value is a tuning knob, not yet locked here (owned by the relevant config).

---

### Snap, Never Tween

**Category**: Feedback (foundational/cross-cutting convention)
**Used In**: Every committed-value change in the game — AP counter, hp, cost previews, any numeric readout

**Description**: This isn't a single widget pattern — it's the project-wide rule every numeric/state display above already assumes: a value that has genuinely *changed* (a real commit happened) snaps instantly to its new value, never animates by counting up/down or tweening smoothly. Motion/glow effects layered on top of a snap communicate "this really happened"; a static weight or dimming shift communicates "this might happen" (a preview). The two must never be confused.

**Specification**:
- On a real commit: the displayed value jumps directly to the new number in one frame. Any accompanying flourish (flash, glow-decay) is a *reinforcement* riding on top of the snap, never a substitute for it, and never delays the number itself from being correct.
- On a preview/hypothetical (nothing committed yet): the value change is communicated through static means only — weight, dimming, an arrow/echo — with **no** glow, flash, or motion. This is the boundary that keeps a fast mouse-sweep from producing visual noise.
- No progress-bar-style interpolation anywhere a discrete game-state value is shown — bars imply continuous quantities, but every value in this game (AP, hp, costs) is a discrete integer.
- Accessibility: because the flourish is always reinforcement rather than the sole signal, this pattern is inherently compatible with a future reduced-motion setting — turning off the flourish loses nothing functionally, only polish.

**When to Use**: Universal — every numeric or discrete-state display in the game inherits this rule.
**When NOT to Use**: N/A — this is a base convention, not an opt-in pattern.

**Reference**: None yet.

---

### Standard Button

**Category**: Input (base control)
**Used In**: Build button, End Turn control, and any future clickable HUD/menu affordance — the base state set every other interactive control composes with (e.g. *Hold-to-Confirm Refund* is this pattern plus a hold-gate; menu verbs in the *Hover-Preview-Commit Loop* are this pattern plus *Affordability Dimming*)

**Description**: The base interaction-state set for any clickable `Control` in the game — the foundation other patterns build on rather than a new visual language of its own. Defines the minimum state set every button-like element must support so implementers aren't inventing hover/focus/disabled behavior per-widget.

**Specification**:
- States: **Default** (rest, available) / **Hover** (mouse pointer over it — `hover` StyleBox) / **Keyboard-Focused** (holds keyboard/gamepad focus via `grab_focus()` — distinct `focus` StyleBox, per *Three-State Focus Indicator*) / **Pressed/Active** (mid-click, or held "live" while a related preview is open — e.g. the Build button while `PREVIEW_BUILD` is active) / **Inert** (present but non-interactive — turn-scoped, e.g. during the opponent's turn).
- Mouse-click focus and keyboard/gamepad focus are tracked and styled independently (`grab_click_focus()` vs `grab_focus()`) — a control can show hover and keyboard-focus simultaneously without the two treatments colliding.
- Inert controls render at full visibility (never hidden) but accept no input — composes with *Affordability Dimming* when the inertness is due to unaffordability rather than turn-scoping.
- Accessibility: every button reachable by click and by keyboard/gamepad focus traversal; inert state never removes the element from the keyboard traversal order silently — see individual consuming patterns for whether inert controls are skipped or merely non-actionable.

**When to Use**: Any single clickable affordance (not a preview-driven board interaction — those use *Hover-Preview-Commit Loop*).
**When NOT to Use**: Board-space tile interactions (use *Board Cursor Navigation* + *Board Overlay Taxonomy* instead) — this pattern is for discrete `Control` widgets only.

**Reference**: None yet.

---

### Scroll List

**Category**: Data Display / Input
**Used In**: The action log (the only scrollable list currently in the design; the base pattern for any future list)

**Description**: A read-only, append-driven scrollable list, newest entry on top, with a bounded capacity that silently drops the oldest entry once full. The list itself never mutates game state — it's a display of already-resolved events.

**Specification**:
- Input: mouse wheel or click-drag to scroll; keyboard/gamepad scroll (e.g. up/down) when the list holds keyboard focus.
- New entries append at the top; once at capacity, the oldest entry is dropped — the player never sees a "list full" state, it just ages out silently.
- Entries render in strict append order — no re-sorting, no client-side reordering.
- Uses *Standard Button*'s focus conventions to become keyboard-scrollable (the list itself is the focusable element, not each entry).
- Accessibility: scrollable via keyboard once focused, not mouse-only; a screen-reader-style "announce newest entry" hook is a reasonable future addition but not yet specified (tracked as an extension, not a requirement here).

**When to Use**: Any bounded, append-only, read-only feed of events.
**When NOT to Use**: Interactive/selectable lists (e.g. a future inventory or menu list) — those would need selection-state handling this pattern doesn't cover; treat as a distinct pattern if one is needed later.

**Reference**: None yet.

---

## Animation Standards

| Element | Trigger | Duration/Behavior | Status | Owning Pattern |
|---|---|---|---|---|
| Cost/damage readout update | active locus changes | Zero-duration snap, no interpolation | **Locked** (zero, by design) | Inline Cost/Damage Readout |
| AP counter preview echo in/out | preview opens/closes | Zero-duration snap, inert weight-shift only | **Locked** (zero, by design) | AP Counter Current→Projected Echo |
| AP counter commit tick | real commit | Instant snap to new value + flare-and-decay riding on top | TBD (art bible) | AP Counter Current→Projected Echo |
| AP counter fill-flourish | turn start, AP unspent | Slow, low-amplitude breathe loop | TBD (art bible) | Snap, Never Tween |
| Hold-to-Confirm Refund threshold | press-and-hold begins | Fixed hold duration; release before threshold aborts with no partial effect | TBD (config value) | Hold-to-Confirm Refund |
| hp-pip drain | damage taken (pip mode) | One pip removed per point of damage, no partial-pip animation | **Locked** (discrete, by design) | Pip-vs-Numeric Display Branch |

All non-locked rows are intentionally left as "TBD" — this table exists so every unlocked timing value lives in one place instead of scattered across pattern entries; it does not invent numbers this session has no authority to set.

---

## Gaps & Patterns Needed

Screens/interactions visible in the GDDs/ADRs that will need their own patterns, not yet formalized here — each is a `/ux-design` screen spec away from surfacing what it needs:

- **Faction Picker** (faction-identity.md) — needs a pattern for the experimental-faction acknowledgment gate (an explicit "these values are unvalidated" step before an unbalanced pick locks) and a starting-loadout preview-before-commit pattern, distinct from the board's Hover-Preview-Commit Loop since it's a setup-screen, not in-match, decision.
- **Victory/Defeat Overlay** (game-hud.md/ADR-0016) — a one-frame-preemption pattern (must interrupt any in-flight turn banner immediately) isn't yet generalized; currently only specified for this one case.
- **Detail/Inspection Panel Pinned-vs-Peek** (command-action-interface.md/ADR-0016) — the panel needs a visual distinction between a persistently *selected* entity and one merely being *inspected* (hover/peek); ADR-0016 flags this as binding but non-hue, deferred to `/ux-design`.
- **Action Log Display** (game-hud.md) — the ring-buffer *data model* is architected (ADR-0016 §5), but no pattern yet covers how entries visually append/scroll/age.
- **On-Demand Reveal Toggle** (game-hud.md) — the income-breakdown's hover-or-click expand/collapse behavior needs its own pattern once a second on-demand element exists (currently a one-off).
- **Audio Feedback Priority** (ADR-0016 §7) — a single-owner dispatch with a total priority order (GameOver > turn-stinger > completion-cue > AP-fill) and ducking exists architecturally, but has no UX-facing pattern describing what the player actually hears/when.

### Value Slider

**Category**: Input
**Used In**: Settings screen (UI Scale). The base pattern for any continuous numeric setting.

**Description**: A draggable track for a bounded numeric value, paired with a **numeric echo** of the
current value. Added 2026-08-24 when `/ux-review` found the settings screen had invented one: the
library had no slider, so the next screen needing one would have invented a second.

**Specification**:
- States: composes *Standard Button*'s state set (default / hover / keyboard-focus / pressed /
  inert) on the grab handle — a slider is a control, and gets the same focus treatment as one.
- **A slider is never the only readout of its own value.** A numeric echo sits beside it (e.g.
  "100%"), because a handle position communicates *approximately* and a settings value is exact. It
  also gives the value to a player who cannot judge the handle's position precisely.
- **Applies live, on change** — not on release and not on a confirm step. A setting the player
  cannot see take effect is one they cannot evaluate.
- Keyboard/gamepad: arrows adjust by one `step` when focused. The step must be coarse enough that
  crossing the whole range is not tedious (a 75–150% range at 0.05 is 15 presses, not 75).
- Bounds are enforced at the model, not the widget — a value arriving from a hand-edited config file
  must be clamped on load, or the widget renders a state the player cannot get back from.
- Accessibility: reachable and adjustable by keyboard/gamepad, never drag-only. The numeric echo is
  what makes it usable without fine motor control.

**When to Use**: A bounded, continuous, immediately-applicable value.
**When NOT to Use**: Discrete choices (use a toggle or a list) or anything needing confirmation
before it takes effect.

**Reference**: `src/ui/settings/settings_screen.gd` (UI Scale row).

---

### Setting Toggle

**Category**: Input
**Used In**: Settings screen (Reduced Motion). The base pattern for any binary preference.

**Description**: An on/off control for a preference that applies immediately. Added alongside *Value
Slider* and for the same reason.

**Specification**:
- States: composes *Standard Button*'s set; the on/off state is carried by the control's own
  position/fill **and** its label — never by colour alone (the Non-Hue Semantic Layer applies to
  settings UI exactly as it does to the board).
- **Applies immediately**, like *Value Slider*. No OK/Cancel.
- The label states **what the setting is**, not what pressing it will do ("Reduced Motion", not
  "Turn on reduced motion") — so the row reads the same whichever state it is in.
- Accessibility: reachable by keyboard/gamepad; the state must be discernible without colour and
  without relying on animation to show the transition.

**When to Use**: A binary preference with no destructive consequence.
**When NOT to Use**: Anything destructive or hard to reverse — that wants a confirm step (see
*Hold-to-Confirm Refund* for the in-match equivalent).

**Reference**: `src/ui/settings/settings_screen.gd` (Reduced Motion row).

---

---

## Open Questions

- No player journey map exists (`design/player-journey.md`) — every pattern above was designed against GDD/ADR requirements, not validated player emotional-state context. Template available at `.claude/docs/templates/player-journey.md`.
- No accessibility tier has been committed (`design/accessibility-requirements.md` missing) — patterns above assume a WCAG-AA-ish baseline (keyboard-reachable, non-hue-redundant, no twitch timing) but this hasn't been formally ratified.
- Several tuning values are named but deliberately left unlocked here (owned by config/art-bible, not this library): Hold-to-Confirm Refund's hold duration, Affordability Dimming's dim%/hatch density, Pip-vs-Numeric's threshold value, AP Counter Echo's exact typography weights.
- `BoardCursor`'s on-screen glyph appearance is an unresolved art-bible gap (named in both ADR-0013 and ADR-0014) — the anchor math exists, the pixels don't yet.
- Camera model (pan/zoom vs. fixed) is explicitly left open by ADR-0013 (OQ-8) — could affect how Board Cursor Navigation and on-board glyph anchoring feel in practice; not blocking this library, but worth revisiting once decided.
