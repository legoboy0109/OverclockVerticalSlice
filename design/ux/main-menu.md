# UX Spec: Main Menu

> **Status**: Reviewed — APPROVED (`/ux-review` 2026-07-27, 0 blocking)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-27
>
> ⛔ **Note added 2026-08-24 (no design change).** The **control-binding / rebinding UI** is
> deferred until this menu is implemented, by user decision. It belongs under the **Settings**
> screen this spec already routes to but does not itself specify. The precondition is done — all
> seven board verbs are named InputMap actions with keyboard *and* gamepad bindings as of S6-17/20,
> so there is now something concrete for such a screen to edit. Full context, the current binding
> table, and two items travelling with it (`InputConfig.menu_keyboard_nav_enabled`, and a missing
> pad binding for `board_cursor_cycle`) are in `production/post-gate-backlog.md` item 6.
> **Whoever specs the Settings screen should start there.**
> **Journey Phase(s)**: Entry / cold boot (no player-journey.md yet — see Open Questions)
> **Template**: UX Spec
> **Scope**: Vertical Slice (S2-05). VS-minimal entry set; persistence/campaign deferred (Alpha+).

---

## Purpose & Player Need

The first screen on launch. In the VS its only job is to get the player into a skirmish
quickly and to expose the Standard-tier accessibility/settings before play. The player arrives
wanting to **start a match** (or adjust settings, or quit). Nothing here should slow that down —
a strategy player booting a slice wants to be reading the board within seconds, not navigating
menus. If this screen didn't exist, there'd be no launch surface for settings and no clean
entry/return point after Quit-to-Menu from a match.

---

## Player Context on Arrival

Reached on **cold boot** and on **Quit to Main Menu** from an in-match pause. Emotional state:
neutral/anticipatory on boot; on return-from-match, possibly post-loss (reflective) or
post-win (satisfied) — the menu must read calmly in all three. Players arrive **voluntarily**
(boot) or are **routed here** (quit). No time pressure.

---

## Navigation Position

`root → Main Menu`. This is the **top-level hub** — always the boot destination and the return
target from pause → Quit to Main Menu. Alternate entry: none (it is the root).

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| App launch | Process start | none (fresh) |
| In-match Pause | "Quit to Main Menu" (confirm) | match discarded (VS has no save); returns to a clean menu |

| Exit Destination | Trigger | Notes |
|---|---|---|
| VS skirmish (in-match) | "New Skirmish" | Starts a fresh match; loads the VS map + HUD |
| Settings | "Settings" | Opens the settings screen (separate spec — see Data Requirements / Open Questions). ⛔ **Control bindings live here** — deferred to this screen by user decision 2026-08-24; the actions are already named and rebindable in `project.godot`, see `production/post-gate-backlog.md` item 6 |
| App exit | "Quit" (confirm) | Closes the process |

---

## Layout Specification

### Information Hierarchy

1. **Game title / logo** (identity, Neon Retro-Future — first thing seen).
2. **New Skirmish** (the primary action; visually dominant among entries).
3. **Settings**, **Quit** (secondary, smaller).
4. Build/version stamp (discoverable, corner, low priority — useful for playtest bug reports).

### Layout Zones

Center-stacked vertical menu (standard for a title screen; reads at a glance, trivially
keyboard/gamepad navigable, no board to keep clear here).

| Zone | Location | Hosts |
|------|----------|-------|
| Title | upper third, centered | game title / logo |
| Menu stack | center, vertical | New Skirmish · Settings · Quit |
| Footer | bottom corner | build/version stamp |

### Component Inventory

| Component | Zone | Type | Content | Interactive | Pattern |
|-----------|------|------|---------|-------------|---------|
| Title | Title | image/text | OVERCLOCK logo | No | — |
| New Skirmish | Menu stack | button | "New Skirmish" | Yes | **Standard Button** |
| Settings | Menu stack | button | "Settings" | Yes | **Standard Button** |
| Quit | Menu stack | button | "Quit" | Yes | **Standard Button** |
| Version stamp | Footer | text | build id | No | — |

*No dead entries* — Campaign/Continue are omitted in the VS (persistence deferred), not greyed.

### ASCII Wireframe

```
 ┌─────────────────────────────────────────┐
 │                                         │
 │              O V E R C L O C K          │
 │            ‹neon title / logo›          │
 │                                         │
 │            ┌───────────────────┐        │
 │            │   NEW SKIRMISH    │  ‹focus│
 │            └───────────────────┘        │
 │            ┌───────────────────┐        │
 │            │     SETTINGS      │        │
 │            └───────────────────┘        │
 │            ┌───────────────────┐        │
 │            │       QUIT        │        │
 │            └───────────────────┘        │
 │                                         │
 │  vslice-build 0.x                       │
 └─────────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| Default | Load | Full menu, New Skirmish focused |
| Quit confirm | "Quit" pressed | Confirm/cancel prompt ("Quit OVERCLOCK?") |
| From-match return | Quit to Main Menu | Identical default menu (VS has no save, so no "Continue") |
| Loading (into match) | "New Skirmish" pressed | Brief transition while the VS map/HUD load |

No empty state (menu content is static). No error state expected on the menu itself.

---

## Interaction Map

Input: **Keyboard/Mouse primary, Gamepad partial** (from technical-preferences).

| Component | Action | Inputs | Feedback | Outcome |
|-----------|--------|--------|----------|---------|
| New Skirmish | activate | click · Enter/Space · gamepad A | button pressed state | → VS skirmish |
| Settings | activate | click · Enter/Space · gamepad A | pressed state | → Settings screen |
| Quit | activate | click · Enter/Space · gamepad A | pressed state | → Quit-confirm prompt |
| Quit confirm | confirm/cancel | click · Enter (confirm) / Esc (cancel) | — | app exit / back to menu |

Focus order (keyboard/gamepad): New Skirmish → Settings → Quit. New Skirmish focused on load.
Every element has a keyboard-focus indicator distinct from mouse-hover (dual-focus,
**Three-State Focus Indicator** convention).

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| New Skirmish | `match_started` (game-state boot) | VS map id, sides |
| Settings | none (navigation) | — |
| Quit (confirmed) | `app_quit` | — |

No action here writes persistent game state (VS has no save system). Analytics events are
out of VS scope.

---

## Transitions & Animations

- **Screen enter (boot):** fade/scale-in of title + menu (Snap-Never-Tween base: the menu is
  interactive instantly; the flourish is decorative).
- **Screen exit (New Skirmish):** cut/fade to the loading transition, then the match.
- **Quit-confirm:** modal prompt snaps in over a dimmed menu.
- **Reduced motion:** all enter/exit flourishes stripped; instant presentation, no info loss.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Build/version string | Build/config | Read | For playtest bug reports |
| VS map + sides definition | Game-state / VS content | Read | Consumed on New Skirmish |
| Settings values | Settings/config store | Read/Write | Owned by the Settings screen, not this menu |

The menu owns no game state. Settings persistence is a Settings-screen/config concern.

---

## Accessibility

Tier: **Standard** (WCAG 2.1 AA + CVAA).
- Full keyboard/gamepad navigation; New Skirmish focused on load; visible focus indicator
  distinct from hover.
- Text ≥ 20px critical, ≥ 4.5:1 contrast; entries readable at 1080p and 1440p.
- No information by color alone (Non-Hue Semantic Layer) — entries are labeled text, not
  color-coded.
- Reduced-motion strips title/menu flourishes.
- Hit-target minimum: menu buttons present a target of **≥ 44×44 px at 1080p** (they far exceed
  this by design, but it's the floor).
- Settings (input remap, text size, volume, reduced motion) are reachable from here — the tier's
  remap/text-size commitments are hosted by the Settings screen this menu links to.

---

## Localization Considerations

- Longest strings: "NEW SKIRMISH" and the Quit-confirm prompt. Buttons must accommodate ~40%
  text expansion (e.g., German) without wrapping or clipping — size the menu buttons to the
  expanded width, not the English width. HIGH PRIORITY for the localization pass.
- "OVERCLOCK" title is a brand mark — not localized.
- Version stamp is numeric/latin — no localization.

---

## Acceptance Criteria

- [ ] Main menu appears within [X]ms of app launch (target set at build time).
- [ ] "New Skirmish" starts a fresh VS match and loads the board + HUD.
- [ ] "Settings" opens the settings screen and returns to the menu on back.
- [ ] "Quit" shows a confirm prompt; confirming exits, cancelling returns to the menu.
- [ ] Keyboard/gamepad navigation reaches New Skirmish → Settings → Quit in order, each with a
      focus indicator distinct from mouse-hover.
- [ ] No Campaign/Continue entry appears in the VS build.
- [ ] With reduced-motion enabled, the menu presents instantly with no lost information.

---

## Open Questions

1. ~~**Player journey absent**~~ — ✅ **RESOLVED 2026-07-27 (S2-08):** `design/player-journey.md`
   now exists; its alignment check confirms this menu's cold-boot / return-from-match arrival
   assumptions are consistent with the journey (no rework needed).
2. **New Skirmish → side/faction pick?** The VS is symmetric (scope.md §5), so New Skirmish can
   launch straight into the match with no pre-match pick. If the VS build wants a side choice or
   a map confirm, that's a tiny intermediate screen (flag, not authored here).
3. **Settings screen is a separate spec** — not required by S2-05 (HUD/menu/pause only). This
   menu links to it as a named dependency; author it when settings implementation is scheduled.
