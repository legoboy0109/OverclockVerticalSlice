## CommandFSM — headless, pure state machine + contextual menu builder for the
## Command & Action Interface (ADR-0015 §1).
##
## Presentation-layer system per ADR-0015 (Command & Action Interface FSM).
## Mirrors the corpus's established pure-logic/driving-Node split
## ([AI]/[code]AITurnDriver[/code], ADR-0011): this class is the pure,
## headless, unit-testable-with-zero-mocks core; the future
## [code]CommandInterface[/code] [Node] (a later story) drives it, owns
## scene-tree input/render concerns, and holds the ephemeral
## per-preview recompute sets (Tier-1/Tier-2, ADR-0015 §3) — none of which
## belong here.
##
## [b]This story (Story 001) ships exactly two pure functions:[/b]
## [method next_state] (the State x Trigger transition table) and
## [method menu_model] (the CR-4 contextual action menu). Deliberately
## [b]out of scope[/b] here (see the story's Out of Scope section): the
## four-tier recompute timing (Story 002), live D-1/D-2/D-3 query wiring
## beyond what [method menu_model] itself needs (Story 003), the Cancel-Build
## hold gesture (Story 004 — [method menu_model] never emits a Cancel-Build
## [VerbEntry] in this story), [code]BoardCursor[/code] (Story 005), and the
## Node-side observation of [code]match_status[/code] (Story 008).
##
## [b]Pass-Through Invariant (TR-cmdui-010), structurally enforced:[/b]
## [method menu_model] reaches every cost/legality answer [b]only[/b] by
## calling an owning system's side-effect-free query
## ([code]Movement.reachable[/code], [code]Combat.legal_targets[/code],
## [code]Combat.attack_cost_for[/code], [code]AP.can_afford[/code],
## [code]BaseProduction.legal_deploy_tiles[/code]/
## [code]effective_production_cap[/code]/[code]defensive_attack_cost[/code],
## [code]Unit.effective_produce_cost[/code]) — this file holds zero literal
## references to any owning-system tuning-constant symbol by name anywhere in
## its source (no move-cost, soft-cap-penalty, per-attack AP price, cover
## reduction, or cancel-refund-rate constant, etc.). A grep-based lint test
## asserts this directly (the [code]test_command_fsm_source_never_references_balance_constants_by_name[/code]
## and [code]test_command_fsm_uses_only_public_query_calls_for_attack_cost[/code]
## functions in [code]tests/unit/command-action-interface/command_fsm_test.gd[/code]).
##
## Usage:
## [codeblock]
## var next: CommandFSM.State = CommandFSM.next_state(
##     CommandFSM.State.ENTITY_SELECTED, CommandFSM.Trigger.PICK_MOVE, state)
## var menu: Array[VerbEntry] = CommandFSM.menu_model(state, selected_unit)
## for entry: VerbEntry in menu:
##     if entry.enabled:
##         print("verb %d is available" % entry.verb)
## [/codeblock]
class_name CommandFSM
extends RefCounted


## The 7-state FSM (ADR-0015 §1/§2, TR-cmdui-001) — transcribed exactly from
## the ADR's worked signature. [constant GAME_OVER] is terminal/absorbing
## (see [method next_state]).
enum State { IDLE, ENTITY_SELECTED, PREVIEW_MOVE, PREVIEW_ATTACK, PREVIEW_PRODUCE, PREVIEW_BUILD, GAME_OVER }

## The 11 triggers the interface can feed into [method next_state]
## (ADR-0015 §1/§2), transcribed exactly from the ADR's worked signature.
enum Trigger { SELECT_OWN, SELECT_ENEMY_OR_EMPTY, PICK_MOVE, PICK_ATTACK, PICK_PRODUCE, PICK_BUILD_CMD,
		COMMIT, BACK_OUT, WAIT, END_TURN, OBSERVE_GAME_OVER }


## VerbEntry — one row of [method menu_model]'s returned contextual menu.
##
## Inner class of [CommandFSM]; not auto-registered as a global
## [code]class_name[/code] (GDScript inner-class limitation, mirroring
## [code]Movement.ReachableTile[/code]/[code]Combat.TargetResult[/code]'s
## established precedent) — external references (tests, the future
## [code]CommandInterface[/code] Node) use the [code]CommandFSM.VerbEntry[/code]
## prefix.
##
## [member reason] is a [b]bitmask[/b] of [enum Reason] flag values (powers of
## two), not a single code — [method menu_model] ORs every conjunct that
## failed into it, so a verb that is both out-of-range/no-targets AND
## unaffordable surfaces [b]both[/b] reasons in one field (AC-8, D-2's "when
## both conjuncts fail, both reasons are surfaced" requirement). A verb with
## [member enabled] == true always carries [constant Reason.NONE] (0).
class VerbEntry extends RefCounted:
	## Which verb this entry describes — a [enum Verb] value.
	var verb: int
	## True iff this verb is both legal AND affordable right now (D-2:
	## [code]is_legal AND can_afford[/code]) — never true with a non-[constant Reason.NONE]
	## [member reason].
	var enabled: bool
	## Bitmask (OR) of every [enum Reason] flag that made this verb
	## unavailable. [constant Reason.NONE] (0) iff [member enabled] is true.

	var reason: int

	func _init(v: int, e: bool, r: int) -> void:
		verb = v
		enabled = e
		reason = r


## The verbs [method menu_model] can emit an entry for. [constant Verb.CANCEL_BUILD]
## (Story 004) is the destructive-gesture verb for an under-construction owned
## structure — see [method _cancel_build_entry]. Deliberately excludes Build
## (CR-5: Build is a player-level command, never part of a selected entity's
## own menu).
enum Verb { MOVE, ATTACK, PRODUCE, WAIT, CANCEL_BUILD }

## Disablement reason flags (powers of two — see [member VerbEntry.reason]'s
## doc comment for why this is a bitmask, not a single code). Each flag names
## which owning-system conjunct failed; it never encodes a balance number
## itself (Pass-Through Invariant, ADR-0015 §4) — only *which* query returned
## false.
enum Reason {
	NONE = 0,
	OUT_OF_RANGE = 1,           ## Movement: reachable() is empty (no tile in range).
	INSUFFICIENT_AP = 2,        ## AP.can_afford() returned false.
	NO_TARGETS = 4,             ## Combat: legal_targets() is empty.
	ALREADY_ATTACKED = 8,       ## Unit.can_attack()/has_attacked gate failed.
	NOT_A_PRODUCER = 16,        ## Entity has no producible_types (not a producer).
	NOT_COMPLETED = 32,         ## Producer/attacker structure is still UNDER_CONSTRUCTION.
	PRODUCTION_CAP_REACHED = 64, ## BaseProduction.effective_production_cap() exhausted this turn.
	NO_DEPLOY_SPACE = 128,      ## BaseProduction.legal_deploy_tiles() is empty.
	NOT_UNDER_CONSTRUCTION = 256, ## Cancel Build: entity is not an owned, UNDER_CONSTRUCTION StructureState.
	INSUFFICIENT_CREDITS = 512,   ## Credits.can_afford() returned false — the Credit main cost of a dual-cost economic action (Build/Produce) is unaffordable (ADR-0006 pivot). INSUFFICIENT_AP covers the AP-surcharge leg.
	POPULATION_CAP_REACHED = 1024, ## Population.can_field() returned false — the army is at (or over) its population cap. Mirrors [constant Action.Reason.POPULATION_CAP_REACHED].
}


## PURE, TOTAL: the next [enum State] given [param current], [param trigger],
## and read-only [param state] (ADR-0015 §1/§2, TR-cmdui-001). Transcribes the
## GDD States table's base "To state" column directly — this function
## implements ONLY the entity-agnostic top-level transition, never the
## per-commit refinements the GDD's "Side effect" column also describes
## (e.g. "→ IDLE if the actor died / has no remaining legal action", "→ the
## newly-placed structure"): those require knowing [i]which[/i] entity is
## selected/acted, a concept [param state] alone does not carry (selection is
## the future [code]CommandInterface[/code] Node's [code]_selected_id[/code],
## per ADR-0015 §1) — they are AC-32/AC-33 (Integration-typed, Story 008's
## Post-Commit Re-Selection), explicitly out of this story's scope.
##
## [b]Totality convention:[/b] any [param current]/[param trigger] pair the
## GDD table does not list is an inert self-transition — returns
## [param current] unchanged. This is what makes the function total over the
## full 7 x 11 cross-product without inventing any transition the GDD never
## specified.
##
## [b][constant State.GAME_OVER] is absorbing[/b] (TR-cmdui-001): once
## [param current] is [constant State.GAME_OVER], every [param trigger]
## (including a repeated [constant Trigger.OBSERVE_GAME_OVER]) returns
## [constant State.GAME_OVER] — checked first, before any other branch, so no
## later table entry can ever re-open it.
##
## [b][constant Trigger.OBSERVE_GAME_OVER] is universal[/b] (ADR-0015 §2): from
## [i]any[/i] non-terminal state it transitions straight to
## [constant State.GAME_OVER] — the one trigger this story's pure function can
## fully express; [i]how[/i] a future [code]CommandInterface[/code] Node
## observes [code]match_status[/code] and decides to feed this trigger is
## Story 008's concern, not this function's.
##
## O(1) — a fixed small `match` dispatch, no query calls, no state mutation.
static func next_state(current: State, trigger: Trigger, _state: GameState) -> State:
	# GAME_OVER is absorbing — checked first, unconditionally.
	if current == State.GAME_OVER:
		return State.GAME_OVER

	# OBSERVE_GAME_OVER is universal from any non-terminal state.
	if trigger == Trigger.OBSERVE_GAME_OVER:
		return State.GAME_OVER

	match current:
		State.IDLE:
			match trigger:
				Trigger.SELECT_OWN:
					return State.ENTITY_SELECTED
				Trigger.SELECT_ENEMY_OR_EMPTY:
					return State.IDLE
				Trigger.PICK_BUILD_CMD:
					return State.PREVIEW_BUILD
				_:
					return current

		State.ENTITY_SELECTED:
			match trigger:
				Trigger.PICK_MOVE:
					return State.PREVIEW_MOVE
				Trigger.PICK_ATTACK:
					return State.PREVIEW_ATTACK
				Trigger.PICK_PRODUCE:
					return State.PREVIEW_PRODUCE
				Trigger.PICK_BUILD_CMD:
					return State.PREVIEW_BUILD
				Trigger.SELECT_OWN:
					return State.ENTITY_SELECTED # Switch selection (same top-level state).
				Trigger.SELECT_ENEMY_OR_EMPTY:
					return State.IDLE
				Trigger.WAIT:
					return State.IDLE
				Trigger.BACK_OUT:
					return State.IDLE
				Trigger.COMMIT:
					return State.ENTITY_SELECTED # Cancel-Build commit (Story 004) — base table target only.
				_:
					return current

		State.PREVIEW_MOVE, State.PREVIEW_ATTACK, State.PREVIEW_PRODUCE:
			match trigger:
				Trigger.COMMIT:
					return State.ENTITY_SELECTED
				Trigger.BACK_OUT:
					return State.ENTITY_SELECTED
				_:
					return current

		State.PREVIEW_BUILD:
			match trigger:
				Trigger.COMMIT:
					return State.ENTITY_SELECTED # Base target only — "or IDLE if no legal action" is Story 008.
				Trigger.BACK_OUT:
					return State.IDLE # Build has no source entity — backing out has nothing to return to.
				_:
					return current

		_:
			return current


## PURE: the CR-4 contextual action menu for [param entity], given
## [param state] (ADR-0015 §1, TR-cmdui-011..014). Reaches every cost/legality
## answer [b]only[/b] by calling an owning system's side-effect-free query —
## [code]Movement.reachable[/code], [code]Combat.legal_targets[/code],
## [code]AP.can_afford[/code], [code]Unit.can_attack[/code] (Unit-owned
## per-turn-flag read, not a balance constant),
## [code]BaseProduction.legal_deploy_tiles[/code]/
## [code]effective_production_cap[/code] — never a hardcoded balance constant
## (the structural enforcement of the Pass-Through Invariant, ADR-0015 §4).
##
## Returns exactly one [VerbEntry] per [enum Verb] value, always in
## [code]Verb[/code] declaration order (Move, Attack, Produce, Wait, Cancel
## Build) — [b]Wait is always present and always enabled[/b] (CR-4: "Wait
## (always — ends this entity's involvement without spending)"), satisfying
## AC-10's "Wait clickable" even for a fully-spent entity. [b]Cancel Build[/b]
## ([constant Verb.CANCEL_BUILD], Story 004) is enabled only for an owned,
## [constant StructureState.BuildStatus.UNDER_CONSTRUCTION] structure — see
## [method _cancel_build_entry] — disabled with [constant Reason.NOT_UNDER_CONSTRUCTION]
## for every unit and every Completed/non-owned structure.
##
## - [b]Move[/b] ([constant Verb.MOVE]): only meaningful for a [UnitState]
##   [param entity] (structures never move). Enabled iff
##   [code]Movement.reachable(state, entity)[/code] is non-empty AND at least
##   one returned tile is affordable via [code]AP.can_afford[/code] at its
##   [code]min_cost[/code]. Disabled reasons: [constant Reason.OUT_OF_RANGE]
##   if the reachable set is empty (AC-9's "no open tiles" case — the entity
##   is boxed in or has 0 AP to spend on any tile); [constant Reason.INSUFFICIENT_AP]
##   if the set is non-empty but every tile's cost exceeds current AP
##   (AC-9's "no affordable moves" case). A [StructureState] [param entity]
##   always yields Move disabled with [constant Reason.OUT_OF_RANGE]
##   (structures have no [code]reachable()[/code] concept).
## - [b]Attack[/b] ([constant Verb.ATTACK]): enabled iff the attacker can still
##   attack this turn ([code]Unit.can_attack[/code] for a [UnitState], or
##   [code]not entity.has_attacked[/code] plus
##   [constant StructureState.BuildStatus.COMPLETED] for a [StructureState]
##   Defensive Structure), [code]Combat.legal_targets(state, entity)[/code] is
##   non-empty, AND affordable via [code]AP.can_afford[/code] at the
##   attacker-kind-appropriate cost read via the public query
##   [code]Combat.attack_cost_for(entity)[/code] — never a locally-held
##   tuning constant. [b]AC-8[/b]: legality (targets present) and affordability are
##   evaluated as two independent conjuncts, and [b]both[/b] failing reasons —
##   [constant Reason.NO_TARGETS] and [constant Reason.INSUFFICIENT_AP] — are
##   OR'd into [member VerbEntry.reason] when both fail, never just one.
##   [constant Reason.ALREADY_ATTACKED] surfaces alone (AC-7) when the
##   attacker has already attacked this turn — that gate is checked first and
##   short-circuits the other two conjuncts (an already-spent attacker has no
##   meaningful "also out of range" reading to add, mirroring the GDD Edge
##   Cases: "disabled with reason 'already attacked,' regardless of remaining AP").
## - [b]Produce[/b] ([constant Verb.PRODUCE]): only meaningful for a
##   [StructureState] [param entity] with a non-empty
##   [code]type.producible_types[/code] (a producer). Disabled with
##   [constant Reason.NOT_A_PRODUCER] for any [UnitState] or non-producer
##   structure. For a producer: disabled with [constant Reason.NOT_COMPLETED]
##   if still [constant StructureState.BuildStatus.UNDER_CONSTRUCTION];
##   otherwise evaluated as three independent conjuncts — production-cap
##   remaining ([code]BaseProduction.effective_production_cap[/code], AC-10's
##   "production limit reached this turn" case →
##   [constant Reason.PRODUCTION_CAP_REACHED]), a non-empty
##   [code]BaseProduction.legal_deploy_tiles[/code] (AC-9/Edge Cases' "no
##   deploy space" case → [constant Reason.NO_DEPLOY_SPACE]), and
##   affordability of the cheapest producible unit type via
##   [code]AP.can_afford[/code] ([constant Reason.INSUFFICIENT_AP]) — every
##   failing conjunct is OR'd in, mirroring Attack's AC-8 multi-reason
##   discipline.
## - [b]Wait[/b] ([constant Verb.WAIT]): always [code]enabled = true[/code],
##   [code]reason = Reason.NONE[/code] — CR-4's "always" verb, never gated on
##   any query (AC-10).
##
## O(1) query-composition cost dominated by the owning systems' own published
## complexity ([code]Movement.reachable[/code] O(frontier size),
## [code]Combat.legal_targets[/code] O(4*attack_range) DIRECT,
## [code]BaseProduction.legal_deploy_tiles[/code] O(4)) — no additional scan
## of its own (control-manifest Performance Guardrail class).
static func menu_model(state: GameState, entity: EntityState) -> Array[VerbEntry]:
	var menu: Array[VerbEntry] = []
	menu.append(_move_entry(state, entity))
	menu.append(_attack_entry(state, entity))
	menu.append(_produce_entry(state, entity))
	menu.append(VerbEntry.new(Verb.WAIT, true, Reason.NONE))
	menu.append(_cancel_build_entry(state, entity))
	return menu


## Builds the Move [VerbEntry] — see [method menu_model]'s doc comment for the
## full rule. Isolated so each verb's rule is independently readable/testable
## without re-deriving the others.
static func _move_entry(state: GameState, entity: EntityState) -> VerbEntry:
	if not (entity is UnitState):
		return VerbEntry.new(Verb.MOVE, false, Reason.OUT_OF_RANGE)
	var unit: UnitState = entity

	var reachable: Array[Movement.ReachableTile] = Movement.reachable(state, unit)
	if reachable.is_empty():
		return VerbEntry.new(Verb.MOVE, false, Reason.OUT_OF_RANGE)

	for tile: Movement.ReachableTile in reachable:
		if AP.can_afford(state, unit.owner, tile.min_cost):
			return VerbEntry.new(Verb.MOVE, true, Reason.NONE)

	return VerbEntry.new(Verb.MOVE, false, Reason.INSUFFICIENT_AP)


## Builds the Attack [VerbEntry] — see [method menu_model]'s doc comment for
## the full rule, including AC-8's both-reasons requirement and AC-7's
## already-attacked short-circuit.
static func _attack_entry(state: GameState, entity: EntityState) -> VerbEntry:
	var can_still_attack: bool
	if entity is UnitState:
		can_still_attack = Unit.can_attack(entity)
	elif entity is StructureState:
		var structure: StructureState = entity
		if structure.build_status != StructureState.BuildStatus.COMPLETED:
			return VerbEntry.new(Verb.ATTACK, false, Reason.NOT_COMPLETED)
		can_still_attack = not structure.has_attacked
	else:
		return VerbEntry.new(Verb.ATTACK, false, Reason.ALREADY_ATTACKED)

	if not can_still_attack:
		return VerbEntry.new(Verb.ATTACK, false, Reason.ALREADY_ATTACKED)

	var has_targets: bool = not Combat.legal_targets(state, entity).is_empty()
	var cost: int = Combat.attack_cost_for(entity)
	var affordable: bool = AP.can_afford(state, entity.owner, cost)

	if has_targets and affordable:
		return VerbEntry.new(Verb.ATTACK, true, Reason.NONE)

	var reason: int = Reason.NONE
	if not has_targets:
		reason |= Reason.NO_TARGETS
	if not affordable:
		reason |= Reason.INSUFFICIENT_AP
	return VerbEntry.new(Verb.ATTACK, false, reason)


## Builds the Produce [VerbEntry] — see [method menu_model]'s doc comment for
## the full rule, including AC-10's cap-exhausted/no-deploy-tile cases.
static func _produce_entry(state: GameState, entity: EntityState) -> VerbEntry:
	if not (entity is StructureState):
		return VerbEntry.new(Verb.PRODUCE, false, Reason.NOT_A_PRODUCER)
	var producer: StructureState = entity
	if producer.type.producible_types.is_empty():
		return VerbEntry.new(Verb.PRODUCE, false, Reason.NOT_A_PRODUCER)
	if producer.build_status != StructureState.BuildStatus.COMPLETED:
		return VerbEntry.new(Verb.PRODUCE, false, Reason.NOT_COMPLETED)

	var reason: int = Reason.NONE

	var cap_remaining: bool = producer.units_produced_this_turn < BaseProduction.effective_production_cap(state, producer, producer.owner)
	if not cap_remaining:
		reason |= Reason.PRODUCTION_CAP_REACHED

	var deploy_tiles: Array[Vector2i] = BaseProduction.legal_deploy_tiles(state, producer, null)
	if deploy_tiles.is_empty():
		reason |= Reason.NO_DEPLOY_SPACE

	# ★ Population cap (S6-07, `population-cap.md` AC-12). The RULES already
	# enforced this -- BaseProduction.validate returns
	# Action.Reason.POPULATION_CAP_REACHED -- and the AI already respected it, but
	# this menu did not consult it, so a player at cap saw Produce ENABLED, chose a
	# unit, and had the commit rejected with no forewarning. The menu is the
	# affordance AC-12 is about; a rule enforced only at validation is a rule the
	# player discovers by failing.
	#
	# Checked against every producible type, not one: a cap that blocks Heavies may
	# still admit a Scout, and the menu must stay enabled while ANY unit is legal.
	var any_fieldable: bool = false
	for unit_type: UnitTypeDef in producer.type.producible_types:
		if Population.can_field(state, producer.owner, unit_type):
			any_fieldable = true
			break
	if not any_fieldable:
		reason |= Reason.POPULATION_CAP_REACHED

	# Dual-cost (ADR-0006 pivot): a unit is affordable iff BOTH its Credit main cost
	# AND the shared AP surcharge (produce_ap_cost) are payable.
	var ap_surcharge_affordable: bool = AP.can_afford(state, producer.owner, Balance.economy.produce_ap_cost)
	var cheapest_affordable: bool = false
	for unit_type: UnitTypeDef in producer.type.producible_types:
		var credit_cost: int = Unit.effective_produce_cost(state, unit_type, producer.owner)
		if ap_surcharge_affordable and Credits.can_afford(state, producer.owner, credit_cost):
			cheapest_affordable = true
			break
	if not cheapest_affordable:
		# Name the binding pool: the AP surcharge is per-action (identical for every
		# producible type), so if it's unaffordable that's the reason; otherwise no
		# type's Credit main cost fits.
		if not ap_surcharge_affordable:
			reason |= Reason.INSUFFICIENT_AP
		else:
			reason |= Reason.INSUFFICIENT_CREDITS

	if reason == Reason.NONE:
		return VerbEntry.new(Verb.PRODUCE, true, Reason.NONE)
	return VerbEntry.new(Verb.PRODUCE, false, reason)


## ProduceOption — one row of [method produce_options]' submenu: a single unit
## type a producer could deploy, with the dual cost of deploying it and whether
## it is available right now.
##
## Inner class of [CommandFSM] for the same reason [VerbEntry] is — external
## references use the [code]CommandFSM.ProduceOption[/code] prefix.
##
## [member reason] is the same [enum Reason] bitmask [VerbEntry] carries, and
## carries the same guarantee: [constant Reason.NONE] iff [member enabled].
## Costs are reported even on a DISABLED row — the price is exactly what the
## player needs in order to understand why the row is disabled, so hiding it
## would defeat the purpose (`design/ux/action-menu.md`, submenu wireframe).
class ProduceOption extends RefCounted:
	## The unit type this row deploys.
	var unit_type: UnitTypeDef
	## Credits the deployment would cost, from [method Unit.effective_produce_cost].
	var credit_cost: int
	## AP the deployment would cost — the flat per-action surcharge, identical for
	## every row (ADR-0006 dual-cost).
	var ap_cost: int
	## True iff this type is deployable right now: affordable in BOTH pools, under
	## the population cap, and with production cap and deploy space remaining.
	var enabled: bool
	## Bitmask (OR) of every [enum Reason] flag that made this row unavailable.
	var reason: int

	func _init(t: UnitTypeDef, cc: int, ac: int, e: bool, r: int) -> void:
		unit_type = t
		credit_cost = cc
		ap_cost = ac
		enabled = e
		reason = r


## PURE: the per-type submenu behind [constant Verb.PRODUCE] — one
## [ProduceOption] for every type [param entity] can produce, in the producer's
## own [member StructureTypeDef.producible_types] order.
##
## [b]Why this exists as a sibling of [method menu_model] rather than inside it.[/b]
## [method menu_model]'s Produce entry answers one question — "is producing
## anything possible right now" — by short-circuiting on the FIRST affordable,
## fieldable type. That is the right answer for a menu ROW, and the wrong answer
## for a menu the player is choosing FROM: it cannot say which types are the
## affordable ones. This walks every type instead and reports each independently,
## so the submenu can show a Scout enabled and a Heavy disabled-with-reason in the
## same list (`design/ux/action-menu.md` AC-13).
##
## [b]Returns an EMPTY array, never a null or an error[/b], for any [param entity]
## that is not a completed producer — the caller has already been told that by
## [method menu_model]'s Produce entry (NOT_A_PRODUCER / NOT_COMPLETED), and a
## submenu is never opened off a disabled row. Empty is the honest answer to "what
## can this thing make", not a failure.
##
## [b]Pass-Through Invariant (TR-cmdui-010)[/b] holds here exactly as it does in
## [method menu_model]: every cost and legality answer comes from an owning
## system's side-effect-free query ([method Unit.effective_produce_cost],
## [method Credits.can_afford], [method AP.can_afford],
## [method Population.can_field],
## [method BaseProduction.effective_production_cap],
## [method BaseProduction.legal_deploy_tiles]) — this function names no balance
## constant of its own.
##
## O(producible types), each with that type's own query cost.
static func produce_options(state: GameState, entity: EntityState) -> Array[ProduceOption]:
	var options: Array[ProduceOption] = []
	if not (entity is StructureState):
		return options
	var producer: StructureState = entity
	if producer.build_status != StructureState.BuildStatus.COMPLETED:
		return options

	# Producer-wide gates: these fail identically for every type, so they are
	# computed ONCE and OR-ed into every row rather than re-derived per type. A
	# player at production cap sees every row disabled for that reason, which is
	# true and is the explanation they need.
	var shared: int = Reason.NONE
	if producer.units_produced_this_turn >= BaseProduction.effective_production_cap(
			state, producer, producer.owner):
		shared |= Reason.PRODUCTION_CAP_REACHED
	if BaseProduction.legal_deploy_tiles(state, producer, null).is_empty():
		shared |= Reason.NO_DEPLOY_SPACE

	# The AP surcharge is per-ACTION, not per-type (ADR-0006), so it is also a
	# shared gate — but it is folded in per row below so each row's reason mask is
	# self-contained and readable on its own.
	var ap_cost: int = Balance.economy.produce_ap_cost
	var ap_affordable: bool = AP.can_afford(state, producer.owner, ap_cost)

	for unit_type: UnitTypeDef in producer.type.producible_types:
		var credit_cost: int = Unit.effective_produce_cost(state, unit_type, producer.owner)
		var reason: int = shared
		if not ap_affordable:
			reason |= Reason.INSUFFICIENT_AP
		if not Credits.can_afford(state, producer.owner, credit_cost):
			reason |= Reason.INSUFFICIENT_CREDITS
		if not Population.can_field(state, producer.owner, unit_type):
			reason |= Reason.POPULATION_CAP_REACHED
		options.append(ProduceOption.new(
			unit_type, credit_cost, ap_cost, reason == Reason.NONE, reason
		))
	return options


## BuildOption — one row of [method build_options]' player-level Build picker.
##
## The Build sibling of [ProduceOption], and deliberately a separate class rather
## than a shared "type option": Build belongs to the PLAYER (CR-5) and Produce
## belongs to a producer, they are gated by different queries, and collapsing them
## would mean one class whose fields are half-meaningless in each of its two uses.
class BuildOption extends RefCounted:
	## The structure type this row would place.
	var structure_type: StructureTypeDef
	## Credits the build would cost, from [method BaseProduction.effective_build_cost].
	var credit_cost: int
	## AP the build would cost — the flat per-action surcharge (ADR-0006 dual-cost).
	var ap_cost: int
	## True iff this type is placeable right now: affordable in BOTH pools with at
	## least one legal tile to put it on.
	var enabled: bool
	## Bitmask (OR) of every [enum Reason] flag that made this row unavailable.
	var reason: int

	func _init(t: StructureTypeDef, cc: int, ac: int, e: bool, r: int) -> void:
		structure_type = t
		credit_cost = cc
		ap_cost = ac
		enabled = e
		reason = r


## PURE: one [BuildOption] per type in [param types], for [param player], in the
## order given.
##
## [b]Player-level, not entity-level[/b] (CR-5): Build takes no selected entity,
## which is why it has no [VerbEntry] in [method menu_model] at all and why this
## takes a player index where [method produce_options] takes a producer. The HUD's
## persistent Build control is its entry point; this is the model behind that
## control's type picker.
##
## Reuses [constant Reason.NO_DEPLOY_SPACE] for "nowhere legal to put it" rather
## than adding a build-specific flag — the two mean the same thing to a player
## (there is no tile for this), and one flag with one phrase is one fewer thing for
## a translator and a reader to hold.
##
## Same Pass-Through discipline as its siblings: every answer comes from
## [method BaseProduction.effective_build_cost],
## [method BaseProduction.legal_build_tiles], [method Credits.can_afford] and
## [method AP.can_afford]. No balance constant is named here.
static func build_options(state: GameState, player: int, \
		types: Array[StructureTypeDef]) -> Array[BuildOption]:
	var options: Array[BuildOption] = []
	var ap_cost: int = Balance.economy.build_ap_cost
	var ap_affordable: bool = AP.can_afford(state, player, ap_cost)
	for type: StructureTypeDef in types:
		var credit_cost: int = BaseProduction.effective_build_cost(state, type, player)
		var reason: int = Reason.NONE
		if not ap_affordable:
			reason |= Reason.INSUFFICIENT_AP
		if not Credits.can_afford(state, player, credit_cost):
			reason |= Reason.INSUFFICIENT_CREDITS
		if BaseProduction.legal_build_tiles(state, player, type).is_empty():
			reason |= Reason.NO_DEPLOY_SPACE
		options.append(BuildOption.new(
			type, credit_cost, ap_cost, reason == Reason.NONE, reason
		))
	return options


## Builds the Cancel Build [VerbEntry] (Story 004, ADR-0015 §2) — see
## [method menu_model]'s doc comment for the full rule. Enabled iff
## [param entity] is a [StructureState] AND
## [member StructureState.build_status] is
## [constant StructureState.BuildStatus.UNDER_CONSTRUCTION] AND
## [member EntityState.owner] equals [member GameState.active_player] — a
## unit, a Completed structure, or an opponent's under-construction structure
## are all disabled with [constant Reason.NOT_UNDER_CONSTRUCTION] (a single
## reason, never a bitmask, since this verb has exactly one gating condition —
## unlike Attack/Produce's multi-conjunct rule).
static func _cancel_build_entry(state: GameState, entity: EntityState) -> VerbEntry:
	if not (entity is StructureState):
		return VerbEntry.new(Verb.CANCEL_BUILD, false, Reason.NOT_UNDER_CONSTRUCTION)
	var structure: StructureState = entity
	if structure.build_status != StructureState.BuildStatus.UNDER_CONSTRUCTION:
		return VerbEntry.new(Verb.CANCEL_BUILD, false, Reason.NOT_UNDER_CONSTRUCTION)
	if structure.owner != state.active_player:
		return VerbEntry.new(Verb.CANCEL_BUILD, false, Reason.NOT_UNDER_CONSTRUCTION)
	return VerbEntry.new(Verb.CANCEL_BUILD, true, Reason.NONE)


## PURE: the AP refund preview for cancelling [param structure] under
## [param state] (Story 004, ADR-0015 §2) — reaches the value [b]only[/b] via
## [method BaseProduction.cancel_refund] composed with
## [method BaseProduction.effective_build_cost] (Pass-Through Invariant,
## ADR-0015 §4): never a locally-held refund-rate constant and never a direct
## read of the structure type's own build-cost field. Under the VS's
## Neutral-only faction roster this equals the AP that will actually be
## credited on commit; the base-vs-effective divergence for a non-Neutral
## faction is deferred (mirrors the corpus's established BP-009 tech-debt
## pattern — [method BaseProduction.apply_cancel] itself still refunds off the
## structure's base cost, not the effective one).
##
## O(1) — two owning-system query calls, no scan of its own (control-manifest
## Performance Guardrail).
static func cancel_build_preview(state: GameState, structure: StructureState) -> int:
	var cost: int = BaseProduction.effective_build_cost(state, structure.type, structure.owner)
	return BaseProduction.cancel_refund(cost)


## PURE display derivation D-1 (ADR-0015 §1, TR-cmdui-014, AC-5): the AP
## [param player] would have left if a previewed action costing
## [param previewed_cost] committed right now. A literal one-line
## pass-through — [code]AP.current_ap(state, player) - previewed_cost[/code] —
## never a re-derivation of the cost itself (Pass-Through Invariant, ADR-0015
## §4). [b]Independence (AC-5) is structural, not enforced by any guard
## here[/b]: this function holds no field, cache, or running total across
## calls — each call reads [method AP.current_ap] fresh and subtracts exactly
## the one [param previewed_cost] passed in. A caller previewing a move
## (cost 6) then, independently, an attack (cost 2) against the same
## [code]current_ap == 9[/code] pool calls this twice —
## [code]projected_remaining_ap(state, player, 6) == 3[/code] and
## [code]projected_remaining_ap(state, player, 2) == 7[/code] — never
## [code]9 - 6 - 2 == 1[/code], because neither call's [param previewed_cost]
## ever includes the other preview's cost.
##
## May return a negative value when [param previewed_cost] exceeds
## [method AP.current_ap] (AC-24: a disabled-for-insufficient-AP action's
## internal projection may go negative — the UI never renders that raw
## negative, it shows "insufficient AP" instead, a rendering concern outside
## this pure function). O(1).
static func projected_remaining_ap(state: GameState, player: int, previewed_cost: int) -> int:
	return AP.current_ap(state, player) - previewed_cost


## BuildEntry — one structure type's Build-command preview row (AC-16,
## ADR-0015 §5 Base & Production bullet).
##
## Inner class of [CommandFSM]; not auto-registered as a global
## [code]class_name[/code] (mirrors [code]VerbEntry[/code]'s established
## inner-class precedent) — external references use the
## [code]CommandFSM.BuildEntry[/code] prefix.
##
## Unlike [VerbEntry]'s bitmask [member VerbEntry.reason] (which OR's
## multiple simultaneously-failing conjuncts for Attack/Produce), Build's
## gates are exposed as [b]independent[/b] booleans
## ([member insufficient_credits]/[member insufficient_ap]/[member no_legal_tile])
## — AC-16's "distinguishable" exclusion reasons, never combined into one flag; a
## caller checks each independently rather than unpacking a mask. The dual-cost
## pivot (ADR-0006) split the single affordability gate into the Credit main cost
## and the AP surcharge, so there are now three.
class BuildEntry extends RefCounted:
	## The structure type this row previews.
	var structure_type: StructureTypeDef
	## [method BaseProduction.effective_build_cost]'s live return — never a
	## locally-held [code]StructureTypeDef[/code] build-cost field read (Pass-Through
	## Invariant; the effective cost may faction-fold in a later epic).
	var build_cost: int
	## [method BaseProduction.effective_build_time]'s live return.
	var build_time: int
	## True iff BOTH the Credit main cost AND the AP surcharge are affordable
	## (dual-cost, ADR-0006 pivot) — the Build button is enabled only then.
	var affordable: bool
	## [method BaseProduction.legal_build_tiles]'s live result set for
	## [param player]/[member structure_type] — placement preview restricts to
	## exactly this set, never a locally re-derived adjacency/standoff rule.
	var legal_tiles: Array[Vector2i]
	## True iff the Credit main cost ([member build_cost]) is unaffordable — a
	## distinguishable exclusion reason (the ADR-0006 pivot's dual-cost Credit leg).
	var insufficient_credits: bool
	## True iff the AP surcharge (build_ap_cost) is unaffordable — a distinguishable
	## exclusion reason. Independent of [member insufficient_credits].
	var insufficient_ap: bool
	## True iff [member legal_tiles] is empty — a distinguishable exclusion reason,
	## independent of the two affordability reasons (any combination may be true
	## simultaneously — an unaffordable structure with no legal tile either).
	var no_legal_tile: bool

	func _init(type: StructureTypeDef, cost: int, time: int, tiles: Array[Vector2i], credits_afford: bool, ap_afford: bool) -> void:
		structure_type = type
		build_cost = cost
		build_time = time
		legal_tiles = tiles
		affordable = credits_afford and ap_afford
		insufficient_credits = not credits_afford
		insufficient_ap = not ap_afford
		no_legal_tile = tiles.is_empty()


## PURE: the AC-16 Build-command preview row for [param structure_type] and
## [param player] (ADR-0015 §5 Base & Production bullet, TR-cmdui-013). Reaches
## every value [b]only[/b] via [BaseProduction]/[AP]'s side-effect-free
## queries — [method BaseProduction.effective_build_cost],
## [method BaseProduction.effective_build_time],
## [method BaseProduction.legal_build_tiles], and the dual-cost affordability pair
## [method Credits.can_afford] (Credit main cost) + [method AP.can_afford] (AP
## surcharge) — never a locally-held balance constant (Pass-Through Invariant,
## ADR-0015 §4). Build
## is a player-level command (CR-5) with no source entity, so — unlike
## [method menu_model] — this takes [param player] directly, never an
## [EntityState].
##
## O(1) plus one [method BaseProduction.legal_build_tiles] call (already
## budgeted O(friendly_count * 4 * enemy_structure_count), control-manifest
## Performance Guardrail) — safe to call once per structure type shown in the
## Build picker.
static func build_preview(state: GameState, player: int, structure_type: StructureTypeDef) -> BuildEntry:
	var cost: int = BaseProduction.effective_build_cost(state, structure_type, player)
	var time: int = BaseProduction.effective_build_time(state, structure_type, player)
	var tiles: Array[Vector2i] = BaseProduction.legal_build_tiles(state, player, structure_type)
	# Dual-cost (ADR-0006 pivot): affordable iff BOTH the Credit main cost (build_cost)
	# AND the AP surcharge (build_ap_cost) are payable; both are surfaced separately so
	# the picker can name the binding pool.
	var credits_afford: bool = Credits.can_afford(state, player, cost)
	var ap_afford: bool = AP.can_afford(state, player, Balance.economy.build_ap_cost)
	return BuildEntry.new(structure_type, cost, time, tiles, credits_afford, ap_afford)
