# UX Spec: Settings Screen

> **Status**: **Written retroactively 2026-08-24 (S6-26)** — documents the shipped screen. **Not
> yet reviewed** (`/ux-review` owed).
> **Author**: main session, from standing commitments
> **Last Updated**: 2026-08-24
> **Journey Phase(s)**: Pre-play configuration (from the main menu) and in-match interrupt (from
> pause)
> **Template**: UX Spec
> **Scope**: Vertical Slice. Controls + Display only — audio is out of scope until audio buses exist.

> ### ⚠ This spec is retroactive, and that is worth stating plainly
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
| Hint / conflict line | Controls | text | prompt or ⚠ warning | No | — |
| UI Scale | Display | slider + value | 75–150%, shown as % | Yes | — |
| Reduced Motion | Display | toggle | on/off | Yes | — |
| Reset to Defaults | Footer | button | "RESET TO DEFAULTS" | Yes | **Standard Button** |
| Back | Footer | button | "BACK" | Yes | **Standard Button** |

### ASCII Wireframe

```
 ┌───────────────────────────────────────────────────┐
 │  SETTINGS                                         │
 │  CONTROLS                                         │
 │                     KEYBOARD      GAMEPAD         │
 │  Move / Attack      [   M    ]   [  Pad 2  ]      │
 │  Build              [   B    ]   [  Pad 3  ]      │
 │  Cycle Build Type   [   C    ]   [  Pad 9  ]      │
 │  Produce            [   P    ]   [  Pad 1  ]      │
 │  Cycle Unit Type    [   V    ]   [ Pad 10  ]      │
 │  End Turn           [  Tab   ]   [  Pad 4  ]      │
 │  Pause              [ Escape ]   [  Pad 6  ]      │
 │  Focus Action Panel [QuoteLeft]  [  Pad 8  ]      │
 │  Jump Cursor        [BracketLeft][  Pad 7  ]      │
 │  ⚠ Also bound to: Pause                           │
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

No loading state (settings load at boot). No error state — a failed save is not surfaced, which
Open Questions flags.

---

## Interaction Map

| Component | Action | Inputs | Feedback | Outcome |
|-----------|--------|--------|----------|---------|
| Binding button | begin rebind | click · Enter/Space · gamepad A | button reads "PRESS…" | listening |
| (listening) | assign | any key, or any pad button | table updates; ⚠ if it clashes | bound, applied, saved |
| (listening) | cancel | Esc | table restores | nothing changed |
| UI Scale | adjust | drag · arrows when focused | live rescale, % updates | applied, saved |
| Reduced Motion | toggle | click · Enter · gamepad A | toggle state | applied, saved |
| Reset to Defaults | activate | click · Enter · gamepad A | table repopulates | overrides cleared, saved |
| Back | activate | click · Enter · Esc · gamepad A | screen closes | returns to caller |

Focus order: the controls table top-to-bottom (keyboard column, then gamepad), then UI Scale,
Reduced Motion, Reset, Back. **Back is focused on open** — the most likely action for a player who
opened the screen to look rather than to change something, and a safe landing for a gamepad.

### Three decisions that need stating, because none is obvious

**1. Conflicts are reported, never refused.** Refusing a duplicate outright makes swapping two
bindings impossible: every swap passes through a state where both actions want the same input. The
⚠ line names what else uses it and the player decides.

**2. Changes apply and save immediately — there is no OK/Cancel.** A player rebinding a control they
cannot press needs to *test* it, and an un-applied change cannot be tested. The cost is that there
is no "revert my last change"; **Reset to Defaults is the only undo**, which is coarse.

**3. Esc during a rebind cancels rather than binding Esc.** Otherwise the only way out of a
listening row is to bind something, which traps a player who opened it by mistake. The cost:
**Esc cannot be bound to anything**, which is accepted (it is Pause's key, and unbinding it would
make the pause menu unreachable).

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

And respects the same floors as the other screens: text ≥ 24px for menu UI, hit targets ≥ 44×44 at
1080p, keyboard focus styled distinctly from mouse hover (colour **and** border weight, so it is not
colour-only), no information by colour alone.

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
- "PRESS…", the ⚠ conflict line and "Defaults restored." are player-facing strings and need
  translating.

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
- [x] A settings file that is missing, out of range, or references a deleted action degrades
      cleanly rather than erroring.
- [ ] ⚠ **`/ux-review` has not been run on this screen.** It is the only screen in the game that
      shipped without one.

---

## Open Questions

1. **This spec is retroactive and unreviewed.** The screen exists; nothing in this document was
   challenged before it was built. `/ux-review` is owed, and these are the choices I would expect it
   to push on: Back-focused-on-open, the absence of OK/Cancel, and a single flat controls list with
   no grouping.
2. **No per-change undo.** Reset to Defaults is the only revert, and it is all-or-nothing. A player
   who mis-binds one control loses every other customisation to fix it. A per-row "clear" would be
   cheap and is not implemented.
3. **A failed save is silent.** `GameSettings.save()` returns an `Error` that this screen discards.
   A read-only `user://` would lose the player's settings with no indication.
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
