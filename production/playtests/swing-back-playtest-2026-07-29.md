# Swing-Back + Two-Pool Tempo Playtest — Tempo / Comeback / Investment-Cost Validation (S4-05)

> **Status**: TEMPLATE — awaiting session(s). Fill one row per game played, then complete the
> analysis + verdict blocks.
> **Story**: S4-05 (Sprint 4 — Vertical Slice Validation). Feeds the S4-06 REPORT + re-gate.
> **Revised 2026-08-08 for the AP→AP+Credits economy pivot** (ADR-0006): the swing-back / no-reversal
> gate is unchanged; added the **Two-Pool Tempo Tradeoff** validation (Analysis D). The pivot
> re-opened the core hypothesis, so S4-05 now validates *both* that decided games don't reverse
> *and* that "investment costs tempo" is a real, felt tradeoff.
> **Build**: current Vertical Slice with the two-pool economy + dual HUD counters — commit `aec78bb`
> (or later; record the exact commit below).
> **Run on**: a windowed Redot 26.2 build (`./redot` → the vertical slice). Art-independent —
> this is testable on the placeholder-diamond build **now**; it does not wait on S4-02 art.

---

## What this playtest is checking (and the design stance behind it)

OVERCLOCK **deliberately has no rubber-band / comeback mechanic.** Pillar 2 ("Tempo Is the
Skill") does not reward losing. Post-pivot (ADR-0006) the economy is **two budgets, not one**: a
**flat AP** tactical budget (refills each turn, unspent carries capped) and a **banked Credit** war
chest (income accumulates, never resets) that funds economy/production. It is the **Credit war
chest that compounds** whoever is ahead — banking more income → more investment → more income —
while AP stays flat; the **AP surcharge on economic actions is the intended brake** on that
snowball ("investment costs tempo"). So "swing-back" here does **not** mean "a losing player gets
bailed out." Post-pivot the playtest checks **four** things:

1. **Close / undecided games have a live swing.** In a game whose outcome is genuinely still in
   doubt, a skilled stabilization can still flip it — the "Zero Hour" white-knuckle beat that
   emerges from systems, not scripting (concept lines 105–108, 157–159). If close games feel
   *already over* long before they are, the tempo fantasy is muted.
2. **Decided games do NOT reverse.** Once a game is *actually decided* (one side has a
   compounding, barring-a-blunder-insurmountable lead), the systems must not hand the loser a
   reversal. **A decided game reversing is the one hard "must-not-happen"** — it means the
   economy (now: the Credit banking curve and/or the AP-surcharge brake) is accidentally
   rubber-banding, and triggers economy re-tuning (a PIVOT outcome for S4-06, not a KILL).
3. **Closeout does not drag.** When a game is decided, is finishing it a satisfying close or a
   tedious mop-up (chasing the last unit, grinding an HQ with no counterplay)? Long boring
   closeouts are a pacing problem even when the *outcome* is correct.
4. **"Investment costs tempo" is a real, felt tradeoff (NEW — the re-opened pivot hypothesis).**
   Spending Credits + the AP surcharge to grow your economy must *feel* like it costs tactical
   tempo this turn, and the hold-vs-cash-out banking decision must be live — not two disconnected
   currencies. Validated in **Analysis D**; a "the two pools don't interact / the surcharge is
   ignorable" result routes to economy re-tune (PIVOT), same weight as a dead swing.

### Operational definition — when is a game "DECIDED"?
Record the **turn number** at which you judged the outcome no longer in doubt. A working heuristic
(use judgement, note what drove it):
- The losing side can no longer contest the winner's HQ **and** cannot rebuild enough tempo
  (Credit war chest + board position — AP is a flat per-turn budget, *not* the compounding lever)
  to threaten it before losing their own; **or**
- A material + economy (banked Credits + income rate) gap so large that only a winner blunder
  changes the result.
If a game never reaches this point before someone wins, classify it **CLOSE** (undecided to the end).

---

## Session Info
- **Date(s)**: [date]
- **Build / commit**: [exact commit hash — the two-pool build, `aec78bb` or later]
- **Tester(s)**: [name/id — note if a naive/silent observer was involved]
- **Platform / input**: PC — [KB+M / Gamepad]
- **Total games played**: [n]  ·  **Close**: [n]  ·  **Decided**: [n]
- **How close games were engineered**: [the VS AI is "credible, not masterful" — note any
  self-handicap used to force genuinely close/undecided games, e.g. deliberately ceding early tempo]

---

## Per-Game Log (the core instrument — one row per game)

| # | Result (W/L) | Who led early | Turn it became DECIDED (or "never → close") | Class (Close/Decided) | Did it REVERSE after being decided? (Y/N) | Swing / Zero-Hour moment? (close games) | Closeout length (turns) | Closeout drag? (None/Mild/Bad) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |  |  |

> Add rows as needed. **The "Did it REVERSE?" column is the hard gate** — any `Y` on a game
> classified `Decided` is a blocking finding (see Verdict).

---

## Analysis A — Close / undecided games (is the swing alive?)
- **Did a genuine swing moment emerge** in the close games, or did they feel decided long before the end?
- **Could a stabilization flip a still-in-doubt game** through skilled play (AP tempo sequencing +
  Credit-timed reinvestment)? Give an example turn.
- **Zero-Hour feel**: was there a white-knuckle "this turn decides it" beat? [Yes / Weak / Absent]
- **Notes / representative game**: [describe one close game turn-by-turn if instructive]

## Analysis B — Decided games (the hard no-reversal check + closeout)
- **Did any decided game reverse?** [No / YES — list game #s]  ← **the one hard "must-not-happen"**
- **If a decided game reversed**: what mechanic handed the comeback (Credit banking swing?
  production/build tempo? AP surcharge too weak a brake? combat math?) — this points at the economy
  term to re-tune.
- **Closeout drag**: once decided, how did finishing feel? [None / Mild / Bad] — and why.
- **Notes**: [any near-reversals that self-corrected are worth recording too]

## Analysis C — Tempo readability (supporting)
- Could you **feel whether you were gaining or losing tempo** at a glance (Pillar 3), reading the
  **dual HUD counters** (AP tempo + Credit war chest, in distinct hues)? [Yes/Partly/No]
- Did **Credit banking / reinvestment** decisions feel like they **compounded** (the "momentum"
  arc)? (AP is a flat budget and does not compound — the war chest is the momentum lever.) [Yes/Partly/No]
- Did the two counters read as **two distinct budgets**, or did they blur into one? [Distinct/Blurred]

## Analysis D — Two-Pool Tempo Tradeoff (NEW — the re-opened pivot hypothesis)
The pivot's whole bet is that **macro (economy) and micro (tactics) stay entangled** through the AP
surcharge, so investing in your economy *costs tactical tempo this turn*. Validate that it lands:
- **Does spending on economy FEEL like a tempo cost?** When you built/produced (Credits + the AP
  surcharge), did you feel the tactical-tempo dip that same turn, or was the surcharge negligible?
  [Real cost / Noticeable / Ignorable]
- **Is the hold-vs-cash-out banking decision alive?** Did you ever deliberately *hold* Credits to
  bank toward a bigger spike vs. cash out now — and did that choice feel meaningful? [Yes/Weak/No]
- **Does the AP surcharge brake the economic snowball?** Did the surcharge meaningfully slow a
  runaway economy, or could you out-bank the opponent with the tactical cost barely registering?
  [Brakes it / Partial / Ignorable]
- **Do the two pools read as ONE entangled economy, or two disconnected currencies?** The pivot
  fails if they feel like unrelated resources. [Entangled / Disconnected]
- **Representative moment**: [describe one turn where the Credits-vs-AP tradeoff drove your decision]

> **Routing**: an "Ignorable surcharge / Disconnected currencies / dead banking decision" result is
> a pivot-validation failure → economy re-tune (`ap-economy` tuning story), same PIVOT weight as a
> dead swing. A strong result *confirms* the two-budget split and closes the re-opened hypothesis.

---

## Findings → categorized (fill after playing)

- **Design changes needed**: [swing muted in close games / decided games feel over too early / two
  pools feel disconnected / banking decision dead / etc.]
- **Balance adjustments**: [the pivot knobs — Credit income curve (base_income, outpost tiers), the
  AP surcharges (produce/build/research), AP carryover cap, build/produce Credit costs — plus combat
  values; the levers a decided-game reversal, a muted swing, or an ignorable surcharge point at]
- **Bug reports**: [reproducible defects seen during play]
- **Polish items**: [friction/feel, non-blocking]

Routing (per `/playtest-report`): design → `/propagate-design-change`; balance → `/balance-check
ap-economy` (+ combat-resolution / base-production as implicated); bugs → `/bug-report`.

---

## Verdict (feeds S4-06 REPORT + re-gate)

Pick one, with the evidence above:

- **PASS / PROCEED** — close games have a live swing, **no decided game reversed**, closeout is
  acceptable, **and the two-pool tempo tradeoff lands** (Analysis D: the surcharge is a felt cost,
  banking is a live decision, the pools read as one entangled economy). Tempo fantasy holds; the
  gate's swing-back concern is cleared and the re-opened two-budget hypothesis is confirmed.
- **CONCERNS** — swings present but muted, or closeout drags, or a near-reversal worried you, or the
  tempo tradeoff is present but weak (surcharge only "noticeable", banking decision "weak").
  Proceed with a named tuning follow-up, not a block.
- **PIVOT (economy re-tune)** — **a decided game reversed** (rubber-band artifact) OR close games
  feel decided-before-they-are (dead swing) OR **the two-pool tempo tradeoff does not land**
  (ignorable surcharge / disconnected currencies / dead banking decision). Not a KILL — spawns a
  focused `ap-economy` / `base-production` tuning story, then re-gate.

**Definition of Done check:**
- [ ] ≥1 session documented (DoD floor)
- [ ] ≥3 close **and** ≥3 decided games logged (preferred target)
- [ ] Closeout-drag observation captured
- [ ] The "no decided game reverses" hard criterion explicitly answered (Analysis B)
- [ ] The Two-Pool Tempo Tradeoff explicitly answered (Analysis D — the pivot's re-opened hypothesis)

**Verdict**: [PASS / CONCERNS / PIVOT]  ·  **One-line rationale**: [ ]
