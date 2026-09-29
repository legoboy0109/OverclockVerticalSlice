# Decision log — calls made while building from draft designs

**Why this exists (user direction, 2026-09-28):** build as many core features as possible now,
and rework or remove what doesn't work later. Where a draft design left a question open, Claude
picked a sensible default and recorded it here so every call can be reviewed and reversed.
Game-shaping calls still go to the user; these are the rest.

Each entry: **the call** · why · how to reverse it.

---

## Research (CR-14)

- **Losing the Lab doesn't cancel tier-2 research already in progress** — it finishes. Consistent
  with "keep what you paid for". *Reverse:* cancel research in `GameState.destroy_entity` when a
  player's last Lab dies and the target is tier 2.

## Data vault

- **A note's title is the in-game name; its `id` property is the stable file name** code and art
  refer to. Renaming a note is safe. *Reverse:* n/a — structural.
- **Art is looked up by `id`, not display name** (it used to be the name, which would have broken
  every sprite on a rename).
- **The build roster is a `buildable` checkbox on each structure** instead of four hand-kept lists.
- **Balance configs (economy, combat, AI tuning) are not in the vault yet** — only the things the
  user asked for (units, structures, factions, maps) plus techs. *Extend:* add Kinds to
  `tools/vault/build_data.py`.

## Unit classes (`design/gdd/unit-classes.md`)

- **UCOQ-2 — "difficult terrain" is a new terrain type, `ROUGH`** (map symbol `r`). Infantry and
  aircraft cross it normally; ground vehicles cannot enter it. **No rough tiles were placed on the
  vertical-slice map** — it would change a measured layout. Add them in the vault when wanted.
  ⚠ Drawn as a darker, browner floor tile — placeholder, no rough art exists.
- **Aircraft fly over everything** (terrain, units, structures) but, like everyone, must land on an
  empty, non-blocked tile.
- **Something you cannot target does not block your line of fire** — a ground gun fires under an
  aircraft; an anti-air weapon fires over a tank.
- **Structures count as ground targets** — attackable by anything that can hit infantry or
  vehicles, so the air-only Fighter cannot attack buildings.
- **UCOQ-3 — anti-air follows the Alliance roster exactly:** Fighter (air only), Helicopter (hits
  everything). Snipers, Defensive Structures and everything else cannot hit air. The recommended
  "generalists hit air at reduced effect" needs Damage Types; revisit then.
- **Artillery uses the existing AREA targeting** (fires over obstacles, minimum range 2) until Damage
  Types adds its burst.
- **Vehicles and aircraft don't count toward the population cap** (UC-7). The crew requirement that
  is meant to cap them (PC-8) arrives with Transport & Pilots — until then vehicles are capped only
  by cost and upkeep.
- **UCOQ-1 — the air height cue is in the art, not the renderer:** aircraft are drawn high on their
  canvas with a ground shadow at the bottom, which is the anchor point. No renderer change.
- **Factory `hp` 8 → 14**, matching the Alliance roster table (the 8 was a leftover).
- ⚠ **All new units and the Airfield use placeholder art** (`tools/asset-pipeline/make_placeholder_sprites.py`
  — flat shapes in each side's colour). Real art is a look-and-feel call for the user.

### Findings to review (not fixed)
- **The AI rarely fields vehicles or aircraft.** Over 30 AI-vs-AI games it built 20 Factories and 1
  Airfield but produced 1 Artillery and no Tanks or aircraft. Its scoring prefers them when it can
  afford one; it almost never can. Income is 1,000–1,500/turn and a Tank costs 1,400 plus 500/turn
  upkeep. That is an economy question: vehicles may simply be too expensive for this economy.
- **The AI builds Factories it then doesn't use** — its build scoring values a Factory's throughput
  without checking it could afford what the Factory makes.

## Damage types (`design/gdd/damage-types.md`)

- **DTOQ-1 — three types (kinetic, EMF, incendiary)**, as the draft recommended. No fourth type.
- **DTOQ-3 — EMF is a damage tilt, not a stun.** Status effects are a much larger system.
- **Splash only hits what the attacker could target** — a Bomber's blast doesn't damage aircraft.
  The draft didn't say; this keeps the class rules consistent.
- **LINE attacks start beside the attacker and run along the dominant axis toward the target**,
  always including the target. No shipped unit uses LINE yet.
- **Artillery and Bomber are BURST** (from the Alliance roster); the Tank resists incendiary +2.
  Every machine is EMF −2, every infantry EMF +2 (DT-9b). Nothing in the game deals EMF or
  incendiary yet — those arrive with the factions.
- **Structures have resistances (all 0) and a damage type, but never area attacks.**
- **The AI weighs splash:** damage to other enemies adds value; damage to its own units is taken
  off *after* its kill bonus (otherwise a kill that also wiped out its own units scored like a
  clean one — a test caught this).
- ⚠ **Not built:** the area preview telegraph and the friendly-fire warning before commit
  (AC-13, advisory), and showing a unit's damage type/resistances in the HUD. The attack preview
  number already includes resistance.

## Unit abilities + Transport & Pilots (`unit-abilities.md`, `transport-and-pilots.md`)

- **ABOQ-1 — seven of the eight catalogue entries built; `SPOT` deferred.** Spot changes another
  unit's range mid-turn conditional on adjacency — complex for its payoff, and no base unit needs it.
- **Abilities are vault notes** (`game-data/Abilities/`): cost, range, cooldown, uses and magnitude
  are editable; the effect is code keyed by `id`.
- **Embark/Disembark are implicit** — every non-air unit may embark; they aren't listed on units.
  Their costs are still vault notes.
- **ABOQ-2 — Paradrop is the transport's action** (it carries the ability and its cooldown). AP is a
  player-wide pool in this game, so "whose AP" only decides whose cooldown and turn it uses.
- **ABOQ-4 — an ability and an attack exclude each other** (AB-5 as written): using one blocks the
  other that turn. Embark/disembark are movement and exempt.
- **Passengers and pilots are off the board**, stored inside their vehicle. They still count toward
  the population cap and still pay upkeep, and die with the vehicle (TP-1/4/10).
- **Aircraft do not need pilots.** TP-5a mandates it for ground vehicles only.
- **`crew_bonus` (TP-5d) is not built** — no base unit uses it; it arrives with the Solar/Union rosters.
- **Capture refuses a vehicle with passengers inside** — who would own the passengers is undefined.
- **A crew-targeting hit on a pilot ignores Cover** (the pilot is inside the vehicle).
- **Base roster abilities (my call):** Builder carries **Repair**; Heavy carries **Fortify**;
  Scout and Trooper **can pilot** (per the Alliance roster); every ground vehicle **needs a pilot**;
  new **Transport** (Factory, carries 3 infantry). Demolish, Self Destruct, Capture and Paradrop are
  built and tested but no base unit carries them yet — they belong to faction units.
- **An unpiloted vehicle is drawn dimmed** (the same "can't act" look as a stood-down unit), so a
  fresh tank reads as inert rather than broken.
- **AI:** crews its empty vehicles (walks a pilot over and embarks), and scores Repair, Fortify
  (only when threatened), Demolish, Self Destruct and Capture on the attack scale. It never
  disembarks or paradrops — it has no transport plan yet.

### Findings to review
- In a 30-game batch the AI used Fortify 87× and Repair 61×; games still resolved 27/30 by HQ kill,
  average 63 turns (was 68) — Repair did not stall matches (ABOQ-3's worry).
- The AI still rarely fields vehicles (3 Transports, 1 crewing across 30 games) — the economy
  finding under Unit classes stands.

## Promotion & veterancy (`promotion-veterancy.md`)

- **Built as general machinery, switched on per faction** (`promotes` in the faction's vault note).
  No shipped faction promotes — PV-8 says the Holy Cosmic Empire only, and it doesn't exist yet —
  so the system is inert in play today and proven by tests with a test faction.
- **PV-9 / UOQ-3 — rank does not change upkeep**, per the resolved PVOQ-4.
- **PVOQ-2 — per-unit stats:** rank lives on the unit; one `Unit.effective_max_hp` now replaces every
  read of a unit's max hp (healing, repair, Field Repair, the AI, the HUD reader). No ADR written.
- **A faction whose ranks need support cannot promote while unsupported** (PV-7 only described
  losing rank; promoting during it would undo the drop).
- **Merit from Demolish counts** (it is combat); from Self Destruct it doesn't (the unit is gone).
- ✅ **Rank on the board (PVOQ-3), built 2026-09-28:** 1–3 gold chevrons on a dark plate at the
  tile's lower-right corner, drawn with the units so it layers correctly. Gold, not a faction colour
  (colour means which player). Units have no ownership decal to put a pip on, so it is its own badge.
  Preview: `production/qa/evidence/rank-badges/mockup-composite.png` (a composite, not a screenshot).

## Faction framework v2 + setup screen (`faction-identity.md`, `factions/democratic-alliance.md`)

User decisions (2026-09-28): **colour = which player** (OQ-11); **factions in waves, Alliance first**
(OQ-12); **setup screen with faction picker + AP per turn, round limit, who moves first**.

- **A faction owns its HQ, its buildable structures and its tech tree** (D5/D6); its units are
  whatever those produce (D1 derived, not listed — one less list to drift). Empty lists fall back to
  the shared content, which is what Neutral does, so every older test still means what it meant.
- **Built MOD domains: infantry cap (D3), base income (D4), upkeep rate % (D9).** Not yet built:
  per-structure cost/time deltas (D5-mod), starting loadout beyond the free Builder (D7), ability
  access beyond "what the faction's units carry" (D8 is satisfied by roster ownership).
- **A player can only build their own faction's structures** — enforced in the rules, not just the menu.
- **Rush and Boom are no longer factions**; they are the two seat colour palettes (orange = you,
  cyan = opponent). Neutral stays as the test/default faction.
- **One `MatchSetup` builds every match** — the game, the simulator and the diagnostic tools.
  Factions are set before the first turn, so its income already includes faction modifiers.
- **Match AP is applied to a per-match copy of the economy config**, never the shipped one.
- **Random first move is decided at setup**, not by the rules (determinism applies to play).
- **Setup choices are remembered** in `user://match.cfg`; tests never read it.
- **Alliance deviations from its GDD, kept:** Barracks hp 14 (doc 12), Research Lab hp 12 (doc 10),
  the CR-14 tech tree (doc: Economy I–III), and the **Defensive Structure is not "manned"** (doc AC-6/7
  want it to need a pilot — structures with pilots is new machinery; deferred).
- ⚠ **Not built:** a faction emblem on units (the design's replacement for faction-by-colour), and
  the per-faction comparison sheets (CR-10 — a design-review gate, due as each faction is added).

## Faction wave 2 — Solar Federation (`factions/solar-federation.md`)

- **Solar uses the shared HQ and Builder.** Its design has the HQ making infantry; that predates
  the Builder rule (S8-13) that every faction now follows.
- **Faction variants of shared buildings are their own structures** (Solar Barracks — 4 allowed,
  its own production list; Solar Factory; Solar Airfield). The Research Lab is shared.
- ⚠ **Placeholder art is BORROWED** (`art_id`): e.g. Pilot and Volunteer both look like a Scout,
  Citizen Trooper like a Trooper, Gun Truck and Armoured Transport like the Transport. Units that
  look identical but play differently are a real legibility problem — the first thing real art fixes.
- **Crew bonus (TP-5d) built as `crew_bonus_attack`** — the Pilot's +1. Other crew-bonus stats
  (hp, move, range) are not built; no unit uses them yet.
- **Income:** −200 base, −100 per economy tier; with CR-14's single economy tier, Solar's income
  runs 800 → 1,200 against the Alliance's 1,000 → 1,500.

### Findings to review
- **Solar vs Alliance, 60 AI-vs-AI games (both seats): the Alliance won 39 (65%).** All games
  resolved, no errors. ⚠ Weak evidence: the AI plays Solar as mass Citizen Troopers — it produced
  19 Pilots, 4 transports and **no Medics, Volunteers or Lance Teams** — so Solar's specialist
  identity is untested; and the harness's handicap cells hand out Alliance Troopers to both seats.
  A symmetric-policy AI cannot measure faction skill ceilings anyway (see `.agent/notes.md`).

## Faction wave 3 — Independents (`factions/independents.md`)

- **Built as designed** with its own Barracks (2 allowed, 900 each), Factory (1) and Airfield (the
  Buzzard); the shared Research Lab and Defensive Structure. The Buzzard is an aircraft that needs a
  pilot (the design says so; TP-5a only mandates it for ground vehicles).
- **Economy Tier III denial is moot** — CR-14 removed tiers II and III.
- ⚠ **The Marksman ships without SPOT** (deferred). Placeholder art borrowed from base units.

### Findings to review
- **Independents vs Alliance, 60 AI games: the Alliance won 51 (85%)**, in ~31 turns. The design
  intends a poor, small army that wins by stealing vehicles — **the AI built 1 Pirate in 60 games and
  captured nothing**, so it plays the Independents as a weak generic army. Either the faction is
  too weak on paper, or (more likely) the AI can't play its identity. Worth your eyes before tuning.

## Faction wave 4 — Machinist's Union (`factions/machinists-union.md`)

- **Built as designed**: Machinist (crew bonus +1 attack AND −1 move cost), Foreman, Guard; Walker,
  Siege Mech, Hauler, Lancer (EMF), Battery (area, min range 2); two crewed aircraft; Union
  Barracks (2), Factory (3, 16 hp), Airfield, and the crewless Bulwark (attack 5, 14 hp, 4 allowed).
- **Crew move bonus built** (`crew_bonus_move_cost`), floored so movement is never free.
- **Its "compounding arc" is compressed by CR-14:** designed for three economy tiers (700 → 2,800);
  with one tier it runs 700 → 1,600 vs the Alliance's 1,000 → 1,500 — it still overtakes, sooner
  and by less. Worth revisiting if more economy tiers come back.
- **The Bulwark has defence 1** (the Alliance Defensive Structure's value; the design table omits it).

### ★ Findings to review — the AI cannot play the non-baseline factions
- **Union vs Alliance: Alliance 53/60.** The AI built 4 Union vehicles in 60 games (the Union's
  whole identity) and fought with Machinists and Foremen.
- **This is the third faction in a row** (Solar 21/60, Independents 9/60, Union 7/60 wins) losing
  for the same reason: the AI values units by cost and plays every faction like the Alliance —
  it never builds specialists, never steals, rarely affords vehicles. `faction-identity.md` OQ-15
  already names this: *"the AI cannot play six different armies with one set of weights."*
  ⇒ **Faction-aware AI is the prerequisite for any faction balance judgement.** Until then these
  win rates measure the AI, not the factions.

## Faction wave 5 — Galactic Protectorate (`factions/galactic-protectorate.md`)

- **Mech Autonomy built as a data effect** (`frees_pilots` on a tech): once researched, Sentinel and
  Breaker mechs stop needing pilots and crewed ones eject their pilot onto an adjacent tile (it
  stays aboard if there's no room). Tanks never stop needing crew (CR-11a). "Needs a pilot" is now
  a live question (`Unit.needs_pilot`), not just a type flag.
- **Mech Autonomy is gated on a Research Lab** (my call — the design gives no prerequisite); it is
  in the Protectorate's own tree only.
- ⚠ **The Cinder Tank has one weapon, not two.** Its design gives it napalm at range 2–4 and a
  machine gun at range 1; "attack profiles chosen by range" is new machinery nothing else needs.
  It ships with the napalm gun (incendiary, area targeting, min range 2).
- **Lance Tank and Cinder Tank use area targeting** (indirect fire) because of their minimum range.
- **The Servitor is robot infantry: EMF −2, cap-exempt, 300 upkeep, a −1-attack pilot.**
- ⚠ Support Specialist ships without SPOT. Placeholder art borrowed.

### Findings to review
- **Protectorate vs Alliance: Alliance 48/60.** Clearest case yet of the AI problem: it built
  **89 Lance Specialists** — anti-armour troops that cannot shoot infantry — against a mostly-infantry
  army. The AI values a unit by its price without asking what it can hit.

## Faction wave 6 — Holy Cosmic Empire (`factions/holy-cosmic-empire.md`)

- **The only faction that promotes** (`promotes`, with the Cathedral as rank support — PV-7).
  Knights are produced with 6 starting merit (rank 1).
- **The Cathedral is the Empire's Research Lab**: its own structure (900, 12 hp) that **counts as a
  Research Lab** (`counts_as`), so it gates tier-2 research like one. General machinery — any
  faction's variant building can stand in for a shared one.
- **Doctrine I→II→III**: strictly sequential, ground-vehicle-only attack/defence; gated on the
  Cathedral (my call — the design gives no structure gate).
- **Empire vehicles and aircraft survive on defence** (3 / 2 / 2) rather than hit points; aircraft
  need pilots ("no autonomous units").
- ✅ Rank is shown on the board (see Promotion above).
- ⚠ Confessor ships without SPOT. Placeholder art borrowed.

### Findings to review
- **Empire vs Alliance: Empire 29 / Alliance 31** — the closest matchup — **after** teaching the AI
  to build its Cathedral. Before, it never built one (the AI only knew the building literally named
  "Research Lab"), so every veteran lost a rank a turn and the Empire won 25/60.

## The six factions — where things stand (2026-09-28)

| Faction | Wins vs Alliance (60 AI games) | Main reason |
|---|---:|---|
| Solar Federation | 21 | AI never fields its specialists |
| Independents | 9 | AI never steals (1 Pirate built) |
| Machinist's Union | 7 | AI can't afford its vehicles |
| Galactic Protectorate | 12 | AI buys anti-armour troops against infantry |
| Holy Cosmic Empire | 29 | closest to even |

⇒ **These measure the AI, not the factions.** The single most valuable next step for faction
balance is a **faction-aware AI** (OQ-15) — it at least needs to value a unit by what it can hit
in the current matchup, and to use each faction's signature tools.

## Faction-aware AI (OQ-15) — first pass, 2026-09-28

- **The AI values a unit by what it can hit in this matchup**, not by its price alone: a
  multiplier of 0.25 + 1.25 × (share of the enemy's worth it can target, weighted by how much of
  their hp one hit takes, after defence and resistance). Builders keep their flat value; unarmed
  transports sit at the floor (the AI has no plan for carrying troops — at a flat value it bought
  89 Haulers).
- **Pilots are wanted while the AI owns an empty vehicle** (+1.5 on a pilot-capable unit).
- **Crew-targeting attacks are valued as what they do** (kill the pilot, leave a vehicle to steal),
  and a unit that can Capture walks toward empty enemy ground vehicles.
- Knobs in `AIConfig`: `matchup_floor`, `matchup_scale`, `crew_need_bonus`.

### Results — faction wins vs the Alliance, 60 AI games each (both seats)

| Faction | Before | After | Note |
|---|---:|---:|---|
| Solar Federation | 21 | **10** | now crews its Gun Trucks — but 4-hp Citizens die to one Sniper shot, and the Alliance AI now builds Snipers. ⚠ **Likely a real balance signal** |
| Independents | 9 | **23** | Pirate/crew play and better unit choice |
| Machinist's Union | 7 | **18** | builds its Batteries now |
| Galactic Protectorate | 12 | **18** | stopped mass-buying anti-armour against infantry |
| Holy Cosmic Empire | 29 | **28** | unchanged |
| **Total** | 78/300 | **97/300** | Alliance mirror still healthy: 29/30 HQ kills, avg 55 turns |

⇒ Better, still Alliance-favoured. Two things remain unknowable from this harness: whether the
Alliance is simply the strongest roster (its design is "complete"), and how much is the AI still
not playing specialists (Solar's Medics/Volunteers, the Independents' Saboteurs) or transports.
A human playing each faction is the next real measurement.

## AI — specialists and transports (second pass, 2026-09-28)

- **Specialists are valued by their abilities** as well as their gun: Repair by how much of the
  army's hp is missing, Demolish by its boosted hit on enemy structures, Self Destruct by its blast
  (halved — one use). Transports by the share of infantry far from the fight.
- **Transport plan:** far-off infantry boards a working transport; a loaded transport advances
  like any unit; near the enemy it unloads (or paradrops) a passenger on the tile that best sets up
  an attack. Knobs: `transport_far_distance` (6), `transport_turns_estimate` (2).

### Results (60 games per faction vs the Alliance)
Solar 9 · Independents 21 · Union 18 · Protectorate 15 · Empire 26 = **89/300** (was 97). The
Alliance mirror is byte-for-byte unchanged (29/30 HQ kills, avg 55 turns).
- ✅ Specialists now appear and act: Medics 34, Volunteers 13, Saboteurs 11, Support 26, Demolitions
  76, Confessors 41; Demolish used 77×, Self Destruct 5×, Repair far more.
- ⚠ **Transports still barely feature (2 built).** Not a bug — the plan is unit-tested — but on the
  12×10 board most infantry is within 6 tiles of the fight for most of the game, so a transport
  rarely beats walking. **Transports need bigger maps to matter**; worth remembering when maps are
  authored.
- ⚠ Using specialists did not make their factions win more. Either the specialists are weak as
  designed, or the AI uses them crudely (e.g. a Medic spends its turn healing instead of shooting).

## Bigger maps (2026-09-28)

- **Two new maps, drawn in the vault:** *Crossroads* (18×14 — open centre, walled/rough flanks) and
  *Highlands* (24×16, the engine's maximum — two ridges with passes, rough foothills that stop
  vehicles). ★ **Placeholder names** — rename the notes to rename the maps.
- **All maps follow the vertical slice's measured layout rules**, now enforced for every map by
  `tests/unit/map/all_maps_test.gd`: mirror-symmetric, nothing within 3 tiles of an HQ, an open
  HQ-to-HQ row, both starting Builders seated, HQs reachable.
- **A Map row on the setup screen** (remembered like the other choices). The user listed which
  settings to expose before multiple maps existed; a map picker is the necessary addition.
- **Camera:** a map bigger than 12×10 opens at the tile size the 12×10 board shows (the size the
  legibility gate was measured at), centred on your HQ — not shrunk to fit. **Zoom now works on
  keyboard (+/−, keypad +/−) and gamepad (RT in / LT out)**, not only the mouse wheel; zooming keeps
  the cursor in view. ⚠ Zoom is **not rebindable** in Settings: the triggers are axes and the
  rebinding system handles keys and buttons only.
- **"Behind the HQ"** (the starting Builder's tile) now means away from the enemy along whichever
  axis separates the HQs, so top-vs-bottom maps work too.

### Findings to review
- ✅ **Transports finally get used on big maps** (Highlands: 20 built, 27 boardings, 5 unloads; the
  small map: 2 built).
- ⚠ **Big-map games mostly run out the 80-round limit** (AI mirror: Crossroads 17/30 capped,
  Highlands 24/30; small map ~1/30). The AI does not commit to attacking across a long board.
  Options: a longer default round limit per map (you can already raise it on the setup screen),
  and/or making the AI push toward the enemy HQ harder on big boards.
- ⚠ The AI produces a great many Builders (~80 per game on the big maps) — they are cheap and get
  consumed building; worth capping if it shows up in play.

## AI pushes harder on big maps (2026-09-28)

- **Builder cap:** the AI keeps at most `max_builders` (1) spare Builders; the ~80-per-game
  Builder spam is gone.
- **Transports valued by need:** it counts far-away infantry that don't already have a seat, so it
  no longer overbuilds Haulers.
- **Mass before advancing:** a unit won't step into enemy firing reach unless enough friendly
  armed units are nearby. That means at least as many as the enemies covering that tile, and at
  least `mass_minimum` (2) within `mass_radius` (3). Before this, units trickled forward one at a
  time and Snipers picked them off (1,137 Snipers built in one batch, armies of 2–5). A wounded
  unit that is under threat may still retreat freely.
- Results (AI mirror, 30 games per map, HQ destroyed before the round limit):
  **small map 30/30** (avg 51.8 turns), **Crossroads 12/30**, **Highlands 8/30** (was 3).

### Findings to review
- ⚠ **Big maps still mostly run to the round limit.** The remaining drain is structures being
  destroyed and rebuilt over and over (one Highlands batch rebuilt 265 Barracks, 162 Factories
  and 81 Research Labs), which keeps armies small. That is an economy/attrition question, not a
  quick AI fix.
- ★ **Your call:** give each map its own default round limit (e.g. Crossroads 120,
  Highlands 160), so long maps have room to finish.

## Per-map round limits + push for the HQ (2026-09-28)

- **Per-map round limit (user decision):** each map note carries `round_limit`: Vertical Slice
  80, Crossroads 120, Highlands 160. Choosing a map on the setup screen switches the round limit
  to that map's value, and the player can still change it afterwards. Tests keep every map within the
  setup screen's 20–200 range, and a bigger board never gets a shorter limit than a smaller one.
- **Push for the HQ (user direction):** a unit is *ready to push* when at least 3 friendly
  fighters (itself included) are within 3 tiles of it **and** the enemy has fewer armed
  defenders within 4 tiles of its HQ than that group. While pushing:
  - attacks on **unarmed non-HQ buildings** are worth 10% of their usual value, with no kill bonus;
  - its movement goal is the enemy HQ (the "walk toward the nearest enemy thing" pull is off),
    and each tile closed on the HQ is worth 3× the normal amount;
  - **enemy units and armed buildings (turrets) keep their full value**, since they are what
    stands in the way.
  Knobs: `push_group_size`, `push_defence_radius`, `push_structure_value_factor`,
  `push_siege_multiplier` in `ai_config.gd`.
- Results (AI mirror, 30 games per map, HQ destroyed before the limit):

  | Map | Before (80 rounds) | Push AI, 80 rounds | Push AI, map's own limit |
  |---|---|---|---|
  | Vertical Slice | 30/30 | — | 30/30 (limit 80, avg 26 rounds) |
  | Crossroads | 12/30 | 17/30 | 21/30 (limit 120, avg 54 rounds) |
  | Highlands | 8/30 | 8/30 | 16/30 (limit 160, avg 78 rounds) |

### Findings to review
- ⚠ **The push helps on Crossroads, but not measurably on Highlands.** There, the gain comes from
  the longer limit alone. Structure churn is still high on both big maps (Highlands: ~300
  Barracks and ~230 Factories built per 30 games). Worth a dedicated look at *why* groups rarely
  form on Highlands, e.g. whether the ridges split them before they reach 3.
- The simulator's own safety cap was raised from 200 to 402 player turns, so a 160-round map
  ends on its own limit.

## Why groups don't form on Highlands (investigation, 2026-09-28)

Measured with the simulator's new `--push-trace` (Highlands, 80 rounds, 30 games each).
- **It isn't the ridges. The AI barely has an army:** 1.8 fighters per side on an average turn,
  and a group of 3+ on only 6% of turns. That is far below the unit cap (~10).
- **Cause (Alliance): the Sniper.** Attack 6 at range 3 kills a Sniper, Trooper, Scout or Builder
  in one shot, from beyond their reach. Both sides build almost only Snipers (1,084 in 30 games),
  and **Sniper-kills-Sniper happened 750 times**. Every new unit dies on arrival, so nothing
  accumulates.
- **Balance experiments** (vault untouched, via `--unit-stat=sniper.attack=4` etc.):

  | Sniper change | HQ kills | Group of 3+ | What the AI built instead |
  |---|---|---|---|
  | none (attack 6, range 3, cost 500) | 8/30 | 6% | Snipers |
  | attack 5 | 10/30 | 4% | still mostly Snipers |
  | **attack 4** | **17/30** | **20%** | mostly Heavies |
  | cost 800 | 5/30 | 3% | Snipers + Heavies |
  | range 2 | 2/30 | 9% | even more Snipers |

- **Other factions show the same thin-army pattern** (groups of 3+: Empire 2%, Union 8%) but
  still finish games (Empire 25/30, Union 29/30). The Empire has its own one-for-one duel
  (Inquisitor kills Inquisitor 254 times).
- **Builders are a big money drain:** about a third of all kills are Builders (Sniper→Builder 558),
  and the AI keeps replacing them (1,163 built even with the one-at-a-time cap).
- ★ **Open decision (user):** whether to change the Sniper, e.g. attack 6 → 4.

## Sniper rebalance + Builders stay home (2026-09-29)

- **Sniper: attack 6 → 4, cost 500 → 550 (user decision).** It still one-shots Snipers, Scouts
  and Builders, but takes 2 hits to kill a Trooper and 3 to kill a Heavy. The combat GDD
  shots-to-kill tables are updated.
  - Cost was tested at 500 / 550 / 600 (with attack 4 and the Builder fix, 80 rounds, 30 games):
    groups of 3+ formed on 38/34/4% of Crossroads turns and 43/36/7% of Highlands turns.
    **At 600 the AI went back to mass-building Snipers.** 550 is the "slight" increase.
  - ⚠ **Why 600 backfired — an AI flaw, recorded, not yet fixed:** the AI rates a unit as
    *price × how well it fits the matchup* (`AI._production_value`), so a pricier unit looks
    *more* valuable to it. Any future price change can move AI behaviour the wrong way until
    the AI rates units by what they do, not by what they cost.
- **Builders stay home (AI fix, my call).** Builders were getting the fighters' "advance" and
  "go for the HQ" orders. The check only asked "has it attacked yet this turn?", never
  "can it fight?". 466 of 655 Builder deaths were 8+ tiles from their own HQ. Now a Builder
  only moves to get *out* of enemy reach, and otherwise waits by the base.
  - Builder fix alone (Highlands, 80 rounds): Builders built 1,163 → 662, Builders killed 655 → 202.
  - Everything together: Builders built ~400 and killed ~50–75 per 30 games, down from 1,163 and 655.
- **Faction balance check** (each faction vs the Alliance, small map, 30 games each): the faction
  won Protectorate 12, Empire 16, Independents 8, Union 5, Solar 7 — **48/150 (32%), vs ~30%
  before.** The weaker Sniper did not sink the Alliance; it builds Heavies instead.
- **Final check** (all changes, each map's own round limit, 30 games each):

  | Map | HQ kills before | HQ kills now | Group of 3+ (turns) | Builders built / killed |
  |---|---|---|---|---|
  | Vertical Slice (80) | 30/30 | 26/30 (avg 24 rounds) | 43% | 284 / 55 |
  | Crossroads (120) | 21/30 | 18/30 (avg 30 rounds) | 36% (was ~4%) | 425 / 57 |
  | Highlands (160) | 16/30 | 13/30 (avg 48 rounds) | 47% (was ~6%) | 426 / 85 (was 1,163 / 655) |

### Findings to review
- ⚠ **Armies now form, but slightly fewer games end by HQ kill.** On Highlands a group is ready to
  push on 44% of turns, yet only ~35% of fighters are ever in the enemy's half. Both sides now
  have real armies to defend with, and ready groups seem to advance slowly. Unverified guess: the
  shared per-turn AP pool is spent on building, production and research before the army moves.
  Next step, if wanted: tally AP spent by category in the simulator.

## Where the AP goes + AP priority (2026-09-29)

Measured with the simulator's new `--ap-trace` (AP spent by action type, AP left per turn, and
why each idle fighter stayed put). 30 games per map, each map's own round limit.

### Findings
- **AP is not scarce.** The AI spent only about 20% of the AP it received, and **about half of all
  AP was lost** over the 10-point carry-over cap. Every turn ended because nothing left was
  worth doing, never because AP ran out. Building, production and research used about 5% of
  spent AP; the economy is limited by Credits.
- **Fortify ate the army's turns.** It was used 11,608 times in 30 Highlands games (about 2 per
  side per turn). The AI valued it at about 2.0 per AP, against 0.16–0.6 per tile for moving, so
  any unit within enemy reach dug in, and moving would have cancelled it.
- **Idle fighters mostly had a move, just a "diluted" one.** The advance logic always offered
  the furthest reachable tile. When terrain forced a detour (e.g. 5 tiles walked to get 3
  closer), that tile scored under the bar and the unit did nothing, although a shorter,
  worthwhile step existed. That covered 52–70% of idle fighters.
- Unpiloted Artillery accounts for most of the rest (a minor, separate issue).

### What changed (the AI's AP priority)
1. **Efficient moves first:** a tile that clears the "worth doing" bar always beats a further
   one that doesn't (both the advance and the go-for-the-HQ moves).
2. **Fortify is a holding action:** it's worth nothing to a unit in a push-ready group, or to one
   with a worthwhile move. It is still used by units that have nowhere good to go.
3. ✗ **Tried and removed: "use it or lose it"** (spend AP that would be lost over the cap on any
   positive, credit-free action). It made no measurable difference, because by turn end the AI
   genuinely has nothing useful left to do.
- Knobs: `efficient_moves_first`, `fortify_hold_rule` (0 = old always-fortify, 1 = not in a
  ready group, 2 = also not with a worthwhile move; shipped at 2). Rule-by-rule measurements
  were run on Highlands; the Fortify rule is the big lever.

### Results

| Map | HQ destroyed before → after | Avg rounds of those games | Group of 3+ (turns) |
|---|---|---|---|
| Vertical Slice | 26 → 30 /30 | 24 → 26 | 43% → 23% |
| Crossroads | 18 → 23 /30 | 30 → 56 | 36% → 7% |
| Highlands | 13 → 27 /30 | 48 → 84 | 47% → 4% |

Faction vs Alliance: 46/150 (was 48/150). Unchanged.

### ★ Trade-off for the user
The AI now finishes far more games, but by **steady pressure, not massed pushes**: groups rarely
form, and decisive games take longer. Fortify's +4 defence was what let waiting units survive long
enough to gather. Setting `fortify_hold_rule` back to 0 restores the old dig-in-and-mass style
(more groups, far fewer decisive games).
