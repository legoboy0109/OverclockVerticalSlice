## GameStateReader — read-only facade over [GameState] for Presentation-layer
## consumers (HUD, Command & Action Interface).
##
## Presentation-layer contract per ADR-0016 §1 ("Read-only facade: never-mutates
## is structural, not reviewed", TR-hud-003). This is the **Story 010 stub**:
## only the [method unit_info] accessor this story owns (TR-unit-013 — "HUD/Cmd
## read-surface: type, cur/max hp, effective attack, move cost, has-acted,
## blocked-shot reason; read-only"). The Game HUD epic (ADR-0016) supersedes this
## file with the full getter set named in its skeleton — [code]active_player()[/code],
## [code]round_number()[/code], [code]match_status()[/code], [code]current_ap()[/code],
## [code]income_breakdown()[/code], [code]can_afford()[/code], [code]entities()[/code],
## [code]entity_at()[/code], etc. — all OUT OF SCOPE here.
##
## [b]Structural read-only, not convention[/b]: GDScript has no access-modifier
## keywords, so "read-only" cannot be enforced by a [code]private[/code] marker.
## It is enforced by shape instead — this class exposes getters only (no setter,
## no [code]apply_action[/code]), and [method unit_info] returns a freshly built
## value-snapshot [Dictionary] (copied primitives + one immutable template
## reference), never the live [UnitState] or [member _state]. There is no
## reachable path from a caller holding this reader, or holding [method unit_info]'s
## return value, back to any [GameState]/[UnitState] mutator.
##
## Usage:
## [codeblock]
## var reader := GameStateReader.new(state)
## var info := reader.unit_info(unit.entity_id)
## print(info["type"].display_name, " ", info["current_hp"], "/", info["hp"])
## [/codeblock]
class_name GameStateReader
extends RefCounted

## The wrapped authoritative state. Never exposed by any accessor — no getter
## returns [member _state] or an object holding a live reference back to it.
var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Returns a read-only value-snapshot [Dictionary] describing the unit at
## [param entity_id]. (TR-unit-013 / ADR-0016 §1's [code]unit_info(entity_id)[/code]-
## shaped accessor.)
##
## Keys: [code]"type"[/code] ([UnitTypeDef] registry template reference —
## immutable per ADR-0007, safe to hand out as-is), [code]"current_hp"[/code]
## (int), [code]"hp"[/code] (int, = [code]type.hp[/code], the max), [code]"effective_attack"[/code]
## (int, [method Unit.effective_attack] — Story 004's live Research-tech fold),
## [code]"move_cost"[/code] (int, = [code]type.move_cost[/code]), [code]"has_attacked"[/code]
## (bool), [code]"attack_range"[/code] (int, = [code]type.attack_range[/code] — the
## Combat-owned [code]BlockedReason[/code] classification itself is Out of Scope
## for this story per ADR-0010; Unit only surfaces its own fields as inputs).
##
## [b]Total/safe contract[/b]: [member GameState.entities_by_id] is keyed by
## [EntityState] and holds BOTH [UnitState] and [code]StructureState[/code].
## If [param entity_id] does not resolve to a live entity, OR resolves to a
## non-[UnitState] entity (e.g. a structure's id queried through this unit-only
## accessor), this returns an empty [Dictionary] — never a runtime type error.
## This is a deliberate, read-only total function, not an omission.
##
## The returned [Dictionary] is a fresh value copy on every call — mutating it
## can never alias or perturb [member _state] (structural AC-2 read-only proof).
func unit_info(entity_id: int) -> Dictionary:
	var entity: EntityState = _state.entities_by_id.get(entity_id)
	if entity == null or not (entity is UnitState):
		return {}
	var unit := entity as UnitState

	return {
		"type": unit.type,
		"current_hp": unit.current_hp,
		"hp": unit.type.hp,
		"effective_attack": Unit.effective_attack(_state, unit),
		"move_cost": unit.type.move_cost,
		"has_attacked": unit.has_attacked,
		"attack_range": unit.type.attack_range,
	}
