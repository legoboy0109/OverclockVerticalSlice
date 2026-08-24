# S6-09: the economy-investment throttle has two implementations that must agree.
#
# AITurnDriver._is_economy_or_research is the shipped rule; tools/simulate_matches.gd
# carries a hand-copied duplicate, because the harness runs its own turn loop. The
# sim's own comment says it "must match EXACTLY -- a looser rule here would silently
# simulate a different AI than the one that ships".
#
# ★ It did not match. S6-03 renamed ECONOMY_OUTPOST -> FACTORY mechanically and both
# copies followed, so both kept counting a *production* building as an economy
# investment long after S6-01 moved income to research. The duplication is the
# hazard: two copies of a rule drift silently, and this one drifted in the harness
# that produces the evidence the gate verdict rests on.
#
# This suite pins the rule itself so a future change to either copy has to confront
# the other.
extends GdUnitTestSuite


func _build(structure_type: StructureTypeDef) -> BuildAction:
	var a := BuildAction.new()
	a.player = 0
	a.structure_type = structure_type
	a.tile = Vector2i(4, 4)
	return a


func test_research_is_the_only_economy_investment() -> void:
	var research := Action.new()
	research.verb = Action.Verb.RESEARCH
	assert_bool(AITurnDriver._is_economy_or_research(research)).is_true()


func test_building_a_factory_is_not_an_economy_investment() -> void:
	# ★ The regression. A Factory grants no income -- it is a production building
	# that inherited the Economy Outpost's identity through a rename.
	assert_bool(AITurnDriver._is_economy_or_research(_build(StructureTypes.FACTORY))) \
		.override_failure_message(
			"a Factory build must not count against the economy-investment throttle; " +
			"it grants no income (income moved to research in S6-01)"
		).is_false()


func test_no_structure_build_is_an_economy_investment() -> void:
	for t: StructureTypeDef in [StructureTypes.FACTORY, StructureTypes.BARRACKS,
			StructureTypes.DEFENSIVE_STRUCTURE, StructureTypes.RESEARCH_LAB]:
		assert_bool(AITurnDriver._is_economy_or_research(_build(t))) \
			.override_failure_message("%s must not count as an economy investment" % t.display_name) \
			.is_false()


func test_an_ordinary_verb_is_not_an_economy_investment() -> void:
	var move := Action.new()
	move.verb = Action.Verb.MOVE
	assert_bool(AITurnDriver._is_economy_or_research(move)).is_false()
