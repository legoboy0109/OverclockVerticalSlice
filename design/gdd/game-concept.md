# Game Concept: OVERCLOCK

*Created: 2026-07-18*
*Status: Draft*

---

## Elevator Pitch

> It's a 2D top-down sci-fi turn-based tactics game where you spend a single pool
> of action points — on building, producing, moving, fighting, and researching —
> to out-tempo a rival commander for control of a contested star sector. Victory
> goes not to the bigger army, but to whoever compounds their action-point
> advantage fastest.

**10-second test:** Every turn you have limited action points and more things you
want to do than points to do them with. You choose. So does your opponent. Whoever
chooses better pulls ahead.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Turn-based tactics + light 4X/base-building (strategy) |
| **Platform** | PC (Steam / Epic) |
| **Target Audience** | Strategy players — Achievers & Competitors (see Player Profile) |
| **Player Count** | Single-player (campaign + skirmish vs AI); hot-seat in prototype |
| **Session Length** | 30–90 min per mission |
| **Monetization** | Premium (no F2P, no microtransactions — see anti-pillars) |
| **Estimated Scope** | Large (1–2+ years, solo) — reached in phases from a weeks-scale prototype |
| **Comparable Titles** | Advance Wars, Into the Breach, StarCraft II |

---

## Core Fantasy

You are a rising faction commander who wins by out-thinking your rival's tempo.
Not the general with the biggest fleet — the one who reads the board, invests a
turn's action points where they'll compound hardest, and times the swing that
tips a close war. The fantasy is **mastery of tempo**: the quiet satisfaction of
an opening that snowballs, and the white-knuckle moment when momentum flips and
you have to claw it back — the *Zero Hour* "barely holding on" feeling, earned
through allocation, not luck.

What you can do here that you can't elsewhere: manage your economy and your army
as *the same decision*. There is no separate "macro screen." Building a structure,
producing a unit, moving, attacking, and researching all spend from one budget, so
every turn is a genuine triage between growing, fighting, and teching.

---

## Unique Hook

**Like Advance Wars, AND ALSO your economy and your army share one action budget —
so macro and micro are the same decision, and the game is a tempo duel over who
compounds that budget fastest.**

- Explainable in one sentence: one AP pool governs everything.
- Genuinely novel: turn-based tactics games separate economy from combat; OVERCLOCK
  fuses them into a single resource, making every turn a whole-strategy triage.
- Connected to the fantasy: the unified budget *is* the "mastery of tempo" fantasy.
- Affects gameplay, not just aesthetics: it reshapes every decision the player makes.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | 4 | Neon Retro-Future palette, snappy AP-spend feedback, satisfying resolve animations |
| **Fantasy** | 3 | Commanding a distinct faction in a contested Milky Way; each faction a different way to wage war |
| **Narrative** | 2 | A single-player campaign per faction — competing principles, territory, and resources give the tactics stakes |
| **Challenge** | 1 (primary) | Deep tempo-duel mastery: sequencing and timing AP for compounding advantage; predictable (non-random) combat rewards planning |
| **Fellowship** | N/A | Single-player focus for v1 |
| **Discovery** | 5 | Learning each faction's AP curves and optimal openings; research trees to explore |
| **Expression** | 4 | Authoring your own strategy each turn (rush / boom / tech / turtle); army composition and base layout |
| **Submission** | N/A | Not a relaxation game — anti-pillar territory |

### Key Dynamics (Emergent player behaviors we want)

- Players discover and refine *opening builds* — sequences of AP spends that reliably
  build early momentum.
- Players learn to read an opponent's tempo and *time a push* to hit before the rival's
  power spike.
- Players experiment to find each faction's distinct win condition and AP rhythm.
- The "swing moment" emerges naturally: momentum tips, the losing side scrambles to
  stabilize — the *Zero Hour* beat, produced by systems rather than scripting.

### Core Mechanics (Systems we build)

1. **Unified Action-Point economy** — one per-turn AP budget spent across build, produce,
   move, attack, and research; movement and actions have per-unit AP costs.
2. **Grid tactical combat** — Advance Wars-style readable top-down grid; predictable
   (deterministic) combat resolution, terrain, unit types with rock-paper-scissors roles.
3. **Base building & unit production** — structures produce units and expand economy/AP
   capacity, all paid from the same AP pool.
4. **Research / tech** — spend AP to unlock units and upgrades; a lever for tempo swings
   and faction identity.
5. **Persistent campaign layer** (post-prototype) — base, research, and army carry between
   missions; asymmetric factions each with a single-player campaign.
6. **Pre-commit action interface** — an Advance Wars / Fire Emblem-style command flow that
   previews a unit's move range, valid targets, and the exact AP cost *before* the player
   commits. Core to Pillar 3 (*Readable Board, Deep Decisions*): the unified AP economy only
   feels deliberate rather than fiddly if the player can see the cost of a choice before
   paying for it. *(Identified as the highest-value missing affordance in the concept
   prototype.)*

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | The unified AP pool lets players author their own strategy every turn — rush, boom, tech, or turtle | Core |
| **Competence** | Skill = allocating AP for maximum compounding tempo; mastery is visible, deep, and always improvable | Core |
| **Relatedness** | Carried by the narrative campaigns and distinct faction identities the player comes to know | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — campaign completion, mastering each faction, climbing personal skill. How: clear goals, persistent progression, deep mastery curve.
- [x] **Explorers** — understanding the AP system, discovering openings and faction synergies. How: research trees, emergent optimal builds, asymmetric factions to learn.
- [ ] **Socializers** — not a primary target for v1 (single-player focus).
- [x] **Killers/Competitors** — out-thinking and out-tempoing an opponent. How: the tempo duel is built for competitive strategists; skirmish vs AI now, PvP a possible future.

### Flow State Design

- **Onboarding curve**: First missions constrain AP and unit choices so the economy is
  legible; complexity is introduced one system at a time (move → attack → produce → build → research).
- **Difficulty scaling**: AI opponents (and later campaign missions) escalate in tempo
  competence and starting position; the "building momentum" arc means early turns are
  simple and pressure ramps as the board fills.
- **Feedback clarity**: Every AP spent is a visible, discrete investment; the board reads
  at a glance (Pillar 3) so the player always knows whether they're gaining or losing tempo.
- **Recovery from failure**: Losing tempo is recoverable through smart stabilization, not a
  death spiral — the swing can flip back. Missions are self-contained; a loss teaches an
  opening to try differently next time.

---

## Core Loop

### Moment-to-Moment (30 seconds) — the turn
Read the board → weigh competing AP demands (expand economy? push a unit? tech up?
build defense?) → allocate AP → watch it resolve. Satisfying because every AP spent
is a visible investment and you can feel whether you're gaining or losing tempo.

### Short-Term (5–15 minutes) — the tempo battle
Establish economy → convert an AP advantage into a research or production lead → probe
for the opponent's weakness → commit to a push or a tech swing. "One more turn" lives
here: *"I'm one turn from my power spike."*

### Session-Level (30–90 minutes) — the mission/duel
A full duel arc: opening builds, a mid-game where momentum tips one way, and a decisive
swing. Natural stopping point = mission resolved. The lingering hook: *"next time I'd
open differently."*

### Long-Term Progression — the campaign
Persistent base, research, and army carry between missions (the STAR COMMAND layer).
The player grows in **power** (unlocked units/tech), **knowledge** (mastering each
faction's AP curves), and **story** (the faction's campaign arc). "Done" = campaign
complete; replay value = 3–5 other factions that play entirely differently.

### Retention Hooks
- **Curiosity**: Undiscovered openings, unexplored research branches, other factions' campaigns and stories.
- **Investment**: A persistent war effort you've grown across missions; a campaign you don't want to abandon.
- **Social**: N/A for v1 (single-player).
- **Mastery**: The tempo duel has a high skill ceiling; there is always a cleaner opening or a better-timed swing to chase.

---

## Game Pillars

### Pillar 1: One Economy, Every Choice
Everything a player does — build, produce, move, fight, research — draws from the single
action-point pool. We never add a parallel resource that lets you dodge the core tradeoff.

*Design test*: If a feature would let players do something "for free" outside the AP
economy, this pillar says **cut it or price it in AP.**

### Pillar 2: Tempo Is the Skill
The game rewards out-accelerating your opponent — investing AP so it compounds faster
than theirs. Depth comes from timing and sequencing, not from bigger numbers.

*Design test*: If we're choosing between a mechanic that rewards *raw power* vs. one
that rewards *timing/sequencing*, this pillar says **choose timing.**

### Pillar 3: Readable Board, Deep Decisions
Advance Wars clarity: the state is always visually legible at a glance, even though the
decisions underneath are deep. Complexity lives in the *choices*, never in the *UI or fog*.

*Design test*: If added depth would make the board harder to read at a glance, this
pillar says **find a clearer expression or cut it.**

### Pillar 4: Factions Are Verbs, Not Skins
Each faction changes *how you spend AP and win tempo* — a different playstyle, not just
different art on the same units.

*Design test*: If a new faction plays like an existing one with reskinned units, this
pillar says **redesign it around a distinct AP strategy or don't ship it.**

### Anti-Pillars (What This Game Is NOT)

- **NOT real-time action**: It would compromise *Readable Board, Deep Decisions* and the deliberate weight of AP allocation.
- **NOT parallel resource economies** (separate money / mana / supply tracks): It would compromise *One Economy, Every Choice.*
- **NOT randomized combat outcomes** (dice-roll hit chance): It would compromise *Tempo Is the Skill* — results must be predictable so mastery is about planning, not luck.
- **NOT grind- or monetization-gated progression**: It would compromise the campaign's Challenge + Story promise.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **Advance Wars 2** | Readable top-down grid tactics, unit production, CO-power identity, clean combat | Add real base-building and fuse economy into a single AP budget; deterministic combat | Validates the readable-tactics core and the appetite for a modern successor |
| **StarCraft II** | Economic/tempo pressure, macro-vs-micro tension, the *Zero Hour* siege-survival feeling | Turn-based, deterministic, single unified budget instead of parallel resources | Validates that tempo duels are deeply replayable and emotionally intense |
| **Into the Breach** | Deterministic, puzzle-clean tactics; perfect information; tight scope | Larger economy/production layer and a tempo-duel opponent rather than pure defense puzzle | Proves a modern readable-tactics audience exists and rewards elegant systems |

**Non-game inspirations**: Synthwave / TRON-era neon sci-fi aesthetics; hard-sci-fi
faction politics (competing principles, not just good vs evil) in the vein of *The
Expanse* and *Battlestar Galactica* for narrative tone.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 20–40 |
| **Gaming experience** | Mid-core to hardcore strategy players |
| **Time availability** | 30–90 min sessions; enjoys a mission in one sitting |
| **Platform preference** | PC (mouse-driven); plays on Steam |
| **Current games they play** | Advance Wars / Wargroove, Into the Breach, StarCraft II |
| **What they're looking for** | A modern, deeper reimagining of readable turn-based tactics with real economic depth |
| **What would turn them away** | Real-time twitch demands, luck-based outcomes, grind or predatory monetization, an unreadable/cluttered board |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Redot 26.2 (Godot 4.x-compatible) — already configured. Excellent 2D tooling (TileMap, scenes, signals), free, clean PC export; ideal for grid tactics |
| **Key Technical Challenges** | (1) Balancing a single-currency tempo economy so no opening dominates; (2) a competent tempo-playing AI opponent; (3) making 4–6 factions genuinely asymmetric |
| **Art Style** | 2D, Neon Retro-Future — bold flat neon, silhouette-first units, faction-coded hues |
| **Art Pipeline Complexity** | Low–Medium — flat colors and clean silhouettes are forgiving to produce solo |
| **Audio Needs** | Moderate — synthwave-leaning score, crisp UI/AP feedback SFX |
| **Networking** | None for v1 (single-player + hot-seat); PvP is a possible future, out of current scope |
| **Content Volume** | Prototype: 1 map, ~4 unit types, 2 factions. Full vision: 4–6 factions, a campaign each, full unit/research trees |
| **Procedural Systems** | None planned — hand-crafted maps preferred for balance and readability |

---

## Risks and Open Questions

### Design Risks
- **AP economy balance**: A single-currency tempo duel is elegant but tuning it so no
  opening dominates is the core design challenge. *(Concept prototype 2026-07-19: no
  dominant opening emerged — rush and boom both won. De-risked, but ongoing tuning work.)*
- **Endgame closeout drag** *(surfaced by the prototype)*: With the HQ as the sole unit
  producer and fixed in a corner, a losing player spam-produces from the corner and decided
  games drag out. This is a named design problem to solve — the base-building and combat GDDs
  must include a closeout-pressure answer (e.g. production caps, rising per-turn unit cost,
  forward-deploy structures that move production off the corner, HQ/corner vulnerability, or
  an attrition/morale mechanic that punishes turtling).
- **Analysis paralysis**: The unified pool could overwhelm players with per-turn options —
  the "building momentum" pacing, readable board (Pillar 3), and the pre-commit action-preview
  menu (see Core Mechanic 6) are the mitigations.
- **Faction asymmetry (Pillar 4)**: Making 4–6 factions genuinely distinct — not reskins —
  is deep, ongoing design work. *(Not yet tested — the concept prototype was symmetric.)*

### Technical Risks
- **AI opponent**: A "tempo race" AI that plays the economy competently is non-trivial.
  Mitigation: prototype with hot-seat / simple AI; invest in AI only once the loop is proven fun.
- **Balance tooling**: Deterministic combat helps, but the compounding economy will need
  data-driven tuning support.

### Market Risks
- **Niche audience**: Turn-based tactics is a focused market — but Into the Breach and the
  Advance Wars revival show it is alive and underfed. The base-building + tempo angle is a
  genuine gap.

### Scope Risks
- **Highest risk overall — scope discipline**: The 4–6 faction / per-faction-campaign vision
  is large for a first game. Mitigation: the phased plan *is* the mitigation — prove the
  prototype before building anything for factions 3–6.

### Open Questions
- ~~Is the unified AP tempo duel *fun* and non-degenerate?~~ → **CONFIRMED** by the concept
  prototype (2026-07-19): no dominant opening; rush and boom both won; tempo swings occurred.
- **Do genuinely asymmetric factions (Pillar 4) produce distinct play — not reskins?** → STILL
  OPEN. The concept prototype was *symmetric* and did not test this. Prime candidate for a
  follow-up prototype, seeded by the two emergent archetypes below.
- **How do we prevent endgame closeout drag?** → open design problem (see Design Risks); to be
  answered in the base-building/combat GDDs and validated in the vertical slice.
- Can a simple AI make the duel compelling? → a *simple greedy AI* was already playable and gave
  a real race in the prototype; a competent tempo AI remains a build-time challenge.
- Does the whole loop (economy + combat + persistence + art) hold up end-to-end? → to be answered
  by the **vertical slice**.

---

## MVP Definition

**Core hypothesis**: *A single unified action-point economy makes a turn-based tempo duel
fun and deep, and two factions built around distinct AP strategies feel genuinely different
to play.*

> **Prototype result (2026-07-19): CONFIRMED for the economy.** The concept prototype
> validated the first half — the unified AP duel is fun and non-degenerate (rush and boom
> both won). The *faction* half was not tested (the prototype was symmetric) and remains the
> open question. Baseline tuning values that felt good — base income 10 + 2/outpost, unspent
> AP lost, unit costs Scout 2 / Trooper 4 / Heavy 6, attack 2 AP, outpost 5 AP, research 6 AP,
> deterministic combat with cover −1 and free counters — are recorded in
> `prototypes/overclock-concept/REPORT.md` for the balance/economy GDD.

> **Current build target = Vertical Slice.** The Prototype tier below is **DONE**
> (2026-07-19, verdict PROCEED). Systems Design should therefore scope GDDs to **Vertical
> Slice depth** — the six faction-agnostic core systems (AP economy, movement, grid combat,
> base/production, research, pre-commit action-menu UX) — and **stub everything else**. Keep
> the faction-identity system deliberately *shallow* (seeded by the rush/boom archetypes) until
> the follow-up **faction-asymmetry prototype** validates Pillar 4. Do not author campaign,
> persistence, or 4–6-faction systems this phase.

**Prototype tier requirements** *(DONE — validated the core loop)*:
1. The unified AP economy — one per-turn budget spent on build / produce / move / attack / research.
2. One hand-crafted map with terrain, grid tactical movement, and deterministic combat.
3. ~4 unit types and basic base-building/production.
4. Two sides (symmetric in the prototype; asymmetry deferred to its own prototype).
5. Hot-seat or a simple AI opponent.

**Vertical Slice requirements** *(the next build target)*:
1. All six core systems above at production quality, unified under one AP economy.
2. One polished mission end-to-end + persistence across 2–3 linked missions.
3. Two **asymmetric** factions (rush/tempo vs boom/mass) — pending the asymmetry prototype.
4. A basic but competent AI opponent, and the pre-commit action-preview menu.
5. Neon Retro-Future art (no longer placeholder) and one faction's opening campaign beats.

**Explicitly NOT in the Vertical Slice** (defer to Alpha / Full Vision):
- Full persistent campaign beyond the 2–3 linked missions.
- Full story, narrative, dialogue.
- Factions 3–6.
- Advanced/competitive AI.

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **Prototype** | 1 map, ~4 unit types, 2 factions | Unified AP economy, grid combat, base/production, hot-seat or simple AI. No campaign/story/persistence | Weeks |
| **Vertical Slice** | One polished mission, 2 factions, 2–3 linked missions of persistence | Full AP loop + persistence + basic AI + Neon Retro-Future art + one faction's opening campaign beats | A few months |
| **Alpha** | All core systems, 3–4 factions rough | All systems present, placeholder art/story, campaign skeleton | Later |
| **Full Vision** | 4–6 asymmetric factions, a campaign each, full unit/research trees | All features polished, full narrative | 1–2+ years |

---

## Visual Identity Anchor — Neon Retro-Future

*This section seeds the art bible. It captures the visual decision before it can be
forgotten between sessions.*

- **Visual direction**: Neon Retro-Future — bold flat colors, chunky readable sprites,
  an 80s-sci-fi / synthwave palette (TRON, classic Advance Wars punchiness).
- **One-line visual rule**: *Every element reads as a bold, flat, neon-lit shape —
  clarity comes from color and silhouette, never from detail.*
- **Principle 1 — Silhouette-first units**: Every unit type is identifiable by shape
  alone, before color. *Test*: if two units are confusable in grayscale, redesign the silhouette.
- **Principle 2 — Faction = hue**: Each faction owns a saturated neon hue; the whole
  board is color-coded ownership at a glance. *Test*: if you can't tell whose unit it is
  from across the room, the palette is wrong.
- **Principle 3 — Dark stage, neon actors**: Muted dark environments so saturated
  unit/UI neon pops. *Test*: if terrain competes with units for attention, dim the terrain.
- **Color philosophy**: Restrained dark neutrals for terrain/space; a small set of
  high-saturation neon hues reserved *exclusively* for factions, AP feedback, and
  interactive elements. Neon means "this matters" — it directly serves Pillar 3
  (*Readable Board, Deep Decisions*).

---

## Setting

A version of the Milky Way where humanity has colonized the stars. Multiple competing
factions fight for territory, resources, and — crucially — **principles**: they disagree
about how colonized space should be governed, not merely who governs it. This gives the
faction campaigns moral texture (competing ideologies, not good-vs-evil) and grounds
Pillar 4 — each faction's *way of waging war* should express its worldview.

### Faction Design Seed (from the concept prototype)

In symmetric prototype play, players self-sorted into two organic archetypes without any
asymmetry being present:
- **Rush / Tempo** — early unit pressure, minimal economy, win before the opponent spikes.
- **Boom / Mass** — invest AP into outposts and research first, then overwhelm with numbers.

These are a ready-made template for the **first two asymmetric factions**: design one to
*lean into* aggressive tempo (cheaper/faster units, weaker economy) and the other into
compounding economy (stronger outposts/tech, slower start). Validating that this asymmetry
produces genuinely distinct play — not reskins — is the goal of the next prototype.

---

## Next Steps

- [ ] Fill in CLAUDE.md technology stack / confirm engine config (`/setup-engine`) — Redot already pinned
- [ ] Create the visual identity spec (`/art-bible`) — builds on the Visual Identity Anchor above; required before the Technical Setup gate
- [ ] Validate concept completeness (`/design-review design/gdd/game-concept.md`)
- [ ] **Prototype the core idea** (`/prototype`) — validate the unified AP tempo duel is fun with 2 factions before writing GDDs
- [ ] If prototype PROCEEDS: decompose into systems (`/map-systems`)
- [ ] Author per-system GDDs (`/design-system [system-name]`) using prototype learnings
- [ ] Build the vertical slice in Pre-Production (`/vertical-slice`) — validate the full loop before Production
- [ ] Plan the first sprint (`/sprint-plan`)
