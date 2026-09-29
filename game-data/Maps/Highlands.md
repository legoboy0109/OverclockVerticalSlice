---
id: highlands
round_limit: 160
ap_per_turn: 30
description: 'The largest board: two ridges with passes, rough foothills that stop vehicles, and cover in the passes.'
---

The largest board: two ridges with passes, rough foothills that stop vehicles, and cover in the passes.

| Symbol | Meaning |
|---|---|
| `.` | open ground |
| `c` | cover (attacks against infantry here deal 1 less damage) |
| `r` | rough ground (ground vehicles cannot enter) |
| `#` | blocked (impassable) |
| `A` | player 1's HQ |
| `B` | player 2's HQ |

```map
. . . . . . . . . . . . . . . . . . . . . . . .
. . . . . . . . r r . . . . r r . . . . . . . .
. . . . . . . # # r . . . . r # # . . . . . . .
. . . . . c . # # . . . . . . # # . c . . . . .
. . . . . . . . . . c . . c . . . . . . . . . .
. . . . . . . . . . . . . . . . . . . . . . . .
. . . . . . . r . . . . . . . . r . . . . . . .
. . . . . . . r . . . . . . . . r . . . . . . .
. . A . . . . . . . . . . . . . . . . . . B . .
. . . . . . . r . . . . . . . . r . . . . . . .
. . . . . . . r . . . . . . . . r . . . . . . .
. . . . . . . . . . . . . . . . . . . . . . . .
. . . . . . . . . . c . . c . . . . . . . . . .
. . . . . c . # # . . . . . . # # . c . . . . .
. . . . . . . # # r . . . . r # # . . . . . . .
. . . . . . . . r r . . . . r r . . . . . . . .
```

## Design notes

★ Placeholder name. 24×16, the largest the engine allows (3.2× the vertical slice's area) — big enough that walking is slow and
transports matter. Mirror-symmetric; nothing within 3 tiles of an HQ; the HQ-to-HQ row (row 9) is open. The ridges (`#`) force
armies through passes at the top and bottom; the rough columns either side of the centre funnel vehicles into the middle.
