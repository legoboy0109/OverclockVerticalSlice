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

## `marker-policy-all-vs-structures-only.png`

The comparison the policy decision was made from. **Top: `ALL`** (the original default).
**Bottom: `STRUCTURES_ONLY`** (the shipped default, chosen 2026-08-21).

Six entities on a small patch is enough to show it. Under `ALL` the decals under the units sit
directly beneath the units' own feet and compete with them — art-bible §3.5 forbids exactly that,
and the units were never the problem: they carry ownership at 26–82% accent coverage and ΔE 60–76
under deuteranopia on their own. Under `STRUCTURES_ONLY` the board reads cleanly and the two
structures — the entities the measurement actually found weak — still declare their owner
unambiguously.

**Accepted consequence:** under this policy a unit-only read is hue-carried and does not survive
full desaturation. The non-hue channel exists on the board, but not under every actor on it.
`ALL` restores it board-wide if a monochromacy claim is ever made in earnest.

## What this does NOT establish

Whether the decals read **at playing distance** in the live rasteriser. That is a human call owed
to **S5-03** (legibility) and **S5-07** (windowed sign-off). The clutter question these sheets were
made to answer has been settled — see the policy comparison above.

Note also that these are composited previews: the marker geometry is exported from the live
`OwnershipMarker` code, but the board around it is assembled in the render script, not screenshotted
from the running game. A windowed capture is still owed under S5-07.
