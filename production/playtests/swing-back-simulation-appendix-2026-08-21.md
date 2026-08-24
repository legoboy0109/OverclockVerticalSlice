# S5-04 Appendix — AI-vs-AI Simulation (the measurable half)

> **This is NOT the swing-back playtest.** It does not close S5-04 and it does not
> substitute for a human session. See "What this cannot answer" below.
>
> **Date**: 2026-08-21 · **Build**: commit `6acef13` · **Tool**:
> `tools/SimulateMatches.tscn` (`./redot --headless tools/SimulateMatches.tscn`)
> **Suite at time of run**: 972/972 passing.

## Why this exists

S5-04 has been blocked on a human session for three sprints and is the last thing
standing between this project and its PROCEED/PIVOT/KILL verdict. Its questions split in
two. Some are judgements only a person can make — does the swing *feel* alive, does tempo
read at a glance, does spending on economy *feel* like a tempo cost. Others are structural
properties of the rules, measurable over many games, including **the one hard gate: "no
decided game reverses."**

This appendix answers the second kind. Both sides are driven by the shipped `AI` — the
same `AI.choose_action` the vertical slice uses, with the driver's pacing timer removed
and its economy-cadence counter replicated exactly. Games are differentiated by a starting
material handicap (0–3 bonus Troopers to one side), which the protocol explicitly
sanctions: *"note any self-handicap used to force genuinely close/undecided games."*

---

## ★★★ THE HEADLINE — the vertical slice has no terminating condition under AI play

**All 20 games ran to the 200-turn safety cap with no winner.** Not one resolved — including five in which one side started with three free Troopers.

Two independent facts combine to make that inevitable:

### 1. The AI never attacks an HQ. Not once.

**Zero HQ damage across all 4,182 turn-rows.** Both HQs sat at 40/40 hp for the entire length
of every game measured.

This is not because the AI cannot value the target — it can. `AI._ap_cost_opponent_paid_for`
substitutes `AIBalance.ai.hq_siege_value` (**12**) for the HQ, which is a *high* weight
against a unit's `produce_cost`, and there is an explicit regression guard (AC-29) against
that weight being zero. The scoring is there and it is generous.

**Hypothesis for the mechanism** (stated as hypothesis, not measured): the AI's positional
scoring drives units toward the *nearest enemy unit* (`_nearest_live_enemy_distance`,
`_positional_value`, `_sets_up_attack_next_turn`), so the two armies collide in the middle
of a 12×10 map and trade there indefinitely. A high value on a target you never stand next
to is never realised. **The AI has no siege drive** — no term pulling it toward the
objective when no enemy unit is nearby.

### 2. There is no round cap either.

`GameState.max_rounds` defaults to **0** (= no cap), and `VerticalSliceRoot._build_match`
never sets it. The `max_rounds` tiebreak machinery exists and is documented, but nothing in
the shipped slice arms it.

**So: no HQ kill, no round limit, no draw condition. The match cannot end.**

### What that does to S5-04's hard gate

**"No decided game reverses" is currently satisfied trivially and meaninglessly** — no
game ever becomes decided, because no game ever ends. The gate cannot be evaluated against
AI play at all.

It also reframes the human session: in human-vs-AI, **the human can win but cannot lose**,
except by their own error or by conceding. A swing-back playtest measuring "can a losing
player come back" is measuring an asymmetric situation — the AI has no path to victory to
come back *from*.

---

## Secondary finding — Credits accumulate without bound

Peak observed: **5,724 Credits** on a single side, still climbing linearly at the cap.

This is the exact risk the economy pivot's own open question flagged: *"Credit BANKING may
worsen leader snowball — stock now unbounded even though income rate is capped ~26/32."*
Confirmed empirically. With production capped and nothing else to spend on, income has
nowhere to go and simply piles up.

The AP surcharge brake works on *rate of action*, not on *stock*. Note this is partly an
artefact of games that never end — but the accumulation is linear and shows no sign of a
natural sink even by turn 200.

---

## Results — full batch, complete

**20 games. 20 capped. 0 winners. 0 HQ damage in 4,182 turn-rows.**

| Handicap to one side | Games | Reached a winner | Hit the 200-turn cap | Avg turns |
|---|---:|---:|---:|---:|
| +0 (symmetric) | 3 | **0** | 3 | 200 |
| +1 Trooper | 6 | **0** | 6 | 200 |
| +2 Troopers | 6 | **0** | 6 | 200 |
| +3 Troopers | 5 | **0** | 5 | 200 |
| **Total** | **20** | **0** | **20** | **200** |

**A +3 starting material advantage — three free Troopers against a mirror opponent —
never converted into a win in any of five attempts.** That is the clearest statement of
the finding: the game has no mechanism by which a material lead becomes a victory when
the AI is driving, because the only win condition requires attacking a building the AI
never approaches.

Peak Credits observed: **5,724**, still climbing linearly at the cap.

*(21 games were configured; the last was cut short by the run's wall-clock timeout. The
20 that completed are unanimous, so the missing cell changes nothing.)*

Raw per-turn data is not committed — regenerate with the tool. The full batch takes
roughly 25 minutes.

---

## ✅ FOLLOW-UP — `max_rounds` armed at 30, and what it exposed

The user armed the round cap the same day (`VerticalSliceRoot.VS_MAX_ROUNDS = 30`). The
simulator was re-pointed at the shipped configuration and the batch re-run.

**It fixes the termination problem outright.**

| | before | after |
|---|---:|---:|
| Games reaching a winner | **0 / 20** | **19 / 19** |
| Games hitting the safety cap | 20 / 20 | **0** |
| Turns per game | 200 (cap) | 60 (= 30 rounds) |

### ★★ But capped games skew 95% to the second player

**Player 1 won 18 of 19 (95%)** — including every game where player 0 started with up to three
free Troopers. `LOCAL_PLAYER = 0`, so **the human sits on the losing side of that skew.**

**Mechanism — the tiebreak does not measure what its name says.**
`TiebreakMetric.UNIT_COUNT` is implemented as:

```gdscript
for e: EntityState in entities():
    counts[e.owner] += 1
```

That counts **every entity — structures and the HQ included**, not units. So a capped game
is decided by *who built more*, not by who fought better. It is consistent with the
observed results: P1 won several games while trailing on unit count, which only makes
sense if structures decided them.

Two consequences worth putting in front of the verdict:

1. **The optimal line in a capped game is to boom and avoid combat.** Bank Credits,
   build, never trade units. That is the degenerate strategy the tiebreak accidentally
   rewards, and it sits directly on top of the unbounded-Credit finding above.
2. **A 95% second-player rate is not a tuning wobble.** Two identical deterministic
   agents on a mirrored map should not produce that. Whether it is turn order, the
   `1 - active_player` tie rule, or the entity-count metric itself, it needs diagnosing
   before a capped result can be trusted as a *game* outcome rather than a seat outcome.

**Should the cap stay armed? Yes — on the evidence.** Without it 0% of games end, which is
strictly worse and makes S5-04 unanswerable. With it, every game ends. A human will also
usually win by destroying the HQ (the thing the AI never does), so the cap should behave
as the backstop it is meant to be rather than as the usual result. **But if a human game
does reach turn 30, expect to lose it on a metric that rewarded your opponent's
construction.** Worth knowing before you play, and worth logging if it happens.

### ✅ Tiebreak metric corrected 2026-08-21 — and it isolates the real bug

The metric was fixed the same day. `game-state-turn-manager.md` had specified
`{total HQ hp, tiles controlled, unit count}` with **total HQ hp as the default** all
along; only `unit count` had shipped (HQ hp needed schema fields that had not landed
yet), it became the de-facto default, and it counted every entity. `TOTAL_HQ_HP` is now
implemented and is the default, and `UNIT_COUNT` counts units. Unit tests prove the boom
exploit is closed: a player drowning in units and outposts now **loses** a capped game to
an opponent whose HQ is healthier.

**It did not change AI-vs-AI outcomes — 7 of 7 still went to player 1 — and that is the
informative part.** With the AI never damaging an HQ, both sides finish every capped game
at 40/40. That is an *exact tie*, which falls through to the `1 - active_player` rule, so
the seat wins deterministically.

**So the seat skew was never the metric's fault.** The old entity-count metric was masking
it behind a number that happened to differ; correcting the metric moved the failure into
the open and attributes it correctly:

> **The root cause of everything in this appendix is that the AI never attacks an HQ.**
> No siege drive means no HQ damage, which means no decisive victory, which means every
> game reaches the cap, which means the tiebreak decides, which — with an honest metric —
> is an exact tie decided by seat.

For **human** play the metric is now correct and matters: a player who has battered the
enemy HQ wins a capped game, and cannot be out-built out of it.

Still unchanged, both design calls in `production/post-gate-backlog.md`: **the AI's
missing siege drive** (the root cause), and whether an exact tie should cascade to a
secondary metric rather than to the seat.

---

### ⚠ Siege drive added 2026-08-21 — it works, and it does not fix the symptom

A siege term was added to the AI: a positional pull toward the enemy HQ
(`AIBalance.ai.siege_value_per_tile_closed = 0.20`), scored above the ordinary advance
so progress toward the objective beats progress toward nothing in particular. Seven unit
tests cover it and the full suite is green.

**It provably fires.** Probed in isolation with a unit 4 tiles from the enemy HQ and no
nearer enemy, the AI moves to within 2. Traced across a full turn with a realistic
Credit balance, the AI spends BUILD ×2 (hitting the economy cap), PRODUCE ×2, and then
puts its remaining AP into two siege moves.

**And it changed nothing in a real match: 0 HQ damage across 1,260 turn-rows, 21 games,
all still to player 1.** The term is not the bottleneck.

**Why — the measurement that matters.** Sweeping the siege weight against a Credit-rich
position, the AI keeps choosing `BUILD` until the weight reaches somewhere between
**2.0 and 4.0** — that is **12–20× the ordinary positional rate of 0.16.** Economy
actions are not slightly better than manoeuvring; they are an order of magnitude better.
And with Credits unbounded (peak 5,724 and still climbing), they are *always affordable*.
So the AP budget is consumed by building and producing before any unit can march, and in
a real match with ten units the per-unit share of what is left is nothing.

Raising the siege weight into that range would "work" by making the AI ignore its economy
entirely, which is not a credible opponent — it would trade one degenerate behaviour for
another.

**So the causal chain runs one level deeper than the siege drive:**

> Credits are unbounded → economy and production are always affordable → they outscore
> any positional move by 12–20× → the AP budget never reaches manoeuvring → no siege →
> no HQ damage → no decisive win → every game caps → the tiebreak decides → an exact tie
> decided by seat.

**The two findings in this appendix are one finding.** The unbounded-Credit accumulation
is what starves the siege drive. **Bounding the economy — a Credit sink, or a cap — is
the actual fix**, and it is a design call, recorded in `production/post-gate-backlog.md`.

The siege term is kept: it is correct, tested, harmless at 0.20, and is the piece that
will make the AI push once the economy is bounded. It is necessary and not sufficient.

---

## ⛔ What this CANNOT answer — still owed to a human session

Everything S5-04 actually asks about *feel* is untouched by this and remains open:

- **Analysis A — is the swing alive?** Whether a close game has a genuine swing moment,
  and whether a stabilisation can flip a still-in-doubt game. Requires playing one.
- **Analysis C — tempo readability.** Whether you can feel tempo gain/loss at a glance
  from the dual HUD counters, and whether the two counters read as two distinct budgets or
  blur into one.
- **Analysis D — the two-pool tradeoff.** Whether spending on economy *feels* like a tempo
  cost, whether the hold-vs-cash-out banking decision is alive, and whether the pools read
  as one entangled economy or two disconnected currencies. **This is the pivot's core
  hypothesis and the reason S5-04 exists.** No simulation can answer it.
- **The reversal gate, meaningfully.** Answerable only once games can actually end.

**AI-vs-AI is also not the matchup the protocol is about.** The VS AI is documented as
"credible, not masterful"; a mirror match between two identical deterministic agents tells
you about the rules and about the AI, not about how a person experiences the game.

---

## Recommended reading of this for S5-05

The simulation did not close the gate. It did surface something the gate needs to know:
**as shipped, an AI opponent cannot win a match.** Whatever the verdict, that is worth
resolving before the swing-back question can be asked properly, because "can a losing
player come back" presumes a player can be losing.

Cheapest candidate fixes, in rough order of effort — **all are design calls, none applied**:

1. **Arm `max_rounds`** with the existing tiebreak (the machinery is built and documented;
   the slice just never sets it). Makes every match terminate, and gives the AI a way to
   "win" on the tiebreak metric.
2. **Give the AI a siege term** — a pull toward the enemy HQ that does not depend on an
   enemy unit being nearby, or a fallback objective when no attack candidate scores.
3. **A Credit sink**, so banking has a ceiling and stock cannot run to 5,000.

Items 2 and 3 are real design/balance work and belong in
`production/post-gate-backlog.md` unless the verdict makes them blocking. Item 1 is close
to a one-line configuration change and may be worth doing *before* the human session, so
that S5-04 is played on a build where matches can end.

---

## ⛔ S6-06 GATE RUN — 2026-08-24 — **FAILED**, and the diagnosis was wrong

**Build**: post S6-01..S6-05 (economy re-based on research tiers, upkeep, per-structure
maximums, population cap, AI re-anchored). Suite 1039/1039. 21 games, 1,260 turn-rows.

| # | Gate condition | Result | Baseline |
|---|---|---|---|
| 1 | resolve on **play** | **0 / 21** | 0 / 20 — unchanged |
| 2 | **non-zero HQ damage** | **NO — zero in 1,260 rows** | zero in 4,182 — unchanged |
| 3 | outcomes from both seats | n/a | — |
| 4 | peak banked Credits | **18,400** (target <15,000) | 572,400 equivalent |

A **+3 material advantage converted in 0 of 6 games.** Unchanged.

### The PIVOT note predicted its own falsifier, and hit it

> *"Bounding the economy lets the existing siege term surface. **If it does not, the
> diagnosis is wrong and that is the first thing to revisit.**"*

It did not surface. **The economy chain was wrong at its last link.**

### ★★ What instrumentation found (`tools/DiagnoseAI.tscn`, built for this)

Traced 24 turns, reporting per-verb best scores against `pass_threshold` (0.15):

| verb | turns with a candidate above threshold |
|---|---:|
| move | 14 / 24 |
| attack | 17 / 24 |
| produce | 24 / 24 |
| ★ **build** | ★ **0 / 24 — `best_build` is 0.000 in EVERY row** |

**The AI never builds anything, ever.** The chain:

> `_economy_value` returns 0 for structures (S6-01) → the AI never builds a **Barracks** →
> the population cap stays at its base of **4** → the army never grows → both sides field
> 3–4 units, replace losses instantly from the HQ, and grind mid-map forever → nothing ever
> reaches an objective.

It also explains condition 4: **Credits accumulated to 18,400 because the AI had nothing it
was willing to buy.** Not a broken drain — a broken *buyer*.

★ **The defect was introduced in S6-01**, with reasoning that was right about income and
wrong about value: *"no structure raises Credit income, so building is not an economic
investment."* True — but since **S6-04 a Barracks raises the population cap**, and the AI
has a term for income value and none for **capacity** value.

### ⚠ Two corrections to the first reading of this batch

1. **"The AI leaves 98% of its AP unspent" was an ARTEFACT.** `simulate_matches.gd` emits
   its row *after* `end_turn`, which runs `start_turn` for the next player and resets their
   AP — so the `ap0` column is a *fresh* budget, not a leftover one. The probe shows the AI
   committing **9–12 actions per turn** and spending ~20 of 45 AP. ★ **Check where a metric
   is captured before drawing a conclusion from it.**
2. **"The diagnosis was wrong" was too broad.** The economy work is correct and necessary —
   the unbounded-Credit defect was real and is fixed (a ~97% reduction against the
   equivalent baseline). What was wrong is the final link, *"AP never reaches movement."*
   AP does reach movement. The AI simply cannot grow.

### Next

Give the AI a **capacity-value** term so a Barracks is worth building, then re-run. Whether
that alone makes matches resolve is a separate question — armies that can grow may still
stalemate — but it is one batch to find out, and it is a bounded fix rather than a redesign.

---

## S6-06 GATE RE-RUN — 2026-08-24 — capacity fix landed; **gate still FAILS**

**Change under test**: the AI gained a capacity-value term (a Barracks is worth the army
capacity it unlocks) **and** the build enumeration was un-gated from a hard identity filter.

### The filter was the real defect, and S6-03 created it

`_score_build_and_economy_candidates` contained `if structure_type != ECONOMY_OUTPOST:
continue`. Sound when written — the other types had no strategic model, and enumerating
them on a placeholder basis caused a build↔cancel oscillation. But **S6-03 renamed
`ECONOMY_OUTPOST → FACTORY` mechanically, and the filter came with it**, leaving the AI
hard-locked to the one structure whose value S6-01 had just zeroed. It was structurally
incapable of building a Barracks at any price. Now gated on *"can we actually value this?"*,
which preserves the original guard's intent while letting any type with a real model in.

### What the fix DID achieve

| | before | after |
|---|---:|---:|
| Peak banked Credits | 18,400 | ★ **1,750** ✓ *(condition 4 now passes)* |
| BUILD candidates above `pass_threshold` | 0 / 24 turns | ★ **20 / 24** |

### What it did NOT

| Gate condition | Result |
|---|---|
| resolve on **play** | **0 / 21** — unchanged |
| **non-zero HQ damage** | **zero in 1,260 rows** — unchanged |
| +3 advantage converts | **0 / 6** — unchanged |

### ★★ The number that explains it

| late-game (turn > 40) | before fix | after fix |
|---|---:|---:|
| mean army size | 2.4 v 2.2 | **2.5 v 2.2** |
| mean structure hp | 14.7 | **14.9** |

**The AI now spends, but nothing accumulates.** Units die exactly as fast as they are
produced. Two symmetric AIs reinforcing from HQs at opposite ends of a 12×10 map, trading
one-for-one in the middle, forever. **Perpetual attrition is the equilibrium** — so the
population cap was never the binding constraint either.

### ★ Conclusion: this is a BALANCE property, not a bug

Nothing in the current rules lets either side achieve **local superiority**: reinforcement
is instant and adjacent to the objective, the map is small and symmetric, and a kill scores
**3.00** against an HQ chip at **0.75**, so no unit ever walks past a fight toward the
objective.

**Three levers, all design-direction calls:**
1. **Slower or more distant reinforcement**, so losses cost ground rather than a turn.
2. **Make the objective outscore trading**, so a unit will break off and push.
3. **Make combat decisive**, so a material edge converts instead of dissolving.

### ⚠ For the record: three predictions, three misses

Unbounded economy → AI paralysis → capacity. Each was a real defect, each was fixed, and
**none of them was the cause of non-resolution.** The economy work stands on its own merits
and the AI genuinely could not build. But the pattern says the remaining question is not an
engineering one, and the next change should be **chosen by design intent and then measured**,
not guessed at again. The batch and `tools/DiagnoseAI.tscn` make any candidate cheap to test.

---

## ★★ S6-07 — SLOWER REINFORCEMENT — **the first real movement in this project's history**

**Change**: a per-producer **production cooldown** (user's chosen lever, 2026-08-24). A
producer that makes a unit cannot make another for `production_cooldown_turns`. Shipped at
**2** on the HQ and the Barracks.

**Why a cooldown rather than per-unit build times:** it slows the *rate* of replacement —
which is what makes a loss cost ground — with one field and one check, rather than adding an
under-construction lifecycle to units.

### Result

| # | Gate condition | Result | Previous |
|---|---|---|---|
| 1 | resolve on **play** | 0 / 21 | 0 / 21 |
| 2 | ★★ **non-zero HQ damage** | ★★ **YES — 338 rows, lowest HQ 30/40** | ★ **ZERO, always** |
| 3 | both seats | n/a | n/a |
| 4 | peak banked Credits | **27,000** ⚠ | 1,750 |

### ★★ Condition 2 flipped, and it had never moved before

Across every prior measurement — 4,182 rows pre-fix, 1,260 after the economy work, 1,260
after the capacity fix — **HQ damage was exactly zero**. It is now 338 rows, with an HQ taken
to 30/40.

**The attrition equilibrium was the cause.** Slowing replacement lets one side achieve the
local superiority that instant reinforcement denied both, and somebody finally walks to an
objective and hits it. ★ Three earlier hypotheses (unbounded economy → AI paralysis →
capacity) each found a real defect and each fixed it; **none moved this number. This one
did.**

### Still failing, and now it is a MAGNITUDE problem rather than a DIRECTION one

Damage reaches 10 of 40 hp and stalls: attackers get through, chip, and die before
finishing. Pressure exists but does not sustain.

**Credits regressed 1,750 → 27,000**, and that follows directly from the fix — production is
gated behind a cooldown, so the AI banks what it cannot spend. A predictable second-order
effect, not a new defect, but it means condition 4 needs a sink again.

### Two candidate next steps, one batch each

1. **Raise the cooldown to 3–4** — more pressure per exchange, at the risk of starving both
   sides into a slower stalemate.
2. ★ **Keep 2 and let Barracks raise throughput** — a player who *invests* reinforces faster.
   Preferred on the reasoning that it turns the Credit surplus into the fix rather than a
   side effect, and makes the population-cap/Barracks system load-bearing instead of
   decorative. **User's call.**

---

## S6-07b — BARRACKS THROUGHPUT — **two of four conditions now pass**

**Change** (user's call): keep the cooldown, make investment pay. HQ cooldown **3**,
Barracks **1** — a player who builds Barracks reinforces three times faster. And the AI's
structure valuation switched from *capacity headroom* to **throughput**.

### The trend across four batches

| # | Condition | B1 | B2 | B3 | **B4** |
|---|---|---|---|---|---|
| 1 | resolve on play | 0/21 | 0/21 | 0/21 | **0/21** ✗ |
| 2 | **HQ damage (lowest hp)** | none | none | 30/40 | ★ **21/40** ✓ |
| 3 | both seats | — | — | — | ✗ |
| 4 | **peak Credits** | 18,400 | 1,750 | 27,000 | ★ **1,850** ✓ |

**An HQ is now taken to just over half health.** That number had never moved off 40 across
4,182 rows before S6-07.

### ★★ The trap, recorded because it is the most instructive thing here

The first capacity model scaled a Barracks' value by **cap utilisation**
(`current_population / effective_cap`). It correctly stopped the AI building infrastructure
it could not use — and created a loop that held the stalemate in place:

> armies cannot grow (units die as fast as they are made) → utilisation stays low → a
> Barracks looks worthless → throughput stays low → **armies cannot grow**

The AI built ~0.4 Barracks per match. ★ **A gate that keys on the symptom of the problem it
is meant to solve will preserve that problem.** Switching to throughput-based value broke
the loop: BUILD candidates above threshold went **0/24 → 20/24 → 24/24** turns.

★ It also inverted a relationship, and the new direction is the correct one: value now
**falls** as headroom shrinks, rather than rising with pressure. A producer is worth most
when you have room for what it makes. Over-building is bounded **structurally** (by
`max_count` and the headroom term) rather than **behaviourally** (by a gate).

### Still failing

Damage reaches ~19 of 40 and stalls: attackers get through, do real work, and die before
finishing. **Magnitude, not direction** — and the gap is closing.

**Most likely remaining cause:** a kill still scores **3.00** against an HQ chip at **0.75**,
so a unit standing beside an objective breaks off to fight instead of finishing. That is
lever 2 from the S6-06 analysis ("make the objective outscore trading") and it is the one
lever not yet tried.
