# ADR-0020: HD-2D Lighting — Baked Glow Halo, Floor Light Pools, Edge Blur, Sharp Pixel Sampling

## Status
Accepted (2026-09-30)

## Context
On 2026-09-29 the user moved the art direction to **HD-2D**: pixel-art sprites plus modern
lighting (art bible, top amendment), scoped as "sprites + lighting" with terrain unchanged. The
sprites shipped first. This ADR covers the lighting and the pixel-sampling that makes the sprites
hold up under the camera's continuous zoom (fit zoom → `CAMERA_ZOOM_MAX`).

Constraints: the HUD must stay perfectly legible; the stage stays dark (§1 P3); a unit's hue is its
ownership signal and must never be tinted by another player's light (§4.2); the Steam Deck is the
hardware floor (technical-preferences.md).

## Decision
- **D1 — Sharp pixel sampling on actor bodies** (`pixel_sharp.gdshader`, one shared material from
  `EntitySpriteFeed`). Sharp-bilinear: hard texel edges with a one-screen-pixel blend. Chosen over
  NEAREST (uneven pixel widths shimmer at non-integer zoom) and over snapping zoom to 0.5 steps
  (would change framing and fight the legibility zoom). The glow overlay keeps its soft material.
- **D2 — Bloom as a halo BAKED into each glow mask** (`EntityGlow.halo_texture`): at load, the mask
  is padded by `HALO_PAD_PX` and a blurred copy is added round the rim; the glow sprite is drawn at
  the body offset minus the padding, so the rim still registers with the armour. It rides the
  existing glow shader, so it breathes, dims when AP is spent and spikes with the attack flare.
  **Engine bloom was built and rejected on evidence.** Without `rendering/viewport/hdr_2d` no glow
  threshold separates the neon (rush trim ≈0.54 luminance) from the slate armour (≈0.48). With HDR
  on, bloom worked — but HDR 2D blends translucency in linear space, and in the real game the
  move-range overlay's tan went near-solid (22% of that frame's pixels shifted), silently undoing
  its legibility tuning. HDR 2D therefore stays off (a test asserts it).
- **D3 — Floor light pools** (`EntityLightPools`): one `PointLight2D` per actor in its owner's hue,
  `range_item_cull_mask` = bit 2, which only the floor `TileMapLayer` and cover props carry. Actors
  keep the default mask, so no light ever tints a unit. Sized in screen pixels (compensates the
  per-sprite scale), fades with the death echo. Energy 0.8 (tuned in SDR; the HDR-era 2.5 washed
  the floor blue once HDR was dropped).
- **D4 — Edge blur** (`edge_blur.gdshader`) on its own `CanvasLayer` (1) between the board (0) and the
  HUD, which moved to layer 2. The blur ramps only inside the HUD's reserved top/bottom bands, so at
  the fit zoom it covers empty void; it reads only once the player zooms and the board passes under
  the HUD.
- **D5 — Verification in real renders.** Headless runs do not rasterise (and do not compile shaders),
  so every visual claim is checked with `tools/CaptureRoster.tscn` / `CaptureSlice.tscn` under
  `gamescope --backend headless`, which renders on the real GPU with no desktop session.

## Consequences
- GPU cost measured on the RX 6900 XT with 24 actors: **0.18 ms/frame lit vs 0.10 ms flat** (after the
  HDR removal). Scaled to the Deck's GPU (~14× weaker) ≈ 2.5 ms, well inside the 16.6 ms budget.
  **Unverified on a Deck.**
- Any future screen-space overlay must use `Hd2dLighting.HUD_CANVAS_LAYER` or it will be blurred
  (a test enumerates the slice's CanvasLayers).
- Any future shader on a canvas item: fragment `COLOR` already includes the texture — multiply a
  resample by a vertex-captured modulate, not by `COLOR` (the first `pixel_sharp` build squared the
  texture and turned rush orange deep red).
- `Hd2dLighting.set_enabled(false)` turns the edge blur off (a hook for a future graphics setting; no
  player-facing option is exposed yet — that is a product decision). Halo and pools are not toggled.
- The halo costs a one-off CPU bake per glow mask the first time that type appears (cached after).

## Alternatives Rejected
- Engine bloom under HDR 2D: works, but re-blends every translucent overlay in linear space (see D2).
- A separate halo sprite per actor: would need every glow uniform mirrored onto a second node.
- Snapping zoom to integer pixel scales: changes framing at every window size.
- Lighting sprites as well as floor: neighbours' hues would contaminate ownership colour.

## ADR Dependencies
- ADR-0013 (board renderer / entity sprites, Y-sort bands) — the pools are children of the body
  sprites; the halo reuses the glow overlay; nothing changes the z/Y-sort contract.
- ADR-0016 (game HUD) — the HUD's CanvasLayer moves to `Hd2dLighting.HUD_CANVAS_LAYER` (2).

## Engine Compatibility
Redot 26.2 (Godot 4.6-compatible), Forward+ on Vulkan. Uses `PointLight2D` with
`range_item_cull_mask`, canvas-item shaders (`hint_screen_texture`, `textureGrad`, `fwidth`), and
`Image`/`ImageTexture` at runtime. Verified rendering on RADV (RX 6900 XT). No HDR 2D, no
`WorldEnvironment`. Steam Deck (RDNA 2, same Vulkan driver family) expected compatible — unverified.

## GDD Requirements Addressed
- Art bible top amendment (HD-2D pivot, 2026-09-29): "pixel-art sprites plus modern lighting".
- Art bible §1 P3 (dark stage), §2 (steady glow at rest, attack flare), §4.2 (ownership hue),
  §8.9 (glow driven by `state_timer`, freezes with pause) — the halo inherits all of these.
- technical-preferences.md: Steam Deck floor, 16.6 ms frame budget.
