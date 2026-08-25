# UX Spec: Settings Screen

> **Status**: Reviewed — **APPROVED** (`/ux-review` 2026-08-24, re-run after 4 blocking issues
> fixed; 0 blocking remaining). **Revised 2026-08-24 (S6-28)** to add per-binding reset, closing
> OQ-2 — affected sections re-checked against the review checklist, no new findings.
> ⚠ Written **retroactively** — see the banner below, which is not superseded by the approval.
> **Author**: main session, from standing commitments
> **Last Updated**: 2026-08-24
> **Journey Phase(s)**: Pre-play configuration (from the main menu) and in-match interrupt (from
> pause)
> **Platform Target**: PC (Steam / Epic) — Keyboard/Mouse primary, Gamepad secondary (partial)
> **Template**: UX Spec
> **Scope**: Vertical Slice. Controls + Display only — audio is out of scope until audio buses exist.

> ### ⚠ This spec is retroactive, and approval does not change that
>
> `main-menu.md` OQ-3 and `pause.md` OQ-4 both deferred this screen to "a separate spec". That spec
> was never authored, and on 2026-08-24 the screen was **implemented without one** — its contents
> taken from `design/accessibility-requirements.md`'s Standard-tier commitments rather than from a
> UX document. This file closes that gap after the fact.
>
> The consequence is real: **nothing here was reviewed before it was built.** The layout, the
> wording and the interaction model are all descriptions of a decision already made, not proposals.
> Where a choice looks arbitrary, it probably is — Open Questions flags the ones I would expect a
> reviewer to challenge. Treat this as a record to review, not as a spec that was followed.

---

## Purpose & Player Need

The player wants to **make the game controllable by them specifically** — remap an input they cannot
reach, scale text they cannot read, or stop motion they find uncomfortable. Every one of these is a
precondition for playing at all for the player who needs it, which is why they sit behind a
committed accessibility tier rather than in a "nice to have" pile.

This screen is also the only surface in the game where a **binding is visible**. That turned out to
matter immediately: rendering the bindings table on day one exposed End Turn bound to a keycode that
named no key — the action had never worked from the keyboard, and no test had noticed because they
asserted the on-screen legend rather than the binding behind it.

---

## Player Context on Arrival

Two arrivals, with different emotional states and the same screen:

| From | Player is | Wants |
|---|---|---|
| **Main menu** | Calm, pre-play, configuring deliberately | To set things up before starting |
| **Pause overlay** | Mid-match, interrupted, often frustrated | To fix one specific thing and get back |

The second is the demanding case: a player who paused *because* a control is wrong wants to change
it and return to the exact match they left. Nothing here may cost them that match.

---

## Navigation Position

A leaf screen with **two parents**. `root → Main Menu → Settings` and
`root → Match → Pause → Settings`. It is never a boot destination and never reached from anywhere
else.

Because it has two parents, **it does not own its own exit.** The caller supplies the return
destination; the screen only reports that the player is done. A screen with two parents that
guesses where "back" goes will send half of its visitors to the wrong place.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Main menu | "Settings" | Nothing — no match exists |
| Pause overlay | "Settings" | A frozen match, which must survive untouched |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Whichever screen opened it | "Back" · Esc | Focus returns to the **Settings entry** on that screen, not to the top of its list |

Changes are **applied and saved immediately**, not on exit — see Interaction Map for why.

---

## Layout Specification

### Information Hierarchy

1. **Controls** — the largest group and the committed tier's headline requirement.
2. **Display** — UI scale and reduced motion.
3. **Reset to Defaults** / **Back**.
4. Section headings and the conflict/hint line (orientation, not content).

### Layout Zones

A single scrolling column, centred. The controls table is the tall element and everything else
follows it, so a vertical scroll is the honest shape rather than tabs or columns for what is
currently ~12 rows.

| Zone | Location | Hosts |
|------|----------|-------|
| Heading | top | "SETTINGS" |
| Controls table | upper | one row per rebindable action; KEYBOARD and GAMEPAD columns |
| Hint / conflict line | below the table | prompts while rebinding; warns on conflict |
| Display group | lower | UI Scale, Reduced Motion |
| Footer | bottom | Reset to Defaults · Back |

### Component Inventory

| Component | Zone | Type | Content | Interactive | Pattern |
|-----------|------|------|---------|-------------|---------|
| Column headers | Controls | text | "KEYBOARD" / "GAMEPAD" | No | — |
| Action label | Controls | text | e.g. "Move / Attack" | No | — |
| Binding button | Controls | button | current input name, or "—" | Yes | **Standard Button** |
| Per-binding reset (↺) | Controls | button | "↺" | Yes (click only — see Interaction Map) | **Standard Button** (inert state) |
| Hint / conflict line | Controls | text | prompt or ⚠ warning | No | — |
| UI Scale | Display | slider + value | 75–150%, shown as % | Yes | **Value Slider** |
| Reduced Motion | Display | toggle | on/off | Yes | **Setting Toggle** |
| Reset to Defaults | Footer | button | "RESET TO DEFAULTS" | Yes | **Standard Button** |
| Back | Footer | button | "BACK" | Yes | **Standard Button** |

### ASCII Wireframe

```
 ┌───────────────────────────────────────────────────┐
 │  SETTINGS                                         │
 │  CONTROLS                                         │
 │                     KEYBOARD      GAMEPAD         │
 │  Move / Attack      [   M    ]↺  [  Pad 2  ]↺     │
 │  Build              [   B    ]↺  [  Pad 3  ]↺     │
 │  Cycle Build Type   [   C    ]   [  Pad 9  ]      │
 │  Produce            [   P    ]   [  Pad 1  ]      │
 │  Cycle Unit Type    [   V    ]   [ Pad 10  ]      │
 │  End Turn           [  Tab   ]   [  Pad 4  ]      │
 │  Pause              [ Escape ]   [  Pad 6  ]      │
 │  Focus Action Panel [QuoteLeft]  [  Pad 8  ]      │
 │  Jump Cursor        [BracketLeft][  Pad 7  ]      │
 │  ⚠ Also bound to: Pause                           │
 │  Changed bindings are highlighted. Press ↺, or    │
 │  Delete on a focused binding, to reset just that. │
 │                                                   │
 │  DISPLAY                                          │
 │  UI Scale           [───●────────]   100%         │
 │  Reduced Motion     ( ●———)                       │
 │                                                   │
 │      [ RESET TO DEFAULTS ]      [ BACK ]          │
 └───────────────────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| Default | Open | Table shows live bindings; Back focused |
| Listening | A binding button pressed | That button reads "PRESS…"; hint line names which input family is expected |
| Conflict | A bind duplicates another action's | ⚠ line names every other action using that input; **the bind still applies** |
| Reset | "Reset to Defaults" | All overrides cleared; hint line confirms |
| **Changed** | A binding differs from the shipped default | That cell's text takes the accent colour and its ↺ becomes live. Unchanged cells keep default text and an inert ↺ |
| **Save failed** | Any change, when `user://settings.cfg` cannot be written | ⚠ line names the file, the error code, and that the change applies now but will not survive exit. The change is **not** rolled back |

No loading state (settings load at boot). No empty state (the controls table is never empty — the
action list is a constant).

★ **The save-failure state is why this screen has an error state at all.** Persistence *is* the
screen's purpose, so failing at it silently is the worst available failure: the player rebinds a
control, watches the table update, and finds it reverted next launch with nothing having said why.
The change is deliberately not rolled back — it is still correct for this session, and undoing what
the player just asked for would compound one failure with a second surprise.

---

## Interaction Map

| Component | Action | Inputs | Feedback | Outcome |
|-----------|--------|--------|----------|---------|
| Binding button | begin rebind | click · Enter/Space · gamepad A | button reads "PRESS…" | listening |
| (listening) | assign | any key, or any pad button | table updates; ⚠ if it clashes | bound, applied, saved |
| (listening) | cancel | Esc | table restores | nothing changed |
| UI Scale | adjust | drag · arrows when focused | live rescale, % updates | applied, saved |
| Reduced Motion | toggle | click · Enter · gamepad A | toggle state | applied, saved |
| Per-binding reset (↺) | reset one binding | **click** | that cell reverts; hint line names what was reset | one override cleared, saved |
| (focused binding) | reset one binding | **Delete** | same | one override cleared, saved |
| Reset to Defaults | activate | click · Enter · gamepad A | table repopulates | **all** overrides cleared, saved |
| Back | activate | click · Enter · Esc · gamepad A · **gamepad B / Cancel** | screen closes | returns to caller |

Focus order: the controls table top-to-bottom (keyboard column, then gamepad), then UI Scale,
Reduced Motion, Reset, Back. **Back is focused on open** — the most likely action for a player who
opened the screen to look rather than to change something, and a safe landing for a gamepad.

### Three decisions that need stating, because none is obvious

**1. Conflicts are reported, never refused.** Refusing a duplicate outright makes swapping two
bindings impossible: every swap passes through a state where both actions want the same input. The
⚠ line names what else uses it and the player decides.

**2. Changes apply and save immediately — there is no OK/Cancel.** A player rebinding a control they
cannot press needs to *test* it, and an un-applied change cannot be tested. The undo is therefore
**per binding**, not per session: ↺ or Delete restores one cell to its default, leaving every other
customisation intact. Reset to Defaults remains as the all-or-nothing option. The residual cost is
that there is still no *chronological* undo — you can revert any binding to its default, but not to
whatever you had it on two changes ago.

**2a. The reset affordance has two input paths, and needs both.** `technical-preferences.md` requires
every action be reachable by **click**; the Standard tier requires keyboard/gamepad reach. A
Delete-only clear fails the first, a mouse-only ↺ fails the second. So: ↺ for the mouse, Delete on
the focused binding for keyboard and pad.

★ The ↺ buttons are deliberately **not focusable**. Making them so would take the controls table
from 18 tab stops to 27 — slowing the input method that can least afford it, to duplicate a path
Delete already covers in one press. They are visible-but-inert when there is nothing to reset, which
is the Standard Button pattern's stated treatment and doubles as the **"which of these have I
changed?"** readout the table otherwise has no way to give.

**3. Esc during a rebind cancels rather than binding Esc.** Otherwise the only way out of a
listening row is to bind something, which traps a player who opened it by mistake. The cost:
**Esc cannot be bound to anything**, which is accepted (it is Pause's key, and unbinding it would
make the pause menu unreachable).

This is the **Standard Cancel** pattern, not a local rule — the library defines the universal
back-out as "right-click or ESC or the equivalent gamepad Cancel/B button", and that is what this
screen uses at both levels (cancel a rebind; leave the screen).

> ⛔ **CORRECTED 2026-08-25 (S8-06).** This paragraph previously read: *"`ui_cancel` is left at its
> engine default here, which is what makes gamepad B work without a project binding — worth stating
> because an implementer who did not know that could remove it as dead configuration."*
>
> **That was exactly backwards.** Redot 26.2 ships `ui_accept` and `ui_cancel` with **no gamepad
> events at all** — verified by dumping `InputMap.action_get_events()` on a clean project:
> `ui_accept` had Enter / Kp Enter / Space, `ui_cancel` had Escape, and neither had a single joypad
> button. (`ui_up` and the other directions *do* carry D-pad and stick, so it is specific to these
> two.) Gamepad **B** therefore did **not** work, and neither did **A**: confirm and back-out, the
> two most fundamental controls in the game, were unreachable on a controller.
>
> Both are now declared explicitly in `project.godot` with their keyboard events restored
> alongside — declaring a built-in action replaces its defaults wholesale, so omitting the keys
> would have traded a gamepad bug for a keyboard one.
>
> ★ **The lesson, and it is why the wording mattered:** the note did not merely record a wrong
> fact, it told a future implementer *not to touch* the thing that was broken. **A claim about
> engine defaults is a claim about a specific engine version** — this project runs a Godot *fork*,
> and that is precisely where a default is most likely to differ.

Focus treatment throughout is the **Three-State Focus Indicator** (default / hover /
keyboard-focus, distinguished by colour *and* border weight), inherited from `MenuStyle` rather
than re-specified here.

---

## Events Fired

| Player Action | Event | Payload |
|---|---|---|
| Any binding change | *(none — writes `user://settings.cfg` directly)* | — |
| Any display change | *(none — same)* | — |

This screen fires no game events. It owns no game state and never touches a match — which is what
makes it safe to open from a live pause.

---

## Transitions & Animations

None. The screen appears and disappears instantly. Snap-Never-Tween's base case, and a settings
screen is the last place to spend a flourish.

---

## Data Requirements

| Data | Source | Read / Write | Notes |
|------|--------|--------------|-------|
| Input bindings | `GameSettings` → `user://settings.cfg` | Read/Write | **Overrides only** — an untouched binding falls through to `project.godot` |
| UI scale | `GameSettings` | Read/Write | Clamped to 75–150% on load |
| Reduced motion | `GameSettings` | Read/Write | Read by the slice for `EntitySpriteFeed.glow_paused` |
| Action list | `GameSettings.REBINDABLE` | Read | `ui_*` actions deliberately excluded — see Open Questions |

★ **Only overrides are stored.** A player who never rebinds inherits future changes to the shipped
control scheme; storing every binding would freeze today's defaults into their file permanently.

---

## Accessibility

Tier: **Standard**. This screen is where three of the tier's commitments are *delivered*, not merely
respected:

- **Full input remapping** — every board action, keyboard and gamepad independently, with conflict
  warnings. (`accessibility-requirements.md`, Motor.)
- **Adjustable UI scale** — 75–150%, default 100%. (Visual.)
- **Motion reduction** — wired to the slice's one continuous ambient animation, so it does something
  rather than storing an inert preference. (Visual.)

And respects the same floors as the other screens:

| Floor | Value | Source |
|---|---|---|
| Menu text size | **≥ 24px** at 1080p | `accessibility-requirements.md`, Visual |
| Text contrast | **≥ 4.5:1** body / **3:1** large | WCAG AA, matching `main-menu.md` and `pause.md` |
| Hit target | **≥ 44×44 px** at 1080p | Standard tier |
| Readable at | **1080p and 1440p** — the confirmed target resolutions | `technical-preferences.md` |

Keyboard focus is styled distinctly from mouse hover by colour **and** border weight, so the
distinction is not colour-only. No information anywhere on this screen is carried by colour alone —
every row is labelled text, the ⚠ line states its warning in words, and the **changed-binding
highlight is paired with a live ↺** so the accent colour is never the only signal that a binding
differs from its default.

★ **A player can lock themselves out of nothing.** `ui_accept`, `ui_cancel` and the directional
actions are not rebindable, so no sequence of changes can leave a player unable to operate this
screen and undo them.

---

## Localization Considerations

- Action labels ("Move / Attack", "Cycle Build Type") are the longest strings and sit in a
  fixed-width column — size it to the expanded width, not the English.
- **Key names come from the engine** (`OS.get_keycode_string`) and are **not localized**. A player
  on a non-QWERTY layout sees physical-position names; the binding is by physical keycode, which is
  correct behaviour but may read oddly. Flagged in Open Questions.
- "PRESS…", the ⚠ conflict line, the ⚠ save-failure line and "Defaults restored." are player-facing
  strings and need translating.

**Character budgets** (English, before the ~40% expansion allowance):

| Element | Budget | Consequence of overflow |
|---|---|---|
| Action label | **24 chars** | Column is fixed-width; longer wraps into the binding buttons |
| Binding button text | **12 chars** | Longer truncates — engine key names are the risk ("BracketLeft" is 11) |
| Section heading | **16 chars** | Cosmetic only |
| Hint / warning line | **72 chars** | Longer wraps to a second line and shifts the Display group down |

The longest current action label is "Focus Action Panel" (18) — within budget at 24, and within it
again after expansion only because the column was sized to the expanded width.

---

## GDD Alignment

**N/A — no GDD owns this screen.** Settings is not a game system: it configures how the player
operates the game rather than what the game does, so it has no entry in `systems-index.md` and no UI
Requirements to satisfy. Its requirements come from `design/accessibility-requirements.md` instead,
which is unusual enough to state rather than leave as a blank section.

---

## Acceptance Criteria

- [x] Reachable from both the main menu and the pause overlay, and Back returns to whichever opened
      it, with focus on that screen's Settings entry.
- [x] Every rebindable action shows its current keyboard and gamepad binding, or "—" when unbound.
- [x] A rebind takes effect immediately and persists across a restart.
- [x] Binding an input already used by another action shows a warning naming that action, and the
      bind still applies.
- [x] Keyboard and gamepad bindings change independently.
- [x] Esc during a rebind cancels without changing anything.
- [x] UI scale adjusts between 75% and 150% and persists.
- [x] Reduced motion persists and visibly stops the resting glow animation.
- [x] Reset to Defaults clears every override.
- [x] A single binding can be reset on its own, by click (↺) and by keyboard/gamepad (Delete on the
      focused binding), without disturbing any other customisation — including the same action's
      binding on the other device.
- [x] Bindings that differ from their default are visibly marked, and the mark is not colour-alone.
- [x] Resetting the last remaining override leaves the saved file mentioning no bindings at all, so
      the player continues to inherit future changes to the shipped control scheme.
- [x] A settings file that is missing, out of range, or references a deleted action degrades
      cleanly rather than erroring.
- [x] A failed save tells the player, names the file, and does not roll back the change.
- [x] Opens within **150 ms** of activation on target hardware — it loads no assets and reads
      already-parsed settings, so anything slower indicates a regression, not a cost.
- [x] Every element is readable and operable at **1080p and 1440p**.
- [x] `/ux-review` run 2026-08-24 — verdict recorded below.

---

## Open Questions

1. ~~**This spec is retroactive and unreviewed**~~ — ⚠ **partially resolved.** `/ux-review` ran
   2026-08-24 and returned **NEEDS REVISION** with 4 blocking issues, all now fixed: the missing
   error state (B-1, which also required a code change — save failures were silent), Slider and
   Toggle being undocumented patterns (B-2, now in the library), the absent contrast ratio (B-3),
   and `Standard Cancel` being re-specified rather than referenced (B-4).
   **The spec was still written after the screen shipped**, which is what let those four go
   unnoticed — three of the four were never *decided*, only never *noticed*. The reviewer did not
   challenge Back-focused-on-open, the absence of OK/Cancel, or the flat controls list; those stand,
   but they stand unchallenged rather than endorsed.
2. ~~**No per-change undo**~~ — ✅ **fixed 2026-08-24 (S6-28).** Per-binding reset via ↺ (click) or
   Delete (focused binding), at **cell** granularity rather than per row — a player who mis-binds
   their gamepad keeps their keyboard binding for the same action, which per-row would have thrown
   away and would have been the same bug at smaller scale.
   ⚠ **Residual:** there is still no *chronological* undo. Any binding can be returned to its
   default, but not to a previous non-default value. That needs a change history and is not
   implemented; nobody has asked for it.
3. ~~**A failed save is silent**~~ — ✅ **fixed 2026-08-24** (review B-1). Every save routes through
   one funnel that surfaces the error on the hint line and pushes it to the log; the change is not
   rolled back. Routed through a single site precisely because four separate call sites is how it
   came to be dropped in the first place.
4. **`ui_*` actions are not rebindable at all.** This prevents lockout, but it also means a player
   cannot remap confirm/cancel or the cursor directions — which a motor-accessibility need might
   legitimately require. The safe fix is a rebindable `ui_*` set with a guaranteed-reachable reset
   (e.g. a mouse-only path back to defaults), not simply unlocking them.
5. **Key names are engine-supplied and unlocalized**, and are physical-position names. Correct for
   binding, potentially confusing on non-QWERTY layouts.
6. **No audio settings** because no audio buses exist. Both parent specs list volume as belonging
   here; author that section when audio ships.
7. **`InputConfig.menu_keyboard_nav_enabled`** (ADR-0014 §6) is still unimplemented and would belong
   on this screen. There is no `InputConfig` instance in the project, and the ADR flags
   `FOCUS_CLICK`'s traversal-suppression as its one unverified engine claim — verify before building.
