# S8-14 / S8-15 / S8-16 — Builder art evidence

**Captured**: 2026-08-26 · **By**: `/qa-plan sprint` (QA plan Finding 2)
**Status**: ✅ Base look **approved** by the user 2026-08-26 ("it looks good") · ✅ accent defect fixed (S8-19) · ✅ cradle re-seated on user feedback (S8-20).

## Sheets

| File | Shows |
|---|---|
| `01-builder-idle-all-hues.png` | Idle · 3 hues × 2 facings · shipped 140×145 on 128×64 tiles |
| `02-builder-destroyed.png` | Destroyed state · 3 hues × 2 facings |
| ★ `03-builder-vs-roster.png` | Silhouette check — Builder vs the full rush roster |
| ★★ `04-crate-removed.png` | **S8-22 — with/without the cargo crate. The crate is gone; this is what ships** |

⚠ **These composite the SHIPPED runtime PNGs at shipped size onto the stage colour.**
They deliberately **do not** use `board_preview.py`, which re-runs `cutout(pockets=True)` on its
input and can show artifacts absent from the master — S8-15 nearly chased a non-existent shadow
slab that way. Sheet = what the game draws.

## Status

✅ **Base look approved** by the user 2026-08-26 — *"it looks good"*.
✅ **Accent defect fixed** (S8-19) — 22.8% → 34.7%, clearing the ownership floor.
✅ **Cargo crate removed** (S8-22) after four rounds — the user's call.

---

## ⛔⛔ The cargo crate: four rounds, and why it was dropped

**Rounds 7–8 — generation.** Failed *structurally*, not by luck. Prompt weight is finite, so
describing the cradle strongly enough to appear stole weight from the clauses holding the body
together; every promising candidate undid the fixes of rounds 1–6.

**Round 9 (S8-16) — drawn and composited.** Shipped. ⛔ *"The crate on the back looks a bit tacked on."*

**Round 10 (S8-20) — four real defects fixed, symptom unchanged.** The cradle's lit face measured
**150 against a hull median of 114**; INK traced the whole box including edges buried in the hull; the
rim was flat so it read as a decal; and the contact shadow was a **rectangle** under a **rhombus**
footprint. Every one was genuine, and it still looked off.
★★ **That is the lesson worth keeping: when fixing several real problems does not move the symptom,
the diagnosis is incomplete — not the execution.** I should have concluded that before round 10, not
after it.

**Round 11 (S8-21) — the actual cause.** Measured off the master's own silhouette:

| Hull top edge | Measured | True 2:1 dimetric | Off by |
|---|---:|---:|---:|
| **left** | **−0.179** | −0.500 | ⛔ **64%** |
| right | +0.305 | +0.500 | 39% |

⇒ **The machine is not in the projection it looks like it is in.** SDXL painted a *plausible*
three-quarter view, not a correct dimetric one, and it is **asymmetric**. Every drawn cradle was a
perfect symmetric rhombus, so **the crate was in one projection and the machine in another** — which
the eye catches instantly and cannot name. Matching the measured slopes helped visibly and *still*
was not right.

### ✅ Why removing it was the right call

★ **The silhouette was always doing the work.** Rounds 1–6 produced a hunched, back-heavy machine
that reads as a carrier and not a soldier **with no cargo box on it at all**. The cradle was solving
a problem the body had already solved.

**Removal reversed every cost it had imposed:**

| | With crate | Without |
|---|---:|---:|
| Sprite height | 157 px | ✅ **145 px** — all of S8-15's "shorter" restored |
| Accent coverage | 33.9% | ✅ 34.7% |
| Tooling | `draw_cargo_cradle.py` | ✅ deleted |

⚠ **If a cradle is ever wanted again, do NOT composite one.** Re-roll the body with the bed built
into the render, so there is no projection to mismatch. Full post-mortem in `generation-prompts.md`.

---

## ✅ What the sheets confirm

- **Builder ≠ Scout.** Both four-legged and not confusable: the Builder is hunched, grey-dominant
  and body-heavy; the Scout is taller, orange-dominant and angular. ★ The **silhouette** does this,
  not the 140 px vs 148 px width.
- **Ownership reads** at 34.7% / 34.9% — above the 30% floor, and still the roster's least-coloured
  unit, which is what the brief wants for a support machine.
- **Neutral is achromatic** (0.0%), correct per art-bible §4.2 — neutral means *unowned*.
