## Ability — unit abilities and transport (unit-abilities.md, transport-and-pilots.md).
##
## Static, like every Core system: [method validate] / [method apply] for
## [UseAbilityAction], dispatched by [method GameState.apply_action] (AB-4), plus pure queries
## the menu and the AI read ([method legal_targets], [method usable]).
##
## [b]Who acts.[/b] The acting unit is the one on the board. For DISEMBARK and PARADROP that
## is the VEHICLE, with [member UseAbilityAction.passenger_id] naming who leaves — a carried
## unit is off the board and cannot be selected or act (TP-1).
##
## [b]One meaningful thing per turn (AB-5).[/b] A catalogue ability and an attack exclude each
## other: using one marks [member UnitState.has_attacked] too, and neither is allowed after the
## other. Embark and disembark are movement, not actions, so they are exempt — TP-3's own
## rules (no embark after disembarking, disembarking ends the turn) govern them instead.
class_name Ability
extends RefCounted


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Whether [param unit] carries [param ability] at all — embark for anything that fits in a
## transport, disembark for anything carrying someone, catalogue entries by listing.
static func carries(unit: UnitState, ability: AbilityDef) -> bool:
	if ability == Abilities.EMBARK:
		return unit.type.unit_class != UnitTypeDef.UnitClass.AIR
	if ability == Abilities.DISEMBARK:
		return not Unit.passengers(unit).is_empty()
	return ability in unit.type.abilities


## Every ability [param unit] could use this turn if a target were available, in
## [code]Abilities.ALL[/code] order. Checks the unit, not targets. For menus and the AI.
static func usable(state: GameState, unit: UnitState) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for a: AbilityDef in Abilities.ALL:
		if _unit_gate(state, unit, a) == Action.Reason.OK:
			out.append(a)
	return out


## Every tile [param unit] could aim [param ability] at right now (for DISEMBARK/PARADROP,
## on behalf of [param passenger]). Each is checked through the full [method validate], so
## the menu, the AI and the rules can never disagree about what is legal.
static func legal_targets(state: GameState, unit: UnitState, ability: AbilityDef, passenger: UnitState = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = ability.ability_range
	for dy: int in range(-r, r + 1):
		for dx: int in range(-(r - absi(dy)), r - absi(dy) + 1):
			var t := unit.position + Vector2i(dx, dy)
			if not state.grid.in_bounds(t.x, t.y):
				continue
			var a := _probe(unit, ability, t, passenger)
			if validate(state, a) == Action.Reason.OK:
				out.append(t)
	return out


static func _probe(unit: UnitState, ability: AbilityDef, tile: Vector2i, passenger: UnitState) -> UseAbilityAction:
	var a := UseAbilityAction.new()
	a.player = unit.owner
	a.unit_id = unit.entity_id
	a.ability = ability
	a.target_tile = tile
	a.passenger_id = passenger.entity_id if passenger != null else -1
	return a


# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------

## The unit-side gates, target aside: owned, on the board, carries it, able to act, priced.
static func _unit_gate(state: GameState, unit: UnitState, ability: AbilityDef) -> int:
	if unit.owner != state.active_player:
		return Action.Reason.ILLEGAL_TARGET
	if not carries(unit, ability):
		return Action.Reason.ABILITY_NOT_CARRIED
	# A pilotless vehicle may still let passengers OUT — it is the passengers acting.
	if ability != Abilities.DISEMBARK and not Unit.is_functional(unit):
		return Action.Reason.VEHICLE_UNPILOTED
	if unit.turn_ended:
		return Action.Reason.ALREADY_ACTED
	if ability == Abilities.EMBARK:
		if unit.disembarked_this_turn:
			return Action.Reason.ALREADY_ACTED
	elif ability != Abilities.DISEMBARK:
		if unit.ability_used_this_turn or unit.has_attacked:
			return Action.Reason.ALREADY_ACTED
		if int(unit.cooldowns.get(ability.id, 0)) > 0:
			return Action.Reason.ABILITY_ON_COOLDOWN
		if ability.uses_per_match > 0 and int(unit.uses.get(ability.id, 0)) >= ability.uses_per_match:
			return Action.Reason.ABILITY_ON_COOLDOWN
	if ability.credit_cost > 0:
		if state.per_player[unit.owner].in_deficit:
			return Action.Reason.IN_DEFICIT
		if not Credits.can_afford(state, unit.owner, ability.credit_cost):
			return Action.Reason.CANT_AFFORD_CREDITS
	if not AP.can_afford(state, unit.owner, ability.ap_cost):
		return Action.Reason.CANT_AFFORD
	return Action.Reason.OK


static func validate(state: GameState, action: UseAbilityAction) -> int:
	var entity: EntityState = state.entities_by_id.get(action.unit_id, null)
	if entity == null or not (entity is UnitState) or action.ability == null:
		return Action.Reason.NO_SUCH_ENTITY
	var unit: UnitState = entity
	var gate: int = _unit_gate(state, unit, action.ability)
	if gate != Action.Reason.OK:
		return gate
	var tile: Vector2i = action.target_tile
	if not state.grid.in_bounds(tile.x, tile.y) \
			or state.grid.manhattan_distance(unit.position, tile) > action.ability.ability_range:
		return Action.Reason.OUT_OF_RANGE
	var target: EntityState = state.entity_at(tile)
	match action.ability.id:
		&"embark":
			return _validate_embark(unit, target)
		&"disembark", &"paradrop":
			var passenger: UnitState = _passenger(unit, action.passenger_id)
			if passenger == null:
				return Action.Reason.NO_SUCH_ENTITY
			if action.ability.id == &"paradrop" and passenger == unit.pilot:
				return Action.Reason.ILLEGAL_TARGET   # the pilot flies the transport
			if passenger.embarked_this_turn and action.ability.id == &"disembark":
				return Action.Reason.ALREADY_ACTED   # TP-3: not in and out in one turn
			if not state.grid.is_passable(tile.x, tile.y) \
					or not Unit.can_stand_on(passenger.type, state.grid.terrain_at(tile.x, tile.y)):
				return Action.Reason.TILE_OCCUPIED
			return Action.Reason.OK
		&"repair":
			if not (target is UnitState) or target.owner != unit.owner or target == unit:
				return Action.Reason.ILLEGAL_TARGET
			if (target as UnitState).current_hp >= Unit.effective_max_hp(target as UnitState):
				return Action.Reason.ILLEGAL_TARGET   # repairing a full unit is a trap, not a choice
			return Action.Reason.OK
		&"fortify", &"self_destruct":
			return Action.Reason.OK if tile == unit.position else Action.Reason.ILLEGAL_TARGET
		&"demolish":
			if not (target is StructureState) or target.owner == unit.owner:
				return Action.Reason.ILLEGAL_TARGET   # structures only, never units
			return Action.Reason.OK
		&"capture_vehicle":
			if unit.type.unit_class != UnitTypeDef.UnitClass.INFANTRY:
				return Action.Reason.ILLEGAL_TARGET
			if not (target is UnitState) or target.owner == unit.owner:
				return Action.Reason.ILLEGAL_TARGET
			var v: UnitState = target
			# Ground only; must be empty — the pilot has to be dealt with first.
			if v.type.unit_class != UnitTypeDef.UnitClass.GROUND_VEHICLE or not v.type.requires_pilot \
					or v.pilot != null or not v.cargo.is_empty():
				return Action.Reason.ILLEGAL_TARGET
			return Action.Reason.OK
	return Action.Reason.UNKNOWN_VERB


static func _validate_embark(unit: UnitState, target: EntityState) -> int:
	if not (target is UnitState) or target.owner != unit.owner or target == unit:
		return Action.Reason.ILLEGAL_TARGET
	var v: UnitState = target
	if v.type.requires_pilot and v.pilot == null and unit.type.can_pilot:
		return Action.Reason.OK
	if v.type.transport_capacity <= 0 or not (unit.type.unit_class in v.type.transport_accepts):
		return Action.Reason.TRANSPORT_FULL
	if Unit.transport_load(v) + unit.type.transport_size > v.type.transport_capacity:
		return Action.Reason.TRANSPORT_FULL
	return Action.Reason.OK


static func _passenger(vehicle: UnitState, passenger_id: int) -> UnitState:
	for p: UnitState in Unit.passengers(vehicle):
		if p.entity_id == passenger_id:
			return p
	return null


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

static func apply(state: GameState, action: UseAbilityAction) -> Array[Event]:
	if validate(state, action) != Action.Reason.OK:
		return []
	var unit: UnitState = state.entities_by_id[action.unit_id]
	var ability: AbilityDef = action.ability
	var tile: Vector2i = action.target_tile
	AP.spend(state, unit.owner, ability.ap_cost)
	if ability.credit_cost > 0:
		Credits.spend(state, unit.owner, ability.credit_cost)
	unit.stood_down = false
	if ability != Abilities.EMBARK and ability != Abilities.DISEMBARK:
		unit.ability_used_this_turn = true
		unit.has_attacked = true   # AB-5: one meaningful thing per turn
		if ability.cooldown > 0:
			unit.cooldowns[ability.id] = ability.cooldown
		unit.uses[ability.id] = int(unit.uses.get(ability.id, 0)) + 1

	var events: Array[Event] = []
	var used := AbilityUsedEvent.new()
	used.unit_id = unit.entity_id
	used.ability = ability
	used.target_tile = tile
	match ability.id:
		&"embark":
			var v: UnitState = state.entity_at(tile)
			var as_pilot: bool = v.type.requires_pilot and v.pilot == null and unit.type.can_pilot
			_lift_off_board(state, unit)
			unit.embarked_this_turn = true
			if as_pilot:
				v.pilot = unit
			else:
				v.cargo.append(unit)
			var e := UnitEmbarkedEvent.new()
			e.unit_id = unit.entity_id
			e.vehicle_id = v.entity_id
			e.as_pilot = as_pilot
			events.append(e)
			return events
		&"disembark", &"paradrop":
			var p: UnitState = _passenger(unit, action.passenger_id)
			if p == unit.pilot:
				unit.pilot = null
			else:
				unit.cargo.erase(p)
			p.position = tile
			p.turn_ended = true               # TP-3: disembarking ends its turn
			p.disembarked_this_turn = true
			state.entities_by_id[p.entity_id] = p
			state.grid.place(p.entity_id, tile.x, tile.y)
			var d := UnitDisembarkedEvent.new()
			d.unit_id = p.entity_id
			d.vehicle_id = unit.entity_id
			d.tile = tile
			d.paradrop = ability.id == &"paradrop"
			events.append(d)
			return events
		&"repair":
			var t: UnitState = state.entity_at(tile)
			var before: int = t.current_hp
			Unit.apply_hp_delta(t, ability.amount)
			used.amount = t.current_hp - before
		&"fortify":
			unit.fortify = ability.amount
			used.amount = ability.amount
		&"demolish":
			var s: StructureState = state.entity_at(tile)
			var dmg: int = maxi(CombatBalance.combat.min_damage,
				Unit.effective_attack(state, unit) + ability.amount - s.type.defense
				- Combat.resistance(s, unit.type.damage_type))
			s.current_hp = maxi(0, s.current_hp - dmg)
			used.amount = dmg
			events.append(used)
			events.append(DamageEvent.new(unit.entity_id, s.entity_id, dmg))
			if s.current_hp <= 0:
				events.append_array(state.destroy_entity(s.entity_id))
			Promotion.award_hit(state, unit, s)   # demolition is combat (PV-1)
			Promotion.apply_rank(state, unit)
			return events
		&"self_destruct":
			return _self_destruct(state, unit, ability, used)
		&"capture_vehicle":
			var v: UnitState = state.entity_at(tile)
			_lift_off_board(state, unit)
			v.pilot = unit
			v.owner = unit.owner
			var c := VehicleCapturedEvent.new()
			c.vehicle_id = v.entity_id
			c.pilot_id = unit.entity_id
			c.new_owner = unit.owner
			events.append(c)
			return events
	events.append(used)
	return events


## Takes [param unit] off the board into a vehicle: off the grid and out of
## [member GameState.entities_by_id], so nothing that walks the board can see it (TP-1).
static func _lift_off_board(state: GameState, unit: UnitState) -> void:
	state.grid.remove(unit.position.x, unit.position.y)
	state.entities_by_id.erase(unit.entity_id)


## SELF_DESTRUCT: [member AbilityDef.amount] damage to everything orthogonally adjacent,
## friend or foe (DT-8), through the standard formula's defence, cover and resistance terms;
## all damage before any death (DT-9), then the unit itself dies with its passengers.
static func _self_destruct(state: GameState, unit: UnitState, ability: AbilityDef, used: AbilityUsedEvent) -> Array[Event]:
	var events: Array[Event] = [used]
	var victims: Array[EntityState] = []
	for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:   # row-major
		var e: EntityState = state.entity_at(unit.position + d)
		if e != null:
			victims.append(e)
	var dmgs: Array[int] = []
	for v: EntityState in victims:
		var def: int = Unit.effective_defense(state, v) if v is UnitState else v.type.defense
		var cover: int = CombatBalance.combat.cover_dr if (v is UnitState and Unit.benefits_from_cover(v) \
			and state.grid.is_cover(v.position.x, v.position.y)) else 0
		dmgs.append(maxi(CombatBalance.combat.min_damage,
			ability.amount - cover - def - Combat.resistance(v, UnitTypeDef.DamageType.KINETIC)))
	for i: int in victims.size():
		var v: EntityState = victims[i]
		if v is UnitState:
			Unit.apply_hp_delta(v, -dmgs[i])
		else:
			v.current_hp = maxi(0, v.current_hp - dmgs[i])
		events.append(DamageEvent.new(unit.entity_id, v.entity_id, dmgs[i]))
	for v: EntityState in victims:
		if v.current_hp <= 0:
			events.append_array(state.destroy_entity(v.entity_id))
	unit.current_hp = 0
	events.append_array(state.destroy_entity(unit.entity_id))
	return events
