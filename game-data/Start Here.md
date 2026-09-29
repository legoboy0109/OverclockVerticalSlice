# Game data

This vault **is** the game's data. Every unit, structure, tech, faction and map is a note here,
and the game is generated from these notes. Open this folder as a vault in Obsidian.

## Editing

- **Stats** live in each note's *Properties* (the box at the top). Change a number, tick a box, done.
- **Links** like `[[Trooper]]` connect things: a structure's `produces`, a tech's `requires`.
  Rename a note and Obsidian updates every link — and the game's name for it follows the title.
- **Leave `id` alone** unless you mean it: it's the name the code knows the thing by.
- **Below the properties** is yours: design notes, reasoning, ideas. The game ignores it.
- **Maps** are drawn as text in a `map` block — see [[Vertical Slice]]. Their `round_limit` is the round limit a match on that map starts with (20–200; the player can still change it).
- **New things:** create a note in the right folder from a template (Templates core plugin,
  folder `Templates`). New units/structures also need art and a place in the game's rosters —
  ask Claude to wire them in.

## Seeing everything at once

The `Tables` folder has table views (Obsidian *Bases*) of every unit, structure and tech,
side by side and editable in place.

## Getting changes into the game

After editing, the game's data files need regenerating. Ask Claude, or run from the project folder:

    python3 tools/vault/build_data.py

It checks every note first and refuses to write anything if something is wrong, telling you
which note and which property. If you forget, the test suite fails and says so.

## What's here

| Folder | What | Game file |
|---|---|---|
| Units | Everything that moves | `data/units/` |
| Structures | Everything that's built | `data/structures/` |
| Techs | The research tree | `data/techs/` |
| Abilities | Unit abilities: cost, range, cooldown, strength | `data/abilities/` |
| Factions | Faction modifiers (only placeholders so far) | `data/factions/` |
| Maps | Boards | `data/maps/` |

Rules the numbers mean are explained in the design docs (`design/gdd/`); a note's *Notes*
section is the place to record why a number is what it is.
