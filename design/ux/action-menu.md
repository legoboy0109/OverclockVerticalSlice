# UX Spec: Contextual Action Menu

> **Status**: Reviewed — **revised 2026-08-24** after `/ux-review`. All **6 blocking** issues
> resolved (pattern-library conformance, Cancel Build's confirmation gate, registered animation
> timings, the AP/Credit projected-cost echo, the phantom lock glyph, missing
> performance/resolution criteria) and all **8 advisory** issues resolved (measured contrast, the
> refused-commit state, the states-that-do-not-exist note, null/trigger columns on Data
> Requirements, localisation budgets, tester-evaluable acceptance criteria, the `hud.md`
> reconciliation, and decision 1's overclaim). **OQ-5, the one model-level defect the review
> surfaced, is also fixed** — Move no longer reports "no route" to a unit that has merely run out
> of AP.
> ⚠ The review was a **self-audit by the spec's own author** — an independent pass would carry more
> weight, and the four spec-accuracy findings are the kind an author reliably misses.
>
> ### ⛔ REVISED 2026-08-26 from a play session — two behaviour changes
> **1. Structurally inapplicable verbs are now HIDDEN, not dimmed.** A verb that can never apply
> to the selected *kind* of thing — Produce on a non-producer, Cancel Build on a finished
> structure, Disband on a structure — is dropped from the menu. Reported in play: every ordinary
> unit carried a permanent *"Produce — not a producer"* row.
> ★ **The line is structural vs situational, and that line is the design.** A situational block
> (*needs AP*, *no targets*, *already attacked*) keeps its dimmed, reasoned row **because that row
> is what teaches the rule** — a player who never sees "needs AP" never learns that attacking
> costs AP. ⚠ This narrows `command-action-interface.md` **CR-4** ("legal+affordable verbs,
> disabled-with-reason otherwise"), which did not distinguish the two cases; CR-4's intent is
> preserved for every reason a player can actually clear.
>
> **2. Rows no longer print per-verb shortcut keys.** A row is activated by focusing it and
> pressing select, so a key printed beside it was a second instruction for the same outcome — the
> same "two sources of truth for one choice" reasoning that retired the type-cycle bindings in
> S6-30. ★ **The bindings themselves are kept**: still live, still rebindable in Settings, still
> the fast path for a player who has learned them. Only the advertising is gone.
>
> **Re-reviewed 2026-08-25 (S7-07)** — `production/qa/ux-review-action-menu-2026-08-25.md`.
> Verdict was **NEEDS REVISION** on 2 blocking issues, **both now fixed here**: the stale Platform
> Target line and AC-22's resolution set, which tested only sizes *larger* than the shipping floor.
> ★ **Neither was an authoring defect** — the platform moved under a spec written before it (S7-08),
> and the acceptance criteria had not caught up. ✅ Every behavioural claim in this document was
> re-verified against the shipped code and all passed, including the two that were genuine defects
> at the first review (`open_ap_preview` now has a production caller; `commit_rejected` is
> connected). ⚠ **Independence was still not achieved** — that pass was also by this author.
> **Author**: main session, from `design/gdd/command-action-interface.md` + four user decisions (2026-08-24)
> **Last Updated**: 2026-08-25
> **Journey Phase(s)**: Core in-match loop — every AP-costed action passes through this surface
> **Platform Target**: PC (Steam / Epic) **+ Steam Deck**. Keyboard/Mouse primary on desktop;
> **gamepad is REQUIRED, not secondary**. Hardware floor **1280×800**; quality target 1080p/1440p.
> ⚠ **Updated 2026-08-25 (S7-07).** This line previously read *"Gamepad secondary (partial)"*,
> which was true when written and was overtaken by S7-08's Steam Deck decision. The spec's
> *content* never assumed otherwise — the Interaction Map has always given the gamepad full parity
> (D-pad, A, B, X/Y, LB/RB, L3, Back) — but this is the line a reader trusts to judge how much
> gamepad work is optional, and it said the wrong thing for a day.
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

**Cross-document note.** `hud.md` Zone B is the HUD's fixed control corner, and this picker anchors
there without being HUD chrome: it is a transient popover belonging to the Build control that opens
it, gone the moment a type is chosen or the player backs out. `hud.md` has been updated to record
both this and the fact that the CAI's *verb* menu legitimately draws over the board interior — its
"board interior stays clear" rule is about HUD-owned chrome, and Zone D's "one on-board, one
off-board" phrasing was about the detail panel specifically, not a blanket rule.

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

| Component | Purpose | Pattern |
|---|---|---|
| Menu plate | `HudPanel` palette (`BACKING` / `BORDER`) so it reads as the same HUD, not as OS chrome | — (chrome, not interaction) |
| Verb row | Label + right-hand column: the verb's AP price where it has a single one, then its shortcut or its disablement reason | **Standard Button** |
| Disabled verb row | Same row, dimmed label + reason text; visible, never hidden, never recoloured | **Affordability Dimming** |
| Destructive rows (Cancel Build, Disband) | Show the payout up front; arm on first activation, commit on second, relabel while armed | **Hold-to-Confirm Refund** (toggle variant — see decision 5) |
| Submenu plate | Second plate, same palette, listing produce/build options with dual costs | **Standard Button** + **Affordability Dimming** |
| Focus indicator | Engine-native focus ring, a distinct `StyleBox` from hover | **Three-State Focus Indicator** |
| Back-out | Right-click / ESC / pad B, one level per press | **Standard Cancel** |

### Pattern library conformance

This surface **invents no new interaction patterns**. Every component above composes existing
entries in `design/ux/interaction-patterns.md`, which is where their behaviour is specified — this
spec states only what is *particular to the action menu* and does not restate them.

Three consequences worth being explicit about, because each is a place this spec could have drifted:

- **`Standard Button` says inert controls must not be dropped from keyboard traversal
  "silently"** — it defers the skip-or-not choice to the consuming pattern. This spec makes that
  choice explicitly: **disabled rows are visible but not focusable** (AC-5). Traversal stops only
  where something can happen; the reason is rendered inline so it is readable without focusing it.
- **`Affordability Dimming` forbids a hue-based unavailability signal.** Disabled rows are dimmed
  and carry words. Nothing is recoloured red, and there is no lock glyph — see the Accessibility
  note on why.
- **`Snap, Never Tween` is not violated by the menu's fade.** That pattern governs *numeric and
  discrete-state displays* (a value that changed must jump, not count). A panel appearing is not a
  value changing, and `command-action-interface.md` independently specifies the 150ms fade.

All four of this surface's durations are registered in the pattern library's **Animation Standards**
table rather than living only here.

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
| **Row disabled** | Dimmed label + reason text; visible, **not focusable** (*Affordability Dimming*) |
| **Submenu open** | Parent plate dims to 55%; submenu takes focus |
| **Preview active** | Menu hidden entirely — the board is the surface now, and the menu would compete with the overlay it just opened |
| **Input locked** (post-commit debounce, `input_lock_ms`) | Menu visible, rows inert; no visual change — the window is 120ms and a flicker would read as a fault |
| **Opponent's turn / game over** | Closed |

| **Stood down** | The Wait row's right column reads "stood down"; on the board the entity stops breathing and the idle cursor ring skips it. Every other row is unchanged — the mark forbids nothing |
| **Commit refused** | The status line reads `Refused: <reason>` and the menu re-opens re-filtered, so the verb that failed is now visibly greyed out with the same wording |

**Every row is visible in every variant.** A verb is never hidden for being unavailable — that is
the whole point of CR-4, and it is what lets a player learn the rules from the interface.

**Three states this surface does not have, and why** — stated because their absence is a design
fact, not an oversight:

- **No loading state.** Every value the menu renders comes from a synchronous, side-effect-free
  query against in-memory game state. There is no fetch, so there is no waiting. AC-23 pins this:
  the menu is built and on screen within one frame of the selection.
- **No empty state.** `menu_model()` always returns Wait, and Wait is always enabled (CR-4:
  "Wait — always"), so the plate can never render with nothing on it. The nearest thing is an
  entity with no legal action, which is AC-2's case: Wait live, everything else disabled with a
  reason.
- **No error state for the MODEL.** The queries behind the menu are total — they return a disabled
  verb with a reason rather than failing. The only failure that can reach the player is a
  **refused commit**, which is a distinct thing and has its own row in the table above.

---

## Interaction Map

| Input | Mouse | Keyboard | Gamepad |
|---|---|---|---|
| Select entity | Left-click it | Move cursor + Enter | D-pad + A |
| Focus a verb | Hover | ↑ / ↓ | D-pad ↑ / ↓ |
| Choose focused verb | Left-click | Enter | A |
| Verb accelerator (skip the menu) | — | M / A / P / B | X / Y / RB / LB |
| ⚠ *(accelerators are **not printed on the rows**, 2026-08-26 — they remain bound and rebindable)* | | | |
| Open submenu | Click `Produce ▸` | Enter or → on the row | A or → |
| Back out one level | Right-click | Esc | B |
| Commit inside a preview | Left-click a highlighted tile | Enter on the cursor tile | A |
| Jump cursor between salient tiles | — | `[` | L3 |
| End turn | Click the HUD control | Tab | Back |

### Four decisions this spec makes, because the GDD did not

**1 — Esc opens pause only when there is nothing to back out of.**
*Only the pause fallback is new here.* The step-one-level-at-a-time behaviour is already locked by
the **Standard Cancel** pattern ("exits exactly one level — a live preview backs out to the
contextual menu; the menu backs out to no-selection… it never skips levels"), and this spec follows
it unchanged.

What no document resolved is the key collision: the GDD's input table binds back-out to
right-click **or ESC**, and `pause.md` later bound pause to ESC. Both are right about their own
surface. Resolution: back-out is attempted first and *reports whether it consumed the press*; pause
opens only when it did not. That makes the destructive reading — pausing when the player meant to
cancel — impossible, and it needs no new binding.

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

**5 — Cancel Build takes two presses: arm, then confirm.**
`interaction-patterns.md`'s **Hold-to-Confirm Refund** governs this verb by name — destroying an
in-progress build for a partial refund has no undo, and `Standard Cancel`'s own *when NOT to use*
clause points at it. A single-activation menu row is precisely the mis-click that pattern exists to
prevent, so the row does not commit on first press.

The gate is **arm-then-confirm** rather than press-and-hold, and that substitution is the point:
`design/accessibility-requirements.md` carries an open Standard-tier commitment for a toggle
alternative to that hold ("first press arms, second confirms"), because a sustained press is a motor
requirement some players cannot meet. A menu row is the natural home for it — so one mechanism
satisfies the pattern *and* closes the accessibility item, instead of shipping a hold and then
retrofitting an alternative to it.

It stays double-click-proof the same way the hold does: the row **relabels** on the first press, so
a double-click's second press lands on a button that now reads "Confirm cancel". The refund is shown
on the row before either press, per the pattern's "see the cost before you commit" promise. Arrowing
away, backing out, or picking any other verb all disarm it.

**4 — Wait marks the entity stood down for the turn.** *(Revised 2026-08-25 — it originally
deselected and nothing more, because the simulation had nowhere to record the mark. See OQ-1.)*
`WaitAction` sets a per-turn flag that the interface reads and the rules ignore: the entity dims,
drops out of the idle cursor ring, and stops counting toward the End-Turn notice, while remaining
fully commandable. Acting with it clears the mark, because the player has visibly changed their
mind.

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

Nothing here is fetched, polled or cached: every row is a synchronous query against in-memory game
state, read at the moment the menu is built or refreshed. That is why there is no loading state and
why "update frequency" is a *trigger*, not an interval.

| Needs | Source | Updated on | If unavailable |
|---|---|---|---|
| Which verbs, enabled, and why not | `CommandFSM.menu_model(state, entity)` | Menu open, and every re-open after a commit | Cannot be — the query is total; an entity with no legal action returns all-disabled + Wait |
| Which unit types, their dual costs, affordability | `CommandFSM.produce_options(state, entity)` | Submenu open | Returns an **empty array** for a non-producer or an unfinished one; the submenu is never opened off a disabled row, so the empty case is unreachable rather than rendered |
| Which structures, their dual costs, placeability | `CommandFSM.build_options(state, player, types)` | Build picker open | Empty roster → the picker does not open at all (the HUD Build control is inert) |
| Projected AP after the previewed action | `CommandFSM.projected_remaining_ap(state, player, cost)` | Preview entered; **and every cursor step**, since a move's price is per-tile | Cursor off the legal set → the echo **closes**, rather than showing a stale or zero projection |
| Projected Credits after an economic action | `Credits.current_credits` − the action's Credit cost | Preview entered (Build/Produce only) | Non-economic verb → echo closed, not shown unchanged |
| The refund a Cancel Build would return | `CommandFSM.cancel_build_preview(state, structure)` | Menu open | Not an under-construction structure → the row is dropped, so no refund is owed a value |
| The entity's screen anchor | `BoardRenderer.grid_to_screen` via the camera transform | Menu open, camera move, window resize | No board (menu context) → the menu is not opened |
| Shortcut glyph per verb | `InputMap` / `GameSettings` bindings | Read fresh on every menu open | Action unbound → **empty string**, and the row simply shows no hint (never a stale default letter) |
| Verb labels, reason phrases, rejection phrases | `ActionMenu`'s own constant tables | Static | — |

**On that last row**: the widget owning this is *copy*, not game state, and the distinction is the
whole of the "UI must never own game state" rule. It holds no number, no legality and no cost — it
holds the words used to say them, which is exactly what a presentation layer is for. Every value
those words describe is queried, never stored here.

---

## Accessibility

- **Every verb is click-reachable and keyboard-reachable** (technical-preferences: no hover-only
  interactions). The menu is the click-reachable path the accelerators never were.
- **Three distinct attention states**, per the GDD's input notes: mouse-hover, board cursor, and
  menu keyboard-focus. This surface owns the third, and it is the genuine Godot 4.6 dual-focus case —
  mouse focus and keyboard focus are separate subsystems and can both be live, so the focused row's
  indicator must be visually distinct from the hovered row's.
  ✅ **VERIFIED on Redot 26.2, 2026-08-26 (S8-09)** — no longer assumed. GDD OQ-6 is closed.
  Measured on a real framebuffer: a focused row keeps `has_focus()` while a different row is
  hovered, that row reports `DRAW_HOVER`, and hover never steals focus. The cues are different
  *marks*, not different brightnesses — **focus draws a 2px outline (moves 17.9% of the row's
  pixels); hover draws no box at all (2.9%, the glyphs only)**. That distinction is what makes them
  tellable apart, and it is deliberately not carried by brightness, because `font_focus_color` and
  `font_hover_color` are set to the same white. Report:
  `production/playtests/s8-09-dual-focus-2026-08-26.md`.
  ⚠ **The focus outline is drawn OUTSIDE the row's own rect** (expand margins on the theme's focus
  StyleBox): a row at y 521..548 draws its border at y 519-520 and y 549-550. Rows are spaced far
  enough apart that it does not collide today — but anything that tightens row spacing, or clips
  rows to their own rect, will eat the keyboard cue.
  ⛔ **OQ-7 (new, open): hover is close to invisible on its own.** It lifts the label from
  `LABEL_ENABLED` `(0.90, 0.94, 1.00)` to white — a ~3% change on already-near-white text — because
  `flat = true` suppresses the theme's hover StyleBox and leaves font colour as hover's only
  channel. This spec promises three *distinct* attention states; two of them are strong and the
  third is barely a state. The binding claim above still passes. Whether hover needs a visible mark
  of its own is a **design call, deliberately not taken by the agent that measured it.**
- **Disabled rows are visible but not focusable.** Focus stops only on rows that do something —
  the same treatment the Settings screen's reset buttons use. The reason text is rendered inline on
  the row, so it is readable without focusing it.
- **Colour is never the only signal.** A disabled row carries dimming *and words* — the reason is
  spelled out in text on the row. Affordability in the submenu is text, not a red tint.
  ⚠ **No lock glyph, deliberately.** An earlier draft of this spec (and
  `command-action-interface.md`'s Visual/Audio item 8) called for a padlock beside disabled rows.
  The engine's fallback font has no glyph for one and renders it as a "tofu" box, so the
  implementation does not draw it and this spec no longer claims it. The non-hue requirement is
  still met without it: dimming and text are both independent of colour. If a padlock is wanted, it
  needs a font that has one — an art/font decision, not a UI one.
- **Shortcut hints render the live binding**, so a player who has remapped Move sees their key.
- **UI scale** (`GameSettings.ui_scale`) applies — the menu is a `Control` under the same scale
  factor as the rest of the HUD.
- **Text contrast**, measured rather than asserted. The plate is 88% opaque, so whatever sits
  behind it bleeds through; the numbers that matter are the worst case, which is the tan over-cap
  move overlay, not the board's dark ground.

  | Element | On the board's dark ground | On the tan over-cap overlay (worst case) |
  |---|---|---|
  | Enabled label | 16.2:1 | 14.9:1 |
  | Focused label | 18.7:1 | 17.2:1 |
  | **Disabled label** | 5.3:1 | **4.9:1** |
  | Shortcut hint | 6.4:1 | 5.9:1 |
  | Reason text | 6.0:1 | 5.5:1 |

  All clear the 4.5:1 WCAG AA floor for body text at this size. ⚠ The disabled label was
  `Color(0.46, 0.50, 0.56)` until 2026-08-24, which measured **4.27:1** against that worst case —
  passing over the dark board and failing over a bright overlay, i.e. failing exactly when a move
  preview was open behind the menu. Retune against the worst case, never the comfortable one.

---

## Localization Considerations

- Verb labels, reason phrases and the cost format are whole strings, never assembled from
  fragments; the cost line is a single format string with positional arguments so a translator can
  reorder currency and number.
- **Character budgets.** These are design targets for translators, not hard truncation limits —
  the plate sizes to its content, so overrunning them widens the menu rather than clipping text.
  Each already carries the ~40% expansion typical of English→German/Russian.

  | Element | English today | Budget | What overrunning costs |
  |---|---|---|---|
  | Verb label | "Cancel Build" (12) | **18** | Widens the plate; at ~28 it starts covering tiles the flip cannot save it from |
  | Reason phrase | "already attacked" (16) | **22** | Widens the plate; multi-reason rows concatenate, so this is the one to watch |
  | Multi-reason row (2 joined) | "no targets, needs AP" (20) | **46** | Two budgeted phrases plus ", " |
  | Priced verb column (worst case) | "2 AP · no targets, needs AP" (27) | **54** | A price, a middle dot, then the multi-reason budget above. The widest right-hand column the verb menu can produce |
  | Unit / structure name | "Defensive Structure" (19) | **24** | Widens the picker only |
  | Cost line | "600 CR + 2 AP" (13) | **20** | Currency abbreviations are themselves translatable |
  | Armed-confirm label | "Confirm cancel" (14), "Confirm disband" (15) | **20** | Must stay visibly different from its resting label ("Cancel Build", "Disband"), or the arm state reads as no change |

  ⚠ **The last row is a correctness constraint, not a layout one.** The arm-then-confirm gate
  (decision 5) works because the row visibly changes; a translation whose confirm label reads
  near-identically to its resting label would silently weaken a destructive-action safeguard.
  Flag it for the translator explicitly.
- The plate sizes to its content, so a longer translation widens the menu rather than clipping —
  which makes the placement flip (rule 2) load-bearing in verbose languages, not decorative.
- The submenu affordance (`>`) and the disabled marker are ASCII, not letters, and need no
  translation. There is no lock glyph to translate — see Accessibility.

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
| `command-action-interface.md` AC-25 — move→attack fluidity | Menu re-opens re-filtered after every commit |
| `MENU_KEYBOARD_NAV` | Full keyboard/gamepad traversal is the shipping default, not a fallback |
| D-1 `projected_remaining_ap` inline on the HUD's AP counter, live on hover | Opened when a preview is entered and refreshed per cursor tile for Move (AC-21). ⚠ **Was unaddressed until 2026-08-24** — `GameHud.open_ap_preview()` had no production caller at all, so this "resolved" seam had never once run |
| D-1b `projected_remaining_credits` shown **alongside** it for economic actions | Both echoes open together for Build and Produce, each reporting its own pool's affordability (AC-21) |
| CR-6a Cancel Build's distinct destructive gesture | Arm-then-confirm on the row (decision 5), composing *Hold-to-Confirm Refund* |

---

## Acceptance Criteria

Written to be checkable by a tester who has not read this document or the code. Where a criterion
depends on game rules, the *set-up* is stated so the expected result follows from what is on screen.

| # | Criterion | Type |
|---|---|---|
| AC-1 | Select a unit that has AP and open ground around it. The menu opens with a row for Move, Attack and Wait; Move and Wait are bright and respond to Enter, and nothing on the row set is hidden | Integration |
| AC-2 | Select a unit that has already moved and attacked this turn. The menu still opens; Wait is the only bright row and every other row is dimmed with a short phrase beside it saying why | Integration |
| AC-3 | Click an enemy unit, then empty ground. No menu appears in either case; the SELECTED panel still shows what was clicked | Integration |
| AC-4 | Select a unit with no enemy in range and zero AP. The Attack row names **both** problems, not just the first | Logic |
| AC-28 | With nothing blocked, select any of your units: there is **no** Disband row. Now go into deficit — or fill your population to the cap — and select again: the row appears in either case, stating both what it costs and what it returns. Activate it once: the unit survives and the row reads "Confirm disband". Activate again: the unit is gone and the Credits arrive | Integration |
| AC-29 | Select a structure while in deficit. There is still no Disband row — structures are never disbandable | Integration |
| AC-30 | Arm Disband, then press Esc. The row reads "Disband" again, the unit is alive, and nothing was deselected | Integration |
| AC-27 | Select a unit with an enemy adjacent and AP to spare. The Attack row states what attacking costs, alongside its shortcut, before any preview is opened. Drain the AP and re-select: the row still states the cost, now beside the reason | Integration |
| AC-5 | With the menu open, press ↓ repeatedly. Focus visits only bright rows and never lands on a dimmed one. Clicking a dimmed row does nothing | Integration |
| AC-6 | The menu never touches the sprite it belongs to: there is at least one tile of clear board between the entity and the menu's near edge | Logic |
| AC-7 | Select a unit against the right edge of the board. The menu opens on its **left** instead, fully on screen | Logic |
| AC-8 | Select a unit at the very top and then the very bottom of the board. The menu slides up/down to stay on screen but never moves sideways onto the entity | Logic |
| AC-9 | Complete a full move using only the keyboard: cursor to the unit, Enter, ↓/↑ to Move, Enter, cursor to a highlighted tile, Enter. No mouse at any point | Integration |
| AC-10 | Open Produce, then press Esc three times. First closes the type list and leaves the verb menu up; second closes the menu and deselects; third opens the pause overlay | Integration |
| AC-11 | With nothing selected, Esc opens pause. With a unit selected, the same key backs out instead and pause does **not** appear | Integration |
| AC-12 | Move a unit that still has AP left. The menu re-opens on that same unit with Attack now evaluated afresh. Move a unit into a counterattack that kills it: the menu closes and nothing is left selected | Integration |
| AC-13 | Select a producer while holding enough Credits for the cheapest unit but not the dearest. The list shows both, the cheap one bright, the dear one dimmed and saying it needs Credits — not a generic "unavailable" | Logic |
| AC-14 | Note your AP and Credits, press Wait. Both are unchanged and nothing is selected | Integration |
| AC-25 | After Wait, the unit stops glowing on the board, the ACTIONS panel's idle count drops by one, and pressing the jump-cursor key no longer stops on it. Re-select it: every verb it had is still available, and using one makes it glow and count again | Integration |
| AC-26 | Stand a unit down, then end the turn and come back. It is glowing and counted again — a stand-down lasts exactly one turn | Integration |
| AC-15 | Rebind Move to a different key in Settings, then use it on the board: the rebound key still triggers Move. ⚠ **Revised 2026-08-26** — previously *"the Move row shows the new key"*. Rows no longer print per-verb shortcuts at all (see the playtest revision note); the **binding stays live and rebindable**, it is simply not advertised on the row | Integration |
| AC-32 | Select an ordinary unit. There is **no Produce row at all** — not a dimmed one. Select a producer: the row is there. Now drain a unit's AP and select it: Attack is still **present and dimmed, with a reason** | Integration |
| AC-16 | Turn on Reduced Motion. The menu, submenu and picker appear and disappear instantly, with no fade | Integration |
| AC-17 | Nothing on screen mentions `[C]` or `[V]`, and pressing either key does nothing | UI |
| AC-18 | Select a structure you are still building and activate Cancel Build **once**. The structure is still there and the row now reads "Confirm cancel". Activate again: it is destroyed and the refund is credited | Integration |
| AC-19 | Arm Cancel Build, then press Esc. The row goes back to reading "Cancel Build", the menu stays open, the structure survives, and nothing is deselected | Integration |
| AC-20 | The Cancel Build row states how much AP comes back **before** it is pressed at all | Integration |
| AC-21 | Enter a Move preview: the AP counter reads `current → projected`, and the projected figure changes as the cursor moves between tiles of different cost. Open a Build preview: the Credits counter shows its own `current → projected` alongside it. Leave either preview by any route — commit, Esc, right-click — and both counters go back to a single number | Integration |
| AC-22 | Repeat AC-1, AC-13 and the Build picker at **1280×800, 1920×1080 and 2560×1440**. Nothing is clipped, nothing overlaps a HUD panel, and no row is cut off | UI |
| AC-31 | **At 1280×800 specifically** — the hardware floor, where there is least room — re-run AC-6, AC-7 and AC-8: the one-tile clearance still holds, a unit against the right edge still flips the menu to its left with the whole plate on screen, and a unit at the top and bottom edges still clamps vertically **without** sliding sideways over the entity | UI |
| AC-23 | The menu is on screen in the same frame as the selection that opened it; its fade changes opacity only and a row can be clicked before the fade finishes | Integration |
| AC-24 | Force a commit to be refused (e.g. act on the opponent's turn). The status line says `Refused:` followed by a plain-language reason — never silence | Integration |

## Open Questions

**~~OQ-1~~ — RESOLVED 2026-08-25.** Wait now commits a [`WaitAction`] that sets a per-turn
**stand-down mark** on the entity, cleared at the owner's next turn start and cleared again the
moment the entity acts.

The mark is **advisory, never binding** (user decision): it changes what the interface offers, not
what the rules allow. A stood-down entity stops breathing on the board, is skipped by the
idle-entity cursor cycle, stops counting toward the End-Turn idle notice, and says "stood down" on
its own Wait row — but every verb it had is still legal and still commits. A hard lockout was the
alternative and was rejected: Wait is a single unconfirmed menu row, and locking an entity out of
its turn from one click is the same trap decision 5's confirmation gate exists to prevent.

The `waited` signal being kept separate from `dismissed` — which looked redundant when both did the
same thing — is what made this a one-line rewire rather than an untangling.

**~~OQ-2~~ — RESOLVED 2026-08-25 for Attack; unchanged for the rest.** The Attack row now names its
AP price, both when live (`2 AP · [A]`) and when greyed out (`2 AP · needs AP`) — on a disabled row
the price is the more useful half, because "needs AP" alone says you are short and the figure says
by how much.

**Only Attack.** Move's price is per-TILE and is not knowable until the player is looking at a
destination; Produce's is per-TYPE and belongs on the submenu rows that already carry it; Wait is
free and Cancel Build pays out. `VerbEntry.ap_cost` reports `NO_SINGLE_COST` for all of them rather
than a zero, so no row can ever claim a price the verb does not have. CR-1 still puts *per-target*
cost discovery in the preview — this adds the one figure that is fixed before the preview opens,
it does not move cost discovery out of it.

**~~OQ-6~~ — RESOLVED 2026-08-24 by `/ux-review`.** The first draft let the menu's Cancel Build row
commit on one press, arguing that select-then-pick was gate enough. The review found that this
contradicts **Hold-to-Confirm Refund** outright and, worse, quietly dropped a committed Standard-tier
accessibility item. It is now arm-then-confirm — see decision 5. *Kept visible rather than deleted:
"the two-step selection is already a confirmation" is a tempting argument and it was wrong, which is
worth remembering.*

**~~OQ-3~~ — RESOLVED 2026-08-25.** Disband has a row, and it appears **only when disbanding would
unblock something**: the player is in a Credit deficit, or at/over their population cap.

Those are the two states the verb exists to relieve. `unit-upkeep.md` UR-7 makes it the escape valve
the whole deficit lock depends on; `population-cap.md` makes it the only *voluntary* way back under
a ceiling that otherwise waits on attrition. Before this the action was reachable from nothing at
all. Outside those two states the row would be a permanently visible, irreversible entry on every
unit the player owns, for something most players use rarely.

**"At cap" is `>=`, not `==`.** The cap *falls* when a Barracks dies (PC-6) and units above the new
ceiling are deliberately not destroyed — so a player can sit strictly over cap, production-locked,
which is exactly when a voluntary way back under matters most.

When shown it states both halves of its trade up front (`1 AP · +100 CR back`) — the only verb that
spends *and* pays out, so one figure alone would not let a player weigh it against holding the unit.
It takes **two presses** like every destructive verb, and structures never get it at all (UR-7),
dropped rather than greyed on the same rule that drops Cancel Build from a scout.

**The blocked state is what SHOWS the verb and never what blocks it.** An offered Disband is gated
on AP alone — never on the deficit lock that stops produce/build/research — because disband is the
one action that *reduces* upkeep, and refusing it mid-deficit would make a deficit unrecoverable by
the player's own choice.

> ### ⚠ What this still costs, recorded rather than argued away
>
> **It is a deliberate exception to this spec's own rule.** Everywhere else a verb disabled by the
> *situation* keeps a visible row with its reason, because that is what teaches the rules; only
> verbs that do not apply to an entity's *kind* are dropped. `NOTHING_BLOCKED` is situational and is
> dropped anyway. The consequence is **discoverability**: a player with nothing blocked is never
> shown that Disband exists, and first meets it in a turn where something has already gone wrong.
> Mitigated but not removed by the second trigger — a population ceiling is a far more ordinary
> situation than insolvency, so most players will now meet the verb sooner and under less pressure.
>
> **The rules did not change.** `Upkeep.validate_disband` still accepts a disband from a player with
> nothing blocked — this hides an affordance, it does not forbid an action, and a test pins that
> distinction so a UI-level gate can never harden into a rule.

**~~OQ-5~~ — RESOLVED 2026-08-24.** The menu said "no route" to a unit standing in open ground
that had simply run out of AP. `Movement.reachable()` applies its affordability cut *inside* the
BFS, so "walled in" and "broke" both came back as an empty set — and `_move_entry`'s
`INSUFFICIENT_AP` branch was unreachable, because it re-tested affordability on tiles the query had
already filtered for it. The reason existed in the enum and could never be produced.

Fixed with `Movement.reachable_ignoring_ap()`, asked **only** when the budgeted query comes back
empty — the cold path, so a unit that can move pays nothing for it. Empty there too means genuinely
boxed in (`OUT_OF_RANGE`, no amount of AP helps); non-empty means the tiles exist but are not yet
payable (`INSUFFICIENT_AP`). The two are mutually exclusive and each names the fix that would
actually work: clear a path, versus end the turn. *This mattered more than a wording nit — the two
messages send the player to opposite places.*

**OQ-4 — Pad accelerators may be redundant.** With a fully navigable menu, X/Y/LB/RB duplicate what
A-on-a-row already does. Kept for parity with the keyboard, but a controller playtest may show they
are clutter worth reclaiming for camera control.
