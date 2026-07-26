## GameState — the single authoritative match state.
##
## Foundation-layer data model per ADR-0001. Holds the grid, all entities, and
## all per-player state in one place, decoupled from the scene tree. Extends
## [Resource] (never [Node]), constructed only via [code].new()[/code] at
## runtime — never loaded from disk — so it is headless-instantiable,
## headless-queryable (TR-gamestate-002), and clones for free via
## [method clone] (TR-gamestate-003). Every field carries [code]@export[/code]
## so no field is silently dropped by [code]duplicate_deep()[/code]
## (storage-usage requirement, ADR-0001).
##
## There is no Autoload holding authority over an instance of this class — the
## authoritative instance is created by a match-bootstrap script and passed by
## reference (DI). [code]MatchService[/code] (see [code]match_service.gd[/code])
## is a thin, logic-free lookup pointer only; unit tests and the AI construct
## or receive a [GameState] directly and never touch it.
##
## Story 001 shipped the data model, the side-effect-free read API, and
## [method clone]. Story 002 (this story) adds [method apply_action], the
## [signal action_applied] signal, and the verb-dispatch/registration
## mechanism — with only [EndTurnAction]'s handlers concretely wired.
## [code]start_match[/code]/[code]start_turn[/code]/the real end-of-turn
## sequence are Story 003; win-check logic is Story 004
## ([method run_win_check] is a no-op stub here).
##
## Usage:
## [codeblock]
## var state := GameState.new()
## state.grid = GridState.new()
## state.per_player = [PlayerState.new(), PlayerState.new()]
##
## var clone := state.clone()
## clone.per_player[0].current_ap = 5 # does not affect state.per_player[0]
##
## var action := EndTurnAction.new()
## action.player = state.active_player
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name GameState
extends Resource

## Match terminal status. [code]IN_PROGRESS[/code] is the default; later
## stories (Story 004) transition to [code]GAME_OVER[/code] via win-check.
enum MatchStatus { IN_PROGRESS, GAME_OVER }

## Signal fired exactly once, synchronously, at the very end of
## [method apply_action]'s pipeline — [b]only[/b] when [code]result.ok ==
## true[/code] (ADR-0004). A rejected action is a true no-op by the
## validate-before-mutate atomicity guarantee, so nothing is emitted for it.
## Subscribers (HUD, Board Renderer) must never mutate state from inside their
## handler.
signal action_applied(result: ActionResult)

## Verb-keyed dispatch tables, [code]Dictionary[int, Callable][/code], shared
## by every [GameState] instance — dispatch is pure code-behavior, not
## per-match data, so it deliberately lives on the class, never as an
## [code]@export[/code]ed instance field (it must never be walked by
## [method clone]'s [code]duplicate_deep()[/code]). Built once and reused
## across every call (control-manifest Performance Guardrail); never
## dispatched via [code]get_class()[/code] (ADR-0002 — for a GDScript class
## that returns the base engine class name, not its [code]class_name[/code]).
static var _validators: Dictionary = {}
static var _appliers: Dictionary = {}
static var _dispatch_registered: bool = false

## The authoritative logical board. Owned inside this state, decoupled from
## any render node (ADR-0001, TR-grid-005/-006).
@export var grid: GridState

## Per-player state, indexed by player number (0, 1, ...).
@export var per_player: Array[PlayerState] = []

## int entity_id -> [EntityState]. The single source of truth for every
## entity's data; the grid's [code]occupancy[/code] stores only the matching
## [code]entity_id[/code] int, never an [EntityState] reference (ADR-0005).
@export var entities_by_id: Dictionary = {}

## Next [code]entity_id[/code] to assign. Incremented whenever
## [code]apply_action[/code] creates an entity (Story 002+). Being a plain
## field, it is automatically included in every [method clone].
@export var next_entity_id: int = 0

## Index into [member per_player] identifying whose turn it currently is.
@export var active_player: int = 0

## The current round number. Starts at 1.
@export var round_number: int = 1

## The match's terminal status. See [enum MatchStatus].
@export var match_status: int = MatchStatus.IN_PROGRESS

## The player who moved first this match, set exactly once by [method
## start_match] and never mutated afterward (ADR-0008). [method
## _apply_end_turn] compares an incoming [code]next_player[/code] against
## this field to decide whether control has looped back to the starting
## player — the signal [member round_number] increments on.
@export var starting_player: int = 0


## Returns [param player]'s AP available to spend this turn. O(1) array index.
func current_ap(player: int) -> int:
	return per_player[player].current_ap


## Returns every entity in this state, sorted ascending by [member EntityState.entity_id]
## for stable iteration (ADR-0003 forbids relying on Dictionary hash/insertion
## order). O(n log n) per call — re-sorted every call, not cached; this is the
## only non-constant read on this class (see class doc comment's Read-API
## complexity note in the governing story). Returns [code][][/code] for an
## empty state.
func entities() -> Array[EntityState]:
	var result: Array[EntityState] = []
	for entity: EntityState in entities_by_id.values():
		result.append(entity)
	result.sort_custom(func(a: EntityState, b: EntityState) -> bool: return a.entity_id < b.entity_id)
	return result


## Returns the [EntityState] occupying [param tile], or [code]null[/code] if
## the tile is empty or unoccupied. Resolves via [code]grid.occupant_at(tile)[/code]
## (O(1)) then an [code]entities_by_id[/code] Dictionary lookup (O(1)) = O(1)
## total. Never stores an [EntityState] reference in the grid itself (ADR-0005).
func entity_at(tile: Vector2i) -> EntityState:
	var entity_id: int = grid.occupant_at(tile.x, tile.y)
	if entity_id == GridState.EMPTY_OCCUPANT:
		return null
	return entities_by_id.get(entity_id)


## Returns [param player]'s [FactionDef]. O(1) array index. May be
## [code]null[/code] before Setup assigns a faction.
func faction_of(player: int) -> FactionDef:
	return per_player[player].faction


## Returns a fully independent deep copy of this state — the single most
## important operation in the project (ADR-0001 Validation Criteria). One
## call, no hand-written per-field copy: every [code]@export[/code]-flagged
## field (including [member grid], every [PlayerState] in [member per_player],
## and every [EntityState] in [member entities_by_id]) is recursively
## deep-copied by [method Resource.duplicate_deep]. Mutating the clone never
## affects the original, and vice versa.
func clone() -> GameState:
	return duplicate_deep() as GameState


## The canonical start-of-turn sequence (ADR-0008, TR-gamestate-007) — a
## [GameState]-owned instance method, called in exactly two places: once by
## [method start_match] for the starting player, and once per turn by
## [method _apply_end_turn] for the next player. Runs these 4 steps in this
## exact order, never reordered:
## [br]1. Set [member active_player] to [param player].
## [br]2. Reset per-turn flags for [param player]'s entities, in stable
## [member entity_id]-ascending order ([method entities]) — dispatched to
## the owning system's forward-declared contract
## ([code]Unit.reset_turn_flags[/code] / [code]Structure.reset_turn_flags[/code]),
## never inlined here (control-manifest forbidden pattern: [GameState] owns
## only the timing, not flag semantics).
## [br]3. Advance build and research timers for [param player]
## ([code]BaseProduction.advance_build_timers[/code] then
## [code]Research.advance_research_timers[/code]) — the two calls are
## commutative (order between them must never affect the result); both
## fully complete before step 4 runs.
## [br]4. Snapshot [param player]'s AP income for the turn
## ([code]AP.reset_turn[/code]) — deliberately last, so a structure/tech
## completed this same turn in step 3 is already reflected in the income
## this snapshot freezes (never reorder step 4 before step 3).
##
## Returns every [Event] step 3 appended (completions), in the order they
## happened — flows through the existing [signal action_applied] once the
## caller ([method _apply_end_turn] via [method apply_action], or
## [method start_match]) finishes. No new signal or polling path.
##
## O(entity count): one filtered pass over [method entities] (dominated by
## its stable-order sort) plus two per-system O(entity count) passes and one
## O(1) AP snapshot — runs once per player per turn, never per-frame/per-action.
##
## Usage:
## [codeblock]
## var events: Array = state.start_turn(1) # begin player 1's turn
## for e in events:
##     if e is StructureCompletedEvent:
##         pass # a structure finished building as this turn began
## [/codeblock]
func start_turn(player: int) -> Array:
	# 1. Set active player.
	active_player = player

	# 2. Reset per-turn flags for this player's entities, stable id order.
	for e: EntityState in entities():
		if e.owner != player:
			continue
		if e is UnitState:
			Unit.reset_turn_flags(e)
		elif e is StructureState:
			Structure.reset_turn_flags(e)

	# 3. Advance build + research timers (commutative order; both before step 4).
	var events: Array = []
	events.append_array(BaseProduction.advance_build_timers(self, player))
	events.append_array(Research.advance_research_timers(self, player))

	# 4. AP income snapshot — after step 3, so same-turn completions count.
	AP.reset_turn(self, player)

	return events


## Constructs a brand-new match [GameState] from [param map] (ADR-0001/0005
## grid construction) and runs the Setup->PlayerTurn(starting) transition
## (ADR-0008, ADR-0012): builds the grid, places both HQs as entities with
## real [member next_entity_id]-allocated ids, sets [member starting_player]
## (immutable after this call), initializes [member round_number] to 1 and
## [member match_status] to [constant MatchStatus.IN_PROGRESS], then runs
## [method start_turn] exactly once for [param starting_player] — the first
## start-of-turn, which deliberately does [b]not[/b] increment
## [member round_number] (only [method _apply_end_turn]'s loop-back check does).
##
## [b]HQ entity id allocation (Grid epic Story 003/004 carry-forward "W2"):[/b]
## [method MapDefinition.build_grid] places the two HQs into
## [member GridState.occupancy] using placeholder ids [code]0[/code]/[code]1[/code]
## (documented in its own doc comment as provisional, pending a caller that
## drives real entity allocation). This method is that caller: since
## [member next_entity_id] always starts at [code]0[/code] on a freshly
## constructed [GameState], allocating the two HQ [EntityState]s from
## [member next_entity_id] here yields ids [code]0[/code] and [code]1[/code]
## in [member hq_tiles] order — exactly matching what [method build_grid]
## already wrote into occupancy — with zero risk of collision against any
## later-created entity, because every subsequent allocator call reads the
## already-incremented [member next_entity_id]. No structure/unit type
## schema exists yet (ADR-0007 lands later), so each HQ is constructed as a
## plain [EntityState] — sufficient for grid occupancy/read-API identity;
## it deliberately does not participate in [method start_turn]'s step-2
## [code]is UnitState[/code]/[code]is StructureState[/code] dispatch.
##
## O(width*height) dominated by [method MapDefinition.build_grid], plus
## [method start_turn]'s cost — a one-time, load-time construction, never a
## per-frame or per-action path.
##
## Usage:
## [codeblock]
## var state: GameState = GameState.start_match(map_def, 0) # player 0 moves first
## # state.active_player == 0, state.round_number == 1,
## # state.match_status == GameState.MatchStatus.IN_PROGRESS,
## # state.per_player[0].current_ap == AP.income(state, 0)
## [/codeblock]
static func start_match(map: MapDefinition, starting_player: int) -> GameState:
	var state := GameState.new()

	state.grid = MapDefinition.build_grid(map)

	state.per_player = [PlayerState.new(), PlayerState.new()]

	# Place both HQs as entities, ids allocated from next_entity_id — lands
	# on 0/1 (matching build_grid's already-placed occupancy ids) because
	# next_entity_id starts at 0 on a fresh GameState. hq_tiles[i] belongs to
	# player i (mirroring MapDefinition.build_grid's own placement order).
	for player: int in map.hq_tiles.size():
		var hq := EntityState.new()
		hq.entity_id = state.next_entity_id
		hq.owner = player
		hq.position = map.hq_tiles[player]
		state.entities_by_id[hq.entity_id] = hq
		state.next_entity_id += 1

	state.starting_player = starting_player
	state.round_number = 1
	state.match_status = MatchStatus.IN_PROGRESS

	state.start_turn(starting_player) # First start-of-turn; no round increment.

	return state


## Registers [param verb]'s [code]validate[/code]/[code]apply[/code] handlers
## into the shared, class-level dispatch tables — the mechanism other Core
## epics (Movement, Combat, Base & Production, Research) use to plug their
## verb into [method apply_action] when those systems land (out of scope for
## this story; only [constant Action.Verb.END_TURN] is registered here).
##
## Idempotent by design: registering the same [param verb] again simply
## overwrites its table entry (last-write-wins), so re-registration is always
## safe — a test may re-register a verb between runs with no accumulation and
## no need to "unregister" first. Registration is a one-time, load-time
## concern (control-manifest guardrail: never rebuild the table itself inside
## the [method apply_action] hot path); overwriting an entry is O(1) and
## carries no cost even if called repeatedly.
##
## Usage:
## [codeblock]
## GameState.register_verb(Action.Verb.MOVE, Movement.validate, Movement.apply)
## [/codeblock]
static func register_verb(verb: int, validator: Callable, applier: Callable) -> void:
	_validators[verb] = validator
	_appliers[verb] = applier


## Removes [param verb]'s handlers from the shared dispatch tables entirely
## (unlike [method register_verb]'s overwrite, this fully clears the key so
## [code]_validators.has(verb)[/code] becomes [code]false[/code] again). No-op
## if the verb was never registered. Primarily a test-hygiene tool: a test that
## registers a throwaway verb into the process-wide static tables must call this
## in cleanup to avoid leaving a stub that a later test (or a real Core epic's
## first test suite) could silently inherit under load-order variation.
static func unregister_verb(verb: int) -> void:
	_validators.erase(verb)
	_appliers.erase(verb)


## Populates the shared dispatch tables exactly once per process (guarded by
## [member _dispatch_registered], not per-[GameState]-instance state) with
## this story's only concrete handler pair: [constant Action.Verb.END_TURN].
## Safe to call every time [method apply_action] runs — the guard makes every
## call after the first a single boolean check, never a per-call Dictionary
## rebuild (control-manifest Performance Guardrail).
static func _ensure_dispatch_registered() -> void:
	if _dispatch_registered:
		return
	register_verb(Action.Verb.END_TURN, _validate_end_turn, _apply_end_turn)
	_dispatch_registered = true


## [EndTurnAction]'s [code]validate()[/code] handler (owning system: this
## class — there is no dedicated TurnManager class, per the control
## manifest's forbidden patterns). Unconditionally OK for the active
## player — [method apply_action]'s step 2 active-player gate already
## enforces the "active player only" half; this handler adds no further
## affordability/legality check (TR-gamestate-017, ADR-0002). Pure — reads
## nothing, mutates nothing.
static func _validate_end_turn(_state: GameState, _action: Action) -> int:
	return Action.Reason.OK


## [EndTurnAction]'s [code]apply()[/code] handler (ADR-0008). Runs, in
## order: (1) discard the outgoing (currently-active) player's unspent AP —
## no banking; (2) determine the next player via strict 2-player alternation
## ([code]1 - outgoing[/code] — out of scope for any future N-player mode,
## see ADR-0008 Risks); (3) increment [member round_number] [b]only[/b] if
## [param next_player] equals [member starting_player] (control has looped
## back to whoever moved first this match); (4) run [method start_turn] for
## [param next_player] and return its events.
##
## Deliberately implemented here (a private static handler on [GameState]),
## not as a method on [EndTurnAction] itself — ADR-0002 forbids embedding
## [code]validate()[/code]/[code]apply()[/code] directly on an [Action]
## subclass (the command-pattern the control manifest explicitly bans), and
## the control manifest separately forbids a standalone [code]TurnManager[/code]
## utility class. [GameState] is the correct owner: it already owns
## [method apply_action]/[method start_turn]/[method clone]/[method start_match]
## directly, so turn-orchestration living here matches that existing
## precedent rather than inventing a second home for it.
##
## Assumes validation already passed ([method _validate_end_turn] is
## unconditionally OK for the active player) — never fails.
static func _apply_end_turn(state: GameState, _action: Action) -> Array:
	var outgoing: int = state.active_player
	AP.discard(state, outgoing)
	var next_player: int = 1 - outgoing # 2-player VS: strict alternation.
	if next_player == state.starting_player:
		state.round_number += 1 # Control looped back to the starting player.
	return state.start_turn(next_player)


## [b]Cross-story seam (flag for Story 003 / ADR-0008):[/b] whether
## [member PlayerState.faction]/[member PlayerState.is_ai_controlled] have
## left Setup and become immutable (ADR-0001, ADR-0012 — "same lock as
## [code]is_ai_controlled[/code]", ADR-0011). [code]MatchStatus[/code]
## (ADR-0001) has only [code]IN_PROGRESS[/code]/[code]GAME_OVER[/code] — there
## is no persisted [code]SETUP[/code] value, and this story adds none: ADR-0012
## explicitly places the Setup FSM and the Setup→PlayerTurn transition with
## "Turn Manager / [code]start_match()[/code]" (Story 003's territory), not
## here. No concrete faction-assignment [Action] verb exists yet in this
## story's scope, so there is nothing in [method apply_action]'s dispatch
## table to gate today.
##
## This method is the enforceable seam a future faction-assignment verb's
## [code]validate()[/code] handler calls. Until Story 003 actually models a
## pre-[code]start_match()[/code] Setup phase, every [GameState] this story
## can construct or hand to [method apply_action] is — by construction —
## already past that boundary, so this always returns [code]true[/code].
## [b]Story 003 must revisit this[/b] once [code]start_match()[/code] and a
## real Setup phase exist, and should replace the unconditional [code]true[/code]
## with an actual phase check.
func is_faction_locked() -> bool:
	return true


## Pure query a future faction-(re)assignment verb's [code]validate()[/code]
## would call: is assigning [param player]'s faction/[code]is_ai_controlled[/code]
## still legal? Returns [constant Action.Reason.OK] pre-lock,
## [constant Action.Reason.FACTION_LOCKED] once [method is_faction_locked] is
## [code]true[/code]. See [method is_faction_locked]'s doc comment for the
## Story 003 seam note — [param player] is accepted (matching the shape a
## real handler needs) but unused by today's unconditional guard.
func check_faction_reassignment(_player: int) -> int:
	if is_faction_locked():
		return Action.Reason.FACTION_LOCKED
	return Action.Reason.OK


## The sole mutation vector for [GameState] (ADR-0001, ADR-0002). Runs the
## fixed 7-step pipeline in order: (1) reject if the match is already over,
## (2) reject if [param action] isn't the active player's, (3) dispatch to
## the owning system's pure, total [code]validate()[/code], (4) reject if
## [code]validate()[/code] didn't return [constant Action.Reason.OK] —
## nothing has mutated yet at this point (atomicity), (5) dispatch to the
## owning system's [code]apply()[/code] (assumes validation passed; may not
## fail), (6) run the (Story 004-owned, no-op here) win-check, (7) emit
## [signal action_applied] and return the [ActionResult] — emission happens
## only on success (ADR-0004).
##
## Dispatch is exclusively by [member Action.verb] through the
## [code]Dictionary[int, Callable][/code] tables built by
## [method _ensure_dispatch_registered] — never [code]action.get_class()[/code]
## (ADR-0002; for a GDScript-defined class that returns the base engine class
## name, not its [code]class_name[/code]). A verb with no registered handler
## (any of the 6 not-yet-implemented verbs, or a bare [code]Action.new()[/code]
## whose [member Action.verb] defaults to -1) is rejected cleanly with
## [constant Action.Reason.UNKNOWN_VERB] rather than crashing the dispatch
## lookup — this guard is a precondition to step 3, not an extra pipeline step.
##
## Idempotency is stateless re-validation: resubmitting an already-applied
## [Action] re-runs this same pipeline against current state and is rejected
## naturally by step 3/4 (no dedup IDs, no seen-set, ADR-0002).
##
## O(1): one Dictionary lookup + one [code]validate()[/code] call + (on pass)
## one [code]apply()[/code] call + one [code]emit_signal[/code] on success —
## negligible for turn-based play (control-manifest Performance Guardrail).
##
## Usage:
## [codeblock]
## var action := EndTurnAction.new()
## action.player = state.active_player
## var result: ActionResult = state.apply_action(action)
## if not result.ok:
##     push_warning("rejected: %d" % result.reason)
## [/codeblock]
func apply_action(action: Action) -> ActionResult:
	_ensure_dispatch_registered()

	# 1. GameOver gate — post-GameOver lockout (TR-gamestate-010).
	if match_status == MatchStatus.GAME_OVER:
		return ActionResult.new(false, Action.Reason.GAME_OVER, [])

	# 2. Active-player gate (applies to EndTurnAction too — active player only).
	if action.player != active_player:
		return ActionResult.new(false, Action.Reason.NOT_ACTIVE_PLAYER, [])

	# Dispatch-safety guard (precondition to step 3, not a new pipeline step):
	# fail loud-but-safe if this verb has no registered handler — 6 of 7 verbs
	# are legitimately unregistered until their own Core epic lands, and a bare
	# Action.new() defaults verb to -1. Without this, the step-3 Dictionary
	# lookup would crash the caller (UI/AI) instead of returning a clean
	# rejection, breaking apply_action's uniform-ActionResult contract.
	if not _validators.has(action.verb):
		return ActionResult.new(false, Action.Reason.UNKNOWN_VERB, [])

	# 3. validate() — pure, total; dispatch by verb enum, never get_class().
	var validator: Callable = _validators[action.verb]
	var reason: int = validator.call(self, action)

	# 4. Reject if not OK — atomic: nothing has mutated yet.
	if reason != Action.Reason.OK:
		return ActionResult.new(false, reason, [])

	# 5. apply() — mutates; assumes validation passed; may not fail.
	var applier: Callable = _appliers[action.verb]
	var events: Array = applier.call(self, action)

	# 6. run_win_check — call site only; Story 004 owns the logic.
	run_win_check(events)

	# 7. Emit only on success (ADR-0004), then return.
	var result := ActionResult.new(true, Action.Reason.OK, events)
	action_applied.emit(result)
	return result


## Win-check call site (ADR-0002 step 6). [b]Story 002 no-op stub[/b] — Story
## 004 owns the real HQ-at-0 → [constant MatchStatus.GAME_OVER] logic (keyed
## off a [code]StructureDestroyedEvent{is_hq}[/code] in [param events], per
## the control manifest). Deliberately does nothing here so
## [method apply_action]'s pipeline is fully testable before Story 004 lands;
## do not duplicate win-check logic elsewhere.
func run_win_check(_events: Array) -> void:
	pass
