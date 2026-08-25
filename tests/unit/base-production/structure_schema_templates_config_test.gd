# Story 001: Structure Schema, Templates & Config.
#
# Covers every acceptance criterion in
# production/epics/base-production/story-001-structure-schema-templates-config.md
# (TR-baseprod-001 structure templates; TR-baseprod-002 instance FSM fields;
# TR-baseprod-014 MAX_OUTPOST_COUNT disabled lever; TR-baseprod-016 Research
# Lab as a StructureState, production_cap 0):
#
#   AC-templates (Rules 1-2): each of the five StructureTypeDef templates has
#     its stat-table fields EXACTLY (HQ / Economy Outpost / Production Outpost /
#     Defensive Structure / Research Lab), asserted against the real
#     StructureTypes registry consts (Resource-ref reads, not fresh .new()).
#   AC-immutability: a template read twice is the same shared object.
#   AC-lifecycle: StructureState.BuildStatus is exactly {UNDER_CONSTRUCTION,
#     COMPLETED}; a fresh StructureState carries the per-instance fields
#     (build_status/build_turns_remaining/units_produced_this_turn/has_attacked),
#     all @export (proven by a duplicate() round-trip).
#   AC-config: BaseProductionConfig reads cancel_refund_pct 50,
#     defensive_attack_cost 1, max_outpost_count 10.
#   AC-max-outpost-disabled (smoke): the VS config reads the cap DISABLED
#     (max_outpost_count_enabled == false) — guards the "disabled" claim.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# --- AC-templates: fields match the stat table EXACTLY ----------------------

func test_hq_template_matches_stat_table() -> void:
	var hq := StructureTypes.HQ
	assert_int(hq.hp).is_equal(40)
	assert_int(hq.production_cap).is_equal(2)
	assert_int(hq.defense).is_equal(2)
	assert_bool(hq.can_counterattack).is_false()
	# producible == {Scout} exactly.
	assert_int(hq.producible_types.size()).is_equal(1)
	assert_bool(hq.producible_types.has(UnitTypes.SCOUT)).is_true()


func test_factory_template_matches_stat_table() -> void:
	var eo := StructureTypes.FACTORY
	assert_int(eo.hp).is_equal(8)
	# ★ S6-09: aligned to `base-production.md`'s roster table (1,000 / 3 / 200). The
	# data had been carrying the renamed Economy Outpost's numbers (400 / 1 / 100)
	# ever since S6-03 renamed the resource rather than re-statting it -- a rename
	# moves a file, it does not move the design intent behind the numbers inside it.
	assert_int(eo.build_cost).is_equal(1000)
	assert_int(eo.build_time).is_equal(3)
	assert_int(eo.upkeep).is_equal(200)
	assert_int(eo.max_count).is_equal(2)
	# Produces nothing YET -- GROUND_VEHICLE units are wave 2 (`unit-classes.md`).
	# ★ This is why S6-09 also pulled the Factory from the player's build roster:
	# a 1,000-Credit, 200-upkeep structure that produces nothing is a trap, not a
	# choice. Restore it in the change that gives it something to build.
	assert_int(eo.production_cap).is_equal(0)
	assert_int(eo.producible_types.size()).is_equal(0)
	assert_int(eo.defense).is_equal(0)
	assert_bool(eo.can_counterattack).is_false()


func test_barracks_template_matches_stat_table() -> void:
	var po := StructureTypes.BARRACKS
	assert_int(po.hp).is_equal(14)
	# ★ S6-10: 900 -> 600, aligning with `base-production.md`'s roster table. The 900
	# was the ×100 rescale of the pre-rework 9 and had never been re-derived against
	# the new roster. This one is load-bearing -- Barracks throughput was one of the
	# two levers that fixed the S6-06 resolution gate -- so it was measured against
	# the regression batch rather than assumed safe.
	assert_int(po.build_cost).is_equal(600)
	assert_int(po.build_time).is_equal(2)
	assert_int(po.production_cap).is_equal(4)
	assert_int(po.defense).is_equal(0)
	# producible == {Trooper, Heavy, Sniper} exactly.
	assert_int(po.producible_types.size()).is_equal(3)
	assert_bool(po.producible_types.has(UnitTypes.TROOPER)).is_true()
	assert_bool(po.producible_types.has(UnitTypes.HEAVY)).is_true()
	assert_bool(po.producible_types.has(UnitTypes.SNIPER)).is_true()


func test_defensive_structure_template_matches_stat_table() -> void:
	var ds := StructureTypes.DEFENSIVE_STRUCTURE
	assert_int(ds.hp).is_equal(10)
	# ★ S6-10: 600/1 -> 500/2 per the roster table. The extra build turn is the
	# meaningful half: a turret that completes the turn after you pay for it is a
	# reaction, and the table prices it as a commitment.
	assert_int(ds.build_cost).is_equal(500)
	assert_int(ds.build_time).is_equal(2)
	assert_int(ds.production_cap).is_equal(0)
	assert_int(ds.attack).is_equal(4)
	assert_int(ds.attack_range).is_equal(2)
	assert_int(ds.defense).is_equal(1)
	assert_bool(ds.can_counterattack).is_true()


func test_research_lab_template_matches_stat_table_and_is_structure_state() -> void:
	var lab := StructureTypes.RESEARCH_LAB
	# Research-owned stat values (Rule 2b), B&P-owned lifecycle.
	assert_int(lab.hp).is_equal(12)
	assert_int(lab.build_cost).is_equal(800)  # ★ S6-02: ×100 Credit rescale
	assert_int(lab.build_time).is_equal(2)
	assert_int(lab.production_cap).is_equal(0)
	assert_int(lab.producible_types.size()).is_equal(0)
	# The Lab is a StructureState (no third EntityState subclass) — ADR-0007.
	var lab_instance := StructureState.new()
	lab_instance.type = lab
	assert_bool(lab_instance is StructureState).is_true()


# --- AC-immutability: template registry consts are shared references --------

func test_template_read_twice_is_the_same_shared_object() -> void:
	# Resource-ref identity: reading the registry const twice yields the SAME
	# object (immutable, never re-instantiated) — ADR-0007's identity discipline.
	assert_bool(StructureTypes.HQ == StructureTypes.HQ).is_true()
	assert_object(StructureTypes.FACTORY).is_same(StructureTypes.FACTORY)


# --- AC-lifecycle: BuildStatus enum + per-instance @export fields ------------

func test_build_status_has_exactly_two_persisted_values() -> void:
	# ADR-0017 D1 / ADR-0007: exactly two persisted lifecycle values;
	# "Destroyed"/"Removed" are terminal erasure exits, never stored states.
	assert_int(StructureState.BuildStatus.keys().size()).is_equal(2)
	assert_int(StructureState.BuildStatus.UNDER_CONSTRUCTION).is_equal(0)
	assert_int(StructureState.BuildStatus.COMPLETED).is_equal(1)


func test_fresh_structure_state_carries_per_instance_fields_defaults() -> void:
	var s := StructureState.new()
	# Fresh structure defaults to UNDER_CONSTRUCTION with zeroed per-turn state.
	assert_int(s.build_status).is_equal(StructureState.BuildStatus.UNDER_CONSTRUCTION)
	assert_int(s.build_turns_remaining).is_equal(0)
	assert_int(s.units_produced_this_turn).is_equal(0)
	assert_bool(s.has_attacked).is_false()


func test_per_instance_fields_are_export_carrying_survive_duplicate() -> void:
	# @export inclusion proof (ADR-0001/0007 duplicate_deep storage requirement):
	# set every per-instance field to a distinct non-default value, duplicate(true),
	# and confirm each round-trips — a storage-flagged (@export) field survives,
	# a non-@export one would be dropped.
	var s := StructureState.new()
	s.entity_id = 7
	s.owner = 1
	s.position = Vector2i(3, 4)
	s.type = StructureTypes.BARRACKS
	s.current_hp = 11
	s.build_status = StructureState.BuildStatus.COMPLETED
	s.build_turns_remaining = 2
	s.units_produced_this_turn = 3
	s.has_attacked = true

	var copy: StructureState = s.duplicate(true)
	assert_int(copy.entity_id).is_equal(7)
	assert_int(copy.owner).is_equal(1)
	assert_that(copy.position).is_equal(Vector2i(3, 4))
	assert_object(copy.type).is_same(StructureTypes.BARRACKS)  # path-having template shared, not copied
	assert_int(copy.current_hp).is_equal(11)
	assert_int(copy.build_status).is_equal(StructureState.BuildStatus.COMPLETED)
	assert_int(copy.build_turns_remaining).is_equal(2)
	assert_int(copy.units_produced_this_turn).is_equal(3)
	assert_bool(copy.has_attacked).is_true()


# --- AC-config + AC-max-outpost-disabled ------------------------------------

func test_base_production_config_values() -> void:
	var cfg := StructureBalance.base_production
	assert_int(cfg.cancel_refund_pct).is_equal(50)
	assert_int(cfg.defensive_attack_cost).is_equal(1)
	assert_int(cfg.max_outpost_count).is_equal(10)


func test_max_outpost_count_reads_disabled_in_vs_config() -> void:
	# Smoke: the cap exists as a named lever but is DISABLED in the VS — the only
	# assertion this lever is worth (TR-baseprod-014). Guards the "disabled" claim
	# so no count cap silently re-enables.
	var cfg := StructureBalance.base_production
	assert_bool(cfg.max_outpost_count_enabled).override_failure_message(
		"MAX_OUTPOST_COUNT must read DISABLED in the VS config — closeout pressure is emergent, not a hard cap."
	).is_false()
