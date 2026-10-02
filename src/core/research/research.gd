## Research — the Research / Tech system (ADR-0018 as amended by CR-14, 2026-09-28).
##
## Static-only, like every Core system: pure queries plus validate/apply pairs that
## [method GameState.apply_action] dispatches (ADR-0002). No static mutable state —
## everything lives on [GameState], so a [method GameState.clone] is a complete
## research snapshot for AI look-ahead.
##
## [b]CR-14 shape (user decisions, 2026-09-28):[/b]
## [br]• Research runs at the HQ (any structure type with [code]can_research[/code]),
##   ONE tech at a time. The Research Lab no longer researches — it is a GATE that
##   tier-2 techs list in [member TechDef.required_structures].
## [br]• Losing the Lab keeps completed techs and does not cancel research already in
##   progress; it only blocks STARTING new tier-2 research.
## [br]• Tier-2 techs come in "pick one" pairs ([member TechDef.exclusive_group]), and
##   the choice is permanent for the match. Cancelling a branch before it completes
##   frees the pair again — only completion (or being mid-research) commits.
## [br]• Every tech is dual-cost, Credits + AP, both-or-neither (ADR-0006).
## [br]• [member TechDef.allowed_factions] is a live faction gate with no shipped user.
##
## [b]Effects are summed data.[/b] [method attack_bonus] and friends fold every
## completed tech's field, read live at the call site (Rule 8) — a unit built after a
## tech completes has the bonus, and nothing is ever baked into an entity. The one
## exception is [member TechDef.economy_tier_bonus], written once into
## [member PlayerState.economy_tier] on completion because the income formula
## ([method Credits.credit_income_breakdown]) already reads that field.
class_name Research
extends RefCounted


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## [param player]'s researcher: the first COMPLETED structure they own whose type
## [code]can_research[/code], in stable id order — or [code]null[/code] (no HQ).
static func researcher(state: GameState, player: int) -> StructureState:
	for e: EntityState in state.entities():
		if e is StructureState and e.owner == player and e.type.can_research \
				and e.build_status == StructureState.BuildStatus.COMPLETED:
			return e
	return null


## Whether [param player] has completed [param tech].
static func has_tech(state: GameState, player: int, tech: TechDef) -> bool:
	return tech in state.per_player[player].completed_techs


## Whether [param player] has [param tech] OR a faction swap that replaces it (2026-10-01).
static func has_tech_or_swap(state: GameState, player: int, tech: TechDef) -> bool:
	if has_tech(state, player, tech):
		return true
	for t: TechDef in state.per_player[player].completed_techs:
		if tech in t.replaces:
			return true
	return false


## Whether [param tech] is in progress at any structure [param player] owns.
static func is_under_research(state: GameState, player: int, tech: TechDef) -> bool:
	for e: EntityState in state.entities():
		if e is StructureState and e.owner == player and e.research_target == tech:
			return true
	return false


## Whether [param player] may start [param tech] as far as the TREE is concerned —
## [constant Action.Reason.OK] or the first failing gate. Deliberately ignores the
## researcher's own state and affordability: those change turn to turn, while these
## gates describe the tree. [method validate_research] layers the rest on top, and
## the research picker uses this to say WHY a tech is locked.
##
## Gate order is the order a player would fix them in: done already, not for your
## faction, branch closed, missing parent, missing Lab.
static func availability(state: GameState, player: int, tech: TechDef) -> int:
	if has_tech(state, player, tech):
		return Action.Reason.ALREADY_RESEARCHED
	if is_under_research(state, player, tech):
		return Action.Reason.RESEARCH_IN_PROGRESS
	if not tech.allowed_factions.is_empty() and not (state.faction_of(player) in tech.allowed_factions):
		return Action.Reason.TECH_FACTION_RESTRICTED
	# D6: a tech outside the player's own tree is not theirs to research.
	if not (tech in Faction.techs(state, player)):
		return Action.Reason.TECH_FACTION_RESTRICTED
	if _is_excluded(state, player, tech):
		return Action.Reason.TECH_EXCLUDED
	for prereq: TechDef in tech.prerequisites:
		if not has_tech_or_swap(state, player, prereq):
			return Action.Reason.PREREQUISITE_MISSING
	for structure_type: StructureTypeDef in tech.required_structures:
		if not _owns_completed(state, player, structure_type):
			return Action.Reason.REQUIRES_STRUCTURE
	return Action.Reason.OK


## Every tech [param player] could start right now tree-wise, in [code]Techs.ALL[/code]
## order (ADR-0018 D4, reshaped by CR-14 to take a player rather than a Lab).
## Affordability and a busy researcher are NOT filtered — callers that care check
## [method validate_research].
static func legal_research_targets(state: GameState, player: int) -> Array[TechDef]:
	var out: Array[TechDef] = []
	for tech: TechDef in Faction.techs(state, player):   # D6: the player's own tree
		if availability(state, player, tech) == Action.Reason.OK:
			out.append(tech)
	return out


## Credits to start [param tech]. Faction folding (ADR-0012) is not implemented for
## techs yet; this is the single site it would go in.
static func effective_research_cost(_state: GameState, tech: TechDef, _player: int) -> int:
	return tech.research_cost


## Owner-turns [param tech] takes to complete.
static func effective_research_time(_state: GameState, tech: TechDef, _player: int) -> int:
	return tech.research_time


## AP to start [param tech]: its own [member TechDef.ap_surcharge], or the base
## ★ 2026-10-01 (tech trees): recomputes the tech-derived bonuses cached on [param player]'s units
## and structures ([member UnitState.tech_hp_bonus] etc). A RAISED max hp also raises current hp
## by the same amount (a tech grants its hp at once, like a promotion — PV-5); a lowered one
## clamps. Called at the start of the owner's turn (after production, so new units are covered)
## and on every research completion.
static func refresh_bonuses(state: GameState, player: int) -> void:
	for e: EntityState in state.entities():
		if e.owner != player:
			continue
		if e is UnitState:
			_refresh_unit(state, e as UnitState)
			for c: UnitState in Unit.all_carried(e as UnitState):
				_refresh_unit(state, c)
		elif e is StructureState:
			var st: StructureState = e
			if st.type == null:
				continue
			var before: int = Structure.effective_max_hp(st)
			var hp: int = st.type.hp * sum(state, player, &"structure_hp_pct") / 100
			if st.is_hq():
				hp += sum(state, player, &"hq_hp_bonus")
			st.tech_hp_bonus = hp
			var after: int = Structure.effective_max_hp(st)
			st.current_hp = clampi(st.current_hp + maxi(0, after - before), 0, after)


static func _refresh_unit(state: GameState, u: UnitState) -> void:
	if u.type == null:
		return
	var p: int = u.owner
	var cls: int = u.type.unit_class
	var before: int = Unit.effective_max_hp(u)
	var hp: int = 0
	if cls == UnitTypeDef.UnitClass.INFANTRY:
		hp += sum(state, p, &"infantry_hp_bonus")
	elif cls == UnitTypeDef.UnitClass.GROUND_VEHICLE:
		hp += sum(state, p, &"vehicle_hp_bonus")
	u.tech_hp_bonus = hp
	var after: int = Unit.effective_max_hp(u)
	u.current_hp = clampi(u.current_hp + maxi(0, after - before), 0, after)
	var mv: int = sum(state, p, &"move_cap_bonus") + unit_type_bonus(state, p, u.type, &"bonus_unit_move_cap")
	if cls != UnitTypeDef.UnitClass.INFANTRY:
		mv += sum(state, p, &"vehicle_move_cap_bonus")
	u.tech_move_bonus = mv
	u.tech_move_cost_discount = sum(state, p, &"infantry_move_cost_discount") \
		if cls == UnitTypeDef.UnitClass.INFANTRY else 0
	u.tech_ammo_bonus = sum(state, p, &"ammo_bonus")
	u.tech_attack_ap_discount = sum(state, p, &"attack_ap_discount")


## ★ 2026-10-01 (tech trees): the summed value of int effect [param field] over [param player]'s
## completed techs — the one accessor every new tree effect reads through, so a new field needs
## no new function here. 0 for an out-of-range player (fixtures with no PlayerState).
static func sum(state: GameState, player: int, field: StringName) -> int:
	if state == null or player < 0 or player >= state.per_player.size():
		return 0
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += int(t.get(field))
	return total


## True when any of [param player]'s completed techs sets bool effect [param field].
static func any(state: GameState, player: int, field: StringName) -> bool:
	if state == null or player < 0 or player >= state.per_player.size():
		return false
	for t: TechDef in state.per_player[player].completed_techs:
		if bool(t.get(field)):
			return true
	return false


## Summed per-unit-type bonus [param field] (bonus_unit_attack / bonus_unit_move_cap) that
## applies to [param type] through [member TechDef.bonus_unit_types].
static func unit_type_bonus(state: GameState, player: int, type: UnitTypeDef, field: StringName) -> int:
	if state == null or player < 0 or player >= state.per_player.size() or type == null:
		return 0
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		if type in t.bonus_unit_types:
			total += int(t.get(field))
	return total

## [member EconomyConfig.research_ap_cost] when it leaves that at -1 (ADR-0018 D5).
static func effective_research_ap_surcharge(_state: GameState, tech: TechDef, _player: int) -> int:
	return tech.ap_surcharge if tech.ap_surcharge >= 0 else Balance.economy.research_ap_cost


# ---------------------------------------------------------------------------
# Effect folds — summed over completed techs, read live (Rule 8)
# ---------------------------------------------------------------------------

static func attack_bonus(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.attack_bonus
	return total


## Summed ground-vehicle-only bonuses (Doctrine); folded by [Unit] for ground vehicles only.
static func vehicle_attack_bonus(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.vehicle_attack_bonus
	return total


static func vehicle_defense_bonus(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.vehicle_defense_bonus
	return total


static func defense_bonus(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.defense_bonus
	return total


static func attack_range_bonus(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.attack_range_bonus
	return total


static func ignores_cover(state: GameState, player: int) -> bool:
	for t: TechDef in state.per_player[player].completed_techs:
		if t.ignores_cover:
			return true
	return false


static func idle_heal(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.idle_heal
	return total


## Whether [param player] has researched a tech that frees [param type] from needing a pilot.
static func frees_pilot(state: GameState, player: int, type: UnitTypeDef) -> bool:
	for t: TechDef in state.per_player[player].completed_techs:
		if type in t.frees_pilots:
			return true
	return false


static func produce_ap_discount(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.produce_ap_discount
	return total


static func build_ap_discount(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.build_ap_discount
	return total


## Summed percent, clamped to [0, 100] so stacked discounts can never go negative.
static func produce_cost_discount_pct(state: GameState, player: int) -> int:
	var total: int = 0
	for t: TechDef in state.per_player[player].completed_techs:
		total += t.produce_cost_discount_pct
	return clampi(total, 0, 100)


# ---------------------------------------------------------------------------
# Verbs — dispatched by GameState.apply_action
# ---------------------------------------------------------------------------

static func validate_research(state: GameState, action: ResearchAction) -> int:
	var entity: EntityState = state.entities_by_id.get(action.researcher_id, null)
	if entity == null or not (entity is StructureState):
		return Action.Reason.NO_SUCH_ENTITY
	var lab: StructureState = entity
	var player: int = state.active_player
	if lab.owner != player or not lab.type.can_research or action.tech == null:
		return Action.Reason.ILLEGAL_TARGET
	if lab.build_status != StructureState.BuildStatus.COMPLETED:
		return Action.Reason.NOT_COMPLETED
	if lab.research_target != null:
		return Action.Reason.RESEARCH_IN_PROGRESS
	var gate: int = availability(state, player, action.tech)
	if gate != Action.Reason.OK:
		return gate
	# Deficit before affordability, same as produce/build: it names the real cause.
	if state.per_player[player].in_deficit:
		return Action.Reason.IN_DEFICIT
	if not Credits.can_afford(state, player, effective_research_cost(state, action.tech, player)):
		return Action.Reason.CANT_AFFORD_CREDITS
	if not AP.can_afford(state, player, effective_research_ap_surcharge(state, action.tech, player)):
		return Action.Reason.CANT_AFFORD
	return Action.Reason.OK


static func apply_research(state: GameState, action: ResearchAction) -> Array[Event]:
	if validate_research(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var lab: StructureState = state.entities_by_id[action.researcher_id]
	# Dual-cost spend, both-or-neither (validate re-checked BOTH pools above).
	Credits.spend(state, player, effective_research_cost(state, action.tech, player))
	AP.spend(state, player, effective_research_ap_surcharge(state, action.tech, player))
	lab.research_target = action.tech
	lab.research_turns_remaining = effective_research_time(state, action.tech, player)
	lab.stood_down = false # acting clears a stand-down, as for every other verb

	var evt := ResearchStartedEvent.new()
	evt.entity_id = lab.entity_id
	evt.owner = player
	evt.tech = action.tech
	evt.turns_remaining = lab.research_turns_remaining
	return [evt] as Array[Event]


static func validate_cancel_research(state: GameState, action: CancelResearchAction) -> int:
	var entity: EntityState = state.entities_by_id.get(action.researcher_id, null)
	if entity == null or not (entity is StructureState):
		return Action.Reason.NO_SUCH_ENTITY
	if entity.owner != state.active_player:
		return Action.Reason.ILLEGAL_TARGET
	if (entity as StructureState).research_target == null:
		return Action.Reason.NOTHING_IN_RESEARCH
	return Action.Reason.OK


## Refunds [code]floor(research_cost × cancel_refund_pct / 100)[/code] Credits — the
## same fraction a cancelled build refunds (Rule 7, ADR-0017 reuse). The AP surcharge
## is tempo already spent and is never refunded.
static func apply_cancel_research(state: GameState, action: CancelResearchAction) -> Array[Event]:
	if validate_cancel_research(state, action) != Action.Reason.OK:
		return []
	var player: int = state.active_player
	var lab: StructureState = state.entities_by_id[action.researcher_id]
	var tech: TechDef = lab.research_target
	var refund: int = cancel_refund(state, tech, player)
	Credits.credit(state, player, refund)
	lab.research_target = null
	lab.research_turns_remaining = 0

	var evt := ResearchCancelledEvent.new()
	evt.entity_id = lab.entity_id
	evt.owner = player
	evt.tech = tech
	evt.refund = refund
	return [evt] as Array[Event]


## What cancelling [param tech] would refund — exposed so the UI can quote it.
static func cancel_refund(state: GameState, tech: TechDef, player: int) -> int:
	return effective_research_cost(state, tech, player) * StructureBalance.base_production.cancel_refund_pct / 100


# ---------------------------------------------------------------------------
# Start-of-turn — sequenced by GameState.start_turn
# ---------------------------------------------------------------------------

## [method GameState.start_turn] step 3 (ADR-0008): ticks [param player]'s research
## and completes anything reaching 0. The SOLE writer of
## [member PlayerState.completed_techs]. Runs before the step-4 income snapshot, so an
## economy tech pays out the very turn it completes.
static func advance_research_timers(state: GameState, player: int) -> Array:
	var events: Array = []
	for e: EntityState in state.entities():
		if not (e is StructureState) or e.owner != player:
			continue
		var lab: StructureState = e
		if lab.research_target == null:
			continue
		lab.research_turns_remaining -= 1
		if lab.research_turns_remaining > 0:
			continue
		var tech: TechDef = lab.research_target
		var ps: PlayerState = state.per_player[player]
		ps.completed_techs.append(tech)
		if tech.economy_tier_bonus != 0:
			ps.economy_tier = clampi(ps.economy_tier + tech.economy_tier_bonus, 0, Balance.economy.max_economy_tier)
		lab.research_target = null
		lab.research_turns_remaining = 0
		if not tech.frees_pilots.is_empty():
			events.append_array(_eject_freed_pilots(state, player, tech))
		var evt := TechCompletedEvent.new()
		evt.owner = player
		evt.tech = tech
		events.append(evt)
	refresh_bonuses(state, player)   # a completed tech applies to every unit at once
	return events


## Field Repair: restores [method idle_heal] HP to each of [param player]'s damaged
## units that neither moved nor attacked on [param player]'s previous turn.
##
## ⚠ [b]Must run BEFORE [method GameState.start_turn]'s step-2 flag reset[/b] — the
## "did it act last turn?" answer lives in [member UnitState.has_attacked] and
## [member UnitState.tiles_moved_this_turn], which step 2 zeroes. Those flags are only
## ever written during their owner's own turn, so at this point they describe exactly
## the previous owner-turn. A unit deployed at this same start-of-turn does not exist
## yet (step 3), so it cannot be healed before it has had a turn to be idle in.
## CR-11a: once a type no longer needs a pilot, the pilot aboard each such unit climbs out onto
## the first free adjacent tile (N, E, S, W). With nowhere to stand it stays aboard — still a
## passenger, still counted — rather than vanishing.
static func _eject_freed_pilots(state: GameState, player: int, tech: TechDef) -> Array:
	var events: Array = []
	for e: EntityState in state.entities():
		if not (e is UnitState) or e.owner != player:
			continue
		var v: UnitState = e
		if v.pilot == null or not (v.type in tech.frees_pilots):
			continue
		for d: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var t: Vector2i = v.position + d
			if state.grid.in_bounds(t.x, t.y) and state.grid.is_passable(t.x, t.y) \
					and Unit.can_stand_on(v.pilot.type, state.grid.terrain_at(t.x, t.y)):
				var p: UnitState = v.pilot
				v.pilot = null
				p.position = t
				state.entities_by_id[p.entity_id] = p
				state.grid.place(p.entity_id, t.x, t.y)
				var d_evt := UnitDisembarkedEvent.new()
				d_evt.unit_id = p.entity_id
				d_evt.vehicle_id = v.entity_id
				d_evt.tile = t
				events.append(d_evt)
				break
	return events


static func apply_idle_healing(state: GameState, player: int) -> Array:
	var amount: int = idle_heal(state, player)
	# ★ 2026-10-01 (tech trees): Self-Repair Protocols — ground vehicles heal even after acting.
	var self_repair: int = sum(state, player, &"vehicle_self_repair")
	# Dig In (reworked 2026-10-01): units Cover protects heal while standing in it. Was +2 defence
	# in Cover, which did nothing on its own path — Hardened Armor + Plating + Cover already floor
	# infantry hits at min_damage.
	var cover_heal: int = sum(state, player, &"cover_heal")
	if amount <= 0 and self_repair <= 0 and cover_heal <= 0 and sum(state, player, &"bonus_unit_self_repair") <= 0:
		return []
	var events: Array = []
	for e: EntityState in state.entities():
		if not (e is UnitState) or e.owner != player:
			continue
		var unit: UnitState = e
		if unit.current_hp >= Unit.effective_max_hp(unit):
			continue
		var idle: bool = not unit.has_attacked and unit.tiles_moved_this_turn == 0
		var gain: int = (amount if idle else 0)
		if unit.type.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE:
			gain += self_repair
		gain += unit_type_bonus(state, player, unit.type, &"bonus_unit_self_repair")   # Drone Maintenance
		if cover_heal > 0 and Unit.benefits_from_cover(unit) \
				and state.grid.is_cover(unit.position.x, unit.position.y):
			gain += cover_heal
		if gain <= 0:
			continue
		var before: int = unit.current_hp
		Unit.apply_hp_delta(unit, gain)
		var evt := UnitHealedEvent.new()
		evt.entity_id = unit.entity_id
		evt.amount = unit.current_hp - before
		events.append(evt)
	return events


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _is_excluded(state: GameState, player: int, tech: TechDef) -> bool:
	if tech.exclusive_group == &"":
		return false
	for other: TechDef in Faction.techs(state, player):
		if other == tech or other.exclusive_group != tech.exclusive_group:
			continue
		if has_tech(state, player, other) or is_under_research(state, player, other):
			return true
	return false


static func _owns_completed(state: GameState, player: int, structure_type: StructureTypeDef) -> bool:
	for e: EntityState in state.entities():
		if e is StructureState and e.owner == player \
				and (e.type == structure_type or structure_type in e.type.counts_as) \
				and e.build_status == StructureState.BuildStatus.COMPLETED:
			return true
	return false
