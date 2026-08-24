## Upkeep — the Credit drain that bounds the banked economy (S6-02).
##
## Static utility class. Turns Credit income from a [i]gross[/i] faucet into a
## [i]net[/i] one: every completed, living, non-HQ entity charges its owner
## [member UnitTypeDef.upkeep] / [member StructureTypeDef.upkeep] Credits at that
## owner's start-of-turn economy step.
##
## [b]★ Why this system exists — measured, not speculative.[/b] The vertical slice
## returned a [b]PIVOT[/b] verdict: Credits peaked at 5,724 on one side and were
## still climbing linearly at turn 200, economy actions outscored manoeuvring by
## 12-20x, and no match ever resolved. [b]The game had faucets and no drains.[/b]
## This is the drain.
##
## [b]It is one HALF of the bound, and neither half works alone:[/b]
## [br]• [b]Rate[/b] — a finite three-tier research spine caps income at 2,500
##   ([method Credits.credit_income]). A hard ceiling, not an asymptote.
## [br]• [b]Stock[/b] — this system. A hard income ceiling with no drain still
##   accumulates, just linearly at a fixed rate, which is exactly what the
##   simulation measured.
##
## Reads [code]Balance.economy[/code] ([EconomyConfig]) for its constants — never
## threaded through call sites.
##
## Usage:
## [codeblock]
## var drain: int = Upkeep.total_upkeep(state, 0)
## var net: int = Upkeep.net_credit_income(state, 0)
## Upkeep.apply_turn_economy(state, 0)   # start-of-turn: bank net, set the deficit flag
## [/codeblock]
class_name Upkeep
extends RefCounted


## The Credits [param player] is charged this turn, summed over every entity that
## actually pays (UR-3/UR-4/UR-5):
## [br]• alive, and
## [br]• for a structure, [code]build_status == COMPLETED[/code] — one under
##   construction pays nothing, because [member StructureTypeDef.build_time] is
##   already a deliberate vulnerable-investment window and charging during it would
##   double-tax the same design intent, and
## [br]• not the HQ, which is the sole exemption (UR-4 — it cannot be given up, so
##   charging for it is a flat tax on existing rather than a decision).
##
## ★ [b]A unit produced this turn is not charged this turn, and that needs no flag.[/b]
## The charge happens once at the owner's start of turn, before they act, so anything
## they produce afterwards is first charged at their [i]next[/i] start of turn. UR-3's
## "pays from the turn after it was produced" falls straight out of the ordering.
##
## Pure and side-effect free. O(n) over entities.
static func total_upkeep(state: GameState, player: int) -> int:
	var total: int = 0
	for e: EntityState in state.entities():
		if e.owner != player:
			continue
		if e is UnitState:
			var u: UnitState = e as UnitState
			# A null type is invalid state, not a chargeable entity. Contributing 0 keeps
			# this function TOTAL over every entity the map can hold — including the bare
			# EntityState that start_turn's step 2 is explicitly required to skip safely.
			# Charging for something with no definition is not a meaningful alternative,
			# and crashing the whole economy step over one malformed entity is worse.
			if u.type == null:
				continue
			total += u.type.upkeep
		elif e is StructureState:
			var st: StructureState = e as StructureState
			if st.type == null:
				continue
			if st.build_status != StructureState.BuildStatus.COMPLETED:
				continue
			total += st.type.upkeep
	return total


## [param player]'s [b]net[/b] Credit income: gross income minus total upkeep.
## May be negative — that is the deficit case, and UR-6 handles it by draining the
## bank rather than by recording a debt.
static func net_credit_income(state: GameState, player: int) -> int:
	return Credits.credit_income(state, player) - total_upkeep(state, player)


## The start-of-turn economy step (replaces the pre-S6-02 bare
## [method Credits.add_income] call in [method GameState.start_turn] step 4b).
##
## Banks [method net_credit_income] onto [param player]'s running balance, floors that
## balance at 0, and sets [member PlayerState.in_deficit].
##
## [b]Deficit (UR-6):[/b] when upkeep exceeds income the shortfall is drawn from the
## bank. The bank [b]floors at 0 and never goes negative[/b], and no debt is recorded
## anywhere — a hidden negative balance is exactly the kind of invisible state that
## makes an economy unreadable. A player whose balance would have gone negative is
## flagged [member PlayerState.in_deficit], which locks produce/build/research
## (checked at those call sites) while leaving move, attack and disband available.
##
## ★ [b]There is deliberately NO attrition and no forced disband.[/b] A death spiral
## is not a comeback mechanism, it is the opposite of one, and creating comeback
## pressure is most of why this system exists. A player in deficit is locked out of
## expanding until they lose units or take ground, both of which resolve it naturally.
##
## Runs once per player per turn. O(n) via [method total_upkeep].
static func apply_turn_economy(state: GameState, player: int) -> void:
	var ps: PlayerState = state.per_player[player]
	var balance: int = ps.current_credits + net_credit_income(state, player)
	ps.in_deficit = balance < 0
	ps.current_credits = maxi(0, balance)


## The derived-upkeep convention (UR-1), exposed so tooling and tests can check that
## authored values follow it. [b]Not[/b] called at runtime — shipped entities carry
## authored values, so a designer may deviate deliberately.
##
## ★ The granularity term is load-bearing rather than cosmetic — see
## [member EconomyConfig.upkeep_granularity] for why a bare `ceil(cost / divisor)`
## silently drifts low after the ×100 Credit rescale.
static func default_upkeep(produce_cost: int) -> int:
	var cfg: EconomyConfig = Balance.economy
	var step: int = maxi(1, cfg.upkeep_granularity)
	var divisor: int = maxi(1, cfg.upkeep_divisor)
	return int(ceil(float(produce_cost) / float(divisor * step))) * step


## [DisbandAction]'s [code]validate()[/code] handler (UR-7). Rejects anything that is
## not [param action.player]'s own living [UnitState] — a structure, the HQ, an enemy
## unit and a missing id all fail — and rejects if the AP cost is unaffordable.
##
## ★ It does [b]not[/b] check [member PlayerState.in_deficit]: disband is the one
## action that reduces upkeep, so a player in deficit must be able to use it.
static func validate_disband(state: GameState, action: DisbandAction) -> int:
	var player: int = action.player
	if player != state.active_player:
		return Action.Reason.NOT_ACTIVE_PLAYER
	if not state.entities_by_id.has(action.entity_id):
		return Action.Reason.NO_SUCH_ENTITY
	var e: EntityState = state.entities_by_id[action.entity_id]
	if not (e is UnitState) or e.owner != player:
		return Action.Reason.NOT_OWN_UNIT
	if not AP.can_afford(state, player, Balance.economy.disband_ap_cost):
		return Action.Reason.CANT_AFFORD
	return Action.Reason.OK


## [DisbandAction]'s [code]apply()[/code] handler. Spends the AP, destroys the unit
## through [method GameState.destroy_entity] (so the destroyed event flows out exactly
## as a combat death does, and the renderer's death beat plays), then credits the
## refund.
##
## Ordering is deliberate: AP first (so a failed spend cannot destroy anything), then
## the destroy, then the refund — the refund is credited AFTER the unit is gone so the
## upkeep it was charging is unambiguously ended.
static func apply_disband(state: GameState, action: DisbandAction) -> Array:
	var player: int = action.player
	var unit: UnitState = state.entities_by_id[action.entity_id] as UnitState
	var refund: int = disband_refund(unit.type)
	AP.spend(state, player, Balance.economy.disband_ap_cost)
	var events: Array = state.destroy_entity(action.entity_id)
	Credits.credit(state, player, refund)
	return events


## Credits refunded when [param unit_type] is disbanded (UR-7), floored at 0.
## [member EconomyConfig.disband_refund_pct] is a rate, so it is unaffected by the
## ×100 Credit rescale.
static func disband_refund(unit_type: UnitTypeDef) -> int:
	var cfg: EconomyConfig = Balance.economy
	return maxi(0, int(floor(float(unit_type.produce_cost) * float(cfg.disband_refund_pct) / 100.0)))
