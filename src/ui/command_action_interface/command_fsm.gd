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


## The verbs [method menu_model] can emit an entry for. Deliberately excludes
## Cancel Build (Story 004's scope — see this file's class doc comment) and
## Build (CR-5: Build is a player-level command, never part of a selected
## entity's own menu).
enum Verb { MOVE, ATTACK, PRODUCE, WAIT }

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
## [code]Verb[/code] declaration order (Move, Attack, Produce, Wait) —
## [b]Wait is always present and always enabled[/b] (CR-4: "Wait (always —
## ends this entity's involvement without spending)"), satisfying AC-10's
## "Wait clickable" even for a fully-spent entity. [b]Cancel Build is
## deliberately never emitted here[/b] (Story 004's scope, see this file's
## class doc comment) — an under-construction structure selected in this
## story surfaces only its AP-verb-disabled-with-reason + Wait-enabled rows,
## same as any other entity with no legal AP-costed action (AC-10).
## Cancel Build: Story 004 extension point.
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

	var cheapest_affordable: bool = false
	for unit_type: UnitTypeDef in producer.type.producible_types:
		if AP.can_afford(state, producer.owner, Unit.effective_produce_cost(state, unit_type, producer.owner)):
			cheapest_affordable = true
			break
	if not cheapest_affordable:
		reason |= Reason.INSUFFICIENT_AP

	if reason == Reason.NONE:
		return VerbEntry.new(Verb.PRODUCE, true, Reason.NONE)
	return VerbEntry.new(Verb.PRODUCE, false, reason)
