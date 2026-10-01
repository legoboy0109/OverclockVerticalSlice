# Construction-site sprite (user decision 2026-09-30): every structure UNDER_CONSTRUCTION draws
# one shared generic site sprite until it completes, then its own art.
extends GdUnitTestSuite


func _structure(type: StructureTypeDef, status: int) -> StructureState:
	var st := StructureState.new()
	st.entity_id = 1
	st.owner = 0
	st.type = type
	st.current_hp = type.hp
	st.build_status = status
	return st


func test_construction_site_uses_the_shared_site_sprite() -> void:
	for type: StructureTypeDef in [StructureTypes.FACTORY, StructureTypes.BARRACKS]:
		var st := _structure(type, StructureState.BuildStatus.UNDER_CONSTRUCTION)
		var path: String = EntitySpriteCatalog.texture_path(st, Factions.NEUTRAL, "e")
		assert_str(path).is_equal("%sstruct_construction_neutral_idle.png" % EntitySpriteCatalog.STRUCTURES_DIR)
		assert_str(EntityGlow.mask_path(st, "e")).is_equal(
			"%sstruct_construction_idle_glow.png" % EntitySpriteCatalog.STRUCTURES_DIR)


func test_completed_structure_uses_its_own_sprite() -> void:
	var st := _structure(StructureTypes.FACTORY, StructureState.BuildStatus.COMPLETED)
	var token: String = EntitySpriteCatalog.type_token_for(StructureTypes.FACTORY)
	assert_str(EntitySpriteCatalog.texture_path(st, Factions.NEUTRAL, "e")).contains("struct_%s_" % token)


func test_completing_construction_switches_the_sprite() -> void:
	var st := _structure(StructureTypes.BARRACKS, StructureState.BuildStatus.UNDER_CONSTRUCTION)
	var before: String = EntitySpriteCatalog.texture_path(st, Factions.NEUTRAL, "e")
	st.build_status = StructureState.BuildStatus.COMPLETED
	assert_str(EntitySpriteCatalog.texture_path(st, Factions.NEUTRAL, "e")).is_not_equal(before)


func test_construction_site_art_ships_for_every_hue_and_state() -> void:
	# Without this a site would render as the magenta missing-art placeholder.
	var dir: String = EntitySpriteCatalog.STRUCTURES_DIR
	for hue: String in ["rush", "boom", "neutral"]:
		for state: String in ["idle", "destroyed"]:
			var path: String = "%sstruct_construction_%s_%s.png" % [dir, hue, state]
			assert_bool(ResourceLoader.exists(path)).override_failure_message("missing " + path).is_true()
	assert_bool(ResourceLoader.exists("%sstruct_construction_idle_glow.png" % dir)).is_true()
