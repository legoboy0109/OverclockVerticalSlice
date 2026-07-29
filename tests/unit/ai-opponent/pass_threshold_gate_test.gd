# S4-09 — AI.choose_action enforces AIBalance.ai.pass_threshold (previously defined
# but never applied), plus a structural check that the AP counter uses an ASCII arrow
# (the fallback font has no U+2192 glyph → tofu box).
extends GdUnitTestSuite

const GRID_SIZE: int = 12

var _saved_pass_threshold: float


func before_test() -> void:
	_saved_pass_threshold = AIBalance.ai.pass_threshold


func after_test() -> void:
	AIBalance.ai.pass_threshold = _saved_pass_threshold


func _make_grid() -> GridState:
	var g := GridState.new()
	g.width = GRID_SIZE
	g.height = GRID_SIZE
	g.terrain = PackedByteArray(); g.terrain.resize(GRID_SIZE * GRID_SIZE); g.terrain.fill(GridState.Terrain.PLAIN)
	g.occupancy = PackedInt32Array(); g.occupancy.resize(GRID_SIZE * GRID_SIZE); g.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return g


# Player 1 (the AI) owns a lone Trooper whose ONLY available action is a bare 1-tile
# positional advance (score = positional_value_per_tile_closed = 0.16). AP is capped
# at 3 so an economy-outpost build (cost 4) is unaffordable — leaving just the move —
# and the enemy is far enough (dist 20 >> the Trooper's reach 5) that no
# setup-advance bonus applies, so the single candidate scores exactly 0.16.
func _make_lone_advance_state() -> GameState:
	var state := GameStateFactory.make_state(2, 1) # active_player = 1
	state.grid = _make_grid()
	for i: int in state.per_player.size():
		state.per_player[i].current_ap = 3 # enough for a 1-tile Trooper move (cost 2), not a build (cost 4)
		state.per_player[i].faction = Factions.NEUTRAL
	var ai_unit := UnitState.new()
	ai_unit.entity_id = 1; ai_unit.owner = 1; ai_unit.position = Vector2i(11, 9)
	ai_unit.type = UnitTypes.TROOPER; ai_unit.current_hp = UnitTypes.TROOPER.hp
	var enemy := UnitState.new()
	enemy.entity_id = 2; enemy.owner = 0; enemy.position = Vector2i(0, 0) # dist 20 — far outside reach/setup
	enemy.type = UnitTypes.TROOPER; enemy.current_hp = UnitTypes.TROOPER.hp
	for e: EntityState in [ai_unit, enemy]:
		state.entities_by_id[e.entity_id] = e
		state.grid.place(e.entity_id, e.position.x, e.position.y)
		if e.entity_id >= state.next_entity_id:
			state.next_entity_id = e.entity_id + 1
	return state


func test_choose_action_returns_null_when_best_is_below_pass_threshold() -> void:
	# Raise the floor above the lone 0.16 advance → the candidate no longer clears it,
	# so choose_action returns null (the driver's documented termination exit).
	AIBalance.ai.pass_threshold = 0.5
	var state := _make_lone_advance_state()
	assert_object(AI.choose_action(state, 0)).is_null()


func test_choose_action_returns_the_action_when_it_clears_pass_threshold() -> void:
	# Default floor 0.15: the 0.16 advance clears it (config sets moves just above the
	# floor by design) → a real action is returned.
	AIBalance.ai.pass_threshold = 0.15
	var state := _make_lone_advance_state()
	var action: Action = AI.choose_action(state, 0)
	assert_object(action).is_not_null()
	assert_bool(action is MoveAction).is_true()


func test_pass_threshold_boundary_is_inclusive_reject() -> void:
	# A candidate scoring EXACTLY at the threshold is rejected (<=, not <): set the
	# floor to the advance's own 0.16 score → filtered → null.
	AIBalance.ai.pass_threshold = AIBalance.ai.positional_value_per_tile_closed # 0.16
	var state := _make_lone_advance_state()
	assert_object(AI.choose_action(state, 0)).is_null()


func test_ap_counter_widget_uses_ascii_arrow_not_a_tofu_glyph() -> void:
	# The AP-counter echo must not use U+2192 (no glyph in the engine fallback font →
	# renders as a .notdef square).
	var f: FileAccess = FileAccess.open("res://src/ui/game_hud/ap_counter_widget.gd", FileAccess.READ)
	assert_object(f).is_not_null()
	var src: String = f.get_as_text()
	f.close()
	assert_bool(src.contains("→")).is_false()
