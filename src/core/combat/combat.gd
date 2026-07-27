## Combat — static utility class for damage resolution (ADR-0010, Story 001 slice).
##
## Core-layer system per ADR-0010 (Combat Resolution & Shared Destruction /
## Win-Check). Holds only pure/static functions that take [code]state[/code]
## explicitly — no instance fields of its own. Mirrors the verb-handler shape
## ADR-0002/0006 established for [code]AP[/code]/[code]Movement[/code]
## (static, stateless, state/entity passed explicitly).
##
## [b]Scope so far:[/b] Story 001 shipped [method damage]/[method preview_damage]
## and the [CombatConfig] plumbing; Story 002 added DIRECT [method legal_targets]/
## [method blocked_reason] (the [enum BlockedReason] classification plus the
## [TargetResult] carrier); Story 003 added the [method legal_targets_from]
## hypothetical-origin overload (both public entry points now route through
## it), the dormant AREA ring profile, and the [method has_valid_targeting_schema]
## [code]min_range <= attack_range[/code] invariant predicate. Story 004 added
## the [AttackAction] verb handler ([method validate]/[method apply]) — the
## AP-cost/once-per-turn/atomicity slice of the pipeline only: primary damage
## lands on [code]current_hp[/code] via [method _apply_damage_to], but death/
## destroy_entity/counterattack were not yet implemented, and a
## [code]StructureState[/code] attacker was temporarily rejected. Story 005
## removes that rejection (attacker-kind branching in [method validate]/
## [method apply], with the AP cost reading the forward-declared
## [code]BaseProduction.defensive_attack_cost()[/code] for a structure
## attacker), and adds the primary death check
## ([method GameState.destroy_entity]) immediately after primary damage lands.
## Story 006 completes the pipeline with the conditional counter step: a
## surviving defender with [code]type.can_counterattack == true[/code] and the
## original attacker inside the defender's [b]own[/b] targeting profile
## ([method _in_defenders_profile], reusing [method legal_targets]) retaliates
## for free (no AP, no [code]has_attacked[/code] write) via the same
## [method _apply_damage_to]/[method GameState.destroy_entity] machinery the
## primary hit uses. The counter is structurally non-recursive — it is one
## straight-line block that runs at most once per [method apply] call, never a
## loop or a re-entrant call back into [method apply] — so a counter can never
## itself be countered.
##
## Usage:
## [codeblock]
## var dmg: int = Combat.damage(state, attacker, defender)
## var preview: int = Combat.preview_damage(state, attacker, target) # == dmg for the same inputs
## [/codeblock]
class_name Combat
extends RefCounted


## The one damage formula (ADR-0010, TR-combat-001): [code]max(MIN_DAMAGE,
## effective_attack(attacker) - cover_reduction(defender) - defense(defender))[/code].
##
## [b]Cover term[/b] (TR-combat-002): [member CombatConfig.cover_dr] applies
## only when [param defender] is a [code]UnitState[/code] standing on an
## [method GridState.is_cover] tile — [b]always 0 for a [code]StructureState[/code]
## defender[/b] (structures are cover-immune). The attacker's own tile is
## never read here — only the defender's.
##
## [b]Defense term[/b]: read via [method Unit.effective_defense] (live
## Defense-Tech fold) for a [code]UnitState[/code] defender; read directly
## from [code]defender.type.defense[/code] for a [code]StructureState[/code]
## defender (no Defense-Tech fold applies to structures). Never a bare
## [code]defender.defense[/code] — [code]defense[/code] is a template field on
## [code]UnitTypeDef[/code]/[code]StructureTypeDef[/code] (ADR-0007), not a
## field on the entity itself.
##
## [b]Attack term[/b]: delegated to [method _effective_attack_for], isolated
## so a later story's structure-attacker work extends it in place rather than
## re-opening this function.
static func damage(state: GameState, attacker: EntityState, defender: EntityState) -> int:
	var cover: int = CombatBalance.combat.cover_dr if (defender is UnitState and state.grid.is_cover(defender.position.x, defender.position.y)) else 0
	var def: int = Unit.effective_defense(state, defender) if defender is UnitState else defender.type.defense
	return max(CombatBalance.combat.min_damage, _effective_attack_for(state, attacker) - cover - def)


## The attack value [method damage] charges against [param attacker]: the
## forward-declared [method Unit.effective_attack] (live Attack-Tech fold) for
## a [code]UnitState[/code] attacker; read directly from
## [code]attacker.type.attack[/code] for a [code]StructureState[/code]
## attacker (Story 005's structure-attacker branch, defined now but not
## exercised until that story lands — this story's fixtures are
## unit-attacker-only).
##
## Isolated in its own function (rather than inlined in [method damage]) so a
## later story extends this branch in place; [method damage]'s parameters
## stay typed to [EntityState] (not [code]UnitState[/code]) so no signature
## change is needed then.
static func _effective_attack_for(state: GameState, attacker: EntityState) -> int:
	return Unit.effective_attack(state, attacker) if attacker is UnitState else attacker.type.attack


## The AP cost [param attacker] spends to attack (ADR-0010, TR-combat-012):
## Combat's flat [member CombatConfig.attack_cost] for a [code]UnitState[/code]
## attacker; the forward-declared, Base-&-Production-owned
## [code]BaseProduction.defensive_attack_cost()[/code] for a
## [code]StructureState[/code] (Defensive Structure) attacker. Isolated in one
## place — called by BOTH [method validate]'s affordability check and
## [method apply]'s spend — so the two can never drift (a future third cost
## case is edited once, not in two must-agree call sites). Mirrors the
## [method _effective_attack_for] isolation pattern in this same file. O(1).
static func _attack_cost_for(attacker: EntityState) -> int:
	return BaseProduction.defensive_attack_cost() if attacker is StructureState else CombatBalance.combat.attack_cost


## Pure preview of the damage an attack would deal (ADR-0010, TR-combat-006):
## a one-line pass-through to [method damage] — [b]never[/b] a separately
## re-derived formula. This is what makes the preview a guarantee, not an
## estimate: it calls the exact same function [code]apply()[/code] (Story 004)
## will later call to commit damage.
static func preview_damage(state: GameState, attacker: EntityState, target: EntityState) -> int:
	return damage(state, attacker, target)


## The three distinct reasons a DIRECT walk (or the AREA ring scan, via
## [method has_valid_targeting_schema]'s schema-violation path) has no legal
## target in a given direction/tile (ADR-0010, TR-combat-014): [constant NONE]
## means a target IS present — the walk succeeded, not a "blocked" case at
## all; [constant BLOCKED_BY_FRIENDLY] means the first occupied tile on the
## line belongs to the attacker's own owner; [constant OUT_OF_RANGE] means the
## walk exhausted [code]attacker.type.attack_range[/code] steps (or hit an
## Impassable tile) with no blocker/enemy found. [constant INSIDE_DEAD_ZONE] is
## [b]reserved[/b] for a per-tile AREA dead-zone classification — no current
## caller queries it via [method blocked_reason] (that API is DIRECT-only,
## direction-keyed); AREA's dead zone is expressed structurally by
## [method legal_targets_from] simply omitting the tile, per ADR-0010's note
## that no new [enum Action.Reason] branch is needed yet.
enum BlockedReason { NONE, BLOCKED_BY_FRIENDLY, OUT_OF_RANGE, INSIDE_DEAD_ZONE }

## The four fixed cardinal step offsets [method legal_targets]/[method
## blocked_reason] walk, in this exact enumeration order (N, E, S, W) — never
## [method GridState.neighbors], whose iteration order ADR-0009 leaves
## unpinned. Mirrors [method Movement._neighbors_in_fixed_order]'s established
## fixed-offset-order convention (ADR-0003 stable iteration).
const _CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), # N
	Vector2i(1, 0),  # E
	Vector2i(0, 1),  # S
	Vector2i(-1, 0), # W
]


## TargetResult — one legal DIRECT/AREA target returned by [method legal_targets].
##
## Inner class of [Combat]; not auto-registered as a global [code]class_name[/code]
## (GDScript inner-class limitation) — external references (tests, the Command
## & Action Interface overlay) must use the [code]Combat.TargetResult[/code]
## prefix, mirroring [code]Movement.ReachableTile[/code]'s established
## precedent (ADR-0009).
class TargetResult extends RefCounted:
	## The targeted entity's id — resolve back to an [EntityState] via
	## [code]GameState.entities_by_id[/code] or [method GameState.entity_at].
	var target_id: int
	## The tile the targeted entity occupies.
	var tile: Vector2i

	func _init(id: int, t: Vector2i) -> void:
		target_id = id
		tile = t


## Private walk-result carrier shared by [method legal_targets] and [method
## blocked_reason] — the single source of truth for "why did the DIRECT walk
## in this one direction stop the way it did." Not exposed publicly; both
## public entry points call [method _walk_direction] and read whichever half
## of this they need, rather than maintaining two parallel algorithms.
class _WalkResult extends RefCounted:
	var reason: BlockedReason
	var target: TargetResult # null unless reason == BlockedReason.NONE

	func _init(r: BlockedReason, t: TargetResult = null) -> void:
		reason = r
		target = t


## Walks tile-by-tile outward from [param origin] along one fixed cardinal
## [param direction], up to [code]attacker.type.attack_range[/code] steps
## (ADR-0010 DIRECT profile). [param origin] is a plain local coordinate — the
## hypothetical-tile overload's caller ([method legal_targets_from]) passes
## either [param attacker]'s real [code]position[/code] or an arbitrary
## candidate tile; this function reads only the [param origin] parameter and
## never [code]attacker.position[/code] directly, which is what makes the
## hypothetical-origin query pure (Story 003 refactor — see
## [method legal_targets_from]'s doc comment).
##
## At each step: an Impassable tile stops the walk with [constant
## BlockedReason.OUT_OF_RANGE] (no target, nothing beyond it is reachable this
## direction); an occupied tile is the first blocker — [b]ownership alone
## decides legality, occupant kind (unit vs. structure) never does[/b]: an
## enemy occupant (unit or structure) is the sole legal target this direction
## ([constant BlockedReason.NONE] plus a populated [member _WalkResult.target]),
## while a friendly occupant (unit or structure) blocks with no target
## ([constant BlockedReason.BLOCKED_BY_FRIENDLY]). An empty passable tile is
## skipped and the walk continues outward. If [code]attack_range[/code] steps
## are exhausted with nothing found, the direction yields [constant
## BlockedReason.OUT_OF_RANGE].
##
## Single algorithm shared by [method legal_targets_from] (which reads
## [member _WalkResult.target] when present) and [method blocked_reason]
## (which reads only [member _WalkResult.reason]) — there is exactly one
## tile-walk implementation, per ADR-0010's Implementation Notes.
##
## O([code]attack_range[/code]) — one direction, each step O(1) grid/entity
## lookups (control-manifest Performance Guardrail).
static func _walk_direction(state: GameState, attacker: EntityState, origin: Vector2i, direction: Vector2i) -> _WalkResult:
	var attack_range: int = attacker.type.attack_range
	for step: int in range(1, attack_range + 1):
		var tile: Vector2i = origin + direction * step
		if state.grid.terrain_at(tile.x, tile.y) == GridState.Terrain.IMPASSABLE:
			return _WalkResult.new(BlockedReason.OUT_OF_RANGE)
		var occupant_id: int = state.grid.occupant_at(tile.x, tile.y)
		if occupant_id != GridState.EMPTY_OCCUPANT:
			var occupant: EntityState = state.entity_at(tile)
			if occupant.owner != attacker.owner:
				return _WalkResult.new(BlockedReason.NONE, TargetResult.new(occupant_id, tile))
			return _WalkResult.new(BlockedReason.BLOCKED_BY_FRIENDLY)
		# Empty, passable tile — continue outward.
	return _WalkResult.new(BlockedReason.OUT_OF_RANGE)


## Returns every legal target for [param attacker] (ADR-0010, TR-combat-003)
## at its real, current [code]position[/code] — a one-line delegation to
## [method legal_targets_from] with [code]attacker.position[/code] as the
## origin (Story 003 refactor). See [method legal_targets_from] for the full
## per-profile (DIRECT/AREA) rules; this is the zero-arg form the hypothetical-
## tile overload must match when [code]from_tile == attacker.position[/code]
## (TR-combat-004).
static func legal_targets(state: GameState, attacker: EntityState) -> Array[TargetResult]:
	return legal_targets_from(state, attacker, attacker.position)


## Returns every legal target for [param attacker] [b]as if it stood on
## [param from_tile][/b] (ADR-0010, TR-combat-004) — pure, side-effect-free;
## never mutates [param state], [param state]'s grid, or
## [param attacker].[code]position[/code]. Dispatches on
## [code]attacker.type.targeting_mode[/code]:
##
## [br]- [constant UnitTypeDef.TargetingMode.DIRECT]: walks tile-by-tile
## outward along each of the 4 fixed cardinal directions from [param from_tile],
## in fixed N->E->S->W order ([constant _CARDINAL_DIRECTIONS]), up to
## [code]attacker.type.attack_range[/code] steps, via [method _walk_direction].
## Each direction yields at most one [TargetResult] — the [b]nearest[/b] enemy
## occupant on that line (no pierce); a direction with no enemy found (blocked
## by a friendly, blocked by Impassable terrain, or exhausted out of range)
## contributes nothing. Diagonal/non-cardinal tiles are never considered.
## [br]- [constant UnitTypeDef.TargetingMode.AREA]: delegates to
## [method _area_targets_from] — a dormant ring-scan profile (no VS roster unit
## uses it yet); see that method's doc comment for the full rule.
##
## [param attacker] is never actually moved — [param from_tile] is a plain
## local coordinate passed to whichever profile's algorithm runs, exactly like
## [method legal_targets]'s zero-arg form threads [code]attacker.position[/code]
## through the identical code path; there is exactly one implementation per
## profile, parameterized by origin, never two parallel copies (this is what
## guarantees the "identical rules as if it stood on [param from_tile]"
## requirement by construction). Safe to call against the authoritative
## [param state] or any [method GameState.clone] (AI lookahead, Command &
## Action Interface after-move attack preview).
##
## O(4 * attack_range) worst case for DIRECT / O(ring area) for AREA
## (control-manifest Performance Guardrail); called once per reachable-frontier
## tile by the dominant caller, ADR-0011's AI lookahead.
static func legal_targets_from(state: GameState, attacker: EntityState, from_tile: Vector2i) -> Array[TargetResult]:
	if attacker.type.targeting_mode == UnitTypeDef.TargetingMode.AREA:
		return _area_targets_from(state, attacker, from_tile)
	var results: Array[TargetResult] = []
	for direction: Vector2i in _CARDINAL_DIRECTIONS:
		var walk: _WalkResult = _walk_direction(state, attacker, from_tile, direction)
		if walk.target != null:
			results.append(walk.target)
	return results


## Schema-invariant predicate (ADR-0010/ADR-0007, TR-combat-011): true iff
## [param entity]'s [code]type.min_range <= type.attack_range[/code]. Exposed
## as a pure, directly-testable query — rather than only a bare
## [code]push_error[/code] inside [method _area_targets_from] — because a
## violating AREA unit's ring is empty [i]by construction[/i] (every candidate
## tile fails the [code]min_range <= distance <= attack_range[/code] test when
## the bounds are inverted), so an "is the result empty?" assertion alone
## cannot distinguish a genuine schema violation from an ordinary empty ring
## (no enemy currently in range). This predicate is what makes that
## distinction testable.
##
## DIRECT units always satisfy the invariant ([code]min_range[/code] defaults
## to 1, always [code]<=[/code] any [code]attack_range >= 1[/code]) — this is a
## no-op guard for the whole VS roster; it only ever matters for a
## (currently-dormant) AREA fixture.
static func has_valid_targeting_schema(entity: EntityState) -> bool:
	return entity.type.min_range <= entity.type.attack_range


## The dormant AREA targeting profile (ADR-0010, TR-combat-003 AREA half):
## selects every enemy-occupied tile within [param attacker]'s ring around
## [param from_tile] — [b]ignoring line-of-fire entirely[/b] (no terrain/
## occupant blocker check; AREA "arcs over" intervening pieces and terrain,
## per the GDD). A tile [code]t[/code] is selected iff it is enemy-occupied and
## [code]attacker.type.min_range <= manhattan_distance(from_tile, t) <=
## attacker.type.attack_range[/code] — [b]both bounds inclusive[/b] (the
## off-by-one guard the ACs call out: a tile exactly at [code]min_range[/code]
## or exactly at [code]attack_range[/code] is targetable).
##
## Schema guard first: if [method has_valid_targeting_schema] is false (an
## illegal [code]min_range > attack_range[/code] fixture), logs a
## [code]push_error[/code] (developer visibility) and returns an empty array —
## a validation error, never a silent soft-lock (TR-combat-011) — without
## scanning the ring at all.
##
## Scans the bounding box [code][from_tile - attack_range, from_tile +
## attack_range]^2[/code] in [b]fixed row-major order[/b] ([code]y[/code]
## outer, [code]x[/code] inner — matching [method GridState.index]'s own
## [code]y * width + x[/code] convention), never [code]state.entities()[/code]
## order or an unspecified nested-loop direction — this keeps the returned
## [code]Array[TargetResult][/code]'s ordering reproducible across identical
## calls and clones (ADR-0003 Rule 3, the same stable-iteration discipline
## [method _walk_direction]'s fixed N->E->S->W order follows).
##
## Single-target infrastructure: [b]every[/b] enemy tile satisfying the ring
## test is returned as an independently-targetable candidate — "only one
## target actually takes damage" is [method Combat.apply]'s concern (Story
## 004), not this query's.
##
## O(ring area) = O((2 * attack_range + 1)^2) tile checks, each O(1)
## ([method GridState.manhattan_distance] + [method GridState.occupant_at])
## (control-manifest Performance Guardrail) — bounded, not a per-frame path.
static func _area_targets_from(state: GameState, attacker: EntityState, from_tile: Vector2i) -> Array[TargetResult]:
	var results: Array[TargetResult] = []
	if not has_valid_targeting_schema(attacker):
		push_error("AREA unit has min_range > attack_range: entity_id=%d" % attacker.entity_id)
		return results
	var min_range: int = attacker.type.min_range
	var attack_range: int = attacker.type.attack_range
	for y: int in range(from_tile.y - attack_range, from_tile.y + attack_range + 1):
		for x: int in range(from_tile.x - attack_range, from_tile.x + attack_range + 1):
			var occupant_id: int = state.grid.occupant_at(x, y)
			if occupant_id == GridState.EMPTY_OCCUPANT:
				continue
			var tile := Vector2i(x, y)
			var occupant: EntityState = state.entity_at(tile)
			if occupant.owner == attacker.owner:
				continue
			var dist: int = state.grid.manhattan_distance(from_tile, tile)
			if dist < min_range or dist > attack_range:
				continue
			results.append(TargetResult.new(occupant_id, tile))
	return results


## Reports why [param attacker] cannot (or can) target along one fixed
## [param direction] from its real, current [code]position[/code] (ADR-0010,
## TR-combat-014) — [param direction] must be one of the four fixed cardinal
## unit vectors in [constant _CARDINAL_DIRECTIONS] ([code]Vector2i(0, -1)[/code]
## N, [code]Vector2i(1, 0)[/code] E, [code]Vector2i(0, 1)[/code] S,
## [code]Vector2i(-1, 0)[/code] W) — the same offsets [method legal_targets]
## iterates, never an arbitrary target-tile coordinate. This is a real-position,
## DIRECT-only classification API — it has no hypothetical-origin overload
## (out of this story's scope); it always passes [code]attacker.position[/code]
## as the origin to [method _walk_direction].
##
## Re-runs [method _walk_direction] for that single direction (the same
## algorithm [method legal_targets_from]'s DIRECT branch uses — a single
## source of truth for "why is this direction not targetable") and returns its
## [enum BlockedReason]: [constant BlockedReason.NONE] if an enemy is
## targetable that direction, [constant BlockedReason.BLOCKED_BY_FRIENDLY] if
## the first occupant on the line is friendly, or
## [constant BlockedReason.OUT_OF_RANGE] if the walk exhausted
## [code]attack_range[/code] steps (or hit Impassable terrain) with nothing
## found. [constant BlockedReason.INSIDE_DEAD_ZONE] is never returned here —
## AREA has no per-direction classification (it is a tile-ring scan, not a
## directional walk).
##
## A non-cardinal [param direction] is a programming error (the Command
## interface only ever passes the four cardinals): asserts loudly in debug
## builds, and falls back to [constant BlockedReason.NONE] in release (the
## assert is a dev-time trip-wire, never the only guard behavior depends on in
## a shipped build).
##
## O(attack_range) — one direction (control-manifest Performance Guardrail).
static func blocked_reason(state: GameState, attacker: EntityState, direction: Vector2i) -> BlockedReason:
	assert(direction in _CARDINAL_DIRECTIONS, "blocked_reason() requires one of the 4 fixed cardinal unit vectors")
	if not (direction in _CARDINAL_DIRECTIONS):
		return BlockedReason.NONE
	return _walk_direction(state, attacker, attacker.position, direction).reason


## [AttackAction]'s [code]validate()[/code] handler (ADR-0010, ADR-0002,
## TR-combat-005) — [b]pure and total[/b]: checks every failure condition,
## never mutates [param state]. Registered into [method GameState.register_verb]'s
## dispatch table by [method GameState._ensure_dispatch_registered].
##
## Checks, in order: (1) both tiles resolve to a live entity
## ([constant Action.Reason.NO_SUCH_ENTITY] otherwise); (2) the target is not
## owned by the attacker's own player ([constant Action.Reason.ILLEGAL_TARGET] —
## enemy-only, GDD Rule); (3) attacker-kind branching (ADR-0010/ADR-0017,
## Story 005): a [code]UnitState[/code] attacker is rejected iff
## [method Unit.can_attack] is false (already attacked this turn); a
## [code]StructureState[/code] attacker (the Defensive Structure) is rejected
## iff [member StructureState.has_attacked] is already [code]true[/code]; any
## other entity kind is rejected defensively. This is what makes [method apply]'s
## later [code]attacker.has_attacked = true[/code] write safe for both kinds —
## each has its own [code]has_attacked[/code] field; (4) [method AP.can_afford]
## against the attacker-kind-appropriate cost — [member CombatConfig.attack_cost]
## for a [code]UnitState[/code] attacker, the forward-declared
## [code]BaseProduction.defensive_attack_cost()[/code] for a
## [code]StructureState[/code] attacker ([constant Action.Reason.CANT_AFFORD]
## otherwise); (5) the target must appear in [method legal_targets] for the
## attacker at its real position ([constant Action.Reason.ILLEGAL_TARGET]
## otherwise — out of DIRECT/AREA range, blocked, etc.).
##
## Idempotency (ADR-0002): no dedup IDs, no seen-set. Resubmitting an already-
## applied [AttackAction] is rejected naturally at step 4 — [param action]'s
## attacker already has [code]has_attacked == true[/code] by the time this
## re-runs against current state.
##
## O(1) checks plus one [method legal_targets] call (already budgeted
## O(4 * attack_range) DIRECT / O(ring area) AREA, Stories 002/003) —
## control-manifest Performance Guardrail; runs once per submitted attack, no
## per-frame path.
static func validate(state: GameState, action: AttackAction) -> int:
	var attacker: EntityState = state.entity_at(action.attacker_tile)
	var target: EntityState = state.entity_at(action.target_tile)
	if attacker == null or target == null:
		return Action.Reason.NO_SUCH_ENTITY
	if target.owner == attacker.owner:
		return Action.Reason.ILLEGAL_TARGET
	if attacker is UnitState:
		if not Unit.can_attack(attacker):
			return Action.Reason.ILLEGAL_TARGET   # already attacked this turn
	elif attacker is StructureState:
		if attacker.has_attacked:
			return Action.Reason.ILLEGAL_TARGET   # Defensive Structure already fired this turn
	else:
		return Action.Reason.ILLEGAL_TARGET       # unknown entity kind — defensive
	var cost: int = _attack_cost_for(attacker)
	if not AP.can_afford(state, attacker.owner, cost):
		return Action.Reason.CANT_AFFORD
	var found := false
	for tr: TargetResult in legal_targets(state, attacker):
		if tr.target_id == target.entity_id:
			found = true
			break
	if not found:
		return Action.Reason.ILLEGAL_TARGET
	return Action.Reason.OK


## [AttackAction]'s [code]apply()[/code] handler (ADR-0010, ADR-0002,
## TR-combat-005/007/012) — assumes [method validate] already passed;
## [b]never fails[/b]. Spends the attacker-kind-appropriate AP cost
## ([member CombatConfig.attack_cost] for a [code]UnitState[/code] attacker,
## the forward-declared [code]BaseProduction.defensive_attack_cost()[/code]
## for a [code]StructureState[/code] attacker) via [method AP.spend], flips
## [code]attacker.has_attacked[/code] to [code]true[/code] (regardless of
## whether the resulting damage is lethal), applies primary damage via
## [method damage] routed through [method _apply_damage_to] (polymorphic: unit
## OR structure defender), then — [b]Story 005's death check[/b] — if
## [code]target.current_hp[/code] reached 0, calls
## [method GameState.destroy_entity] and appends its returned events (Grid
## removal + the destruction event, same commit).
##
## [b]Story 006's counter step[/b] then runs, unconditionally evaluated
## immediately after the primary death check: iff [code]target.current_hp > 0[/code]
## (the primary death check runs strictly [i]before[/i] this — a defender
## killed by the primary hit never counters), [code]target.type.can_counterattack
## == true[/code] (read directly off the defender's immutable template, ADR-0010,
## TR-combat-009), and [param target] is a legal target under [param target]'s
## [b]own[/b] targeting profile via [method _in_defenders_profile] (roles
## swapped — "could the defender itself legally attack the original attacker
## right now?"), the defender deals its own [method damage] (attacker/defender
## roles swapped) to the original attacker via [method _apply_damage_to] — the
## same polymorphic exit point the primary hit uses, so a countered
## [code]StructureState[/code] attacker (a Defensive Structure) is damaged
## correctly rather than crashing on a [code]UnitState[/code]-only mutator. The
## counter is [b]free[/b]: no [method AP.spend] call and no
## [code]has_attacked[/code] write on either entity anywhere in this block. If
## the counter reduces the attacker to 0 hp, [method GameState.destroy_entity]
## fires for the attacker too. Non-recursion is [b]structural[/b] (ADR-0010): this
## block is a single straight-line conditional that runs at most once per
## [method apply] call — there is no loop and no call back into [method apply]
## for the counter's own damage, so "never chains" holds by the shape of the
## code, not a runtime guard flag.
##
## O(1): [method AP.spend] + one flag write + one [method damage] call + one
## clamp + (on lethal) one O(1) [method GameState.destroy_entity] call, plus
## — the counter step — three O(1) boolean conditions, one [method legal_targets]
## call (already-budgeted O(4 * attack_range) DIRECT / O(ring area) AREA), and,
## when it fires, one more [method damage]/[method _apply_damage_to] pair and
## at most one more [method GameState.destroy_entity] call (control-manifest
## Performance Guardrail) — no new cost class, no per-frame path, runs at most
## once per committed attack.
static func apply(state: GameState, action: AttackAction) -> Array[Event]:
	var attacker: EntityState = state.entity_at(action.attacker_tile)
	var target: EntityState = state.entity_at(action.target_tile)
	var cost: int = _attack_cost_for(attacker)
	AP.spend(state, attacker.owner, cost)
	attacker.has_attacked = true
	var events: Array[Event] = []
	var dmg: int = damage(state, attacker, target)
	_apply_damage_to(target, dmg)   # polymorphic: unit OR structure defender
	if target.current_hp <= 0:
		events.append_array(state.destroy_entity(target.entity_id))
	# Story 006: conditional single counter — fires iff the defender survived
	# the primary hit, its type opts into can_counterattack, and the original
	# attacker is a legal target under the DEFENDER's own targeting profile.
	# Free (no AP, no has_attacked write); structurally non-recursive (one
	# straight-line block, never a loop or a call back into apply()).
	if target.current_hp > 0 and target.type.can_counterattack and _in_defenders_profile(state, target, attacker):
		var counter_dmg: int = damage(state, target, attacker)   # roles swapped
		_apply_damage_to(attacker, counter_dmg)                  # polymorphic — attacker may be a StructureState (Story 005)
		if attacker.current_hp <= 0:
			events.append_array(state.destroy_entity(attacker.entity_id))
	return events


## Applies [param dmg] to [param target]'s current hp, polymorphic over
## defender kind (ADR-0010) — the shared exit point [method apply] calls so it
## never needs an [code]is UnitState[/code] branch of its own. A
## [code]UnitState[/code] defender routes through [method Unit.apply_hp_delta]
## (the sole [code]current_hp[/code] mutator, ADR-0007); any other defender
## (a [code]StructureState[/code] — Base & Production owns structure hp) is
## clamped inline to [code]0 <= current_hp <= target.type.hp[/code] until that
## epic lands its own mutator ([code]TODO(base-production)[/code]).
static func _apply_damage_to(target: EntityState, dmg: int) -> void:
	if target is UnitState:
		Unit.apply_hp_delta(target, -dmg)   # unit-owned mutator (existing hp-clamp path)
	else: # StructureState — Base & Production owns structure hp; clamp inline until that epic lands
		target.current_hp = clampi(target.current_hp - dmg, 0, target.type.hp)  # TODO(base-production): structure hp mutator


## True iff [param would_be_target] is a legal target for [param defender],
## evaluated from [param defender]'s own current position under
## [param defender]'s own [code]targeting_mode[/code]/[code]attack_range[/code]/
## [code]min_range[/code] (ADR-0010, TR-combat-009) — i.e. "could
## [param defender] itself legally attack [param would_be_target] right now?"
## Backs [method apply]'s counter-step range gate: a counter only fires when
## the original attacker sits inside the [b]defender's[/b] own profile, never
## the attacker's.
##
## A one-line delegation to [method legal_targets] — [b]not[/b] a second,
## parallel range-check formula (this story's Implementation Notes are
## explicit on this point). [param defender]'s position at counter-time is
## identical to when it was struck (no movement happens mid-[method apply]),
## so the real-position zero-arg [method legal_targets] is sufficient; no
## hypothetical-tile overload is needed here.
##
## O(4 * attack_range) DIRECT / O(ring area) AREA — the cost of one
## [method legal_targets] call (control-manifest Performance Guardrail);
## called at most once per committed attack, only when the defender survived
## the primary hit and its type has [code]can_counterattack == true[/code].
static func _in_defenders_profile(state: GameState, defender: EntityState, would_be_target: EntityState) -> bool:
	for tr: TargetResult in legal_targets(state, defender):
		if tr.target_id == would_be_target.entity_id:
			return true
	return false
