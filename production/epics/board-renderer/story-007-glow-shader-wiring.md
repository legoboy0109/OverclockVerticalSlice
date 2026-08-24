# Story 007: Glow Shader Wiring — §8.9 Emission Mask & Per-Instance Uniforms

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel *(secondary: Integration — the state→uniform mapping is automatable)*
> **Estimate**: M (1 day)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-19 (implemented)

## Context

**GDD**: `design/art/art-bible.md` §2 (mood/glow vocabulary), §8.9 (shader & import)
**Requirement**: sprint story **S5-02**; delivers the Pillar-1 AP-available vs AP-spent read
**ADR Governing Implementation**: art bible §8.9 — approach **CONFIRMED** by the S4-01 de-risk spike
**ADR Decision Summary**: one CanvasItem `.gdshader` on the unit sprite, sampling base colour
normally and additively blending `emission_mask × faction_hue × pulse_intensity`, with `faction_hue`
and `pulse_intensity` as **per-instance uniforms** (`set_instance_shader_parameter`) so every actor
shares one material and stays batch-safe (§8.7 rule 2).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW — the 2D per-instance-uniform pattern
was already confirmed on this engine by a headless smoke in the S4-01 spike
(`prototypes/s4-01-art-spike/`).

**8 glow masks already ship** in `assets/art/` and are currently unused. They are greyscale
"which pixels are trim", **hue-agnostic** — one mask serves all three factions, which is why they
carry no faction token in the filename.

## Acceptance Criteria

1. One shared `ShaderMaterial` across all actors; `faction_hue` and `pulse_intensity` set
   **per instance** via `set_instance_shader_parameter` — two sprites sharing the material hold
   divergent values.
2. Mask resolves without a faction token: `unit_[archetype]_[facing]_idle_01_glow.png`,
   `struct_[name]_idle_glow.png`.
3. `faction_hue` matches the locked anchors — Rush `#FF5A2E`, Boom `#22C7F0`, Neutral `#C6CED8`.
4. State → `pulse_intensity`: **AP-available breathes 0.25→0.85** (slow sine) · **AP-spent clamps
   to 0.08** · **attack flare peaks 1.0 and decays** · **destroyed → 0**.
5. **`state_timer` is passed from GDScript; the shader must NOT use the `TIME` built-in** — glow has
   to freeze and scrub with the turn-based pause state.
6. Glow is driven **event-driven on state change**, not polled per frame.
7. Windowed render confirms the emission reads as **neon trim, not a blown-out panel**, at board
   scale — this also clears the S4-01 residual (the headless dummy rasteriser cannot render).

## Implementation Notes

- The mask is the accent's **rim**, not the whole colour block. Accent blocks cover 40–62% of a
  unit; emitting all of it blows the panels out and destroys their shape read, which is why
  `glow_mask.py` ships the eroded rim (18–25% of a unit). Do not "fix" this by widening the mask.
- Idle-AP and idle-spent share **the same sprite and the same mask** — §8.5 is explicit that
  AP-spent is "the same base pose frames, glow-clamp state only". No second pose exists or is owed.
- §2 requires **steady** glow at rest; a pulsing contested-state glow would read as false urgency.
  Breathe is slow; flare is the only spike.

## Out of Scope

- Move / attack / hit body transforms (→ **S5-06**). This story owns the *lighting*, including the
  attack flare; S5-06 owns the motion it syncs to.
- A `WorldEnvironment` 2D bloom halo. If ever wanted, the Godot 4.6 glow rework **does** govern it
  and it must be spiked separately (§8.9 warning).

## QA Test Cases

**Test file**: `tests/unit/board-renderer/glow_uniform_state_test.gd`

- two `Sprite2D` sharing one `ShaderMaterial` hold divergent per-instance `faction_hue` /
  `pulse_intensity`
- state→`pulse_intensity` mapping: AP-available within 0.25–0.85 · AP-spent == 0.08 ·
  attack flare peaks 1.0 then decays · destroyed == 0
- `faction_hue` equals the locked anchor per faction
- glow mask path resolves **without** a faction token
- shader is driven by the injected `state_timer`, not `TIME`

**Edge cases**: 0 AP → clamp not breathe · entity destroyed mid-breathe → drives to 0 · pause
active → `state_timer` does not advance between frames

*Not automatable: whether the additive emission **reads** on screen. That is AC-7, verified
windowed under S5-07.*

## Test Evidence

**Automated** — `tests/unit/board-renderer/glow_uniform_state_test.gd`, 20 tests, all passing.
Full suite **909/909, 0 failures, 0 orphans**.

**Windowed, in the live rasteriser** (this also clears the S4-01 residual the art bible listed as
owed — the headless dummy rasteriser cannot render):

| Check | Result |
|---|---|
| Shader compiles in the real rasteriser | ✅ clean boot, zero shader errors |
| Emission reads as neon trim, not a blown-out panel (AC-7) | ✅ rims luminous, panel shapes intact |
| Breathe actually animates | ✅ measured cycle over ~3.0s, matching `BREATHE_PERIOD_SEC` |
| Per-instance `faction_hue` renders (AC-1) | ✅ see below |

**Proof that per-instance uniforms render, not just store.** The base art is already
faction-coloured, so "the glow looks orange" proves nothing on its own — if instance uniforms were
silently ignored the shader would add its **white** default and *desaturate* the trim. Measured
against the pre-glow frame:
- Rush trim mean saturation **rose** 0.252 → 0.261 — orange is being added, not white.
- Boom trim gained green and blue with red **exactly unchanged** (0.144603 → 0.144603) — i.e. cyan.

Two actors sharing one material therefore render different hues, which is AC-1's whole point.

**Measured Pillar-1 delta, for S5-03 to judge** (crop-mean luminance above the pre-glow baseline):
breathe peak ≈ **+0.0027**, breathe trough ≈ **+0.0008**, AP-spent clamp ≈ **+0.00025**. The clamp
is roughly 3× dimmer than even the breathe trough. Whether that reads *across the board at playing
distance* is a human call, not a measurable one — that is exactly S5-03's job.

## Dependencies

- **Blocked by**: S5-01 (sprites must exist on the board first)
- **Blocks**: S5-03 (legibility gate judges the board with glow live), S5-06

## Completion Notes

**All 7 acceptance criteria met.**

### Shipped
- `src/ui/board_renderer/glow.gdshader` — additive canvas_item shader. Shape only; every number
  arrives as a uniform.
- `src/ui/board_renderer/entity_glow.gd` — the single source of truth for the curve, the locked hue
  anchors, and mask-path resolution. `pulse_for()` mirrors the shader arithmetic so the envelope is
  assertable headlessly.
- `entity_sprite_feed.gd` — one glow overlay child per actor, sharing one `ShaderMaterial`.
- `vertical_slice_root.gd` — advances the glow clock; wires the AP predicate.

### Design decision: the glow overlay is a child sprite, not a second texture
Godot instance uniforms are scalars and vectors, **never samplers**, so a shared `ShaderMaterial`
cannot carry a per-actor mask. Making the mask the overlay's own `TEXTURE` keeps exactly one
material for the whole board — the batch-safe §8.7-rule-2 requirement — and uses only the shader
surface the S4-01 spike already confirmed. Cost is one extra node per actor, which is nothing at
this scale. A single-node `CanvasTexture` variant (mask in the specular slot) would work but adds
unverified engine surface for no practical gain.

### Bug found and fixed during windowed verification
The first implementation put the emission in **both** rgb and alpha. Godot's additive canvas blend
is `dst + src.rgb * src.a`, so that **squared** the emission and the glow all but vanished —
measured at **54 changed pixels across the entire frame**. Alpha is now pinned to 1.0 with the mask
zeroing rgb outside the trim, and the shader carries a comment saying so, because it looks like a
harmless line to "tidy".

This is worth noting as process: the headless suite passed the whole time. Instance uniforms
*store* correctly headlessly whether or not they *render*, which is precisely the false-positive the
art bible's "engine-verify before this becomes load-bearing" warning existed to catch.

### Attack flare is derived from state, not from an event
No event carries an attacker id — ADR-0004's schema has no attack event at all, and adding one is a
core-layer change well outside this story. The feed watches `has_attacked` flip false→true, which
catches **the AI's attacks as well as the player's**; a hook at the slice's own call site would only
have caught the player's. The start-of-turn reset flips it the other way and correctly does not
flare.

### ★ Open design question for S5-03
Breathe-vs-clamp is currently driven by the **owning player's AP pool** — art bible §8.5/§2.6 read
literally ("AP available" / "0 AP"), which dims a player's whole army at once. The alternative is
**per-unit actionability**: a unit that has already moved and attacked clamps while its idle
squadmates keep breathing. That carries strictly more tactical information and is a one-line change
(`EntitySpriteFeed.actionable_predicate`). Left spec-literal rather than silently improved on;
S5-03 should decide.

### Not owed here
`BREATHE_PERIOD_SEC` (3.0) and `FLARE_DECAY_SEC` (0.45) are unpinned feel values. The flare in
particular should be tuned **together with S5-06's attack lunge**, since the light is meant to sync
to the motion.
