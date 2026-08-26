# Research / Tech

> **Status**: **In Revision — PIVOT 2026-08-05.** Previously Approved — independent `/design-review` 2026-07-21 (5 agents: game-designer /
> systems-designer / economy-designer / qa-lead + creative-director senior): verdict **NEEDS REVISION** →
> 4 blocking items resolved in-file → **user accepted the revisions to Approved**. Fixes: (1) stale
> "unlanded handoffs" header + BLOCKED AC tags corrected — **both cross-system handoffs LANDED** (Unit
> System #4 Approved w/ `effective_defense` + two-flag split; Base & Production #7 Approved w/ the Research
> Lab 5th-structure entry), so all Integration ACs are testable now; (2) the Defense-Tech + Cover
> **floor-lock** sanity check corrected to include the researched-vs-researched mirror case, and elevated
> to a named Open Question with a **pre-committed non-stacking fallback lever**; (3) Research honestly
> reframed as an intentional **mid-game snowball lever** (not a no-brainer-free "patient investment"),
> with a closeout re-run AC; (4) **Economy Tech retuned to scale** — now a permanent **+1 AP/turn per
> completed Economy Outpost** (was a one-time −1 Economy-Outpost build-cost discount), a genuine peer to
> Attack/Defense Tech. **Tech numbers remain unplaytested/spike-gated; `DEFENSE_TECH_BONUS` provisional
> (floor-lock). The Economy Tech retune creates owed RE-REVIEWS of AP Economy #3 and Base & Production #7
> (income-formula add + discount-removal — reconciled in-file this session, but both need re-review — see
> Dependencies). AP Economy #3's re-review (2026-07-22) found the income term as originally added was
> untiered and structurally cancelled AP Economy's own diminishing-returns brake — fixed by AP Economy
> adding its own cap, `ECONOMY_TECH_TIER_THRESHOLD` (6 completed Economy Outposts, AP-Economy-owned),
> which lowers the practical ceiling from ~38 to ~32. `ECONOMY_TECH_INCOME_BONUS` (this doc's own value,
> 1) is unchanged. Base & Production #7's re-review is still owed.**
> **PIVOT 2026-08-05 (AP↔Credits split).** The single AP pool split into two resources (see
> ap-economy.md). For Research: a tech's `research_cost` is now denominated in **Credits** (the banked
> economy currency — same numbers as before, 7/10/10), paid via `credits_spend`; **plus** a small
> per-tech **`ap_surcharge`** (AP) charged when research is committed — a new tech-template field whose
> default is the base `RESEARCH_AP_COST` (1, owned by AP & Credits Economy) and which each tech may
> override for its own tempo cost (the three VS techs all default to 1 for now). Research is therefore a
> **dual-cost, both-or-neither** action — `research_cost` Credits **and** `ap_surcharge` AP, spent both
> or neither. **Economy Tech's income bonus** now adds to **`credit_income`** (was `ap_income`), capped
> by `ECONOMY_TECH_TIER_THRESHOLD` (6) as before. Attack/Defense Tech effects are unchanged (unit
> combat-stat buffs). The **Research Lab** structure's `build_cost` (8) is now Credits + the standard
> `BUILD_AP_COST` (2) AP surcharge (it follows Base & Production's build dual-cost, not the research
> surcharge). No numeric values change — only the resource denomination and the added per-tech surcharge.
> The pre-pivot "single shared AP pool" framing in the prose below is superseded; it is retained with
> inline flags. **Pending:** `/design-review` on this delta; ⚠ **Pillar 1 wording** (see ap-economy.md
> Open Questions).
> **Author**: user + main session (systems-designer + economy-designer on tech/Lab numbers; qa-lead on acceptance criteria)
> **Last Updated**: 2026-08-05 (AP↔Credits pivot — research cost → Credits + per-tech `ap_surcharge` base 1; Economy-Tech income → Credits)
> **Implements Pillar**: ⚠ Pillar 1 ("One Economy, Every Choice") is revised by the pivot — research now
> spends **Credits + a small AP surcharge** (`ap_surcharge`, default 1), not a single pool (wording TBD —
> see ap-economy.md Open Questions); Pillar 2 (Tempo Is the Skill — a third tempo axis beyond units and economy)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Lean review mode (not a phase gate). Review pillar alignment manually or in the independent `/design-review`.
> **Priority / Layer**: Vertical Slice / Core (system #8)

> ## ★★ REVISION BANNER — research becomes the economy (2026-08-24)
>
> **Status: IN REVISION.** User decision, 2026-08-24: **economy growth is linked to research
> instead of to Economy Outposts, and the Economy Outpost is deleted.** This document's Economy
> Tech is no longer *a* source of income — it is now **the only one**.
>
> ### What changes here
>
> **Economy Tech becomes a three-tier line, not a single tech.**
>
> | Tech | `research_cost` (Credits) | `ap_surcharge` | `research_time` | Effect |
> |---|---:|---:|---:|---|
> | **Economy Tier I** | **1,000** | 1 | 1 turn | `credit_income` **+500** (1,000 → 1,500) |
> | **Economy Tier II** | **2,000** | 1 | 2 turns | `credit_income` **+500** (1,500 → 2,000) |
> | **Economy Tier III** | **3,500** | 1 | 3 turns | `credit_income` **+500** (2,000 → 2,500) |
>
> - Tiers are **strictly sequential**: II requires I, III requires II. This is what makes the
>   economy a *curve you climb* rather than a menu, and it gives the Holy Cosmic Empire's *"linear
>   tech tree"* identity a shape the base game already speaks.
> - **Flat +500 per tier, escalating cost.** Diminishing returns on investment without a diminishing
>   benefit — each tier still feels like a real upgrade, but Tier III (7-turn payback against a
>   30-round match) is a genuine commitment rather than an automatic purchase.
> - **The economy ceiling is 2,500 Credits/turn, and it is HARD.** Once Tier III is held there is no
>   further economic growth available at any price. ★ This is the structural change; everything else
>   here is bookkeeping.
>
> ### What is superseded
>
> The old `economy_tech_income_bonus(player)` formula — `ECONOMY_TECH_INCOME_BONUS × min(n,
> ECONOMY_TECH_TIER_THRESHOLD)`, scaling with completed Economy Outpost count — is **removed
> entirely**. There is no `n`. The § "Economy Tech's boom-scaling income effect" and the §
> "Compounding sanity check" both existed to bound a term that multiplied against outpost count; **both
> are obsolete, and the risk they guarded against no longer exists.** That is a real simplification,
> not a loss.
>
> Attack Tech and Defense Tech are **unchanged**.
>
> ### ★ Consequences worth stating plainly
>
> 1. **The Research Lab is now the economic spine of the game.** It is the only route to income
>    growth, which makes it the highest-value structure on the board and a natural attack target.
>    The game has been measured failing to give players reasons to attack; this creates one.
> 2. **Destroying a Research Lab mid-research** already voids progress under this doc's existing
>    interrupt rule. That rule is now *much* more consequential and should be re-read with fresh eyes
>    rather than inherited.
> 3. ★ **The Empire's vulnerability needs re-differentiating.** *"Highly vulnerable to tech base
>    disruption"* was meant to be the Holy Cosmic Empire's distinguishing weakness. Under this change
>    **every** faction is vulnerable to losing its Research Lab. The Empire's version must go further —
>    `promotion-veterancy.md` PV-7's rank decay is the mechanism, and it is what keeps the identity
>    distinct. See RTOQ-NEW-1.
> 4. **Faction income deltas (D4) now key to tier bonuses**, not to an outpost curve. The
>    intercept-vs-slope distinction from `faction-identity.md` survives in a cleaner form:
>    **intercept** = a delta on `BASE_INCOME` (felt from turn 1, e.g. the Independents' limited
>    economy); **slope** = a delta on `ECON_TIER_BONUS` or on tier costs (compounds as you climb,
>    e.g. the Machinist's Union's late-game arc).
>
> ### New open questions
>
> | # | Question | Owner |
> |---|---|---|
> | ~~RTOQ-NEW-1~~ | ✅ **RESOLVED 2026-08-24 in `factions/holy-cosmic-empire.md`.** Everyone loses income *growth*; **only the Empire loses what it has already built.** Killing an Alliance Lab caps their future; killing the Empire's **Cathedral** un-develops their present — every unit drops one rank per turn until it is rebuilt (PV-7). ★ It is the only mechanism in the game that takes value **back**, which is what makes the Empire's stated vulnerability sharper than the shared one rather than identical to it. Doctrine bonuses deliberately persist — one vulnerability mechanic, clearly legible | ✅ closed |
> | RTOQ-NEW-2 | **Should Attack/Defense Tech also tier?** Economy now has three tiers; a single flat Attack Tech alongside looks inconsistent, and a tiered combat line would give the Empire's "power increasing based on the linear tech tree" somewhere to live | systems-designer |
> | RTOQ-NEW-3 | ★ **Is a 2,500 ceiling right?** At the pre-rescale scale it was 25, close to the old ~26 practical ceiling, so existing balance intuition roughly carries over. But the old ceiling was reached by *building*, which cost map space and time, while this one is reached by *researching*, which costs only Credits and turns. The curve to reach it is quite different even though the endpoint is similar | economy-designer |

---

# ⛔ EVERYTHING BELOW THIS LINE PREDATES THE S6 ECONOMY REWORK

The revision banner above is the **current** design. The body that follows is the original
Research/Tech design, retained for the rationale, lifecycle, edge cases and acceptance criteria the
rework did not replace — but it was written when Economy Tech was a *modifier on a
structure-keyed economy*, and it has not been rewritten.

**Read it through these corrections (S6-09, 2026-08-24, cross-review W-4/W-5):**

| Below you will read | Status |
|---|---|
| **Economy Tech** as `+ECONOMY_TECH_INCOME_BONUS` per completed Economy Outpost, up to `ECONOMY_TECH_TIER_THRESHOLD` (6) | ⛔ **Superseded.** Research *is* the economy now: income is `base_income + econ_tier_bonus × tier`, with `tier` bought up to `max_economy_tier` (3) at `econ_tier_costs`. Nothing counts structures |
| **Economy Outpost** | Deleted as an income source; the resource was renamed to **Factory**, a `GROUND_VEHICLE` producer that grants no income |
| **Production Outpost** | **Barracks** (S6-03) |
| Any **Credit** figure (`build_cost 8`, `research_cost 7`, payback comparisons) | **×100** (S6-02) |

★ **The economy ceiling is the point.** The old design had no ceiling — Economy Tech multiplied an
unbounded outpost count, which is the compounding loop that produced the **PIVOT** verdict. The
replacement is finite by construction: three tiers, bought once each, and then income stops
growing. Read the tiered structure below as the *ancestor* of that shape, not as the live rule.

Everything else (the Research Lab's lifecycle, the both-or-neither dual-cost contract, the
one-at-a-time research rule, Attack and Defense Tech) is **unaffected** and remains current.

---

## Overview

Research / Tech is OVERCLOCK's progression lever: a small, flat set of three permanent unlocks —
**Attack Tech** (+1 attack, all units), **Defense Tech** (+1 defense, all units), and **Economy Tech**
(+1 **Credit** of income per turn for each completed Economy Outpost the player owns) — researched at a **Research Lab**, a fifth
structure type built through Base & Production's existing structure system (`build_cost`/`build_time`/
Under-Construction/Completed, destroyable with no refund while unfinished). A Lab researches one tech at
a time; building a second Lab lets a player parallelize two techs at once, at the price of the Credits, AP
surcharge, and board risk that entails. Like every other economic action in OVERCLOCK, researching is a
**dual-cost** commit — its `research_cost` in **Credits** (the banked economy currency) **plus** a small
per-tech **`ap_surcharge`** in AP, spent both or neither (pivot 2026-08-05: was a single shared AP pool;
the Credit price is the resource gate, the AP surcharge the tempo gate — see ap-economy.md). The player
engages with this system directly: *when* to divert Credits and tactical AP from units or outposts into a
permanent power spike is a real tempo decision with
the same texture as building an outpost. *Which* tech is largely an archetype-identity choice, not a
live 3-way toss-up every turn — Economy Tech is the boom archetype's signature pick, Attack/Defense
Tech the aggressive archetype's (see Player Fantasy and the "On 'which tech' as a decision" note in
Formulas). The system exists
to give the tempo duel a third axis beyond "more units" and "more economy" — a lever that rewards
patient, protected investment with a lasting edge, and punishes an undefended Lab exactly the way an
undefended Outpost is punished.

## Player Fantasy

Research is the **long bet** — the fantasy of choosing a permanent edge and defending it long enough to
cash in. Where an Economy Outpost pays back in a predictable few turns of extra Credits, a completed tech
never stops paying: every future attack lands harder, every future hit is shrugged off a little more,
every future turn earns a little more Credit income (pivot 2026-08-05: Economy Tech's benefit is now
Credit income per outpost, not the old outpost cost discount), for the rest of the match. That permanence is what makes the
choice feel weighty — you're not asking "what do I need this turn," you're asking "what do I want to
*be* for the rest of the game." The counterweight that keeps it a *bet* rather than a free power-up is
the one Base & Production already established: the Lab is exposed and worthless while under construction,
so committing to a tech is a declaration that you can protect this corner of the board for a few turns.
Landing that protection and watching your whole army hit one point harder, or your economy compound a
little faster — forever, for the rest of the match — is the payoff. It's Pillar 2 (*Tempo Is the Skill*)
expressed as patience.

**Honest framing (snowball — not a no-brainer, but not a comeback tool either).** A *completed* tech is a
permanent, army-wide, **un-raidable** edge — once banked it survives even if every Lab dies (Rule 8).
That makes Research a genuine **mid-game snowball lever**: a player who is already ahead can spend surplus
Credits (and the tactical AP for the surcharge) to bank a permanent advantage the loser (Credit- and
AP-starved, per Base & Production's closeout fixture) cannot
match — it *widens* a lead rather than closing one. This is intended: Research is the **reward for winning
the tempo duel**, not an equal-opportunity power-up, and this GDD does not pretend otherwise. The braking
force is entirely front-loaded — the *only* window to punish a tech is the vulnerable build+research
period before it completes (Rules 3–6). There is **no** Lab-count brake analogous to Base & Production's
closeout-drag answer; whether one is needed is carried into the vertical-slice economy spike and the
closeout re-run AC (Open Questions).

**"Which tech" is archetype identity, not a live 3-way toss-up.** The tech a player takes is largely
determined by *what they already are that game* — booming or pressuring — not re-decided fresh each
turn among three equally-live options. A player compounding an economic lead reaches for Economy Tech;
a player pressing an army advantage reaches for Attack or Defense Tech. This is intended, not a design
gap: it aligns Research with the game's rush/boom archetypes (the Pillar 4 seed) rather than pretending
all three techs are interchangeable sticks a player picks between on pure per-turn merit. The real
per-turn decision is *when* to divert Credits (and the tactical AP for the surcharge) into the tech that
matches your archetype (Overview), not
*which* of three symmetric options to pick.

> `creative-director` not consulted — Lean review mode. Review this framing manually before production.

## Detailed Design

### Core Rules

1. **A tech is an immutable data template** with: display name, `research_cost` (**Credits**),
   **`ap_surcharge`** (AP — the per-tech tempo cost charged when research is committed; default is the
   base `RESEARCH_AP_COST` (1, owned by AP & Credits Economy), overridable per tech; the three VS techs
   all default to 1), `research_time`
   (owner-turns to complete), and an effect. The three Vertical-Slice techs — **Attack Tech** (+1
   attack, all this player's units), **Defense Tech** (+1 defense, all this player's units), **Economy
   Tech** (+`ECONOMY_TECH_INCOME_BONUS` **Credits** of income per turn per completed Economy Outpost this player
   owns) — are **flat and unordered**: no prerequisites, researchable in any order, and each is a
   **one-time, permanent, per-player** unlock (not per-unit, not per-Lab). *(Pivot 2026-08-05: `research_cost`
   is now in Credits and the `ap_surcharge` field is new — see the PIVOT header note.)*

2. **The Research Lab is a fifth structure type**, built through **Base & Production's existing
   structure mechanics** unchanged: same `build_cost`/`build_time`/`hp` data shape, the same placement
   rule (empty passable tile adjacent to a friendly unit/structure, >2 tiles from every enemy
   structure), the same Under-Construction → Completed → Destroyed lifecycle, the same voluntary-cancel
   refund. Research owns the Lab's stat values and all tech data; Base & Production owns the generic
   structure state machine and placement/cancel rules the Lab reuses. *(Cross-system handoff: Base &
   Production's structure roster should list the Research Lab as its 5th entry — logged in
   Dependencies.)*

3. **A Completed Research Lab may research exactly one tech at a time.** Starting research
   (`start_research(lab, tech)`) is a **dual-cost, both-or-neither** commit (AP & Credits Economy Rule 11):
   it spends the tech's full `research_cost` **Credits** (via `credits_spend`) **and** its `ap_surcharge`
   **AP** (via `ap_spend`) **upfront** (mirroring how a structure's `build_cost` + `BUILD_AP_COST` are
   spent entirely at build time, not amortized) — legal only if the player can afford **both**
   (`credits_can_afford` AND `ap_can_afford`), and it spends both or neither. It then begins a
   `research_time`-owner-turn
   countdown; the tech enters **Under Research** at that Lab. An **Under-Construction** Lab cannot
   research (must be Completed first, same rule as producers in Base & Production).

4. **A tech may not be Under Research at two Labs simultaneously for the same player** (no benefit to
   racing yourself), and **a completed tech can never be re-researched** (the unlock is permanent and
   global to that player, not tied to any specific Lab). A player may build multiple Labs to research
   **different** techs in parallel — each Lab tracks its own `current_research_target` and
   `research_turns_remaining` independently.

5. **Research timer advance is a start-of-turn effect, ordered like Base & Production's build-timer
   advance.** At the owner's start-of-turn, each of their Labs' in-progress research turn counters
   decrement; any reaching 0 **completes that turn** — the tech's permanent effect (Rule 8) is live from
   that same turn onward (mirrors Base & Production's Rule 6 completion-before-snapshot ordering,
   generalized to "completion before any effect that reads it").

6. **If a Lab researching a tech is destroyed, that tech's progress is entirely lost.** The spent
   `research_cost` **Credits** are **not refunded** (the boom punish, matching Base & Production's
   under-construction-destruction rule), and the `ap_surcharge` AP was already spent as tempo (never
   refundable), and the tech's status reverts to **Not Started** — it may be
   attempted again later at any Completed Lab (this Rule does not permanently lock a tech out). A
   **completed** tech's effect is **never lost**, even if every Lab that ever housed it is later
   destroyed — the unlock lives on the player's tech-flag state, not on the Lab.
   **Trigger mechanism (added 2026-07-22, `/review-all-gdds` finding):** this revert has no separate
   scheduling — Combat's `attack()` and Base & Production's generic Rule 9 (hp → 0 → Destroyed, Grid
   `remove` invoked) already resolve structure destruction **synchronously within the same
   `apply_action` step** that caused it. This Rule is checked as part of that *same* resolution step:
   when a structure transitions to Destroyed, Research checks whether it was a Lab with
   `current_research_target != Idle` for its owner and reverts that tech to Not Started in the same
   step, before `apply_action` returns. No new event system or async hook is required — Base &
   Production's existing per-action mutation path (single `apply_action` call, no partial application) is
   the trigger; Research just adds one more state check to what that path already resolves.

7. **Voluntary cancel** of an in-progress research works exactly like Base & Production's structure
   cancel: `cancel_research(lab)` refunds `floor(research_cost × CANCEL_REFUND_RATE)` **Credits** (via
   `credits_credit`, reusing the same registered constant, 0.5); the `ap_surcharge` AP paid at commit is
   **not** refunded (the tempo is spent — matching how Base & Production's build-time AP surcharge is not
   refunded on cancel). The Lab returns to Idle, and the tech's status reverts to Not
   Started.

8. **Completed-tech effects are read live, not baked in.** `has_attack_tech(player)` and
   `has_defense_tech(player)` are boolean flags Unit System reads to compute
   `effective_attack`/`effective_defense` for every unit that player owns — instantly, the moment the
   tech completes, exactly like the existing `RESEARCH_ATK_BONUS` research-buff rule in Unit System
   (Core Rule 9, unchanged in spirit, now generalized to two independent flags instead of one). Economy
   Tech's income bonus is read live by **AP & Credits Economy** whenever it computes a researched player's
   `credit_income` — an extra `ECONOMY_TECH_INCOME_BONUS` **Credits** per completed Economy Outpost, up to
   `ECONOMY_TECH_TIER_THRESHOLD` (6, Economy-owned) outposts, added on top of AP & Credits Economy's existing
   tiered outpost bonus (pivot 2026-08-05: was `ap_income`; the resource is now Credits, values unchanged).

9. **Deterministic and headless.** Research start/cancel/timer-advance/completion are pure functions of
   game state and the chosen action — no RNG, stable order, computable on a `clone()` for AI look-ahead
   and headless tests.

### States and Transitions

**Research Lab lifecycle:** identical to Base & Production's generic structure lifecycle
(Under-Construction → Completed → Destroyed) — see `base-production.md` Core Rule 4 and States table;
not repeated here.

**Per-(player, tech) research state:**

| State | Meaning | Transitions to |
|-------|---------|----------------|
| Not Started | Tech not yet attempted, or a prior attempt was lost | **Under Research** (a Completed Lab calls `start_research`) |
| Under Research (at Lab L) | `research_turns_remaining` counting down at Lab L | **Completed** (timer reaches 0 at owner start-of-turn); **Not Started** (Lab L destroyed, or player cancels) |
| Completed | Permanent effect live for that player, globally | (terminal — cannot be re-researched, cannot be lost) |

**Per-Lab state:** `current_research_target` (a tech, or none/Idle) and `research_turns_remaining`,
reset to Idle when a tech completes, is cancelled, or the Lab itself is destroyed (moot — the Lab no
longer exists).

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Base & Production | Research Lab's `build_cost` (Credits)/`build_time`/`hp` (Research-owned values, using B&P's generic build/cancel/destroy mechanics — the Lab's build spends Credits + `BUILD_AP_COST` 2 AP) | Research Lab as a placeable/destroyable structure | Base & Production owns the structure state machine; Research owns the Lab's own stats |
| AP & Credits Economy | `credits_can_afford`/`credits_spend` for `research_cost` (Credits) + `ap_can_afford`/`ap_spend` for the tech's `ap_surcharge` (both-or-neither); cancel refund credits the **Credit** pool; **Economy Tech adds `ECONOMY_TECH_INCOME_BONUS × min(completed_outpost_count(player), ECONOMY_TECH_TIER_THRESHOLD)` to a researched player's `credit_income`** | the Economy-Tech income term (`has_economy_tech` + the per-outpost bonus value) | AP & Credits Economy owns both pools + the `credit_income` formula + the `RESEARCH_AP_COST` base + the `ECONOMY_TECH_TIER_THRESHOLD` cap; Research owns `research_cost`, each tech's `ap_surcharge` override, the Lab's `build_cost`, and the Economy-Tech income-bonus value |
| Unit System | `has_attack_tech(player)`, `has_defense_tech(player)` read to compute `effective_attack`/`effective_defense` | — | Research owns the two flags; Unit System owns the formulas that consume them (handoff — see Dependencies) |
| Combat Resolution | consumes `effective_attack` (existing) and the new `effective_defense` as the `defense(defender)` term — **no formula change in Combat**, since `defense` was already generic | — | Combat's damage formula is unchanged; Unit System now populates a previously-always-0 field |
| Game State & Turn Manager | research-timer advance applied as a start-of-turn effect (interleaved with Base & Production's build-timer advance); `apply_action` for start/cancel | updated Lab/tech state | Turn Manager owns start-of-turn sequencing |

**Public interface:** `legal_research_targets(lab) -> set<tech>` (excludes already-Completed and
already-Under-Research-elsewhere techs) · `start_research(lab, tech) -> Result` ·
`cancel_research(lab) -> Result` · `has_attack_tech(player) -> bool` · `has_defense_tech(player) -> bool` ·
`has_economy_tech(player) -> bool` (AP & Credits Economy reads it to add the per-outpost Credit-income bonus).

## Formulas

Research is a **data/state** system — its "formulas" are the Research Lab template, the tech templates,
and the two new **effect formulas** (`effective_defense`, the Economy Tech income bonus) plus the reused
`cancel_refund`. It introduces **no new combat math**: Attack Tech feeds the existing `effective_attack`;
Defense Tech populates the `defense` term Combat's formula already reads; Economy Tech adds a term to AP
& Credits Economy's `credit_income` (pivot 2026-08-05: was `ap_income`).

### Research Lab template (a Base & Production structure)

| Field | Value | Notes |
|-------|-------|-------|
| `hp` | 12 | Defensible enough that the no-refund destruction punish isn't a free raid |
| `build_cost` | 8 Credits (+ `BUILD_AP_COST` 2 AP) | Capstone structure — just under the Production Outpost (9 Credits). Built through B&P's **structure** dual-cost (Credits main + the standard build AP surcharge), **not** the per-tech research `ap_surcharge` (pivot 2026-08-05) |
| `build_time` | 2 owner-turns | Uses Base & Production's generic build lifecycle |
| `defense` | 0 | Structure-owned (Combat's shared field), like the outposts |
| `can_counterattack` | false | Not an attacker |

### Tech templates

| Tech | `research_cost` (Credits) | `ap_surcharge` (AP) | `research_time` (turns) | Effect |
|------|---------------------------|---------------------|-------------------------|--------|
| **Attack Tech** | 10 | 1 | 3 | `has_attack_tech(player) = true` → +`RESEARCH_ATK_BONUS` (1) attack, all that player's units |
| **Defense Tech** | 10 | 1 | **4** | `has_defense_tech(player) = true` → +`DEFENSE_TECH_BONUS` (1) defense, all that player's units |
| **Economy Tech** | 7 | 1 | 3 | `has_economy_tech(player) = true` → +`ECONOMY_TECH_INCOME_BONUS` (1) Credit/turn income **per completed Economy Outpost, up to `ECONOMY_TECH_TIER_THRESHOLD` (6)** (added to AP & Credits Economy's `credit_income`) |

Research is a **dual-cost, both-or-neither** action (pivot 2026-08-05): `research_cost` **Credits** (the
resource gate) **plus** `ap_surcharge` **AP** (the tempo gate), spent both or neither. The `ap_surcharge`
column defaults to the base `RESEARCH_AP_COST` (1, owned by AP & Credits Economy); the override mechanism
exists so different techs can carry different tempo costs, but all three VS techs default to 1 for now.
Defense Tech's extra turn (4 vs 3) deliberately delays its power spike so it can't hard-counter the
Scout-rush opening too early — the risk is priced into *time*, not cost.

> **On "which tech" as a decision.** Attack and Defense Tech are deliberately symmetric flat +1 sticks —
> between those two the real decision is *timing* (when to divert Credits + the AP surcharge) and *order*
> under single-Lab Credit/AP scarcity, not a game-shaping identity. **Economy Tech is the differentiator**: after the 2026-07-21
> retune it *scales with the boom* (income per completed Economy Outpost), so it is the boom archetype's
> signature tech and a genuinely different investment class, not a third interchangeable stick. Widening
> Attack/Defense into non-interchangeable identities (per-Lab specialization, one-tech-per-player
> exclusivity) is a reserved Alpha lever (Open Questions / tuning toggles).

**Tempo-cost honesty (opportunity cost of opening Research).** Standing up any tech costs the Lab
(8 Credits + `BUILD_AP_COST` 2 AP / 2 build-turns) *plus* the tech (7–10 Credits + `ap_surcharge` 1 AP /
3–4 research-turns) — **15–18 Credits plus 3 AP of surcharge, across ~5–6 turns of
board-presence-free exposure** before any payoff (pivot 2026-08-05: the ~15–18 that used to be one AP
pool is now the Credit spend; the tempo cost is the small combined 3-AP surcharge). Compare: an Economy
Outpost breaks even in 3 turns
total (Base & Production), a Production Outpost pays off the turn it completes. Research is deliberately
the slowest, most Credit-committed, most-exposed investment in the game — the "long bet." That is the
intended texture, but it also means Research is rarely a correct *first* pick over units/outposts; it is
a *second-order* spend by a player who has already secured board presence and surplus Credits.

### Named constants (Research-owned)

| Constant | Value | Unit | Description |
|----------|-------|------|-------------|
| `RESEARCH_ATK_BONUS` | 1 | attack | Flat attack added to all a researched player's units. **Already referenced by `effective_attack` (Unit System)** — this GDD formally owns and registers it. |
| `DEFENSE_TECH_BONUS` | 1 | defense | Flat defense added to all a researched player's units. **Provisional / playtest-gated** — see Open Questions (floor-lock). |
| `ECONOMY_TECH_INCOME_BONUS` | 1 | Credits/turn per outpost | Extra income per completed Economy Outpost while Economy Tech is held (added to `credit_income`). **Hold at 1** — 2 roughly doubles the per-outpost income and hard-snowballs; validate the raised ceiling in the economy spike. (Pivot 2026-08-05: was AP/turn; now Credits/turn, value unchanged.) |
| `ap_surcharge` (per-tech field, not a single constant) | 1 (all 3 VS techs) | AP | The per-tech AP tempo cost charged when research is committed (dual-cost alongside `research_cost` Credits). Defaults to the base `RESEARCH_AP_COST` (1, **AP & Credits Economy-owned**); Research owns each tech's override. All VS techs default to 1 for now. |

### `effective_defense(unit)` — the new Defense-Tech formula (mirrors `effective_attack`)

`effective_defense(unit) = unit.base_defense + (owner_has_defense_tech ? DEFENSE_TECH_BONUS : 0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `unit.base_defense` | — | int | 0 (all VS units) | The unit's template defense (Unit-owned; 0 for the whole VS roster) |
| `owner_has_defense_tech` | — | bool | — | Whether the unit's owner completed Defense Tech |
| `DEFENSE_TECH_BONUS` | — | int const | 1 | Research-owned bonus |
| `effective_defense` | — | int | 0–1 (VS) | The `defense(defender)` term Combat's `damage_formula` consumes |

**Output range:** 0 (un-researched) to 1 (researched). **Example:** a researched player's Trooper has
`effective_defense = 0 + 1 = 1`, so an enemy unresearched Scout deals `max(1, 2 − 0 − 1) = 1`.

> **Cross-system handoff (Unit System #4):** this formula is the exact mirror of `effective_attack`.
> Unit System should own `effective_defense` alongside `effective_attack` (both are unit-owned derived
> values Research feeds a flag into); Combat reads its output through the already-generic
> `defense(defender)` term — **no Combat change**. Flagged in Dependencies.

### `economy_tech_income_bonus(player)` — Economy Tech's boom-scaling income effect

`economy_tech_income_bonus(player) = has_economy_tech(player) ? ECONOMY_TECH_INCOME_BONUS × min(completed_outpost_count(player), ECONOMY_TECH_TIER_THRESHOLD) : 0`

This term is **added to `credit_income` (owned by AP & Credits Economy)** (pivot 2026-08-05: was
`ap_income`): a researched player earns an extra
`ECONOMY_TECH_INCOME_BONUS` Credits per turn for **each completed Economy Outpost** they own, up to
`ECONOMY_TECH_TIER_THRESHOLD` outposts, on top of AP & Credits Economy's existing tiered outpost bonus.
(Effectively each of the first 6 Economy Outposts' income rises from +2/+1 to +3/+2 for a researched
player; the 7th and beyond get no further tech bonus.)

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `ECONOMY_TECH_INCOME_BONUS` | — | int const | 1 | Research-owned Credits/turn granted per completed Economy Outpost, up to the cap below |
| `ECONOMY_TECH_TIER_THRESHOLD` | — | int const | 6 | **AP & Credits Economy-owned** — number of completed Economy Outposts the bonus applies to before it stops accruing (added 2026-07-22, Economy's own re-review) |
| `completed_outpost_count(player)` | `n` | int | 0 – (board-limited) | Completed, alive, owned Economy Outposts — the **same** query `credit_income` uses (Base & Production-owned) |
| `economy_tech_income_bonus` | — | int | 0 – 6 | Extra Credits/turn added to the researched player's income, capped at `ECONOMY_TECH_INCOME_BONUS × ECONOMY_TECH_TIER_THRESHOLD` |

**Output range:** 0 (un-researched, **or** no completed Economy Outposts) up to 6 (capped at
`ECONOMY_TECH_TIER_THRESHOLD` outposts). It is **time-scaling and boom-scaling up to the cap** — it pays
nothing until the player has both researched *and* built Economy Outposts, and grows with the boom until
the 6th outpost, after which further outposts add nothing more from this term (they still earn the base
tiered bonus). **Payback:** cost 7 Credits (+ 1 AP surcharge, a one-time tempo cost not part of the Credit
ROI); at `n ≤ 6` completed outposts it returns `n` Credits/turn, so break-even
≈ `ceil(7 / n)` turns from completion (e.g. 3 outposts → ~2–3 turns); past 6 outposts, payback is fixed
at `ceil(7/6) ≈ 2` turns and does not improve further.

> **Cross-system handoff (AP Economy #3) — RESOLVED 2026-07-22 (resource re-denominated by the 2026-08-05
> pivot: this term now feeds `credit_income`, not `ap_income`; values unchanged).** Economy Tech modifies
> `credit_income`
> directly — AP & Credits Economy's income formula gains the optional
> `+ (has_economy_tech(player) ? ECONOMY_TECH_INCOME_BONUS × min(n, ECONOMY_TECH_TIER_THRESHOLD) : 0)`
> term. AP Economy's 2026-07-22 re-review found the term, as originally added uncapped, structurally
> cancelled AP Economy's own diminishing-returns brake past `n=4` — fixed by AP Economy adding
> `ECONOMY_TECH_TIER_THRESHOLD` (6), its own brake on this term. Practical income ceiling is now **≈32**
> (was ≈38 uncapped, ≈26 with no Economy Tech). `ECONOMY_TECH_INCOME_BONUS` (this doc's own value, 1) is
> unchanged. Economy-designer's separate finding that Economy Tech may still be the dominant tech choice
> for a boomed player (vs. Attack/Defense Tech) was **not** fixed by this cap; it is now **DECIDED
> 2026-07-22 (`/review-all-gdds` D-1): accepted as archetype identity** (Economy Tech = boom's signature
> tech, not a defect — see the Overview + Player Fantasy reframe) **with a pre-committed lifetime-cap
> reserve lever gated on a joint-curve simulation** (see Open Questions). The term + capped output range
> were synced to `ap-economy.md` 2026-07-22; AP Economy's re-review is now resolved.

> **Cross-system handoff (Base & Production #7, Approved) — reconciled in-file, RE-REVIEW OWED:** the
> *previous* Economy Tech design discounted Economy Outpost `build_cost` (4→3); that hook is **removed** —
> Economy Outpost cost is now a flat 4 with no research discount. Base & Production's Core Rule 2
> `economy_outpost_discount` note was updated this session; B&P re-review is owed. Flagged in Dependencies.

### `cancel_refund` (reused, not new)

Reuses Base & Production's registered `CANCEL_REFUND_RATE` (0.5, floor): cancelling in-progress research
refunds `floor(research_cost × 0.5)` **Credits** → Attack **5**, Defense **5**, Economy **3** (the
`ap_surcharge` AP paid at commit is **not** refunded). Cancelling a Lab
build (Under-Construction) refunds `floor(8 × 0.5) = 4` **Credits** (the Lab's `BUILD_AP_COST` 2 AP is
likewise not refunded).

### Compounding sanity check (both the asymmetric AND the mirror case)

A researches **both** Attack (+1) and Defense (+1). Structure shots-to-kill are barely shifted (a
researched Sniper takes the HQ 10→8 hits — no cliff, nothing one-shots).

The flagged risk is **unit-vs-unit on Cover**, and it is worse than a one-sided edge — it **persists into
the mirror match** where both players have researched (the realistic mid/late state this system produces,
since both sides can afford the same techs — equal Credits plus the AP surcharge):

- **Asymmetric (A researched, B not):** A's Scout/Trooper on Cover (defense 1 + COVER_DR 1 = 2) floor-locks
  B's un-researched Scout (atk 2) and Trooper (atk 3) to `max(1, …)` = **1 damage**.
- **Mirror (both researched):** a researched **Scout** attacking (effective_attack 3) *still* floor-locks
  against a researched defender on Cover: `max(1, 3 − 1 − 1) = 1`. **The Scout — the cheapest, most-produced
  unit — is a permanent 1-damage matchup vs a Cover+Defense-Tech defender that *no attacker investment can
  escape*.** A researched Trooper (effective_attack 4) escapes to `max(1, 4 − 2) = 2` only because of its
  *own* Attack Tech; the Scout has no such out.

So **half the base roster (Scout, Trooper) floor-locks vs a Cover+Defense-Tech defender**, and the Scout
does so **structurally** (independent of attacker tech). This is never *unkillable* (the min-1 floor still
grinds), but two different attacks reading as identical 1-damage is a direct hit to Pillar 3 legibility.
It is the `defense + COVER_DR < lowest effective_attack` constraint Combat flagged, now made live by
Defense Tech. **`DEFENSE_TECH_BONUS` is therefore provisional/playtest-gated with a pre-committed fallback
lever (non-stacking mitigation)** — see Open Questions.

## Edge Cases

**Research start & legality:**
- **If a player tries to research at an Under-Construction Lab**: rejected — only a Completed Lab can
  research (mirrors Base & Production's "producers must be Completed").
- **If a player tries to research a tech already Completed** (for that player): rejected — the unlock is
  permanent and global; re-researching does nothing and is never offered (`legal_research_targets`
  excludes it).
- **If a player tries to research a tech already Under Research at another of their Labs**: rejected — a
  tech may be in progress at only one Lab per player at a time (`legal_research_targets` excludes it).
  No benefit to racing yourself.
- **If a player cannot afford *either* `research_cost` (Credits) *or* the tech's `ap_surcharge` (AP)**:
  rejected, nothing spent from either pool, no research started — a **both-or-neither** dual-cost gate
  (AP & Credits Economy's `credits_can_afford` AND `ap_can_afford` + `apply_action` atomicity).
- **If a Lab is already researching a tech** and the player starts another: rejected — one tech at a
  time per Lab. The player must build a second Lab to parallelize.

**Timer, completion & effect:**
- **If a tech's timer reaches 0 at the owner's start-of-turn**: it transitions to Completed **before**
  any effect that reads it that turn — a unit's `effective_attack`/`effective_defense` and Economy
  Outpost cost all reflect it from that turn on (mirrors Base & Production's build-completion-before-
  snapshot ordering).
- **If a tech and a Base & Production Economy Outpost complete on the same start-of-turn**: both
  start-of-turn advances (research timers and build timers) process before the income snapshot and
  before any actions (Game State & Turn Manager Core Rule 3: step 3 covers *all* start-of-turn effects,
  step 4 is the income snapshot — step 4 strictly follows step 3 as a whole). **Corrected 2026-07-22
  (`/review-all-gdds` finding):** this does NOT mean the research-timer and build-timer advances are
  "disjoint state, order-irrelevant" — that claim is false for **Economy Tech**, whose completion flips
  `has_economy_tech`, a direct term in AP & Credits Economy's `credit_income` (pivot 2026-08-05: was
  `ap_income`). The reason the outcome is still
  correct regardless of intra-step-3 order is narrower: Rule 3's *step boundary* (all of step 3 finishes
  before step 4 begins) guarantees the income snapshot observes both a newly-Completed Economy Outpost
  AND a newly-completed Economy Tech, no matter which one's timer advance ran first within step 3. Attack
  and Defense Tech genuinely are disjoint from the income snapshot (they touch unit buffs, not
  `credit_income`) — only Economy Tech's completion is income-affecting and depends on this step-boundary
  guarantee rather than true state-disjointness.
- **If a unit is produced after its owner has completed Attack/Defense Tech**: the new unit gets the
  bonus immediately — effects are read live from the owner's tech flags, not baked at unit creation
  (consistent with Unit System's existing live-research rule).
- **If Attack Tech completes mid-way through the owner's turn** — it cannot: research only completes at
  start-of-turn (Rule 5), never mid-action, so a unit's damage never changes between selecting and
  committing an attack *on the same turn* due to research.

**Destruction & loss:**
- **If the Lab researching a tech is destroyed**: that tech's progress is entirely lost — the
  `research_cost` **Credits** are **not refunded** (and the `ap_surcharge` AP was already spent as tempo),
  the tech reverts to **Not Started**, and it may be re-attempted later at any
  Completed Lab (not permanently locked out).
- **If a player has two Labs each researching a different tech and one is destroyed**: only that Lab's
  tech is lost; the other Lab's research is unaffected (each Lab tracks its own target/timer
  independently).
- **If a Lab is destroyed after its tech has already Completed**: no effect on the tech — a completed
  unlock lives on the player's tech-flag state, not the Lab, and is never lost even if every Lab is
  destroyed.
- **If an Under-Construction Lab (not yet Completed, so not yet researching) is destroyed**: standard
  Base & Production structure-destruction — `build_cost` lost, no refund; no tech was in progress to
  lose.

**Cancel:**
- **If a player cancels an in-progress research**: `floor(research_cost × 0.5)` **Credits** is refunded
  (Attack/Defense 5, Economy 3) via `credits_credit`; the `ap_surcharge` AP is **not** refunded (tempo is
  spent). The Lab returns to Idle, and the tech reverts to Not Started. The Lab
  itself is unaffected (still Completed and usable).
- **If a player tries to cancel research at an Idle Lab** (nothing in progress): no-op / rejected —
  there is nothing to cancel.
- **If a cancel and a destruction target the same Lab in the same resolution step**: **destruction wins**
  — a Lab removed from the board that step cannot then be the target of a `cancel_research` (there is no
  structure to cancel; the cancel is rejected as targeting a non-existent Lab). A destroyed mid-research
  Lab follows the **no-refund destruction** rule (Rule 6), never the 50% cancel refund — so there is no
  double-refund and no refund-then-destroy ambiguity.

**Effect-interaction edge cases:**
- **If a player researches both Attack and Defense Tech**: both flags are true and both bonuses apply to
  all their units simultaneously (+1 atk, +1 def). Combined with Cover, their units' `defense + COVER_DR`
  reaches 2 — floor-locking low-attack enemies to 1 damage (the flagged legibility risk; not a rule
  violation — the min-1 floor still resolves it).
- **If Defense Tech's +1 would reduce incoming damage below `MIN_DAMAGE`**: it clamps to 1, exactly like
  any other mitigation — Defense Tech never makes a unit unkillable, only harder to kill (Combat's floor
  is authoritative).
- **If Economy Tech is researched but the player owns no completed Economy Outposts**: the income bonus is
  0 (`ECONOMY_TECH_INCOME_BONUS × 0`) — the tech pays nothing until the player has both researched *and*
  completed at least one Economy Outpost. It is a boom-synergy tech, worthless to a pure rusher.
- **If a researched player's Economy Outpost is destroyed**: the Credit-income bonus drops by
  `ECONOMY_TECH_INCOME_BONUS` at that player's **next** start-of-turn income snapshot — the bonus tracks
  the *live* completed-outpost count exactly like AP & Credits Economy's base tiered bonus (frozen per turn, not
  recomputed mid-turn; a mid-turn loss is picked up at the next reset).
- **If Economy Tech completes the same start-of-turn an Economy Outpost completes**: both the research-timer
  and the build-timer advance run **before** the income snapshot (Turn Manager Core Rule 3), so that turn's
  income already reflects the tech *and* the newly-completed outpost — the bonus is applied that turn, not a
  turn late.
- **If the Research Lab type is asked to produce a unit or boost income**: it does neither — the Lab only
  researches; it is not a producer (`production_cap = 0`) and does not feed `completed_outpost_count`.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| AP & Credits Economy | Hard | `credits_can_afford`/`credits_spend` for `research_cost` (Credits) + `ap_can_afford`/`ap_spend` for the tech's `ap_surcharge` (both-or-neither); the Lab's `build_cost` follows B&P's structure dual-cost (Credits + `BUILD_AP_COST`); cancel refund credits the **Credit** pool; owns the base `RESEARCH_AP_COST` (1) the per-tech `ap_surcharge` defaults to |
| Base & Production | Hard | The Research Lab is a 5th structure built entirely through B&P's generic structure mechanics (placement, build-timer, Under-Construction/Completed/Destroyed lifecycle, voluntary cancel — its build spends Credits + `BUILD_AP_COST`). Research supplies the Lab's stat values; B&P owns the state machine |
| Game State & Turn Manager | Hard | `start_research`/`cancel_research` applied via `apply_action`; research-timer advance runs as a start-of-turn effect (interleaved with B&P's build-timer advance); clonable state for AI/tests |
| Unit System | Hard | Owns `base_defense` (0 all VS units) and the `effective_attack`/`effective_defense` formulas Research feeds flags into |

**Downstream (systems that depend on this — all HARD):**

| System | What it needs from Research |
|--------|----------------------------|
| Unit System | `has_attack_tech(player)` / `has_defense_tech(player)` flags, read live to compute `effective_attack`/`effective_defense` *(reciprocal: Unit System is also upstream — it owns the formulas)* |
| Combat Resolution | Consumes the buffed `effective_attack` and `effective_defense` through its **already-generic** `damage_formula` — **no Combat change** |
| AP & Credits Economy | `has_economy_tech(player)` + `ECONOMY_TECH_INCOME_BONUS` read when computing a researched player's `credit_income` (per completed Economy Outpost) *(reciprocal: AP & Credits Economy is also upstream — it owns both pools + `credits_spend`/`ap_spend`)* |
| Command & Action Interface (#9) | Research options, `research_cost`/`research_time`, in-progress timers, `legal_research_targets` |
| Game HUD (#10) | Tech status (Not Started / Under Research / Completed), research progress, active buffs |
| AI Opponent (#11) | Research start/cancel actions and their legal-target/affordability queries for planning |
| Faction Identity (#12) | May differentiate which techs exist, their costs, or their bonuses per faction |

*(Bidirectional note: AP & Credits Economy, Game State, Unit System, and Base & Production currently reference
Research / Tech only provisionally. This GDD is the first to make the interfaces concrete; the
reciprocal edges are logged as handoffs below and should be wired when those GDDs next update.)*

**Cross-system handoffs owed (from this GDD):**
1. **→ Unit System (#4, Approved):** (a) add the **`effective_defense`** formula (exact mirror of
   `effective_attack`); (b) generalize the single research flag its `effective_attack` assumes into
   **two independent flags** (`owner_has_attack_tech`, `owner_has_defense_tech`) — Unit System's own
   text already anticipated this ("if Research wants... this boolean formula... must be revised — flag it
   back to Unit System"). `base_defense` (0, all units) already exists. Consider
   `/propagate-design-change` on `unit-system.md`.
2. **→ Base & Production (#7, Approved) — Research Lab LANDED; discount-removal reconciled, RE-REVIEW
   OWED:** the **Research Lab** 5th-structure entry (hp 12 / cost 8 / time 2) already landed (B&P Core Rule
   2b). **Revision applied this session:** the earlier Economy-Tech `build_cost` discount hook
   (`economy_outpost_discount`, 4→3) is **removed** by the Economy Tech retune — Economy Outpost cost is a
   flat 4 with no research discount. B&P Core Rule 2's note was updated to say so; Economy Tech now flows
   through AP & Credits Economy's Credit income, not B&P's cost. B&P re-review owed (its number surface is unchanged, but the
   removed hook should be confirmed).
3. **→ AP & Credits Economy (#3) — cost purity (pivot 2026-08-05: `research_cost` is now a Credit spender,
   plus the per-tech `ap_surcharge` AP spender):** both are concrete deterministic-constant
   spenders; AP & Credits Economy's "downstream cost functions must be pure (no RNG)" contract applies —
   Research's costs are deterministic constants, so it complies. Both legs run through the both-or-neither
   dual-cost commit.
4. **→ AP & Credits Economy (#3) — Economy Tech income term, RE-REVIEW RESOLVED 2026-07-22 (re-denominated
   to Credits by the 2026-08-05 pivot; values unchanged):**
   Economy Tech adds `ECONOMY_TECH_INCOME_BONUS × min(completed_outpost_count(player),
   ECONOMY_TECH_TIER_THRESHOLD)` to a researched player's `credit_income`. AP & Credits Economy owns `credit_income`; its
   re-review found the term as originally added (uncapped) structurally cancelled its own
   diminishing-returns brake past `n=4`, and fixed it by adding `ECONOMY_TECH_TIER_THRESHOLD` (6,
   AP-Economy-owned) — practical income ceiling is now ~32 (was ~38 uncapped, ~26 with no Economy Tech).
   AP Economy's formula, variable table, output range, Tuning Knobs, and 4 new acceptance criteria were
   updated 2026-07-22; **AP Economy's re-review is resolved.**

**Provisional (undesigned dependents):** Command & Action Interface (#9), Game HUD (#10), AI Opponent
(#11), Faction Identity (#12) — each lists Research / Tech under its Dependencies when authored.

### ★ Reciprocal downstream — the wave-2 systems (added 2026-08-24, S6-09)

Cross-review **W-1**: All 3 systems below declare a dependency on this document, and this
document listed none of them. Reciprocity was **0/11 across the corpus** — every new GDD pointed
up, no old GDD pointed back, so reading only this file gave no hint that changing it would break
them. Restored mechanically; the relationship nature is copied from each new GDD's own
Dependencies table, which remains the authority.

| Downstream system | Nature |
|---|---|
| **Promotion & Veterancy (#21)** | Hard |
| **Population Cap (#16)** | Soft |
| **Unit Upkeep (#15)** | Soft |

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `RESEARCH_LAB_HP` | 8–16 | 12 | How raid-able the Lab is vs. the no-refund punish | Lab too safe → research is a free power spike | Lab dies to one Scout raid → the harsh no-refund rule feels unfair |
| `RESEARCH_LAB_BUILD_COST` | 6–10 | 8 | Barrier to entering the tech game | Research never worth opening | Every game opens with a Lab, tech becomes mandatory |
| `RESEARCH_LAB_BUILD_TIME` | 1–3 | 2 | Exposure window before the Lab can research | Lab arrives too slowly to matter in short games | Lab is up almost instantly, little commitment |
| `ATTACK_TECH_COST` | 8–12 | 10 | When an attack spike is affordable (**Credits** — pivot 2026-08-05) | Attack Tech skipped in fast games | Too cheap → always researched, trivializes the choice |
| `ATTACK_TECH_TIME` | 2–4 | 3 | Delay before the +1 atk lands | Spike arrives too late to swing a game | Instant army-wide buff, too swingy |
| `DEFENSE_TECH_COST` | 8–12 | 10 | When a defense spike is affordable (**Credits** — pivot 2026-08-05) | Skipped | Always taken |
| `DEFENSE_TECH_TIME` | 3–5 | **4** | Delay before +1 def lands — **anti-early-rush brake** | Defense Tech irrelevant (too late) | ≤3 → hard-counters the Scout-rush opening too early (the flagged risk) |
| `ECONOMY_TECH_COST` | 5–9 | 7 | When the income tech is affordable (**Credits** — pivot 2026-08-05) | Skipped by boom players | Always taken by boomers |
| `ECONOMY_TECH_TIME` | 2–4 | 3 | Delay before the income bonus starts | Bonus arrives too late to compound | Instant economy acceleration |
| `RESEARCH_ATK_BONUS` | 1–2 | 1 | Magnitude of the attack spike | 2 → shots-to-kill cliffs (a Trooper 1-shots a Scout that a base Trooper 2-shots); rebalances the whole roster | 1 is the floor for a meaningful buff |
| `DEFENSE_TECH_BONUS` | 0–1 | **1** | Magnitude of the defense spike | **>1 → `defense + COVER_DR` ≥ several units' attack → widespread floor-locking, breaks combat legibility (Combat's defense-stacking constraint)** | 0 → Defense Tech does nothing |
| `ECONOMY_TECH_INCOME_BONUS` | 1–2 | **1** | **Credits**/turn income per completed Economy Outpost, up to `ECONOMY_TECH_TIER_THRESHOLD` (pivot 2026-08-05: was AP/turn) | **2 → roughly doubles the capped bonus (ceiling ~32→~38), narrows the diminishing-returns band** | 0 → Economy Tech does nothing |
| `ECONOMY_TECH_TIER_THRESHOLD` | 4–8 | **6** | **AP & Credits Economy-owned** — outposts the Credit-income bonus applies to before it stops accruing (added 2026-07-22 re-review, restores the diminishing-returns brake) | Effectively unbounded again → the untiered-snowball defect this cap exists to close reappears | Economy Tech feels weak, undermining its differentiator role |
| per-tech `ap_surcharge` | 0–4 | **1** (all 3 VS techs; base `RESEARCH_AP_COST`) | Tempo (AP) cost of committing a research — the tech's slice of the tactical turn (pivot 2026-08-05) | Teching crowds out fighting; research too tempo-expensive to open | Teching has no tactical cost; a full Credit war chest tech-dumps in one turn |

**Design-rule toggles (fixed for the VS):**

| Toggle | VS Value | Notes |
|--------|----------|-------|
| Tech tree shape | Flat, no prerequisites, all researchable | Widening to a branching/prereq tree is an Alpha lever; keeps VS shallow |
| Techs per Lab at once | 1 | Parallelism comes from building multiple Labs, not a per-Lab queue |
| Tech scope (which effects exist) | {Attack, Defense, Economy} | Faction Identity may vary this per faction (Open Question) |
| Structure attack research-buff | OFF | Research buffs **units** only; structure `attack` (Defensive Structure) is unaffected — consistent with Base & Production's Open Question |
| Refund on destruction | none | Reuses B&P's no-refund rule; voluntary cancel refunds via `CANCEL_REFUND_RATE` |

> `DEFENSE_TECH_BONUS` and `ECONOMY_TECH_INCOME_BONUS` are the two **playtest-critical** knobs —
> `DEFENSE_TECH_BONUS` has a hard ceiling (1) above which the Cover floor-lock widens (Open Questions), and
> `ECONOMY_TECH_INCOME_BONUS` amplifies the income snowball within the band `ECONOMY_TECH_TIER_THRESHOLD`
> caps (the retune raised the ceiling ~26→~38, and AP Economy's 2026-07-22 re-review capped it back down
> to ~32 by tiering the term; at `ECONOMY_TECH_INCOME_BONUS=2` it would hard-snowball again even with the
> cap). Treat 1 as the locked value for both, not a midpoint. `research_cost`/`research_time` interact
> with match length: re-validate against `MAX_ROUNDS` and typical game length in the vertical slice — a
> tech that never has enough turns left to pay off is dead.

## Visual/Audio Requirements

The Research Lab is a fixed neon structure; the tech effects are felt through the units they buff, not
through Research's own visuals. Anchored to **Neon Retro-Future** (presentation owned by Command &
Action Interface #9 / HUD #10):
- **Research Lab silhouette (Anchor Principle 1):** distinguishable by **shape alone** from the other
  four structures — reads "lab/antenna/data-spire," visually the least martial of the five. Faction-hued
  (Principle 2). Reuses Base & Production's **Under-Construction build-state treatment**
  (translucent/scaffold + build-progress indicator) unchanged.
- **Research-in-progress readout:** a Completed Lab actively researching shows a **distinct "working"
  state** (e.g. a pulsing neon core + a turns-remaining indicator) so an opponent can *see* a tech is
  coming — the same information-transparency the whole readable-board pillar demands (an enemy should be
  able to read that you've committed to a tech, and roughly when it lands).
- **Tech-complete flourish:** a one-time neon "unlock" pulse from the Lab when a tech completes, and —
  because the effect is army-wide — a brief, subtle shared cue across the owner's units (a flicker in
  their faction hue) so the player *feels* the whole army just got stronger. Keep it subtle: this fires
  once per tech, not every combat.
- **Buffed-unit read:** researched units should carry a small persistent tech marker (owned by HUD) so
  both players can tell at a glance which army is teched — the deterministic-combat pillar means the
  opponent should be able to account for the +1 when reading a shot.
- **Destruction:** a Lab destroyed mid-research gets the standard structure death-burst; if a tech's
  progress is lost, that should read as a distinct "research lost" beat (not just a structure dying) so
  the sunk-Credits punish lands emotionally.
- Audio: a research-start cue, a low "working" ambient loop while a Lab researches, a satisfying
  tech-complete sting, and a "research lost" downer if a mid-research Lab dies (specs owned by the audio
  pass).

> `art-director` not consulted — Lean review mode; Research/Tech is not a mandatory-visual category.
> Review this framing manually before production.

> 📌 **Asset Spec** — Visual/audio requirements defined. After the art bible is approved, run
> `/asset-spec system:research-tech` for the Research Lab silhouette, research-in-progress/complete
> states, and audio cues.

## UI Requirements

Research feeds the pre-commit action menu like every other spend. Research owns the **data**; #9/#10 own
presentation:
- **Research menu** (on selecting a Completed Lab): the legal techs (`legal_research_targets`) with their
  **dual cost** (`research_cost` **Credits** + `ap_surcharge` **AP**) and `research_time`, affordability-gated
  on **both** pools (a tech affordable in Credits but not the AP surcharge, or vice-versa, shows
  unavailable — both-or-neither); Completed and already-in-progress techs shown
  as unavailable with a reason (done / in progress elsewhere). *(Pivot 2026-08-05: research is now a
  dual-cost spend — the menu must surface both the Credit price and the AP surcharge.)*
- **Tech status panel:** each tech's state (Not Started / Under Research + turns remaining / Completed)
  and the active buffs the player currently has.
- **In-progress timer** on each researching Lab (turns remaining), mirroring Base & Production's
  build-progress readout.
- **Cancel affordance:** cancelling in-progress research shows the Credit refund (`floor(research_cost × 0.5)`
  Credits; the AP surcharge is not refunded) **before** confirming, mirroring Movement/Combat/Base &
  Production's cancel pattern.

Presentation and interaction are owned by GDDs #9 and #10; this system provides the queries and data.

> 📌 **UX Flag — Research/Tech**: The research menu, tech-status panel, and progress timers are core to
> readability. In Phase 4 (Pre-Production), run `/ux-design` for the core action interface **before**
> writing epics; stories should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

> Research / Tech is a **mixed Logic/Integration** system (same pattern as Base & Production). BLOCKING
> gate = the Pure-Logic suite (deterministic, injected Grid + AP + Lab/tech fixtures, no file I/O) plus
> Integration ACs needing real dependencies. **Handoff status:** both cross-system handoffs have
> **LANDED** — Unit System's flag-split + `effective_defense` (Unit System #4, Approved) and Base &
> Production's Research Lab 5th-structure entry (Base & Production #7, Approved) — so **every Integration
> AC below is testable now** (none are blocked). *(The 2026-07-21 Economy Tech retune replaces the old
> `economy_outpost_discount` hook with an AP Economy income-bonus handoff — exercised by the Economy Tech
> Integration AC below; AP Economy re-review is owed but does not block Research's own Logic gate.)*

**Pure Logic gate (BLOCKING — fake/injected Grid + AP + Credits):**

*Templates (Rule 1):*
- **GIVEN** the Research Lab template, **THEN** fields match: hp 12, build_cost 8, build_time 2, defense
  0, production_cap 0, can_counterattack false.
- **GIVEN** each tech template, **THEN** fields match — Attack (`research_cost` 10 Credits, `ap_surcharge`
  1, time 3, +1 atk), Defense (`research_cost` 10 Credits, `ap_surcharge` 1, time 4, +1 def), Economy
  (`research_cost` 7 Credits, `ap_surcharge` 1, time 3, +1 Credit/turn income per completed Economy
  Outpost, capped at `ECONOMY_TECH_TIER_THRESHOLD` (6) outposts). **AND** each tech's `ap_surcharge`
  reads the base `RESEARCH_AP_COST` (1) unless overridden.
- **GIVEN** any template read twice, **THEN** identical (immutable).

*Start-research legality (Rules 3, 4):*
- **GIVEN** a Completed Idle Lab, ≥10 Credits, **and** ≥ the Attack tech's `ap_surcharge` (1) AP, **WHEN**
  `start_research(lab, Attack)`, **THEN** Credits −10 (via `credits_spend`) **and** AP −`ap_surcharge`
  (via `ap_spend`) — **both**, a single both-or-neither commit — tech Under Research at that Lab,
  `research_turns_remaining` = 3.
- **GIVEN** a Completed Lab that can afford the Credits **but not** the `ap_surcharge` AP (or vice-versa),
  **THEN** rejected, **nothing spent from either pool** (both-or-neither), Lab stays Idle.
- **GIVEN** an Under-Construction Lab, **THEN** `start_research` rejected **and** `legal_research_targets(lab)`
  returns the empty set.
- **GIVEN** a Lab already Under Research, **WHEN** a second `start_research`, **THEN** rejected (one tech
  at a time per Lab).
- **GIVEN** a tech already Completed for this player, **THEN** excluded from `legal_research_targets` at
  all that player's Labs; direct call rejected.
- **GIVEN** a tech Under Research at that player's Lab A, **THEN** excluded at Lab B (same player); direct
  `start_research(lab_B, same_tech)` rejected.
- **GIVEN** a player attempts `start_research(lab_B, X)` while tech X is already Under Research at their
  Lab A, **THEN** it is rejected **before any second timer can exist** — so a single tech can never be
  Under Research at two of a player's Labs at once, making a same-tech double-completion on the same
  start-of-turn **structurally unreachable** (only *different* techs can co-complete — see the batch AC
  below). *(Negative-space proof of Rule 4's exclusion.)*
- **GIVEN** two Completed Labs (same player), **WHEN** each starts a *different* tech, **THEN** both
  succeed with independent targets/timers.
- **GIVEN** Player A researching tech X, **THEN** Player B may still research tech X at B's Lab
  (per-player, not global).
- **GIVEN** a player with an Idle Completed Lab, **WHEN** they build a second Lab, **THEN** allowed
  (redundant Labs are legal; no Lab cap in the VS).

*Timer & completion (Rule 5):*
- **GIVEN** `research_turns_remaining` = 2, **WHEN** the advance step runs once, **THEN** → 1, still Under
  Research.
- **GIVEN** = 1, **WHEN** advance runs, **THEN** → Completed that call, Lab → Idle.
- **GIVEN** two Labs both hitting 0 the same call, **THEN** both Complete (batch).
- **GIVEN** a completed-this-call tech, **THEN** the advance function reads no income/combat state
  (ordering proof is an Integration AC).

*Destruction & permanence (Rule 6):*
- **GIVEN** a Lab Under Research destroyed, **THEN** the tech → Not Started, the `research_cost` **Credits**
  **not** refunded (and the `ap_surcharge` AP already spent, never refundable), and it reappears in
  `legal_research_targets` at any other Completed Lab.
- **GIVEN** a Lab Under Research is destroyed the **same resolution step** a `cancel_research(lab)` is
  submitted for it, **THEN** the cancel is **rejected** (target no longer exists) and the **no-refund
  destruction** path applies — never the 50% cancel refund (destruction wins; no double-resolution, no
  refund-then-destroy).
- **GIVEN** two Labs on different techs, one destroyed, **THEN** only that Lab's tech reverts; the
  other's timer/target unaffected.
- **GIVEN** a tech Completed for a player, **WHEN** all their Labs are destroyed (count → 0), **THEN** the
  flag stays true (completion lives on player state, not a Lab).
- **GIVEN** an Under-Construction Lab destroyed, **THEN** no tech reverts (none in progress); standard
  no-refund.

*Cancel (Rule 7):*
- **GIVEN** a Lab researching Attack/Defense (`research_cost` 10 Credits), **WHEN** `cancel_research`,
  **THEN** `floor(10×0.5)=5` **Credits** refunded (via `credits_credit`), the `ap_surcharge` AP **not**
  refunded, Lab → Idle, tech → Not Started.
- **GIVEN** Economy Tech (`research_cost` 7 Credits), **THEN** `floor(7×0.5)=3` **Credits** refunded (floor, not round).
- **GIVEN** an Idle Lab, **WHEN** `cancel_research`, **THEN** rejected/no-op, no Credit or AP change.
- **GIVEN** a cancelled tech, **THEN** the Lab remains Completed and immediately re-eligible.

*Flags & formulas (Rule 8, Formulas):*
- **GIVEN** `has_attack_tech = false`, **WHEN** Attack Tech completes, **THEN** `has_attack_tech(player)`
  reads true that same call.
- **GIVEN** injected `base_defense 0` + `owner_has_defense_tech false`, **THEN** `effective_defense =
  base_defense` (= 0); with the flag true, **THEN** `effective_defense = base_defense + DEFENSE_TECH_BONUS`
  — assert against the **named constant read from config, not the literal 1**, so a retune of
  `DEFENSE_TECH_BONUS` cannot silently pass a stale test.
- **GIVEN** a player with `has_economy_tech = false` and `k` completed Economy Outposts, **THEN** their
  `economy_tech_income_bonus` is **0**; **GIVEN** `has_economy_tech = true` with `k ≤ ECONOMY_TECH_TIER_THRESHOLD`
  completed Economy Outposts, **THEN** it is `ECONOMY_TECH_INCOME_BONUS × k` — assert against the **named
  constant read from config, not hardcoded** (e.g. k=0 → 0, k=3 → 3 at the default bonus 1); **AND** it
  tracks the live count (destroy one Economy Outpost → the bonus drops by `ECONOMY_TECH_INCOME_BONUS`,
  down to the cap). **GIVEN** `k > ECONOMY_TECH_TIER_THRESHOLD` (e.g. k=8 at the default threshold 6),
  **THEN** the bonus stays capped at `ECONOMY_TECH_INCOME_BONUS × ECONOMY_TECH_TIER_THRESHOLD` (= 6) —
  the 7th and further outposts add nothing more from this term (added 2026-07-22, AP Economy re-review).

*Determinism (Rule 9):*
- **GIVEN** the same fixture + action twice, **THEN** byte-identical results; **GIVEN** a `clone()`,
  **WHEN** an action hits the clone, **THEN** the original is unmutated.

**Integration gate (BLOCKING — real Grid + AP + Credits + Turn Manager + Unit + Combat + Base & Production):**
- **GIVEN** the real B&P roster, **WHEN** a player builds a Research Lab via real `build()`, **THEN** it
  spends 8 **Credits** + `BUILD_AP_COST` (2) AP (both-or-neither, B&P's structure dual-cost) and follows
  the same lifecycle + cancel refund (`floor(8×0.5)=4` **Credits**; the 2 AP surcharge not refunded) as
  any structure. *(Exercises the landed Research-Lab 5th-structure handoff — see Dependencies.)*
- **GIVEN** a real Lab with `research_turns_remaining` = 1 at start-of-turn, **THEN** querying
  `has_attack_tech(player)` immediately post-start-of-turn/pre-action reads true, **AND** a real attack
  that same turn deals buffed damage — the end-to-end proof of Rule 5 ordering.
- **GIVEN** a real Economy Outpost timer and an Economy Tech research timer both hitting 0 the same
  start-of-turn, **THEN** both complete that pass, **AND** that same turn's `credit_income` snapshot reflects
  both — the tiered outpost bonus AND the now-live `has_economy_tech` term — proving the step-3-before-
  step-4 boundary (Game State & Turn Manager Core Rule 3) holds regardless of which timer advance runs
  first within step 3 (corrected 2026-07-22: this is a step-boundary guarantee, not state-disjointness —
  see the Edge Cases note above).
- **GIVEN** a real player completing Attack Tech, **THEN** all their units' real `effective_attack` +1 on
  the next damage calc, **AND** a unit produced afterward includes it live. *(Exercises the landed Unit
  System `effective_attack` two-flag handoff.)*
- **GIVEN** a real player completing Defense Tech, **THEN** their units' `effective_defense` reads 1 and
  real Combat reflects the extra mitigation (un-researched Scout atk 2 vs researched Trooper on Cover
  clamps to `MIN_DAMAGE` 1). *(Exercises the landed Unit System `effective_defense` handoff.)*
- **GIVEN** a real player who has completed Economy Tech and owns `k` completed Economy Outposts, **WHEN**
  their start-of-turn income is computed, **THEN** `credit_income` includes
  `+ ECONOMY_TECH_INCOME_BONUS × min(k, ECONOMY_TECH_TIER_THRESHOLD)` on top of AP & Credits Economy's base tiered
  bonus (e.g. k=3 tier-1 → base `10 + 2×3 = 16`, with Economy Tech `16 + 3 = 19`; k=8 past the default
  threshold 6 → base `10 + 2×4 + 1×4 = 22`, with Economy Tech capped `22 + 6 = 28`, not `22 + 8 = 30`);
  **AND** an Economy Outpost that completes the same start-of-turn is counted **before** the snapshot, so
  its contribution (subject to the cap) is included that turn. *(Exercises the AP & Credits Economy
  `credit_income` handoff — see Dependencies.)*
- **GIVEN** a real Lab mid-research destroyed by real Combat, **THEN** removed that step, tech → Not
  Started, no refund, observable via `legal_research_targets` later.
- **GIVEN** a real `clone()` with in-progress research, **WHEN** an action hits the clone, **THEN** the
  original real state is unmutated (AI look-ahead path).

**Advisory (documented playtest — not unit-testable):**
- **GIVEN** a Cover+Defense-Tech defender, **WHEN** attacked by (i) an un-researched Scout/Trooper **and**
  (ii) a **researched** Scout/Trooper (the mirror case), **THEN** playtest confirms whether the
  `defense + COVER_DR = 2` floor-lock — multiple attacks (and, for the Scout, *every* attack regardless of
  its own Attack Tech) reading as identical 1 damage — is an acceptable Pillar 3 legibility cost. **If not,
  apply the pre-committed non-stacking fallback** (`mitigation = max(defense, cover_reduction)`, see Open
  Questions), not a silent number tweak. *Config/Data-type playtest item, flagged to game-designer /
  systems-designer / Combat (#6).*
- **GIVEN** Base & Production's closeout fixture **CF-1** re-run with the **winning** player A having
  completed **Attack Tech** (a realistic winning-player line), **THEN** playtest confirms decided games
  still **close** by `CLOSEOUT_TARGET_TURNS` — the permanent army-wide +1 must *accelerate* the close, not
  turn a won game into an un-closeable stomp or (worse) let the winner coast while the loser lingers. *(The
  closeout brake is Base & Production's; this AC checks Research does not defeat it. Flagged to
  game-designer / economy-designer.)*

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| The Attack/Defense-on-Cover **floor-lock** — Scout (and Trooper vs an un-teched attacker) reads an identical 1 damage vs a Cover+Defense-Tech defender, **including in the researched mirror match** (a Pillar 3 legibility hit; the Scout case is structural — no attacker tech escapes it). Acceptable, or fix? | game-designer / systems-designer / Combat (#6) | **Pre-committed fallback lever (not "hold and hope"):** if playtest shows the floor-lock reads as broken, apply **non-stacking mitigation** — a unit's damage reduction becomes `max(defense, cover_reduction)` instead of `defense + cover_reduction`, capping a Defense-Teched unit on Cover at 1 mitigation and un-locking Scout/Trooper. This is a Combat-formula change (touches `combat-resolution.md`'s defense-stacking rule) held in reserve. Hold `DEFENSE_TECH_BONUS` at 1 meanwhile; the fallback is the decision-ready fix, not a re-opened design. |
| Does Research **worsen the endgame closeout / snowball**? A winning player banks permanent +1/+1 (and, with Economy Tech, +Credit-income/outpost) on top of a board lead; a losing player is Credit- and AP-starved and can't afford research at all. Lab-spam has **no brake** (unlike outpost-spam's closeout-drag answer). *(Pivot 2026-08-05: with Credits now banked (unbounded stock), a saved war chest could fund a late tech burst — see AP & Credits Economy's re-opened banking→snowball question; the per-tech `ap_surcharge` still rate-limits how many techs commit in one turn.)* | game-designer / economy-designer / Base & Production (#7) | **Accepted as an intentional snowball** (the reward for winning the mid-game), **not braked in the VS**. Validate via the closeout re-run AC (winner holds Attack Tech) that decided games still *close* rather than stall; if a Lab/snowball brake proves needed, a **simultaneous-Lab soft cap or escalating research cost** is the reserved lever. |
| Is **Economy Tech strictly dominant** over Attack/Defense Tech for any boomed player — its +income/outpost *compounds* (reinvestable), the flat +1/+1 sticks don't — collapsing the "which tech" decision? | economy-designer / game-designer | **DECIDED 2026-07-22 (`/review-all-gdds` D-1): accept as archetype identity** — Economy Tech is the boom's signature tech, Attack/Defense the aggressor's (see the Overview + Player Fantasy "which tech is archetype identity" reframe); this is intended, not a defect. **Pre-committed fallback lever (not "hold and hope"):** if a combined **20-round joint-curve simulation** (income + tech + army-size together — no doc has run it yet) *or* the slice shows Economy Tech so dominates that combat tech is *never* worth taking even for a player who wants combat power, apply a **cumulative lifetime cap** on Economy Tech's total Credit-income contribution (converging it toward flat-buff parity) — held in reserve, not shipped. `ECONOMY_TECH_TIER_THRESHOLD` (6) already narrows the gap; the lifetime cap is the decision-ready deepening if data demands it. |
| Should there be a **cap or escalating cost on simultaneous Labs**? With one-tech-per-Lab and no inter-tech opportunity cost, a player who affords 2–3 Labs researches everything, thinning the "which tech" decision. | game-designer | VS = no cap (flat). Reserved lever if multi-Lab spam trivializes the choice or the snowball in playtest (related to the closeout/snowball row above). The Economy Tech retune restores *some* differentiation (it scales with the boom, unlike the flat Attack/Defense sticks). |
| Do the tech `research_cost`/`research_time` values leave **enough turns to pay off** in typical match lengths? | game-designer / systems-designer | Re-validate against `MAX_ROUNDS` and real game length in the slice — a tech researched too late is dead Credits (and a wasted AP surcharge). |
| Should techs be **faction-differentiated** (different techs, costs, or bonuses per faction)? | Faction Identity (#12) | Natural asymmetry lever (e.g. a boom faction with cheaper Economy Tech); keep the faction GDD shallow until the asymmetry prototype. |
| Should there ever be a **hard cap on simultaneous Labs**, or a tech tree with prerequisites? | game-designer | VS = no cap, flat tree. Both are Alpha levers if research proves too spammy or too shallow. |
| Should **structure `attack`** (Defensive Structure) become research-buffable? | Base & Production (#7) / Combat | Currently OFF (Research buffs units only). Shared Open Question with Base & Production — a turret that scales with tech may be desirable in Alpha. |
| Should a completed tech be **visible to the opponent** (full transparency) or hidden until first used? | game-designer / UX | VS assumption: visible (readable-board pillar). Confirm in playtest — hidden tech adds mind-games but hurts legibility. |

---

# ⚑⚑ AMENDMENT PROPOSAL — CR-14: research moves to the HQ and the tree branches

> **Raised**: 2026-08-26 (user). **Status**: ⛔ **DRAFT — decisions open, no code written.**
> **Supersedes**: Core Rules 2–4, the Tech-tree-shape tuning row, and two Open Questions.

## What changed, and why it is not a small edit

The user asked for four things: **research runs from the HQ**, techs are **gated behind owning
certain structures**, techs are **gated behind other techs**, and some choices are **mutually
exclusive branches**.

★ **This GDD already anticipated all of it and deliberately said no**, twice:

> *"Tech tree shape — Flat, no prerequisites, all researchable. Widening to a branching/prereq tree
> is an **Alpha lever**; keeps VS shallow."*
> *"Should there ever be a hard cap on simultaneous Labs, or a tech tree with prerequisites? —
> **VS = no cap, flat tree.** Both are Alpha levers if research proves too spammy or too shallow."*

⇒ **This amendment is the user answering that open question**, not a correction. The deferral was
correct at the time and the reason to reverse it is new: ⛔ **none of this system exists in code.**
`research.gd` is an explicit forward declaration, there is no `ResearchAction`, and `Verb.RESEARCH`
is never registered with `GameState`. **A Research Lab is 800 Credits for a building that does
nothing.** Since the epic must be built from scratch either way, building the flat version first
and the branching version later is strictly more work than building the branching version once.

## ⛔ The decision the rest of this hangs on: what is the Research Lab FOR?

If research runs from the HQ, the Lab loses its only job. Three coherent answers:

| | The Lab becomes | Consequence |
|---|---|---|
| **A** | ★ **A prerequisite structure** — advanced techs require one (or two) standing | ★★ Answers the user's "gated behind certain structures" with a building the game already has, and gives the Lab a *reason* instead of a function. Destroying one becomes a real strategic target: it does not undo completed techs, but it locks the enemy out of the next tier |
| **B** | **Research capacity** — the HQ researches one tech; each Lab adds a parallel slot | Preserves today's multi-Lab parallelism. ⚠ Re-opens the "Lab-spam has no brake" snowball question this GDD already flags as unresolved |
| **C** | **Deleted** | Simplest. ⚠ Throws away a built, textured structure and removes the natural home for structure-gating |

**Recommendation: A.** It is the only one that makes the user's two gating asks — structures and
prior techs — the *same mechanism*, and it converts a dead building into a target worth attacking.

## Proposed tree (concrete, so the shape can be argued with)

Three lines. **Tier 1 needs nothing. Tier 2 needs a Research Lab and its tier-1 parent.**

```
COMBAT        Attack Tech ──┬─→ ⚔ Penetration   (+1 atk, ignores Cover)     ┐ mutually
                            └─→ ⚔ Volley        (+1 atk, +1 attack_range)   ┘ exclusive

DEFENCE       Defense Tech ─┬─→ 🛡 Plating      (+2 def)                    ┐ mutually
                            └─→ 🛡 Field Repair (heal 1/turn when idle)     ┘ exclusive

ECONOMY       Economy Tech ─┬─→ ⚙ Logistics     (−1 AP on produce/build)    ┐ mutually
                            └─→ ⚙ Foundry       (−25% unit Credit cost)     ┘ exclusive
```

★ **Why exclusivity sits at tier 2 and not tier 1:** a player must be able to reach *some* of every
line, or the archetype identity this GDD already establishes ("Economy Tech is the boom's signature,
Attack/Defense the aggressor's") collapses into one forced opening. The branch is where the
interesting decision lives; the trunk is where identity lives.

⚠ **Exclusivity is permanent for the match, with no re-spec.** A reversible branch is a menu, not a
decision — and this GDD's Player Fantasy section is explicit that research is meant to feel like
commitment.

## What this fixes about the Lab-spam snowball

★ Worth noting because it resolves an Open Question rather than dodging it: under **A**, techs stop
scaling with Lab *count*. Two Labs unlock the same tier-2 access one Lab does, so **Lab-spam buys
nothing** — the brake this GDD says it lacks arrives for free as a consequence of the structure gate.

## Open decisions — user's call

1. **Lab's new role** — A, B or C above.
2. **Does destroying the gating Lab revoke tier-2 access?** ⚠ Proposed: **no** for completed techs
   (permanence is this GDD's Rule 8 and the player paid), **yes** for starting new ones. That makes
   the Lab worth defending without ever taking something away that was already earned.
3. **Faction-specific gating.** The user asked for it; ⚠ `faction-identity.md` has no per-faction
   structures yet, so this needs either that epic first or a placeholder flag. **Recommend
   deferring the faction half** and shipping structure + tech prerequisites now.
4. **Do tier-2 techs cost AP as well as Credits?** Consistent with Rule 3 says yes; the tempo cost is
   what stops a banked war chest buying the whole tree in one turn.

## Still to write once the above is settled

Formulas for each new tech · Edge Cases (gate destroyed mid-research; both branches somehow
affordable; tech completing the turn its Lab dies) · Acceptance Criteria · the HQ's research UI ·
AI scoring for a branching tree (⚠ the AI currently has no tech model at all) ·
**a new Research Lab texture** (ASSET-013 — the current one is placeholder-grade).
