# Base & Production Story 008: Determinism & Clone Isolation.
#
# Covers the acceptance criteria in
# production/epics/base-production/story-008-determinism-clone-isolation.md:
#   Group 1 (cross-clone parity) — given a state S and two independent clones
#     A = S.clone(), B = S.clone(), applying the IDENTICAL B&P action to both
#     leaves A/B field-wise equal afterward, for each of the four B&P verbs:
#       build, produce, cancel_build, structure-attack (Defensive Structure).
#   Group 2 (clone isolation) — applying an action only to C = S.clone() leaves
#     the source S field-wise identical to a pre-action snapshot (duplicate_deep
#     never lets a clone mutation leak back into the source — AI look-ahead is
#     side-effect-free), for an add (build), a remove (cancel), and a mutate
#     (structure-attack).
#   Negative sanity — the field-wise predicate _states_equal() is only ever
#     called in "should be equal" contexts above, so a latent comparator bug (a
#     forgotten field) would make every parity/isolation assertion vacuously
#     green. One test per AC field family deliberately diverges exactly one
#     field on a clone and proves the predicate reports the pair UNEQUAL:
#     current_hp, occupancy+presence, AP pool, build_status,
#     build_turns_remaining, units_produced_this_turn, has_attacked.
#
# This story adds NO production code — it pins the determinism/purity of the
# verbs shipped in Stories 002 (build) / 004 (produce) / 005 (cancel) / 006
# (structure-attack). It calls the pure verb handlers directly against
# fixture-built GameStates — NOT through GameState.apply_action() (that
# integration-level concern is Story 010's). Mirrors the Combat epic's
# tests/unit/combat/determinism_test.gd (same field-wise-predicate approach;
# extended here with the structure-specific fields build_status/
# build_turns_remaining/units_produced_this_turn and both players' AP pools).
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 12


# --- Fixture builders --------------------------------------------------------

func _make_grid() -> GridState:
	var grid := GridState.new()
	grid.width = GRID_SIZE
	grid.height = GRID_SIZE
	grid.terrain = PackedByteArray()
	grid.terrain.resize(GRID_SIZE * GRID_SIZE)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(GRID_SIZE * GRID_SIZE)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


# Both players Neutral (produce's Unit.effective_produce_cost dereferences
# state.faction_of(owner)); active_player 0 (the acting player for every verb here).
func _make_state(current_ap: int = 20, current_credits: int = 20) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		# Fund Credits too (dual-cost pivot, ADR-0006): build spends build_cost from
		# Credits + a build_ap_cost surcharge from AP.
		state.per_player[i].current_credits = current_credits
		state.per_player[i].faction = Factions.NEUTRAL
	return state


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = type.hp
	return u


func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, status: int = StructureState.BuildStatus.COMPLETED, build_turns_remaining: int = 0) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = type
	s.current_hp = type.hp
	s.build_status = status
	s.build_turns_remaining = build_turns_remaining
	return s


# A non-countering, defense-0, high-hp enemy unit — a structure-attack target
# that survives without countering, so the parity/isolation assertions aren't
# perturbed by the target dying or countering (both are deterministic anyway,
# but this keeps the fixture's intent focused on the attacker-side effects).
func _make_dummy_enemy(entity_id: int, owner: int, pos: Vector2i, hp: int = 20) -> UnitState:
	var t := UnitTypeDef.new()
	t.display_name = "Dummy"
	t.hp = hp
	t.attack = 0
	t.attack_range = 1
	t.move_cost = 1
	t.soft_move_cap = 1
	t.produce_cost = 1
	t.defense = 0
	t.can_counterattack = false
	return _make_unit(entity_id, owner, t, pos)


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _make_build_action(structure_type: StructureTypeDef, tile: Vector2i, player: int = 0) -> BuildAction:
	var a := BuildAction.new()
	a.player = player
	a.structure_type = structure_type
	a.tile = tile
	return a


func _make_produce_action(producer_id: int, unit_type: UnitTypeDef, tile: Vector2i, player: int = 0) -> ProduceAction:
	var a := ProduceAction.new()
	a.player = player
	a.producer_id = producer_id
	a.unit_type = unit_type
	a.tile = tile
	return a


func _make_cancel_action(structure_id: int, player: int = 0) -> CancelBuildAction:
	var a := CancelBuildAction.new()
	a.player = player
	a.structure_id = structure_id
	return a


func _make_attack_action(attacker_tile: Vector2i, target_tile: Vector2i, player: int = 0) -> AttackAction:
	var a := AttackAction.new()
	a.player = player
	a.attacker_tile = attacker_tile
	a.target_tile = target_tile
	return a


# --- State-equality predicate (test-local, single source of truth) -----------
#
# Pure predicate: true iff `a` and `b` are field-wise equal on exactly the
# fields the story defines — full grid.occupancy, both players' AP pools, and
# for every entity present in either state: presence/absence, position,
# current_hp, has_attacked, and (StructureState only) build_status,
# build_turns_remaining, units_produced_this_turn. Short-circuits (returns
# false) on the first mismatch; never mutates either state. The negative-sanity
# tests below prove each of these fields is actually load-bearing (a forgotten
# field would make every parity assertion vacuously green).
func _states_equal(a: GameState, b: GameState) -> bool:
	if a.grid.occupancy != b.grid.occupancy:
		return false
	if a.per_player.size() != b.per_player.size():
		return false
	for i: int in a.per_player.size():
		if a.per_player[i].current_ap != b.per_player[i].current_ap:
			return false

	var ids: Dictionary[int, bool] = {}
	for id: int in a.entities_by_id.keys():
		ids[id] = true
	for id: int in b.entities_by_id.keys():
		ids[id] = true
	var sorted_ids: Array[int] = ids.keys()
	sorted_ids.sort()

	for id: int in sorted_ids:
		var in_a: bool = a.entities_by_id.has(id)
		var in_b: bool = b.entities_by_id.has(id)
		if in_a != in_b:
			return false
		if not in_a:
			continue # absent identically in both — absence IS the equality
		var ea: EntityState = a.entities_by_id[id]
		var eb: EntityState = b.entities_by_id[id]
		if ea.position != eb.position:
			return false
		if _current_hp_of(ea) != _current_hp_of(eb):
			return false
		if _has_attacked_of(ea) != _has_attacked_of(eb):
			return false
		if (ea is StructureState) != (eb is StructureState):
			return false
		if ea is StructureState:
			var sa: StructureState = ea
			var sb: StructureState = eb
			if sa.build_status != sb.build_status:
				return false
			if sa.build_turns_remaining != sb.build_turns_remaining:
				return false
			if sa.units_produced_this_turn != sb.units_produced_this_turn:
				return false
	return true


func _assert_states_equal(a: GameState, b: GameState) -> void:
	assert_bool(_states_equal(a, b)).is_true()


# EntityState has exactly two concrete subclasses (ADR-0007) — no third branch.
func _current_hp_of(e: EntityState) -> int:
	if e is UnitState:
		return (e as UnitState).current_hp
	return (e as StructureState).current_hp


func _has_attacked_of(e: EntityState) -> bool:
	if e is UnitState:
		return (e as UnitState).has_attacked
	return (e as StructureState).has_attacked


# --- Group 1: cross-clone parity (one per B&P verb) --------------------------

func test_cross_clone_build_yields_field_wise_equal_states() -> void:
	# Arrange -- a friendly unit gives an adjacent legal build tile; two clones.
	var source := _make_state()
	_place(source, _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5)))
	var a: GameState = source.clone()
	var b: GameState = source.clone()
	var action := _make_build_action(StructureTypes.ECONOMY_OUTPOST, Vector2i(6, 5))
	# Act -- identical build on each clone.
	BaseProduction.apply_build(a, action)
	BaseProduction.apply_build(b, action)
	# Assert -- a built structure exists (non-vacuous) and A ≡ B field-wise.
	assert_object(a.entity_at(Vector2i(6, 5))).is_not_null()
	_assert_states_equal(a, b)


func test_cross_clone_produce_yields_field_wise_equal_states() -> void:
	# Arrange -- a Completed Production Outpost; two clones.
	var source := _make_state()
	_place(source, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST))
	var a: GameState = source.clone()
	var b: GameState = source.clone()
	var action := _make_produce_action(1, UnitTypes.TROOPER, Vector2i(6, 5))
	# Act
	BaseProduction.apply_produce(a, action)
	BaseProduction.apply_produce(b, action)
	# Assert -- a unit was deployed (non-vacuous) and A ≡ B (incl. producer's
	# units_produced_this_turn counter + both AP pools).
	assert_object(a.entity_at(Vector2i(6, 5))).is_not_null()
	_assert_states_equal(a, b)


func test_cross_clone_cancel_yields_field_wise_equal_states() -> void:
	# Arrange -- an Under-Construction structure to cancel; two clones (AP 0 so
	# the refund credit is observable and must match).
	var source := _make_state(0)
	_place(source, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1))
	var a: GameState = source.clone()
	var b: GameState = source.clone()
	var action := _make_cancel_action(1)
	# Act
	BaseProduction.apply_cancel(a, action)
	BaseProduction.apply_cancel(b, action)
	# Assert -- the structure was erased (non-vacuous) and A ≡ B (equal refund
	# in both AP pools + equal occupancy removal).
	assert_bool(a.entities_by_id.has(1)).is_false()
	_assert_states_equal(a, b)


func test_cross_clone_structure_attack_yields_field_wise_equal_states() -> void:
	# Arrange -- a Completed Defensive Structure + an enemy target in range; clones.
	var source := _make_state()
	_place(source, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.DEFENSIVE_STRUCTURE))
	_place(source, _make_dummy_enemy(2, 1, Vector2i(5, 6)))
	var a: GameState = source.clone()
	var b: GameState = source.clone()
	var action := _make_attack_action(Vector2i(5, 5), Vector2i(5, 6))
	# Act
	Combat.apply(a, action)
	Combat.apply(b, action)
	# Assert -- the attacker fired (has_attacked, non-vacuous) and A ≡ B (equal
	# has_attacked + AP spend + target hp).
	assert_bool((a.entities_by_id[1] as StructureState).has_attacked).is_true()
	_assert_states_equal(a, b)


# --- Group 2: clone isolation (source never mutated) -------------------------

func test_clone_isolation_build_leaves_source_unchanged() -> void:
	# Arrange
	var source := _make_state()
	_place(source, _make_unit(1, 0, UnitTypes.SCOUT, Vector2i(5, 5)))
	var snapshot: GameState = source.clone() # pre-action snapshot
	var c: GameState = source.clone()
	var action := _make_build_action(StructureTypes.ECONOMY_OUTPOST, Vector2i(6, 5))
	# Act -- build only on the clone.
	BaseProduction.apply_build(c, action)
	# Assert -- the clone gained the structure; the source is untouched (never
	# mutated by the clone's build — no aliasing leak-back).
	assert_object(c.entity_at(Vector2i(6, 5))).is_not_null()
	assert_object(source.entity_at(Vector2i(6, 5))).is_null()
	_assert_states_equal(source, snapshot)


func test_clone_isolation_cancel_leaves_source_structure_intact() -> void:
	# Arrange -- an Under-Construction structure in the source.
	var source := _make_state(0)
	_place(source, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.ECONOMY_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 1))
	var snapshot: GameState = source.clone()
	var c: GameState = source.clone()
	var action := _make_cancel_action(1)
	# Act -- cancel only on the clone.
	BaseProduction.apply_cancel(c, action)
	# Assert -- the clone erased the structure + refunded; the source still has
	# it (alive, occupying its tile) and is field-wise identical to the snapshot.
	assert_bool(c.entities_by_id.has(1)).is_false()
	assert_bool(source.entities_by_id.has(1)).is_true()
	assert_int(source.grid.occupant_at(5, 5)).is_equal(1)
	_assert_states_equal(source, snapshot)


func test_clone_isolation_structure_attack_leaves_source_unchanged() -> void:
	# Arrange
	var source := _make_state()
	_place(source, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.DEFENSIVE_STRUCTURE))
	_place(source, _make_dummy_enemy(2, 1, Vector2i(5, 6)))
	var snapshot: GameState = source.clone()
	var c: GameState = source.clone()
	var action := _make_attack_action(Vector2i(5, 5), Vector2i(5, 6))
	# Act -- attack only on the clone.
	Combat.apply(c, action)
	# Assert -- the clone reflects the attack (attacker fired, target damaged);
	# the source's attacker never fired and its target is at full hp.
	assert_bool((c.entities_by_id[1] as StructureState).has_attacked).is_true()
	assert_bool((source.entities_by_id[1] as StructureState).has_attacked).is_false()
	assert_int(source.entities_by_id[2].current_hp).is_equal((source.entities_by_id[2] as UnitState).type.hp)
	_assert_states_equal(source, snapshot)


# --- Negative sanity: _states_equal() detects a single-field divergence -------
#
# One test per AC field family. Each clones a base twice (the pair starts equal),
# mutates exactly ONE field on `diverged`, and asserts the predicate reports the
# pair unequal — proving that field is actually compared (not vacuously green).

# A base carrying every field the predicate inspects: a placed Under-Construction
# Production Outpost (build_status / build_turns_remaining / units_produced_this_turn
# / has_attacked / current_hp) + nonzero AP pools + grid occupancy.
func _negative_base() -> GameState:
	var state := _make_state(7)
	_place(state, _make_structure(1, 0, Vector2i(5, 5), StructureTypes.PRODUCTION_OUTPOST, StructureState.BuildStatus.UNDER_CONSTRUCTION, 2))
	return state


func test_predicate_detects_current_hp_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	(diverged.entities_by_id[1] as StructureState).current_hp -= 1
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_occupancy_and_presence_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	diverged.grid.remove(5, 5)
	diverged.entities_by_id.erase(1)
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_ap_pool_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	diverged.per_player[0].current_ap -= 1
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_build_status_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	(diverged.entities_by_id[1] as StructureState).build_status = StructureState.BuildStatus.COMPLETED
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_build_turns_remaining_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	(diverged.entities_by_id[1] as StructureState).build_turns_remaining -= 1
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_units_produced_this_turn_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	(diverged.entities_by_id[1] as StructureState).units_produced_this_turn += 1
	assert_bool(_states_equal(base, diverged)).is_false()


func test_predicate_detects_has_attacked_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	(diverged.entities_by_id[1] as StructureState).has_attacked = true
	assert_bool(_states_equal(base, diverged)).is_false()


# `position` is not mutated by any B&P verb under test (build/produce place NEW
# entities; cancel removes one; structure-attack moves no one), so a dropped
# position comparison wouldn't false-green the parity/isolation tests today —
# but the predicate DOES compare it, so pin it too (regression-proofs the
# predicate for a future relocating verb, e.g. knockback). Diverge only the
# entity's `position` field, leaving grid occupancy identical, so this isolates
# the position comparison from the occupancy comparison.
func test_predicate_detects_position_divergence() -> void:
	var base: GameState = _negative_base().clone()
	var diverged: GameState = base.clone()
	assert_bool(_states_equal(base, diverged)).is_true()
	diverged.entities_by_id[1].position = Vector2i(6, 6)
	assert_bool(_states_equal(base, diverged)).is_false()
