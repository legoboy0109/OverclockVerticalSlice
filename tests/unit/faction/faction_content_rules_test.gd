# The universal rules every PLAYABLE faction must meet (faction-identity.md CR-11, unit-classes.md
# UC-5, and the lessons of S6-09 / S8-34). Driven by Factions.playable(), so each new faction wave
# is held to them the moment it is registered — nothing to remember to add.
extends GdUnitTestSuite


func _all_structures(f: FactionDef) -> Array[StructureTypeDef]:
	var out: Array[StructureTypeDef] = [Faction.hq_type(f)]
	out.append_array(f.structures if not f.structures.is_empty() else StructureTypes.BUILDABLE)
	return out


func _techs(f: FactionDef) -> Array[TechDef]:
	return f.techs if not f.techs.is_empty() else Techs.ALL


func test_every_faction_can_build_from_turn_one() -> void:
	for f: FactionDef in Factions.playable():
		var hq: StructureTypeDef = Faction.hq_type(f)
		var builders: Array = hq.producible_types.filter(func(t: UnitTypeDef) -> bool: return t.can_build)
		assert_bool(builders.is_empty()).override_failure_message(
			"%s's HQ makes no Builder — it could never raise a structure." % f.display_name).is_false()


func test_every_buildable_structure_does_something() -> void:
	for f: FactionDef in Factions.playable():
		var gates: Array = []
		for t: TechDef in _techs(f):
			gates.append_array(t.required_structures)
		for s: StructureTypeDef in (f.structures if not f.structures.is_empty() else StructureTypes.BUILDABLE):
			var useful: bool = not s.producible_types.is_empty() or s.cap_bonus > 0 or s.attack > 0 \
				or s.can_research or gates.has(s) or s.resupplies
			assert_bool(useful).override_failure_message(
				"%s can build %s, which does nothing." % [f.display_name, s.display_name]).is_true()


func test_cr11_every_faction_fields_crewable_armour_and_can_crew_it() -> void:
	for f: FactionDef in Factions.playable():
		var units: Array[UnitTypeDef] = Faction.units(f)
		var piloted: bool = units.any(func(t: UnitTypeDef) -> bool:
			return t.unit_class == UnitTypeDef.UnitClass.GROUND_VEHICLE and t.requires_pilot)
		var pilots: bool = units.any(func(t: UnitTypeDef) -> bool: return t.can_pilot)
		assert_bool(piloted).override_failure_message("%s has no piloted ground vehicle (CR-11)." % f.display_name).is_true()
		assert_bool(pilots).override_failure_message(
			"%s has vehicles but no unit that can crew them — its armour is permanently inert." % f.display_name).is_true()


func test_uc5_every_faction_can_answer_air() -> void:
	for f: FactionDef in Factions.playable():
		var aa: bool = Faction.units(f).any(func(t: UnitTypeDef) -> bool: return UnitTypeDef.UnitClass.AIR in t.can_target)
		for s: StructureTypeDef in _all_structures(f):
			if s.attack > 0 and UnitTypeDef.UnitClass.AIR in s.can_target:
				aa = true
		assert_bool(aa).override_failure_message("%s cannot shoot aircraft at all (UC-5)." % f.display_name).is_true()


func test_every_tier_two_gate_is_buildable_by_that_faction() -> void:
	for f: FactionDef in Factions.playable():
		var own: Array[StructureTypeDef] = _all_structures(f)
		for t: TechDef in _techs(f):
			for gate: StructureTypeDef in t.required_structures:
				# A structure that counts as the gate (the Empire's Cathedral for a Research Lab) satisfies it.
				var met: bool = own.has(gate) or own.any(func(s: StructureTypeDef) -> bool: return gate in s.counts_as)
				assert_bool(met).override_failure_message(
					"%s's %s needs a %s it cannot build." % [f.display_name, t.display_name, gate.display_name]).is_true()


func test_every_faction_unit_and_structure_has_sprites() -> void:
	for f: FactionDef in Factions.playable():
		for t: UnitTypeDef in Faction.units(f):
			var path := "res://assets/art/units/unit_%s_rush_e_idle_01.png" % EntitySpriteCatalog.type_token_for(t)
			assert_bool(ResourceLoader.exists(path)).override_failure_message(
				"%s's %s has no sprite (%s)." % [f.display_name, t.display_name, path]).is_true()
		for s: StructureTypeDef in _all_structures(f):
			var path := "res://assets/art/structures/struct_%s_rush_idle.png" % EntitySpriteCatalog.type_token_for(s)
			assert_bool(ResourceLoader.exists(path)).override_failure_message(
				"%s's %s has no sprite (%s)." % [f.display_name, s.display_name, path]).is_true()


func test_every_faction_unit_is_registered() -> void:
	# UnitTypes.ALL drives the art and accent guards; a unit missing from it escapes them.
	for f: FactionDef in Factions.playable():
		for t: UnitTypeDef in Faction.units(f):
			assert_bool(UnitTypes.ALL.has(t)).override_failure_message(
				"%s is fielded by %s but not in UnitTypes.ALL." % [t.display_name, f.display_name]).is_true()
