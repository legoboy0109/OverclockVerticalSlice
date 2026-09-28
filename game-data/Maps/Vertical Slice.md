---
id: vertical_slice
---

The skirmish board. Edit the grid below; spaces between symbols are optional.

| Symbol | Meaning |
|---|---|
| `.` | open ground |
| `c` | cover (attacks against infantry here deal 1 less damage) |
| `r` | rough ground (ground vehicles cannot enter) |
| `#` | blocked (impassable) |
| `A` | player 1's HQ |
| `B` | player 2's HQ |

```map
. . . . . . . . . . . .
. . . . . . . . . . . .
. . . . . . . . . . . .
. . . c . c c . c . . .
. . . . . . . . . . . .
. . A . . . . . . B . .
. . . . . . . . . . . .
. . . c . c c . c . . .
. . . . . . . . . . . .
. . . . . . . . . . . .
```

Rules the tests check for this map: mirror-symmetric left-to-right, and no cover within 3 tiles of an HQ. Each player's starting Builder is placed on the tile directly behind their HQ.

## Design notes

**Why the centre lane (row 6, the HQ-to-HQ row) has no cover — measured, not a gap.** The first
layout had 14 cover tiles including two in the centre lane. In AI-vs-AI batches the nearly-even
games (+1 unit handicap) went from 1 in 6 reaching the round limit to **5 in 6**: cover let a
slightly-behind player hold, then kept holding, and close games became draws. Cover belongs
where a player *chooses* to fight, not where both sides are forced to cross. The 8-tile layout
with the lane open fixed it.

**Why nothing within 3 tiles of an HQ:** units deploy up to 2 tiles from their producer, and
terrain inside that ring has already caused one game-ending bug (the S6-15 spawn-ring latch).

**Why mirror-symmetric:** the batches alternate who moves first because on a symmetric board
that is the only asymmetry; an asymmetric map would make every seat-balance reading measure
the map instead of the game.
