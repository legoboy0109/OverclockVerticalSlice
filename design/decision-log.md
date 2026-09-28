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
- ⚠ **Not built: showing rank on the board (PVOQ-3).** Nothing promotes yet; build with the Empire.
  The HUD reader already reports `rank`.

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
