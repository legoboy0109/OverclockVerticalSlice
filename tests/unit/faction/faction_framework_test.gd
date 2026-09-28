# Faction framework v2 (design/gdd/faction-identity.md) — factions own content, colour is the
# seat, and one MatchSetup builds every match.
extends GdUnitTestSuite


func _map() -> MapDefinition:
	return VSMap.build()


func test_the_alliance_is_playable_and_owns_the_base_roster() -> void:
	var a: FactionDef = Factions.DEMOCRATIC_ALLIANCE
	assert_bool(a.playable).is_true()
	var units: Array[UnitTypeDef] = Faction.units(a)
	for t: UnitTypeDef in [UnitTypes.BUILDER, UnitTypes.SCOUT, UnitTypes.TROOPER, UnitTypes.HEAVY,
			UnitTypes.SNIPER, UnitTypes.TANK, UnitTypes.FIGHTER, UnitTypes.TRANSPORT]:
		assert_bool(units.has(t)).override_failure_message("Alliance cannot field %s." % t.display_name).is_true()


func test_seat_palettes_are_not_playable_factions() -> void:
	for f: FactionDef in [Factions.RUSH, Factions.BOOM, Factions.NEUTRAL]:
		assert_bool(Factions.playable().has(f)).is_false()


func test_the_baseline_modifies_nothing() -> void:
	# faction-democratic-alliance AC-1: the regression anchor — every MOD delta is 0.
	var a: FactionDef = Factions.DEMOCRATIC_ALLIANCE
	assert_int(a.infantry_cap_delta).is_equal(0)
	assert_int(a.base_income_delta).is_equal(0)
	assert_int(a.upkeep_pct_delta).is_equal(0)
	assert_array(a.unit_deltas).is_empty()


func test_match_setup_gives_each_seat_its_factions_hq_and_builder() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
	assert_object(state.faction_of(0)).is_same(Factions.DEMOCRATIC_ALLIANCE)
	var hqs: int = 0
	var builders: int = 0
	for e: EntityState in state.entities():
		if e is StructureState and (e as StructureState).is_hq():
			hqs += 1
		elif e is UnitState and (e as UnitState).type == UnitTypes.BUILDER:
			builders += 1
	assert_int(hqs).is_equal(2)
	assert_int(builders).is_equal(2)
	assert_int(state.max_rounds).is_equal(80)
	assert_bool(state.per_player[1].is_ai_controlled).is_true()


func test_match_setup_honours_who_moves_first() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 1, 80)
	assert_int(state.active_player).is_equal(1)
	assert_int(state.starting_player).is_equal(1)


func test_a_faction_only_builds_its_own_structures() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
	var narrow := FactionDef.new()
	narrow.structures = [StructureTypes.BARRACKS]
	state.per_player[0].faction = narrow
	assert_array(Faction.buildable(state, 0)).is_equal([StructureTypes.BARRACKS])
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = StructureTypes.FACTORY
	assert_int(BaseProduction.validate_build(state, a)).is_equal(Action.Reason.ILLEGAL_TARGET)


func test_mod_domains_fold_into_their_owning_systems() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
	var cap: int = Population.effective_cap(state, 0)
	var income: int = Credits.credit_income(state, 0)
	var f := FactionDef.new()
	f.infantry_cap_delta = 2
	f.base_income_delta = 300
	state.per_player[0].faction = f
	assert_int(Population.effective_cap(state, 0)).is_equal(cap + 2)
	assert_int(Credits.credit_income(state, 0)).is_equal(income + 300)


func test_an_upkeep_delta_scales_upkeep() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.DEMOCRATIC_ALLIANCE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
	var base: int = Upkeep.total_upkeep(state, 0)
	assert_int(base).override_failure_message("Fixture: the starting Builder should cost upkeep.").is_greater(0)
	var f := FactionDef.new()
	f.upkeep_pct_delta = 50
	state.per_player[0].faction = f
	assert_int(Upkeep.total_upkeep(state, 0)).is_equal(base * 150 / 100)


func test_a_match_ap_choice_never_touches_the_shipped_config() -> void:
	Balance.apply_match(33)
	assert_int(Balance.economy.flat_ap_per_turn).is_equal(33)
	assert_int(Balance.base_economy.flat_ap_per_turn).is_not_equal(33)
	Balance.reset()
	assert_object(Balance.economy).is_same(Balance.base_economy)


func test_match_settings_default_to_a_playable_faction_and_shipped_values() -> void:
	var m := MatchSettings.defaults()
	assert_bool(m.factions[0].playable).is_true()
	assert_int(m.ap_per_turn).is_equal(Balance.base_economy.flat_ap_per_turn)
	assert_int(m.round_limit).is_equal(VerticalSliceRoot.VS_MAX_ROUNDS)


func test_the_setup_screen_steps_and_clamps_its_settings() -> void:
	var screen: SkirmishSetup = auto_free(SkirmishSetup.new())
	add_child(screen)
	await get_tree().process_frame
	var ap: int = screen.settings().ap_per_turn
	screen._step(2, 1)
	assert_int(screen.settings().ap_per_turn).is_equal(mini(ap + 1, MatchSettings.AP_MAX))
	for i: int in 100:
		screen._step(3, -1)
	assert_int(screen.settings().round_limit).is_equal(MatchSettings.ROUNDS_MIN)
	screen._step(4, 1)
	assert_int(screen.settings().first_mover).is_equal(MatchSettings.FirstMover.AI)
