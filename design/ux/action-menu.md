# UX Spec: Contextual Action Menu

> **Status**: Draft — awaiting `/ux-review`
> **Author**: main session, from `design/gdd/command-action-interface.md` + four user decisions (2026-08-24)
> **Last Updated**: 2026-08-24
> **Journey Phase(s)**: Core in-match loop — every AP-costed action passes through this surface
> **Platform Target**: PC (Steam / Epic) — Keyboard/Mouse primary, Gamepad secondary (partial)
> **Template**: UX Spec
> **Scope**: Vertical Slice. Move / Attack / Produce / Wait / Cancel Build. Build stays a
> player-level HUD control (CR-5) and is specified here only where it hands off.

> ### Why this exists now
>
> The menu is not a new idea: `command-action-interface.md` CR-1 has always described the loop as
> *select → menu → verb → preview → commit*, and `CommandFSM.menu_model()` — which verbs are legal,
> which are disabled, and the reason bitmask for each — has been built and unit-tested since Story
> 001. What never shipped is the **surface that shows it**. The vertical slice stood in a
> one-key-per-command scheme as scene glue, and it grew until the on-screen legend named eleven
> bindings across two lines. A playtester reported it on 2026-08-24 as the thing to fix.
>
> This spec therefore mostly *transcribes* decisions the GDD already made, and records four that it
> did not.

---

## Purpose & Player Need

The player has selected something of theirs and wants to know **what it can do right now, what each
option costs, and why the greyed-out ones are greyed out** — without having memorised a keyboard.

The failure this replaces is specific and worth naming: under per-command keys, a verb that is
illegal or unaffordable is *indistinguishable from a verb that does not exist*. Pressing [M] on a
unit that has already moved produces a flash message; pressing [P] on a non-producer produces a
different flash message; nothing on screen ever tells the player, before they press anything, which
of the five verbs are live. CR-4's "shown disabled with its reason, not hidden" is unimplementable
without a menu, because there is nowhere to show a disabled thing.

---

## Player Context on Arrival

Mid-match, mid-turn, holding a finite AP pool they are trying to spend well. They have just clicked
(or cursor-selected) one of their own entities. They are **deciding**, not executing — the menu's
job is to make the decision cheap, and then get out of the way.

Two arrival routes, and the menu is identical in both:

| From | Trigger | Notes |
|---|---|---|
| Board click | Left-click an owned entity with ≥1 legal action (CR-3) | Mouse-primary path |
| Board cursor | Confirm (Enter / A) on an owned entity | Keyboard/gamepad path — the cursor *is* the hover |

A third route matters as much as the first two: **re-entry after a commit**. The menu re-opens on
the same entity, re-filtered, so move→attack is one fluid sequence (AC-25) rather than a
re-selection.

---

## Navigation Position

Not a screen. A transient, non-modal, board-anchored surface owned by the Command & Action
Interface, living entirely inside `CommandFSM.State.ENTITY_SELECTED`. It has no parent screen and
no children other than its own one-level submenu.

The pause overlay and the game-over overlay both preempt it; it never blocks either.

---

## Entry & Exit Points

| Event | Result |
|---|---|
| Select own entity with ≥1 legal action | Menu opens (fade 150ms), first enabled row takes keyboard focus |
| Select own entity with **no** legal action | Menu still opens; every verb disabled-with-reason except Wait (AC-10) |
| Select enemy / neutral / empty | Menu does **not** open; SELECTED panel shows read-only inspection (CR-3) |
| Pick a verb | Menu closes, board enters that verb's preview |
| Pick Produce | **Submenu** opens; parent menu stays visible and dimmed |
| Back out (Esc / right-click / B) from submenu | Submenu closes, parent menu re-focuses |
| Back out from menu | Deselect → IDLE |
| Back out from preview | Preview clears, menu re-opens on the same entity |
| Commit | Menu re-opens on the same entity, re-filtered — **unless** the entity died or has no remaining legal action, then IDLE |
| Wait | Menu closes, deselect → IDLE, nothing spent |
| End Turn / opponent's turn / game over | Menu closes |

---

## Layout Specification

### Placement — floating, beside the entity

The menu **follows the selection** (user decision, 2026-08-24; matches the GDD's element inventory:
"floats near the selected entity, never covering it or the tiles it can act on; auto-repositions to
stay on-screen at board edges").

The placement rule, in order:

1. **Default side: right.** The menu's left edge sits one full tile-width right of the entity's
   ground anchor, vertically centred on that anchor. One tile of clearance is what keeps it off the
   entity's own sprite *and* off the eight tiles adjacent to it — the tiles a move or attack preview
   is most likely to highlight.
2. **Flip when it would overflow.** If the right-placed menu's right edge would pass the viewport's
   safe margin, mirror it to the left of the entity by the same tile-width gap.
3. **Clamp vertically**, never horizontally. Vertical clamping slides the menu along the entity;
   horizontal clamping would slide it *over* the entity, which rule 1 exists to prevent.
4. **Re-anchor on camera move and on window resize**, since the anchor is a board position and the
   menu is screen-space.

### Placement — the Build picker is the exception

The player-level Build picker (CR-5) has no entity to float beside, so it does **not** use the rule
above. It hangs off the HUD's Build control: its **bottom-right corner lands on the ACTIONS panel's
top-right corner**, so the list grows *up and to the left*, out of the button that summoned it.

The verb menu's flip rule would be meaningless here — a plate anchored in a screen corner has no
"other side" to flip to, and centring it on the anchor the way the verb menu does put half the list
below the screen edge and the rest under the status legend. Growing inward from the corner is the
only placement that reads as belonging to its button.

> The GDD's stronger phrasing — never covering *any* tile the entity can act on — is not
> achievable in general: a reachable set can surround the entity on all sides, and there is no
> off-board space to retreat to. The one-tile-gap rule is the honest, testable version, and it
> covers the case the phrasing was written for.

### Information hierarchy

1. **The verb** — the decision being made.
2. **Its cost** — for the verbs that carry one, so the AP pool is spent knowingly.
3. **Its shortcut** — dim; present for learning, never competing with the verb.
4. **Its reason for being unavailable** — only on disabled rows, and only there.

### Component inventory

| Component | Purpose |
|---|---|
| Menu plate | `HudPanel` palette (`BACKING` / `BORDER`) so it reads as the same HUD, not as OS chrome |
| Verb row | Label + shortcut hint; enabled rows are focusable buttons |
| Disabled verb row | Same row, greyscale label + lock glyph + reason text (interaction-patterns.md item 8) |
| Submenu plate | Second plate, same palette, listing produce options with dual costs |
| Focus indicator | Distinct from mouse-hover — see Accessibility, this is the Godot 4.6 dual-focus case |

### ASCII wireframe — unit selected, all verbs live

```
                                       ┌──────────────────────────┐
                                       │  Move              [M]   │
              ▓▓▓▓                     │  Attack            [A]   │
             ▓ 🤖 ▓  ◄── selected      │  Wait              [.]   │
              ▓▓▓▓       (1 tile gap)  └──────────────────────────┘
```

### ASCII wireframe — producer selected, mixed availability

```
   ┌────────────────────────────────────┐
   │  Move          🔒 structures don't │
   │  Attack        🔒 no targets       │
   │  Produce   ▸       [P]             │
   │  Wait              [.]             │
   └────────────────────────────────────┘
```

### ASCII wireframe — Produce submenu open

```
   ┌───────────────────────┐   ┌──────────────────────────────────────┐
   │  Move          🔒 …   │   │  Scout        200 CR + 1 AP          │
   │  Attack        🔒 …   │   │  Trooper      300 CR + 1 AP          │
   │  Produce   ▸   [P]    ├──▸│  Heavy     🔒  450 CR + 1 AP  needs  │
   │  Wait          [.]    │   │                       Credits        │
   └───────────────────────┘   └──────────────────────────────────────┘
        (parent dimmed)
```

A disabled produce row names **the binding pool** — "needs Credits" or "needs AP", never a generic
"unaffordable" (CR-8 / D-2 / AC-6b). When both fail, both are named (AC-8b).

---

## States & Variants

| State | Appearance |
|---|---|
| **Opening** | 150ms fade-in, no movement (CR: "fades in and doesn't move") |
| **Open, verb focused** | Focused row carries the keyboard-focus treatment; mouse-hover carries its own, separately |
| **Row disabled** | Greyscale + lock glyph + reason; visible, **not focusable** |
| **Submenu open** | Parent plate dims to 55%; submenu takes focus |
| **Preview active** | Menu hidden entirely — the board is the surface now, and the menu would compete with the overlay it just opened |
| **Input locked** (post-commit debounce, `input_lock_ms`) | Menu visible, rows inert; no visual change — the window is 120ms and a flicker would read as a fault |
| **Opponent's turn / game over** | Closed |

**Every row is visible in every variant.** A verb is never hidden for being unavailable — that is
the whole point of CR-4, and it is what lets a player learn the rules from the interface.

---

## Interaction Map

| Input | Mouse | Keyboard | Gamepad |
|---|---|---|---|
| Select entity | Left-click it | Move cursor + Enter | D-pad + A |
| Focus a verb | Hover | ↑ / ↓ | D-pad ↑ / ↓ |
| Choose focused verb | Left-click | Enter | A |
| Verb accelerator (skip the menu) | — | M / A / P / B | X / Y / RB / LB |
| Open submenu | Click `Produce ▸` | Enter or → on the row | A or → |
| Back out one level | Right-click | Esc | B |
| Commit inside a preview | Left-click a highlighted tile | Enter on the cursor tile | A |
| Jump cursor between salient tiles | — | `[` | L3 |
| End turn | Click the HUD control | Tab | Back |

### Four decisions this spec makes, because the GDD did not

**1 — Esc backs out first, and only pauses when there is nothing to back out of.**
The GDD's input table says "Cancel / back-out: Right-click **or** ESC". `pause.md` later claimed Esc
for the pause overlay. Both are right about their own screen, and the collision is real. Resolution:
Esc backs out one level (preview → menu → deselect); when the interface is already IDLE with nothing
selected, Esc opens pause. This is the near-universal convention and it makes the destructive
reading — pausing when the player meant to cancel — impossible.

**2 — The two type-cycle bindings are retired, not rebound.**
`board_build_cycle` ([C]/LB) and `board_produce_cycle` ([V]/RB) exist only because there was no way
to *show* a list of types. The submenu is that way. Keeping the cycles would leave two bindings that
mutate a hidden selection the menu now displays — two sources of truth for one choice. They are
removed from the input map and from the Settings screen's rebindable table. Their pad buttons (LB /
RB) are freed and reassigned to Build / Produce.

**3 — `board_act` splits into Move and Attack.**
Today one binding means "move or attack, whichever the cursor tile supports", which is a guess the
interface makes on the player's behalf and cannot explain. Two verbs on the menu need two
accelerators. `board_act` keeps its identity as **Move** (relabelled), and a new `board_attack`
joins the rebindable set.

**4 — Wait deselects; it does not mark the entity done.**
The GDD says Wait "ends this entity's involvement without spending". There is no `WaitAction` and no
persistent per-entity done flag in the simulation, so the only honest implementation is: close the
menu, deselect, spend nothing. The entity remains selectable and cursor-cycle will still stop on it.
See Open Questions OQ-1 — this is a genuine gap between the GDD's wording and the data model, not an
implementation shortcut.

---

## Events Fired

| Event | When | Consumer |
|---|---|---|
| `verb_chosen(verb: int)` | An enabled verb row is activated | Scene glue → `CommandInterface.enter_preview` |
| `produce_type_chosen(type: UnitTypeDef)` | A submenu row is activated | Scene glue → PREVIEW_PRODUCE with that type |
| `dismissed()` | Back-out from the top-level menu | Scene glue → deselect |
| `waited()` | Wait row activated | Scene glue → deselect, no action dispatched |

The menu **never dispatches an action itself** and never reads a balance constant. It renders
`CommandFSM.menu_model()` and `CommandFSM.produce_options()` and reports which row was picked —
the Pass-Through Invariant (TR-cmdui-010) applies to this surface exactly as it does to the FSM.

---

## Transitions & Animations

| Transition | Treatment | Reduced motion |
|---|---|---|
| Menu open | Fade in 150ms, no translation | Instant |
| Menu close | Fade out 100ms | Instant |
| Submenu open | Fade in 120ms | Instant |
| Focus change | Instant — focus must never lag input | Instant |
| Parent dim on submenu | 120ms | Instant |

`GameSettings.reduced_motion` collapses every duration above to zero. Nothing here conveys
information through motion alone, so that costs no meaning.

---

## Data Requirements

| Needs | Source | Notes |
|---|---|---|
| Which verbs, enabled, and why not | `CommandFSM.menu_model(state, entity)` | Already built and tested |
| Which unit types, their dual costs, affordability | `CommandFSM.produce_options(state, entity)` | **New** — pure, same query-only discipline |
| Verb labels and reason wording | This spec's tables, held in the widget | Localisation-ready strings, no concatenated fragments |
| The entity's screen anchor | `BoardRenderer.grid_to_screen` via the camera transform | Same anchor the sprite uses |
| Shortcut glyph per verb | `InputMap` / `GameSettings` bindings | Must reflect a **rebound** key, never a hardcoded letter |

---

## Accessibility

- **Every verb is click-reachable and keyboard-reachable** (technical-preferences: no hover-only
  interactions). The menu is the click-reachable path the accelerators never were.
- **Three distinct attention states**, per the GDD's input notes: mouse-hover, board cursor, and
  menu keyboard-focus. This surface owns the third, and it is the genuine Godot 4.6 dual-focus case —
  mouse focus and keyboard focus are separate subsystems and can both be live, so the focused row's
  indicator must be visually distinct from the hovered row's. ⚠ Redot 26.2 fork parity on this
  behaviour is assumed, not verified (GDD OQ-6).
- **Disabled rows are visible but not focusable.** Focus stops only on rows that do something —
  the same treatment the Settings screen's reset buttons use. The reason text is rendered inline on
  the row, so it is readable without focusing it.
- **Colour is never the only signal.** A disabled row carries greyscale *and* a lock glyph *and*
  words. Affordability in the submenu is text, not a red tint.
- **Shortcut hints render the live binding**, so a player who has remapped Move sees their key.
- **UI scale** (`GameSettings.ui_scale`) applies — the menu is a `Control` under the same scale
  factor as the rest of the HUD.

---

## Localization Considerations

- Verb labels, reason phrases and the cost format are whole strings, never assembled from
  fragments; the cost line is a single format string with positional arguments so a translator can
  reorder currency and number.
- The plate sizes to its content, so a longer translation widens the menu rather than clipping —
  which makes the placement flip (rule 2) load-bearing in verbose languages, not decorative.
- The lock glyph is a glyph, not a letter, and needs no translation.

---

## GDD Alignment

| GDD requirement | How this spec serves it |
|---|---|
| CR-1 universal interaction loop | The menu is the loop's second step; every verb routes into a preview |
| CR-3 selection opens the menu for owned entities only | Entry table, row 1 and row 3 |
| CR-4 legal+affordable verbs, disabled-with-reason otherwise | Rendered from `menu_model()` verbatim; disabled rows always visible |
| CR-5 Build is player-level | Build never appears in the menu; the HUD button keeps it |
| CR-6 single-click commit, illegal clicks inert | Only enabled rows are focusable/clickable |
| CR-8 / D-2 binding-pool reason | Submenu rows name Credits or AP, never "unaffordable" |
| AC-25 move→attack fluidity | Menu re-opens re-filtered after every commit |
| `MENU_KEYBOARD_NAV` | Full keyboard/gamepad traversal is the shipping default, not a fallback |

---

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | Selecting an owned entity with ≥1 legal action opens the menu; every enabled row's verb satisfies its `menu_model()` predicate | Integration |
| AC-2 | Selecting an owned entity with **no** legal action still opens the menu, with Wait enabled and every other verb disabled-with-reason | Integration |
| AC-3 | Selecting an enemy, neutral or empty tile does not open the menu | Integration |
| AC-4 | A disabled row renders its reason text; a row disabled for two reasons renders both | Logic |
| AC-5 | A disabled row is not focusable and does not respond to click | Integration |
| AC-6 | The menu's default position leaves ≥1 tile-width of clearance from the entity's anchor | Logic |
| AC-7 | When the default position would overflow the viewport, the menu flips to the opposite side and remains fully on-screen | Logic |
| AC-8 | The menu is clamped vertically but never horizontally, at any board edge | Logic |
| AC-9 | Every enabled verb is reachable by ↑/↓ + Enter with no mouse | Integration |
| AC-10 | Back-out from the submenu returns to the parent menu; back-out from the menu deselects; back-out from a preview re-opens the menu | Integration |
| AC-11 | Esc with nothing selected opens the pause overlay; Esc with a selection backs out instead | Integration |
| AC-12 | After a commit the menu re-opens on the same entity, re-filtered — or closes if that entity died | Integration |
| AC-13 | Produce submenu lists every producible type with its dual cost; an unaffordable type is disabled naming the binding pool | Logic |
| AC-14 | Wait closes the menu and deselects, spending no AP and no Credits | Integration |
| AC-15 | Shortcut hints render the player's current binding, not a hardcoded default | Integration |
| AC-16 | `reduced_motion` makes every open/close/dim transition instant | Integration |
| AC-17 | The on-screen control legend no longer names the retired cycle bindings | UI |

---

## Open Questions

**OQ-1 — Wait has no simulation meaning.** The GDD says Wait "ends this entity's involvement";
nothing in `GameState` records that. Until an entity carries a per-turn *done* flag, Wait is a
deselect and the entity keeps appearing in cursor-cycle. Either the data model gains the flag or the
GDD's wording should be softened to "dismisses the menu". **Design call, not implementation.**

**OQ-2 — Should the menu show a verb's cost before its preview?** CR-1 puts cost discovery in the
*preview* (hover a tile, see the cost). Move's cost is per-tile so it genuinely cannot be shown on
the row; Attack's is a single number and could be. This spec shows costs only in the Produce
submenu, where the number is fixed and is the deciding factor. Attack's row is left bare for
consistency. Worth a playtest.

**OQ-6 — Cancel Build skips its timed hold when reached from the menu.** Story 004 gave Cancel
Build a bounded press-and-hold, because a bare keypress could otherwise destroy a structure by
accident. Reaching the menu row already costs a deliberate two-step — select the structure, then
activate a row that says "Cancel Build" — so the row commits immediately. The hold remains intact
for any direct-input path. If playtesting shows the row is still too easy to hit, the fix is a
confirm step on the row, not a hold on a mouse click.

**OQ-3 — Does the menu need a Disband row?** `DisbandAction` exists and is reachable from nothing.
Out of scope here; named so it is not lost.

**OQ-5 — "no route" is shown where "needs AP" is the truth.** `Movement.reachable()` is itself
AP-bounded, so a unit with 0 AP gets an *empty* reachable set and `CommandFSM._move_entry` reports
`OUT_OF_RANGE` ("no route"). Its `INSUFFICIENT_AP` branch only fires when the set is non-empty but
every tile is too dear — which zero AP can never produce. The player is told *something* true (there
is indeed no tile they can move to) but not the *useful* thing (they are out of AP and should end
the turn). Fixing it means either an AP-unbounded `reachable()` variant for the menu or a check in
`_move_entry` ahead of the query. **Model-level, not a rendering fix** — named here because this is
the surface where it shows.

**OQ-4 — Pad accelerators may be redundant.** With a fully navigable menu, X/Y/LB/RB duplicate what
A-on-a-row already does. Kept for parity with the keyboard, but a controller playtest may show they
are clutter worth reclaiming for camera control.
