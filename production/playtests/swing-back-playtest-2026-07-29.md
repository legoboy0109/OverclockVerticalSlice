# Swing-Back Playtest — Tempo / Comeback Validation (S4-05)

> **Status**: TEMPLATE — awaiting session(s). Fill one row per game played, then complete the
> analysis + verdict blocks.
> **Story**: S4-05 (Sprint 4 — Vertical Slice Validation). Feeds the S4-06 REPORT + re-gate.
> **Build**: current Vertical Slice — commit `20ed9be` (or later; record the exact commit below).
> **Run on**: a windowed Redot 26.2 build (`./redot` → the vertical slice). Art-independent —
> this is testable on the placeholder-diamond build **now**; it does not wait on S4-02 art.

---

## What this playtest is checking (and the design stance behind it)

OVERCLOCK **deliberately has no rubber-band / comeback mechanic.** Pillar 2 ("Tempo Is the
Skill") does not reward losing; the unified AP economy *compounds* whoever is ahead
(`design/gdd/game-concept.md` Core Fantasy). So "swing-back" here does **not** mean "a losing
player gets bailed out." It means two distinct things must both be true:

1. **Close / undecided games have a live swing.** In a game whose outcome is genuinely still in
   doubt, a skilled stabilization can still flip it — the "Zero Hour" white-knuckle beat that
   emerges from systems, not scripting (concept lines 105–108, 157–159). If close games feel
   *already over* long before they are, the tempo fantasy is muted.
2. **Decided games do NOT reverse.** Once a game is *actually decided* (one side has a
   compounding, barring-a-blunder-insurmountable lead), the systems must not hand the loser a
   reversal. **A decided game reversing is the one hard "must-not-happen"** — it means the
   economy is accidentally rubber-banding, and triggers economy re-tuning (a PIVOT outcome for
   S4-06, not a KILL).

Plus a pacing check:

3. **Closeout does not drag.** When a game is decided, is finishing it a satisfying close or a
   tedious mop-up (chasing the last unit, grinding an HQ with no counterplay)? Long boring
   closeouts are a pacing problem even when the *outcome* is correct.

### Operational definition — when is a game "DECIDED"?
Record the **turn number** at which you judged the outcome no longer in doubt. A working heuristic
(use judgement, note what drove it):
- The losing side can no longer contest the winner's HQ **and** cannot rebuild enough tempo
  (AP income + board position) to threaten it before losing their own; **or**
- A material + economy gap so large that only a winner blunder changes the result.
If a game never reaches this point before someone wins, classify it **CLOSE** (undecided to the end).

---

## Session Info
- **Date(s)**: [date]
- **Build / commit**: [exact commit hash]
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
- **Could a stabilization flip a still-in-doubt game** through skilled AP sequencing? Give an example turn.
- **Zero-Hour feel**: was there a white-knuckle "this turn decides it" beat? [Yes / Weak / Absent]
- **Notes / representative game**: [describe one close game turn-by-turn if instructive]

## Analysis B — Decided games (the hard no-reversal check + closeout)
- **Did any decided game reverse?** [No / YES — list game #s]  ← **the one hard "must-not-happen"**
- **If a decided game reversed**: what mechanic handed the comeback (AP income swing? production
  tempo? combat math?) — this points at the economy term to re-tune.
- **Closeout drag**: once decided, how did finishing feel? [None / Mild / Bad] — and why.
- **Notes**: [any near-reversals that self-corrected are worth recording too]

## Analysis C — Tempo readability (supporting)
- Could you **feel whether you were gaining or losing tempo** at a glance (Pillar 3)? [Yes/Partly/No]
- Did AP allocation decisions feel like they **compounded** (the "momentum" arc)? [Yes/Partly/No]

---

## Findings → categorized (fill after playing)

- **Design changes needed**: [swing muted in close games / decided games feel over too early / etc.]
- **Balance adjustments**: [AP income, production cost/tempo, combat values that drive over- or
  under-swinging — the levers a decided-game reversal or a muted swing would point at]
- **Bug reports**: [reproducible defects seen during play]
- **Polish items**: [friction/feel, non-blocking]

Routing (per `/playtest-report`): design → `/propagate-design-change`; balance → `/balance-check
ap-economy` (+ combat-resolution / base-production as implicated); bugs → `/bug-report`.

---

## Verdict (feeds S4-06 REPORT + re-gate)

Pick one, with the evidence above:

- **PASS / PROCEED** — close games have a live swing, **no decided game reversed**, closeout is
  acceptable. Tempo fantasy holds; the gate's swing-back concern is cleared.
- **CONCERNS** — swings present but muted, or closeout drags, or a near-reversal worried you.
  Proceed with a named tuning follow-up, not a block.
- **PIVOT (economy re-tune)** — **a decided game reversed** (rubber-band artifact) OR close games
  feel decided-before-they-are (dead swing). Not a KILL — spawns a focused
  `ap-economy` / `base-production` tuning story, then re-gate.

**Definition of Done check:**
- [ ] ≥1 session documented (DoD floor)
- [ ] ≥3 close **and** ≥3 decided games logged (preferred target)
- [ ] Closeout-drag observation captured
- [ ] The "no decided game reverses" hard criterion explicitly answered (Analysis B)

**Verdict**: [PASS / CONCERNS / PIVOT]  ·  **One-line rationale**: [ ]
