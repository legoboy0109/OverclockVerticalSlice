## AIBalance — Autoload, logic-free lookup for AI Opponent's tuning config.
##
## Feature-layer Autoload per ADR-0011 §6, a sibling of [code]Balance[/code]/
## [code]UnitBalance[/code]/[code]CombatBalance[/code]/
## [code]StructureBalance[/code], mirroring their thin "read-only lookup
## convenience" idiom. Loads [AIConfig] once at boot and exposes it by
## reference via [code]AIBalance.ai[/code].
##
## [b]Deviation from story AC-3's literal "no new loader class"[/b] — mirrors
## the established per-domain `*Balance` autoload pattern (Balance/
## UnitBalance/CombatBalance/StructureBalance); story AC-3 assumed a single
## shared loader that does not exist in this codebase.
##
## [b]The one exception to "never validates, never interprets":[/b] TR-ai-008
## requires the cross-knob invariant `lethal_floor_bonus >
## economy_ceiling_score` be enforced at load time with a release-surviving
## guard, not a bare `assert()` (ADR-0011 §6 Risks — `assert()` is stripped
## from release exports, which would silently defeat this check in a shipped
## build). This Autoload is the load-time seam ADR-0011 names for that
## enforcement, so unlike its siblings it does own exactly one piece of
## logic: [method _check_lethal_floor_invariant].
##
## Registered in `project.godot`'s `[autoload]` section, after [code]Balance[/code]
## and [code]StructureTypes[/code] (both read by the invariant check) so
## Autoload init order never depends on script-parse-time evaluation — the
## check runs in [method _ready], which the engine guarantees fires only
## after every Autoload node has been added to the tree.
extends Node

## The loaded [AIConfig] tuning-constants resource. Read via
## [code]AIBalance.ai.*[/code].
var ai: AIConfig = preload("res://data/ai/ai_config.tres")


func _ready() -> void:
	_check_lethal_floor_invariant(ai, Balance.economy, StructureTypes.ECONOMY_OUTPOST)


## Enforces TR-ai-008: `lethal_floor_bonus` must exceed the uncapped
## first-Economy-Outpost `action_score` ceiling, or a non-lethal boom could
## silently outscore a finishing blow (CR-7 broken). Computes
## `economy_ceiling_score = OUTPOST_BONUS_TIER1 * Σ_{t=1..economy_horizon}
## economy_decay^t / first_economy_outpost.build_cost` (the GDD's
## `LETHAL_FLOOR_BONUS` row / `action_score` symbol table formula, verbatim)
## and fails loudly — [method @GlobalScope.push_error] plus [method OS.crash]
## — if the invariant does not hold. [method OS.crash] is a real,
## unconditional process termination that survives release exports (unlike a
## bare `assert()`, which release-compiles to a no-op), so a future tuning
## pass that silently breaks the invariant cannot ship undetected. Takes its
## three inputs as explicit parameters (not read internally from the
## Autoload globals) so the check itself is a pure, unit-testable function
## with no scene-tree dependency.
static func _check_lethal_floor_invariant(cfg: AIConfig, economy_cfg: EconomyConfig, first_economy_outpost: StructureTypeDef) -> void:
	var ceiling: float = economy_ceiling_score(cfg, economy_cfg, first_economy_outpost)
	if cfg.lethal_floor_bonus <= ceiling:
		var msg: String = (
			"AIConfig invariant violated (TR-ai-008): lethal_floor_bonus (%s) must exceed economy_ceiling_score (%s). "
			% [cfg.lethal_floor_bonus, ceiling]
			+ "A non-lethal economy build could outscore a finishing blow, breaking CR-7. "
			+ "Raise lethal_floor_bonus, or lower economy_horizon/economy_decay, and re-check."
		)
		push_error(msg)
		OS.crash(msg)


## Pure computation of the invariant's right-hand side:
## `OUTPOST_BONUS_TIER1 * Σ_{t=1}^{economy_horizon} economy_decay^t /
## first_economy_outpost.build_cost` (ADR-0011 §6 / the GDD's
## `LETHAL_FLOOR_BONUS` row, verbatim). No side effects, no Autoload reads —
## callable directly from tests.
static func economy_ceiling_score(cfg: AIConfig, economy_cfg: EconomyConfig, first_economy_outpost: StructureTypeDef) -> float:
	var decayed_sum: float = 0.0
	for t in range(1, cfg.economy_horizon + 1):
		decayed_sum += pow(cfg.economy_decay, t)
	return float(economy_cfg.outpost_bonus_tier1) * decayed_sum / float(first_economy_outpost.build_cost)
