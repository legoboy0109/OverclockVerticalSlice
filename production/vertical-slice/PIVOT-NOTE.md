# PIVOT NOTE — OVERCLOCK "One Close Skirmish"

> Required by `scope.md` §10: *"Capture a PIVOT-NOTE.md (what worked at slice quality, what
> failed, what the next slice must prove differently) before routing back."*
>
> **Date**: 2026-08-24 · **Verdict source**: `production/vertical-slice/REPORT.md`
> **Root evidence**: `production/playtests/swing-back-simulation-appendix-2026-08-21.md`

---

## 1. What failed — one cause, stated once

**The economy is unbounded, so building always outscores fighting, so nobody ever marches on the
objective, so no game is ever won.**

Everything else the investigation surfaced is a symptom of that sentence. Peak Credits observed:
**5,724** on one side, still climbing linearly at turn 200. Economy actions outscore manoeuvring by
**12–20×**, and unbounded Credits make them permanently affordable, so the AP budget is spent
before a unit can march.

**Do not re-attempt these — they were tried and measured:**
- ❌ *Raise the AI's siege weight.* The term already exists, provably fires in isolation, and
  changed nothing across 1,260 rows. Making it competitive requires 2.0–4.0 (12–20× the positional
  rate), at which point the AI abandons its economy entirely. One degenerate behaviour for another.
- ❌ *Fix the tiebreak metric.* Already done and correct (`TOTAL_HQ_HP`, boom exploit closed). It
  moved AI-vs-AI outcomes **not at all** — which is precisely what proved the seat skew was never
  the metric's fault.
- ❌ *Widen recolour masks for ownership* (from S5-08). There is no orange left in those sprites;
  relaxing the hue gate adds 0.2–1.0%. Solved instead by the tile decal.

---

## 2. What worked at slice quality — carry forward, do not re-litigate

| Thing | Status |
|---|---|
| **Two-budget AP + Credits economy** | Mechanically sound and fully wired end to end. The split is *not* what broke — the absence of a **bound** is |
| **Deterministic combat (Pillar 2)** | Untouched by every change in the arc, exactly as designed |
| **Render stack** | Sprite feed, per-instance glow, four state transforms, death echo, tile ownership decals. Four layers, ADR-0013 consistent |
| **Faction framework** | Approved, built, inert at Neutral — absorbed the whole economy pivot without a schema change. **This is where new faction content plugs in with zero rework** |
| **Round cap** | `VS_MAX_ROUNDS = 30` took termination from 0/20 to 19/19. Keep it armed |
| **Tiebreak** | `TOTAL_HQ_HP` default, unit-tested. Correct for human play |
| **Test + tooling discipline** | 984 tests green. The simulation harness and the windowed capture harness are the two most valuable artefacts Sprint 5 produced |

**18 ADRs remain Accepted. This PIVOT invalidates none of them** — the projected fix is data and
scoring, not architecture.

---

## 3. What the next slice must prove differently

The next slice's validation question is **not** the original one. It narrows to the thing that
failed:

> **Does a bounded economy make matches resolve on play?**

### Required outcomes, in order

1. **Bound the economy** — a Credit sink and/or cap, so accumulation cannot outrun every other
   consideration. **This is the replacement first PIVOT lever.** §7.1's designated first lever
   ("adding build-outpost") has already been spent: outposts shipped in Sprint 3, and the economy
   they feed is the thing that broke.
2. **Re-measure the siege term without changing it.** The existing `siege_value_per_tile_closed =
   0.20` is *predicted to surface on its own* once Credits are bounded. If it does, the diagnosis
   is confirmed. If it does not, the diagnosis is wrong and this note is the first thing to revisit.
3. **Shorten the natural arc** so 30 rounds is a genuine backstop, not the usual result.
4. **Restore a real win path for the AI.** Today the human can win but cannot lose, which makes any
   comeback measurement asymmetric by construction.

### Regression gate — cheap, automated, run it every time

Re-run the AI-vs-AI batch (`./redot --headless tools/SimulateMatches.tscn`, ~25 min for a full
batch). **Pass condition:**

- Games resolve **on play** (HQ destruction), not on the round cap
- Resolution is **not seat-determined** — outcomes appear from both seats
- The **material-advantaged side wins more often than not** (today, +3 Troopers wins 0 of 5)
- **Non-zero HQ damage** appears in the turn-rows at all (today: literally zero)

### Still owed, unchanged, and only a human can supply them

- **S5-03** iso-legibility (Pillar-3 hard gate) — never run, 3 sprints
- **S5-04** swing-back Analysis A / C / D — does the swing feel alive, does tempo read at a glance,
  does spending Credits *feel* like a tempo cost. **Analysis D is the economy pivot's core
  hypothesis** and no simulation can touch it
- **S5-07** windowed Visual/Feel sign-offs — captures exist, human sign-off does not

> ⚠ **Sequencing note.** Running S5-03/S5-04 *before* the economy is bounded means judging a build
> whose central failure is already known and already scheduled for repair. Bound the economy first,
> then play the sessions against a game that can actually be won and lost.

---

## 4. Known-false claims corrected during this arc

Recorded here so they are not re-inherited by the next slice:

- **"Silhouettes distinguishable in grayscale"** (§10 PROCEED clause, art bible §5.2 "Mass
  Distribution Bias") — **never built.** All 26 Rush/Boom sprite pairs are pixel-identical
  palette-swaps. Three documents asserted otherwise, including an accessibility audit row marked
  *Resolved*. The tile ownership decal now carries the non-hue read at `STRUCTURES_ONLY`; the
  silhouette form is Full Vision work.
- **"Δ34/255 — reads on structures, marginal on units"** — backwards. Units are the strong case
  (ΔE 60–76 deuteranopia); **structures** were the weak case, with the Defensive Structure at
  ΔE 2.3 whole-silhouette **under normal colour vision** — an ownership defect affecting everyone.
- **`TiebreakMetric` shipped 1 of 3 specified metrics**, and the one that shipped counted every
  entity, silently rewarding pure booming. Corrected.
- **There is still no victory/defeat presentation for any win path** — `game-hud.md` CR-9 / AC-17 /
  AC-22 all unimplemented. A one-line status message is the current stopgap. Invisible while games
  never ended; immediately visible now that they do.

---

## 5. Route

`PIVOT` → focused economy/tempo work (Sprint 6) → re-run the AI-vs-AI regression gate → run S5-03
and S5-04 against the repaired build → update `REPORT.md` → re-run `/gate-check pre-production`.

**Stage stays Pre-Production until that sequence completes.**

---

## 6. Outcome — the gate passed, 2026-08-24

**Step 2 of the route is done.** `18/21` matches now end by HQ destruction in a mean 25 turns,
from a baseline where an HQ had never taken a single point of damage in 4,182 turn-rows. Both
seats win equally (9/9); banked Credits peak at 9,550 and stay flat. Full table and caveats in
`production/sprints/sprint-6.md`.

**★ §3.2's prediction was wrong, and the correction matters.** This note predicted that once the
economy was bounded, *"the existing siege term should surface on its own"* — and said that if it
did not, **the diagnosis is wrong and that is the first thing to revisit.** It did not surface.
Bounding the economy was necessary and fixed real defects, but it moved resolution *not at all*.

The actual cause was one line of scoring: `_combat_value` scaled an HQ hit by `hp_removed /
max_hp`, which is right for a unit and wrong for a win condition. An HQ at 1 hp is nearly a
victory, not 1/40th of a structure. A 5-damage chip scored 0.75 against 3.00 for killing a
Trooper, so units correctly broke off a reachable objective to trade — forever. Matches stalled
at precisely the point where winning became possible.

So the honest version of §1 is: the slice did not stall because the economy was unbounded. It
stalled because **the AI was never paid to win**, and an unbounded economy meant it never had to
care. Both were real; only the second was load-bearing.

### What still stands between here and a verdict

The gate was always the *machine* half. Unchanged and still owed by a human (§3, "Still owed"):

| | |
|---|---|
| **S5-03 iso-legibility playtest** | ⛔ Pillar 3 hard gate, never run, now carried 4 sprints — and the corpus has since added unit classes, damage types, area telegraphs, ranks and crew states to a board that already took a sprint to make readable (cross-review **B-4**, still open) |
| **S5-04 swing-back playtest** | Deferred on purpose until the gate passed. **It is now unblocked** — this is the first build where a match actually ends, so the tempo question can finally be asked of a real game |
| **Core-loop fun** | No amount of AI-vs-AI resolution says the game is enjoyable. A resolving match is a precondition, not evidence |

`REPORT.md`'s **PIVOT** verdict therefore stands. It is not flipped by this batch and should not
be flipped without the human sessions above — replacing one unvalidated verdict with another is
the exact failure this note exists to prevent.
