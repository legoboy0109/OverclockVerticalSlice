## ApCounterWidget — the reactive Control that renders the AP counter (the game's
## *tactical* budget), wrapping the pure [ApCounterFsm] (Story 003) per
## ADR-0016 §2/§8 (TR-hud-005/006/007) and CR-3.
##
## A thin [BudgetCounterWidget] subclass: all the FSM wiring, preview echo, settle
## timing, opponent muting, and the Integration-testable display model
## ([method committed_value]/[method showing_echo]/[method projected_value]/
## [method insufficient_ap]/[method opponent_label_shown]/[method is_muted]/
## [method fsm_state]) live in the shared base — this class supplies only the
## AP-specific pieces: it reads the [b]AP[/b] pool
## ([method GameStateReader.current_ap]) and renders in the tactical/AP hue family
## (CR-3 — held distinct from the Credits counter's war-chest hue so the two
## persistent counters never blur; the final split is an /art-bible decision,
## OQ-9). AP is a flat, non-income budget that fills to `FLAT_AP_PER_TURN + carry`
## at start-of-turn and ticks down on each tactical (move/attack) or AP-surcharge
## commit; the preview echo shows CAI's [method CommandFSM.projected_remaining_ap].
##
## Usage:
## [codeblock]
## var counter := ApCounterWidget.new()
## counter.bind(reader)                       # HudReactiveControl DI
## counter.configure(HudBalance.hud, local_player)
## hud_layer.add_child(counter)
## # when CAI opens an affordable move preview costing C AP:
## counter.open_preview(CommandFSM.projected_remaining_ap(state, local_player, C), true)
## [/codeblock]
class_name ApCounterWidget
extends BudgetCounterWidget


## Selects the AP pool (verbatim, Pass-Through Invariant).
func _read_committed_value() -> int:
	return _reader.current_ap(_player)


## The tactical/AP neon hue (muted for the opponent counter, CR-3b).
func _budget_color() -> Color:
	return Color(0.55, 0.55, 0.6) if _is_opponent else Color(0.2, 1.0, 0.9)


## "AP" for the "insufficient AP" unaffordable-preview text (AC-7).
func _insufficient_noun() -> String:
	return "AP"


## Whether an unaffordable AP preview is open — renders "insufficient AP" (AC-7).
## AP-named alias for [method BudgetCounterWidget.insufficient_budget].
func insufficient_ap() -> bool:
	return insufficient_budget()
