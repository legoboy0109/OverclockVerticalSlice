# Change-Impact Report — Isometric Projection Adoption

**Date:** 2026-07-23
**Change origin:** `design/art/art-bible.md` (Map Projection Decision) — OVERCLOCK's tactical view is **isometric 2D (2:1 dimetric, FFT lineage)**, revising the concept doc + GDD corpus's "top-down" framing.
**Analysis method:** Parallel per-GDD review of the 5 projection-affected GDDs, classifying every projection-dependent statement as RULE-CHANGE / WORDING-ONLY / ARCH-NOTE.
**Note:** No ADRs exist yet (Technical Setup just started), so this report targets the GDD corpus + the forthcoming architecture rather than ADR staleness. This is the inverse of `/propagate-design-change`'s usual direction (an art-bible decision propagating *into* the GDDs).

---

## Verdict: LOW–MEDIUM impact — ZERO gameplay rule changes

The isometric shift is **purely a view-layer change**. No gameplay rule, formula, or acceptance criterion in any GDD changes. This is because the corpus was authored on a **render-decoupled, headless-simulatable state model** (a TD seed from day one): grid coordinates, occupancy, Manhattan distance, 4-directional adjacency, deterministic combat, and AP costs all live in logical grid space, with projection applied *after*, in the view. **No GDD requires re-approval.**

| GDD | Impact | RULE-CHANGE | Summary |
|-----|--------|-------------|---------|
| `grid-terrain.md` | MEDIUM | 0 | Grid math projection-invariant; elevation/high-ground explicitly deferred to Alpha (VS = plain+cover+impassable, flat) |
| `movement-system.md` | LOW | 0 | No "top-down" string; unit-facing surfaced as presentational only (no ZoC/flanking) |
| `combat-resolution.md` | LOW | 0 | Facing-agnostic, omni-directional cover (defender-tile), discrete-tile range, no LoS-by-height |
| `command-action-interface.md` | MEDIUM | 0 | Most view-dense; entire select→preview→confirm FSM + formulas projection-invariant |
| `game-hud.md` | LOW | 0 | Screen-space HUD invariant; only the CR-5 on-board glyph layer reprojects (already flagged in its OQ-8) |

---

## Architecture Concerns Introduced (7) — inputs for `/create-architecture`

None block architecture; all are new view-layer requirements the master architecture + board/render ADRs must absorb.

1. **Grid-coordinate → iso-screen transform (2:1 dimetric).** The render-decoupled view seam the GDDs already anticipated (grid-terrain Overview: "the on-screen `TileMapLayer` is only a view"). A plain top-down `TileMapLayer` will not render 2:1 iso for free — the view layer becomes non-trivial. Godot/Redot TileMap supports isometric tile shape, but 2:1 dimetric with correct depth-sort + picking typically needs custom handling.
2. **Inverse mouse→tile hit-testing (screen px → grid tile).** Top-down's trivial integer divide becomes an inverse dimetric projection (+ stacking resolution). Makes the existing "tile-change-gate the mouse-motion handler" perf note (command-interface CR-10) more important, and projection-specific.
3. **Depth-sort / Y-sort.** Units behind Impassable "walls" (and any raised feature) must draw correctly; overlays and per-tile badges on partly-occluded tiles must not be hidden. Art bible §8.8 already specifies the YSort + ground-contact-pivot approach.
4. **Iso-conformant overlay rendering.** Reachable/target/cover overlays, AREA manhattan-diamond rings, hatch angles (over-cap 45° vs. build cross-hatch must stay distinct on a 2:1 diamond), fills, and in-cap/over-cap boundary seams must be re-derived for diamond tiles rather than axis-aligned squares.
5. **On-board glyph/badge anchoring under iso.** hp pips, has-acted/tech markers, AP-cost badges, damage numbers, and the board-cursor indicator need defined iso anchors (tile vertex / above-sprite) and occlusion avoidance. game-hud OQ-8 + Visual/Audio-D already name this world→screen seam; annotate with "iso."
6. **Unit facing during iso movement.** Purely presentational — the VS has no facing/ZoC/flanking/overwatch mechanic, so facing has zero mechanical effect. Art/animation concern; art bible §8.4 already specs 4 iso facings (n/s/e/w) + mirror-flip.
7. **Board-cursor directional-navigation mapping.** Arrow/D-pad cursor stepping must decide grid-axes vs. screen-axes movement (screen "up" ≠ grid +1 row under iso). A `/ux-design` decision; the one-tile-per-press *rule* is invariant.

---

## Wording Debt (cosmetic, non-blocking)

- `grid-terrain.md` — only doc with projection-flavored text: "a fixed-size rectangular board of **square tiles**" and "rectangular grid of GRID_WIDTH × GRID_HEIGHT square tiles." Clarify "square in grid space, rendered as 2:1 diamonds." Also clarify "cardinal"/4-directional = grid-axis, not screen-cardinal (the 4 grid axes render along screen diagonals under iso). **[Applied 2026-07-23: projection note added.]**
- The other 4 GDDs contain **zero** "top-down" strings — no rewording debt.

---

## Future-System Capture (not VS scope)

A **vehicle/mech unit tier** (added via a new production structure + a piloting mechanic) is planned for Alpha/Full-Vision. The art bible already forward-specs its visual rules (§5.0/§5.5: larger silhouettes, same Mass Distribution Bias faction families, scaled-up neon budget). Captured in `systems-index.md` as a deferred future system. **Do not expand VS scope.**

---

## Resolution

- **No GDD re-approval required** — zero rule changes.
- Light-touch wording note applied to `grid-terrain.md` (canonical board doc); other 4 GDDs left untouched.
- Vehicle/mech tier recorded in `systems-index.md` (Alpha/Full-Vision, deferred).
- The 7 architecture concerns above are carried as first-class inputs to `/create-architecture` — specifically the board/render/input ADR cluster.
