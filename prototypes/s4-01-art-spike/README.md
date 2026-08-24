# S4-01 — Art De-Risk Spike (glow shader + Boom-cyan hue)

Throwaway spike for **Sprint 4 / S4-01**. Resolves the two non-blocking watch-items the
Art Director left open when signing off the art bible (`design/art/art-bible.md`, AD-ART-BIBLE):

1. **§4.2 hue-neighborhood** — Boom's cyan sits in the same cool-blue neighborhood as the
   Dark Stage family; does it still pop on the board, worst case on the lightest terrain?
2. **§8.9 glow shader** — does the 2D CanvasItem per-instance-uniform emission approach work
   in Redot 26.2 / Godot 4.6, given the 4.6 glow-pipeline rework?

## Hypotheses tested

- **H1 (hue):** Boom `#22C7F0` stays legible against every §4.1 stage tile (esp. max-elevation
  `#33405A`) via saturation + lightness distance, without changing the hue.
- **H2 (shader):** All units can share ONE `ShaderMaterial` yet glow different faction hues/pulse
  via per-instance uniforms in a 2D `canvas_item` shader (batch-safe, §8.7 rule 2), and the 4.6
  glow rework (WorldEnvironment/Compositor 3D post-process) does not affect this hand-authored path.

## How to run

**Hue analysis (no engine needed):**
```
python3 hue_analysis.py        # prints HSL / WCAG contrast / grayscale Δ / ΔE2000 per pair
```
Open `swatch.html` in a browser for the visual 3×5 side-by-side (Boom/Rush/Neutral × 5 stage tiles).

**Glow shader (windowed editor — the §8.9 residual sign-off):**
```
./redot prototypes/s4-01-art-spike/project.godot      # then press F5
```
15 tokens (Boom/Rush/Neutral over each stage tile) share one `ShaderMaterial`. **SPACE** cycles
the glow behavior: BREATHE (§2.1 has-AP) → FLARE (§2.2 spend) → CLAMP (§2.6 0-AP). Confirm:
the shader compiles (no error on run), the additive glow blooms on the dark stage, tokens glow
different hues off one material, and Boom stays readable on every tile.

## Status: CONCLUDED — 2026-07-29

## Findings

### H1 (hue) — CONFIRMED. Verdict: LOCK the hexes.
Boom `#22C7F0` clears every legibility bar against all five stage tiles. Worst case
(max-elevation `#33405A`, the lightest tile): **ΔE2000 51.8** (further than Rush's 49.4 vs the
same tile), **WCAG 5.19:1** (passes AA), **grayscale Δ 104/255** (passes the §4.4 desaturation
test). Boom is only **28°** from the stage hue (vs Rush's 150°) but sits **60% S / 26% L** away —
the saturation-plus-lightness mitigation is validated; no hue adjustment needed.
*Doc nit:* §4.2's "stage tops out at L 22%" describes terrain base (`#232A38`, L 17.8%); the
max-elevation tile reaches L 27.6% — Boom was tested at that true brighter ceiling and passes.

### H2 (shader) — CONFIRMED. Verdict: 2D CanvasItem per-instance-uniform approach safe to commit.
- The Redot 26.2 engine reference confirms the 4.6 glow rework is the **WorldEnvironment/Compositor
  3D post-process** (glow-before-tonemapping, screen-blend) — orthogonal to the 2D emission shader.
- Headless smoke (Redot 26.2): two `Sprite2D` CanvasItems sharing one `ShaderMaterial` hold
  divergent per-instance `faction_hue` / `pulse_intensity` — batch-safe pattern works in 2D.
- **Residual (windowed, advisory → S4-07):** run `GlowSpike.tscn` to confirm the `instance uniform`
  declaration compiles in the live rasterizer + the emission renders (the dummy headless rasterizer
  can't render GPU shaders). And a *WorldEnvironment 2D bloom halo*, if ever layered on top, IS
  governed by the 4.6 rework and must be spiked separately.

Both verdicts are recorded in `design/art/art-bible.md` (intro watch-items #3/#4, §4.2, §8.9).
This spike is reference-only — production glow/color work is rewritten to standard, not migrated.
