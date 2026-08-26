# Keyboard-only command flow — `design/ux/action-menu.md` AC-9.
#
# WHY THIS SUITE EXISTS: AC-9 ("complete a full move using only the keyboard:
# cursor to the unit, Enter, ↓/↑ to Move, Enter, cursor to a highlighted tile,
# Enter. No mouse at any point") had NO test. The action-menu suite's own "AC-9"
# is a different, narrower claim — that the first enabled row takes focus on open
# — so the spec's end-to-end keyboard journey was never once executed.
#
# It was broken. The menu grabs keyboard focus when it opens (which is correct,
# and the spec asks for it), but nothing released that focus when a verb was
# chosen: `ActionMenu.close()` fades over FADE_OUT_SEC and only hides itself at
# the END of the tween, so for the whole fade the focused row was still eating
# ui_up/ui_down/ui_accept. The player picked Move and then could not steer the
# board cursor to a target — which, with the cursor still parked on the unit
# itself, reads as "the action did nothing", because a unit cannot move onto its
# own tile.
#
# These tests push REAL InputEventKey through the viewport rather than calling
# `VerticalSliceRoot`'s methods directly. That is the entire point: every method
# in that chain already worked when called by hand, and the defect lived purely
# in who received the keypress. A test that calls `move_cursor()` cannot see it.
extends GdUnitTestSuite

# Bound to ui_accept / ui_up / ui_down in project.godot. Pushed as physical keys
# so the InputMap resolves them exactly as it does for a real keyboard.
const KEY_CONFIRM: Key = KEY_ENTER


## Each test builds and frees its own slice, and a freed UI can leave the shared
## viewport's key focus pointing at a dead control. That would make the NEXT
## test's first confirm vanish — the very symptom under investigation here — for a
## reason that has nothing to do with the code being tested. Clearing it per test
## keeps a failure meaning what it says.
func before_test() -> void:
	get_viewport().gui_release_focus()


func _make_root() -> VerticalSliceRoot:
	var root: VerticalSliceRoot = auto_free(
		load("res://scenes/vertical_slice.tscn").instantiate())
	add_child(root)
	await get_tree().process_frame
	return root


## Pushes one press+release of [param key] through the viewport and lets the
## frame settle, so GUI focus routing and `_unhandled_input` both see it in the
## order the engine would deliver them.
func _tap(key: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await get_tree().process_frame


## Steps keyboard focus down the open menu until [param label]'s row has it, and
## asserts it got there. Disabled rows are not focusable, so failing to arrive
## means the verb is unavailable — which is a real and different failure from the
## input one these tests are about, and must not be allowed to masquerade as it by
## letting a later confirm activate whatever row focus happened to be sitting on.
func _focus_row(root: VerticalSliceRoot, label: String) -> void:
	for _i: int in range(8):
		var focus: Control = root.get_viewport().gui_get_focus_owner()
		if focus is Button and (focus as Button).text == label:
			return
		await _tap(KEY_DOWN)
	var landed: Control = root.get_viewport().gui_get_focus_owner()
	assert_str(landed.text if landed is Button else "<none>").override_failure_message(
		"could not put keyboard focus on the '%s' row — it is absent or disabled" % label
	).is_equal(label)


## A tile [param unit] can legally move to, or its own position when it is boxed
## in. Asked of [Movement] — the owning system — rather than guessed.
func _a_reachable_tile(root: VerticalSliceRoot, unit: UnitState) -> Vector2i:
	for reach: Movement.ReachableTile in Movement.reachable(root.state(), unit):
		if reach.tile != unit.position:
			return reach.tile
	return unit.position


## Walks the board cursor onto [param target] with arrow keys only, one axis at a
## time. Returns early if the cursor stops responding, so a failure surfaces as
## "the cursor never arrived" rather than as a hang.
func _steer_cursor_to(root: VerticalSliceRoot, target: Vector2i) -> void:
	for _i: int in range(40):
		var here: Vector2i = root.cursor_tile()
		if here == target:
			return
		var delta: Vector2i = target - here
		if delta.x != 0:
			await _tap(KEY_RIGHT if delta.x > 0 else KEY_LEFT)
		else:
			await _tap(KEY_DOWN if delta.y > 0 else KEY_UP)
		if root.cursor_tile() == here:
			return # cursor refused to move — let the caller's assert report it


## Waits out [member InputConfig.input_lock_ms], the DELIBERATE post-commit
## debounce in [method CommandInterface.dispatch_commit].
##
## ⚠ Not a fudge for flakiness — it is the real rule of the interface. Every commit
## locks input for that window so a held or double-tapped confirm cannot fire the
## same action twice, and a commit attempted inside it is refused outright. Test
## keystrokes land microseconds apart, far faster than any hand, so without this a
## test would be measuring the debounce rather than the flow. A player never
## notices it; 120 ms is shorter than a deliberate second keypress.
func _settle_input_lock() -> void:
	await get_tree().create_timer(InputConfig.new().input_lock_ms / 1000.0 + 0.05).timeout


func _own_unit(root: VerticalSliceRoot) -> UnitState:
	for e: EntityState in root.state().entities():
		if e is UnitState and e.owner == 0:
			return e as UnitState
	return null


## Deploys a unit and then hands the turn round so it is actually able to act.
##
## ⚠ A unit CANNOT move on the turn it is produced, so a test that deploys one and
## immediately opens its menu finds Move disabled. Skipping this step made an
## earlier draft of these tests pass green while confirming on the [i]Wait[/i] row —
## the exact false-pass this suite exists to prevent. Returns the unit, now
## standing on a fresh turn with its full allowance.
func _deploy_a_unit_and_end_the_turn(root: VerticalSliceRoot) -> UnitState:
	var unit: UnitState = await _deploy_a_unit_by_keyboard(root)
	if unit == null:
		return null
	# The menu re-opens on the HQ after the deploy commits (spec: "Commit | Menu
	# re-opens on the same entity"), and while it holds focus it owns BOTH the
	# arrows and confirm. Backing out first is what a player does too — it is the
	# documented way to let go of one entity and go looking for another.
	await _back_out_of_any_open_menu(root)
	root.try_end_human_turn()
	for _i: int in range(600): # bounded: a hung AI turn must fail, not hang
		if not root.is_ai_turn_running() and root.state().active_player == 0:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	await _back_out_of_any_open_menu(root)
	await _steer_cursor_to(root, unit.position)
	return unit


## Presses Esc only while a menu row actually holds focus. Guarded because Esc
## with nothing selected opens the PAUSE overlay (`action-menu.md` AC-11), which
## would freeze the tree and strand the rest of the test.
func _back_out_of_any_open_menu(root: VerticalSliceRoot) -> void:
	for _i: int in range(4):
		var focus: Control = root.get_viewport().gui_get_focus_owner()
		if not (focus is Button):
			return
		await _tap(KEY_ESCAPE)


## Deploys one unit using nothing but the keyboard. The match opens with two HQs
## and no units at all, so this is also the first half of AC-9's journey.
func _deploy_a_unit_by_keyboard(root: VerticalSliceRoot) -> UnitState:
	# The cursor starts on the player's HQ.
	await _tap(KEY_CONFIRM)  # select HQ -> menu opens, first enabled row focused
	# Walk down to Produce and take it. Focus starts on the first enabled row;
	# stepping until the row under focus is the one wanted keeps this robust
	# against row-order changes rather than hard-coding a number of presses.
	for _i: int in range(6):
		var focus: Control = root.get_viewport().gui_get_focus_owner()
		if focus is Button and (focus as Button).text == "Produce":
			break
		await _tap(KEY_DOWN)
	await _tap(KEY_CONFIRM)  # open the Produce submenu
	await _tap(KEY_CONFIRM)  # take the first buildable unit in it
	# The interface snaps the cursor onto a legal deploy tile, so confirm places.
	await _tap(KEY_CONFIRM)
	await _settle_input_lock()
	return _own_unit(root)


# ==============================================================================
# AC-9 — the whole journey, no mouse.
# ==============================================================================

func test_a_unit_can_be_produced_with_the_keyboard_alone() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var unit: UnitState = await _deploy_a_unit_by_keyboard(root)
	assert_object(unit).override_failure_message(
		"AC-9: producing a unit from the HQ using only Enter and the arrow keys " +
		"must deploy it. Nothing was deployed."
	).is_not_null()


func test_choosing_a_verb_hands_the_arrow_keys_back_to_the_board_cursor() -> void:
	# ★ THE REGRESSION. Picking Move must release menu focus, or the arrow keys
	# keep driving a menu that is fading out instead of the board cursor.
	var root: VerticalSliceRoot = await _make_root()
	var unit: UnitState = await _deploy_a_unit_and_end_the_turn(root)
	assert_object(unit).is_not_null()

	await _tap(KEY_CONFIRM)  # select the unit the cursor is standing on
	await _focus_row(root, "Move")
	await _tap(KEY_CONFIRM)  # choose Move -> the board owns the arrows again

	assert_object(root.get_viewport().gui_get_focus_owner()).override_failure_message(
		"AC-9: after a verb is chosen the menu must not hold keyboard focus — " +
		"a focused row consumes the arrow keys the player needs to steer the " +
		"cursor onto a target tile."
	).is_null()

	var before: Vector2i = root.cursor_tile()
	await _tap(KEY_DOWN)
	assert_vector(root.cursor_tile()).override_failure_message(
		"AC-9: the cursor must move inside a preview. It stayed on %s, which is " +
		"the unit's own tile — confirming there would be a no-op, which is " +
		"exactly what 'the action did nothing' looks like to a player."
	).is_not_equal(before)


func test_a_full_move_completes_on_the_keyboard_alone() -> void:
	var root: VerticalSliceRoot = await _make_root()
	var unit: UnitState = await _deploy_a_unit_and_end_the_turn(root)
	assert_object(unit).is_not_null()
	var origin: Vector2i = unit.position

	await _tap(KEY_CONFIRM)  # select the unit
	await _focus_row(root, "Move")
	await _tap(KEY_CONFIRM)  # choose Move

	# Steer onto a tile the unit can actually reach and commit — the last two beats
	# of AC-9. The destination is queried rather than assumed: the unit deploys
	# beside the HQ, so a blind step in a fixed direction can land on the HQ's own
	# occupied tile and fail for a reason that has nothing to do with input.
	var destination: Vector2i = _a_reachable_tile(root, unit)
	assert_vector(destination).override_failure_message(
		"test setup: the unit has nowhere to move, so this cannot test moving"
	).is_not_equal(unit.position)
	await _steer_cursor_to(root, destination)
	assert_vector(root.cursor_tile()).override_failure_message(
		"AC-9: the arrow keys must be able to walk the cursor to %s" % destination
	).is_equal(destination)
	await _tap(KEY_CONFIRM)

	assert_vector(unit.position).override_failure_message(
		"AC-9: cursor to the unit, Enter, arrow to Move, Enter, arrow to a tile, " +
		"Enter — the unit must end up somewhere new. It never left %s." % origin
	).is_not_equal(origin)
