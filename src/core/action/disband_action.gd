## DisbandAction — voluntarily destroy one of your own units for a partial refund.
##
## The escape valve the deficit lock depends on (`unit-upkeep.md` UR-7). Without it a
## player who over-extends has no [i]agency[/i] in recovering — only the hope of losing
## units in combat — and UR-6's produce/build/research lock would be a trap rather than
## a pressure.
##
## Costs [member EconomyConfig.disband_ap_cost] AP and refunds
## [member EconomyConfig.disband_refund_pct]% of the unit's [member UnitTypeDef.produce_cost]
## in Credits. ★ Being a [b]priced[/b] verb is what keeps it inside Pillar 1 — it is not
## a free action, and produce-then-disband is strictly loss-making by design.
##
## ★ Deliberately available [b]while in deficit[/b], unlike produce/build/research: it is
## the one action that can [i]reduce[/i] upkeep, so locking it would make the deficit
## unrecoverable by the player's own choice.
##
## Usage:
## [codeblock]
## var action := DisbandAction.new()
## action.player = state.active_player
## action.entity_id = my_unit.entity_id
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name DisbandAction
extends Action

## The own, living unit to destroy. Must be a [UnitState] owned by [member Action.player] —
## never a structure, never the HQ, never an enemy unit (UR-7).
@export var entity_id: int = -1


func _init() -> void:
	verb = Action.Verb.DISBAND
