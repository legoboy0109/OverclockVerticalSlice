## CancelProductionAction — abandon the unit a producer is building (S8-28).
##
## The unit sibling of [CancelBuildAction]. Refunds
## [code]CANCEL_REFUND_RATE x produce_cost[/code] in Credits — the SAME rate and the
## same shape structures already use, because the game had one cancellation rule and
## inventing a second would be a rule to learn for no reason.
##
## ⚠ The AP surcharge is NOT refunded, matching cancel-build exactly: AP bought the
## tempo, the tempo was spent, and only the Credits were ever recoverable.
class_name CancelProductionAction
extends Action

## The producer whose in-flight build is being abandoned.
@export var producer_id: int = -1


func _init() -> void:
	verb = Action.Verb.CANCEL_PRODUCTION
