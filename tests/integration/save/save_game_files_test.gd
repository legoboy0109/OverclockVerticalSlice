# Save files on disk: write, read back, list, delete. Uses its own slot name and removes it,
# so it never touches a real autosave or manual slot.
extends GdUnitTestSuite

const SLOT: String = "test_slot"


func after_test() -> void:
	SaveGame.delete(SLOT)


func _state() -> GameState:
	var map: MapDefinition = load("res://data/maps/vertical_slice.tres")
	VSMap.select(map)
	return MatchSetup.build(map, [Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef],
		0, 80, [1])


func test_a_written_save_reads_back() -> void:
	var state := _state()
	assert_int(SaveGame.write(SLOT, state)).is_equal(OK)
	assert_bool(SaveGame.exists(SLOT)).is_true()
	var loaded := SaveGame.read(SLOT)
	assert_object(loaded).is_not_null()
	assert_str(JSON.stringify(SaveGame._encode_object(loaded.state))) \
		.is_equal(JSON.stringify(SaveGame._encode_object(state)))


func test_no_temporary_file_is_left_behind() -> void:
	SaveGame.write(SLOT, _state())
	assert_bool(FileAccess.file_exists(SaveGame.path_for(SLOT) + ".tmp")).is_false()


func test_slot_info_reads_the_label_without_loading_the_match() -> void:
	var state := _state()
	SaveGame.write(SLOT, state)
	var info := SaveGame.info(SLOT)
	assert_bool(info.exists).is_true()
	assert_str(info.label).is_equal(SaveGame.describe(state, VSMap.data()))
	assert_int(info.saved_at).is_greater(0)


func test_an_empty_slot_reports_empty() -> void:
	SaveGame.delete(SLOT)
	assert_bool(SaveGame.info(SLOT).exists).is_false()
	assert_object(SaveGame.read(SLOT)).is_null()


func test_a_corrupt_file_is_rejected_not_crashed_on() -> void:
	DirAccess.make_dir_recursive_absolute(SaveGame.dir())
	var f := FileAccess.open(SaveGame.path_for(SLOT), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	assert_object(SaveGame.read(SLOT)).is_null()


func test_tests_never_write_to_the_players_save_folder() -> void:
	assert_str(SaveGame.dir()).is_not_equal("user://saves")


func test_delete_removes_the_slot() -> void:
	SaveGame.write(SLOT, _state())
	SaveGame.delete(SLOT)
	assert_bool(SaveGame.exists(SLOT)).is_false()
