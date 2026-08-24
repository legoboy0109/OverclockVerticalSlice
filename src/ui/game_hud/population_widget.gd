## PopulationWidget — the current/max population readout (`population-cap.md`
## AC-12). Reads both figures VERBATIM through [GameStateReader]
## ([method GameStateReader.population] / [method GameStateReader.population_cap]) —
## the HUD never adds a Barracks [code]cap_bonus[/code] itself (Pass-Through
## Invariant, ADR-0016 §1).
##
## [b]Why this is a separate widget from [IncomeBreakdownWidget][/b]: upkeep and
## the population cap are the two halves of the same design pairing (an army is
## limited by what you can pay for *and* by what you can house), but they fail
## differently and at different moments. Upkeep degrades continuously — net income
## slides toward zero and the player has turns to react. The cap is a hard stop
## that turns a produce affordance off outright. Merging them into one readout
## would blur a gradient into a wall.
##
## AC-12 has two halves. This widget owns the readout; the produce affordance's
## disabled state and its stated reason belong to the control that offers the
## purchase ([HudControlsWidget]) — a widget cannot grey out a button it does not
## own. [method cap_reason] supplies the wording so both surfaces say the same
## thing, in the same words.
##
## [b]Testable model[/b] (AC-12): [method population_value] / [method cap_value] /
## [method is_at_cap] / [method cap_reason]; [method _draw] renders them (advisory).
##
## Usage:
## [codeblock]
## var pop := PopulationWidget.new()
## pop.bind(reader)
## pop.configure(local_player)
## hud_layer.add_child(pop)
## [/codeblock]
class_name PopulationWidget
extends HudReactiveControl

## Drawn when the player is at or over the cap — no more infantry can be produced.
const AT_CAP_COLOR: Color = Color(0.93, 0.45, 0.35)
## Drawn when the cap is close enough to plan around but not yet binding.
const NEAR_CAP_COLOR: Color = Color(0.95, 0.80, 0.42)
## Drawn with headroom to spare.
const NORMAL_COLOR: Color = Color(0.82, 0.82, 0.86)

## How many slots from the cap the readout starts warning. One unit of notice is
## the minimum that lets a player choose to spend the last slot deliberately.
const NEAR_CAP_SLACK: int = 1

var _player: int = 0


func configure(player: int) -> void:
	_player = player


func _on_action_applied(_result: ActionResult) -> void:
	# Production, a destroyed unit, and a destroyed Barracks all move these
	# figures — including the case where the CAP falls rather than the population
	# rising, which is the one players find surprising.
	queue_redraw()


# --- Display model (Integration-testable) ------------------------------------

## Current population (verbatim). 0 if unbound.
func population_value() -> int:
	return _reader.population(_player) if _reader != null else 0

## Effective population cap including Barracks bonuses (verbatim). 0 if unbound.
func cap_value() -> int:
	return _reader.population_cap(_player) if _reader != null else 0

## True iff no further population can be fielded.
## [b]Greater-or-equal, not equal[/b]: losing a Barracks lowers the cap without
## destroying units (`population-cap.md` AC-11), so a player can legitimately sit
## ABOVE their cap. An equality test would report that state as having headroom.
func is_at_cap() -> bool:
	return _reader != null and population_value() >= cap_value()

## True iff within [constant NEAR_CAP_SLACK] of the cap (but not yet at it).
func is_near_cap() -> bool:
	return not is_at_cap() and population_value() >= cap_value() - NEAR_CAP_SLACK

## The player-facing reason production is blocked, or [code]""[/code] when it is
## not. Shared with the produce affordance so the readout and the disabled button
## give one explanation, not two competing ones.
func cap_reason() -> String:
	if not is_at_cap():
		return ""
	if population_value() > cap_value():
		# Over cap, which only happens when the cap FELL beneath a standing army.
		# Naming the cause matters: the player did not build their way here, and
		# without this they are left looking for a unit they never produced.
		return "over population cap (%d/%d) — a Barracks was lost" % [
			population_value(), cap_value()]
	return "at population cap (%d/%d) — build a Barracks to raise it" % [
		population_value(), cap_value()]


func _draw() -> void:
	if _reader == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var color: Color = NORMAL_COLOR
	if is_at_cap():
		color = AT_CAP_COLOR
	elif is_near_cap():
		color = NEAR_CAP_COLOR
	draw_string(font, Vector2(4, 14), "pop %d/%d" % [population_value(), cap_value()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	var reason: String = cap_reason()
	if reason != "":
		draw_string(font, Vector2(4, 28), reason,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AT_CAP_COLOR)
