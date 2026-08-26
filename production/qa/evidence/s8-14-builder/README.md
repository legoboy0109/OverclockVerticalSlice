# S8-14 / S8-15 / S8-16 — Builder art evidence

**Captured**: 2026-08-26 · **By**: `/qa-plan sprint` (QA plan Finding 2)
**Status**: ⛔ **NOT SIGNED OFF** — see "What this is for" below.

## Sheets

| File | Shows |
|---|---|
| `01-builder-idle-all-hues.png` | Idle · 3 hues × 2 facings · shipped 140×157 on 128×64 tiles |
| `02-builder-destroyed.png` | Destroyed state · 3 hues × 2 facings |
| `03-builder-vs-roster.png` | ★ Silhouette check — Builder vs the full rush roster |
| `04-cradle-detail-2x.png` | S8-16 cradle at 2× in all three hues |

⚠ **These composite the SHIPPED runtime PNGs at shipped size onto the stage colour.**
They deliberately **do not** use `board_preview.py`, which re-runs `cutout(pockets=True)` on its
input and can show artifacts absent from the master — S8-15 nearly chased a non-existent shadow
slab that way. Sheet = what the game draws.

## What this is for

`.claude/docs/coding-standards.md` requires *screenshot + lead sign-off* for Visual/Feel stories.
The three Builder art stories shipped with none, and **S8-14's own manifest entry records that the
base look was selected by the agent, not user-approved** — every other manifest entry carries an
explicit sign-off. ⇒ **The user has still not seen this unit.** These sheets exist so that can happen.

## ✅ What the sheets confirm

- **The cradle reads.** It is a visible dark-interior mass breaking the top silhouette at shipped
  size — S8-16's core claim, which two generation rounds failed to achieve and authored geometry did.
- **The ACCENT recolour works.** The cradle rim re-hues to orange / cyan / near-white across rush /
  boom / neutral, so `recolor.py` is keying on it correctly. ★ This was the specific risk of painting
  it in the shared ACCENT constant, and it is clear.
- **Builder ≠ Scout.** Both are four-legged, and they are not confusable: the Builder is hunched,
  grey-dominant and body-heavy with a cargo mass; the Scout is taller, orange-dominant and angular.
  ★ The 140 px vs 148 px sizing was the stated reason for the width choice, but the **silhouette**
  does the work, not the 8 px.
- **Neutral is achromatic** (0.1% coverage), correct per art-bible §4.2 — neutral means *unowned*.

## ⛔ What they also exposed — see QA plan Finding 3

`03-builder-vs-roster.png` shows the Builder as **markedly greyer than every other unit**. Measured:

| | rush | boom | neutral |
|---|---:|---:|---:|
| Scout | 45.6% | 45.3% | 0.0% |
| Trooper | 42.5% | 42.6% | 0.0% |
| Heavy | 62.7% | 62.0% | 0.0% |
| Sniper | 43.2% | 43.7% | 0.5% |
| **Builder** | **22.8%** | **22.9%** | 0.1% |

**The S8-05 accent gate's owned-faction floor is 30%.** The Builder is **7 points under it**, and
the roster spread is now **2.75×** against a stated 2.5× ceiling. **It would fail two assertions.**

⛔ **It does not fail, because `accent_coverage_test.gd:21` keeps a hand-written list —
`["scout", "trooper", "heavy", "sniper"]` — and the Builder is not in it.**

★★ **This is exactly the defect S8-14 fixed in the sibling guard, still live in this one.** S8-14
rewrote the art-coverage and glow-mask guards to enumerate `UnitTypes.ALL`; `accent_coverage_test.gd`
was written earlier (S8-05) for the same purpose and was not touched. ⚠ **The gate written because
"the Sniper defect shipped and survived a full art sprint because nothing measured it" does not
measure the roster's newest unit.**

## ⚠ Open, needs the user

1. **Sign off or reject the base look** — never approved.
2. **The 22.8% question is a DESIGN call, not a bug to patch.** The brief deliberately says *"grey
   everywhere else"* and *"the silhouette has to say 'not a soldier' before any colour is read"*, so
   low accent coverage is partly **intended**. But ownership still has to read on a busy board, and
   22.8% is closer to the Sniper defect (13.3%) than to the roster mean (48.5%).
3. **The S8-15 → S8-16 trade**: the cradle grew the sprite 145 → 157 px, giving back part of S8-15's
   "shorter". ★ Acknowledged in the commit as the chosen point on an opposed trade, and **cheap to
   move**.
