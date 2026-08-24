# Story 007 / sprint task S5-02: glow shader wiring — the automatable slice
# (production/epics/board-renderer/story-007-glow-shader-wiring.md).
#
# Covers the state->uniform mapping, the locked hue anchors, mask-path resolution,
# the shared-material/per-instance split, and that the glow clock is an injected
# state_timer rather than the shader TIME built-in.
#
# NOT covered, and not automatable: whether the additive emission READS as neon trim
# rather than a blown-out panel at board scale (AC-7). The headless dummy rasteriser
# cannot render, so that is windowed evidence under S5-07.
extends GdUnitTestSuite

const FACTIONS: Array[FactionDef] = [Factions.RUSH, Factions.BOOM]


func _make_renderer() -> BoardRenderer:
	var renderer: BoardRenderer = auto_free(BoardRenderer.new())
	add_child(renderer)
	return renderer


func _make_unit(id: int, owner: int, tile: Vector2i, type: UnitTypeDef, hp: int = 10) -> UnitState:
	var unit := UnitState.new()
	unit.entity_id = id
	unit.owner = owner
	unit.position = tile
	unit.type = type
	unit.current_hp = hp
	return unit


func _glow_of(renderer: BoardRenderer, entity_id: int) -> Sprite2D:
	for child: Node in renderer.occupant_layer.get_children():
		if child.name == "Entity%d" % entity_id:
			return child.get_node_or_null("Glow")
	return null


# --- AC-3: locked faction anchors -------------------------------------------

func test_faction_hue_matches_the_locked_anchors() -> void:
	# Assert — these are palette-locked (art-bible §4.1); S5-08's colourblind
	# measurement of 34/255 grayscale separation is derived from this exact pair.
	assert_bool(EntityGlow.hue_for(Factions.RUSH).is_equal_approx(Color("FF5A2E"))).is_true()
	assert_bool(EntityGlow.hue_for(Factions.BOOM).is_equal_approx(Color("22C7F0"))).is_true()
	assert_bool(EntityGlow.hue_for(Factions.NEUTRAL).is_equal_approx(Color("C6CED8"))).is_true()


func test_unknown_faction_falls_back_to_the_neutral_hue() -> void:
	assert_bool(EntityGlow.hue_for(null).is_equal_approx(Color("C6CED8"))).is_true()


# --- AC-2: mask paths carry no faction token --------------------------------

func test_every_vs_type_now_has_a_shipped_glow_mask() -> void:
	# Arrange / Act / Assert — masks are hue-agnostic, so one per unit facing and one
	# per structure covers the roster. Coverage guard for the 2026-08-19 art round.
	for archetype: String in ["scout", "trooper", "heavy", "sniper"]:
		for facing: String in ["e", "w"]:
			var path := "res://assets/art/units/unit_%s_%s_idle_01_glow.png" % [archetype, facing]
			assert_bool(ResourceLoader.exists(path)).override_failure_message(
				"missing glow mask: %s" % path
			).is_true()
	for name: String in ["hq", "barracks", "factory",
			"defensive_structure", "research_lab"]:
		var path := "res://assets/art/structures/struct_%s_idle_glow.png" % name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"missing glow mask: %s" % path
		).is_true()


func test_unit_mask_path_drops_the_faction_token() -> void:
	# Arrange
	var scout := _make_unit(1, 0, Vector2i.ZERO, UnitTypes.SCOUT)

	# Act
	var path := EntityGlow.mask_path(scout, "e")

	# Assert — one greyscale mask serves all three hues, which is exactly why hue is
	# a per-instance uniform rather than baked per asset.
	assert_str(path).is_equal("res://assets/art/units/unit_scout_e_idle_01_glow.png")
	assert_str(path).not_contains("rush")
	assert_bool(ResourceLoader.exists(path)).is_true()


func test_structure_mask_path_drops_the_faction_token() -> void:
	# Arrange
	var hq := StructureState.new()
	hq.entity_id = 1
	hq.owner = 0
	hq.position = Vector2i.ZERO
	hq.type = StructureTypes.HQ
	hq.current_hp = 40

	# Act
	var path := EntityGlow.mask_path(hq, "e")

	# Assert
	assert_str(path).is_equal("res://assets/art/structures/struct_hq_idle_glow.png")
	assert_bool(ResourceLoader.exists(path)).is_true()


# --- AC-4: state -> pulse_intensity envelope --------------------------------

func test_ap_available_breathes_within_the_authored_range() -> void:
	# Arrange / Act / Assert — sampled across a full cycle, the breathe must stay
	# inside 0.25..0.85 and must actually reach both ends.
	var lowest := 999.0
	var highest := -999.0
	for step in 60:
		var t: float = float(step) * EntityGlow.BREATHE_PERIOD_SEC / 60.0
		var pulse: float = EntityGlow.pulse_for(EntityGlow.Mode.BREATHE, EntityGlow.SPENT_CLAMP, t, 0.0)
		assert_float(pulse).is_greater_equal(EntityGlow.BREATHE_MIN - 0.001)
		assert_float(pulse).is_less_equal(EntityGlow.BREATHE_MAX + 0.001)
		lowest = minf(lowest, pulse)
		highest = maxf(highest, pulse)
	assert_float(lowest).is_less(EntityGlow.BREATHE_MIN + 0.02)
	assert_float(highest).is_greater(EntityGlow.BREATHE_MAX - 0.02)


func test_ap_spent_clamps_to_the_authored_level() -> void:
	# Assert — clamp is NOT zero: a fully dark actor reads as destroyed, a different
	# state entirely.
	assert_float(EntityGlow.SPENT_CLAMP).is_equal_approx(0.08, 0.0001)
	assert_float(EntityGlow.resting_pulse(false)).is_equal_approx(0.08, 0.0001)
	assert_float(
		EntityGlow.pulse_for(EntityGlow.Mode.STATIC, EntityGlow.SPENT_CLAMP, 12.3, 0.0)
	).is_equal_approx(0.08, 0.0001)


func test_attack_flare_peaks_at_one_then_decays() -> void:
	# Arrange
	var base := EntityGlow.SPENT_CLAMP
	var start := 5.0

	# Act
	var at_peak: float = EntityGlow.pulse_for(EntityGlow.Mode.FLARE, base, start, start)
	var mid: float = EntityGlow.pulse_for(EntityGlow.Mode.FLARE, base, start + 0.2, start)
	var late: float = EntityGlow.pulse_for(EntityGlow.Mode.FLARE, base, start + 1.5, start)

	# Assert — peaks at 1.0, decays monotonically, and settles onto the resting level
	# rather than snapping to black.
	assert_float(at_peak).is_equal_approx(EntityGlow.FLARE_PEAK, 0.001)
	assert_float(mid).is_less(at_peak)
	assert_float(late).is_less(mid)
	assert_float(late).is_greater_equal(base)


func test_destroyed_drives_the_pulse_to_zero() -> void:
	# Assert — death outranks every other state.
	assert_float(EntityGlow.resting_pulse(true)).is_equal_approx(0.0, 0.0001)
	assert_int(EntityGlow.mode_for(true, true)).is_equal(EntityGlow.Mode.STATIC)
	assert_float(
		EntityGlow.pulse_for(EntityGlow.Mode.STATIC, EntityGlow.resting_pulse(true), 9.0, 0.0)
	).is_equal_approx(0.0, 0.0001)


func test_mode_selects_breathe_only_when_the_actor_can_still_act() -> void:
	assert_int(EntityGlow.mode_for(false, true)).is_equal(EntityGlow.Mode.BREATHE)
	assert_int(EntityGlow.mode_for(false, false)).is_equal(EntityGlow.Mode.STATIC)


# --- AC-1: one shared material, divergent per-instance values ---------------

func test_two_actors_share_one_material_but_hold_divergent_instance_values() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var rush_unit := _make_unit(1, 0, Vector2i(2, 2), UnitTypes.SCOUT)
	var boom_unit := _make_unit(2, 1, Vector2i(4, 4), UnitTypes.TROOPER)
	var entities: Array[EntityState] = [rush_unit, boom_unit]

	# Act
	feed.sync(entities)

	# Assert — ONE ShaderMaterial instance, shared by identity (§8.7 rule 2:
	# a material per actor would break batching) ...
	var rush_glow := _glow_of(renderer, 1)
	var boom_glow := _glow_of(renderer, 2)
	assert_object(rush_glow).is_not_null()
	assert_object(boom_glow).is_not_null()
	assert_bool(rush_glow.material == boom_glow.material).is_true()
	assert_bool(rush_glow.material is ShaderMaterial).is_true()

	# ... yet divergent per-instance hues.
	var rush_hue: Color = rush_glow.get_instance_shader_parameter(&"faction_hue")
	var boom_hue: Color = boom_glow.get_instance_shader_parameter(&"faction_hue")
	assert_bool(rush_hue.is_equal_approx(EntityGlow.RUSH_HUE)).is_true()
	assert_bool(boom_hue.is_equal_approx(EntityGlow.BOOM_HUE)).is_true()
	assert_bool(rush_hue.is_equal_approx(boom_hue)).is_false()


func test_glow_overlay_uses_the_mask_texture_not_the_body_sprite() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]

	# Act
	feed.sync(entities)

	# Assert
	var glow := _glow_of(renderer, 1)
	assert_str(glow.texture.resource_path).contains("_glow.png")
	assert_str(glow.texture.resource_path).not_contains("rush")


func test_glow_overlay_shares_its_parents_pivot_so_it_registers_with_the_body() -> void:
	# Arrange — the mask is authored pixel-for-pixel against its sprite, so any pivot
	# or scale divergence would show as a visibly offset rim.
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(3, 3), UnitTypes.HEAVY)]

	# Act
	feed.sync(entities)

	# Assert
	var glow := _glow_of(renderer, 1)
	var body: Sprite2D = glow.get_parent()
	assert_vector(glow.offset).is_equal(body.offset)
	assert_vector(glow.position).is_equal(Vector2.ZERO)
	assert_vector(glow.scale).is_equal(Vector2.ONE)
	assert_vector(glow.texture.get_size()).is_equal(body.texture.get_size())


# --- AC-5/AC-6: injected clock, event-driven writes --------------------------

func test_state_timer_is_injected_and_advances_with_delta() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]
	feed.sync(entities)

	# Act
	feed.advance_glow(0.5)
	feed.advance_glow(0.25)

	# Assert — the clock is ours, not the shader's TIME built-in.
	assert_float(feed.state_timer()).is_equal_approx(0.75, 0.0001)
	var material: ShaderMaterial = _glow_of(renderer, 1).material
	assert_float(material.get_shader_parameter(&"state_timer")).is_equal_approx(0.75, 0.0001)


func test_paused_glow_does_not_advance_the_clock() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)]
	feed.sync(entities)
	feed.advance_glow(1.0)

	# Act
	feed.glow_paused = true
	feed.advance_glow(5.0)

	# Assert — this is why the shader must never read TIME: TIME would keep running
	# straight through a turn-based pause.
	assert_float(feed.state_timer()).is_equal_approx(1.0, 0.0001)


func test_shader_source_never_reads_the_time_builtin() -> void:
	# Arrange / Act — a static guard on the shader source itself (AC-5). A future
	# edit reaching for TIME would silently unfreeze the glow during a pause, which
	# no runtime assertion in a headless suite would ever catch.
	var source: String = FileAccess.get_file_as_string(EntityGlow.SHADER_PATH)

	# Assert
	assert_bool(source.is_empty()).is_false()
	for line: String in source.split("\n"):
		var code: String = line.split("//")[0]
		assert_bool(code.contains("TIME")).is_false()


func test_shared_tunables_are_pushed_from_the_gdscript_constants() -> void:
	# Arrange / Act — the shader owns the curve's SHAPE; every VALUE comes from
	# EntityGlow, so the two can never disagree on numbers.
	var material := EntityGlow.make_material()

	# Assert
	assert_float(material.get_shader_parameter(&"breathe_min")).is_equal_approx(EntityGlow.BREATHE_MIN, 0.0001)
	assert_float(material.get_shader_parameter(&"breathe_max")).is_equal_approx(EntityGlow.BREATHE_MAX, 0.0001)
	assert_float(material.get_shader_parameter(&"breathe_period")).is_equal_approx(EntityGlow.BREATHE_PERIOD_SEC, 0.0001)
	assert_float(material.get_shader_parameter(&"flare_peak")).is_equal_approx(EntityGlow.FLARE_PEAK, 0.0001)
	assert_float(material.get_shader_parameter(&"flare_decay")).is_equal_approx(EntityGlow.FLARE_DECAY_SEC, 0.0001)


func test_glow_mode_follows_the_owners_ap_through_the_injected_predicate() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var unit := _make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)
	var entities: Array[EntityState] = [unit]
	var has_ap := [true]
	feed.actionable_predicate = func(_e: EntityState) -> bool: return has_ap[0]

	# Act / Assert — breathing while the owner can act ...
	feed.sync(entities)
	var glow := _glow_of(renderer, 1)
	assert_float(glow.get_instance_shader_parameter(&"glow_mode")).is_equal_approx(
		float(EntityGlow.Mode.BREATHE), 0.0001
	)

	# ... clamped once the AP is gone.
	has_ap[0] = false
	feed.sync(entities)
	assert_float(glow.get_instance_shader_parameter(&"glow_mode")).is_equal_approx(
		float(EntityGlow.Mode.STATIC), 0.0001
	)
	assert_float(glow.get_instance_shader_parameter(&"pulse_base")).is_equal_approx(
		EntityGlow.SPENT_CLAMP, 0.0001
	)


func test_attacking_triggers_the_flare_and_stamps_the_clock() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var unit := _make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)
	var entities: Array[EntityState] = [unit]
	feed.sync(entities)
	feed.advance_glow(2.0)

	# Act — the flare is derived from has_attacked flipping, so it fires for the AI's
	# attacks exactly as it does for the player's.
	unit.has_attacked = true
	feed.sync(entities)

	# Assert
	var glow := _glow_of(renderer, 1)
	assert_float(glow.get_instance_shader_parameter(&"glow_mode")).is_equal_approx(
		float(EntityGlow.Mode.FLARE), 0.0001
	)
	assert_float(glow.get_instance_shader_parameter(&"flare_start")).is_equal_approx(2.0, 0.0001)


func test_start_of_turn_attack_reset_does_not_re_trigger_a_flare() -> void:
	# Arrange
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var unit := _make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)
	var entities: Array[EntityState] = [unit]
	unit.has_attacked = true
	feed.sync(entities)

	# Act — the turn rolls over and the flag clears (true -> false).
	unit.has_attacked = false
	feed.sync(entities)

	# Assert — an edge in the other direction must not read as a new attack.
	var glow := _glow_of(renderer, 1)
	assert_float(glow.get_instance_shader_parameter(&"glow_mode")).is_equal_approx(
		float(EntityGlow.Mode.BREATHE), 0.0001
	)


func test_destroyed_actor_loses_its_glow_overlay_entirely() -> void:
	# Arrange — only idle masks are authored; a dead actor emits nothing, so it is
	# never owed one and must not fall back to a placeholder.
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var unit := _make_unit(1, 0, Vector2i(1, 1), UnitTypes.SCOUT)
	var entities: Array[EntityState] = [unit]
	feed.sync(entities)
	assert_object(_glow_of(renderer, 1)).is_not_null()

	# Act
	unit.current_hp = 0
	feed.sync(entities)

	# Assert
	assert_object(_glow_of(renderer, 1)).is_null()


func test_unshipped_type_gets_no_glow_overlay_rather_than_a_broken_one() -> void:
	# Arrange — a FABRICATED type, not a real one: every VS type has shipped art and
	# a mask as of 2026-08-19, and naming a real type here silently rots the moment
	# its art lands (which is exactly what happened to the Sniper).
	var renderer := _make_renderer()
	var feed := EntitySpriteFeed.new(renderer, FACTIONS)
	var phantom_type := UnitTypeDef.new()
	phantom_type.display_name = "Phantom Walker"
	var entities: Array[EntityState] = [_make_unit(1, 0, Vector2i(1, 1), phantom_type)]

	# Act
	feed.sync(entities)

	# Assert — the missing BODY art is already loud (push_error + magenta); the glow
	# layer must not add a second, more confusing failure on top.
	assert_object(_glow_of(renderer, 1)).is_null()
