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
	if _is_excluded(state, player, tech):
		return Action.Reason.TECH_EXCLUDED
	for prereq: TechDef in tech.prerequisites:
		if not has_tech(state, player, prereq):
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
	for tech: TechDef in Techs.ALL:
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
		var evt := TechCompletedEvent.new()
		evt.owner = player
		evt.tech = tech
		events.append(evt)
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
static func apply_idle_healing(state: GameState, player: int) -> Array:
	var amount: int = idle_heal(state, player)
	if amount <= 0:
		return []
	var events: Array = []
	for e: EntityState in state.entities():
		if not (e is UnitState) or e.owner != player:
			continue
		var unit: UnitState = e
		if unit.has_attacked or unit.tiles_moved_this_turn > 0 or unit.current_hp >= Unit.effective_max_hp(unit):
			continue
		var before: int = unit.current_hp
		Unit.apply_hp_delta(unit, amount)
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
	for other: TechDef in Techs.ALL:
		if other == tech or other.exclusive_group != tech.exclusive_group:
			continue
		if has_tech(state, player, other) or is_under_research(state, player, other):
			return true
	return false


static func _owns_completed(state: GameState, player: int, structure_type: StructureTypeDef) -> bool:
	for e: EntityState in state.entities():
		if e is StructureState and e.owner == player and e.type == structure_type \
				and e.build_status == StructureState.BuildStatus.COMPLETED:
			return true
	return false
