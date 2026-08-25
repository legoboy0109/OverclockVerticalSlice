# The Legibility Budget

> **Status**: Proposed — answers cross-review blocker **B-4** (`gdd-cross-review-2026-08-24.md`).
> **Owns**: the total count of simultaneous visual channels on the board, which no single document
> owned before. Individual GDDs keep owning *their* visual requirement; this document owns the sum.
> **Authority**: subordinate to `game-concept.md` Pillar 3 and `design/art/art-bible.md`. Where this
> document and the art bible disagree on a *principle*, the art bible wins; this document only
> allocates the budget those principles imply.
> **Author**: main session, 2026-08-24 (S6-11)
> **Not a system GDD** — it is a standard, so it does not carry the 8 required GDD sections.
> **Readable version**: https://claude.ai/code/artifact/4adc45e0-12e4-4fcb-93e9-1c91a5a35fce
> (this file stays the source of record; the page is a rendering of it)

---

## The question

Pillar 3 makes board legibility a **hard gate**: *"if the board is not readable at a glance under
the shipping isometric camera, the depth gets fixed or cut, not shipped."* That gate (S5-03) has
never been run. Since it was written, six GDDs have each added a visual requirement to the board,
and **none of them owns the total**. Four individually-reasonable channels can still be collectively
unreadable.

## The answer, in one paragraph

**Cap the number of facts a unit broadcasts *without being asked* at five, and route everything else
to on-demand or transient display.** "At a glance" is a claim about the always-on layer only — a
glance is what you get before you interact. Depth is supposed to live in the choices, and the
pre-commit preview interface is where a player *makes* choices, so it is the correct home for
almost everything wave 2 wants to show. The board is currently **at seven always-on channels
carrying five facts**, so the first move is not to add anything: it is to reclaim the redundancy
already there. Then run S5-03 to calibrate whether five is the right number, because right now that
figure is reasoned, not measured.

---

## 1. What the board spends today

Read from the shipped renderer (`entity_sprite_feed.gd`, `entity_glow.gd`,
`on_board_glyph_layer.gd`), not from the design docs.

| # | Channel | Encodes | Notes |
|---|---|---|---|
| 1 | **Silhouette** | Unit archetype (Scout / Trooper / Heavy / Sniper) | ⚠ Measured **identical across factions** — S5-08 found the art bible's mandated non-hue faction marker is not in the shipped art |
| 2 | **Faction hue** | Ownership + faction | Measured to clear ΔE 27–45 under all three dichromacies; **fails under full desaturation** (S5-08) |
| 3 | **Body tint** | Can this unit still act? | `EntityGlow.body_tint_for(destroyed, is_actionable)` |
| 4 | **Emission glow** (mode + intensity) | Can this unit still act? | `BREATHE` = has AP, `STATIC` = spent, `FLARE` = event |
| 5 | **Has-acted glyph** | Can this unit still act? | On-board glyph layer |
| 6 | **hp glyph** (pips or numeric) | Health | Branches at `PIP_MAX_HP` |
| 7 | **Ownership decal** | Ownership | Deliberately narrow coverage (S5-08) |

Terrain and overlays sit on separate layers and are budgeted separately (§5).

### ★ The finding: seven channels are carrying five facts

**Channels 3, 4 and 5 all encode the same single bit** — *has this unit acted yet?* Body tint, glow
mode and the has-acted glyph are three simultaneous expressions of one boolean.

That is not a bug. Redundant coding is exactly what accessibility guidance asks for, and it is why
AP state survives colourblindness when ownership does not. But it is the single most important fact
in this budget, because **it means the board's apparent crowding is not all information.** Before
wave 2 adds a channel, there is slack to reclaim — and reclaiming it is cheaper and safer than
inventing a new visual language.

Actual distinct facts on screen today: **ownership, archetype, act-state, health** — four, plus
faction identity riding along with ownership. Call it **five**.

---

## 2. What wave 2 wants to add

| Fact | Source | Cardinality |
|---|---|---|
| Unit class (ground / vehicle / air) | `unit-classes.md` | 3 |
| Damage type | `damage-types.md` | 3 |
| Resistances | `damage-types.md` | ~7 values per unit |
| Area-of-effect shape | `damage-types.md` DT-7 | 3 |
| Abilities | `unit-abilities.md` | 8, per-unit subset |
| Rank | `promotion-veterancy.md` | 4 (0–3) |
| Crew state (crewed / uncrewed / carried) | `transport-and-pilots.md` | 3 |

**Naively that is five to seven new always-on channels on top of seven.** That is the risk B-4
identified, and stated that way it is obviously not survivable.

---

## 3. The budget

### Three tiers, and only one of them is "at a glance"

| Tier | Definition | Budget |
|---|---|---|
| **Always-on** | Broadcast by every unit continuously, with no interaction | ⛔ **5 facts, hard cap** |
| **On-demand** | Revealed when the player selects, hovers, or previews | No cap — this is where depth belongs |
| **Transient** | Shown only during an interaction, then gone | No cap, but **one at a time** |

**Why five.** It is the count the board already carries, and Sprint 5 established that reaching a
legible version of *that* set took a full sprint and required finding and fixing a measured defect.
Five is therefore the largest number this project has evidence it can render legibly — and even that
evidence is incomplete, because S5-03 never ran. **Five is a ceiling supported by experience, not a
target.**

### The allocation rule

> **A new fact does not get an always-on channel because it is important. It gets one only if the
> player must act differently *before* they interact with the unit.**

Test: *would a player make a wrong opening decision if they had to click to learn this?* If no, it is
on-demand. Almost everything fails this test, which is the point — Pillar 3 says complexity lives in
the choices, and clicking a unit **is** the beginning of a choice.

### Allocation of the wave-2 facts

| Fact | Tier | Where | Why |
|---|---|---|---|
| **Unit class** | ⭐ **Always-on** | Silhouette family (merge into channel 1) | You must not have to click to learn a target is unreachable. Ground vs. air changes what can even attack what — a mis-read here wastes a whole turn. The art bible already requires silhouette to carry family identity, so this is a **merge, not an addition** |
| **Crew state** | ⭐ **Always-on** | Reclaimed from the act-state redundancy (§1) | An uncrewed vehicle is inert — tactically closer to terrain than to a unit. Mistaking one for a threat mis-plans the turn. Uses slack that already exists rather than new budget |
| **Rank** | On-demand + a **minimal** always-on tick | Ownership decal (channel 7) gains rank marks | Rank shifts damage numbers, so it matters for target selection — but the *number* can be on-demand. A pip count on an element already being drawn is close to free |
| **Damage type** | **On-demand** | Selection panel + **pre-commit damage preview** | The preview already shows exact damage. A type that changes the number is *expressed by the number*. Showing the type as well is showing the working, not the answer |
| **Resistances** | **On-demand** | Selection panel | ~7 values per unit. There is no glanceable encoding of seven values, and no attempt should be made |
| **Abilities** | **On-demand** | Command menu | They are already actions in the command interface. An ability the player has not opened the menu for is not a decision they are making yet |
| **Area shape** | **Transient** | Targeting overlay | Only meaningful while choosing a target, and must be **exclusive** — never two telegraphs at once |

**Net always-on change: +1 fact (crew state), paid for out of existing redundancy. Class merges into
silhouette. Rank rides an existing element. Everything else leaves the glance layer.**

---

## 4. The rules this implies

1. **The glance layer is closed.** Any GDD proposing a new always-on channel must name the incumbent
   it displaces, or argue past the test in §3. "It is important" is not the argument; "the player
   mis-plays the opening without it" is.
2. **Redundancy is spent deliberately, not accidentally.** Act-state is triple-coded on purpose
   (§1). That is the *only* fact permitted more than one always-on channel, and it holds that
   privilege because it is the most frequently consulted fact in the game and the one whose
   mis-reading wastes a turn. Any other fact acquiring a second channel is a budget error.
3. **One transient overlay at a time.** Move range, attack range, build placement and area telegraph
   are mutually exclusive. Two overlays at once is the failure this rule exists to prevent.
4. **Hue is full.** It carries ownership and faction and nothing else, ever. S5-08 measured it as
   sound under dichromacy but failing under full desaturation, so it has no headroom to lend.
5. **Depth cues stay off the actors.** Restates art bible Principle 3 as a budget rule: elevation
   and occlusion use terrain value and shape. Air units are the live exception and are handled next.

### ⚠ The air-unit problem is not a channel problem

`unit-classes.md` UCOQ-1 flags hovering aircraft with no ground contact against ADR-0013's Y-sort.
That is a **rendering-architecture** question — where does a unit with no tile contact sort, and how
does its shadow read — not a competition for a visual channel. It needs an ADR, and this budget
should not be read as having cleared it.

---

## 5. Terrain and HUD

**Terrain** currently carries two channels (type, elevation value) and wave 2 adds none. Rule 5 keeps
it that way: terrain absorbs depth cues so actors do not have to.

**HUD** additions from `population-cap.md` and `unit-upkeep.md` (net income, current/max population)
are **not board channels** and are outside this budget — they shipped in S6-07. Recording that here
so a future reader does not double-count them against the board's cap.

---

## 6. What this means for the hard gate

**The budget above is reasoned. It is not measured.** Five is defended by "this is what a full
sprint of work achieved" — which is real evidence about cost, and no evidence at all about whether
the result is *readable*.

**Recommendation: run S5-03 on the current build now, before any wave-2 art or renderer work.**

Not as ceremony. Three specific things are unknown, and each changes this document:

| Unknown | If it fails |
|---|---|
| Are the **current five facts** readable at a glance under the shipping camera? | The cap is not 5, it is lower — and wave 2 must *remove* before it adds |
| Is act-state's triple coding **necessary**, or is it over-served? | If one channel does the job, two channels of slack are freed and the crew-state allocation gets cheaper |
| Does faction-hue ownership survive at **playing distance**, not just as a ΔE measurement? | S5-08's Option D is reopened, and ownership needs a real second channel — which would consume the slack this budget just allocated |

★ **This is the cheapest measurement available and it gates the most expensive work.** Every wave-2
visual decision is currently being made against an unverified assumption, and the slice is playable
today. Running the gate costs a session; discovering the answer after the art is authored costs the
art.

### ✅ The mechanical half ran, 2026-08-24 — `production/playtests/s5-03-iso-legibility-2026-08-24.md`

| Unknown | Answer |
|---|---|
| Are the current five facts readable at a glance? | **Yes**, with one exception that is a unit-art defect rather than a channel-count problem — the Sniper carries 13.3% hue coverage against a roster mean of 50.1% and does not read as owned. **The cap of 5 stands.** |
| Is act-state's triple coding necessary, or over-served? | ⚠️ **Necessary.** Brightness alone is a 1.58:1 ratio — thin on its own. See the revision below |
| Does hue-carried ownership survive at playing distance? | **Partially.** It holds on 3 of 4 archetypes and fails on the fourth, and the cause is *coverage*, not hue choice. Still owes the human session |

> ### ⚠️ REVISION — crew state is not free after all
>
> §3 allocated crew state to always-on and funded it from the act-state redundancy. **That
> redundancy is thinner than this document assumed.** Measured, act-state's brightness channel alone
> is only 1.58:1; the triple coding is doing real work rather than merely duplicating. Removing a
> channel to pay for crew state would degrade the most frequently consulted fact in the game.
>
> **Treat crew state as needing new always-on budget, or move it on-demand.** This is the first
> allocation in this document to be overturned by measurement, which is the process working.

> ### ★★ A rule the measurement added, which this document did not anticipate
>
> Contrast in the real frames splits sharply: the **neon accent** clears the bar everywhere (4.26:1
> at the dimmest, 7.17:1 typical, against a 3.0:1 requirement), while the **unit body** never clears
> it (1.80–2.46:1). Units are dark chassis reading almost as stage, plus an accent doing 100% of the
> legibility work. Therefore:
>
> **An archetype's accent coverage *is* its legibility. Coverage is the budget, not hue choice.**
>
> The Heavy (62% coverage) and the Sniper (13%) use the same palette and the same hues; one is
> unmistakable and the other is unreadable. Every wave-2 unit must be measured against this before
> being authored — `tools/analyse_legibility.py` computes it.

---

## 7. The calls that are still yours

This document makes engineering-side allocations. Three judgments underneath them are design
direction, and I have taken a position rather than leaving them blank — say the word and any can go
the other way.

| # | Call | Position taken | The case against |
|---|---|---|---|
| **1** | **Five always-on facts** | Cap at 5; wave 2 nets +1, funded by existing redundancy | Arbitrary until S5-03 runs. A different number is equally defensible today — the *rule* matters more than the figure, and the figure should be re-set by the gate |
| **2** | **Class goes always-on; damage type does not** | Class changes what can *reach* what, which invalidates a plan; type changes a number the preview already shows | If damage types end up as hard counters (`RESISTANCE_MIN/MAX` at ±3), type may become as plan-invalidating as class, and this flips |
| **3** | **Rank gets a minimal always-on tick** | Rides the ownership decal; cheap because that element is already drawn | Rank is a *reward*, and `promotion-veterancy.md` may want it celebrated rather than economised. That is a fantasy argument this budget cannot settle |

Two further items are logged in the cross-review and unchanged by this document: **S5-03** itself
(the gate) and **S5-04** (swing-back), which S6-06 unblocked.
