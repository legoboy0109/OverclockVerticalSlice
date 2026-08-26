# S8-14 / S8-15 / S8-16 — Builder art evidence

**Captured**: 2026-08-26 · **By**: `/qa-plan sprint` (QA plan Finding 2)
**Status**: ✅ Accent defect **FIXED** (S8-19, re-rendered 2026-08-26) · ⛔ base look **still not signed off**.

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

## ✅ What they exposed, and how it was fixed — S8-19

The first capture of these sheets showed the Builder **markedly greyer than every other unit**, and
measuring it confirmed a real defect:

| | rush | boom | neutral |
|---|---:|---:|---:|
| Scout | 45.6% | 45.3% | 0.0% |
| Trooper | 42.5% | 42.6% | 0.0% |
| Heavy | 62.7% | 62.0% | 0.0% |
| Sniper | 43.2% | 43.7% | 0.5% |
| **Builder — was** | ⛔ **22.8%** | ⛔ **22.9%** | 0.1% |
| ✅ **Builder — now** | **33.9%** | **34.2%** | 0.1% |

**The gate's owned-faction floor is 30%.** The Builder was **7 points under it**, and the roster
spread was **2.75×** against a 2.5× ceiling — it would have failed two of four assertions.

⛔ **It did not fail, because `accent_coverage_test.gd:21` kept a hand-written list —
`["scout", "trooper", "heavy", "sniper"]` — and the Builder was not in it.**

★★ **That was S8-14's own finding, still live in the sibling test.** S8-14 rewrote the art-coverage
and glow-mask guards to enumerate `UnitTypes.ALL` after a transcribed list let the Builder ship as a
magenta placeholder. `accent_coverage_test.gd` was written earlier (S8-05) **for the same purpose**
and was never touched. ⇒ **Fixing an anti-pattern where you found it is not fixing it.**

### How it was fixed — art, not threshold

★ The test's own failure message said it: *"Fix the ART, not this threshold: raise saturated
coverage via `promote_accent.py` and re-derive. Do NOT touch the silhouette."* That is what happened.

`promote_accent.py --target 34` **grows the existing accent regions outward** rather than inventing
new ones — the artist already decided *where* the accent belongs, dilation only decides how far it
extends. ⚠ Two earlier approaches (brightest-N pixels, value-banded components) produced correct
numbers and unusable art — orange speckle and a corduroy artefact. **The silhouette is untouched.**

**Target 34 was chosen by eye against three candidates**, not by picking the smallest passing number:

| Candidate | Shipped | Verdict |
|---|---:|---|
| 22.8% (was) | — | ⛔ fails the floor; ownership genuinely weak on a busy board |
| ✅ **34** | **33.9%** | **Clears the floor by ~4 pts. Grey upper hull still dominates, so "not a soldier" survives. Still the roster's least-coloured unit by 8.6 pts** |
| 38 | 38.1% | Passes, but the grey mass is visibly shrinking |
| 42 | 42.7% | ⛔ Reads as a combat unit — level with the Trooper's 42.5%. Fights the design |

★★ **Why not just clear the floor by the minimum:** the brief deliberately says *"grey everywhere
else"* and *"the silhouette has to say 'not a soldier' before any colour is read"*, so the Builder
**should** be the least-coloured unit — but ownership still has to read. 33.9% keeps both true.
⚠ Judged by rendering the candidates side by side at shipped scale on the stage colour, per the
standing rule: *a correct metric with wrong art is the normal case — if a number is the only check,
bad art passes.*

✅ **Gate now enumerates `UnitTypes.ALL`** via `EntitySpriteCatalog.type_token`, the same call the
renderer uses, so it cannot drift from what the game loads. **Verified to have teeth**: raising the
floor to 40% makes it fail naming *"builder rush … 33.9% … below the 40.0% floor"* and
*"builder boom … 34.2%"*. Roster spread is now **1.85×**.

## ⚠ Open, needs the user

1. **Sign off or reject the base look** — never approved.
2. ✅ **The coverage question is resolved** (S8-19, above) — repaint to 33.9%, user's call
   2026-08-26. ⚠ **Judge the result**: the sheets here are the post-fix art.
3. **The S8-15 → S8-16 trade**: the cradle grew the sprite 145 → 157 px, giving back part of S8-15's
   "shorter". ★ Acknowledged in the commit as the chosen point on an opposed trade, and **cheap to
   move**.
