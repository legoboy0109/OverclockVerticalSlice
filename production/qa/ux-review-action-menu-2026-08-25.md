## UX Review: Contextual Action Menu

**Date**: 2026-08-25 · **Story**: S7-07
**Document**: `design/ux/action-menu.md` (592 lines)
**Reviewer**: `/ux-review` skill
**Platform Target (authoritative)**: `.claude/docs/technical-preferences.md` — PC + **Steam Deck**,
gamepad **required**, floor **1280×800**
**Accessibility Tier**: Standard (`design/accessibility-requirements.md`)

> ⚠ **Independence: still not achieved, and this is the second time.** S7-07 existed because the
> previous review was a self-audit by the spec's author. So is this one. What it *can* do
> objectively — verify every claim against the shipped code, and re-check the spec against config
> that has moved — it does, and that is where both blocking findings came from. **A subjective
> design/accessibility critique still wants separate eyes.**

### Completeness: 14/14 sections present
All required sections present: header, Purpose & Player Need, Player Context on Arrival,
Navigation Position, Entry & Exit Points, Layout Specification, States & Variants, Interaction Map,
Events Fired, Transitions & Animations, Data Requirements, Accessibility, Localization, Acceptance
Criteria (30). No gaps.

### ✅ Claim verification against the shipped code — all pass
The high-value check, and the one that found real defects last time (two of the previous review's
six blocking issues were the spec describing something the build did not do).

| Claim | Verified |
|---|---|
| AC-15 — rebound key shows on the row | ✅ `action_menu.gd:742` reads live `InputMap.action_get_events` |
| AC-16 — Reduced Motion removes the fade | ✅ `_reduced_motion` injected via `configure()` |
| AC-17 — `[C]`/`[V]` cycles retired | ✅ only historical comments remain in `project.godot` |
| AC-21 — AP/Credit projected-cost echo | ✅ `vertical_slice_root.gd:1285` calls `open_ap_preview` — **the S6-32 defect stayed fixed** |
| AC-24 — refused commit reaches the player | ✅ `commit_rejected` connected at `vertical_slice_root.gd:407` |

★ Both of the previous review's *real* defects remain wired. Nothing has silently regressed.

### Quality Issues: 2 blocking, 2 advisory

**1. Platform Target header is stale — [BLOCKING]**
- **What's wrong**: the header reads *"Gamepad secondary (partial)"*. `technical-preferences.md`
  now reads **"Gamepad Support: Full — required"** with **Steam Deck as the target hardware floor**
  (changed in S7-08, after this spec was written).
- **Where**: document header.
- ★ **The spec's *content* is fine** — the Interaction Map already gives gamepad full parity
  (D-pad, A, B, X/Y, LB/RB, L3, Back). Only the header's claim about the platform is wrong, and it
  is the line a reader trusts to know how much gamepad work is optional.
- **Fix**: update the header to match `technical-preferences.md`.

**2. The resolution criterion omits the floor — [BLOCKING]**
- **What's wrong**: AC-22 tests **1920×1080 and 2560×1440**. Both are *larger* than the shipping
  floor of **1280×800**. A menu that fits at 1080p can clip at 800p, and this criterion would not
  catch it.
- **Where**: Acceptance Criteria, AC-22.
- ★ This is the single most consequential finding here: the menu is a floating plate with
  clearance, flip and clamp rules, and **every one of those rules is resolution-sensitive.** The
  spec's own AC-6/7/8 (clearance, edge flip, vertical clamp) are exactly what a smaller viewport
  stresses, and none of them is currently tested at the smallest supported size.
- **Fix**: add 1280×800 to AC-22, and re-check AC-6/7/8 there specifically.

**3. Text legibility at the floor is unaddressed — [ADVISORY]**
- The Accessibility section commits to Standard tier but says nothing about minimum text size at
  1280×800 on a 7″ panel. `technical-preferences.md` records this as an open Deck-Verified gap
  project-wide, so the spec is not uniquely at fault — but this surface carries per-row reason
  text, which is the smallest type in the menu.

**4. Godot-vs-Redot dual-focus parity still assumed — [ADVISORY]**
- The spec flags it: *"Redot 26.2 fork parity on this behaviour is assumed, not verified (GDD
  OQ-6)."* Still true. ★ It is now *cheaply* verifiable — S7-05 produced a real exported binary,
  so this can be checked on the shipping build rather than in the editor.

### GDD Alignment: ALIGNED
`command-action-interface.md` CR-1's loop (select → menu → verb → preview → commit) is fully
transcribed. The four decisions the GDD did not make are stated as decisions with their costs.
All six original open questions are closed; OQ-4 (pad accelerators possibly redundant) remains a
playtest observation rather than a defect.

### Accessibility: COMPLIANT (Standard tier)
Focus order defined and restricted to actionable rows; colour never the sole signal (disabled rows
carry dimming **and** words); three distinct attention states specified; the lock glyph deliberately
omitted with reasoning. Contrast figures are measured, not asserted.

### Pattern Library: CONSISTENT
Standard Cancel, Standard Button and the focus-indicator treatment are referenced rather than
re-specified. No new pattern is invented without being flagged.

### ✅ RESOLUTION — both blocking issues fixed the same day (S7-07b)

`design/ux/action-menu.md` revised 2026-08-25:

| # | Fix |
|---|---|
| **B1** | Platform Target now reads **PC + Steam Deck, gamepad REQUIRED, floor 1280×800**, with a note recording what it used to say and why it was wrong |
| **B2** | AC-22 extended to **1280×800**, 1920×1080 and 2560×1440. ★ New **AC-31** re-runs AC-6/7/8 (clearance, edge flip, vertical clamp) **at the floor specifically** — the plate rules are resolution-sensitive and the floor is where there is least room |

★ **Found while fixing:** the GDD Alignment table carried a row labelled bare `AC-25`, which is
`command-action-interface.md`'s AC-25 — colliding with **this** spec's own AC-25 two sections
below. Two different requirements under one label in a single document. Now written as
`` `command-action-interface.md` AC-25 ``. Confirmed 31 unique AC ids, no collisions.

The two advisories are **not** fixed and remain open by choice: text legibility at 1280×800 is a
project-wide Deck-Verified gap tracked in `technical-preferences.md`, and Redot/Godot dual-focus
parity is now cheaply checkable against the S7-05 binary but was not checked here.

> ### ✅ Advisory 4 CLOSED — 2026-08-26 (S8-09)
> Checked, and it holds. `tools/CaptureDualFocus.tscn` measures the behaviour on a real framebuffer
> instead of assuming it: 8 of 8 checks pass, deterministic across three runs. Focus and hover are
> independent state in Redot 26.2, and they are different **marks** — focus draws a 2px outline,
> hover draws no box. Report: `production/playtests/s8-09-dual-focus-2026-08-26.md`.
>
> ⚠ It also surfaced something the review could not have: **hover on its own is close to invisible**
> (a ~3% brightness lift on already-near-white glyphs, because `flat = true` suppresses the theme's
> hover StyleBox). The spec's binding claim passes; whether its promised *third* attention state is
> really there is now `action-menu.md` **OQ-7**, open and left for the spec's owner.
>
> ★ Advisory 3 (text legibility at 1280×800) remains open and is still the project-wide gap —
> partially addressed by S8-07's floor UI scale, still unobserved on a device.

### Verdict (at review time): **NEEDS REVISION**
**Blocking**: 2 — both are the spec having been overtaken by the Steam Deck decision (S7-08), not
authoring defects. **Advisory**: 2.

★ **Nothing here impugns the implementation.** Every behavioural claim verified against the code.
The gap is that the platform moved under a spec written before it, and the acceptance criteria have
not caught up.

---

## Post-fix status: ✅ **APPROVED**

Both blocking issues resolved. No behavioural claim changed — the fixes were a stale header line
and an acceptance-criterion gap, neither of which touched the implementation. The spec is
implementation-current again.

⚠ **The independence caveat stands unchanged.** Two reviews, two self-audits. The objective half
(claim-versus-code verification, and re-checking the spec against config that has moved) is where
every finding across both passes actually came from — and that half is sound. A subjective design
and accessibility critique has still never been done by anyone other than the author.
