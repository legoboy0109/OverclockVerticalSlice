## HUDConfig — Game HUD's designer-tunable presentation-timing/behavior knobs.
##
## Presentation-layer config [Resource] per ADR-0016 §4 (the
## `gameplay_config_storage` pattern, ADR-0006), mirroring the project's
## established per-system config Resource idiom ([code]EconomyConfig[/code]/
## [code]InputConfig[/code]/[code]AIConfig[/code], etc.). Loaded once by the
## [code]HudBalance[/code] Autoload; every Game HUD widget story reads its own
## knob from [code]HudBalance.hud.*[/code].
##
## [b]No cross-config logic here[/b] — the
## [code]ap_tick_duration_ms <= InputConfig.input_lock_ms[/code] invariant
## (TR-hud-008) is deliberately NOT self-validated in [method _init]
## (control-manifest forbidden rule): this Resource cannot see [InputConfig] (a
## separate Resource) at its own construction time, so the cross-resource check
## lives in the loader Autoload that holds both (ADR-0016 §4).
class_name HUDConfig
extends Resource

## Hp-pip branch threshold (TR-hud-012): entities with max_hp below this render
## discrete drain-on-damage pips; at/above this render numeric current/max
## instead (the `>=` boundary is load-bearing).
@export var pip_max_hp: int = 10

## Action log ring-buffer capacity (TR-hud-014): the oldest entry drops once the
## log would exceed this many entries.
@export var action_log_length: int = 20

## Duration (ms) of the start-of-turn AP-fill flourish animation (TR-hud-005,
## `ApCounterFsm.State.FILL_FLOURISH`).
@export var ap_fill_flourish_ms: int = 400

## Duration (ms) of a single AP tick-down step (TR-hud-005/008,
## `ApCounterFsm.State.TICK_DOWN`). Must never exceed
## `InputConfig.input_lock_ms` — enforced by `HudBalance`'s load-time guard,
## not here (see class doc comment).
@export var ap_tick_duration_ms: int = 120

## Duration (ms) the self-clearing YOUR/ENEMY turn banner stays visible before
## it clears itself (TR-hud-009).
@export var turn_banner_duration_ms: int = 1000

## Duration (ms) a lower-priority HUD audio cue is ducked under a higher-priority
## one in the total-priority collision order (TR-hud-021).
@export var hud_audio_duck_ms: int = 150

## Whether the opponent's budget counters render at all (TR-hud-005, CR-3b). Since
## the 2026-08-05 economy pivot this gates BOTH the opponent's AP counter and their
## Credits counter as a pair (the knob keeps its name per the GDD Tuning table).
## Mechanics-adjacent, not purely cosmetic (ADR-0016 Risks) — flipping this changes
## information available for play (opponent AP threat ranges AND their banked Credit
## war chest); a balance owner should sign off changes, not just UX.
@export var show_opponent_ap: bool = true

## Whether the opponent's AP counter plays the start-of-turn fill-flourish
## (TR-hud-005). Independent of `show_opponent_ap` — the opponent counter can be
## shown but muted to `COMMITTED`/`TICK_DOWN` only.
@export var show_opponent_fill_flourish: bool = false

## Whether the AP income breakdown panel starts expanded (true) or collapsed
## (false) each time it becomes visible (TR-hud-019 / CR-3).
@export var income_breakdown_default_expanded: bool = false
