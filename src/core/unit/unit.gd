## Unit — static utility class for [UnitState]-owned pure operations.
##
## Core-layer system per ADR-0007 (entity/stat schema). Holds only pure/static
## functions that take the entity explicitly — no instance fields of its own.
## Mirrors the verb-handler shape ADR-0002/0006 established for
## [code]AP[/code]/[code]Movement[/code]/[code]Combat[/code]/[code]BaseProduction[/code]
## (static, stateless, state/entity passed explicitly).
##
## This formally replaces the Sprint-1 [code]tests/helpers/stubs/unit_stub.gd[/code]
## stand-in — [method reset_turn_flags] keeps the exact same signature the
## stub used, so [code]GameState.start_turn[/code]'s step-2 call site
## ([code]Unit.reset_turn_flags(e)[/code], ADR-0008) needs zero change.
##
## Usage:
## [codeblock]
## if Unit.can_attack(unit):
##     ...
## Unit.reset_turn_flags(unit) # start-of-turn, ADR-0008 step 2
## var copy: UnitState = Unit.clone(unit) # AI lookahead, ADR-0011
## Unit.apply_hp_delta(unit, -5) # sole hp mutator, ADR-0007
## [/codeblock]
class_name Unit
extends RefCounted

## Move-cost floor (ADR-0012 §3): "[code]MIN_MOVE_COST[/code] already exists"
## as a conceptual rule (Movement's Approved [code]move_cost >= 1[/code]), but
## no named symbol existed in [code]src/[/code] before this story. Materializes
## that floor as a real [code]Unit[/code]-owned const so
## [method effective_move_cost]'s [code]max(MIN_MOVE_COST, …)[/code] binds to a
## symbol, not a magic literal.
const MIN_MOVE_COST := 1


## Pure precondition query: can [param unit] currently attack? Combat reads
## this (ADR-0010) but Unit owns/tests it (GDD Rule 2a). O(1).
static func can_attack(unit: UnitState) -> bool:
	return not unit.has_attacked


## Resets [param unit]'s per-turn flags: [member UnitState.has_attacked] back
## to [code]false[/code] and [member UnitState.tiles_moved_this_turn] back to
## [code]0[/code]. Pure, per-instance — no [code]GameState[/code] or Turn
## Manager object required.
##
## Called only from [code]GameState.start_turn[/code]'s step 2 (ADR-0008),
## dispatched per active-player [UnitState] in [code]entity_id[/code]-ascending
## order. Same signature as the Sprint-1 stub it replaces — the call site
## needs zero change.
static func reset_turn_flags(unit: UnitState) -> void:
	unit.has_attacked = false
	unit.tiles_moved_this_turn = 0
	unit.stood_down = false # a stand-down lasts one turn, never longer.
	# ★ Abilities / transport (2026-09-28). Fortify lasts until its owner's next turn;
	# cooldowns tick once per owner-turn.
	unit.ability_used_this_turn = false
	unit.turn_ended = false
	unit.disembarked_this_turn = false
	unit.embarked_this_turn = false
	unit.fortify = 0
	for key: Variant in unit.cooldowns.keys():
		unit.cooldowns[key] = maxi(0, int(unit.cooldowns[key]) - 1)
	# Passengers are off the board, so start_turn's entity loop never reaches them.
	for passenger: UnitState in passengers(unit):
		reset_turn_flags(passenger)


## [param unit]'s AP cost per tile, including its pilot's crew bonus (TP-5d) and the cached
## Infiltrators discount, floored at [constant MIN_MOVE_COST] so nothing makes movement free
## (Dijkstra monotonicity, CR-3). ★ This — not [method effective_move_cost] — is what Movement
## actually bills; a per-tile effect that only touches effective_move_cost does nothing in play.
static func crewed_move_cost(unit: UnitState) -> int:
	var bonus: int = unit.pilot.type.crew_bonus_move_cost if unit.pilot != null else 0
	return maxi(MIN_MOVE_COST, unit.type.move_cost + bonus - unit.tech_move_cost_discount)


## Everyone riding in [param unit]: its pilot (if any) then its cargo, one level deep.
static func passengers(unit: UnitState) -> Array[UnitState]:
	var out: Array[UnitState] = []
	if unit.pilot != null:
		out.append(unit.pilot)
	out.append_array(unit.cargo)
	return out


## Everyone riding in [param unit] at any depth (a vehicle carried in a transport has a
## pilot too). Population and upkeep count these: a carried unit still exists (TP-1/TP-10).
static func all_carried(unit: UnitState) -> Array[UnitState]:
	var out: Array[UnitState] = []
	for p: UnitState in passengers(unit):
		out.append(p)
		out.append_array(all_carried(p))
	return out


## Whether [param unit] can act at all (TP-5): a vehicle that needs a pilot and has none
## cannot move, attack or use abilities. It still blocks its tile and can be destroyed.
static func is_functional(state: GameState, unit: UnitState) -> bool:
	return not needs_pilot(state, unit) or unit.pilot != null


## Whether [param unit] needs a pilot to act right now: its type does, and its owner has not
## researched a tech that frees that type (CR-11a — the Protectorate's Mech Autonomy).
static func needs_pilot(state: GameState, unit: UnitState) -> bool:
	return unit.type.requires_pilot and not Research.frees_pilot(state, unit.owner, unit.type)


## Passenger slots in use in [param unit] (TP-2). The pilot's seat is not a slot.
static func transport_load(unit: UnitState) -> int:
	var total: int = 0
	for c: UnitState in unit.cargo:
		total += c.type.transport_size
	return total


## Returns an independent deep copy of [param unit] via
## [method Resource.duplicate_deep] (ADR-0001/0007) — never a hand-written
## per-field copy. [member UnitState.type] stays a [b]shared reference[/b]
## ([code]===[/code]) across the clone (a path-having, [code]preload()[/code]d
## [UnitTypeDef] template); [member UnitState.current_hp],
## [member EntityState.position], [member UnitState.has_attacked], and
## [member UnitState.tiles_moved_this_turn] all deep-copy independently.
## Mirrors the same bare-no-arg [code]duplicate_deep()[/code] call
## [code]GameState.clone()[/code] uses.
##
## [b]Named [code]clone[/code], not [code]duplicate[/code][/b] (the GDD Rule 2a
## wording): a [code]class_name[/code] script is itself a [Resource], whose
## built-in [method Resource.duplicate] shadows any static [code]duplicate[/code]
## when called as [code]Unit.duplicate(...)[/code]. [code]clone[/code] also
## matches [method GameState.clone] — one deep-copy verb across the codebase.
static func clone(unit: UnitState) -> UnitState:
	return unit.duplicate_deep() as UnitState


## The sole mutator of [member UnitState.current_hp] (ADR-0007, TR-unit-005).
## Applies [param delta] (positive heal or negative damage) and clamps the
## result to [code]0 <= current_hp <= unit.type.hp[/code] — both the ceiling
## (named by the story's AC) and the floor (Combat depends on the [code]0[/code]
## clamp so hp never reads negative). Never assign
## [member UnitState.current_hp] directly outside this function.
static func apply_hp_delta(unit: UnitState, delta: int) -> void:
	unit.current_hp = clampi(unit.current_hp + delta, 0, effective_max_hp(unit))


## [param unit]'s maximum hp: its type's, plus its rank's bonus (promotion-veterancy.md PV-3).
## ★ The ONE place max hp is read for a unit — healing, repair, the AI and the HUD all use it,
## so a promoted unit is never healed back to its old ceiling.
static func effective_max_hp(unit: UnitState) -> int:
	return unit.type.hp + _rank_value(CombatBalance.combat.rank_hp, unit.rank) + unit.tech_hp_bonus


## Tiles [param unit] may move before the over-cap surcharge: its type's cap plus the cached
## tech bonus (Rapid Deployment, Blitz). ★ 2026-10-01: every surcharge read goes through here.
static func soft_move_cap(unit: UnitState) -> int:
	return unit.type.soft_move_cap + unit.tech_move_bonus


## The rank's bonus from [param table], clamped to the table (rank 0 = no bonus).
static func _rank_value(table: PackedInt32Array, rank: int) -> int:
	if table.is_empty():
		return 0
	return table[clampi(rank, 0, table.size() - 1)]


## The rank [param merit] earns under the threshold table (PV-2), 0..3.
static func rank_for_merit(merit: int) -> int:
	var t: PackedInt32Array = CombatBalance.combat.rank_thresholds
	var r: int = 0
	for i: int in t.size():
		if merit >= t[i]:
			r = i
	return r


## Moves [param unit] to [param new_rank], keeping current hp in step with max hp (PV-5: a
## promotion grants the new hp at once; a demotion clamps it to the lower ceiling).
static func set_rank(unit: UnitState, new_rank: int) -> void:
	var before: int = effective_max_hp(unit)
	unit.rank = new_rank
	var after: int = effective_max_hp(unit)
	unit.current_hp = clampi(unit.current_hp + maxi(0, after - before), 0, after)


## The attack value Combat uses (ADR-0010, TR-unit-006): [param unit]'s base attack
## plus the summed [member TechDef.attack_bonus] of every tech its owner has completed
## ([method Research.attack_bonus]). Computed [b]live[/b] every call — never baked — so
## an already-built unit reflects a tech completing mid-match (Rule 8).
static func effective_attack(state: GameState, unit: UnitState) -> int:
	# TP-5d: a trained pilot improves the vehicle it crews, only while it is aboard.
	var crew: int = unit.pilot.type.crew_bonus_attack if unit.pilot != null else 0
	var doctrine: int = Research.vehicle_attack_bonus(state, unit.owner) if unit.type.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE else 0
	# ★ 2026-10-01 (tech trees): Combined Arms reaches aircraft too; per-type bonuses (Technicals).
	if unit.type.unit_class == UnitTypeDef.UnitClass.AIR:
		doctrine += Research.sum(state, unit.owner, &"aircraft_attack_bonus")
	doctrine += Research.unit_type_bonus(state, unit.owner, unit.type, &"bonus_unit_attack")
	return unit.type.attack + Research.attack_bonus(state, unit.owner) + _rank_value(CombatBalance.combat.rank_attack, unit.rank) + crew + doctrine


## The defense value Combat's damage formula subtracts (ADR-0010's
## `defense(defender)` term): [param unit]'s base defense plus
## [method Research.defense_bonus] (Defense Tech, and Plating on top). Live, like
## [method effective_attack].
static func effective_defense(state: GameState, unit: UnitState) -> int:
	var doctrine: int = Research.vehicle_defense_bonus(state, unit.owner) if unit.type.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE else 0
	return unit.type.defense + Research.defense_bonus(state, unit.owner) + unit.fortify + doctrine


## The AP cost to produce a unit of [param unit_type] for [param player]
## (ADR-0012 §3's Faction-identity read-site, TR-unit-011): [param unit_type]'s
## base [member UnitTypeDef.produce_cost] plus [param player]'s faction's
## [member FactionUnitDelta.cost_delta] for that type (0 if the faction carries
## no entry for it — orphaned/absent is inert, [method Faction.unit_delta]),
## floored at [code]1[/code] so a subtractive delta can never reach a free or
## negative-cost verb (CR-3). Computed [b]live[/b] every call, never baked —
## same discipline as [method effective_attack]/[method effective_defense].
##
## Under [code]Factions.NEUTRAL[/code] (empty [member FactionDef.unit_deltas]),
## [code]d[/code] is always [code]null[/code], so this returns exactly
## [code]unit_type.produce_cost[/code] — the ADR-0012 §5 Neutral no-op
## regression pin. Combat stats ([code]attack[/code]/[code]defense[/code]/
## [code]attack_range[/code]) are [b]not[/b] read or folded here — they stay
## faction-identity-locked per ADR-0012 CR-6 (this story does not touch them).
static func effective_produce_cost(state: GameState, unit_type: UnitTypeDef, player: int) -> int:
	var d: FactionUnitDelta = Faction.unit_delta(state.faction_of(player), unit_type)
	var cost: int = unit_type.produce_cost + (d.cost_delta if d else 0)
	# ★ CR-14 Foundry: a percent off AFTER the faction delta, integer-floored — the
	# discount applies to what this player actually pays, not the catalogue price.
	cost = cost * (100 - Research.produce_cost_discount_pct(state, player)) / 100
	# ★ 2026-10-01 (tech trees): Levy en Masse — an infantry-only discount on top.
	if unit_type.unit_class == UnitTypeDef.UnitClass.INFANTRY:
		cost = cost * (100 - Research.sum(state, player, &"infantry_cost_discount_pct")) / 100
	return maxi(1, cost)


## The attack range [param entity] fires at (CR-14): its template range, plus
## [method Research.attack_range_bonus] for a UNIT that can already attack at range.
## Structures never get the bonus (research buffs units only, as for attack/defense),
## and a unit with range 0 — the Builder — stays at 0: Volley extends reach, it does
## not arm a unit that has no weapon.
##
## ★ The single read site for range. Combat's targeting, the AI's reach estimates and
## the HUD all go through here, so what the board highlights, what the AI plans for
## and what Combat accepts can never disagree.
## Whether a unit of [param unit_type] may enter or stop on terrain [param terrain]
## (unit-classes.md UC-2). Impassable stops everyone who walks or drives; Rough stops
## ground vehicles. Air may FLY OVER anything ([method Movement] handles that) but, like
## everyone, may not stop on Impassable ground — the grid never holds an occupant there.
static func can_stand_on(unit_type: UnitTypeDef, terrain: int) -> bool:
	if terrain == GridState.Terrain.IMPASSABLE:
		return false
	if terrain == GridState.Terrain.ROUGH and unit_type.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE:
		return false
	return true


## Whether Cover protects [param unit] (UC-2): infantry only. Vehicles and aircraft
## gain nothing from standing on a Cover tile.
static func benefits_from_cover(unit: UnitState) -> bool:
	return unit.type.unit_class == UnitTypeDef.UnitClass.INFANTRY


static func effective_attack_range(state: GameState, entity: EntityState) -> int:
	if entity is UnitState:
		var base: int = effective_type_attack_range(state, entity.type, entity.owner)
		# PV-3: a Champion's extra range, for a unit that attacks at all.
		return base + _rank_value(CombatBalance.combat.rank_range, entity.rank) if base > 0 else base
	# ★ 2026-10-01 (tech trees): armed structures get Point Defense range; the HQ gets a weapon
	# from Hardpoints. Unarmed structures stay at range 0.
	var r: int = entity.type.attack_range
	if entity.type.attack > 0:
		r += Research.sum(state, entity.owner, &"defensive_range_bonus")
	if entity is StructureState and (entity as StructureState).is_hq():
		r = maxi(r, Research.sum(state, entity.owner, &"hq_range"))
	return r


## [method effective_attack_range] for a unit TYPE [param player] would field — for
## callers reasoning about a unit that does not exist yet (the AI's deploy scoring).
static func effective_type_attack_range(state: GameState, unit_type: UnitTypeDef, player: int) -> int:
	if unit_type.attack_range > 0:
		var r: int = unit_type.attack_range + Research.attack_range_bonus(state, player)
		# ★ 2026-10-01 (tech trees): Long Guns — ground vehicles only.
		if unit_type.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE:
			r += Research.sum(state, player, &"vehicle_range_bonus")
		return r
	return unit_type.attack_range


## The AP cost to move [param unit_type] one tile for [param player]
## (ADR-0012 §3's Faction-identity read-site, TR-unit-011): [param unit_type]'s
## base [member UnitTypeDef.move_cost] plus [param player]'s faction's
## [member FactionUnitDelta.move_cost_delta] for that type (0 if absent/
## orphaned — [method Faction.unit_delta]), floored at [constant MIN_MOVE_COST]
## so a subtractive delta can never reach a free or negative move (CR-3, the
## conceptual floor Movement already enforced, now a named symbol here).
## Computed live every call, same discipline as the other [code]effective_*[/code]
## functions on this class.
##
## Under [code]Factions.NEUTRAL[/code] this returns exactly
## [code]unit_type.move_cost[/code] (Neutral no-op, ADR-0012 §5). Combat stats
## are not read or folded here — see [method effective_produce_cost]'s note.
static func effective_move_cost(state: GameState, unit_type: UnitTypeDef, player: int) -> int:
	var d: FactionUnitDelta = Faction.unit_delta(state.faction_of(player), unit_type)
	var cost: int = unit_type.move_cost + (d.move_cost_delta if d else 0)
	# ★ 2026-10-01 (tech trees): Infiltrators — infantry pay less per tile.
	if unit_type.unit_class == UnitTypeDef.UnitClass.INFANTRY:
		cost -= Research.sum(state, player, &"infantry_move_cost_discount")
	return maxi(MIN_MOVE_COST, cost)
