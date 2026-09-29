---
id: crossroads
round_limit: 120
description: 'A mid-size board: an open centre, with rough ground and short walls on both flanks.'
---

A mid-size board: an open centre, with rough ground and short walls on both flanks.

| Symbol | Meaning |
|---|---|
| `.` | open ground |
| `c` | cover (attacks against infantry here deal 1 less damage) |
| `r` | rough ground (ground vehicles cannot enter) |
| `#` | blocked (impassable) |
| `A` | player 1's HQ |
| `B` | player 2's HQ |

```map
. . . . . . . . . . . . . . . . . .
. . . . c . . . . . . . . c . . . .
. . . . . . . r r r r . . . . . . .
. . . . . # # r . . r # # . . . . .
. . . . . . . . . . . . . . . . . .
. . . . . . c . . . . c . . . . . .
. . . . . . . . . . . . . . . . . .
. . A . . . . . . . . . . . . B . .
. . . . . . . . . . . . . . . . . .
. . . . . . c . . . . c . . . . . .
. . . . . . . . . . . . . . . . . .
. . . . . # # r . . r # # . . . . .
. . . . . . . r r r r . . . . . . .
. . . . c . . . . . . . . c . . . .
```

## Design notes

★ Placeholder name. 18×14 (1.9× the vertical slice's area). Mirror-symmetric left to right; nothing within 3 tiles of an HQ;
the HQ-to-HQ row (row 8) is open — the measured lesson from the vertical slice (cover in the lane both sides must cross turns
close games into draws). The flank walls and rough ground make the north and south routes infantry country; vehicles take the centre.
