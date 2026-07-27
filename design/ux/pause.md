# UX Spec: Pause Menu

> **Status**: Reviewed — APPROVED (`/ux-review` 2026-07-27, 0 blocking)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-27
> **Journey Phase(s)**: In-match interrupt (no player-journey.md yet — see Open Questions)
> **Template**: UX Spec
> **Scope**: Vertical Slice (S2-05). In-match overlay; Restart included (playtest replay aid).

---

## Purpose & Player Need

A deliberate interrupt from within a match: the player wants to **step away, restart, adjust
settings, or leave to the menu** without losing their place involuntarily. OVERCLOCK is
turn-based and self-paced, so pause is not a safety valve against real-time pressure — it's a
convenience/exit surface. During the VS playtests it earns its keep via **Restart Skirmish**:
gathering the swing-back close/decided samples (scope.md needs ≥3 of each) means replaying short
skirmishes repeatedly, and Restart makes that one keypress instead of quit → menu → New Skirmish.
Without this screen there's no in-match way to reach settings or leave cleanly.

---

## Player Context on Arrival

Invoked **mid-match, voluntarily**, by the player pressing pause/Esc. Emotional state: variable —
mid-think, stepping away, or frustrated and wanting a restart. The board should remain visible
(dimmed) behind the overlay so the player keeps their mental context. No time pressure (the sim
is turn-based; pausing changes nothing about game state).

---

## Navigation Position

`… → In-Match → Pause (overlay)`. A **context-dependent overlay**, reachable only during a
match. Not a top-level destination. Sits on top of the live board + HUD, which are frozen/dimmed
beneath it.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| In-match | Esc / Pause button / gamepad Start | current match state (frozen, visible beneath) |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Resume (back to match) | "Resume" · Esc again | Returns to exact match state; no state change |
| Fresh match | "Restart Skirmish" (confirm) | Discards current match, reloads the VS map from turn 1 |
| Settings | "Settings" | Opens settings; back returns to the pause overlay |
| Main Menu | "Quit to Main Menu" (confirm) | Discards current match (VS has no save); one-way for this match |

Restart and Quit-to-Menu are **one-way for the current match** — the in-progress skirmish is not
recoverable (VS has no save). Both are confirm-gated.

---

## Layout Specification

### Information Hierarchy

1. **Resume** (the default/primary action — most players pause then resume).
2. **Restart Skirmish**, **Settings**, **Quit to Main Menu** (secondary).
3. "PAUSED" label (orientation).

### Layout Zones

Center-stacked vertical menu over a dimmed, still-visible board. Same stack idiom as the main
menu (consistency), but as a modal overlay — the board beneath is the context the player is
holding.

| Zone | Location | Hosts |
|------|----------|-------|
| Scrim | full screen | dim over the frozen board/HUD |
| Label | upper-center of the panel | "PAUSED" |
| Menu stack | center | Resume · Restart Skirmish · Settings · Quit to Main Menu |

### Component Inventory

| Component | Type | Content | Interactive | Pattern |
|-----------|------|---------|-------------|---------|
| Scrim | overlay | dim layer over board | No | — |
| Resume | button | "Resume" | Yes | **Standard Button** |
| Restart Skirmish | button | "Restart Skirmish" | Yes | **Standard Button** |
| Settings | button | "Settings" | Yes | **Standard Button** |
| Quit to Main Menu | button | "Quit to Main Menu" | Yes | **Standard Button** |

### ASCII Wireframe

```
 ┌─────────────────────────────────────────┐
 │····· (board dimmed, still visible) ·····│
 │····┌───────────────────────────┐····· │
 │····│          PAUSED           │······ │
 │····│  ┌─────────────────────┐  │······ │
 │····│  │      RESUME         │  │ ‹focus│
 │····│  └─────────────────────┘  │······ │
 │····│  ┌─────────────────────┐  │······ │
 │····│  │  RESTART SKIRMISH   │  │······ │
 │····│  └─────────────────────┘  │······ │
 │····│  ┌─────────────────────┐  │······ │
 │····│  │     SETTINGS        │  │······ │
 │····│  └─────────────────────┘  │······ │
 │····│  ┌─────────────────────┐  │······ │
 │····│  │  QUIT TO MAIN MENU  │  │······ │
 │····│  └─────────────────────┘  │······ │
 │····└───────────────────────────┘······ │
 └─────────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| Default | Pause pressed | Overlay + dimmed board, Resume focused |
| Restart confirm | "Restart Skirmish" | Confirm prompt ("Restart this skirmish?") |
| Quit confirm | "Quit to Main Menu" | Confirm prompt ("Leave the match? Progress is lost.") |
| Blocked during resolve | pause pressed mid-animation | Pause defers until the current commit animation settles, OR opens with animations paused — see Open Questions |

No empty/loading state (overlay is instant). No pause during the opponent's AI turn is required,
but if allowed it simply freezes the same way — see Open Questions.

---

## Interaction Map

Input: **Keyboard/Mouse primary, Gamepad partial**.

| Component | Action | Inputs | Feedback | Outcome |
|-----------|--------|--------|----------|---------|
| (open) | pause | Esc · Pause button · gamepad Start | scrim + overlay snap in | pause overlay shown |
| Resume | activate | click · Enter · Esc · gamepad A/Start | overlay dismiss | back to match |
| Restart Skirmish | activate | click · Enter · gamepad A | pressed state | → Restart-confirm |
| Settings | activate | click · Enter · gamepad A | pressed state | → Settings (returns here) |
| Quit to Main Menu | activate | click · Enter · gamepad A | pressed state | → Quit-confirm |

**Esc is symmetric**: opens pause from the match, and (from the default pause view) resumes.
Focus order: Resume → Restart Skirmish → Settings → Quit to Main Menu; Resume focused on open.
Distinct keyboard-focus vs. mouse-hover indicators (dual-focus).

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Open pause | `game_paused` | — |
| Resume | `game_resumed` | — |
| Restart Skirmish (confirmed) | `match_restarted` | VS map id, sides |
| Quit to Main Menu (confirmed) | `match_abandoned` | — |

Restart and Quit discard the current match — flagged for the architecture team as a state-teardown
path (the VS has no save to protect, but the match instance must be cleanly disposed and rebuilt).

---

## Transitions & Animations

- **Enter:** scrim fades + menu panel snaps in over the frozen board (Snap-Never-Tween base;
  interactive immediately).
- **Exit (Resume):** scrim/menu snap out, board un-dims, exact state resumes.
- **Confirm prompts:** modal snap-in over the dimmed pause menu.
- **Reduced motion:** scrim/menu appear instantly with no flourish; no info loss.
- No animation here risks motion sickness (static overlay).

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Match-in-progress handle | Game-state | Read | To freeze/resume/teardown |
| VS map + sides | Game-state / VS content | Read | Consumed on Restart |
| Settings values | Settings/config | Read/Write | Owned by Settings screen |

Pause reads the match handle to freeze/resume and to tear down on Restart/Quit. It owns no game
state itself. **Freeze semantics** (does pausing the turn-based sim need any special handling
beyond blocking input?) is an architecture question — flagged below.

---

## Accessibility

Tier: **Standard**.
- Full keyboard/gamepad nav; Resume focused on open; Esc both opens and resumes (symmetric,
  low-effort exit).
- Board dimmed beneath but the pause panel meets ≥ 4.5:1 contrast against the scrim; text ≥ 20px.
- No color-only information (labeled text buttons).
- Reduced-motion strips overlay flourishes.
- Confirm prompts on destructive actions (Restart, Quit) prevent accidental match loss — an
  accessibility/error-prevention safeguard, not just a UX nicety.
- Hit-target minimum: pause buttons present a target of **≥ 44×44 px at 1080p**.

---

## Localization Considerations

- Longest strings: "QUIT TO MAIN MENU", "RESTART SKIRMISH", and the two confirm prompts. Size the
  panel to ~40% text expansion without wrapping. HIGH PRIORITY for localization.
- Confirm-prompt body text ("Leave the match? Progress is lost.") expands most — give it room.

---

## Acceptance Criteria

- [ ] Pressing Esc/Pause during a match opens the overlay within [X]ms with the board frozen and
      dimmed beneath, Resume focused.
- [ ] "Resume" (or Esc again) returns to the exact prior match state with no change.
- [ ] "Restart Skirmish" shows a confirm; confirming reloads the VS map from turn 1.
- [ ] "Quit to Main Menu" shows a confirm; confirming returns to the main menu and the match is
      disposed.
- [ ] "Settings" opens settings and returns to the pause overlay on back.
- [ ] Keyboard/gamepad navigation reaches Resume → Restart → Settings → Quit in order, each with a
      focus indicator distinct from mouse-hover.
- [ ] Destructive actions (Restart, Quit) cannot fire without a confirm step.
- [ ] With reduced-motion enabled, the overlay appears instantly with no lost information.

---

## Open Questions

1. **Player journey absent** (backlogged S2-08) — arrival context assumed; revisit later.
2. **Pause during resolve/AI turn** — can the player pause mid-commit-animation or during the
   opponent's AI turn? Simplest rule: pause is always allowed and freezes whatever is on screen;
   any in-flight animation resumes on Resume. Confirm the freeze/resume semantics with the
   architecture team (turn-manager / apply_action interaction).
3. **Freeze semantics** — the sim is turn-based and event-driven, so "pause" mostly means "block
   input + halt animations." Confirm no timer/tween relies on wall-clock that would desync on
   resume (Snap-Never-Tween makes this cheap).
4. **Settings screen is a separate spec** — reached from here and from the main menu; not authored
   under S2-05 (HUD/menu/pause only).
