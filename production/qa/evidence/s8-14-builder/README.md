# S8-14 / S8-15 / S8-16 — Builder art evidence

**Captured**: 2026-08-26 · **By**: `/qa-plan sprint` (QA plan Finding 2)
**Status**: ✅ Base look **approved** by the user 2026-08-26 ("it looks good") · ✅ accent defect fixed (S8-19) · ✅ cradle re-seated on user feedback (S8-20).

## Sheets

| File | Shows |
|---|---|
| `01-builder-idle-all-hues.png` | Idle · 3 hues × 2 facings · shipped 140×157 on 128×64 tiles |
| `02-builder-destroyed.png` | Destroyed state · 3 hues × 2 facings |
| `03-builder-vs-roster.png` | ★ Silhouette check — Builder vs the full rush roster |
| `04-cradle-detail-2x.png` | S8-16 cradle at 2× in all three hues |
| ★ `05-cradle-before-after.png` | S8-20 cradle re-seat — before/after |
| ★★ `06-cradle-projection-fix.png` | **S8-21 — the cradle drawn in the hull's OWN projection. This is the one that mattered** |

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


---

## S8-20 — "the crate on the back looks a bit tacked on"

User feedback on the approved look, 2026-08-26. ★ **S8-16 had already identified this exact failure
mode** — its own note reads *"a flat box with no occlusion where it meets the hull reads as a
sticker, which is exactly what the first draft looked like"* — so the contact treatment existed and
was simply not doing enough. **Four separate causes, measured rather than guessed:**

| Cause | Was | Now |
|---|---|---|
| ⛔ **Value** — the single biggest one | Cradle lit face **150** against a hull median of **114**. A lighter object on a darker surface pops forward no matter what else is right. The palette had been matched to the hull's *lit panels* (160–162), not its median | `PLATE_LIT` **150 → 124**, `PLATE_MID` 112 → 102 |
| **Outline** | INK traced the **whole** box, including the lower edges buried in the hull. ★ A hard black line all the way round is the strongest sticker cue there is — real geometry has no outline where it meets another surface | Ink only on the edges that form silhouette |
| **Rim lighting** | Both near rim edges painted one flat `ACCENT`, so the rim read as a **decal outline traced on the hull** | Directional: `ACCENT_LIT` on the near-left, `ACCENT_SHADE` on the near-right. ⚠ Both kept inside `recolor.py`'s accent gate so all three still re-key together |
| **Contact shadow** | A **rectangular band** across the bounding width — the wrong shape. The footprint is a 2:1 rhombus, so it darkened hull the cradle never touches and missed hull it does. Occlusion that doesn't match an object's shape reads as dirt, not contact | Distance-field off the **cradle's own alpha**, biased downward. Right shape by construction, and it picks up the brackets for free |

★★ **Plus the decisive addition: mounting brackets.** Occlusion says an object is *resting* on a
surface; visible hardware says it is *fixed* to one. Three chunky struts at the rim corners, drawn
**before** the box so it overlaps them and they read as running underneath. ⚠ Sized at ~34 master px
because the sprite ships at ~0.17×, so anything under ~20 px vanishes in the resample.

### ⚠ Two things that were tried and rejected

- **A wider "cargo bed" spanning the back** (width 0.60–0.68). It **overhangs the hull silhouette**
  on both sides and reads as a tray balanced on top — worse than what it replaced.
- **A taller, more prominent box.** Makes the cradle read as more three-dimensional and *more*
  separate. Prominence and integration pull opposite ways here.

### ✅ And the height trade went the right way for once

S8-16 grew the sprite 145 → 157 px, giving back part of S8-15's "shorter and bulkier". Seating the
cradle **into** the hull rather than perching it on top means less canvas growth: **157 → 154 px.**
★ Slightly shorter than what shipped, so this recovers a little of what the cradle cost.

Accent re-measured after the re-derive: **35.1% / 35.5%**, still clearing the 30% floor, roster
spread **1.79×**. Suite 1307/1307.


---

## ⛔⛔ S8-21 — "still looks off", and this time the cause was structural

Second round of feedback on the cradle. S8-20 had fixed four genuine defects and the crate still
looked wrong, which is itself the finding: **when correcting several real problems does not fix the
symptom, the diagnosis is incomplete, not the execution.**

### The hull is not in the projection the cradle was drawn in

Measured off the bare master's own silhouette:

| Hull top edge | Measured slope | True 2:1 dimetric | Off by |
|---|---:|---:|---:|
| **left** | **−0.179** | −0.500 | ⛔ **64%** |
| right | +0.305 | +0.500 | 39% |

★★ **This machine is a GENERATED render.** SDXL painted a *plausible-looking* three-quarter view,
not a mathematically correct dimetric one — and it is **asymmetric**, the left edge far shallower
than the right. `draw_cargo_cradle.py` drew a perfect **symmetric 2:1 rhombus**.

⇒ **The crate was in one projection and the machine it sits on was in another.** The eye reads that
immediately and cannot name it, which is precisely what "looks off" means. **No amount of tone,
occlusion, rim lighting or mounting hardware can fix a projection mismatch** — which is exactly why
S8-20 corrected four real defects and moved the needle only slightly.

### The fix — measure the render, don't assume the grid

`measure_projection()` fits the hull's actual top-edge slopes from its alpha and feeds them to the
face builder, so the cradle is constructed in **the machine's own perspective**. ★ It re-measures
every run, so a re-rolled master carries its own geometry automatically — nothing to keep in sync.

★ **This is the same principle the file already stated for colour** and did not apply to shape: *the
brief describes what was ASKED for; the render is what EXISTS; the sprite must agree with the
render.* The palette note learned it in S8-16. Geometry took until S8-21.

⚠ **Guarded**: a degenerate or inverted fit falls back to true dimetric rather than shearing the box
into a mess.

### ✅ And it is flatter, which pays back the height

Following the hull's shallower left axis makes the cradle sit lower. The sprite is **148 px** —
against 157 as originally shipped and 154 after S8-20. ★ **The cradle now costs 3 px of height
instead of 12**, so most of what it took from S8-15's user-requested "shorter and bulkier" is back.

Accent 34.2% / 34.4%, floor OK, spread 1.83×. Suite 1307/1307.
