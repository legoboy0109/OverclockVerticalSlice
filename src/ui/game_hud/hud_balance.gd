## HudBalance — Autoload, logic-free lookup for Game HUD's tuning config.
##
## Presentation-layer Autoload per ADR-0016 §4, a sibling of [code]Balance[/code]/
## [code]UnitBalance[/code]/[code]CombatBalance[/code]/[code]StructureBalance[/code]/
## [code]AIBalance[/code], mirroring their thin "read-only lookup convenience"
## idiom. Loads [HUDConfig] once at boot and exposes it by reference via
## [code]HudBalance.hud[/code].
##
## [b]The one exception to "never validates, never interprets":[/b] TR-hud-008 /
## ADR-0016 §4 requires the cross-config invariant
## [code]HUDConfig.ap_tick_duration_ms <= InputConfig.input_lock_ms[/code] be
## enforced at load time with a release-surviving guard, not a bare
## [code]assert()[/code] (stripped from release exports — the same shared
## `*Config` caveat ADR-0011 established for [code]AIBalance[/code]). This
## Autoload is the load-time seam ADR-0016 §4 names for that enforcement, so
## unlike most siblings it owns exactly one piece of logic:
## [method enforce_ap_tick_within_input_lock].
##
## [b]Deviation from the AIBalance precedent[/b] — [code]AIBalance[/code]'s
## invariant guard fails hard (push_error + [method OS.crash]). ADR-0016 §4
## explicitly mandates a softer outcome for THIS invariant: push_error + CLAMP,
## never a crash — "a hard OS.crash in release was considered worse than
## clamping — a shipped hard-crash on a tuning typo" (ADR-0016 Risks). The two
## invariants are enforced differently on purpose; do not unify them.
##
## Registered in `project.godot`'s `[autoload]` section, after
## [code]AIBalance[/code]. There is no `input_config.tres` today — [InputConfig]
## is only ever constructed via `.new()` (injected into [CommandInterface], see
## `command_interface.gd`), so [method _ready] checks against a fresh
## [code]InputConfig.new()[/code] (its shipped class default,
## `input_lock_ms = 120`). If an `input_config.tres` is introduced later,
## preload it here instead.
extends Node

## The loaded [HUDConfig] tuning-constants resource. Read via
## [code]HudBalance.hud.*[/code].
var hud: HUDConfig = preload("res://data/ui/hud_config.tres")


func _ready() -> void:
	enforce_ap_tick_within_input_lock(hud, InputConfig.new())


## Release-surviving cross-config guard (TR-hud-008, ADR-0016 §4): the AP-tick
## animation must finish inside the input-lock window, or the commit-flash /
## AP-tick sequencing ADR-0015 depends on breaks. push_error + CLAMP — never
## [method OS.crash] (a shipped hard-crash on a tuning typo is worse than a
## silently-corrected feel bug) and never a bare [code]assert()[/code] (stripped
## from release exports, ADR-0011 precedent). Takes both configs as explicit
## parameters (not read from Autoload globals) so the check is a pure,
## unit-testable function with no scene-tree dependency, mirroring
## [code]AIBalance[/code]'s pure-helper split.
static func enforce_ap_tick_within_input_lock(hud_cfg: HUDConfig, input_cfg: InputConfig) -> void:
	if hud_cfg.ap_tick_duration_ms > input_cfg.input_lock_ms:
		push_error(
			"HUDConfig invariant (TR-hud-008): ap_tick_duration_ms (%d) exceeds InputConfig.input_lock_ms (%d) — clamping effective ap_tick to %d."
			% [hud_cfg.ap_tick_duration_ms, input_cfg.input_lock_ms, input_cfg.input_lock_ms]
		)
		hud_cfg.ap_tick_duration_ms = input_cfg.input_lock_ms
