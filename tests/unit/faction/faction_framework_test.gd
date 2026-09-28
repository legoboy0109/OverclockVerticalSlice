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


func test_a_trained_pilot_makes_the_vehicle_hit_harder() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.SOLAR_FEDERATION, Factions.SOLAR_FEDERATION] as Array[FactionDef], 0, 80)
	var truck := UnitState.new()
	truck.entity_id = 300
	truck.owner = 0
	truck.position = Vector2i(5, 1)
	truck.type = UnitTypes.GUN_TRUCK
	truck.current_hp = truck.type.hp
	var trooper := UnitState.new()
	trooper.type = UnitTypes.TROOPER
	truck.pilot = trooper
	var plain: int = Unit.effective_attack(state, truck)
	var pilot := UnitState.new()
	pilot.type = UnitTypes.PILOT
	truck.pilot = pilot
	assert_int(Unit.effective_attack(state, truck)).is_equal(plain + UnitTypes.PILOT.crew_bonus_attack)


func test_solar_is_poorer_with_a_shallower_economy_slope() -> void:
	var state := MatchSetup.build(_map(),
		[Factions.SOLAR_FEDERATION, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)
	assert_int(Credits.credit_income(state, 1) - Credits.credit_income(state, 0)).is_equal(200)
	state.per_player[0].economy_tier = 1
	state.per_player[1].economy_tier = 1
	assert_int(Credits.credit_income(state, 1) - Credits.credit_income(state, 0)).is_equal(300)


func test_a_machinist_crew_drives_the_siege_mech_faster() -> void:
	var mech := UnitState.new()
	mech.type = UnitTypes.SIEGE_MECH
	var guard := UnitState.new()
	guard.type = UnitTypes.FOREMAN   # can pilot, no crew bonus
	mech.pilot = guard
	assert_int(Unit.crewed_move_cost(mech)).is_equal(3)
	var machinist := UnitState.new()
	machinist.type = UnitTypes.MACHINIST
	mech.pilot = machinist
	assert_int(Unit.crewed_move_cost(mech)).is_equal(2)
	assert_int(Movement.move_path_cost(mech, 1)).is_equal(2)


func test_no_crew_makes_movement_free() -> void:
	var walker := UnitState.new()
	walker.type = UnitTypes.SCOUT.duplicate()
	walker.type.move_cost = 1
	var fast := UnitState.new()
	fast.type = UnitTypes.MACHINIST
	walker.pilot = fast
	assert_int(Unit.crewed_move_cost(walker)).is_equal(Unit.MIN_MOVE_COST)


func _protectorate_state() -> GameState:
	return MatchSetup.build(_map(),
		[Factions.GALACTIC_PROTECTORATE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)


func _place(state: GameState, type: UnitTypeDef, tile: Vector2i) -> UnitState:
	var u := UnitState.new()
	u.entity_id = state.next_entity_id
	u.owner = 0
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	state.entities_by_id[u.entity_id] = u
	state.grid.place(u.entity_id, tile.x, tile.y)
	state.next_entity_id += 1
	return u


func test_mech_autonomy_frees_mechs_but_never_tanks() -> void:
	var state := _protectorate_state()
	var mech := _place(state, UnitTypes.SENTINEL_MECH, Vector2i(5, 1))
	var tank := _place(state, UnitTypes.LANCE_TANK, Vector2i(5, 8))
	assert_bool(Unit.is_functional(state, mech)).is_false()
	GameStateFactory.grant_tech(state, 0, Techs.MECH_AUTONOMY)
	assert_bool(Unit.is_functional(state, mech)).is_true()
	assert_bool(Unit.is_functional(state, tank)).override_failure_message(
		"Mech Autonomy freed a TANK — CR-11a says tanks always need crew.").is_false()


func test_completing_mech_autonomy_ejects_the_pilot() -> void:
	var state := _protectorate_state()
	var mech := _place(state, UnitTypes.SENTINEL_MECH, Vector2i(5, 1))
	var pilot := UnitState.new()
	pilot.entity_id = 400
	pilot.owner = 0
	pilot.type = UnitTypes.SERVITOR
	pilot.current_hp = pilot.type.hp
	mech.pilot = pilot
	var hq: StructureState = Research.researcher(state, 0)
	hq.research_target = Techs.MECH_AUTONOMY
	hq.research_turns_remaining = 1
	Research.advance_research_timers(state, 0)
	assert_object(mech.pilot).is_null()
	assert_bool(state.entities_by_id.has(400)).is_true()
	assert_int(state.grid.manhattan_distance(pilot.position, mech.position)).is_equal(1)


func test_mech_autonomy_is_the_protectorates_alone() -> void:
	var state := _protectorate_state()
	assert_bool(Faction.techs(state, 0).has(Techs.MECH_AUTONOMY)).is_true()
	assert_bool(Faction.techs(state, 1).has(Techs.MECH_AUTONOMY)).is_false()
	assert_int(Research.availability(state, 1, Techs.MECH_AUTONOMY)).is_equal(Action.Reason.TECH_FACTION_RESTRICTED)


func test_servitors_are_cap_exempt_and_poor_pilots() -> void:
	assert_bool(UnitTypes.SERVITOR.counts_toward_cap).is_false()
	assert_int(UnitTypes.SERVITOR.crew_bonus_attack).is_equal(-1)


func _empire_state() -> GameState:
	return MatchSetup.build(_map(),
		[Factions.HOLY_COSMIC_EMPIRE, Factions.DEMOCRATIC_ALLIANCE] as Array[FactionDef], 0, 80)


func test_the_empire_is_the_only_faction_that_promotes() -> void:
	for f: FactionDef in Factions.playable():
		assert_bool(f.promotes).is_equal(f == Factions.HOLY_COSMIC_EMPIRE)


func test_a_knight_is_produced_a_veteran() -> void:
	var state := _empire_state()
	var barracks := StructureState.new()
	barracks.entity_id = 500
	barracks.owner = 0
	barracks.position = Vector2i(4, 2)
	barracks.type = StructureTypes.EMPIRE_BARRACKS
	barracks.current_hp = barracks.type.hp
	barracks.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[500] = barracks
	state.grid.place(500, 4, 2)
	state.per_player[0].current_credits = 5000
	state.per_player[0].current_ap = 20
	# The Knight needs a standing Cathedral to hold its rank (PV-7 support).
	var cathedral := StructureState.new()
	cathedral.entity_id = 501
	cathedral.owner = 0
	cathedral.position = Vector2i(4, 8)
	cathedral.type = StructureTypes.CATHEDRAL
	cathedral.current_hp = cathedral.type.hp
	cathedral.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[501] = cathedral
	state.grid.place(501, 4, 8)
	var a := ProduceAction.new()
	a.player = 0
	a.producer_id = 500
	a.unit_type = UnitTypes.KNIGHT
	a.tile = BaseProduction.legal_deploy_tiles(state, barracks, UnitTypes.KNIGHT)[0]
	assert_bool(state.apply_action(a).ok).is_true()
	BaseProduction.advance_build_timers(state, 0)
	var knight: UnitState = state.entity_at(a.tile)
	assert_int(knight.rank).is_equal(1)
	assert_int(Unit.effective_attack(state, knight)).is_equal(UnitTypes.KNIGHT.attack + CombatBalance.combat.rank_attack[1])


func test_the_cathedral_opens_tier_two_like_a_research_lab() -> void:
	var state := _empire_state()
	GameStateFactory.grant_tech(state, 0, Techs.ATTACK_I)
	assert_int(Research.availability(state, 0, Techs.PENETRATION)).is_equal(Action.Reason.REQUIRES_STRUCTURE)
	var c := StructureState.new()
	c.entity_id = 502
	c.owner = 0
	c.position = Vector2i(4, 8)
	c.type = StructureTypes.CATHEDRAL
	c.current_hp = c.type.hp
	c.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[502] = c
	state.grid.place(502, 4, 8)
	assert_int(Research.availability(state, 0, Techs.PENETRATION)).is_equal(Action.Reason.OK)


func test_doctrine_strengthens_vehicles_only() -> void:
	var state := _empire_state()
	var walker := UnitState.new()
	walker.owner = 0
	walker.type = UnitTypes.AEGIS_WALKER
	var levy := UnitState.new()
	levy.owner = 0
	levy.type = UnitTypes.LEVY
	var w_atk: int = Unit.effective_attack(state, walker)
	var l_atk: int = Unit.effective_attack(state, levy)
	GameStateFactory.grant_tech(state, 0, Techs.DOCTRINE_III)
	assert_int(Unit.effective_attack(state, walker)).is_equal(w_atk + 1)
	assert_int(Unit.effective_defense(state, walker)).is_equal(UnitTypes.AEGIS_WALKER.defense + 1)
	assert_int(Unit.effective_attack(state, levy)).is_equal(l_atk)


func test_doctrine_is_strictly_linear() -> void:
	var state := _empire_state()
	assert_int(Research.availability(state, 0, Techs.DOCTRINE_II)).is_equal(Action.Reason.PREREQUISITE_MISSING)
