# Story 002: `HUDConfig` Resource + Cross-Config Loader Guard

> **Epic**: Game HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (2h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-008` (config-loader half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §4); ADR-0014 (secondary — the forward-declared invariant this closes); ADR-0006 (secondary — `gameplay_config_storage` loader pattern)
**ADR Decision Summary**: `HUDConfig` is a per-system config Resource with 9 knobs, loaded once by the thin Balance-style loader Autoload; that loader (not either Resource's `_init()`) enforces `InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms` with a release-surviving guard (`push_error` + clamp), never a bare `assert()`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure Resource + Autoload loader logic; stable `Resource.@export`/`push_error`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `HUDConfig` must be a new per-system config Resource with knobs: `pip_max_hp`, `action_log_length`, `ap_fill_flourish_ms`, `ap_tick_duration_ms`, `turn_banner_duration_ms`, `hud_audio_duck_ms`, `show_opponent_ap`, `show_opponent_fill_flourish`, `income_breakdown_default_expanded` — source: ADR-0016
- Required: The config loader (Autoload, not either Resource's `_init()`) must enforce `InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms` using a release-surviving guard — source: ADR-0014, ADR-0016
- Forbidden: Never self-validate the cross-config invariant inside `HUDConfig._init()` — source: ADR-0016

---

## Acceptance Criteria

*From ADR-0016 §4 + TR-hud-008, scoped to this story:*

- [ ] `HUDConfig` Resource exists with all 9 `@export` knobs: `pip_max_hp` (10), `action_log_length` (20), `ap_fill_flourish_ms` (400), `ap_tick_duration_ms` (120), `turn_banner_duration_ms` (1000), `hud_audio_duck_ms` (150), `show_opponent_ap` (true), `show_opponent_fill_flourish` (false), `income_breakdown_default_expanded` (false)
- [ ] GIVEN `HUDConfig.ap_tick_duration_ms > InputConfig.input_lock_ms` at load, THEN the loader Autoload emits a `push_error` (visible in debug/editor) AND clamps the effective `ap_tick_duration_ms` down to `input_lock_ms` in a release build — never a bare `assert()`
- [ ] GIVEN the default values (120 ≤ 120, satisfied), THEN no error/clamp fires and both configs load unmodified
- [ ] The invariant check lives in the shared loader Autoload (`gameplay_config_storage` pattern), never inside either Resource's own `_init()`

---

## Implementation Notes

*Derived from ADR-0016 §4:*

- `hud_config.gd` — `class_name HUDConfig extends Resource`, the 9 `@export` fields exactly as listed. Loaded once by the same thin Balance-style loader Autoload as `EconomyConfig`/`InputConfig` (`gameplay_config_storage`, ADR-0006).
- The loader Autoload — after loading both `InputConfig` and `HUDConfig` — checks `InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms`. Because a bare `assert()` is stripped in release exports (ADR-0011 precedent), use a release-surviving guard: `push_error(...)` + clamp the effective `ap_tick_duration_ms` down to `input_lock_ms`, mirroring `AIConfig`'s `LETHAL_FLOOR_BONUS` enforcement pattern.
- This discharges the obligation CAI's ADR-0014 named and that CAI Story 007 explicitly deferred to this epic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `InputConfig` itself (already exists, CAI epic)
- Any widget's actual use of these knobs beyond the guard — each widget story reads its own knob

---

## QA Test Cases

- **AC (violation)**: Given `HUDConfig.ap_tick_duration_ms = 200` and `InputConfig.input_lock_ms = 120`, When the loader runs its post-load check, Then a `push_error` fires AND the effective `ap_tick_duration_ms` is clamped to 120.
- **AC (defaults)**: Given the shipped defaults (120/120), When the loader runs, Then no error/clamp fires and `HUDConfig.ap_tick_duration_ms == 120` unmodified.
- **AC (debug visibility)**: Given a debug build with the violation, Then the `push_error` is visible in the editor console (not silently swallowed like a stripped `assert`).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/game-hud/hud_config_guard_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `InputConfig` existing (CAI epic — shipped; CAI Story 007 explicitly left this guard to the HUD epic). Can run in parallel with Story 001 (no shared files).
- Unlocks: Story 003 (reads `ap_tick_duration_ms`) and every story that reads a `HUDConfig` knob (004, 005, 006, 007, 008)
