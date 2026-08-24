## IncomeBreakdownWidget — the Credit-income breakdown popover (ADR-0016 §8 +
## ADR-0006, TR-hud-019, CR-3d). Since the 2026-08-05 economy pivot, income funds
## the Credits pool, so this belongs to the [CreditsCounterWidget] (it is parented
## under that counter by [method GameHud.assemble]). Renders
## [method GameStateReader.income_breakdown]'s PRE-LABELED fields
## ([code]base[/code], [code]tiers[/code]) VERBATIM — read
## through [method Credits.credit_income_breakdown] — the HUD never receives raw
## inputs (tier count) and splits locally, and never re-derives a
## coefficient (Pass-Through Invariant).
##
## An on-demand popover: hover/click/keyboard-toggles the Credits counter. Starts
## expanded iff [member HUDConfig.income_breakdown_default_expanded].
##
## [b]Testable model[/b] (AC-8): [method breakdown] / [method base_value] /
## [method tiers_value] read the facade verbatim —
## the tier-0 (base only) case surfaces
## as literal zeros, never a phantom non-zero. [method _draw] renders them (advisory).
##
## Usage:
## [codeblock]
## var income := IncomeBreakdownWidget.new()
## income.bind(reader)
## income.configure(HudBalance.hud, local_player)
## ap_counter.add_child(income)   # anchored to the counter (Story 004)
## [/codeblock]
class_name IncomeBreakdownWidget
extends HudReactiveControl

var _config: HUDConfig = null
var _player: int = 0
var _expanded: bool = false


func configure(config: HUDConfig, player: int) -> void:
	_config = config
	_player = player
	_expanded = config.income_breakdown_default_expanded if config != null else false


## Toggles the popover open/closed (hover/click/keyboard entry point).
func toggle() -> void:
	_expanded = not _expanded
	queue_redraw()


func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


# --- Display model (Integration-testable) ------------------------------------

## The full breakdown [Dictionary] ([code]{base, outpost, econ_tech}[/code]) read
## VERBATIM from [method GameStateReader.income_breakdown]. [code]{}[/code] if unbound.
func breakdown() -> Dictionary:
	return _reader.income_breakdown(_player) if _reader != null else {}

## The base-income term (verbatim).
func base_value() -> int:
	return breakdown().get("base", 0)

## The research-tier income term (verbatim; 0 at tier 0).
## ★ Replaced `outpost_value()` on 2026-08-24 (S6-01) — the Economy Outpost is
## deleted and income is research-driven. Returns 0 rather than a missing key so a
## tier-0 player renders an explicit "no tiers yet", never a phantom bonus.
func tiers_value() -> int:
	return breakdown().get("tiers", 0)

## Whether the popover is currently expanded.
func is_expanded() -> bool:
	return _expanded


func _draw() -> void:
	if not _expanded or _reader == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var b: Dictionary = breakdown()
	var text: String = "base %d  +outpost %d  +econ-tech %d" % [
		b.get("base", 0), b.get("outpost", 0), b.get("econ_tech", 0)]
	draw_string(font, Vector2(4, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
