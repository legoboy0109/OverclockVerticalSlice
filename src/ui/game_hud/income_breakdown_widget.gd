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
## income.open_preview(unit_type.upkeep)  # AC-20 — the unit's authored upkeep
## [/codeblock]
class_name IncomeBreakdownWidget
extends HudReactiveControl


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
	_sync()


func _on_action_applied(_result: ActionResult) -> void:
	# A commit can change gross (a research tier), upkeep (a unit produced, a unit
	# lost) or both. Closing any open preview here is deliberate: the preview
	# describes a purchase that has now either happened or been overtaken, so
	# leaving it up would show a projection from a stale baseline.
	_preview_upkeep_delta = -1
	queue_redraw()
	_sync()


# --- Purchase preview (AC-20) -------------------------------------------------

## Opens the prospective-purchase preview: [param upkeep_delta] is the recurring
## upkeep the considered unit would add (see [method Upkeep.default_upkeep]).
## Shows the resulting net income beside the live one.
func open_preview(upkeep_delta: int) -> void:
	_preview_upkeep_delta = maxi(0, upkeep_delta)
	queue_redraw()
	_sync()


## Clears the purchase preview (selection cleared, or the purchase committed).
func close_preview() -> void:
	_preview_upkeep_delta = -1
	queue_redraw()
	_sync()


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


# ★ 2026-10-01 (holo glass): a small glass card under the top plate — a ledger of where
# the turn's Credits come from and go. Text sits on a child over the plate (a GlassBackdrop
# paints over its parent's own _draw). Net is the one emphasised figure: your hue when in
# surplus, plain white with a DEFICIT caption when not (no red/green — art bible §4.6).
const CARD_W: float = 250.0
var _plate: Control = null
var _text: Control = null


func _ready() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	GlassBackdrop.attach(_plate)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_card)
	_plate.add_child(_text)
	_sync()


func _card_height() -> float:
	return 150.0 if is_previewing() else 124.0


func _sync() -> void:
	if _plate == null:
		return
	_plate.visible = _expanded and _reader != null
	_plate.size = Vector2(CARD_W, _card_height())
	_text.size = _plate.size
	_text.queue_redraw()


func _draw() -> void:
	_sync()


func _row(ci: CanvasItem, y: float, label: String, value: String, color: Color, size_px: int = 14) -> void:
	ci.draw_string(UiTheme.label_font(), Vector2(14, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_LABEL,
		UiTheme.TEXT_MUTED)
	var f: Font = UiTheme.font(600)
	var w: float = f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	ci.draw_string(f, Vector2(CARD_W - 14 - w, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _draw_card() -> void:
	if not _expanded or _reader == null:
		return
	var t: Control = _text
	_row(t, 24, "BASE INCOME", "+%d" % base_value(), UiTheme.TEXT)
	_row(t, 44, "RESEARCH TIERS", "+%d" % tiers_value(), UiTheme.TEXT)
	_row(t, 64, "UPKEEP", "-%d" % upkeep_value(), UiTheme.TEXT)
	t.draw_line(Vector2(14, 76), Vector2(CARD_W - 14, 76), Color(UiTheme.EDGE, 0.6), 1.0)
	var net: int = net_value()
	var hue: Color = UiTheme.player_hue(_player)
	_row(t, 102, "DEFICIT / TURN" if net < 0 else "NET / TURN", "%+d" % net, UiTheme.TEXT if net < 0 else hue, 22)
	if is_previewing():
		_row(t, 134, "AFTER PURCHASE", "%+d  (-%d upkeep)" % [previewed_net_value(), _preview_upkeep_delta],
			UiTheme.TEXT_MUTED, 13)
