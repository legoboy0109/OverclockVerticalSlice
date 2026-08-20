# Swing-Back + Two-Pool Tempo Playtest — SESSION RECORD (S5-04)

> **Status**: IN PROGRESS — session opened 2026-08-19.
> **Protocol**: `production/playtests/swing-back-playtest-2026-07-29.md` (revised 2026-08-08 for
> the AP→AP+Credits pivot). This file is the filled instance; the protocol stays a clean template.
> **Story**: S5-04 (Sprint 5). Feeds the S5-05 REPORT + `/gate-check pre-production` re-run.
> **Day-1 gate**: satisfied — this session ran **before** any S5-01 renderer code was written
> (Sprint 4 retro action 1).

---

## Session Info
- **Date(s)**: 2026-08-19
- **Build / commit**: `39767de` — two-pool economy + dual HUD counters, placeholder-diamond board
  (S5-01 art wiring deliberately not yet done; this playtest is art-independent)
- **Test suite at time of play**: 860/860 passing, 0 failures, 0 orphans
- **Tester(s)**: user (game-designer) — self-test
- **Platform / input**: PC (Linux) — KB+M, windowed
- **Total games played**: [n]  ·  **Close**: [n]  ·  **Decided**: [n]
- **How close games were engineered**: [the VS AI is "credible, not masterful" — note any
  self-handicap used to force genuinely close/undecided games]

---

## Per-Game Log (one row per game)

| # | Result (W/L) | Who led early | Turn it became DECIDED (or "never → close") | Class (Close/Decided) | REVERSED after decided? (Y/N) | Swing / Zero-Hour moment? | Closeout length (turns) | Closeout drag? (None/Mild/Bad) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |  |  |

> **"REVERSED?" is the hard gate** — any `Y` on a `Decided` game is a blocking finding.

---

## Analysis A — Close / undecided games (is the swing alive?)
- **Genuine swing moment in close games, or decided long before the end?**
- **Could a stabilization flip a still-in-doubt game** (AP tempo sequencing + Credit-timed reinvestment)? Example turn:
- **Zero-Hour feel**: [Yes / Weak / Absent]
- **Notes / representative game**:

## Analysis B — Decided games (no-reversal check + closeout)
- **Did any decided game reverse?** [No / YES — game #s]  ← the one hard must-not-happen
- **If yes, what mechanic handed the comeback?** (Credit banking swing / production tempo / AP surcharge too weak / combat math)
- **Closeout drag**: [None / Mild / Bad] — and why:
- **Near-reversals that self-corrected**:

## Analysis C — Tempo readability (supporting)
- **Could you feel tempo gain/loss at a glance** from the dual HUD counters? [Yes/Partly/No]
- **Did Credit banking / reinvestment feel like it compounded?** [Yes/Partly/No]
- **Did the two counters read as two distinct budgets, or blur into one?** [Distinct/Blurred]

## Analysis D — Two-Pool Tempo Tradeoff (the re-opened pivot hypothesis)
- **Does spending on economy FEEL like a tempo cost?** [Real cost / Noticeable / Ignorable]
- **Is the hold-vs-cash-out banking decision alive?** [Yes / Weak / No]
- **Does the AP surcharge brake the economic snowball?** [Brakes it / Partial / Ignorable]
- **Do the pools read as ONE entangled economy, or two disconnected currencies?** [Entangled / Disconnected]
- **Representative moment**:

---

## Findings → categorized
- **Design changes needed**:
- **Balance adjustments** (pivot knobs: Credit income curve, AP surcharges produce/build/research, AP carryover cap, build/produce Credit costs):
- **Bug reports**:
- **Polish items**:

---

## Verdict (feeds S5-05 REPORT + re-gate)

**Definition of Done check:**
- [ ] ≥1 session documented (DoD floor)
- [ ] ≥3 close **and** ≥3 decided games logged (preferred target)
- [ ] Closeout-drag observation captured
- [ ] "No decided game reverses" explicitly answered (Analysis B)
- [ ] Two-Pool Tempo Tradeoff explicitly answered (Analysis D)

**Verdict**: [PASS / CONCERNS / PIVOT]  ·  **One-line rationale**:
