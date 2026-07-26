## EndTurnAction — the one verb exempt from affordability/legality checks.
##
## Foundation-layer command model per ADR-0002. Sets [member Action.verb] to
## [constant Action.Verb.END_TURN] in [method _init]. Unconditionally legal
## for the active player (no softlock, TR-gamestate-017) — its
## [code]validate()[/code]/[code]apply()[/code] handlers live on [GameState]
## itself (this story's private [code]_validate_end_turn[/code]/
## [code]_apply_end_turn[/code]), never embedded on this class (ADR-0002
## forbids the command-pattern of methods directly on an [Action] subclass).
##
## [b]Scope note (Story 002):[/b] the owning handler's [code]apply()[/code] is
## a minimal no-op stub here — Story 003 (ADR-0008) wires the real
## end-of-turn sequence (AP discard, next-player switch, conditional
## [code]round_number[/code] increment, [code]start_turn()[/code]).
##
## Usage:
## [codeblock]
## var action := EndTurnAction.new()
## action.player = state.active_player
## var result: ActionResult = state.apply_action(action)
## assert(result.ok) # unconditionally legal for the active player
## [/codeblock]
class_name EndTurnAction
extends Action


func _init() -> void:
	verb = Action.Verb.END_TURN
