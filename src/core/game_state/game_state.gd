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
## [method clone]. Story 002 added [method apply_action], the
## [signal action_applied] signal, and the verb-dispatch/registration
## mechanism — with only [EndTurnAction]'s handlers concretely wired. Story
## 003 wired [code]start_match[/code]/[code]start_turn[/code]/the real
## end-of-turn sequence. Story 004 (this story) implements [method
## run_win_check]: HQ-destruction detection (event-based, via
## [StructureDestroyedEvent]) and the optional [member max_rounds]/[member
## tiebreak_metric] anti-drag terminal predicate.
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

## Match terminal status. [code]IN_PROGRESS[/code] is the default; [method
## run_win_check] (Story 004) transitions to [code]GAME_OVER[/code].
enum MatchStatus { IN_PROGRESS, GAME_OVER }

## Why the match ended — set alongside [member winner] by [method run_win_check],
## mirroring its two terminal branches.
##
## ★ Added 2026-08-24 (S6-08). [GameOverEvent] previously carried only the winner,
## which is enough to say [i]who[/i] won but not [i]how[/i] — and `game-hud.md`
## AC-22 requires the victory presentation to reflect a round-limit tiebreak
## specifically. That AC was deferred as untestable while [member max_rounds] was
## off; it was armed at 30 in S6-03 and now fires in roughly 1 game in 7, so the
## deferral no longer holds and the reason has to be recorded rather than inferred.
##
## Inferring it downstream would not work: by the time the HUD reads the terminal
## state the destroyed HQ is gone from [member entities_by_id], so "was an HQ
## destroyed?" is no longer answerable from state alone.
enum WinReason {
	NONE, ## Match still in progress — pairs with [member winner] == -1.
	HQ_DESTROYED, ## Decisive victory: the loser's HQ was destroyed.
	ROUND_LIMIT, ## [member max_rounds] reached with both HQs standing; decided by [member tiebreak_metric].
}

## Which metric [method run_win_check]'s MAX_ROUNDS/tiebreak fallback uses to
## pick a winner when the round cap is reached with no HQ destroyed
## (TR-gamestate-016, ADR-0001).
##
## [b]Corrected 2026-08-21.[/b] `game-state-turn-manager.md` specifies
## [code]{total HQ hp, tiles controlled, unit count}[/code] with [b]total HQ hp as
## the default[/b]. Only [constant TiebreakMetric.UNIT_COUNT] originally shipped,
## because HQ hp needed entity-stat-schema fields that did not exist at the time —
## [code]StructureState.current_hp[/code] and structure-type identity. [b]ADR-0007
## has since landed and both exist[/b], so the specified default is now
## implementable and is implemented. The old note claiming otherwise was stale.
##
## [constant TiebreakMetric.TILES_CONTROLLED] remains unimplemented: the GDD names it
## but nothing defines what "controlled" means for a tile, and inventing a definition
## is a design decision rather than a gap to fill in. It is deliberately absent from
## this enum rather than present-but-broken.
enum TiebreakMetric {
	TOTAL_HQ_HP, ## Whose HQ is healthier — the spec default. See [method _compute_tiebreak_metric].
	UNIT_COUNT, ## How many UNITS each side has left. Structures do not count.
}

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

## The winning player once [member match_status] is [constant
## MatchStatus.GAME_OVER], or [code]-1[/code] while the match is still
## [constant MatchStatus.IN_PROGRESS] (no winner yet). Sole writer: [method
## run_win_check].
@export var winner: int = -1

## Why the match ended (see [enum WinReason]), or [constant WinReason.NONE] while
## it is still [constant MatchStatus.IN_PROGRESS]. Sole writer: [method
## run_win_check], which sets it in the same statement group as [member winner] —
## the two are always consistent.
@export var win_reason: int = WinReason.NONE

## Optional round cap for the anti-drag terminal predicate (TR-gamestate-016,
## ADR-0001). [code]0[/code] (the default) means [b]unset/OFF[/b] — the round
## cap never fires regardless of how high [member round_number] climbs; this
## is an opt-in cap, not a default game length. When set to a positive value
## [code]N[/code], [method run_win_check] ends the match once [member
## round_number] exceeds [code]N[/code] (i.e. all [code]N[/code] rounds have
## fully completed) with no HQ destroyed, deciding the winner via [member
## tiebreak_metric].
@export var max_rounds: int = 0

## Which metric decides the winner when [member max_rounds] is reached with no
## HQ destroyed. See [enum TiebreakMetric].
##
## [b]Defaults to [constant TiebreakMetric.TOTAL_HQ_HP][/b], which is what
## `game-state-turn-manager.md` specifies. It measures progress toward the only real
## win condition, so a capped game is decided by who was closer to winning it —
## and, unlike a count, it cannot be inflated by building things.
@export var tiebreak_metric: int = TiebreakMetric.TOTAL_HQ_HP


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


## The shared cross-system destruction hook (ADR-0010, Combat Resolution
## Story 005) — the single place any killer (Combat's primary hit, its future
## counter step, an AoE unit, a hazard) removes an entity from live play.
## Called only from inside a verb handler's [code]apply()[/code] (currently
## [method Combat.apply]'s primary-death branch), [b]never mid-iteration over
## [member entities_by_id][/b] — that ordering is what makes the
## [code]entities_by_id.erase()[/code] below concurrent-modification-safe
## (control-manifest Core Layer Rule, ADR-0010).
##
## Runs, in this exact order, all synchronously within the caller's
## [code]apply_action[/code] commit:
## [br](a) Lab-revert: forward-declared, currently a [b]no-op[/b] — see the
## [code]TODO[/code] below. Skipped until the Research/Base & Production
## epics land (Out of Scope, Story 005) — no stub invented for it since it
## has no consumer yet.
## [br](b) [method GridState.remove] to clear grid occupancy at [param
## entity_id]'s tile.
## [br](c) Drop [param entity_id] from [member entities_by_id].
## [br](d) Append a [UnitDestroyedEvent] (non-structure entity) or a
## [StructureDestroyedEvent]{[member StructureDestroyedEvent.entity_id],
## [member StructureDestroyedEvent.is_hq], [member StructureDestroyedEvent.owner]}
## (a [code]StructureState[/code] entity) to the returned events array.
##
## O(1): one [method GridState.remove], one [code]Dictionary.erase[/code], one
## event append — no scan (control-manifest Performance Guardrail).
##
## Usage:
## [codeblock]
## # inside Combat.apply(), immediately after the primary damage line:
## if target.current_hp <= 0:
##     events.append_array(state.destroy_entity(target.entity_id))
## [/codeblock]
func destroy_entity(entity_id: int) -> Array[Event]:
	# Precondition: [param entity_id] must be a live key in entities_by_id. The
	# only caller is Combat.apply() (ADR-0010: never called except from inside a
	# verb handler's apply()), which always passes a just-validated target/
	# attacker id — so a missing key is a caller bug, deliberately left to throw
	# on the line below rather than silently no-op'd (a swallowed bad id would
	# hide a real pipeline error). Not defended against by design.
	var e: EntityState = entities_by_id[entity_id]
	var evts: Array[Event] = []
	# TODO(research-tech epic): Lab-revert hook, ADR-0010 step (a) — call the
	# forward-declared Research.on_lab_destroyed(self, e) here once a real
	# StructureState/Research Lab model exists (is_research_lab(),
	# current_research_target). No-op today; no consumer, no stub invented.
	grid.remove(e.position.x, e.position.y) # (b)
	entities_by_id.erase(entity_id)          # (c)
	if e is StructureState:
		var evt := StructureDestroyedEvent.new()
		evt.entity_id = entity_id
		evt.is_hq = e.is_hq()
		evt.owner = e.owner
		evts.append(evt)
	else:
		evts.append(UnitDestroyedEvent.new(entity_id))
	return evts


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
## [br]4. Reset [param player]'s AP ([code]AP.reset_turn[/code] — flat budget +
## capped carryover, step 4a) and bank the turn's Credit income
## ([code]Credits.add_income[/code], step 4b). Step 4b is deliberately after step
## 3, so a structure/tech completed this same turn is reflected in the Credit
## income it adds (never reorder 4b before step 3; 4a is order-independent).
##
## Returns every [Event] step 3 appended (completions), in the order they
## happened — flows through the existing [signal action_applied] once the
## caller ([method _apply_end_turn] via [method apply_action], or
## [method start_match]) finishes. No new signal or polling path.
##
## O(entity count): one filtered pass over [method entities] (dominated by
## its stable-order sort) plus two per-system O(entity count) passes and the two
## O(1) economy resets (AP flat-carry + Credit income add) — runs once per player
## per turn, never per-frame/per-action.
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

	# 4a. AP reset — flat budget + capped carryover (ADR-0006; not income-driven).
	AP.reset_turn(self, player)
	# ★ S7-16: one-off compensation for the measured SECOND-mover advantage. On a symmetric
	# board with no fog and deterministic combat, the player who moves first must commit into
	# the open and the second answers with full information — across 12 symmetric openings the
	# second mover won 10, every one of them on the round-cap unit-count tiebreak.
	#
	# Fires exactly once per match: round_number is still 1 for BOTH players' opening turns
	# (it increments only when control returns to starting_player), so the starting_player
	# guard is what makes this one-off rather than twice.
	#
	# ⚠ Deliberately additive AFTER reset_turn rather than folded into it: reset_turn is the
	# per-turn AP rule and applies to every turn of the match, while this is a one-time
	# handicap. Keeping them separate stops a future carryover change from silently scaling
	# the compensation. Defaults to 0 — inert unless configured.
	if round_number == 1 and player == starting_player and Balance.economy.first_turn_ap_bonus > 0:
		per_player[player].current_ap += Balance.economy.first_turn_ap_bonus
	# 4b. Credit economy — bank NET income (gross - upkeep) AFTER step 3, so a
	# structure completing this turn is already paying its own upkeep. Also sets
	# PlayerState.in_deficit, which locks produce/build/research for this turn
	# (unit-upkeep.md UR-2/UR-6).
	Upkeep.apply_turn_economy(self, player)

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
## # state.per_player[0].current_ap == Balance.economy.flat_ap_per_turn (leftover 0),
## # state.per_player[0].current_credits == Credits.credit_income(state, 0)
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
## [member _dispatch_registered], not per-[GameState]-instance state):
## [constant Action.Verb.END_TURN] (this class's own handlers),
## [constant Action.Verb.MOVE] ([Movement], ADR-0009),
## [constant Action.Verb.ATTACK] ([Combat], ADR-0010, Combat Resolution
## Story 004), [constant Action.Verb.BUILD] ([BaseProduction], ADR-0017,
## Base & Production Story 002), [constant Action.Verb.PRODUCE]
## ([BaseProduction], ADR-0017 D4, Base & Production Story 004), and
## [constant Action.Verb.CANCEL_BUILD] ([BaseProduction], ADR-0017 D5, Base &
## Production Story 005). Safe to call every time [method apply_action]
## runs — the guard makes every call after the first a single boolean check,
## never a per-call Dictionary rebuild (control-manifest Performance
## Guardrail).
static func _ensure_dispatch_registered() -> void:
	if _dispatch_registered:
		return
	register_verb(Action.Verb.END_TURN, _validate_end_turn, _apply_end_turn)
	register_verb(Action.Verb.MOVE, Movement.validate, Movement.apply)
	register_verb(Action.Verb.ATTACK, Combat.validate, Combat.apply)
	register_verb(Action.Verb.BUILD, BaseProduction.validate_build, BaseProduction.apply_build)
	register_verb(Action.Verb.PRODUCE, BaseProduction.validate_produce, BaseProduction.apply_produce)
	register_verb(Action.Verb.CANCEL_BUILD, BaseProduction.validate_cancel, BaseProduction.apply_cancel)
	register_verb(Action.Verb.DISBAND, Upkeep.validate_disband, Upkeep.apply_disband)
	register_verb(Action.Verb.WAIT, _validate_wait, _apply_wait)
	_dispatch_registered = true


## [WaitAction]'s [code]validate()[/code] handler.
##
## [b]Owning system: this class[/b], for the same reason [EndTurnAction]'s handlers
## live here — standing an entity down is turn bookkeeping, and there is no
## TurnManager class (the control manifest forbids one). It is also the only verb
## that applies to units and structures alike, so neither [Unit] nor [Structure]
## is a more natural home than the other.
##
## Rejects an entity that does not exist ([constant Action.Reason.NO_SUCH_ENTITY])
## or that the acting player does not own ([constant Action.Reason.ILLEGAL_TARGET]).
## [method apply_action]'s step 2 already enforces "active player only", so this
## adds no turn check of its own.
##
## [b]Standing down an already-stood-down entity is deliberately OK, not an
## error[/b] — it is idempotent, and rejecting it would make a double-press of a
## harmless tidying verb produce a "Refused" line for no reason.
static func _validate_wait(state: GameState, action: Action) -> int:
	var entity: EntityState = state.entities_by_id.get(action.entity_id)
	if entity == null:
		return Action.Reason.NO_SUCH_ENTITY
	if entity.owner != action.player:
		return Action.Reason.ILLEGAL_TARGET
	return Action.Reason.OK


## [WaitAction]'s [code]apply()[/code] handler: sets the per-turn stand-down mark.
##
## Spends nothing — no AP, no Credits — and emits [EntityStoodDownEvent] so the
## action log can show it and any listener can react. See [WaitAction] for why a
## rules-free verb still routes through the mutation pipeline.
static func _apply_wait(state: GameState, action: Action) -> Array:
	var entity: EntityState = state.entities_by_id.get(action.entity_id)
	if entity is UnitState:
		(entity as UnitState).stood_down = true
	elif entity is StructureState:
		(entity as StructureState).stood_down = true
	return [EntityStoodDownEvent.new(action.entity_id)] as Array[Event]


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
## order: (1) determine the next player via strict 2-player alternation
## ([code]1 - outgoing[/code] — out of scope for any future N-player mode,
## see ADR-0008 Risks); (2) increment [member round_number] [b]only[/b] if
## [param next_player] equals [member starting_player] (control has looped
## back to whoever moved first this match); (3) run [method start_turn] for
## [param next_player] and return its events. There is no AP-discard step — the
## economy pivot (ADR-0006) removed it: unspent AP carries (capped) into the
## outgoing player's next reset, and Credits bank across the turn boundary.
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
	# No AP discard (ADR-0006 pivot): unspent AP carries (capped) into the outgoing
	# player's next AP.reset_turn(); Credits bank. `outgoing` is used only below.
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
## fail), (6) run [method run_win_check] (HQ-destruction / MAX_ROUNDS-tiebreak
## terminal check), (7) emit [signal action_applied] and return the
## [ActionResult] — emission happens only on success (ADR-0004).
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

	# 6. run_win_check — HQ-destruction / MAX_ROUNDS-tiebreak terminal check.
	run_win_check(events)

	# 7. Emit only on success (ADR-0004), then return.
	var result := ActionResult.new(true, Action.Reason.OK, events)
	action_applied.emit(result)
	return result


## Win-check — [method apply_action]'s pipeline step 6 (ADR-0002; TR-gamestate-010).
## Evaluates terminal conditions in strict precedence order and sets [member
## match_status]/[member winner] synchronously, inside the same commit that
## triggered them:
##
## [br]1. [b]HQ-destruction (decisive, checked first):[/b] scans [param
## events] for any [StructureDestroyedEvent] with [member
## StructureDestroyedEvent.is_hq] `true` — never a separate HQ hp re-scan
## (ADR-0010, control-manifest Core Layer Rules). If both players' HQs are
## destroyed in the same step, the [b]non-active player wins[/b] (an attacker
## cannot win by an action that also destroys their own HQ) — an explicit
## deterministic branch, not incidental ordering. If exactly one HQ is
## destroyed, its owner's opponent wins. Either way this method sets [member
## match_status] to [constant MatchStatus.GAME_OVER], sets [member winner],
## appends a [GameOverEvent] to [param events], and returns immediately — a
## decisive victory always takes precedence over the MAX_ROUNDS/tiebreak
## fallback below, even if the round cap is reached in the very same step.
## [br]2. [b]MAX_ROUNDS/tiebreak (anti-drag fallback, only reached if no HQ was
## destroyed this step):[/b] if [member max_rounds] is set ([code]> 0[/code])
## and [member round_number] has exceeded it (all [member max_rounds] rounds
## have fully completed), computes [member tiebreak_metric] per player —
## [constant TiebreakMetric.UNIT_COUNT] counts each player's entities in
## [member entities_by_id] via the stable-order [method entities] scan
## (ADR-0003) — and the higher metric wins. An exact tie resolves to the
## [b]non-active player[/b] — the same deterministic rule as the simultaneous-
## HQ case, so there is never an undefined draw. Sets [member match_status],
## [member winner], and appends a [GameOverEvent], same as branch 1.
## [br]3. Otherwise leaves [member match_status] at [constant
## MatchStatus.IN_PROGRESS] — no terminal condition met.
##
## Idempotency/safety: if [member match_status] is already [constant
## MatchStatus.GAME_OVER] this is a no-op (though [method apply_action]'s
## step-1 lockout normally prevents [method run_win_check] from ever being
## reached again post-GameOver, so this guard is defense-in-depth, not the
## primary lockout mechanism).
##
## O(entity count) at worst (branch 2's [method entities] scan, run once per
## commit, never per-frame) — negligible for turn-based play (control-manifest
## Performance Guardrail). Integer-only, no RNG (ADR-0003).
##
## Usage:
## [codeblock]
## # inside apply_action, after apply() returns events:
## run_win_check(events) # may mutate match_status/winner and append a GameOverEvent
## [/codeblock]
func run_win_check(events: Array) -> void:
	if match_status == MatchStatus.GAME_OVER:
		return

	# --- 1. HQ-destruction: decisive, checked first, event-based only. ------
	var destroyed_hq_owners: Array[int] = []
	for e: Event in events:
		if e is StructureDestroyedEvent and e.is_hq:
			destroyed_hq_owners.append(e.owner)

	if not destroyed_hq_owners.is_empty():
		var hq_winner: int
		if destroyed_hq_owners.size() >= 2:
			# Simultaneous double-HQ destruction (AC3) — the attacker cannot
			# win by an action that also destroys their own HQ; the
			# non-active player wins, an explicit deterministic branch.
			hq_winner = 1 - active_player
		else:
			# Exactly one HQ destroyed — its owner's opponent wins.
			hq_winner = 1 - destroyed_hq_owners[0]
		match_status = MatchStatus.GAME_OVER
		winner = hq_winner
		win_reason = WinReason.HQ_DESTROYED
		var hq_game_over := GameOverEvent.new()
		hq_game_over.winner = hq_winner
		hq_game_over.reason = WinReason.HQ_DESTROYED
		events.append(hq_game_over)
		return # AC6: decisive victory always beats the tiebreak fallback.

	# --- 2. MAX_ROUNDS/tiebreak: anti-drag fallback, opt-in, off by default. -
	if max_rounds <= 0:
		return # Unset (AC5) — the round cap never fires.
	if round_number <= max_rounds:
		return # Cap not yet reached.

	var metric_by_player: Array[int] = _compute_tiebreak_metric()
	var tiebreak_winner: int
	if metric_by_player[0] > metric_by_player[1]:
		tiebreak_winner = 0
	elif metric_by_player[1] > metric_by_player[0]:
		tiebreak_winner = 1
	else:
		# Exact tie (AC7) — non-active player wins, same rule as branch 1.
		tiebreak_winner = 1 - active_player

	match_status = MatchStatus.GAME_OVER
	winner = tiebreak_winner
	win_reason = WinReason.ROUND_LIMIT
	var tiebreak_game_over := GameOverEvent.new()
	tiebreak_game_over.winner = tiebreak_winner
	tiebreak_game_over.reason = WinReason.ROUND_LIMIT
	tiebreak_game_over.metric = tiebreak_metric
	tiebreak_game_over.metric_by_player = metric_by_player
	events.append(tiebreak_game_over)


## Computes [member tiebreak_metric] for each of the two players, in player-
## index order (index 0 = player 0's metric, index 1 = player 1's). Pure,
## integer-only, no RNG (ADR-0003) — private helper for [method run_win_check]'s
## branch 2 only.
##
## [constant TiebreakMetric.TOTAL_HQ_HP] (the default) sums each player's own HQ hp;
## [constant TiebreakMetric.UNIT_COUNT]:
## counts entities in [member entities_by_id] by [member EntityState.owner],
## scanned via the stable [member entity_id]-ascending [method entities] order
## (ADR-0003) even though a plain count does not depend on visitation order —
## kept for consistency with every other order-sensitive entity pass on this
## class, and so a future metric (e.g. total hp) that DOES care about order
## can be added here without an ordering regression.
## Each player's current [member tiebreak_metric] score, indexed by player — what
## a round-limit finish would be decided on if the cap fired right now.
##
## The public read over [method _compute_tiebreak_metric], added 2026-08-24 (S6-08)
## for [method GameStateReader.tiebreak_scores]. Exposed rather than reimplemented
## in the HUD so the figure a player sees is definitionally the figure that decides
## the game — a second implementation could drift from this one and would do so
## invisibly, since both only disagree on games that reach the cap.
##
## O(entity count). Read on commit, never per-frame.
func tiebreak_scores() -> Array[int]:
	return _compute_tiebreak_metric()


func _compute_tiebreak_metric() -> Array[int]:
	var counts: Array[int] = [0, 0]
	match tiebreak_metric:
		TiebreakMetric.TOTAL_HQ_HP:
			# The spec default. Each side scores its OWN HQ's remaining hp, so the
			# player whose HQ is healthier wins — i.e. the player who did more damage
			# toward the actual win condition. Unlike a count it cannot be inflated by
			# producing or building, which is what made the old entity count degenerate
			# (the optimal capped line was boom-and-avoid-combat).
			for e: EntityState in entities():
				if e is StructureState and (e as StructureState).is_hq():
					counts[e.owner] += (e as StructureState).current_hp
		TiebreakMetric.UNIT_COUNT:
			# ★ Counts UNITS. It previously counted every entity — structures and the
			# HQ included — which made the name a lie and handed capped games to
			# whoever built most. Corrected 2026-08-21; see the enum's note.
			for e: EntityState in entities():
				if e is UnitState:
					counts[e.owner] += 1
	# No default branch by design: an unrecognized metric (bad save data / a
	# future enum value not yet handled) intentionally falls through to [0, 0],
	# which run_win_check resolves as a tie → non-active player wins. A silent
	# deterministic fallback is preferred here over a hard error mid-commit.
	return counts
