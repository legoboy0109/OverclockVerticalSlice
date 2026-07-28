# Story 010: HUD / Command-Interface Read-Surface -- GameStateReader.unit_info.
#
# Covers every acceptance criterion in
# production/epics/unit-system/story-010-hud-read-surface.md
# (TR-unit-013 -- HUD/Cmd read-surface: type, cur/max hp, effective attack,
# move cost, has-acted, blocked-shot reason; read-only):
#
#   AC-1 (read surface): GameStateReader.new(state).unit_info(entity_id)
#     surfaces type/current_hp/hp/effective_attack/move_cost/has_attacked for a
#     Trooper, matching the story's QA Test Case values (verified against the
#     live data/units/trooper.tres template, not hardcoded independently of it).
#   AC-2 (structural read-only): unit_info returns a fresh value-snapshot
#     Dictionary every call -- mutating a previously returned snapshot cannot
#     perturb a later snapshot or live state; GameStateReader exposes no
#     mutation path (no setter/apply_action reachable from the reader).
#   AC-3 (blocked-shot inputs exposed, enum Combat-owned): unit_info surfaces
#     attack_range and has_attacked, the inputs Unit owns -- the BlockedReason
#     enum/classification itself (ADR-0010) is Out of Scope for this story.
#
# Naming follows tests/README.md: [system]_[feature]_test.gd +
# test_[scenario]_[expected].
extends GdUnitTestSuite


# Builds a 1-player GameState with a single live Trooper UnitState at
# entity_id 0, has_attacked = true, current_hp = 4 (the story's QA Test Case
# setup). Returns the state; the unit is reachable at state.entities_by_id[0].
func _make_state_with_trooper() -> GameState:
	var state := GameStateFactory.make_state(1, 0)

	var unit := UnitState.new()
	unit.entity_id = 0
	unit.owner = 0
	unit.type = UnitTypes.TROOPER
	unit.current_hp = 4
	unit.has_attacked = true

	state.entities_by_id[unit.entity_id] = unit

	return state


# --- AC-1: read surface -----------------------------------------------------

func test_unit_info_surfaces_trooper_fields_matching_type_template() -> void:
	# Arrange
	var state := _make_state_with_trooper()
	var reader := GameStateReader.new(state)

	# Act
	var info := reader.unit_info(0)

	# Assert -- asserted against the live UnitTypes.TROOPER template (not
	# independently hardcoded), so this test tracks the data if it changes.
	assert_str(info["type"].display_name).is_equal(UnitTypes.TROOPER.display_name)
	assert_str(info["type"].display_name).is_equal("Trooper")
	assert_int(info["current_hp"]).is_equal(4)
	assert_int(info["hp"]).is_equal(UnitTypes.TROOPER.hp)
	assert_int(info["hp"]).is_equal(6)
	assert_int(info["effective_attack"]).is_equal(UnitTypes.TROOPER.attack)
	assert_int(info["effective_attack"]).is_equal(3)
	assert_int(info["move_cost"]).is_equal(UnitTypes.TROOPER.move_cost)
	assert_int(info["move_cost"]).is_equal(2)
	assert_bool(info["has_attacked"]).is_true()


# --- AC-2: structural read-only ---------------------------------------------

func test_unit_info_returns_independent_snapshot_not_aliased_to_live_state() -> void:
	# Arrange
	var state := _make_state_with_trooper()
	var reader := GameStateReader.new(state)
	var info := reader.unit_info(0)

	# Act -- mutate the returned Dictionary directly (simulating a careless
	# caller), then re-fetch a fresh snapshot.
	info["current_hp"] = 999
	var info_again := reader.unit_info(0)

	# Assert -- the fresh snapshot still reads the true live value; mutating
	# a prior snapshot could not have aliased/perturbed game state.
	assert_int(info_again["current_hp"]).override_failure_message(
		"unit_info must return an independent value-snapshot Dictionary each " +
		"call -- mutating a previously returned snapshot must never leak into " +
		"a later snapshot or live GameState (AC-2 structural read-only proof)."
	).is_equal(4)
	assert_int(state.entities_by_id[0].current_hp).override_failure_message(
		"mutating unit_info's returned Dictionary must never reach the live " +
		"UnitState.current_hp field."
	).is_equal(4)


func test_game_state_reader_exposes_only_unit_info_as_script_method() -> void:
	# AC-2 structural read-only proof by ALLOWLIST, not blocklist. GDScript has
	# no access-modifier keywords, so "no mutation path" is proven by shape:
	# enumerate the reader's OWN script-defined methods and assert the only ones
	# are the constructor and the single read accessor. This catches ANY newly
	# added method (a setter/apply_action/mutator of any name), not just one
	# literally named "apply_action" -- the allowlist the story's "structurally
	# enforced, not review-enforced" requirement actually calls for.
	var state := _make_state_with_trooper()
	var reader := GameStateReader.new(state)

	var script_method_names: Array[String] = []
	for m: Dictionary in reader.get_script().get_script_method_list():
		script_method_names.append(m["name"])

	# Only _init (constructor) + read accessors + non-mutating affordances --
	# nothing that writes GameState. unit_info is this story's accessor; Story 009
	# added the B&P read-surface getters (legal_build_tiles/legal_deploy_tiles/
	# structure_info/can_afford_build/can_afford_produce); Game HUD Story 001
	# (ADR-0016 §1/§8) added the HUD read getters (active_player/round_number/
	# match_status/current_ap/income_breakdown/can_afford/entities/entity_at) plus
	# the signal-subscription broker (subscribe_action_applied/
	# unsubscribe_action_applied) -- the brokers register a Callable listener on an
	# existing signal, NOT a mutation path to GameState. The allowlist grows with
	# each read accessor / non-mutating affordance but must never admit a mutator.
	assert_array(script_method_names).override_failure_message(
		"GameStateReader must expose ONLY _init + read accessors + non-mutating " +
		"affordances; any other script-defined method is a potential mutation " +
		"path (AC-2 structural read-only). Found: %s" % [script_method_names]
	).contains_exactly_in_any_order([
		"_init", "unit_info", "legal_build_tiles", "legal_deploy_tiles",
		"structure_info", "can_afford_build", "can_afford_produce",
		"active_player", "round_number", "match_status", "winner", "current_ap",
		"income_breakdown", "can_afford", "entities", "entity_at",
		"subscribe_action_applied", "unsubscribe_action_applied",
	])

	# Belt-and-suspenders, human-readable: the specific mutation shapes must be
	# absent and the read accessor present.
	assert_bool(reader.has_method("unit_info")).is_true()
	assert_bool(reader.has_method("apply_action")).is_false()


# --- Total/safe contract: unresolvable entity_id -> {} ----------------------

func test_unit_info_returns_empty_dict_for_missing_entity_id() -> void:
	# The documented total/safe contract (game_state_reader.gd): an entity_id
	# absent from entities_by_id yields an empty Dictionary, never a runtime
	# error -- so a HUD querying a just-destroyed unit degrades gracefully.
	var state := _make_state_with_trooper()  # only entity_id 0 exists
	var reader := GameStateReader.new(state)

	assert_dict(reader.unit_info(999)).override_failure_message(
		"unit_info(<absent id>) must return an empty Dictionary, not error."
	).is_empty()

	# NOTE(structures): unit_info's OTHER total-function branch -- a resolvable
	# id that maps to a non-UnitState entity (e.g. a structure) -> {} -- cannot
	# be exercised yet: StructureState does not exist in the codebase (only
	# UnitState is a concrete EntityState today). Add a covering test that places
	# a StructureState in entities_by_id and asserts unit_info(<its id>).is_empty()
	# once the Structure entity type lands (Base & Production epic).


# --- AC-3: blocked-shot inputs exposed (Unit's own fields only) -------------

func test_unit_info_surfaces_attack_range_and_has_attacked_as_blocked_shot_inputs() -> void:
	# Arrange -- Unit System's job is only to expose its own fields as inputs;
	# the BlockedReason enum + classification is Combat-owned (ADR-0010) and
	# explicitly Out of Scope for this story.
	var state := _make_state_with_trooper()
	var reader := GameStateReader.new(state)

	# Act
	var info := reader.unit_info(0)

	# Assert
	assert_int(info["attack_range"]).is_equal(UnitTypes.TROOPER.attack_range)
	assert_int(info["attack_range"]).is_equal(2)
	assert_bool(info["has_attacked"]).is_true()
