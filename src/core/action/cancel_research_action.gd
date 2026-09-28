## CancelResearchAction — abandon the research in progress at [member researcher_id],
## refunding half its Credits (never the AP). Data only; handled by
## [method Research.validate_cancel_research] / [method Research.apply_cancel_research].
class_name CancelResearchAction
extends Action

@export var researcher_id: int = -1


func _init() -> void:
	verb = Action.Verb.CANCEL_RESEARCH
