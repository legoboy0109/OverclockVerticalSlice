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
