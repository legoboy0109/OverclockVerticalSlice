# Visual/Feel Evidence — AP Counter Widget (hud-004)

> **Story**: production/epics/game-hud/story-004-ap-counter-widget.md
> **Type**: Visual/Feel (ADVISORY gate)
> **Status**: ⏳ OWED — pending a windowed (non-headless) session for sign-off

## Scope

The BLOCKING value assertions (AC-6/7/9a/19/28) are covered by the automated
Integration test `tests/integration/game-hud/ap_counter_widget_test.gd` (pass).
This document covers the **advisory** motion-quality criteria, which require a
human viewing a real (windowed) build — they cannot be asserted headlessly.

## Criteria to verify (reviewer sign-off)

| AC | Setup | Pass condition | Verdict |
|----|-------|----------------|---------|
| **AC-3b** | Start-of-turn AP reset to income (e.g. 8) | Fill reads as a **glow-fill** over ~`ap_fill_flourish_ms` (400ms), NOT an instant snap | ☐ |
| **AC-5b** | Commit spending 6 AP | Step-down reads as a **discrete/chunky tick** over ~`ap_tick_duration_ms` (120ms), never a smooth slide | ☐ |
| **AC-9b** | A `PlayerTurn` transition | The YOUR/ENEMY banner visibly displays + reads correctly for its `turn_banner_duration_ms` (1000ms) hold, with the directional slide-in (non-hue channel) | ☐ |
| **Echo snap** | Open, then change, then cancel a preview | The `→ projected` echo SNAPS (no tween) on open/change/close; the committed value moves only on a real commit | ☐ |
| **Opponent mute** | Opponent's turn, `show_opponent_ap = on` | Opponent AP renders under a persistent `OPPONENT` label + muted/desaturated treatment; the committed-vs-projected channel is the `→` + numerals, not hue alone (Accessibility E) | ☐ |

## Sign-off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| Lead / reviewer | | [ ] Approved | |

## Notes

- Motion/config values are data-driven from `HUDConfig` (`ap_fill_flourish_ms`,
  `ap_tick_duration_ms`, `turn_banner_duration_ms`) — tuning is a `/ux-design` +
  `/art-bible` concern, not pinned by this story.
- Capture screenshots/GIFs of the fill, tick, and banner into this folder when
  the windowed session runs.
