## Promotion — merit and rank (design/gdd/promotion-veterancy.md).
##
## General machinery gated per faction ([member FactionDef.promotes]); in the current design
## only the Holy Cosmic Empire opts in (PV-8), so for every shipped faction this is inert.
##
## ★ Ordering (PV-6), stated once so no caller diverges: compute all damage → apply all deaths
## → award all merit → apply all rank changes. Callers award merit AFTER their deaths, then
## call [method apply_rank] — never mid-resolution, which would break damage-types.md DT-9.
class_name Promotion
extends RefCounted


## Whether [param unit]'s owner's faction promotes at all.
static func promotes(state: GameState, unit: UnitState) -> bool:
	var f: FactionDef = state.faction_of(unit.owner)
	return f != null and f.promotes


## Credits [param unit] with merit for having hit [param victim] (PV-1): a kill, a destroyed
## structure, or a hit that did not kill. Friendly fire earns nothing. Call after deaths.
static func award_hit(state: GameState, unit: EntityState, victim: EntityState) -> void:
	if not (unit is UnitState) or victim.owner == unit.owner or not promotes(state, unit):
		return
	var cfg: CombatConfig = CombatBalance.combat
	if victim.current_hp > 0:
		unit.merit += cfg.merit_per_hit
	elif victim is StructureState:
		unit.merit += cfg.merit_per_structure
	else:
		unit.merit += cfg.merit_per_kill


## Applies whatever rank [param unit]'s merit now earns (PV-6), capped at the table. A
## faction whose ranks need support cannot promote while it has none (PV-7).
static func apply_rank(state: GameState, unit: EntityState) -> void:
	if not (unit is UnitState) or not promotes(state, unit) or unit.current_hp <= 0:
		return
	if not _supported(state, unit.owner):
		return
	var earned: int = Unit.rank_for_merit(unit.merit)
	if earned > unit.rank:
		Unit.set_rank(unit, earned)


## Start-of-turn PV-7: a faction whose ranks need support, with no COMPLETED support structure
## standing, drops every unit one rank (merit kept). With support, ranks return to what merit
## earns — recovery is real rather than punitive.
static func start_of_turn(state: GameState, player: int) -> void:
	var f: FactionDef = state.faction_of(player)
	if f == null or not f.promotes or not f.rank_requires_support:
		return
	var supported: bool = _supported(state, player)
	for e: EntityState in state.entities():
		if not (e is UnitState) or e.owner != player:
			continue
		var u: UnitState = e
		if supported:
			Unit.set_rank(u, Unit.rank_for_merit(u.merit))
		elif u.rank > 0:
			Unit.set_rank(u, u.rank - 1)


static func _supported(state: GameState, player: int) -> bool:
	var f: FactionDef = state.faction_of(player)
	if f == null or not f.rank_requires_support:
		return true
	for e: EntityState in state.entities():
		if e is StructureState and e.owner == player \
				and e.build_status == StructureState.BuildStatus.COMPLETED \
				and e.type in f.rank_support_structures:
			return true
	return false
