## ResearchAction — start researching [member tech] at [member researcher_id]
## (CR-14: the player's HQ). Data only; validated and applied by
## [method Research.validate_research] / [method Research.apply_research] (ADR-0002).
class_name ResearchAction
extends Action

## Entity id of the researching structure (a type with [code]can_research[/code]).
@export var researcher_id: int = -1

## The tech to start — a shared [code]Techs[/code] preset.
@export var tech: TechDef


func _init() -> void:
	verb = Action.Verb.RESEARCH
