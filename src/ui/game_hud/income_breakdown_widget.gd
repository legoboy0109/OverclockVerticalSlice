## IncomeBreakdownWidget — the Credit-economy readout (ADR-0016 §8 + ADR-0006,
## TR-hud-019, CR-3d; `unit-upkeep.md` UR-8 / AC-19 / AC-20). Since the 2026-08-05
## economy pivot, income funds the Credits pool, so this belongs to the
## [CreditsCounterWidget] (it is parented under that counter by
## [method GameHud.assemble]).
##
## [b]Shows the UR-8 triple: gross − upkeep = net.[/b] Every figure is read
## PRE-LABELED and VERBATIM through [GameStateReader] — gross terms from
## [method GameStateReader.income_breakdown] ([code]base[/code], [code]tiers[/code]),
## upkeep from [method GameStateReader.total_upkeep], net from
## [method GameStateReader.net_income]. The HUD never sums, subtracts or re-derives
## a coefficient (Pass-Through Invariant). In particular [method net_value] is read,
## not computed as gross − upkeep: the economy owns that arithmetic.
##
## ★ [b]net carries the visual weight[/b] (UR-8, and the sprint's own note on this
## story). Gross and upkeep are context; net is the number that goes negative, and
## the player must see the equilibrium coming *before* it arrives, not discover it
## when income stops. [method net_value] is therefore drawn larger, and coloured by
## sign — the only colour in the widget, so it reads at a glance.
##
## [b]Purchase preview (AC-20)[/b]: [method open_preview] takes the upkeep a
## prospective unit would add and shows the resulting net alongside the live one, so
## the cost of a purchase is legible as an ongoing commitment rather than a one-off
## price. [method close_preview] clears it. The caller supplies the delta because
## the prospective unit is not in [GameState] yet — there is nothing for the facade
## to read. This is the one figure the widget computes locally, and it is explicitly
## a projection, never presented as live state.
##
## [b]Testable model[/b] (AC-8/AC-19/AC-20): [method breakdown] / [method gross_value]
## / [method upkeep_value] / [method net_value] / [method previewed_net_value] are the
## integration surface; [method _draw] renders them (advisory).
##
## Usage:
## [codeblock]
## var income := IncomeBreakdownWidget.new()
## income.bind(reader)
## income.configure(HudBalance.hud, local_player)
## credits_counter.add_child(income)   # anchored to the counter (Story 004)
## income.open_preview(Upkeep.default_upkeep(unit_type.produce_cost))  # AC-20
## [/codeblock]
class_name IncomeBreakdownWidget
extends HudReactiveControl

## Drawn in the net figure when net income is negative — the army is eating more
## than the economy earns. Warm, not alarming: a deficit is a legitimate tempo
## play, not an error state.
const NET_NEGATIVE_COLOR: Color = Color(0.93, 0.45, 0.35)
## Drawn in the net figure when net income is positive or zero.
const NET_POSITIVE_COLOR: Color = Color(0.55, 0.87, 0.60)
## The projected-net figure shown during a purchase preview (AC-20) — dimmer than
## the live figures so a projection never reads as state.
const PREVIEW_COLOR: Color = Color(0.75, 0.75, 0.80)

var _config: HUDConfig = null
var _player: int = 0
var _expanded: bool = false

## Upkeep the previewed purchase would add, or -1 when no preview is open.
## Never conflated with 0, which is a legitimate delta (a zero-upkeep unit).
var _preview_upkeep_delta: int = -1


func configure(config: HUDConfig, player: int) -> void:
	_config = config
	_player = player
	_expanded = config.income_breakdown_default_expanded if config != null else false


## Toggles the popover open/closed (hover/click/keyboard entry point).
func toggle() -> void:
	_expanded = not _expanded
	queue_redraw()


func _on_action_applied(_result: ActionResult) -> void:
	# A commit can change gross (a research tier), upkeep (a unit produced, a unit
	# lost) or both. Closing any open preview here is deliberate: the preview
	# describes a purchase that has now either happened or been overtaken, so
	# leaving it up would show a projection from a stale baseline.
	_preview_upkeep_delta = -1
	queue_redraw()


# --- Purchase preview (AC-20) -------------------------------------------------

## Opens the prospective-purchase preview: [param upkeep_delta] is the recurring
## upkeep the considered unit would add (see [method Upkeep.default_upkeep]).
## Shows the resulting net income beside the live one.
func open_preview(upkeep_delta: int) -> void:
	_preview_upkeep_delta = maxi(0, upkeep_delta)
	queue_redraw()


## Clears the purchase preview (selection cleared, or the purchase committed).
func close_preview() -> void:
	_preview_upkeep_delta = -1
	queue_redraw()


## Whether a purchase preview is currently open.
func is_previewing() -> bool:
	return _preview_upkeep_delta >= 0


## Net income as it [i]would be[/i] after the previewed purchase, or
## [method net_value] when no preview is open. The single locally-computed figure
## in this widget (the prospective unit does not exist in state yet, so there is
## nothing to read) — always rendered as a projection, never as live state.
func previewed_net_value() -> int:
	if not is_previewing():
		return net_value()
	return net_value() - _preview_upkeep_delta


# --- Display model (Integration-testable) ------------------------------------

## The gross-income breakdown [Dictionary] ([code]{base, tiers}[/code]) read
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

## Gross income — the sum of the breakdown's terms, i.e. income before upkeep.
## Summed from the pre-labeled terms rather than read separately so it can never
## disagree with the terms shown beside it.
func gross_value() -> int:
	return base_value() + tiers_value()

## Total per-turn upkeep (verbatim). 0 when unbound or when nothing is fielded.
func upkeep_value() -> int:
	return _reader.total_upkeep(_player) if _reader != null else 0

## ★ Net income (verbatim) — the figure UR-8 puts the weight on. Read from the
## economy, never computed here as gross − upkeep.
func net_value() -> int:
	return _reader.net_income(_player) if _reader != null else 0

## Whether the player is currently running an upkeep deficit.
func is_deficit() -> bool:
	return net_value() < 0

## Whether the popover is currently expanded.
func is_expanded() -> bool:
	return _expanded


func _draw() -> void:
	if not _expanded or _reader == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	# Line 1 — where gross comes from. Context, small, neutral.
	draw_string(font, Vector2(4, 12),
		"income  base %d  +tiers %d" % [base_value(), tiers_value()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.78, 0.82))

	# Line 2 — the subtraction, stated as arithmetic so the relationship is legible
	# rather than implied by adjacency.
	draw_string(font, Vector2(4, 26),
		"gross %d  −  upkeep %d" % [gross_value(), upkeep_value()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.78, 0.82))

	# Line 3 — ★ net, the load-bearing figure: larger, and the only coloured one.
	var net: int = net_value()
	draw_string(font, Vector2(4, 46), "net %+d" % net,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		NET_NEGATIVE_COLOR if net < 0 else NET_POSITIVE_COLOR)

	# Line 4 — the projection, only while a purchase is being considered (AC-20).
	if is_previewing():
		var projected: int = previewed_net_value()
		draw_string(font, Vector2(4, 62),
			"after purchase:  net %+d  (−%d upkeep)" % [projected, _preview_upkeep_delta],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PREVIEW_COLOR)
