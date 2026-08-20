# Story 007: Glow Shader Wiring — §8.9 Emission Mask & Per-Instance Uniforms

> **Epic**: Board Renderer
> **Status**: Not Started
> **Layer**: Presentation
> **Type**: Visual/Feel *(secondary: Integration — the state→uniform mapping is automatable)*
> **Estimate**: M (1 day)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-19

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

*(to be filled by /story-done — unit test result + windowed screenshot)*

## Dependencies

- **Blocked by**: S5-01 (sprites must exist on the board first)
- **Blocks**: S5-03 (legibility gate judges the board with glow live), S5-06

## Completion Notes

*(to be filled on completion)*
