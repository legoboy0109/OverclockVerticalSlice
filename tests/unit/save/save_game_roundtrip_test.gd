# Save/load round trip (user decision 2026-09-29: autosave + manual slots). No file I/O here —
# the dictionary <-> state path only; tests/integration/save/ covers the files.
#
# The central proof: a match played for real by the AI on both seats, saved and loaded, is
# IDENTICAL to the original — and stays identical when both copies keep playing. Anything the
# save lost (a cooldown, a pilot, a research timer) would make the two games diverge.
extends GdUnitTestSuite

const TURNS_BEFORE_SAVE: int = 24
const TURNS_AFTER_LOAD: int = 12


func _map() -> MapDefinition:
	var map: MapDefinition = load("res://data/maps/vertical_slice.tres")
	VSMap.select(map)
	return map


## Solar (pilots, transports) against the Empire (merit, ranks) exercises the most state.
func _played_match(turns: int) -> GameState:
	var state: GameState = MatchSetup.build(_map(),
		[Factions.SOLAR_FEDERATION, Factions.HOLY_COSMIC_EMPIRE] as Array[FactionDef], 0, 80, [0, 1])
	_play(state, turns)
	return state


func _play(state: GameState, turns: int) -> void:
	for t: int in turns:
		if state.match_status == GameState.MatchStatus.GAME_OVER:
			return
		for i: int in 60:
			var action: Action = AI.choose_action(state, 0)
			if action == null:
				break
			state.apply_action(action)
			if state.match_status == GameState.MatchStatus.GAME_OVER:
				return
		var end := EndTurnAction.new()
		end.player = state.active_player
		state.apply_action(end)


func _through_json(state: GameState, map: MapDefinition) -> SaveGame.Loaded:
	var text: String = JSON.stringify(SaveGame.to_dict(state, 20, map))
	return SaveGame.from_dict(JSON.parse_string(text))


func _canonical(state: GameState) -> String:
	return JSON.stringify(SaveGame._encode_object(state))


## Every difference between two states, found by walking the live objects directly — deliberately
## NOT through SaveGame's encoder, which would drop the same fields from both sides and hide a loss
## (exactly what the first version of these tests did).
func _differences(a: Variant, b: Variant, where: String = "state") -> Array[String]:
	var out: Array[String] = []
	if typeof(a) != typeof(b):
		out.append("%s: type %s vs %s" % [where, type_string(typeof(a)), type_string(typeof(b))])
		return out
	match typeof(a):
		TYPE_OBJECT:
			if a == null or b == null:
				if a != b:
					out.append("%s: null vs object" % where)
				return out
			if a is Resource and (a as Resource).resource_path.begins_with("res://"):
				if a != b:
					out.append("%s: %s vs %s" % [where, (a as Resource).resource_path, (b as Resource).resource_path])
				return out
			for p: Dictionary in (a as Object).get_property_list():
				if int(p["usage"]) & PROPERTY_USAGE_STORAGE and int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					out.append_array(_differences(a.get(p["name"]), b.get(p["name"]), where + "." + p["name"]))
		TYPE_ARRAY:
			if (a as Array).size() != (b as Array).size():
				out.append("%s: %d vs %d items" % [where, a.size(), b.size()])
				return out
			for i: int in a.size():
				out.append_array(_differences(a[i], b[i], "%s[%d]" % [where, i]))
		TYPE_DICTIONARY:
			if (a as Dictionary).size() != (b as Dictionary).size():
				out.append("%s: %d vs %d keys" % [where, a.size(), b.size()])
				return out
			for k: Variant in a:
				if not (b as Dictionary).has(k):
					out.append("%s: key %s missing" % [where, k])
				else:
					out.append_array(_differences(a[k], b[k], "%s[%s]" % [where, k]))
		_:
			if a != b:
				out.append("%s: %s vs %s" % [where, a, b])
	return out


## Puts a non-default value in every kind of field, so a field the save forgets cannot hide
## behind its default: merit/rank, ability tallies, fortify, a pilot and a passenger.
func _stamp_unusual_values(state: GameState) -> void:
	var units: Array[UnitState] = []
	for e: EntityState in state.entities():
		if e is UnitState:
			units.append(e)
	var u: UnitState = units[0]
	u.merit = 7
	u.rank = 2
	u.fortify = 3
	u.cooldowns[&"fortify"] = 2
	u.uses[&"self_destruct"] = 1
	var pilot := UnitState.new()
	pilot.entity_id = state.next_entity_id
	pilot.owner = u.owner
	pilot.type = UnitTypes.PILOT
	pilot.current_hp = 1
	pilot.merit = 4
	state.next_entity_id += 1
	u.pilot = pilot
	var rider := UnitState.new()
	rider.entity_id = state.next_entity_id
	rider.owner = u.owner
	rider.type = UnitTypes.TROOPER
	rider.current_hp = 5
	state.next_entity_id += 1
	u.cargo.append(rider)


func test_a_played_match_survives_a_save_and_load_unchanged() -> void:
	var state := _played_match(TURNS_BEFORE_SAVE)
	_stamp_unusual_values(state)
	var loaded := _through_json(state, VSMap.data())
	assert_object(loaded).is_not_null()
	var diffs: Array[String] = _differences(state, loaded.state)
	assert_array(diffs).override_failure_message("Lost in the save: %s" % ", ".join(diffs.slice(0, 8))).is_empty()


func test_the_fixture_is_not_trivial() -> void:
	# Positive control: the round trip above only means something if the match has depth.
	var state := _played_match(TURNS_BEFORE_SAVE)
	assert_int(state.entities().size()).is_greater(6)
	assert_int(state.round_number).is_greater(5)


func test_a_loaded_match_plays_on_exactly_like_the_original() -> void:
	var state := _played_match(TURNS_BEFORE_SAVE)
	var loaded := _through_json(state, VSMap.data())
	var original: GameState = state.clone()
	_play(original, TURNS_AFTER_LOAD)
	_play(loaded.state, TURNS_AFTER_LOAD)
	var diffs: Array[String] = _differences(original, loaded.state)
	assert_array(diffs).override_failure_message(
		"After loading, the match played out differently — something was not saved: %s" % ", ".join(diffs.slice(0, 8))) \
		.is_empty()


func test_shared_game_data_comes_back_as_the_same_objects() -> void:
	var state := _played_match(4)
	var loaded := _through_json(state, VSMap.data())
	assert_object(loaded.state.per_player[0].faction).is_same(Factions.SOLAR_FEDERATION)
	var hqs: int = 0
	for e: EntityState in loaded.state.entities():
		if e is StructureState and (e as StructureState).is_hq():
			hqs += 1
	assert_int(hqs).override_failure_message("is_hq() compares by identity; the HQs must still be found.").is_equal(2)


func test_the_settings_outside_the_state_come_back() -> void:
	var state := _played_match(2)
	var map: MapDefinition = VSMap.data()
	var loaded := SaveGame.from_dict(JSON.parse_string(JSON.stringify(SaveGame.to_dict(state, 27, map))))
	assert_int(loaded.ap_per_turn).is_equal(27)
	assert_object(loaded.map).is_same(map)


func test_a_reference_outside_the_game_data_is_refused() -> void:
	var state := _played_match(2)
	var text: String = JSON.stringify(SaveGame.to_dict(state, 20, VSMap.data()))
	text = text.replace("res://data/factions/solar_federation.tres", "res://src/core/save/save_game.gd")
	assert_object(SaveGame.from_dict(JSON.parse_string(text))).override_failure_message(
		"A save pointing outside res://data/ must be rejected whole.").is_null()


func test_a_save_from_a_newer_version_is_refused() -> void:
	var d: Dictionary = SaveGame.to_dict(_played_match(1), 20, VSMap.data())
	d["version"] = SaveGame.VERSION + 1
	assert_object(SaveGame.from_dict(d)).is_null()


func test_a_field_missing_from_an_older_save_keeps_its_default() -> void:
	var d: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.to_dict(_played_match(1), 20, VSMap.data())))
	(d["state"] as Dictionary).erase("tiebreak_metric")
	var loaded := SaveGame.from_dict(d)
	assert_object(loaded).is_not_null()
	assert_int(loaded.state.tiebreak_metric).is_equal(GameState.new().tiebreak_metric)


func test_the_label_names_map_factions_and_round() -> void:
	var state := _played_match(3)
	var label: String = SaveGame.describe(state, VSMap.data())
	assert_str(label).contains(VSMap.data().display_name)
	assert_str(label).contains("Solar Federation")
	assert_str(label).contains("round %d" % state.round_number)
