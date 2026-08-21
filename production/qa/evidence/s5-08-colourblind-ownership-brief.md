# S5-08 — Colourblind Ownership: Decision Brief

> **Story**: S5-08 (Sprint 5, Should Have) · **Status**: prepared 2026-08-20, **awaiting the user's
> design-direction call**
> **Decides**: build §5.2-style non-hue ownership markers, or accept hue-carried ownership with a
> recorded rationale in the art bible.
> **Measured on**: the shipped runtime art in `assets/art/` at commit `a2b443f`. Reproduce with the
> method in the Appendix.

---

## Summary — the sprint's framing was backwards, and there is a real defect

The sprint plan carries this as *"Δ34/255 (13%) — readable on structures, marginal on units."*
Measurement says the opposite on both halves:

- **Units are the strong case, not the marginal one.** They carry faction colour on **26–82%** of
  their silhouette and separate at **ΔE 60–76** under deuteranopia.
- **Structures are the weak case.** They carry it on **5–22%**, and the Defensive Structure's
  whole-silhouette difference is **ΔE 2.3 with completely normal colour vision** — i.e. a Rush and a
  Boom Defensive Structure look nearly the same to *everyone*, colourblind or not.

That last point is the finding that matters most, and it is **not an accessibility issue** — it is
an ownership-legibility defect that happens to have surfaced during accessibility work.

Separately: **the art bible's stated non-hue backup does not exist in the shipped art.** §5.2's Mass
Distribution Bias (Rush forward-light / Boom rear-loaded) is declared LOCKED and is cited by
`accessibility-requirements.md` as the reason faction identity is marked **Resolved**. All **26**
Rush/Boom sprite pairs are **pixel-identical in silhouette** — the factions are pure hue swaps. The
backup was never built.

**But the outcome is better than that sounds.** The hue pair chosen in S4-01 turns out to be close
to ideal for dichromats on its own, so the project's Standard-tier commitment is *actually met* for
the three colourblind modes it names. What is wrong is the **stated mechanism**, not the result.

---

## Measurement 1 — ownership survives real colourblindness, and fails only under full desaturation

Mean CIELAB ΔE between the Rush and Boom versions of the same sprite, over the **accent pixels**
(the pixels that actually carry faction colour). Rule of thumb: ΔE < 2 is "the same colour",
ΔE ~10 is "clearly different", ΔE > 40 is "unmistakably different".

| Sprite | accent coverage | normal | deuteranopia | protanopia | tritanopia | full grayscale |
|---|---:|---:|---:|---:|---:|---:|
| Scout | 61.0% | 69.1 | 60.5 | — | — | 5.2 |
| Trooper | 54.4% | 82.4 | 76.0 | — | — | 5.8 |
| Heavy | 82.1% | 80.3 | 72.4 | — | — | 7.2 |
| Sniper | 26.3% | 63.2 | 62.8 | — | — | 4.1 |
| HQ | 21.8% | 73.8 | 69.6 | — | — | 7.1 |
| Economy Outpost | 15.0% | 63.3 | 53.5 | — | — | 7.7 |
| Research Lab | 11.1% | 71.8 | 54.5 | — | — | 4.7 |
| Production Outpost | 8.2% | 77.7 | 71.8 | — | — | 7.2 |
| **Defensive Structure** | **5.2%** | 42.9 | 34.8 | — | — | 5.2 |

Whole-silhouette figures (what the eye integrates at board distance) across all four vision models:

| Sprite | normal | deuteranopia | protanopia | tritanopia | grayscale |
|---|---:|---:|---:|---:|---:|
| Scout | 42.4 | 37.1 | 27.7 | 80.8 | 3.2 |
| Trooper | 45.1 | 41.6 | 31.6 | 73.4 | 3.2 |
| Heavy | 66.1 | 59.5 | 45.1 | 111.1 | 5.9 |
| Sniper | 16.8 | 16.6 | 13.0 | 30.6 | 1.1 |
| HQ | 16.2 | 15.2 | 11.8 | 28.0 | 1.6 |
| Economy Outpost | 9.5 | 8.1 | 6.0 | 20.5 | 1.2 |
| Research Lab | 8.0 | 6.1 | 4.3 | 14.8 | 0.5 |
| Production Outpost | 6.4 | 5.9 | 4.5 | 11.0 | 0.6 |
| **Defensive Structure** | **2.3** | **1.9** | **1.4** | 5.8 | 0.3 |

**Reading it:**

1. **Rush orange `#FF5A2E` vs Boom cyan `#22C7F0` is a near-ideal dichromat pair.** It sits on the
   blue-versus-yellow axis, which is exactly the axis red-green colourblind people *retain*.
   Protanopia is the hardest of the three and units still clear ΔE 27–45. The S4-01 hue lock chose
   very well — apparently by luck, since the lock's stated justification was contrast against the
   stage tiles, not dichromat separation.
2. **Tritanopia is not a problem** — it is the mode where this pair separates *best* (up to 111).
3. **Full desaturation destroys ownership completely** — ΔE 4–8 in-accent, 0.3–5.9 whole-sprite.
   Nothing survives. This is monochromacy/achromatopsia, roughly **1 in 30,000**, against roughly
   **1 in 12 men** for red-green deficiency. It is also the case the grayscale-broadcast/streaming
   scenario in §4.4 cares about.
4. **The failure is coverage, not colour.** Where the accent exists, the separation is strong
   everywhere (ΔE 35–76 deuteranopia, worst case). Structures simply have too little of it.

---

## Measurement 2 — the declared non-hue backup is not in the shipped art

All **26** Rush/Boom sprite pairs (units × 4 archetypes × 2 facings × idle/destroyed, plus 5
structures) have **byte-identical alpha channels**. Faction variants were produced by the S4-02
`recolor` tool from one base render per entity, so the silhouettes cannot differ.

This contradicts three places in the corpus that currently assert otherwise:

| Document | What it claims | Reality |
|---|---|---|
| `art-bible.md` §5.2 / §1 P2 | Mass Distribution Bias is the "mandatory non-hue backup", "survives colorblind vision and full desaturation" | Not implemented; silhouettes identical |
| `art-bible.md` §8.7 | "faction units are **distinct art, not palette-swaps** — 3 faction silhouettes × 4 roles" | They are exactly palette-swaps |
| `accessibility-requirements.md` Color-as-Only-Indicator Audit | Faction identity row: backup = "Distinct per-faction silhouette (§5.2, LOCKED)" → **Resolved** | The cited backup does not exist |

`accessibility-requirements.md` already schedules the check that catches this — *"Color-as-only-
indicator re-audit: implementation matches the 'Resolved' status claimed at design time — flag any
drift. Not Started — scheduled once UI implementation exists."* The UI now exists; **this brief is
that re-audit**, and the drift is real.

**How much this actually costs us.** The project targets **Standard** accessibility tier, whose
colourblind requirement names Protanopia / Deuteranopia / Tritanopia specifically. Measurement 1
shows faction ownership **passes all three**. So the commitment is met — just not for the reason the
documents give. The exposure is (a) the docs are wrong about their own mechanism, (b) there is no
redundancy if the hue channel is ever degraded, and (c) the **Neutral-vs-Neutral mirror match** has
no ownership signal whatsoever — though that is Full Vision scope, since the slice pins Rush vs Boom.

---

## The options

### Option A — Accept hue-carried ownership; correct the documents
Record the rationale in the art bible: ownership is carried by hue, **measured** to pass all three
dichromacies; Mass Distribution Bias is re-scoped from "LOCKED and shipped" to a Full Vision
commitment; monochromacy is explicitly out of scope for the Vertical Slice. Fix the
`accessibility-requirements.md` audit row to cite the real mechanism.

- **Cost**: ~0.25 day, documentation only. No art, no palette change.
- **For**: the measurements genuinely support it for ~99.99% of colour-vision-deficient players. It
  respects the sprint's own design freeze. It replaces a false claim with a true, evidenced one.
- **Against**: edits a rule adjacent to a stated Pillar (§1 P2), which is a design-identity change,
  not a technical one. Leaves the Defensive Structure defect unfixed. Leaves zero redundancy.

### Option B — Build the non-hue marker across the whole roster
Honour §1 P2 as written: a per-faction trim pattern or emblem on all 9 entity types.

- **Cost**: ~1.5–2 days. 9 entities × 3 hues × facings × states, plus glow-mask regeneration, spec
  and manifest updates. Realistically an approval loop, not a production task (retro action 4).
- **For**: makes every document true as written; fixes monochromacy, the Neutral mirror, *and*
  structures in one pass.
- **Against**: the largest art scope of the four, landing directly in front of a gate that has
  already rolled over twice. Fights §4.6's neon budget and §3.5's detail restraint — a marker big
  enough to read on a 5%-coverage structure is a marker big enough to compete with the units for the
  eye.

### Option C — Non-hue marker on structures only
Units measure strongest (26–82% coverage, ΔE 60–76 deuteranopia) and need nothing. Give the **five
structures** a shape-level ownership tell — a silhouette notch, mast or pennant differing per
faction — and leave units on hue.

- **Cost**: ~0.75–1 day. Five entities, no facings (structures never turn), idle + destroyed.
- **For**: targeted precisely at the measured failure. Satisfies §1 P2 where it actually bites.
  Structure silhouettes are simple, so a shape tell is easier to land there than on a unit.
- **Against**: a split rule (units hue-only, structures shape+hue) needs its own stated rationale or
  it reads as inconsistency. Still real art work under the freeze. Does not fix units under
  monochromacy.

### Option D — Raise structure accent coverage; take Option A for the rest ★ recommended
Treat the Defensive Structure result as what it is — an **ownership bug affecting all players** —
and fix it with the tool that already exists. Widen the recolour mask on the five structures so
faction accent covers a unit-like share of the silhouette (target ~20–25%, where the HQ already
sits and reads correctly). Then take Option A's documentation correction for the accessibility
scope.

- **Cost**: ~0.5 day. The `recolor` tool and per-entity masks already ship from S4-02; this is a
  mask edit and a re-run, not new art. No new visual vocabulary, no palette-lock risk.
- **For**: fixes the only defect the measurements actually found, and fixes it for everybody rather
  than for a 1-in-30,000 minority. Cheapest correct action. Keeps the freeze essentially intact.
- **Against**: does not deliver a non-hue channel at all — monochromacy and the Neutral mirror stay
  unsolved and become Full Vision debt. Pushes more neon onto structures, which §4.6's neon budget
  and §2.1's dark-stage identity deliberately restrain; needs a check that structures do not start
  out-competing units for attention (§3.5 hierarchy).

---

## Recommendation

**D**, with **A**'s documentation correction folded in, and **C** logged as post-gate debt.

The reasoning: only one thing here is actually broken for real players today, and it is not a
colourblind problem — it is that two of the five structures barely declare their owner to anyone at
all. That deserves the cheap, immediate fix. The accessibility commitment the project actually made
is already met and merely mis-explained, so the honest move is to correct the explanation rather
than build art to justify a sentence. And the genuine remaining gap — no redundancy if hue is lost,
plus the Neutral mirror — is Full Vision scope by the art bible's own reckoning, so it belongs on
the post-gate backlog where the sprint's freeze rule says new design work goes.

**This is a design-direction call and is the user's to make.** The measurements are the input; the
choice about what OVERCLOCK promises about non-hue identity is not a technical one.

---

## Appendix — how to reproduce

Dichromacy simulated with the standard Viénot–Brettel–Mollon LMS projection; difference reported as
mean CIELAB ΔE76 per pixel. "Accent pixels" are those the recolour actually changed (linear RGB
distance > 8 between the Rush and Boom versions), which isolates the faction-carrying region from
the shared matte plating. Silhouette identity is a byte comparison of the alpha channels.

Note the runtime adds the §8.9 glow on top of this base art, which pushes additional faction hue
onto the trim rim — so the *rendered* separation is somewhat better than these figures. It does not
change the conclusions: the glow is hue-only, its masks are hue-agnostic and shared between
factions, and Story 007 measured its luminance contribution at ~+0.003, so it adds nothing under
desaturation and no shape information in any mode.
