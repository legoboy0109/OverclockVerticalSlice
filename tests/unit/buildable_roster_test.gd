# The buildable roster — what a Builder is actually OFFERED, and why two entries are absent.
#
# ⛔⛔ WHY THIS EXISTS. Two structure types have been pulled from the roster because they
# do nothing, and until 2026-08-26 NOTHING GUARDED EITHER REMOVAL:
#   • FACTORY      — removed S6-09. Produces GROUND_VEHICLE units, which are wave 2 and
#                    unimplemented. Today it produces nothing, grants no income, and costs
#                    1,000 Credits plus 200 upkeep a turn.
#   • RESEARCH_LAB — removed S8-34. The Research & Tech epic (ADR-0018) is NOT BUILT:
#                    research.gd is a forward declaration, there is no ResearchAction, and
#                    Action.Verb.RESEARCH is never registered with GameState. 800 Credits
#                    and a consumed Builder for a building that cannot do anything.
#
# ★ Both are "a button that can only make the player's position worse". Both were one-line
#   list edits, and a one-line edit is exactly what silently comes back — the same failure
#   mode as the art-coverage guards that kept hand-written type lists (S8-14 / S8-19).
#
# ⚠ THE ROSTER LIVES IN THREE PLACES that must agree: the slice (the authority on what is
#   OFFERED), the HUD widget's default (drives affordability rendering), and CommandFSM's
#   affordability superset (decides whether the Build ROW is enabled at all). If they
#   disagree the player gets a Build row whose picker then greys every line, or an offered
#   structure the row refuses to enable. That agreement is asserted here.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd + test_[scenario]_[expected].
extends GdUnitTestSuite


func _slice_roster() -> Array[StructureTypeDef]:
	var root := VerticalSliceRoot.new()
	var roster: Array[StructureTypeDef] = root._buildable_roster()
	root.free()
	return roster


func _hud_roster() -> Array[StructureTypeDef]:
	var w := HudControlsWidget.new()
	var roster: Array[StructureTypeDef] = w._default_buildable_types()
	w.free()
	return roster


func test_the_research_lab_is_offered_because_it_gates_tier_two() -> void:
	# ★ Restored 2026-09-28 (CR-14). Research runs at the HQ; the Lab is the gate every
	# tier-2 tech requires. Absent, the whole second half of the tree is unreachable.
	assert_bool(_slice_roster().has(StructureTypes.RESEARCH_LAB)).override_failure_message(
		"The Research Lab is not offered, but every tier-2 tech requires one — the " +
		"player could never reach tier 2."
	).is_true()
	for tech: TechDef in Techs.ALL:
		for gate: StructureTypeDef in tech.required_structures:
			assert_bool(_slice_roster().has(gate)).override_failure_message(
				"%s requires a %s, which the player cannot build." % [tech.display_name, gate.display_name]
			).is_true()


func test_every_buildable_structure_does_something() -> void:
	# ★ The general form of S6-09 (Factory) and S8-34 (Research Lab): both were offered
	# while they did nothing, and a player paid a Builder for an inert building. Now the
	# roster is data (the vault's `buildable` box), so this guards every future structure.
	var gates: Array = []
	for tech: TechDef in Techs.ALL:
		gates.append_array(tech.required_structures)
	for type: StructureTypeDef in _slice_roster():
		var useful: bool = not type.producible_types.is_empty() or type.cap_bonus > 0 \
			or type.attack > 0 or type.can_research or gates.has(type)
		assert_bool(useful).override_failure_message(
			"%s is buildable but produces nothing, grants no cap, gates no tech and cannot " % type.display_name +
			"attack — a player would pay a Builder for a building that does nothing."
		).is_true()


func test_the_hq_is_never_buildable() -> void:
	assert_bool(_slice_roster().has(StructureTypes.HQ)).is_false()


func test_the_roster_still_offers_something_to_build() -> void:
	# ⚠ Guards the guard: two removals in, an empty roster would make both tests above
	# pass vacuously while the Build verb became unusable.
	assert_int(_slice_roster().size()).is_greater(0)
	assert_bool(_slice_roster().has(StructureTypes.BARRACKS)).is_true()


func test_the_hud_default_roster_matches_the_slice() -> void:
	# The HUD renders affordability for what it thinks is buildable. If it disagrees with
	# the slice, the player sees a cost for something they cannot place.
	var slice: Array[StructureTypeDef] = _slice_roster()
	var hud: Array[StructureTypeDef] = _hud_roster()
	assert_int(hud.size()).is_equal(slice.size())
	for type: StructureTypeDef in slice:
		assert_bool(hud.has(type)).override_failure_message(
			"HUD roster is missing %s, which the slice offers." % type.display_name
		).is_true()


func test_the_build_rows_affordability_set_offers_nothing_the_slice_will_not_place() -> void:
	# ⚠ CommandFSM._buildable_types decides whether the Build ROW is enabled. Its own doc
	# permits a SUPERSET (a row whose picker greys every line is "visible and explicable").
	# A superset containing a type the slice refuses to offer is NOT explicable, though —
	# the row would enable for a structure the player can never reach.
	var slice: Array[StructureTypeDef] = _slice_roster()
	for type: StructureTypeDef in CommandFSM._buildable_types():
		assert_bool(slice.has(type)).override_failure_message(
			"CommandFSM would enable Build for %s, which the slice never offers." % type.display_name
		).is_true()
