## Ammo — limited attacks for vehicles and aircraft, refilled beside a supply structure
## (user decision 2026-10-01).
##
## Rules:
## [br]• Ground vehicles and aircraft carry [method max_ammo] attacks; infantry never use ammo.
## [br]• Every attack AND every counterattack spends 1. At 0 the unit can still move but has no
##   legal targets ([method Combat.legal_targets_from] gates on [method is_empty]), so it can
##   neither attack nor counter until resupplied.
## [br]• At the start of its owner's turn, each COMPLETED structure whose type
##   [member StructureTypeDef.resupplies] refills every own unit on a 4-neighbour tile, and the
##   passengers it carries. Free and automatic.
##
## State is [member UnitState.ammo_spent] (spent, not remaining) so a fresh unit and every
## pre-ammo save start full. Pure static helpers; the only mutators are [method spend] and
## [method resupply_turn].
class_name Ammo
extends RefCounted

const _NEIGHBOURS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Attacks a full [param type] carries; 0 = unlimited (infantry, or an explicit 0).
static func max_ammo(type: UnitTypeDef) -> int:
	if type == null or type.max_ammo == 0:
		return 0
	# Unarmed (transports, lifters) never fire, so they carry no ammo to track.
	if type.attack_range <= 0 or type.can_target.is_empty():
		return 0
	if type.max_ammo > 0:
		return type.max_ammo
	match type.unit_class:
		UnitTypeDef.UnitClass.GROUND_VEHICLE:
			return CombatBalance.combat.vehicle_ammo
		UnitTypeDef.UnitClass.AIR:
			return CombatBalance.combat.air_ammo
	return 0


static func uses_ammo(type: UnitTypeDef) -> bool:
	return max_ammo(type) > 0


## [param unit]'s full load: its type's, plus the cached tech bonus (Supply Lines, Ammo Surplus)
## for a unit that uses ammo at all. 0 = unlimited.
static func unit_max(unit: UnitState) -> int:
	var m: int = max_ammo(unit.type)
	return m + unit.tech_ammo_bonus if m > 0 else 0


## Attacks [param unit] has left, or -1 when it doesn't use ammo.
static func remaining(unit: UnitState) -> int:
	var m: int = unit_max(unit)
	if m <= 0:
		return -1
	return maxi(0, m - unit.ammo_spent)


## True when [param entity] is a unit that uses ammo and has none left.
static func is_empty(entity: EntityState) -> bool:
	return entity is UnitState and remaining(entity as UnitState) == 0


## Spends one attack. No-op for anything that doesn't use ammo (infantry, structures).
static func spend(entity: EntityState) -> void:
	if entity is UnitState and uses_ammo((entity as UnitState).type):
		(entity as UnitState).ammo_spent += 1


## True when [param structure] can resupply right now.
static func is_resupplier(structure: StructureState) -> bool:
	return structure.type != null and structure.type.resupplies \
		and structure.build_status == StructureState.BuildStatus.COMPLETED


## Start-of-turn step: refills every own unit beside an own resupplying structure. Returns one
## [UnitResuppliedEvent] per unit that actually gained ammo (a full unit is not announced).
static func resupply_turn(state: GameState, player: int) -> Array[Event]:
	var events: Array[Event] = []
	if state.grid == null:
		return events   # board-less states (unit-test fixtures): nothing is adjacent to anything
	# ★ 2026-10-01 (tech trees): Forward Depots widen the reach; Field Workshops heal there too.
	var reach: int = maxi(1, Research.sum(state, player, &"resupply_range"))
	var heal: int = Research.sum(state, player, &"supply_heal")
	var healed: Dictionary = {}
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState) or not is_resupplier(e as StructureState):
			continue
		for d: Vector2i in _offsets(reach):
			var u: EntityState = state.entity_at(e.position + d)
			if not (u is UnitState) or u.owner != player:
				continue
			if heal > 0 and not healed.has(u.entity_id):
				healed[u.entity_id] = true
				Unit.apply_hp_delta(u as UnitState, heal)
			for unit: UnitState in [u as UnitState] + Unit.all_carried(u as UnitState):
				if unit.ammo_spent > 0 and uses_ammo(unit.type):
					unit.ammo_spent = 0
					var evt := UnitResuppliedEvent.new()
					evt.entity_id = unit.entity_id
					evt.owner = player
					evt.supplier_id = e.entity_id
					events.append(evt)
	return events


## Every tile offset within Manhattan distance [param reach] (1 = the four neighbours).
static func _offsets(reach: int) -> Array[Vector2i]:
	if reach <= 1:
		return _NEIGHBOURS
	var out: Array[Vector2i] = []
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var m: int = absi(dx) + absi(dy)
			if m >= 1 and m <= reach:
				out.append(Vector2i(dx, dy))
	return out

