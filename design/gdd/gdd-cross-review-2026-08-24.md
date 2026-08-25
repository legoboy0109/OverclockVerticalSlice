# Cross-GDD Review Report — Faction Corpus v2

**Date**: 2026-08-24 · **Mode**: full (consistency + design theory + scenarios)
**GDDs reviewed**: 23 system GDDs (16 in `design/gdd/`, 6 in `design/gdd/factions/`, plus
`game-concept.md` and `systems-index.md`)
**Trigger**: `faction-identity.md` reshaped to framework v2; 7 new Tier-1 systems (#15–21); 6 faction
GDDs authored; the economy re-based onto research; AP and Credits rescaled.

## Verdict: ⛔ **FAIL** — 5 blocking issues

> **✅ ALL FIVE NOW RESOLVED.** B-1/B-2/B-3/B-5 were fixed in the review pass itself; **B-4 was
> answered 2026-08-24 (S6-11)** by `design/legibility-budget.md`. W-1/W-4/W-5 closed by the S6-09
> sweep. ★ One item remains outstanding and it is not a document fix: **S5-03, the Pillar-3 gate
> itself, has still never been run** — the budget calibrates against it.

> **FAIL here is not a judgement on the design.** It is the expected outcome of adding 13 documents
> and rebuilding the economy in one pass without a propagation sweep. Three of the four blockers are
> bounded edits; the fourth is a design-direction call. **No faction-vs-faction contradiction was
> found, no tuning-knob ownership conflict, and no anti-pillar violation** — the corpus is
> internally coherent where it is new, and stale where it meets what came before.

---

## Consistency Issues

### 🔴 BLOCKING

#### B-1 — `ai-opponent.md`'s `economy_value` scores a structure that no longer exists

- **`ai-opponent.md` §Formulas**: *"`economy_value` — AP-equivalent value of **building an Economy Outpost**"*
- **`base-production.md`** (rev 2026-08-24): the Economy Outpost is **DELETED**.
- Also affected in the same document: the worked example *"a first Economy Outpost: 7.06/4 = 1.765 → 7.06/6 ≈ 1.177"*, the `completed_outpost_count()` query listed under CR-4 and in the Base & Production interaction row, and the `combat_value` worst-case *"a full-hp kill on a Production Outpost"*.

**Why blocking rather than cosmetic:** economic mis-valuation by the AI **is** the PIVOT verdict's
root cause — the AI chose `BUILD` over manoeuvring because economy actions outscored movement 12–20×.
The corpus now changes what "economy action" even means, and the one document that decides how the
AI weighs them still scores a deleted building. **Any AI-vs-AI regression run before this is fixed
measures nothing.**

**Resolution:** re-point `economy_value` at the research-tiered income model — the value of an
economy action is now the projected income from a **research tier**, not from a structure. The
horizon/decay projection machinery is unchanged and still correct.

#### B-2 — Promotion and area attacks specify contradictory resolution order

- **`damage-types.md` DT-9**: *"Targets resolve in a fixed board order… with all deaths applied after all damage. **No target's death changes another's damage within the same attack.**"*
- **`promotion-veterancy.md`** Edge Cases: *"Rank-up mid-combat: applied after damage resolves and before the next target (PV-6), so **a burst's later targets face the promoted stats**."*
- **`promotion-veterancy.md` AC-11** asserts the same thing as a test.

**These cannot both hold.** A kill mid-burst promotes the attacker; a promoted attacker deals more
damage; therefore a target's death *has* changed another target's damage within the same attack —
exactly what DT-9 forbids. Reachable as soon as the Holy Cosmic Empire fields any area weapon.

**Why blocking:** Pillar 2 ("Tempo Is the Skill") requires deterministic, predictable combat, and
this is precisely the kind of order-dependence that produces a result the player cannot predict.
Leaving it to implementation means the answer is decided by whichever loop happens to be written
first.

**Resolution (recommended):** **DT-9 wins — promotion applies after the entire attack resolves.**
Rationale: DT-9's guarantee is load-bearing for every area weapon in the corpus (Alliance Artillery
and Bomber, Protectorate Breaker and Strafer, Union Battery, Solar Volunteer), while the
"mid-burst promotion" clause serves one faction's edge case and buys it almost nothing — the merit
is still earned, the promotion still lands, one tick later.

#### B-3 — `game-hud.md` mandates an income breakdown with two dead components

- **`game-hud.md`** specifies a Credit income breakdown of `base` + `outpost` + `econ_tech`, with edge cases covering *"0 completed Economy Outposts"* and *"Economy Tech held but 0 Economy Outposts exist"*.
- Income is now `BASE_INCOME` + completed research tiers. **There is no `outpost` term, and no outpost-scaled `econ_tech` term.**

**Why blocking:** it is a UI contract on a system whose data shape changed. Implemented as written,
the HUD queries fields that do not exist. It also interacts with `unit-upkeep.md` UR-8, which
requires **gross / upkeep / net** to be displayed — a three-figure contract that does not exist
anywhere in the HUD spec.

**Resolution:** rewrite the breakdown as `base + research tiers − upkeep = net`, absorbing UR-8's
requirement in the same edit.

#### B-5 — ★★ The rescale broke the AI's currency conversion — found while fixing B-1

**Not caught by the mechanical scan.** It surfaced only when re-deriving `economy_value`, and it is
the most consequential finding in this review.

`ai-opponent.md` states its scoring anchor explicitly:

> *"the pivot re-denominated the produce/build/research costs into Credits at the **same numbers**
> they used to cost in AP, [so] 1 Credit is worth exactly 1 old-AP of investment, giving a clean 1:1
> anchor."*

**The 2026-08-24 rescale destroyed that anchor.** Credits went ×100; AP *action costs* were
deliberately left unchanged. So every Credit-denominated value term — `economy_value`,
`research_value`, `production_value`, and `combat_value` through
`credit_cost_opponent_paid_for` — inflates **100×**, while the AP-native positional terms
(`POSITIONAL_VALUE_PER_TILE_CLOSED` ≈ 0.16, `PASS_THRESHOLD` 0.15) do not move.

★★ **At the unchanged rate of 1.0, the AI would value building and killing roughly one hundred times
a march.** That is not a rounding error — **it is the exact failure mechanism the PIVOT verdict
diagnosed** (economy outscoring manoeuvre by 12–20×) amplified by two further orders of magnitude.
Every AI-vs-AI regression run after the rescale would have measured an agent structurally incapable
of manoeuvring, and the result would have looked like the PIVOT fix had failed.

**Fixed:** `CREDIT_TO_AP_RATE` 1.0 → **0.01** (range 0.005–0.02). Because `0.01 × 100 = 1`, every
worked example, output range and threshold margin in that document still holds unchanged; only the
constant producing them moved. Both coupled invariants were re-checked: the lethal-floor headroom
**widened** (1.65 vs the old 1.77, against a floor of 3.5), and the Defense-Tech pass margin is
untouched.

> ### ⚠⚠ CORRECTION 2026-08-24 (S6-05 implementation) — B-5's DIRECTION was partly wrong
>
> This review stated: *"the AI would value building and killing roughly one hundred times a
> march."* **Reading the actual scoring code during S6-05 shows that is right about killing
> and wrong about building.** The real picture, per verb:
>
> | Verb | Value term | Denominator | Net effect of the ×100 rescale |
> |---|---|---|---|
> | **Attack** | target's `produce_cost` — Credits, ×100 | `attack_cost` — **AP, unchanged** | ★ **score inflated ~100×** |
> | **Produce** | `produce_cost` × multiplier — ×100 | raw Credit `produce_cost` — ×100 | ★ **cancels — unchanged** |
> | **Build** | `_economy_value` — **0 since S6-01** | Credit `build_cost` | ★ **score 0** |
> | **Move** | positional rate 0.16 — AP-native | AP | unchanged |
>
> So building was never inflated (it is zero), producing survived **by luck** — the ×100
> cancelled top and bottom — and only **combat** was distorted. The conclusion that the batch
> would have been unmeasurable stands, and the fix is the same; the mechanism is not what was
> written.
>
> ★★ **And a hazard this review missed entirely:** `hq_siege_value` is **12**, an
> AP-equivalent *weight* that did not rescale, while a unit's value became its ×100 Credit
> cost. A Trooper kill would score **~30× an HQ strike** — precisely the "armies collide in
> the middle and trade indefinitely, nobody sieges" behaviour the PIVOT verdict diagnosed,
> now amplified. Corrected by converting only the **Credit** branches of the opponent-paid
> lookup and leaving the HQ weight alone.
>
> ★ **The meta-lesson:** the direction of a unit-mismatch bug is not guessable from the fact
> that a mismatch exists. It depends on which side of each ratio scaled — and here that
> differed per verb inside one function family. **Read the arithmetic, do not reason about it
> abstractly.**

> ### ★ The general lesson, recorded because it has now happened twice
>
> **A "purely proportional" rescale is not safe for two classes of constant:**
> 1. **Unit-conversion factors between quantities scaled by different amounts** — `CREDIT_TO_AP_RATE`
>    converts Credits (×100) into AP (×1 on costs). This one.
> 2. **Formulas containing `ceil`, `floor` or integer division** — `UPKEEP_DIVISOR`, whose `ceil`
>    was doing heavy rounding on small numbers and silently drifted low at the new scale
>    (`unit-upkeep.md`).
>
> Both were caught, but only by working through the arithmetic rather than by grepping for stale
> names. **Any future rescale should audit conversion factors and rounding functions explicitly.**

#### B-4 ✅ ANSWERED 2026-08-24 (S6-11) — see `design/legibility-budget.md`

#### B-4 — Pillar 3 is a hard gate, and nothing owns whether the corpus still passes it

**`game-concept.md` Pillar 3** ("Readable Board, Deep Decisions") is explicit: *"the
vertical-slice legibility playtest is a **hard gate** on this pillar: if the board is not readable
at a glance… the depth gets fixed or cut, not shipped."* That gate (**S5-03**) has **never been
run**, across three sprints.

Since it was written, the corpus has added to the board:

| Added | Source |
|---|---|
| 3 unit classes, incl. **hovering aircraft with no ground contact** | `unit-classes.md` (UCOQ-1 flags the pivot/Y-sort problem) |
| 3 damage types + per-unit resistances | `damage-types.md` |
| 3 area shapes needing telegraph overlays | `damage-types.md` DT-7 |
| 8 abilities, each needing an affordance | `unit-abilities.md` (which notes the HUD has **none** today) |
| Ranks 0–3, visually distinguishable | `promotion-veterancy.md` PVOQ-3 |
| Crewed / uncrewed / carried states | `transport-and-pilots.md` |
| Population cap and net-income readouts | `population-cap.md`, `unit-upkeep.md` |

…on a board **already** carrying faction hue, AP-state body tint, emission glow and an ownership
decal — a set that took all of Sprint 5 to make legible, and only after a measured Pillar-1 defect
was found and fixed.

**Why blocking:** this is not a document error, it is an unowned risk against an explicit hard gate.
Six separate GDDs each flag their own visual requirement; **none owns the aggregate.** Four
individually-reasonable channels can still be collectively unreadable.

**Resolution — a design-direction call, not an edit.** Options: (a) run S5-03 on the current build
before building any of it, establishing the baseline; (b) commission a legibility budget document
that owns the total channel count; (c) accept and defer, with the gate re-run after wave 2.

> ### ✅ ANSWERED 2026-08-24 (S6-11) — **(b) then (a)**, in that order
>
> `design/legibility-budget.md` now owns the aggregate channel count. Summary:
>
> **★ The board is at seven always-on channels carrying five facts.** Read from the shipped
> renderer, *act-state is triple-encoded* — `body_tint_for(destroyed, _is_actionable(e))`,
> `mode_for(destroyed, _is_actionable(e))` and the has-acted glyph are three simultaneous
> expressions of one boolean. That is deliberate accessibility redundancy and it is kept, but it
> means the board's apparent crowding is **not all information**, and wave 2 has slack to spend
> before it needs new visual language.
>
> **The budget:** cap **always-on facts at five**; route everything else to on-demand (selection /
> pre-commit preview / command menu) or transient (targeting overlay, one at a time). The
> allocation rule is *"a fact earns an always-on channel only if the player would mis-play
> **before** interacting without it"* — which almost everything fails, correctly: Pillar 3 puts
> complexity in the choices, and clicking a unit **is** the start of a choice.
>
> **Net effect on wave 2: +1 always-on fact (crew state), funded from the existing redundancy.**
> Unit class merges into the silhouette family the art bible already mandates; rank rides the
> ownership decal; damage type, resistances and abilities go on-demand; area shapes are transient.
>
> **The gate still has to run.** Five is defended by "this is what a full sprint achieved", which
> is evidence about cost and none about readability. **S5-03 should run on the current build before
> any wave-2 art**, and it is what sets the real number — three specific unknowns in §6 of the
> budget each change the document. It is the cheapest measurement available and it gates the most
> expensive work.
>
> ⚠ **Not cleared by this:** `unit-classes.md` UCOQ-1 (hovering aircraft vs. ADR-0013 Y-sort) is a
> rendering-architecture question needing its own ADR, not a channel-budget question.

### ⚠ Warnings

| # | Issue | Documents |
|---|---|---|
| **W-1** ✅ **RESOLVED 2026-08-24 (S6-09)** — reciprocal downstream blocks added to 12 GDDs, derived from each new GDD's own Dependencies table. | **Dependency reciprocity is 0/11.** Not one existing GDD lists any of the 7 new systems as a downstream dependent, though all 7 declare hard upstream dependencies on them. Mechanical to fix via `/propagate-design-change` | all 11 pre-v2 GDDs |
| **W-2** | **`game-hud.md`'s pip-threshold derivation is invalidated.** It reasons from *"the highest-hp **unit** is Heavy at 10"* to justify `PIP_MAX_HP = 10`. A Union Siege Mech is a **unit** with **28 hp**; every vehicle is 12–28. The whole "units render pips, structures render numeric" intent collapses — vehicles are units that need numeric readouts. Its worked boundary analysis also cites the deleted Economy Outpost's hp 8 as the binding constraint | `game-hud.md`, `unit-classes.md` |
| **W-3** | **Deficit does not block `CAPTURE_VEHICLE`.** `unit-upkeep.md` UR-6 blocks produce/build/research in deficit; capture costs 0 Credits, so a player in deficit may steal a 700-upkeep vehicle and deepen it, unguarded. `independents.md` IOQ-3 already notes inherited upkeep can be 44% of their income | `unit-upkeep.md`, `unit-abilities.md`, `independents.md` |
| **W-4** ✅ **RESOLVED 2026-08-24 (S6-09)** — scale notes rather than rewritten numbers; see the commit rationale. | **Pre-rescale arithmetic in prose** across `combat-resolution.md`, `game-state-turn-manager.md`, `unit-system.md`, `base-production.md`, `transport-and-pilots.md`. Conclusions unaffected (the rescale is proportional); the arithmetic reads wrong. Tracked as APOQ-SCALE-2 | 5 docs |
| **W-5** ✅ **RESOLVED 2026-08-24 (S6-09)** — context-triaged, not find-replaced; historical records deliberately untouched. | **"Production Outpost" naming** persists in 10 documents; it is the **Barracks** | 10 docs |
| **W-6** | **`defense` has never shipped a non-zero value on a unit.** `combat-resolution.md` introduced the field and its floor-lock analysis was written against *structures*. The Empire is its first real use on units, at values (2–5) that interact with `MIN_DAMAGE` in ways that analysis did not consider | `combat-resolution.md`, `holy-cosmic-empire.md` |

---

## Game Design Issues

### ⚠ Warnings

#### D-1 — AP is now a surplus resource, and Pillar 1's stated premise is no longer true

**Pillar 1 reads: *"Two **scarce** budgets."*** After the 2026-08-24 rescale, `FLAT_AP_PER_TURN` is
30 while action costs are unchanged — roughly **three times the actions per turn** at identical
prices.

Against the economic-loop table in this skill's own checklist, AP now matches **"Source ≫ Sink →
surplus accumulates → resource becomes meaningless."** A typical army can move *and* attack in the
same turn, so the triage that made Pillar 1 *felt* is largely gone. Pillar 2 ("Tempo Is the Skill")
is weakened by the same change.

★ **This was a deliberate, documented user decision** (`ap-economy.md` SCALE banner) taken to solve a
measured problem: at 10 AP, any army above ~5 units had members standing idle every turn regardless
of player intent. The trade was made knowingly, and the restoring dial — **AP action costs** — was
deliberately left unscaled for exactly this purpose.

**What the review adds:** the pillar text still asserts scarcity that the numbers no longer deliver.
Either the numbers move back toward the pillar (raise action costs once large armies have been
played) or **the pillar text should be revised to match**, as Pillar 1 already was once in 2026-08.
Leaving them divergent means the design test *"if it has an effect, it has a price"* no longer
describes the game.

#### D-2 — Cognitive load: ~11 simultaneously active systems against a 3–4 guideline

Systems requiring active decisions in a single turn: AP budget · Credits budget · **upkeep/net
income** · **population cap** · movement · combat targeting **+ damage types + resistances** ·
**abilities** · **transport/crewing** · research · structures with per-faction maximums · **(Empire)
promotion**.

Seven of those eleven are new since 2026-08-24. This compounds B-4 — cognitive load and visual
legibility are the same problem measured from two directions.

**Not blocking**, because a turn-based game with no clock is the genre most tolerant of load, and
several systems are per-faction rather than universal (only the Empire tracks promotion, only three
factions use the cap as a primary lever). **But it should be a stated, owned decision** rather than
an accumulation.

#### D-3 — Two of six factions have quality set by opponent behaviour, not by numbers

`independents.md` IOQ-1 and `holy-cosmic-empire.md` HCEOQ-1 both record this honestly. The
Independents are the worst faction in the game against a careful opponent and play with a stolen
army against a careless one; the Empire's whole investment is reversible by one successful raid.

**One such faction is a texture. Two of six may be a pattern.** Flagged for the user as a
faction-set-level judgement no individual document can make.

#### D-4 — `REPAIR` runs against the project's central open problem

`unit-abilities.md` ABOQ-3 and `solar-federation.md` SFOQ-3 both raise it; recorded here because it
crosses documents. The PIVOT verdict was *"matches never resolve."* Healing is structurally a
mechanism for making combat **less** decisive, and two Medics can sustain each other. `REPAIR_AMOUNT`
must be validated against the AI-vs-AI batch **with a healer present**, not tuned in isolation.

#### D-5 — Merit sits close to the "no parallel currencies" anti-pillar

**Anti-pillar:** *"NOT a sprawl of parallel currencies… we don't bolt on further disconnected
tracks."* Merit is a per-unit accumulating track that is not AP and not Credits.

**Assessed as NOT a violation**, and the reasoning is worth recording: merit is **not spendable**,
has no sink, cannot be transferred or converted, is capped at rank 3, and exists for exactly one
faction. It is closer to experience-on-a-piece than to a currency. ★ But if a future design ever
lets merit be **spent**, that would cross the line and the anti-pillar should be re-read first.

### ✅ Checks that passed

- **Pillar 4 is delivered** — six factions with genuinely distinct verbs, each with a CR-10 sheet, and pairwise separations explicitly checked (Protectorate/Union, Union/Empire). ★ This pillar has been unvalidated for the project's entire history; it is now at least *designed* convincingly.
- **No tuning-knob ownership conflicts.** Every new constant has exactly one owning document. `crew_bonus` (Transport), `UPKEEP_DIVISOR` (Upkeep), `RANK_THRESHOLD` (Promotion), `RESISTANCE_MIN/MAX` (Damage Types) are each singly owned.
- **No dominant faction on paper.** All six pass CR-10.2; each loses at least one axis decisively.
- **No competing progression loops.** One economy, one cap, one research spine. Promotion is faction-scoped, not a second global loop.
- **Credit economy is now bounded on both ends** — a finite research ceiling (rate) and upkeep (stock). This is the PIVOT fix and it is coherent across `ap-economy.md`, `research-tech.md`, `base-production.md` and `unit-upkeep.md`.
- **CR-3 holds.** Every ability is priced ≥1 AP; no faction adds a third resource or re-prices a catalogue verb.

---

## Cross-System Scenario Issues

**Scenarios walked: 4**

#### 🔴 S-1 — Empire area attack that kills — *Damage Types × Promotion × Combat*
**Trigger:** an Empire unit with an area weapon kills a unit in the first tile of a `BURST`.
**Failure at step 3 (data flow):** DT-9 requires all damage computed before any death is applied;
PV-6 plus `promotion-veterancy.md` AC-11 require the resulting promotion to affect later targets in
the same attack. **Undefined behaviour** — damage to targets 2–4 differs depending on which rule the
implementation follows. **This is B-2.**

#### ⚠ S-2 — Capturing while insolvent — *Abilities × Upkeep × Population Cap*
**Trigger:** an Independents player in deficit (bank 0, upkeep > income) captures an enemy vehicle.
**Failure at step 2:** UR-6's lock covers produce/build/research; capture is an ability with 0 Credit
cost and is permitted. The player inherits the vehicle's upkeep, deepening the deficit with no
guard and no recovery path except disbanding what they just took. **This is W-3.**
**Recommendation:** either extend UR-6's lock to any action that *increases* upkeep, or state
explicitly that capture is a sanctioned exception — the latter is arguably better design (a
desperate player stealing their way out is a good story) but it must be a decision, not a gap.

#### ⚠ S-3 — Cathedral falls while veterans are in transit — *Promotion × Transport × Turn Manager*
**Trigger:** the Empire's Cathedral is destroyed while Empire units are carried inside a Reliquary.
**Ambiguity at step 2:** PV-7 decays *"every unit of that faction"*; carried units are live units
without a tile. Consistent reading is that they decay, but **no document says so**, and the same
class of ambiguity (`entities()` assuming board presence) is already flagged as `transport-and-pilots.md`
TPOQ-1. **Recommendation:** state it explicitly in PV-7 — carried units decay.

#### ℹ️ S-4 — Stolen vehicle upkeep at the turn boundary — *Abilities × Upkeep × Turn Manager*
**Trigger:** a vehicle changes owner mid-turn.
**Resolves correctly.** UR-2 charges upkeep once per player at their own start of turn, so the old
owner has already paid and the new owner pays from their next turn. No double-charge, no gap.
Recorded as a *pass* because it is the kind of boundary that usually is not.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `ai-opponent.md` | `economy_value` scored a deleted structure; **`CREDIT_TO_AP_RATE` broken by the rescale** | Consistency | 🔴 **Blocking — ✅ FIXED** |
| `promotion-veterancy.md` | Resolution-order contradiction with `damage-types.md` DT-9 | Consistency | 🔴 **Blocking — ✅ FIXED** |
| `game-hud.md` | Income breakdown specified dead components; pip derivation invalidated by vehicle hp | Consistency | 🔴 **Blocking — ✅ FIXED** (pip rule flagged to `/ux-design`) |
| `game-concept.md` | Pillar 1 asserts AP scarcity the numbers no longer deliver | Design Theory | ⚠ Warning |
| `unit-upkeep.md` | Deficit lock does not cover upkeep-increasing actions | Consistency | ⚠ Warning |
| `combat-resolution.md` | Floor-lock analysis predates non-zero unit `defense` | Design Theory | ⚠ Warning |
| `command-action-interface.md` | Consumes `completed_outpost_count` | Consistency | ⚠ Warning |
| `base-production.md`, `unit-system.md`, `game-state-turn-manager.md`, `movement-system.md` | Pre-rescale arithmetic; "Production Outpost" naming | Consistency | ⚠ Warning |

---

## Required actions before re-running

1. ✅ **B-1 — DONE.** `economy_value` re-pointed at research-tiered income; machinery unchanged.
2. ✅ **B-2 — DONE.** DT-9 wins; promotion applies after the whole attack resolves. AC-11 rewritten,
   and `damage-types.md` DT-9 now cross-references the correction so it is discoverable from both sides.
3. ✅ **B-3 — DONE.** Income breakdown rewritten as `gross − upkeep = net`, absorbing `unit-upkeep.md`
   UR-8's three-figure contract, which previously had no home in the HUD spec.
4. ✅ **B-4 — ANSWERED (S6-11).** `design/legibility-budget.md`. ★ Still owes the **S5-03 playtest**, which calibrates the cap.
5. ✅ **B-5 — DONE.** `CREDIT_TO_AP_RATE` 1.0 → 0.01. ★ **This one would have invalidated the next
   AI-vs-AI regression batch, which is the evidence the entire PIVOT fix depends on.**

Then run `/propagate-design-change` for W-1, W-4 and W-5 as one sweep.

> ### ⚠ Addendum 2026-08-24 — a sequencing claim in this corpus was wrong, and is withdrawn
>
> Two faction documents (and this reviewer's handoff) claimed an **infantry-only faction could be
> shipped early** as a cheap validation target. **The user corrected it:** under the new
> `faction-identity.md` **CR-11**, every faction has piloted vehicles and an infantry cap, so a
> faction stripped of vehicles is a fragment rather than a faction, and testing it would measure a
> game nobody will play. Corrected in `democratic-alliance.md` and `solar-federation.md`.
>
> ★ **The underlying goal survives, on a better footing.** What wave 1 can validate is **the
> economy**, and it needs no faction at all — upkeep, research-driven income and the per-structure
> maximums all apply to the units the vertical slice *already ships*. Run the AI-vs-AI batch on the
> existing Neutral slice with the new economy: that answers the PIVOT's question — *do matches now
> resolve on play?* — honestly, without dressing a partial roster up as a faction.

> ★ **Sequencing recommendation.** B-1 and B-3 should land before the next AI-vs-AI regression batch,
> because that batch is the evidence the PIVOT fix depends on and it cannot be trusted while the AI
> cannot value an economic action. B-4 should be answered before any wave-2 art or renderer work.


---

## ✅ S6-09 sweep — W-1 / W-4 / W-5 closed, 2026-08-24

**W-1 (reciprocity 0/11).** Reciprocal downstream blocks added to 12 GDDs, generated from each
wave-2 GDD's own Dependencies table so the new documents stay the authority. `unit-system.md` and
`ai-opponent.md` each take all 7 — unsurprising: the wave-2 corpus is mostly new unit properties
and the AI reasoning that must account for them.

★ Why this was worth more than tidiness: the Dependencies section is what tells an author what
they are about to break, and it only works when read *from the document being edited*. Someone
opening `unit-system.md` to change `UnitTypeDef` saw nothing indicating seven documents now build
on it. Every pointer existed; every one pointed the wrong way for that question.

**W-5 (naming).** Deliberately not a find-replace. Occurrences fell into three classes and only
one should change:

| Class | Treatment |
|---|---|
| Stale live reference ("produced from a Production Outpost") | Renamed |
| Prose *about* the rename ("the Production Outpost becomes the Barracks") | Left — it is the record of the change |
| A section describing a **deleted** mechanic (outpost-keyed income) | ⛔ **Marked superseded, never renamed** |

Renaming the third class would have been the worst outcome available: it would read as a live rule
describing a structure that no longer feeds income at all.

Scope was also narrowed on purpose. 2,385 of the 2,523 matching lines are in the session log, with
more in retrospectives, past playtests, dated consistency reports and closed sprints. Those are the
audit trail — the names were correct when written, and rewriting them falsifies the record.

★ **The real find.** Three documents — `base-production.md`, `ap-economy.md`, `research-tech.md` —
had the S6 rework bolted on as a leading block with the entire original body left underneath,
describing the old roster and the deleted income formula **in the present tense**. A reader who
skipped the block got a coherent, confident, completely superseded design. Each now carries an
unmissable divider and a correction table.

★ `faction-identity.md` carried an actual error rather than a stale name: its per-stat saturation
argument cited "Economy Outpost `build_time` = 1" as a floored stat. That structure's successor now
sits at `build_time` 3, so it is not floored and the example never applied. The paragraph is
specifically about auditing headroom against **live** values, so the correction was left visible as
its own cautionary example.

**W-4 (pre-rescale arithmetic).** `unit-system.md` gains a scale note rather than rescaled numbers.
Its conclusions are unaffected — the rescale was proportional — and rewriting them would silently
restate arguments the user approved at the old scale. The remaining W-4 documents are covered by
the three dividers or carry no Credit figures.

**Beyond the three warnings**, the sweep reconciled `design/registry/entities.yaml`, which had
drifted for four sprints. That file is the grep-first baseline for `/consistency-check` and this
very skill, so its stale entries would have been treated as authoritative and used to flag correct
documents as inconsistent. All 11 spot-checked values now match `data/`.

### ⚠ Left open, deliberately

| | |
|---|---|
| **B-4 — the Pillar 3 legibility budget** | ✅ **Answered 2026-08-24 (S6-11)** — `design/legibility-budget.md`. What remains is running **S5-03**, which is a playtest, not a document |
| **Barracks / Defensive Structure stat drift** | Data says Barracks 900 and Defensive 600/1; `base-production.md`'s roster table says 600 and 500/2. Live balance values on a gate that has only just started passing — reconciling them either way is a **balance decision**, not a data correction |
