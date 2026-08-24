# S5-03 — Iso-Legibility Gate (Pillar 3)

> **Ran**: 2026-08-24 · **Build**: `design/initial-gdd-corpus` @ S6-11 · Redot 26.2, Forward+, 1280×720
> **Harness**: `tools/CaptureLegibility.tscn` → `production/qa/evidence/s5-03-legibility/` (5 frames)
> **Measurements**: `tools/analyse_legibility.py`
> **Status**: ⚠️ **CONDITIONAL PASS** — one blocking defect found, **and fixed the same day**
> (§1a). Still owes the naive-observer session.
> **Owed**: the naive/silent-observer session. No script can supply that half; see §6.

---

## Verdict

**The board is readable. One unit is not.**

Four of the five things this gate tests pass, several of them comfortably. The fifth fails
concretely, systemically, and in a way that is cheap to fix: **the Sniper does not carry faction
ownership.** It is not a matter of degree — a Rush Sniper and a Boom Sniper are measurably almost
the same object.

This is a *unit-art* defect, not a board defect. The map, the stage contrast, the silhouette
system, the depth handling and the act-state read all hold up under deliberate stress.

---

## 1. ★★ BLOCKING — the Sniper does not read as owned

Ownership in this game is carried by hue (S5-08 measured and accepted this). Hue can only be
carried by pixels that are actually saturated — and the Sniper has almost none.

| Archetype | Body pixels carrying faction hue | Faction separation (ΔE76) | Under full desaturation |
|---|---:|---:|---|
| Heavy | **62.4 %** | 61.8 | Δ 23.3/255 — marginal |
| Scout | 45.4 % | 41.6 | Δ 13.6/255 — marginal |
| Trooper | 42.5 % | 46.1 | Δ 14.5/255 — marginal |
| **Sniper** | ⛔ **13.3 %** | ⛔ **12.9** | ⛔ **Δ 2.7/255 — indistinguishable** |

**A 4.7× spread in ownership signal across the roster**, and the Sniper sits at roughly one fifth
of the Heavy. Its faction separation (ΔE 12.9) is *below* the threshold at which two colours are
reliably told apart, before any consideration of distance, colourblindness or crowding.

**It is systemic, not one bad sprite.** Every Sniper variant and both facings measure the same:

```
sniper_rush_e 13.7%   sniper_rush_w 13.7%
sniper_boom_e 12.8%   sniper_boom_w 12.8%
sniper_neutral_e 0.5% sniper_neutral_w 0.5%
sniper mean 9.0%   ·   every other unit, mean 50.1%
```

It is visible in three of the five captured frames without measuring anything — in
`05-mirror-pairs.png` the two enemy Snipers are the only pair a viewer cannot tell apart, and in
`04-diagonal-stack.png` the Sniper is the one unit in an alternating orange/cyan column that breaks
the alternation.

### Why this matters more than it looks

The Sniper is the longest-ranged unit in the game. It is the one the player most needs to identify
*at distance and without selecting it*, because its threat range is what constrains where everything
else can safely stand. It is the worst unit in the roster to have as the least identifiable.

### ★ The fix is small and is art, not code

Raise the Sniper's saturated coverage toward the roster's ~42–50 % band. It does not need
redesigning — its silhouette is the **most** distinct in the roster (§3) and should not be touched.
It needs hue applied to more of the chassis it already has.

---

## 1a. ✅ FIXED — 2026-08-24, same day

New pipeline stage `tools/asset-pipeline/promote_accent.py`, run on the rush master, then
re-derived through the existing chain (recolour → facings → place_runtime → glow/destroyed
variants), so all six Sniper sprites and both derived faction sets stay in sync.

| Measure | Before | After | Roster comparison |
|---|---:|---:|---|
| Hue coverage | 13.3 % | **43.5 %** | Trooper 42.5 %, Scout 45.4 % |
| Faction ΔE76 *(accent mask, both factions)* | 12.9 | **66.5** | Scout 81, Heavy 90, Trooper 97 |
| Coverage spread across roster | **4.7×** | **1.5×** | — |

The Sniper now sits with the Trooper — which is the correct target, since the art bible names the
Trooper as the roster's baseline control.

### ★★ How it was fixed matters, because two obvious approaches produce unusable art

Both of these hit the coverage number exactly and both had to be thrown away:

| Approach | Coverage | Result |
|---|---|---|
| Promote the brightest *N* plate pixels | ✅ exact | ⛔ A global value threshold cuts **across** panels, taking the lit half of many and leaving the shadowed half — reads as orange **speckle** on grey armour |
| Value-banded connected components | ✅ exact | ⛔ Quantising value before labelling splits smoothly-shaded panels into **stripes**; promoting some and not others gives a corduroy artefact |
| **Grow the existing accent outward** | ✅ exact | ✅ Reads as a bolder version of the same design |

**Growth works because it does not invent a composition.** The artist already decided *where* this
unit's accent belongs; dilation only decides *how far* it extends. It also cannot speckle — every
added pixel is adjacent to accent already there.

The grown tone (saturation 0.72, value band 0.42–0.86) was chosen by rendering muted / mid / vivid
candidates **at the real shipping size of 99×156 on the real stage colour** and comparing. At master
resolution all three look fine; at board scale the vivid option starts flattening the unit into a
single orange mass and loses the grey structural contrast that gives the silhouette its form.

### What was deliberately NOT chased

Test 4's grayscale/desaturation measure still reports the Sniper at Δ 11.4 against a 13 threshold.
**That is not a Sniper problem.** The whole roster sits in an 11–23 band on that axis:

```
sniper 11.4  ·  scout 13.6  ·  trooper 14.5  ·  heavy 23.3
```

This is the roster-wide non-hue-ownership gap S5-08 measured and the project consciously deferred —
the art bible's mandated non-hue marker is not in the shipped art for *any* unit. Pushing the Sniper
past its peers would be over-fitting one unit to a test none of them pass. It is logged as the
existing S5-08 item, not as a Sniper defect.

Suite 1089/1089, slice boots clean, frames re-captured.

---

## 2. ★ The finding that should shape UI work: units read by ACCENT, not by MASS

Measured in the real frames, reproducing S4-01's own method (validated — the script reproduces
S4-01's locked 5.19:1 figure exactly):

| Frame | Neon accent vs stage | Whole unit vs stage |
|---|---:|---:|
| 01 dense, all actionable | **7.17 : 1** | 2.43 : 1 |
| 02 dense, mixed act-state | 5.98 : 1 | 1.94 : 1 |
| 03 dense, all spent | **4.26 : 1** *(worst)* | 1.80 : 1 |
| 04 diagonal stack | 6.46 : 1 | 2.46 : 1 |
| 05 mirror pairs | 6.66 : 1 | 2.34 : 1 |

*(WCAG AA large-text bar: 3.0 : 1.)*

**The neon accents clear the bar everywhere, including the dimmest state the board ever reaches.
The unit bodies never clear it at all.** Units are dark chassis that read almost as stage, plus a
neon accent that does 100 % of the legibility work.

That is a legitimate art direction and it is working — but it has a consequence worth making
explicit, because it governs every future unit:

> **An archetype's accent coverage *is* its legibility. Coverage is the budget, not hue choice.**

This is exactly why the Sniper fails while the Heavy is unmistakable: they use the same palette. One
spends 62 % of its body on it, the other 13 %. **Any new unit — every wave-2 vehicle and aircraft —
should be checked against this number before it is authored, not after.**

---

## 3. ✅ PASS — silhouettes are distinct by outline alone

The art bible's Principle 1 test, run on alpha masks with colour removed entirely.

| Pair | IoU (shape overlap) |
|---|---:|
| scout / sniper | 0.298 |
| heavy / sniper | 0.325 |
| trooper / sniper | 0.335 |
| scout / trooper | 0.401 |
| scout / heavy | 0.434 |
| **trooper / heavy** | **0.437** *(closest)* |

Identical shapes score 1.000. The closest pair is Trooper/Heavy at 0.437 — **which is the design
intent**, not a defect: the bible specifies the Heavy as *"Trooper scaled up and widened — same DNA,
more mass."* The system is behaving as written.

The bible's stated primary read also holds: Scout aspect 0.99 (low, horizontal) vs Sniper 0.63
(tall, narrow) — a **1.57× separation**, distinguishable at blob-on-a-tile scale.

> ⚠️ **Method note worth keeping.** A first pass scale-normalised every silhouette to a square before
> comparing, and reported Heavy/Sniper as the *most confusable* pair — the opposite of the truth.
> Normalising away aspect ratio destroyed the exact cue the art bible says does the work. The
> corrected, aspect-preserving figures are the ones above.

---

## 4. ✅ PASS — depth stacking is not currently a problem

The art bible's Principle 3 anticipates isometric overlap breaking flat-colour legibility. Measured
against a deliberately hostile arrangement — six units on a single iso diagonal, alternating faction
(`04-diagonal-stack.png`) — **it does not currently occur.** At the shipping tile pitch and sprite
scale, a diagonal projects to a cleanly separated vertical column with negligible occlusion.

The dense mid-board cluster (`01`) does show partial overlap between adjacent units, and it remains
readable, but it is the arrangement to re-test when sprites get larger. **Air units will change this
answer** — a unit rendered off its ground contact point is precisely the case this test could not
cover, because they do not exist yet.

---

## 5. ✅ PASS — act-state survives crowding

Measured on the dense board rather than an isolated pair, which is the arrangement that actually
tests it:

- **1.58 : 1** luminance ratio between actionable and spent
- **4.26 %** of the frame changes visibly between the two states
- Reinforced by the has-acted glyph and body tint (the deliberate triple-encoding recorded in
  `design/legibility-budget.md`)

Worth noting for the budget: at all-spent the accent contrast drops to its floor of 4.26:1 and still
clears the 3.0:1 bar. **The triple-encoded act-state is doing real work, not just redundancy** — the
brightness channel alone is a 1.58× difference, which would be thin on its own.

---

## 6. ⛔ Still owed — the naive-observer session

S5-03's acceptance criteria require **"≥1 documented naive/silent-observer session."** Everything
above is measurement. Measurement can prove two colours are separable; it cannot prove a person
knows what they are looking at.

**Three questions only a human can answer, and each is quick:**

| Question | Why it needs a person |
|---|---|
| Within 2 minutes and unprompted, can a first-time viewer say **which units are theirs**? | ΔE says the colours differ. It does not say the mapping "orange = me" was ever communicated |
| Can they tell **which units they have already moved**? | 1.58:1 is a real difference; whether it reads as *"used"* rather than *"further away"* is interpretation |
| Do they read the structures as **buildings** rather than large units? | Measured silhouette separation is fine. Category confusion is a semantic failure, not an optical one |

---

## 7. Recommended changes, in priority order

| # | Change | Scope | Why now |
|---|---|---|---|
| **1** | ✅ **DONE — Sniper hue coverage 13.3 % → 43.5 %** | `promote_accent.py` + the existing derive chain. Silhouette untouched | The only blocking defect. Fixed same day; see §1a |
| **2** | Add an **accent-coverage check** to the asset pipeline | Tooling — `analyse_legibility.py` already computes it | This defect shipped and survived a full art sprint because nothing measured it. Every wave-2 unit will have the same failure mode available |
| **3** | ✅ **DONE — neutral re-derived** from the corrected master in the same pass | Was 0.5 % coverage | Neutral is the vertical slice's default faction |
| **4** | Book the **naive-observer session** | ~20 minutes, one person who has not seen the game | The gate is not formally passed without it, and it is the only part that cannot be automated |
| **5** | Re-run this harness after any unit-art change | `./redot tools/CaptureLegibility.tscn && python3 tools/analyse_legibility.py` | It is now a repeatable measurement, not a one-off |

**No map or terrain changes are recommended.** The stage, tile contrast, cover tiles and depth
handling all measured sound. The map is not where the problem is.

---

## 8. What this does to the legibility budget

`design/legibility-budget.md` capped always-on facts at **5** and flagged three unknowns it could
not resolve. Two are now answered:

| Unknown | Answer |
|---|---|
| Are the current five facts readable at a glance? | **Yes, with one exception that is a unit-art defect rather than a channel-count problem.** The cap of 5 stands |
| Is act-state's triple coding necessary or over-served? | **Necessary.** Brightness alone is 1.58:1. The budget's plan to fund crew state out of that redundancy should be treated as *provisional* — there is less slack than assumed |
| Does hue-carried ownership survive at playing distance? | **Partially answered.** It survives on 3 of 4 archetypes and fails on the fourth — and the cause is coverage, not hue choice. Still owes the human session |

★ **The budget's biggest assumption needs revising.** It proposed funding crew state from the
act-state redundancy. That redundancy is thinner than it looked: strip a channel and act-state falls
to a 1.58:1 brightness difference. **Crew state should be treated as needing new budget, not
recycled budget** — or it should go on-demand.

---

## Reproducing

```bash
./redot tools/CaptureLegibility.tscn      # needs a display; writes 5 frames
python3 tools/analyse_legibility.py       # all six measurements
```

Raw output archived at `production/qa/evidence/s5-03-legibility/measurements.txt`.
