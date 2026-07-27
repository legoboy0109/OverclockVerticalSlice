# Base & Production Story 007: Structure Destruction & HQ Win-Hook (real-schema coverage).
#
# Covers the acceptance criteria in
# production/epics/base-production/story-007-structure-destruction-hq-win-hook.md
# against the REAL StructureState schema (Story 001) — the already-shipped
# GameState.destroy_entity / StructureDestroyedEvent{is_hq} / run_win_check /
# cover-immunity (Combat epic, Story 005) re-verified with real registry types:
#   - a real StructureState at 0 hp -> Destroyed: erased from entities_by_id and
#     GridState.remove() run for its tile the same step (tile empties);
#   - an HQ (StructureTypes.HQ) lethally hit -> the resolution raises an
#     observable StructureDestroyedEvent{is_hq == true}, which run_win_check
#     turns into match_status == GameOver, winner == opponent;
#   - a non-HQ structure lethally hit -> StructureDestroyedEvent{is_hq == false},
#     no win-signal (run_win_check leaves the match IN_PROGRESS);
#   - a StructureState defender is cover-immune: cover_reduction is always 0
#     whatever tile it stands on (an equivalent UNIT on the same Cover tile IS
#     reduced, proving cover_dr is live — the immunity is structure-specific).
#
# This story does NOT re-implement destroy_entity; it is real-schema coverage in
# the B&P suite (Combat's own structure tests build their structures locally).
# Cross-referenced, not duplicated: Combat's targeting/counter/damage-formula ACs.
#
# GameState.destroy_entity()/run_win_check() and Combat.validate()/apply()/damage()
# are called directly against a hand-built GameStateFactory state with real (not
# mocked) AP/GridState, mirroring tests/unit/combat/destroy_entity_test.gd's style.
#
# No RNG, no time-dependent asserts, no file I/O; each test builds its own
# isolated state. Naming follows tests/README.md:
# [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite

const GRID_SIZE: int = 8


# The attacker's effective_attack reads the process-global Research stub bonus
# only when its owner holds Attack Tech (none here) — reset for isolation anyway,
# matching the suite convention (tests/unit/effective_attack_test.gd).
func before_test() -> void:
	Research.reset()


func after_test() -> void:
	Research.reset()


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


func _make_state(current_ap: int = 5) -> GameState:
	var state := GameStateFactory.make_state(2, 0)
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = current_ap
		state.per_player[i].faction = Factions.NEUTRAL
	return state


# A real StructureState from the registry template (type carries the real hp/
# defense/is_hq identity). current_hp is set explicitly so a test can make it
# lethally low without depending on the template's full hp.
func _make_structure(entity_id: int, owner: int, pos: Vector2i, type: StructureTypeDef, current_hp: int = -1, status: int = StructureState.BuildStatus.COMPLETED) -> StructureState:
	var s := StructureState.new()
	s.entity_id = entity_id
	s.owner = owner
	s.position = pos
	s.type = type
	s.current_hp = current_hp if current_hp >= 0 else type.hp
	s.build_status = status
	return s


func _make_unit(entity_id: int, owner: int, type: UnitTypeDef, pos: Vector2i, current_hp: int = -1) -> UnitState:
	var u := UnitState.new()
	u.entity_id = entity_id
	u.owner = owner
	u.position = pos
	u.type = type
	u.current_hp = current_hp if current_hp >= 0 else type.hp
	return u


func _place(state: GameState, entity: EntityState) -> void:
	state.grid.place(entity.entity_id, entity.position.x, entity.position.y)
	state.entities_by_id[entity.entity_id] = entity


func _make_attack(attacker_tile: Vector2i, target_tile: Vector2i, player: int) -> AttackAction:
	var action := AttackAction.new()
	action.player = player
	action.attacker_tile = attacker_tile
	action.target_tile = target_tile
	return action


# --- AC-destruction (Rule 9): 0 hp -> Destroyed + Grid remove, same step -----

func test_real_structure_destroyed_erased_from_entities_and_grid_same_step() -> void:
	# Arrange -- a real (non-HQ) StructureState placed on the board.
	var state := _make_state()
	var tile := Vector2i(4, 4)
	var struct := _make_structure(1, 0, tile, StructureTypes.ECONOMY_OUTPOST)
	_place(state, struct)
	# Act -- the shared mutation-layer destruction (what Combat.apply calls at 0 hp).
	var events: Array[Event] = state.destroy_entity(struct.entity_id)
	# Assert -- erased from entities_by_id AND the grid, same call (tile empties).
	assert_bool(state.entities_by_id.has(struct.entity_id)).is_false()
	assert_object(state.entity_at(tile)).is_null()
	assert_int(state.grid.occupant_at(tile.x, tile.y)).is_equal(GridState.EMPTY_OCCUPANT)
	# One StructureDestroyedEvent (not a UnitDestroyedEvent — real StructureState).
	assert_int(events.size()).is_equal(1)
	assert_bool(events[0] is StructureDestroyedEvent).is_true()
	var evt: StructureDestroyedEvent = events[0]
	assert_int(evt.entity_id).is_equal(struct.entity_id)
	assert_int(evt.owner).is_equal(0)
	assert_bool(evt.is_hq).is_false() # Economy Outpost is not an HQ


# --- AC-hq-win-signal: HQ at 0 hp -> observable is_hq signal, drives GameOver -

func test_hq_lethally_hit_resolution_raises_is_hq_win_signal_and_run_win_check_sets_gameover() -> void:
	# Arrange -- player 0's Heavy adjacent to player 1's real HQ (current_hp 1 so
	# the single hit is lethal); Heavy attack 5, HQ defense 2, range 1.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	var hq := _make_structure(2, 1, Vector2i(4, 3), StructureTypes.HQ, 1)
	_place(state, heavy)
	_place(state, hq)
	var action := _make_attack(heavy.position, hq.position, 0)
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)
	# Act -- the resolution brings the HQ to 0 hp and destroys it.
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- the HQ is gone, and the commit carries the is_hq win-signal.
	assert_object(state.entity_at(hq.position)).is_null()
	var hq_destroyed := false
	for e: Event in events:
		if e is StructureDestroyedEvent and e.is_hq:
			hq_destroyed = true
			assert_int(e.owner).is_equal(1) # the destroyed HQ's owner
	assert_bool(hq_destroyed).is_true()
	# The signal drives the win: run_win_check keys off the event (no hp re-scan),
	# setting GameOver with the opponent (player 0) as winner.
	state.run_win_check(events)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.GAME_OVER)
	assert_int(state.winner).is_equal(0)


# --- AC-non-hq-no-signal: non-HQ structure at 0 hp -> no win-signal ----------

func test_non_hq_structure_lethally_hit_raises_no_win_signal() -> void:
	# Arrange -- player 0's Heavy adjacent to player 1's real (non-HQ) Defensive
	# Structure, current_hp 1 so lethal.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	var struct := _make_structure(2, 1, Vector2i(4, 3), StructureTypes.DEFENSIVE_STRUCTURE, 1)
	_place(state, heavy)
	_place(state, struct)
	var action := _make_attack(heavy.position, struct.position, 0)
	assert_int(Combat.validate(state, action)).is_equal(Action.Reason.OK)
	# Act
	var events: Array[Event] = Combat.apply(state, action)
	# Assert -- the structure is destroyed, but the event carries is_hq == false,
	# so run_win_check raises no terminal condition.
	assert_object(state.entity_at(struct.position)).is_null()
	var saw_non_hq_destroyed := false
	for e: Event in events:
		if e is StructureDestroyedEvent:
			saw_non_hq_destroyed = true
			assert_bool(e.is_hq).is_false()
	assert_bool(saw_non_hq_destroyed).is_true()
	state.run_win_check(events)
	assert_int(state.match_status).is_equal(GameState.MatchStatus.IN_PROGRESS)
	assert_int(state.winner).is_equal(-1)


# --- AC-cover-immunity: a StructureState defender gets no cover reduction -----

func test_structure_defender_is_cover_immune_unit_on_same_cover_is_not() -> void:
	# Arrange -- an HQ (defense 2) standing on a Cover tile, attacked by a Heavy
	# (attack 5). Structures are cover-immune, so the HQ mitigates exactly its
	# own defense (2), never defense + cover.
	var state := _make_state()
	var heavy := _make_unit(1, 0, UnitTypes.HEAVY, Vector2i(3, 3))
	var cover_tile := Vector2i(4, 3)
	state.grid.terrain[state.grid.index(cover_tile.x, cover_tile.y)] = GridState.Terrain.COVER
	var hq := _make_structure(2, 1, cover_tile, StructureTypes.HQ)
	# Control -- an equivalent UNIT (defense 2) on the SAME cover tile geometry.
	var tanky_type := UnitTypeDef.new()
	tanky_type.display_name = "Tanky"
	tanky_type.hp = 20
	tanky_type.attack = 0
	tanky_type.attack_range = 1
	tanky_type.move_cost = 1
	tanky_type.soft_move_cap = 1
	tanky_type.produce_cost = 1
	tanky_type.defense = 2 # same as HQ, so the only difference is cover applicability
	var unit_on_cover := _make_unit(3, 1, tanky_type, cover_tile)
	# Act / Assert -- Combat.damage is a pure function (no placement needed); it
	# reads the defender's own tile for cover.
	# HQ on cover: 5 - 0(cover-immune) - 2(defense) = 3. Mitigation exactly 2, never 3.
	assert_int(Combat.damage(state, heavy, hq)).is_equal(5 - 2)
	# Differential control -- the same-defense UNIT on the SAME cover tile IS
	# reduced by cover_dr (1): 5 - 1 - 2 = 2. This proves cover_dr is live and
	# nonzero here, so the HQ's higher damage is a real "structure ignores cover",
	# not "cover does nothing".
	assert_int(Combat.damage(state, heavy, unit_on_cover)).is_equal(5 - CombatBalance.combat.cover_dr - 2)
	assert_bool(Combat.damage(state, heavy, hq) > Combat.damage(state, heavy, unit_on_cover)).is_true()
	# And the structure takes the SAME damage whether on Cover or Plain (cover
	# confers nothing to it) -- move the HQ's tile to Plain and re-measure.
	var hq_on_plain := _make_structure(4, 1, Vector2i(6, 6), StructureTypes.HQ) # (6,6) is Plain
	assert_int(Combat.damage(state, heavy, hq_on_plain)).is_equal(Combat.damage(state, heavy, hq))
