## WaitAction — mark one of your own entities as finished for this turn.
##
## The commit behind the contextual action menu's **Wait** row
## (`design/ux/action-menu.md`, OQ-1). The GDD has always said Wait "ends this
## entity's involvement without spending"; until 2026-08-25 nothing in the
## simulation could record that, so Wait was a deselect and the entity kept
## appearing everywhere an idle one does.
##
## [b]Advisory, not binding[/b] (user decision, 2026-08-25). This spends nothing,
## forbids nothing, and no validator anywhere consults
## [member EntityState.stood_down]. It sets a per-turn mark that the INTERFACE
## reads: a stood-down entity stops breathing on the board, is skipped by the
## idle-entity cursor cycle, and stops counting toward the End-Turn idle notice.
## Every verb it had remains legal, and acting with it clears the mark.
##
## [b]Why it is an [Action] at all, given it changes no rules.[/b] It writes core
## state, and [method GameState.apply_action] is the sole mutation vector
## (ADR-0002) — a UI that reached in and set the field itself would be the exact
## boundary violation the control manifest forbids. Routing it here also puts it
## in the action log for free, and gives the AI a verb it could one day use to
## signal the same thing.
##
## [b]Deliberately free.[/b] Every other verb in the game is priced (Pillar 1), and
## this one is not, because it buys nothing: it is the player telling the interface
## what they have already decided, not an action in the fiction. A priced Wait
## would tax tidiness.
##
## Usage:
## [codeblock]
## var action := WaitAction.new()
## action.player = state.active_player
## action.entity_id = my_unit.entity_id
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name WaitAction
extends Action

## The own, living entity to stand down. A [UnitState] or a [StructureState] —
## both carry [member EntityState.stood_down], because both appear in the
## contextual menu and both can be something the player is finished with.
@export var entity_id: int = -1


func _init() -> void:
	verb = Action.Verb.WAIT
