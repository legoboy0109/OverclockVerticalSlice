# S5-08 / Story 009 — Ownership Marker Render Evidence

Rendered 2026-08-20 at commit `4dbfef1`. The marker textures were exported from the **live
`OwnershipMarker` code** (not reimplemented for the preview) and composited over the real shipped
floor and entity art, so what these show is the actual geometry the renderer draws.

## `marker-shapes-normal-deuteranopia-grayscale.png`

Columns: **Rush / Boom / Neutral**, all on the Defensive Structure — the entity the S5-08
measurement found weakest (ΔE 2.3 between factions across its whole silhouette, with entirely
normal colour vision).

Rows: **normal vision / deuteranopia / full grayscale.**

The bottom row is the acceptance evidence for AC-1. With every colour channel discarded the three
factions still read apart — solid chevron, split flanks with a gap, unbroken ring. That is the
non-hue ownership channel art bible §1 P2 has required since the bible was written and that the
project did not have until this story.

## `marker-alignment-on-real-board-art.png`

A patch of real `tile_plain_clean.png` floor tiles with a structure and two units standing on their
decals. Confirms two things that would be defects if wrong:

- **Alignment is exact** — the decals sit on the renderer's own tile diamonds, because the marker
  geometry reuses `BoardRenderer`'s point-in-diamond metric rather than deriving a second diamond.
- **Adjacent decals do not touch** (`BAND_OUTER` 0.92). A continuous line running across several
  owned tiles would read as terrain rather than as ownership.

## What this does NOT establish

Whether the decals read **at playing distance**, and whether a full board of them is too busy for
§3.5's hierarchy. Both are human calls and both are owed to **S5-03** (legibility) and **S5-07**
(windowed sign-off). `EntitySpriteFeed.marker_policy` is the knob if the answer is "too busy" —
`STRUCTURES_ONLY` keeps the decal exactly where the measurement said it was needed.
