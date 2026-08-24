# Faction Identity

> **Status**: **IN REVISION — framework v2** (2026-08-24). Was **Approved** (2026-07-22) as
> framework v1. This revision is a **framework-shape change, not a balance pass**, and requires a
> fresh `/design-review` before it can return to Approved. v1 is preserved at
> `git show design/initial-gdd-corpus:design/gdd/faction-identity.md`.
>
> **Author**: user (faction direction) + agents (framework)
>
> ### What changed in v2, and why
>
> The user supplied the full six-faction design direction on 2026-08-24. Framework v1 could not
> express it. v1 assumed **one shared unit roster that factions re-price**; the design has **six
> factions with independently authored rosters** that differ in *shape*, not just in numbers — the
> Democratic Alliance fields three infantry tiers, the Solar Federation one plus specialists, the
> Galactic Protectorate robots instead of humans. No arrangement of v1's additive deltas produces
> that.
>
> Three v1 rules are therefore reopened, each by its own named trigger:
>
> | v1 rule | Change | Trigger |
> |---|---|---|
> | **CR-6** — combat stats (hp/atk/range) locked to identity for all factions | **UNLOCKED.** See CR-6 (v2) | **OQ-9's named reopen-trigger.** v1: *"if tempo-only asymmetry is insufficient to make factions read as distinct, OQ-9 reopens the CR-6 combat-stat lock — a framework-shape change requiring a fresh `/design-review`."* The design direction requires per-unit qualitative difference throughout (*"weaker stats", "frail and expensive", "strong defense", "mediocre vehicle options"*). **User decision, 2026-08-24.** |
> | **CR-2** — closed list of 6 modifiable domains | **Expanded to 9**, and reshaped: rosters are *owned*, not deltaed | Follows necessarily from independent rosters. **User decision, 2026-08-24** (chose "fully independent rosters" over an archetype spine or a shared core) |
> | **CR-3** — *"never introduce a new verb the base game lacks"* | **Narrowed to its real intent**: never introduce an **unpriced** verb. See CR-3 (v2) | The design needs faction-unique abilities (heal, demolish, capture, paradrop). CR-3 existed to protect **Pillar 1**, and Pillar 1 is about *everything costing from the shared budgets* — not about the size of the verb catalogue |
>
> **What did NOT change, and is not up for renegotiation in v2:** CR-1 (a faction is data, not
> logic), CR-4 (live resolution, no base mutation), CR-5 (symmetric framework / asymmetric
> content), CR-7 (determinism), and **Pillar 1's hard invariant — no third resource, nothing free**.
>
> ### ⚠ Two consequences this revision creates and does not resolve
>
> 1. **Six factions break "faction = hue."** The art bible's Visual Identity Anchor makes hue the
>    ownership channel, and the shipped `#FF5A2E` / `#22C7F0` pair was *measured* as a near-ideal
>    dichromat pair (blue-vs-yellow axis; passes deutan/protan/tritan unaided —
>    `production/qa/evidence/s5-08-colourblind-ownership-brief.md`). **Six hues cannot all be
>    mutually distinguishable, and no six-colour palette passes red-green colourblindness.** See
>    **OQ-11** — the recommended resolution is that **hue becomes seat, not faction**.
> 2. **Independent rosters remove every structural bound on faction imbalance.** v1's OQ-10 noted
>    that nothing prevents a faction stacking all-upside deltas; under v1 the damage was bounded by
>    small deltas on shared units. Under v2 it is unbounded — a faction can simply author better
>    units. This is promoted from an open question to a **Core Rule (CR-10)**.
>
> **⚠ Pivot banner (2026-08-05, still current):** the single-AP economy is split into flat tactical
> **AP** and banked **Credits**. Every `ap_income` reference is `credit_income`.
>
> **⚠ Economy banner (2026-08-24):** the vertical slice returned a **PIVOT** verdict
> (`production/vertical-slice/REPORT.md`) — Credits are unbounded, so economy actions outscore
> manoeuvring by 12–20× and no match ever resolves on play. **Unit upkeep** is the chosen fix and is
> a new CR-2 domain (D9). Faction balance authored before upkeep ships is provisional by
> construction: upkeep changes what every unit is worth.

## Overview

The **Faction Identity** system is the data-and-rules layer that makes each playable faction a
*distinct army with a distinct way to spend AP and Credits* rather than a reskin — the mechanical
expression of Pillar 4 ("Factions Are Verbs, Not Skins"). In framework v2 a faction is **two things
at once**: (a) an **owner** of content — its own unit roster, its own structures, its own tech tree,
its own ability loadouts — and (b) a **modifier provider** over the systems that remain shared
(income curve, population cap, upkeep rates, starting loadout). It is still not a system with its
own board presence; it is the layer that decides *what army you command and what it costs you*.

Faction differences express **only** through the shared AP + Credits economy (Pillar 1). A faction
may field wholly different units with wholly different abilities — but every one of those units is
produced with Credits and acts by spending AP, every ability has a price in one or both, and no
faction has a third resource or a free action. **That invariant is the whole of CR-3 and it is not
negotiable.**

Six factions are specified (names TBD, user-supplied 2026-08-24). The **Democratic Alliance of
Planets** is the declared balance baseline — a generalist army against which the other five are
measured — and is the closest to what the vertical slice already ships. The other five each carry a
structural thesis: the **Solar Federation** trades income for volume and specialists; the **Galactic
Protectorate** trades expensive elite humans against cheap disposable robots; the **Holy Cosmic
Empire** compounds power through field promotion and a linear tech spine, and is brittle when that
spine is cut; the **Independents** field few but exceptional infantry and steal what they cannot
build; the **Machinist's Union** is weak in the hand and overwhelming in the vehicle.

**This GDD locks what a faction may own and modify, and the fairness discipline every faction must
pass. It does not set balance values — those live in the six per-faction GDDs and are provisional
until upkeep ships and playtest runs.**

## Player Fantasy

**The feeling: "this faction wages war *my* way — and no other faction could have fought that
battle."**

Under framework v1 the fantasy target was *directional*: Rush should read as the aggressor, Boom as
the accumulator, expressed purely through tempo. v2 raises the bar, because the design direction
requires it. A faction is now a different **army**, not a differently-priced one. Switching from the
Machinist's Union to the Independents should not feel like the same game at different speeds; it
should feel like being handed a different problem — different units, different threats, different
things you are good at and different things you simply cannot do.

Two audiences this serves directly. The **Competitor** wants their strategic personality to be a
real mechanical stance — and now it is an army composition question as well as a tempo one. The
**Explorer** wants each faction to be a distinct puzzle to learn, and six independent rosters
deliver that far more strongly than six price lists ever could.

**The failure mode this system exists to prevent** is unchanged and is now the *easier* failure to
avoid but the *harder* one to balance: two factions that play the same with different neon hues. v2
trades that risk for its opposite — **six factions that are genuinely different and wildly unfair to
each other.** CR-10 exists for exactly that reason.

**Accepted cost, stated plainly:** independent rosters mean roughly 50–60 units to design, balance,
test and eventually make art for, and every future balance change is potentially six edits rather
than one. That is the price of the identity the design asks for. **User decision, 2026-08-24.**

## Detailed Design

### Core Rules

**CR-1 — A faction is data, not logic.** *(Unchanged from v1.)* A faction is a named, statically
typed data resource (`FactionDef`) with no executable behaviour of its own — numbers, enum flags and
references to other data resources. In v2 it additionally *owns references to* its roster,
structures, tech tree and ability loadouts, all of which are themselves data. It still contains no
code paths. Designers add or retune a faction without touching system logic.

**CR-2 — Closed set of ownable and modifiable domains (the v2 framework contract).** A `FactionDef`
may own or modify *only* the following nine domains. Domains marked **OWN** mean the faction
authors its own content; domains marked **MOD** mean the faction applies an additive delta to a
value another system owns (v1's mechanism, preserved with its clamps intact).

| # | Domain | Kind | Owning system | Notes |
|---|---|---|---|---|
| **D1** | **Unit roster** | **OWN** | Unit System (#4) owns the *schema*; the faction owns *which units exist for it* | ★ **The v2 change.** Replaces v1's "unit cost deltas". Each faction authors its own `UnitTypeDef` set. No unit is shared between factions unless deliberately duplicated |
| **D2** | **Unit class access** | **OWN** | `unit-classes.md` (new) | Which of infantry / ground vehicle / air the faction fields, and how well. A faction may field none of a class |
| **D3** | **Population cap** | **MOD** | `population-cap.md` (new) | Base infantry cap, **`max_barracks`** and `cap_per_barracks`, and which of the faction's units are exempt. ★ **Infantry only** — vehicles are bounded through their crew (PC-8), so a faction's armour count falls out of its infantry cap rather than needing a lever of its own |
| **D4** | **Income parameters** | **MOD** | AP & Credits Economy (#3) | ★ **REKEYED 2026-08-24** — income is now research-driven, so the outpost-tier deltas are gone. A faction deltas **`BASE_INCOME`** (intercept: felt from turn 1) and/or the **economy tier bonuses and their research costs** (slope: compounds as you climb). The intercept/slope distinction survives in a cleaner form; the combined-ceiling rule survives but is now trivial, since the ceiling is a single literal number |
| **D5** | **Structure roster + costs + maximums** | **OWN + MOD** | Base & Production (#7) | A faction may author its own structures (Solar's autonomous defences vs. the Alliance's manned ones), delta the shared ones' `build_cost` / `build_time` / `production_cap`, and ★ **set its own per-structure maximums** (`max_barracks`, `max_factories`, `max_airfields`, `max_defensive`). The maximums are how a faction's *shape* on the map is expressed — and, per `base-production.md`, they are load-bearing for the PIVOT fix |
| **D6** | **Tech tree** | **OWN** | Research/Tech (#8) | ★ Widened from v1's per-tech availability/cost deltas. A faction authors its own tech tree, including trees that alter unit *behaviour* (the Protectorate's mechs going autonomous; the Empire's linear power spine) |
| **D7** | **Starting loadout** | **OWN** | Game State & Turn Manager (#2) | Starting AP, Credits, units and structures placed at setup. Unchanged from v1 |
| **D8** | **Ability access** | **OWN** | `unit-abilities.md` (new) | Which abilities from the **shared, base-game-priced catalogue** the faction's units may carry. ★ See CR-3 — the catalogue is base-game content; the faction chooses from it, it does not invent entries |
| **D9** | **Upkeep modifiers** | **OWN + MOD** | `unit-upkeep.md` (new) | Each faction-owned unit declares its own upkeep; the faction may additionally delta the global upkeep rate. ★ **This is the domain that prices the design's central tradeoffs** — the Protectorate's cap-exempt robots being "less economical", the Union's powerful-but-expensive-to-run vehicles |

Anything not in this list is not a faction lever. A proposed faction feature that does not fit one
of the nine is cut or re-expressed until it does.

**CR-3 — Pillar 1 invariant (hard constraint, v2 wording).** Every action any faction can take must
be **priced in AP and/or Credits**. A faction may never:

- **(a)** add a **third resource** of any kind;
- **(b)** grant an action costing 0 AP *and* 0 Credits where an equivalent base action is priced;
- **(c)** carry an ability that is not an entry in the **shared ability catalogue**, where each
  entry's AP/Credit price is set by `unit-abilities.md` — *the base game*, not the faction;
- **(d)** modify a value outside CR-2's nine domains.

> **★ What changed and what did not.** v1's clause (c) read *"introduce a new verb the base game
> lacks."* Under v1 that was equivalent to (a)/(b) — the base game had exactly four verbs, so any
> new verb necessarily arrived unpriced. Under v2 the base game gains an **ability framework**, and
> abilities are priced base-game content that factions *select from*. The invariant CR-3 was
> actually protecting — **nothing free, nothing outside AP+Credits** — is fully preserved and is
> now stated directly rather than by proxy. **A faction still cannot invent a verb; it can only
> choose which priced verbs its units carry.** The catalogue itself grows by ordinary design work
> in `unit-abilities.md`, reviewed on its own merits, never as a side effect of authoring a faction.

**CR-4 — Live modifier resolution (no base mutation).** *(Unchanged from v1, scope clarified.)*
Applies to the **MOD** domains (D3, D4, D5-mod, D9-mod): the delta is folded in at the owning
system's read site via an `effective_X` lookup taking `player` as an argument; base registry values
are never rewritten. **OWN** domains do not delta anything — the faction's roster *is* the base data
for that faction, read directly. This distinction matters for testing: `effective_X` regression
tests apply to MOD domains only.

**CR-5 — Symmetric framework, asymmetric content.** *(Unchanged from v1.)* Every faction draws from
the same nine domains; asymmetry lives entirely in the content and values. Mirror matches are legal
and are the natural balance baseline for that faction.

**CR-6 — Six factions; combat-stat asymmetry UNLOCKED.** *(Replaces v1's CR-6 entirely.)*

- The roster is **six** factions plus **Neutral**. Neutral is retained as the identity/no-op
  reference used by regression tests and as the safe default when no faction is assigned — it is
  **not** a playable faction in the shipping game.
- **`combat_stat_deltas_enabled` is removed.** Per-unit `hp` / `attack` / `attack_range` /
  `move_cost` / `soft_move_cap` differ freely between factions, because under D1 each faction
  authors its own units and there is no shared base to delta.
- **Deterministic combat (Pillar 2) is untouched.** The combat *formula* remains deterministic and
  identical for every faction; only the *inputs* differ. Damage types (`damage-types.md`) extend the
  formula symmetrically for all factions — they are base-game content, not a faction lever.
- **The Democratic Alliance of Planets is the declared balance baseline.** Every other faction is
  authored and reviewed as a comparison against it (CR-10).

**CR-7 — Determinism.** *(Unchanged from v1.)* A `FactionDef` and everything it references is fixed
data applied identically every match. No per-match randomisation of faction content or values.

**CR-8 — Roster ownership and orphan safety.** A unit, structure or tech belongs to exactly one
faction (or to `shared`, for content deliberately common to all). A faction's content is loaded only
when that faction is in play. Content referenced by a faction but missing from the registry is a
**load-time error**, not a silent degradation — v1's forgiving "orphaned delta is inert" rule was
correct for *deltas on shared values* and is **wrong for owned rosters**, where a missing unit means
the faction cannot field an army it was designed around.

**CR-9 — No faction-unique rule exceptions.** A faction expresses itself through *content* (D1, D2,
D5, D6, D8) and *rates* (D3, D4, D9). It never gets a special case in a shared system's logic. If a
faction's design appears to need one — *"the Empire's units promote"*, *"the Independents' pirate
steals vehicles"* — the correct response is to build that capability as **general base-game
machinery** (`promotion-veterancy.md`, `transport-and-pilots.md`) that any faction *could* use, and
then grant access to it through D6/D8. This keeps CR-1 true, keeps the systems testable, and is why
Tier 1 of the corpus exists at all.

**CR-11 — ★ Universal baseline: every faction has piloted vehicles and an infantry cap.**
*(User decision, 2026-08-24.)* These two are **not** per-faction choices. Every shipping faction:

1. **Fields ground vehicles that require a crew** (`requires_pilot = true`), so armour always costs
   an infantry slot (`population-cap.md` PC-8) and is always exposed to crew-killing and capture
   (`transport-and-pilots.md` TP-7/TP-8).
2. **Is subject to the infantry cap** — every faction declares a `base_infantry_cap` and a
   `max_barracks`, and no faction may opt out of the system.

> ★ **Why this is a Core Rule rather than a convention.** Both mechanics are load-bearing for
> balance *across* factions, not within one. If a faction could field pilot-free armour it would
> escape the cap entirely (armour is uncapped except through its crew) **and** be immune to the
> Independents' entire design. If a faction could opt out of the cap it would have no army-size
> bound but upkeep. Either exemption, granted casually, breaks the corpus's two shared limiters at
> once. Anything that looks like an exception is a **deliberate, reviewed** exception (see below),
> never an omission.

**CR-11a — The one sanctioned exception: the Galactic Protectorate.** *(User decision, 2026-08-24,
made explicitly rather than inherited.)* The Protectorate may hold **autonomous** units that need no
crew, and its robotic infantry are **cap-exempt**. Both are bounded:

- **It never fully escapes.** Its **tanks always require pilots**, at every tech level. Only its
  *mechs* can be freed, and only by completing the expensive **Mech Autonomy** research — so the
  exemption is *earned mid-match*, not granted at setup, and its human cap stays scarce all game.
- **It pays in upkeep.** The cap-exempt Servitor costs **300/turn** — the same as an Alliance Heavy,
  for a unit with attack 2. ★ The exemption was measured and does **not** make the faction larger:
  it fields the **smallest sustainable army in the corpus** (~5 units), because a cap stops at a wall
  while upkeep keeps taking. What it buys is *resilience* (never production-locked, always able to
  field something), not scale.
- **It is a legible strategic property, not a hidden one.** *"The Protectorate can research its way
  out of needing people"* is the faction's stated arc, and it is the hard counter to the
  Independents' Pirate — an emergent interaction between two independently authored factions.

> ★ **Any future proposal to exempt a second faction from either mechanic re-opens this rule**, and
> should be reviewed against CR-10's comparison sheet before it is accepted. One exception is an
> identity; two is the rule quietly dissolving.

**CR-10 — Every faction is measured against the baseline before it ships.** *(Promoted from v1's
OQ-10, which noted the gap and enforced nothing.)*

Independent rosters remove every structural bound on imbalance: under v1 a faction could only be
mildly better, because it could only nudge shared values; under v2 a faction can simply author
better units. Nothing in the schema prevents it and no clamp catches it. Therefore:

1. Every non-baseline faction ships with a **comparison sheet against the Democratic Alliance**,
   covering: cost-per-hp, cost-per-damage, damage-per-AP, effective board reach per turn, upkeep
   burden at a standard army size, and time-to-first-contact from the standard opening.
2. **A faction is not "balanced" by having a weakness somewhere.** It must be *unable* to win the
   comparison on every axis at once. A faction that is even slightly ahead on all axes is
   over-tuned regardless of narrative justification.
3. **Mirror matches are the balance floor, cross-matchups the ceiling.** With six factions there are
   21 matchups; a faction passing against the Alliance may still be degenerate against one specific
   other. The review obligation is against the baseline; the *playtest* obligation is the matchup
   grid.
4. This is a **design-review gate**, not an automated test — no assertion can encode "fair". It is
   enforced by `/design-review` on each per-faction GDD and by the matchup grid in playtest.

### States and Transitions

A player's faction has a short setup-phase lifecycle — previewed and acknowledged in the picker, committed once, then immutable for the match. The **SELECTING** sub-state exists specifically so the pre-lock preview (AC-28) and experimental-acknowledgment (AC-27) contracts have a state to live in *before* the commit that places the starting loadout (AC-26) — without it, "picked" and "committed" would collapse into a single transition and the two UI contracts would have nowhere to attach:

| From state | Trigger | To state | Side effect |
|---|---|---|---|
| **UNASSIGNED** | Match setup begins — the faction picker opens for the player (or campaign/skirmish config) | SELECTING | None yet — no `faction_of(player)` set, no loadout placed |
| **SELECTING** | Player highlights/selects a candidate `FactionDef` in the picker | SELECTING | Candidate faction's starting loadout (CR-2.6) is **previewable** (AC-28); **no** board placement occurs yet. Re-highlighting a different faction stays in SELECTING (pre-lock re-pick — whether re-picking is allowed and whether it re-triggers the acknowledgment is governed by OQ-8) |
| **SELECTING** | Player **confirms** the pick — and, for a non-Neutral (provisional) faction, first passes the experimental-values acknowledgment (AC-27); Neutral requires no acknowledgment | ASSIGNED | `faction_of(player)` set; starting loadout (CR-2.6) placed (AC-26) |
| **ASSIGNED** | Turn Manager transitions Setup → first PlayerTurn | LOCKED | Faction is now immutable for the match; all effective-value lookups fold in its modifiers |
| **LOCKED** | — | — | No transition — no mid-match faction switching exists (would violate the "pre-commitment" fantasy and determinism) |

> The picker never places anything until the **SELECTING → ASSIGNED** confirm transition. Highlighting a faction only previews it (AC-28); the acknowledgment gate (AC-27) sits *on* the confirm transition for non-Neutral factions. This keeps AC-26's "loadout placed at UNASSIGNED→ASSIGNED" honest — placement fires exactly once, at commit, never during preview.

### Interactions with Other Systems

Faction Identity is both a **content owner** (D1/D2/D5-own/D6/D7/D8) and a **modifier provider**
(D3/D4/D5-mod/D9). Under Neutral every MOD delta is identity and the OWN domains resolve to the
base game's own roster, so Neutral-vs-Neutral is unchanged — the v1 invariant is preserved and
remains the regression anchor.

| System | What faction owns / modifies | Who applies it | v2 status |
|---|---|---|---|
| **Game State & Turn Manager** (#2) | Holds `faction_of(player)`; applies starting loadout (D7) | Turn Manager (setup) | Owed: per-player faction + loadout. **Already partly built** |
| **AP & Credits Economy** (#3) | Income-curve params (D4) | `credit_income` | Owed: optional faction term, identity at Neutral. **Unchanged from v1** |
| **Unit System** (#4) | ★ **Owns the `UnitTypeDef` schema; the faction owns which units exist** (D1, D2) | Unit registry, scoped by faction | ★ **v2 reshape.** Unit System stops being the roster owner and becomes the *schema* owner |
| **Base & Production** (#7) | Faction structures (D5-own) + `build_cost`/`build_time`/`production_cap` deltas (D5-mod) | Base & Production | Owed: faction-scoped structure registry + effective lookups |
| **Research/Tech** (#8) | ★ **Owns its own tech tree** (D6) | Research | ★ **v2 widening.** v1 had one shared tech list with availability/cost deltas; v2 has per-faction trees, incl. trees that change unit behaviour |
| **Combat Resolution** (#6) | Unit combat stats — ★ **no longer identity-locked** (CR-6) | Combat, via each faction's own unit stats | ★ **v2 unlock.** The *formula* stays deterministic and shared; only inputs differ |
| **Population Cap** (new) | Base cap, raise-cost curve, per-unit exemptions (D3) | `population-cap.md` | New Tier-1 system |
| **Unit Upkeep** (new) | Per-unit upkeep values + global rate delta (D9) | `unit-upkeep.md` | New Tier-1 system. ★ Prices the design's central tradeoffs |
| **Unit Abilities** (new) | Which catalogue entries the faction's units carry (D8) | `unit-abilities.md` | New Tier-1 system. ★ Catalogue and prices are **base-game**, per CR-3(c) |
| **Unit Classes** (new) | Which classes the faction fields (D2) | `unit-classes.md` | New Tier-1 system (infantry / ground vehicle / air) |
| **Transport & Pilots** (new) | Accessed via D8 | `transport-and-pilots.md` | New Tier-1 system. ★ The Independents' pirate is meaningless without it |
| **Promotion & Veterancy** (new) | Accessed via D6 | `promotion-veterancy.md` | New Tier-1 system. ★ The Holy Cosmic Empire *is* this system |
| **Damage Types** (new) | ★ **Not a faction lever** — base-game content applying symmetrically | `damage-types.md` | New Tier-1 system. Factions differ in which units *deal/resist* types, never in the rules |
| **AI Opponent** (#11) | Reads `faction_of(player)` for scoring | AI Opponent | ★ **Materially harder in v2.** v1's "correctly-costed, Neutral-weighted" fallback worked because every faction played the same army. It does not survive independent rosters — see OQ-7 |

**Ownership note:** Faction owns *content and rates*. It never owns a shared **formula** and never
receives a special case inside one (CR-9).

## Formulas

> ### ★ v2 scope note — read before the tables below
>
> Everything in this section describes the **MOD** domains (D3 population cap, D4 income, D5-mod
> structure costs, D9-mod upkeep rate). Its machinery — the additive `clamp(base + Δ, floor, ∞)`
> shape, the per-domain floors, the intercept-vs-slope income split, the combined-income-ceiling
> rule — **survives v2 unchanged and is still correct.** It is good work and none of it is
> discarded.
>
> The **OWN** domains (D1 roster, D2 classes, D5-own structures, D6 tech tree, D7 loadout, D8
> abilities, D9-own per-unit upkeep) have **no formula here at all**, by design. A faction's own
> unit is not `base + Δ`; it *is* the base for that faction, read directly. There is nothing to
> clamp because there is nothing to drift from.
>
> **Two v1 subsections are consequently obsolete and are retained only as history:**
> - **Domain 1 (`produce_cost` delta)** — superseded by D1. A faction sets its units' costs when it
>   authors them. The floor survives as a *schema* rule: any authored `produce_cost` must be ≥ 1.
> - **Domains 2a/2b (`move_cost` / `soft_move_cap` deltas)** — superseded by D1 for the same
>   reason. `MIN_MOVE_COST` survives as a schema floor, and remains load-bearing: Movement System's
>   Dijkstra reachability shortcut requires `move_cost ≥ 1` for monotonicity, independently of
>   factions.
>
> **★ The floors did not become optional — they moved.** Under v1 they were runtime clamps guarding
> against a bad *delta*. Under v2 they are **load-time schema validations** guarding against a bad
> *authored value*. A faction author writing `produce_cost = 0` must fail at load, exactly as a
> delta driving it to 0 was clamped before. This is the single easiest thing to lose in the
> transition and it is what AC-7/8/9 are re-pointed at.


> *Lean review mode: drafted by `systems-designer` (v1), scoped to MOD domains in v2. Framework-level only — no per-faction balance numbers (those live in the six faction GDDs). Defines the modifier-resolution formula family and its clamps.*

**Generic modifier-resolution formula.** Every faction effect resolves through one shape, applied at the owning system's read site (CR-4):

```
effective_X(base_owner, player) =
    clamp(base_X(base_owner) + faction_delta_X(faction_of(player), base_owner), floor_X, ceiling_X)
```

| Symbol | Type | Range | Description |
|---|---|---|---|
| `base_X` | int/float | domain-specific | Value already Approved in the owning GDD — read-only, never mutated |
| `faction_delta_X` | int | schema-unbounded; **always 0 for Neutral** | The faction's additive modifier for this `(domain, base_owner)` pair |
| `floor_X` / `ceiling_X` | int/∞ | domain-specific | Legal min/max (per-domain table). **Note:** across all VS domains only the **floor** ever binds — every per-domain instantiation below is `max(floor, base+Δ)` with `ceiling_X = ∞`. The `ceiling_X` half of the generic form is currently **dead** (no domain uses it) and is retained only as a placeholder for a future domain that might need an upper clamp (e.g. a capped `production_cap`); it is **not** the income-ceiling guard — that is the separate combined-ceiling *validation rule*, not a per-query clamp. Domains 5c (`tech_available`, a boolean gate) and 6 (starting loadout, a replacement set) are **not clamp-shaped at all** and only share this table for locality. |
| `effective_X` | int/float | `[floor_X, ceiling_X]` | What every consuming system's read site actually uses |

Mirrors `effective_attack`/`effective_defense` (`base + delta`, additive, floored). **Additive, not multiplicative** — integer-AP is a hard invariant (a ×0.8 on Scout cost 2 = 1.6 breaks it); if a future faction ever needs scaling, it overrides a *rate constant* (the `SOFT_MOVE_PENALTY`/`CANCEL_REFUND_RATE` precedent), never bolts a multiplier onto an additive delta.

**Per-domain instantiation (floors + rationale):**

| Domain | Effective formula | Floor | Rationale |
|---|---|---|---|
| 1. `produce_cost` | `max(1, base + Δ)` | 1 AP | 0/negative = free verb (CR-3 violation) |
| 2a. `move_cost` | `max(MIN_MOVE_COST, base + Δ)` | 1 AP/tile | 0-cost move = free verb + unbounded Dijkstra reachability |
| 2b. `soft_move_cap` | `max(1, base + Δ)` | 1 tile | 0 collapses the base/surcharge two-tier shape |
| 3. `credit_income` (was `ap_income`) | `max(BASE_INCOME_FLOOR, (BASE_INCOME+Δ_base) + (OUTPOST_BONUS_TIER1+Δ_tier1)·min(n,T) + (OUTPOST_BONUS_TIER2+Δ_tier2)·max(0,n−T) + econ_tech_term)` — where **`econ_tech_term = has_economy_tech(player) ? ECONOMY_TECH_INCOME_BONUS·min(n, ECONOMY_TECH_TIER_THRESHOLD) : 0`**, carried **verbatim** from AP & Credits Economy's *current 4-term* formula (`ap-economy.md`) — only the resource it denominates changed (Credits, not AP). Factions do **not** modify the tech term or its `ECONOMY_TECH_TIER_THRESHOLD` (=6) cap. | `BASE_INCOME_FLOOR` | Rule-7's floor (10) assumes no subtractive term; a lower floor keeps income > 0. **The base folded here is AP & Credits Economy's *complete, current* `credit_income` formula — the Economy-Tech term and its tier cap are load-bearing (they close a real unbounded-income defect AP & Credits Economy already paid to fix) and must not be dropped when a faction income delta is applied. Domain-3's two sub-levers are named separately below (intercept vs slope).** |
| 4a. `build_cost` | `max(1, base + Δ)` | 1 AP | free-verb logic |
| 4b. `build_time` | `max(MIN_BUILD_TIME, base + Δ)` | 1 turn | instant build removes the vulnerable-investment window B&P documents as intentional |
| 4c. `production_cap` | **base cap ≥ 1:** `max(1, base + Δ)` for a **faction-authored** delta (floor 1, never 0). **base cap = 0** (a non-producer structure — Research Lab / Defensive Structure): effective cap stays **0** regardless of any faction delta — the delta is **inert** (cannot raise a base-zero cap above 0). `max(0, base + Δ)` remains the *mechanical* floor for base-game/symmetric reasons. | **1** (faction, base cap ≥ 1) / **0** (base-cap-0 structure, delta inert; or base-game symmetric) | **A faction `production_cap` delta may move a cap only *within* the producing range [1, ∞); it never crosses the produces / does-not-produce boundary in *either* direction.** (a) A faction may not drive a base-positive cap to 0 — that silently deletes a verb-avenue for one player only (asymmetric removal, CR-3's spirit). (b) *Symmetrically*, a faction may **not** raise a base-**zero** cap above 0 — a structure the base game defines as a non-producer (Research Lab / Defensive Structure, `base-production.md` `production_cap = 0`) cannot be turned into a producer for one faction, because that *creates a new verb the base game withholds* (CR-3 (c)). CR-2.4's delta authority is thus bounded on both ends. The Research-Lab cap-0 is a *symmetric* base-game property (both players), never a faction lever. |
| 5a. `research_cost` | `max(1, base + Δ)` | 1 AP | free-verb logic |
| 5b. `research_time` | `max(MIN_RESEARCH_TIME, base + Δ)` | 1 turn | instant research breaks the destroy-while-researching interrupt |
| 5c. `tech_available` | `base_available AND faction_allows(faction, tech)` | (boolean gate) | availability is a gate, not a clamp |
| 6. starting loadout | `starting_state(player) = faction.starting_loadout` | `starting_ap ≥ 0` | a *replacement set*, not a delta; every placed entity must already be a legal priced entity elsewhere (CR-3) |

**Worked example — Neutral (the critical invariant):** every `Δ = 0` ⇒ `effective_X = clamp(base_X + 0, floor, ∞) = base_X`, since every Approved value already sits at/above its floor (e.g. Scout `effective_produce_cost = max(1, 2+0) = 2`). **Confirms CR-6: Neutral-vs-Neutral changes nothing in any Approved GDD.**

**Worked example — illustrative boundary stress (NOT a balance proposal):** a hypothetical Δ = −3 on Scout `produce_cost` ⇒ `max(1, 2−3) = 1` — clamp absorbs cleanly; Δ = −5 on Heavy `soft_move_cap` (base 2) ⇒ `max(1, 2−5) = 1`.

**Income domain — two named sub-levers (framework contract, not a value).** CR-2.3's "income-curve parameters" is **two distinct levers** on `credit_income`, and they must be named because they shape the felt economic *arc* differently, independent of any value chosen:
- **Intercept lever (`Δ_base_income`)** — shifts the whole curve up/down by a constant. Felt maximally at turn 1, compresses toward noise as income climbs (a flat −2 is 20% of early base-10 income but under 8% of a late ~26–32). This is the right lever for a **uniform-from-turn-1** trait — e.g. the **Independents'** *"economy is more limited than other factions"*: bad at economy always, from turn 1.
- **Slope levers (`Δ_tier1` / `Δ_tier2`)** — change the *per-outpost* marginal bonus, so the gap widens as the economy scales. This is the right lever for a **compounding** trait — e.g. the **Machinist's Union's** *"slower start... excels in the late game"*, and the **Holy Cosmic Empire's** power curve. ★ Note both of those theses are *arc* claims, so an intercept lever alone cannot deliver either of them no matter what value is chosen. An intercept lever alone *structurally cannot* deliver a compounding arc no matter what value is chosen — a shape fact the asymmetry prototype must respect, not discover.

**Combined-income-ceiling rule (hard framework constraint, load-bearing before any non-Neutral income delta ships).** Because a faction income delta stacks a *third* per-`n` term onto a base curve that already multiplies through `OUTPOST_BONUS_TIER1/TIER2` **and** the Economy-Tech term, the same unbounded-stacking failure AP & Credits Economy already caught once (untiered Economy-Tech term, ceiling 26→38 before a cap was retrofitted) can recur along the faction axis. Therefore: **any faction carrying a non-zero income delta (`Δ_base`/`Δ_tier1`/`Δ_tier2`) must be validated against the same `n`-swept ceiling model AP & Credits Economy used in its re-review, and the *combined* ceiling (base tiers × Economy Tech × faction delta) must be re-approved by economy-designer as a single number — not three independently-approved deltas.** This is a validation-discipline rule that costs nothing under Neutral (all Δ = 0, so the combined ceiling *is* AP & Credits Economy's Approved ~26/~32 `credit_income`) and is owed the moment a real delta lands. See OQ-3.

**Two framework flags (prototype-gated, surfaced not resolved):**
- **Per-stat saturation (Pillar 4 risk):** some base values already sit at their floor (Economy Outpost `build_time` = 1), so no faction delta can shorten them — only lengthen. And two factions with deltas −2 and −5 on the same floored stat become *indistinguishable* on that stat. **This is not abstract: run against the actual Approved roster, the two most identity-defining data points are already floored** — Scout `produce_cost` = 2 (a Rush discount can only reach the 1-AP floor: one point of range on the roster's signature cheap unit) and Economy Outpost `build_time` = 1 (no faction can make Boom's signature structure complete *faster* than Neutral). The asymmetry prototype must run a **per-stat headroom audit against the real Approved values** (not per-faction averages) before setting any delta — several levers have near-zero usable range where the fantasy needs them most.
- **Additive income compresses over the match:** covered by the intercept/slope split above — a flat `Δ_base_income` compresses late; the slope levers are the compounding-safe alternative. A shape choice the framework now names explicitly, not a value left to tuning.

**Floors — one already exists today, the rest are one-line additions owed to owning GDDs:**
- **`MIN_MOVE_COST` is NOT undocumented and NOT faction-deferred** — Movement System's Approved GDD already requires `move_cost ≥ 1` *today* as a monotonicity precondition for its Dijkstra reachability shortcut (`movement-system.md`), independent of Faction Identity. Domain 2a simply *reuses* that existing floor (`MIN_MOVE_COST` = Movement's `move_cost ≥ 1`); nothing new is owed here.
- **Genuinely owed (one-line additions to the owning docs, load-bearing only once a faction carries a subtractive delta):** `BASE_INCOME_FLOOR` (AP & Credits Economy, applies to `credit_income` — needs economy-designer sign-off), `MIN_BUILD_TIME` (Base & Production), `MIN_RESEARCH_TIME` (Research/Tech). *(The former `production_cap ≥ 0` item is superseded — faction deltas now floor at 1, see Formulas 4c; the mechanical `≥ 0` remains Base & Production's existing property, not a new owed floor.)*

## Edge Cases

- **If no faction is assigned to a player at setup:** default to **Neutral** (all deltas identity). Guarantees every match is valid and playable on the corpus's shipped balance — the VS default is Neutral-vs-Neutral.
- **If both players pick the same faction (mirror match):** fully legal; it is the intended balance baseline (symmetric, so any imbalance is the map/first-move, not the faction).
- **If two players pick *different* factions (asymmetric match):** ★ **v2 — this is now the normal case, not an edge case**, and it means two genuinely different rosters on one board. Each player's effective-value lookups read *their own* `faction_of(player)` deltas — `effective_X` takes `player` as an argument, so there is no cross-contamination (player A's Rush discount never touches player B's units).
- **If a faction delta would drive a value below its floor:** the Formulas clamp applies (e.g. `max(1, …)`). The result is legal; the excess magnitude is silently absorbed — see the per-stat saturation flag (two factions can become indistinguishable on a floored stat; the asymmetry prototype must check this).
- **If a faction's starting loadout would place an entity on an illegal tile** (occupied, off-board, or violating Base & Production's placement rules): setup validation rejects the loadout — faction loadouts must be *authored* to place only on legal setup tiles for the map. A malformed loadout is a data error caught at load, not a runtime state.
- **If a faction marks a tech unavailable (`faction_allows` false) and the player attempts to research it:** Research's availability gate blocks it exactly as it blocks any illegal action — the tech simply never appears as a legal research target for that faction.
- **If a faction delta would drive a base-positive producer's `production_cap` to 0 (or below):** the faction clamp floors it at **1**, not 0 (Formulas 4c / CR-2.4) — a faction can make a producer *slower* (lower cap) but can never fully delete its production verb, because that would be an asymmetric verb-removal (CR-3's spirit).
- **If a faction delta targets a base-cap-0 structure** (a non-producer such as the Research Lab or Defensive Structure, `base-production.md` `production_cap = 0`): the delta is **inert** — the effective cap stays 0, because a faction may not turn a base-game non-producer into a producer (that would manufacture a verb the base game withholds, CR-3 (c)). Together these two cases mean a faction `production_cap` delta only moves a cap *within* the producing range and never crosses the produces/doesn't-produce boundary in either direction — **resolving** the earlier CR-3-borderline concern by rule rather than by per-faction review. (A true cap of 0 remains a *symmetric* base-game structure property — both players affected identically.)
- **If a base entity a faction's delta keys to is later removed or renamed** (a future Approved-GDD change): the delta is keyed by `(domain, base_owner)`; an orphaned delta is inert and ignored, and schema validation warns at load. Factions never hard-break on a base-roster change — they degrade to "no modifier for the missing entity."
- **If the AI Opponent (#11) plays a non-Neutral faction:** it reads the same `effective_X` queries every other consumer does (CR-4), so its costs/income are automatically faction-correct with *zero* AI code change. However, its *scoring weights* are not faction-tuned in the VS (AI OQ-6) — so the AI plays a faction "correctly costed but with Neutral strategy," an acceptable VS limitation flagged for post-VS.
- **If a faction is switched mid-match:** impossible by construction — faction is LOCKED at the Setup→PlayerTurn transition (States) and immutable thereafter. There is no code path to change it, so no mid-match-switch edge case can arise.

## Dependencies

**Upstream — Hard** (Faction is a pure consumer; its modifier read-sites live *inside* these systems, but under the VS's Neutral default every delta is identity, so the *contract* is owed while the *shipped numbers* are unchanged):

| System | Interface consumed | Handoff owed (additive, identity-default) |
|---|---|---|
| **Game State & Turn Manager** (#2) | Setup phase; per-player state | Store `faction_of(player)`; apply `starting_loadout` at setup. **This is the only handoff needed for a playable VS** (Neutral-vs-Neutral needs faction *plumbing*, not deltas). |
| **AP & Credits Economy** (#3) | `credit_income` | Fold optional faction income deltas into `credit_income`; add `BASE_INCOME_FLOOR` (needs economy-designer sign-off). Framework also allows a faction to re-weight AP surcharges on economic actions — no VS faction uses this, kept Neutral-inert. |
| **Unit System** (#4) | ★ **v2: the faction OWNS its roster (D1/D2).** Unit System keeps the `UnitTypeDef` schema and the shared mechanics; it no longer owns *which units exist* | Faction-scoped unit registry; `MIN_MOVE_COST` and the other floors become **load-time schema validations** (AC-7/8/9) |
| **Base & Production** (#7) | structure `build_cost` / `build_time` / `production_cap` | effective structure-value lookups; add `MIN_BUILD_TIME` + explicit `production_cap ≥ 0` rule |
| **Research/Tech** (#8) | `research_cost`, `research_time`, tech availability | effective research-value lookups + `faction_allows` availability gate; add `MIN_RESEARCH_TIME` floor |
| **Combat Resolution** (#6) | Unit combat stats | ★ **v2: HARD dependency, not soft.** The CR-6 identity lock is gone, so Combat now resolves genuinely different stat profiles every match. The *formula* is unchanged and stays deterministic (Pillar 2); `damage-types.md` extends it symmetrically for all factions |

**Downstream dependents:**
- **AI Opponent** (#11) — already reads `faction_of(player)`-adjusted `effective_X` automatically via CR-4 (no AI change needed to play a faction correctly-costed). Per-faction *scoring weights* are future work (AI OQ-6). Soft, forward-looking.

**Bidirectional-consistency status (owed):** This GDD introduces additive contract obligations on 5 upstream systems (an `effective_X` fold-in + a floor each). Those 5 GDDs are all **Approved** and do **not** yet list Faction Identity (#12) as a downstream dependent (this system was authored last) — a reciprocity gap to close via `/propagate-design-change`. **Critically, because the VS ships Neutral (identity), none of those systems' shipped *numbers* change** — the fold-ins are no-ops until a non-Neutral faction carries a real delta, which is itself prototype-gated. So the handoffs are **owed-but-deferrable**: only the Game State faction-assignment plumbing is needed for a playable Neutral-vs-Neutral VS; the effective-value fold-ins and floors land alongside the asymmetry prototype, not before.

### ★ Reciprocal downstream — the wave-2 systems (added 2026-08-24, S6-09)

Cross-review **W-1**: All 4 systems below declare a dependency on this document, and this
document listed none of them. Reciprocity was **0/11 across the corpus** — every new GDD pointed
up, no old GDD pointed back, so reading only this file gave no hint that changing it would break
them. Restored mechanically; the relationship nature is copied from each new GDD's own
Dependencies table, which remains the authority.

| Downstream system | Nature |
|---|---|
| **Population Cap (#16)** | Hard |
| **Unit Abilities (#19)** | Hard |
| **Unit Classes (#17)** | Hard |
| **Unit Upkeep (#15)** | Soft |

## Tuning Knobs

| Knob | Default (VS) | Safe range / guidance | What it affects / what breaks at extremes |
|---|---|---|---|
| **Per-faction modifier deltas** (the **MOD** subset of CR-2's 9 domains: D3/D4/D5-mod/D9-mod) | Neutral = all 0; the six factions = **provisional until upkeep ships and playtest runs** | Keep each delta small enough that clamps rarely bind (avoid the per-stat saturation trap where two factions read identical on a floored stat). Aggregate per-faction power kept within a fairness band TBD by the asymmetry prototype. | The primary asymmetry dials. Too large → clamps saturate (Pillar 4 blur) or one faction dominates; too small → factions read as reskins (Pillar 4 failure). **All non-Neutral values are unvalidated — do not ship to players before the prototype.** |
| `default_faction` | `Neutral` | fixed for VS | The faction assigned when none is chosen. Neutral keeps the corpus's shipped balance intact. |
| `faction_roster` | `{Neutral, Democratic Alliance, Solar Federation, Galactic Protectorate, Holy Cosmic Empire, Independents, Machinist's Union}` — **names TBD** | Neutral non-playable (reference/default only) | Which `FactionDef`s exist. **Which of the six actually *ship* in a given wave is OQ-12**, a producer call, not this knob |
| **Per-faction rosters** (D1) | six independent sets, ~50–60 units total | authored per faction; every unit passes the schema floors at load | ★ **The primary v2 identity surface.** No clamp protects these — CR-10's baseline comparison is the only guard, and it is a review gate, not a test |
| ~~`combat_stat_deltas_enabled`~~ | **REMOVED in v2** | — | The CR-6 lock. Deleted, not defaulted differently: under independent rosters there is no shared base stat to lock *to*. Retained here struck-through so a reader of the v1 doc finds its disposition. Deterministic combat is unaffected — the lock was never what made combat deterministic. ~~Enabling it opens hp/atk/range asymmetry — a much larger balance surface, deferred past VS. |
| **Floors** — `MIN_MOVE_COST` (= Movement's existing `move_cost ≥ 1`, already Approved), plus `BASE_INCOME_FLOOR` (applies to `credit_income`) / `MIN_BUILD_TIME` / `MIN_RESEARCH_TIME` (owed one-liners), and the faction `production_cap` floor of **1** (Formulas 4c) | see owning GDDs | **owned elsewhere** — this GDD references, does not set (except the faction `production_cap`-floor-of-1 rule, which is this GDD's contract) | Referenced by the Formulas clamps. Setting any too low re-opens the free-verb / instant-action / verb-deletion exploits the floors exist to prevent. Owned by Movement / AP & Credits Economy / Base & Production / Research (owed handoffs). |

**Knob interactions:** the per-faction deltas and the floors are coupled — a delta only produces real asymmetry in the *unsaturated* range above the floor, so the two must be tuned together (a large subtractive delta against a value near its floor produces no differentiation, just saturation). The asymmetry prototype owns finding the deltas; the floors are fixed guardrails those deltas play within.

## Visual/Audio Requirements

The modifier framework still has no presentation surface of its own. But v2 creates one genuinely
new visual problem, and it is load-bearing enough to state here because **this GDD owns the
`FactionDef` schema**.

### ★★ Six factions break "faction = hue"

The art bible's Visual Identity Anchor makes a saturated neon hue the ownership channel, and v1
shipped two: Rush `#FF5A2E`, Boom `#22C7F0`. S5-08 *measured* that pair as near-ideal for
colourblind play — it sits on the blue-vs-yellow axis, the axis red-green dichromats retain, and it
passes deutan, protan and tritan unaided.

**That property does not survive being extended to six.** No six-colour palette is mutually
distinguishable under red-green colourblindness (~1 in 12 men), and six saturated neons on one board
would degrade at-a-glance ownership for players with normal colour vision too.

**Recommended resolution — hue becomes SEAT, not faction (OQ-11, user's call).** Matches are 1v1, so
only two factions are ever on the board. Bind the validated `#FF5A2E` / `#22C7F0` pair to **player 1
and player 2** rather than to faction identity. Faction identity is then carried by:

- **Silhouette** — which under v2 is *genuinely* different for the first time. This is the thing v1
  claimed and never had: S5-08 found all 26 Rush/Boom sprite pairs pixel-identical, because they
  were recolours of one master. Independent rosters make silhouette a real channel by construction.
- **The tile ownership decal** (S5-08, `ownership_marker.gd`) — already the project's only non-hue
  ownership channel, currently `STRUCTURES_ONLY`.

**What this buys:** the measured accessibility property is preserved exactly, art cost drops from
six hue variants per asset to two, and faction identity rides on the channel that actually
distinguishes six armies. **What it costs:** a faction no longer has "its" colour, which is a real
loss of identity in marketing art, menus and lore. Those surfaces can still carry a faction colour
that simply is not used for in-match ownership.

> Cross-references unchanged from v1: hue is owned by the art bible; the `faction_pattern_id`
> non-hue fallback handle remains a required schema field (AC-6b).

## UI Requirements

**One UI surface owed: faction selection at match setup.** The framework requires a *faction picker* on the skirmish/setup screen (and a campaign config hook) so each player's `FactionDef` is chosen before the Setup→PlayerTurn lock (States). The picker must present the 3 VS factions and default to Neutral. Full *visual* design defers to `/ux-design` (OQ-8), but the following **interaction/data contracts are binding now** (they are framework requirements, not visual polish, so they must not be hand-waved):

- **[v2 — likely moot, see OQ-8]** *Experimental factions are gated behind an explicit acknowledgment, not merely labelled.* Under v1 this distinguished the provisional Rush/Boom from the balanced Neutral. In v2 **every** playable faction is provisional and Neutral is not playable, so a gate on all six is a gate on nothing. Retained pending the UX pass. Original rationale: because balance values are provisional/unvalidated, selecting a non-Neutral faction requires the player to pass an explicit "these values are unvalidated" acknowledgment step before the pick can lock. (Neutral — the balanced default — needs no such step.) This is a *behavioral* requirement the UX pass must implement, not a "make it look experimental" suggestion.
- **Starting loadout is previewable before lock-in.** A faction may carry a distinct starting loadout (CR-2.6) — the single largest commitment a player makes per match. Per the corpus's established *preview-before-commit* precedent (Command & Action Interface previews cost/targets before any in-match action), the picker MUST let the player preview a faction's starting units/structures/AP before the Setup→PlayerTurn lock. Committing to a faction without seeing what it starts with would silently violate that precedent.
- **Faction-reveal sequencing in skirmish-vs-AI and pre-lock re-picking** are stated as UX-pass questions (OQ-8): whether the AI's faction is shown before or after the player locks (governs whether counter-picking is possible — a real strategic axis for an asymmetric-faction game), and whether re-picking is allowed pre-lock and whether it re-triggers the experimental acknowledgment. These are flagged for `/ux-design` to resolve, not left silent.

This is a HUD/UX concern, not owned here beyond the binding contracts above. In-match there is no faction-specific UI beyond the existing HUD showing each side's neon hue (and its `faction_pattern_id` fallback).

> **📌 UX Flag — Faction Identity**: This system has a UI surface (the setup-screen faction picker, OQ-8). In Pre-Production, run `/ux-design` for a faction-select screen **before** writing epics. Stories that reference faction selection should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

Each criterion is independently verifiable by a QA tester without reading this GDD. **Type**: Logic (automatable unit/integration — BLOCKING) / Integration (multi-system — BLOCKING) / Config-Data (schema/data well-formedness — **BLOCKING here**, since a malformed `FactionDef` shipping to the VS is a real defect, not a balance nit) / Visual-Feel (advisory). **Covers**: the CR / Formula / Edge it verifies.

| # | Criterion | Type | Covers |
|---|---|---|---|
| AC-1 | GIVEN no faction is assigned to a player at match setup, THEN `faction_of(player)` resolves to `Neutral` and the match is playable | Logic | Edge (no-faction default) |
| AC-2 | **[v2 REVISED]** GIVEN `faction_roster`, THEN it contains `Neutral` plus exactly the six shipping factions, and `Neutral` is flagged non-playable (reference/default only) | Config-Data | CR-6 (v2) |
| AC-3 | GIVEN the `Neutral` `FactionDef`, THEN every `faction_delta_X` across all 6 CR-2 domains equals 0 (or the identity/no-op value for that domain: `tech_available` gate always true, `starting_loadout` equal to the base game's default setup) | Logic | CR-6, Formula (Neutral worked example) |
| AC-4a | **[Regression guard — CR-6 critical invariant; runnable as soon as *any* test-execution path exists (a bare `redot --headless --script` harness suffices — no full CI required; see AC-4b)]** GIVEN a Neutral-vs-Neutral match, WHEN `effective_X` is queried for every unit `produce_cost`/`move_cost`/`soft_move_cap`, every structure `build_cost`/`build_time`/`production_cap`, every tech `research_cost`/`research_time`/availability, and `credit_income`, THEN each returned value **equals the corresponding `base_X` already defined in the owning GDD's base table** (i.e. `effective_X == base_X` for every entity) — a parametrized unit test that reads the base tables directly. It needs no second *game* build (it runs against the data tables, not a playable binary), but it does require the test harness to be stood up first (the project's `tests/` is currently empty). | Logic | CR-6 (regression pin), Formula |
| AC-4b | **[CI wiring — infrastructure dependency, not owned by this GDD]** Once a CI pipeline exists for the project (none does today — no `.github/workflows`, empty `tests/`), wire AC-4a into it as a blocking regression gate so any future change to the modifier-resolution path that perturbs a Neutral value fails the build. **Owner: technical-director / lead-programmer** (test-infra story), tracked separately — this is a prerequisite, not a claim this GDD can assert as already-achievable. | Logic (infra-gated) | CR-6 (regression pin) |
| AC-5 | **[v2: 6 domains → 9]** GIVEN any `FactionDef`, THEN it defines content or deltas for a domain **only** if that domain is one of CR-2's 9 — a schema/loader test asserting the `FactionDef` resource exposes no field outside this closed set (loading a `FactionDef` with an extra/unknown field is rejected at load) | Config-Data | CR-2 |
| AC-6 | **[v2 REPLACED — the v1 criterion asserted the CR-6 lock that v2 removes]** GIVEN any two shipping factions, THEN no unit definition is shared between them unless explicitly marked `shared`, AND every faction-owned unit passes schema validation (`produce_cost ≥ 1`, `move_cost ≥ MIN_MOVE_COST`, `soft_move_cap ≥ 1`, `hp ≥ 1`, `upkeep ≥ 0`) at load | Config-Data | CR-6 (v2), CR-8, Formulas v2 scope note |
| AC-6b | GIVEN any shipped `FactionDef`, THEN it declares **both** a `faction_hue` handle **and** a reserved non-hue `faction_pattern_id` handle (the value/asset may be a TBD placeholder pending `/art-bible`, but the field must exist and be non-empty) — a schema test asserting neither identity handle is absent | Config-Data | Visual/Audio (non-hue fallback schema contract) |
| AC-7 | **[v2 RE-POINTED — runtime clamp → load-time schema]** GIVEN a faction-owned unit authored with `produce_cost` ≤ 0, WHEN the faction is loaded, THEN load fails with a schema-validation error naming the unit and field (it is no longer clamped silently — under v2 there is no delta to absorb, only a bad authored value) | Config-Data | CR-3(b), Formulas v2 scope note |
| AC-8 | **[v2 RE-POINTED]** GIVEN a faction-owned unit authored with `move_cost < MIN_MOVE_COST`, WHEN loaded, THEN load fails — Movement's Dijkstra monotonicity precondition must hold for every unit of every faction | Config-Data | Formulas v2 scope note, `movement-system.md` |
| AC-9 | **[v2 RE-POINTED]** GIVEN a faction-owned unit authored with `soft_move_cap < 1`, WHEN loaded, THEN load fails | Config-Data | Formulas v2 scope note |
| AC-10 | GIVEN a faction income delta driving the computed `credit_income` below `BASE_INCOME_FLOOR`, WHEN `credit_income` is queried, THEN it returns exactly `BASE_INCOME_FLOOR`, never lower, and never ≤ 0 | Logic | Formula (floor, credit_income) |
| AC-11 | GIVEN a structure with a faction `build_cost` or `build_time` delta driving the effective value below its floor, WHEN queried, THEN `effective_build_cost ≥ 1` and `effective_build_time ≥ MIN_BUILD_TIME` respectively | Logic | Formula (floors, build_cost/build_time) |
| AC-12 | GIVEN a faction `production_cap` delta on a structure whose base cap ≥ 1 that would drive the effective value below 1, WHEN queried, THEN it returns exactly `1` (a faction may reduce but never zero a base-positive producer's cap — never 0, never negative). GIVEN a structure whose *base* cap is 0 (symmetric base-game property, e.g. Research Lab / Defensive Structure) with no faction delta, THEN it returns 0 and that producer legally produces nothing (no error state). **GIVEN a structure whose *base* cap is 0 AND a faction *does* author a `production_cap` delta on it (positive or negative), WHEN queried, THEN it still returns exactly `0` — the delta is inert and cannot raise a base-zero cap above 0 (a faction may not manufacture a producer where the base game defines a non-producer).** | Logic | Formula (faction floor 1 / base-zero-inert / base-game floor 0, production_cap), Edge (no asymmetric verb-deletion or verb-creation) |
| AC-13 | GIVEN a tech with a faction `research_cost` or `research_time` delta driving the effective value below its floor, WHEN queried, THEN `effective_research_cost ≥ 1` and `effective_research_time ≥ MIN_RESEARCH_TIME` respectively | Logic | Formula (floors, research_cost/research_time) |
| AC-14 | GIVEN a faction marks a tech `tech_available = false`, WHEN the owning player attempts to research it, THEN Research's availability gate rejects it and it does not appear as a legal research target for that player | Integration | Formula (5c, boolean gate), Edge (tech-availability gate) |
| AC-15 | GIVEN any of the 5 numeric-domain deltas, WHEN the corresponding `effective_X` is queried, THEN the returned value equals `clamp(base_X + faction_delta_X, floor_X, ceiling_X)` computed from the literal delta on file for that faction — verified by injecting a known delta and asserting the exact clamped output, once per domain (a proxy for CR-4's read-site resolution) | Logic | CR-4, Formula (generic formula) |
| AC-16 | GIVEN `effective_X` is queried for any domain across a match, THEN the corresponding `base_X` value in the owning system's base registry is unchanged before and after (read-only) — verified via a registry snapshot diff around **N ≥ one full match's worth of queries (minimum 50)** | Integration | CR-4 (no base mutation) |
| AC-17 | **[v2: any two distinct factions]** GIVEN Player A and Player B on two *different* factions (asymmetric match), WHEN `effective_produce_cost(unit, A)` and `effective_produce_cost(unit, B)` are both queried for the same unit type, THEN each reflects only its own player's faction delta — A's result never incorporates B's delta and vice versa | Integration | CR-5, Edge (asymmetric match, per-player reads) |
| AC-18 | **[v2: all six]** GIVEN both players select the same faction (mirror match, for each of the six, not just Neutral-Neutral), THEN the match loads and is playable with both players' `effective_X` values identical for every domain | Integration | CR-5 (mirror legality) |
| AC-19 | GIVEN a `FactionDef`'s `starting_loadout` places a unit/structure on a tile that is occupied, off-board, or otherwise illegal per Base & Production's placement rules, THEN setup validation rejects the loadout at load time (data error caught before match start, not a runtime crash/silent skip) | Logic | Formula (domain 6), Edge (illegal starting loadout) |
| AC-20 | **[v2 REVERSED — this is the most important behavioural change in the AC set]** GIVEN a `FactionDef` references a unit, structure, tech or ability that is missing from the registry, WHEN loaded, THEN load **fails with an error** naming the faction and the missing reference. v1 logged a warning and continued, which was correct for *deltas on shared values* and is **wrong for owned rosters** — a silently-dropped unit means a faction fields an army it was not designed around, and nothing downstream would detect it | Config-Data | **CR-8** |
| AC-21 | GIVEN a `FactionDef` with a **numeric-domain delta** (cost/mobility/income/structure/tech) keyed to a `(domain, base_owner)` pair that no longer exists in the base roster, WHEN `effective_X` is queried for that owner elsewhere, THEN the missing delta is silently ignored (contributes 0) with no runtime error, and a load-time warning is logged | Logic | Edge (orphaned **cost/mobility/income/structure/tech delta**, base-roster removal — a *different code path* from AC-20's loadout ref) |
| AC-22 | GIVEN a player is assigned a faction at the Setup→PlayerTurn transition, THEN `faction_of(player)` cannot be reassigned for the remainder of the match — no code path/UI/debug command changes it mid-match; a second assignment attempt is rejected or has no effect | Logic | States (LOCKED), Edge (no mid-match switch) |
| AC-23 | GIVEN two matches run with identical faction assignments and identical input/action sequences, THEN every `effective_X` value and every resolved game-state outcome at each corresponding turn is identical between the two runs (deterministic replay) | Integration | CR-7 |
| AC-24 | GIVEN the AI Opponent (#11) is assigned a non-Neutral faction, WHEN it queries any `effective_X` for costs/income during its turn, THEN the returned value is **identical** to the value a human player on the same faction receives for the same query — verified by invoking `effective_X(entity, ai_player)` and `effective_X(entity, human_player)` under identical faction/state and asserting equality. *(The stronger structural claim "zero AI-specific code path required" is a code-shape property, not black-box-observable — it is routed to **code review** (a static check that the AI's cost/income call sites invoke the shared `effective_X` with no AI-only branch), the same routing CR-1 and CR-3's structural claims use. Not a QA AC.)* | Integration | Edge (AI plays a faction via CR-4), Dependencies (AI Opponent) |
| AC-25 | **[v2: the shipping six]** GIVEN each shipping `FactionDef`, THEN loading them raises no schema-validation error, and their non-identity deltas resolve through the same `effective_X` clamp path as Neutral's (legal data even though their balance values are provisional/unvalidated) | Config-Data | CR-6 (2 seed factions ship), Tuning Knobs (provisional deltas) |
| AC-26 | GIVEN a player **confirms** a `FactionDef` at setup (the SELECTING→ASSIGNED commit transition — *not* during preview/highlight), THEN that faction's `starting_loadout` units/structures are placed on the board exactly once, **before** the Setup→PlayerTurn transition completes, and the placed entities match the loadout's declared types/positions exactly. GIVEN a faction is only being previewed (SELECTING, highlighted but not confirmed), THEN **no** loadout placement has occurred. | Logic | States (SELECTING→ASSIGNED commit side effect; no placement during preview), Formula (domain 6) |
| AC-27 | GIVEN the setup faction picker, WHEN a player selects a non-Neutral (provisional) faction, THEN the pick cannot lock until an explicit "unvalidated values" acknowledgment is passed; GIVEN Neutral is selected, THEN no acknowledgment step is required | UI (advisory — owned by `/ux-design`, contract binding here) | UI Requirements (experimental-flag gate) |
| AC-28 | GIVEN the setup faction picker, WHEN a player is considering a faction, THEN that faction's starting loadout (units/structures/starting AP) is viewable before the Setup→PlayerTurn lock (preview-before-commit) | UI (advisory — owned by `/ux-design`, contract binding here) | UI Requirements (loadout preview-before-lock) |

> **Coverage notes (routing decisions, not gaps):** Two claims are **not independently black-box QA-testable** and route to code review / static analysis / schema validation instead — the same pattern the corpus uses for Command & Action Interface's and AI Opponent's Pass-Through / structural claims:
> 1. **CR-1 ("a faction is data, not logic").** A structural property of the `FactionDef` resource, not player-observable behavior. Route to: a schema/lint check that `FactionDef` is a pure data `Resource` (no `_process`, no logic beyond trivial getters) + an ADR fixing its shape. AC-5's closed-field schema test is a *partial* proxy (catches an out-of-domain field) but does not prove the absence of logic.
> 2. **CR-3's universal negatives ("never a third resource," "never a new verb").** You cannot black-box-test the absence of a hypothetical future faction feature. The floor ACs (AC-7/9/11/13) mechanically enforce the "never 0/free" *sub-claim* for the 5 numeric domains (real, blocking); the broader universals are enforced by the CR-2 closed-domain schema (AC-5) + a per-`FactionDef` design-review checklist item at authoring time, not a one-time runtime test.
>
> **Not an AC — advisory residue:** The Player-Fantasy claim that **"each faction reads as its stated thesis, and a player can feel the pre-commitment"** is a subjective, session-level feel judgment about *specific balance numbers this GDD explicitly defers to the asymmetry prototype* (Overview; Tuning Knobs "do not ship before the prototype"). It cannot be pass/fail today because its inputs don't exist in validated form. Track as advisory playtest evidence once the prototype lands non-provisional deltas — a structured "does Rush open differently from Boom, and feel aggressive/patient respectively" questionnaire, mirroring AI Opponent's "credible sparring partner" residue. Until then, **AC-1–AC-28 (including AC-4a/4b, AC-6b)** are the full QA surface for Faction Identity in the VS — of which AC-4b (CI wiring) is infra-gated, AC-27/AC-28 are UI contracts owned by `/ux-design`, and AC-24's "zero AI-specific code path" structural half routes to code review (as CR-1/CR-3 do). The per-stat saturation / additive-income-compression flags (Formulas) and the `production_cap = 0` CR-3-borderline judgment (Edge Cases) are likewise prototype/design-review concerns, not ACs.

## Open Questions

> **v1 disposition first.** OQ-1 (Rush/Boom values) is **void** — those factions no longer exist.
> **OQ-9 is RESOLVED**: its named reopen-trigger fired and CR-6 is unlocked (user decision,
> 2026-08-24). **OQ-10 is PROMOTED to CR-10** — under independent rosters an unenforced fairness
> note is not good enough. OQ-2/3/4 survive, narrowed to the MOD domains. OQ-5 (tech-denial review)
> is **subsumed by CR-10**: under per-faction tech trees, denial is no longer a special lever — it
> is simply the absence of a branch, and CR-10's comparison is what catches an unfair one.

| # | Question | Owner | Target |
|---|---|---|---|
| **OQ-11** | ★★ **Does hue mean SEAT or FACTION?** Six factions cannot all be hue-distinguishable, and no six-colour palette survives red-green colourblindness. Recommendation in Visual/Audio: bind the measured `#FF5A2E`/`#22C7F0` pair to **seat**, and carry faction identity on silhouette (genuinely distinct for the first time under v2) plus the S5-08 tile decal. Preserves the accessibility property exactly and cuts art cost from six hue variants to two; costs each faction "its" colour in-match. **Design-direction call — the user's.** | user + art-director | Before any faction art |
| **OQ-12** | ★ **Do all six ship together, or in tiers?** Six independent rosters is ~50–60 units to design, balance, art and test. The corpus can be *authored* in full (the user's 2026-08-24 decision) while *implementation* still ships in waves. Recommended wave 1: **Democratic Alliance** (baseline, ≈ what the slice already has) + **Solar Federation** (the only faction expressible with almost no new systems). Waves 2+ unlock as Tier-1 systems land | producer + user | Sprint 6 planning |
| **OQ-13** | ★ **Population cap vs upkeep — how do they divide the work?** Both bound army size. The intended split is **cap = how many you may field, upkeep = how long you can afford them**. They must be tuned as a pair; a cap set below where upkeep already bites makes upkeep inert, and vice versa. Note three factions use the cap as a *primary* identity lever (Solar higher, Independents lower + expensive to raise, Protectorate exempt robots), so the cap cannot simply be tuned away | systems-designer + economy-designer | With `unit-upkeep.md` + `population-cap.md` |
| ~~OQ-14~~ | ✅ **RESOLVED 2026-08-24 in `factions/solar-federation.md`.** The proportional income/cost pair *would* have been a null modifier — confirmed by working it through. Solar is differentiated instead on **three non-proportional axes**: a higher infantry ceiling (13 vs 10), materially lower **upkeep** (mean ~1.25 vs ~2, so more bodies are *sustainable*, not just affordable), and ★ lower **AP** costs (`move_cost` 1), which is the one that actually makes volume work — see that document's § "Why volume nearly did not work" | — | ✅ closed |
| **OQ-15** | ★★ **The AI cannot play six different armies with one set of weights.** v1's fallback — "correctly costed, Neutral strategy" — held only because every faction fielded the same units. It does not survive independent rosters: an AI with no concept of transports will never load one, and one with no concept of promotion will never protect a promoted unit. This is a **substantial** AI work item, not a tuning pass, and it is on the critical path for any faction the AI must play. *(Supersedes v1's OQ-7 and AI OQ-6.)* | ai-programmer + technical-director | Before any faction ships to play-vs-AI |
| **OQ-16** | **Faction-unique structures need a placement/production review.** D5-own lets a faction author its own structures (Solar's cheap autonomous defences, Protectorate's robotic production). Base & Production's `production_cap` rules, build-time windows and placement legality were all written against one shared structure set | systems-designer | `factions/*.md` + Base & Production propagation |
| **OQ-17** | **Does `shared` content exist at all?** CR-8 allows a `shared` scope for content deliberately common to all factions. Nothing currently requires it, and admitting it invites the shared-roster erosion the user explicitly rejected. Recommend: **allow it for structures** (an HQ is an HQ) and **forbid it for units**, so faction rosters stay genuinely independent | systems-designer | Tier-1 authoring |
| OQ-2 | **Floors owed to owning GDDs**, narrowed to MOD domains: `BASE_INCOME_FLOOR` (AP & Credits Economy), `MIN_BUILD_TIME` (Base & Production), `MIN_RESEARCH_TIME` (Research). `MIN_MOVE_COST` is already Approved in Movement and now also serves as a **schema** floor (AC-8) | systems-designer | With Tier-1 |
| OQ-3 | **Income shape + combined-ceiling validation** — survives v2 intact (D4 is unchanged). The intercept-vs-slope distinction is *more* important now, not less: several factions' theses are explicitly about economic *arc* (Union "slower start, excels late" needs slope; Independents "economy more limited" needs intercept) | economy-designer | Per-faction authoring |
| OQ-4 | **Per-stat saturation** — largely **dissolved** for OWN domains (no clamp, no saturation). Still live for the MOD domains, and the audit is still owed there | systems-designer | With Tier-1 |
| OQ-6 | **Reciprocity propagation** — now much larger than v1's 5 additive contracts. Unit System stops owning the roster; Research stops owning one tech list; Combat's inputs stop being universal. Run `/propagate-design-change` once v2 is Approved | producer | After `/design-review` |
| OQ-8 | **Faction-selection UI** — carried from v1 and grown: the picker now shows six factions with genuinely different rosters, so it needs a real roster preview, not a stat delta list. The v1 "experimental values acknowledgment" (AC-27) is now arguably moot, since *every* faction is provisional | ux-designer | `/ux-design` |
