# The HUD must still fit at the hardware floor, at the scale that floor ships with (S8-07).
#
# ★★ WHY THIS EXISTS. `GameSettings.UI_SCALE_SMALL_SCREEN` raises the UI on floor-resolution
# displays so text is legible on a 7-inch panel. This suite pins the thing that would silently
# break it: that the HUD still fits once everything is scaled up.
#
# Measured at 1280×800 across the whole settings range — 1.00, 1.10, 1.15, 1.25, 1.35, 1.50 — the
# HUD has ZERO plate collisions at every step. The plates are edge-anchored and the status strip is
# centred, so they stay clear even at a logical 853×533. Layout is therefore not the constraint on
# this value; legibility is, and legibility needs a real device.
#
# ⚠ A first version of this measurement reported collisions from 1.15 upward and was WRONG: its
# collector filtered Controls against the PHYSICAL viewport width rather than the logical one, so
# full-screen scrims — which are supposed to cover everything — counted as overlaps. The filter
# below is logical-relative for exactly that reason. ★ The bad number nearly shipped as the
# justification for the constant.
#
# What this suite is really for is the future: the HUD gains elements, and a new one that does not
# anchor to an edge can walk into another plate once the logical viewport shrinks. That must fail
# here rather than be discovered on a handheld.

extends GdUnitTestSuite

const _FLOOR := Vector2i(1280, 800)

var _prev_size: Vector2i = Vector2i.ZERO
var _prev_scale: float = 1.0


func before() -> void:
	_prev_size = get_window().size
	_prev_scale = get_window().content_scale_factor


func after() -> void:
	get_window().size = _prev_size
	get_window().content_scale_factor = _prev_scale


## Top-level HUD plates and the status strip — the things that can collide with each other.
## Nested children are excluded: a panel's own contents overlapping their parent is layout, not a
## defect.
func _hud_rects(root: Node) -> Array:
	var out: Array = []
	_collect(root, out, 0)
	return out


func _collect(n: Node, out: Array, depth: int) -> void:
	if n is Control and depth >= 1 and depth <= 2:
		var c: Control = n
		# Skip full-screen scrims and overlays — they are SUPPOSED to cover everything.
		var logical: Vector2 = Vector2(get_window().size) / get_window().content_scale_factor
		if c.size.x > 40 and c.size.y > 20 and c.size.x < logical.x * 0.9:
			out.append([String(n.name), Rect2(c.global_position, c.size)])
			return
	for child: Node in n.get_children():
		if depth < 3:
			_collect(child, out, depth + 1)


func _measure(scale: float) -> Dictionary:
	get_window().size = _FLOOR
	get_window().content_scale_factor = scale
	var root: Node = preload("res://scenes/vertical_slice.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var rects: Array = _hud_rects(root)
	var logical: Vector2 = Vector2(_FLOOR) / scale
	var overlaps: Array[String] = []
	var offscreen: Array[String] = []
	for i: int in rects.size():
		var a: Rect2 = rects[i][1]
		if a.position.x < -1.0 or a.position.y < -1.0 \
				or a.end.x > logical.x + 1.0 or a.end.y > logical.y + 1.0:
			offscreen.append(rects[i][0])
		for j: int in range(i + 1, rects.size()):
			if a.intersects(rects[j][1]):
				overlaps.append("%s x %s" % [rects[i][0], rects[j][0]])
	root.queue_free()
	await get_tree().process_frame
	return {"count": rects.size(), "overlaps": overlaps, "offscreen": offscreen}


func test_the_hud_fits_at_the_floor_with_the_shipped_small_screen_scale() -> void:
	# ★ The assertion that makes shipping at the measured ceiling safe.
	var r: Dictionary = await _measure(GameSettings.UI_SCALE_SMALL_SCREEN)
	assert_int(r["count"]).override_failure_message(
		"Found no HUD plates to measure — the collector is broken and this suite asserts nothing."
	).is_greater(0)
	assert_array(r["overlaps"]).override_failure_message(
		("At %s with ui_scale %.2f the HUD overlaps itself: %s.\n" % [_FLOOR, GameSettings.UI_SCALE_SMALL_SCREEN, ", ".join(r["overlaps"])]) +
		"The HUD had zero collisions across 1.00-1.50 when this value was chosen, so something " +
		"new has been added that does not anchor to an edge.\n" +
		"FIX: re-anchor or shrink the offending element. Lowering the scale instead makes text " +
		"smaller on the 7-inch panel this value exists to serve."
	).is_empty()
	assert_array(r["offscreen"]).override_failure_message(
		"Off the logical viewport at the floor: %s" % ", ".join(r["offscreen"])).is_empty()


func test_the_hud_also_fits_at_the_floor_unscaled() -> void:
	# The fallback path: a player who explicitly chooses 1.0 on a small screen must still get a
	# usable HUD, not a broken one.
	var r: Dictionary = await _measure(GameSettings.UI_SCALE_DEFAULT)
	assert_array(r["overlaps"]).override_failure_message(
		"The HUD overlaps at the floor even UNSCALED: %s" % ", ".join(r["overlaps"])).is_empty()
	assert_array(r["offscreen"]).is_empty()


func test_the_recommended_scale_band() -> void:
	# Pure function, no window needed. Pins the band's edges so a change is deliberate.
	assert_float(GameSettings.recommended_ui_scale(Vector2i(1280, 800))).override_failure_message(
		"The Steam Deck floor must get the small-screen scale."
	).is_equal(GameSettings.UI_SCALE_SMALL_SCREEN)
	assert_float(GameSettings.recommended_ui_scale(Vector2i(1366, 768))).is_equal(
		GameSettings.UI_SCALE_SMALL_SCREEN)
	assert_float(GameSettings.recommended_ui_scale(Vector2i(1920, 1080))).is_equal(
		GameSettings.UI_SCALE_DEFAULT)
	assert_float(GameSettings.recommended_ui_scale(Vector2i(2560, 1440))).is_equal(
		GameSettings.UI_SCALE_DEFAULT)


func test_a_headless_or_test_viewport_is_never_auto_scaled() -> void:
	# ⚠ Load-bearing. Headless runs report a viewport a few dozen pixels wide; treating that as a
	# small screen would silently re-scale what every other suite renders and measures.
	assert_float(GameSettings.recommended_ui_scale(Vector2i(64, 64))).is_equal(
		GameSettings.UI_SCALE_DEFAULT)
	assert_float(GameSettings.recommended_ui_scale(Vector2i(320, 240))).is_equal(
		GameSettings.UI_SCALE_DEFAULT)


func test_an_explicit_player_choice_is_never_overridden_by_the_floor_default() -> void:
	# ★ The auto-scale must apply only when the player has NOT chosen. GameSettings stores
	# overrides only (S6-24) so players inherit future default changes; auto-scaling by WRITING a
	# value would pin them to today's answer forever.
	var s := GameSettings.new()
	s.ui_scale = 1.25
	assert_float(s.ui_scale).is_equal(1.25)
	# The resolver itself is untouched by the stored value — apply_display() is what composes them.
	assert_float(GameSettings.recommended_ui_scale(Vector2i(1280, 800))).is_equal(
		GameSettings.UI_SCALE_SMALL_SCREEN)
