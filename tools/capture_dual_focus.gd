## capture_dual_focus.gd — S8-09: does Redot 26.2 actually give us dual focus?
##
## [b]Why this exists.[/b] `design/ux/action-menu.md` (Accessibility) commits to
## THREE distinct attention states — mouse-hover, board cursor, and menu
## keyboard-focus — and says of the third:
##
##     "it is the genuine Godot 4.6 dual-focus case — mouse focus and keyboard
##      focus are separate subsystems and can both be live, so the focused row's
##      indicator must be visually distinct from the hovered row's.
##      [i]Redot 26.2 fork parity on this behaviour is assumed, not verified.[/i]"
##
## `production/qa/ux-review-action-menu-2026-08-25.md` advisory 4 carried that
## forward as the spec's last open item. This harness closes it by MEASURING the
## behaviour instead of assuming it, on the real widget with the real theme.
##
## [b]Why it has to be windowed.[/b] The headless dummy rasteriser stores state and
## reports draw modes happily without ever producing a pixel — the same false
## positive that hid the Story 007 glow bug behind a green suite. The engine-state
## half of this check would pass headless; the "are they visually DISTINCT" half is
## a question about drawn pixels and can only be answered from a framebuffer.
##
## [b]What it asserts.[/b] Three independent layers, each of which could fail alone:
##   1. [b]State[/b] — a focused Button keeps [code]has_focus()[/code] while a
##      DIFFERENT Button is hovered, and that other Button reports
##      [code]DRAW_HOVER[/code]. If the fork collapsed the two subsystems, hovering
##      would steal or clear focus and this fails first.
##   2. [b]Theme[/b] — the rows resolve a "focus" StyleBox that is not the same
##      resource as "hover" or "normal". The rows are [code]flat = true[/code], and
##      a flat Button suppresses its normal/hover box, so the focus box is the ONLY
##      thing carrying the keyboard cue. If it resolved to an empty box the cue
##      would be font brightness alone — and the row code deliberately sets
##      font_focus_color and font_hover_color to the SAME white, so brightness
##      cannot separate them.
##   3. [b]Pixels[/b] — the drawn focused row differs from a resting row, the drawn
##      hovered row differs from a resting row, and focused differs from hovered.
##      That last one is the spec's actual claim.
##
## Usage (opens a window on the current display, then closes itself):
## [codeblock]
## DISPLAY=:0 ./redot tools/CaptureDualFocus.tscn
## [/codeblock]
## Verdict prints to stdout; frames land in `production/qa/evidence/s8-09-dual-focus/`.
##
## [b]A normal scene, not a `--script` SceneTree main loop.[/b] Same reason as
## capture_evidence.gd: the SceneTree form creates a rendering device but never
## produces a drawn frame, so the capture awaits a post-draw that never comes and
## hangs. Do not "simplify" this back to `--script`.
extends Node2D

const OUT_DIR: String = "res://production/qa/evidence/s8-09-dual-focus"
const VIEW: Vector2i = Vector2i(1600, 900)

## Where the menu is anchored. Well clear of every viewport edge so the plate's
## flip/clamp rules (AC-6/7/8) never fire and move a row out from under the
## sampling rects mid-run.
const ANCHOR: Vector2 = Vector2(560.0, 520.0)
const TILE_WIDTH_PX: float = 128.0

## Mean per-channel difference (0-1) above which two sampled bands are called
## "different". Well above sampling noise on a static, tween-free plate — the menu
## is opened with reduced_motion so nothing is animating — and well below the
## contrast of an actual drawn outline.
const DIFF_EPSILON: float = 0.01

## Depth of the outline band [method _sample] reads, measured OUTWARD and INWARD
## from the row's own rect.
##
## ★ Straddling the boundary is load-bearing, not caution. Measured on Redot 26.2:
## a row at x 700..885, y 521..548 draws its focus border at x 699 / x 886 and
## y 519-520 / y 549-550 — i.e. the theme's focus StyleBox carries expand margins
## and the cue lands ENTIRELY OUTSIDE the button it belongs to. The first pass of
## this harness sampled a ring 3px *inside* the rect, never touched a single lit
## pixel, and reported "the keyboard cue does not render" about an outline plainly
## visible in the very screenshot it had just saved.
const RING_PX: int = 3

## Frames [method _hover] / [method _unhover] will spend re-asserting the mouse
## position before giving up. Generous: it costs nothing when the first attempt
## takes, and a window that has just opened can take several frames to settle.
const HOVER_SETTLE_FRAMES: int = 30

## Per-channel change above which one pixel counts as having moved. ~1/255, so it
## catches a real redraw and ignores nothing — the capture is deterministic, with
## no tweens running and no dithering in play.
const PIXEL_EPSILON: float = 0.004

## Two readings of one row, because the two cues live in different places and a
## single average hides both. [member ring] is the 3px band just inside the row's
## rect, where a focus StyleBox draws its border; [member whole] is the entire row
## including its label, where a font-colour change (all this fork's flat Buttons can
## express for hover) would show. Averaging the row into one number dilutes a 2px
## outline across ~200px of unchanged plate and reports "no difference" for a cue
## that is plainly visible — which is exactly what the first pass of this harness did.
class Sample:
	var ring: Color
	var whole: Color
	## Every pixel of the row's rect GROWN by [constant RING_PX], kept so two frames
	## can be compared pixel for pixel instead of average against average.
	##
	## ★ Grown, not the own rect. The focus outline is drawn entirely outside the
	## button (see [constant RING_PX]), so counting only the own rect scored focus
	## at 5.8% and hover at 3.6% — both of which were purely the LABEL changing
	## colour, with the outline, the actual cue, contributing nothing. Safe to grow
	## here because every comparison is one row across two frames: whatever a
	## neighbour draws into this band is present identically in both.
	##
	## ★ Averages hide small marks. Hover here lifts ~3% of the row's pixels (the
	## glyphs, and only the glyphs) from LABEL_ENABLED to white, which moves the
	## row's mean by 0.0013 — indistinguishable from noise, and the harness duly
	## reported "hover renders nothing" about a change that is really there. The
	## outline was the same story in reverse. Count the pixels that moved.
	var pixels: PackedColorArray

	func _init(ring_avg: Color, whole_avg: Color, whole_px: PackedColorArray) -> void:
		ring = ring_avg
		whole = whole_avg
		pixels = whole_px


## Whether mouse-hover produced ANY pixel change. Reported, never asserted — see
## the note at its assignment in [method _run].
var _hover_renders: bool = false
## Fraction of each row's pixels the cue moves. The honest size of each mark.
var _hover_changed: float = 0.0
var _focus_changed: float = 0.0

var _menu: ActionMenu
var _rows: Array[Button] = []
var _failures: Array[String] = []
var _checks: Array[String] = []


func _ready() -> void:
	get_window().size = VIEW
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _run()
	_report()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	_build_menu()
	# One drawn frame before anything is measured: rows have no real rect until the
	# container has laid out, and every sample below is taken from those rects.
	await RenderingServer.frame_post_draw
	await get_tree().process_frame

	_rows = _enabled_rows()
	if _rows.size() < 2:
		_failures.append(
			"FIXTURE: needed 2+ enabled rows to hover one and focus another, got %d."
			% _rows.size())
		return

	var focused: Button = _rows[0] # first enabled row — what open() focuses (AC-9).
	var hovered: Button = _rows[1]

	# --- Layer 2: theme ------------------------------------------------------
	# Checked before the pixels because a missing focus box explains a pixel
	# failure, and finding out in that order saves guessing at the image.
	_check_theme(focused)

	# --- Frame A: the control. Neither cue live. -----------------------------
	# ★ The baseline is the SAME rows with both cues off, not a different row.
	# An earlier pass compared the focused row against a neighbouring row and was
	# measuring the difference between two verbs' labels, not the focus cue.
	focused.release_focus()
	if not await _unhover(_rows):
		_failures.append("could not get the mouse OFF every row — the control frame is not a control")
	await RenderingServer.frame_post_draw
	var img_a: Image = _grab()
	_save(img_a, "01-neither")
	var a_focus_row: Sample = _sample(img_a, focused)
	var a_hover_row: Sample = _sample(img_a, hovered)

	# --- Frame B: keyboard focus only ----------------------------------------
	focused.grab_focus()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img_b: Image = _grab()
	_save(img_b, "02-focus-only")
	var b_focus_row: Sample = _sample(img_b, focused)
	# ★ The hover row is sampled HERE as well, not only in the control frame.
	# Its grown ring overlaps the focused row's outline (which is drawn outside the
	# focused row's rect and lands in its neighbour's band), so measuring hover as
	# C-minus-A would report the NEIGHBOUR'S focus cue as this row's hover cue —
	# a 0.107 reading that has nothing to do with the mouse. B and C both contain
	# that outline identically, so B-to-C isolates hover and nothing else.
	var b_hover_row: Sample = _sample(img_b, hovered)

	# --- Frame C: focus AND hover, on different rows, simultaneously ---------
	var hovered_ok: bool = await _hover(hovered)
	await RenderingServer.frame_post_draw

	# Layer 1: state, asserted while both are live.
	_expect(hovered_ok,
		"the mouse could be settled on a row that is not the focused one",
		"the engine never reported the row as hovered within %d frames — the measurement below is not trustworthy"
			% HOVER_SETTLE_FRAMES)
	_expect(focused.has_focus(),
		"focused row kept has_focus() while a different row was hovered",
		"hovering a different row CLEARED keyboard focus — the two subsystems are not independent in this fork")
	_expect(hovered.get_draw_mode() == BaseButton.DRAW_HOVER,
		"hovered row reports DRAW_HOVER while another row holds focus",
		"hovered row reported draw mode %d, not DRAW_HOVER (%d) — hover and focus are not independent"
			% [hovered.get_draw_mode(), BaseButton.DRAW_HOVER])
	_expect(not hovered.has_focus(),
		"mouse hover did NOT steal keyboard focus",
		"the hovered row took focus off the keyboard's row")

	var img_c: Image = _grab()
	_save(img_c, "03-focus-and-hover")
	var c_focus_row: Sample = _sample(img_c, focused)
	var c_hover_row: Sample = _sample(img_c, hovered)

	# --- Layer 3: pixels -----------------------------------------------------
	# Every comparison is the SAME row across two frames that differ in exactly one
	# thing. Comparing two different rows in one frame was tried and rejected: their
	# labels differ, so any delta is mostly typography.
	_expect(_differs(b_focus_row.ring, a_focus_row.ring),
		"the FOCUSED row draws a cue the same row does not draw unfocused",
		"the focused row is pixel-identical to itself unfocused — the keyboard cue does not render")

	var hover_ring_delta: float = _delta(c_hover_row.ring, b_hover_row.ring)
	_hover_changed = _changed_fraction(c_hover_row, b_hover_row)
	_focus_changed = _changed_fraction(b_focus_row, a_focus_row)
	_hover_renders = _hover_changed > 0.0

	# The spec's claim, stated as what actually has to be true for a player: the two
	# cues are different KINDS of mark. Focus draws an outline; hover does not add
	# one. So a keyboard player can always find their row, even with the mouse
	# resting on a different one.
	var focus_ring_delta: float = _delta(b_focus_row.ring, a_focus_row.ring)
	_expect(focus_ring_delta > DIFF_EPSILON and hover_ring_delta <= DIFF_EPSILON,
		"FOCUS and HOVER are different marks — focus adds an outline (%.4f), hover does not (%.4f)"
			% [focus_ring_delta, hover_ring_delta],
		"focus and hover both change the row's outline band (focus %.4f, hover %.4f) — a keyboard player cannot tell which row they are on while the mouse rests on another"
			% [focus_ring_delta, hover_ring_delta])

	# ★ Reported, NOT asserted. Whether mouse-hover should carry a visible state of
	# its own is a design question this harness has no standing to fail a build
	# over — so it is measured, named in the verdict, and left to the spec's owner.

	_log_measurements(a_focus_row, b_focus_row, c_focus_row, a_hover_row, b_hover_row, c_hover_row)


## Builds a real ActionMenu over a real GameState. A producer with plenty of AP and
## Credits is used because it yields the most ENABLED rows, and only enabled rows
## are focusable (AC-5) — a disabled row could not stand in for either state.
func _build_menu() -> void:
	var host := Control.new()
	host.size = Vector2(VIEW)
	add_child(host)

	var state: GameState = _make_state()
	state.grid = _blank_grid(12)
	for i: int in state.per_player.size():
		state.per_player[i].faction = Factions.NEUTRAL
	state.per_player[0].current_ap = 20
	state.per_player[0].current_credits = 500

	var producible: Array[UnitTypeDef] = [_unit_type("Scout"), _unit_type("Sniper")]
	var producer: StructureState = _place_producer(state, 1, 0, Vector2i(5, 5), producible)

	_menu = ActionMenu.new()
	# No fades: a mid-tween alpha would make every pixel comparison below a
	# measurement of the tween rather than of the focus cue.
	_menu.configure(true)
	host.add_child(_menu)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.open(state, producer, ANCHOR, TILE_WIDTH_PX)


## A two-player, round-1, in-progress [GameState].
##
## ★ Built here rather than via [code]GameStateFactory[/code], which does exactly
## this in three lines. The factory is declared under [code]tests/[/code], the
## export preset strips that directory, and `export_safety_test.gd` correctly fails
## any production or tools script that reaches into it — a reference that resolves
## in every build a developer runs and crashes in the shipped one. Inlining is the
## fix that guard asks for; adding the symbol to its allowlist is not.
func _make_state() -> GameState:
	var state := GameState.new()
	for _i: int in 2:
		state.per_player.append(PlayerState.new())
	state.active_player = 0
	state.round_number = 1
	state.match_status = GameState.MatchStatus.IN_PROGRESS
	return state


func _blank_grid(size: int) -> GridState:
	var grid := GridState.new()
	grid.width = size
	grid.height = size
	grid.terrain = PackedByteArray()
	grid.terrain.resize(size * size)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(size * size)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	return grid


func _unit_type(display: String) -> UnitTypeDef:
	var type := UnitTypeDef.new()
	type.display_name = display
	type.hp = 10
	type.attack = 3
	type.attack_range = 1
	type.move_cost = 1
	type.soft_move_cap = 8
	type.produce_cost = 4
	return type


func _place_producer(state: GameState, id: int, owner: int, pos: Vector2i, \
		producible: Array[UnitTypeDef]) -> StructureState:
	var type := StructureTypeDef.new()
	type.display_name = "Factory"
	type.hp = 20
	type.build_cost = 6
	type.build_time = 2
	type.production_cap = 2
	type.producible_types = producible
	var structure := StructureState.new()
	structure.entity_id = id
	structure.owner = owner
	structure.position = pos
	structure.type = type
	structure.current_hp = type.hp
	structure.build_status = StructureState.BuildStatus.COMPLETED
	state.entities_by_id[id] = structure
	state.grid.occupancy[state.grid.index(pos.x, pos.y)] = id
	return structure


## The menu's verb rows that can actually take focus, in visual order.
func _enabled_rows() -> Array[Button]:
	var found: Array[Button] = []
	var plate: Node = _menu.get_node_or_null(^"MenuPlate")
	if plate == null:
		return found
	for child: Node in plate.get_child(0).get_children():
		if child is Button and not (child as Button).disabled:
			found.append(child as Button)
	return found


## Puts the mouse over [param row]'s centre and does not return until the engine
## agrees it is hovered, or the budget runs out.
##
## ★ The retry is not defensive padding. A synthetic motion event sets the
## viewport's hover immediately, but the OS delivers its own enter/motion events
## for the real cursor when a freshly-opened window settles under (or away from)
## it, and those land a frame or two later and overwrite it. Pushing once and
## capturing gave DRAW_HOVER on some runs and DRAW_NORMAL on others depending on
## where the operator's mouse happened to be — a coin-flip measurement, which is
## worse than no measurement. Re-asserting every frame until the engine confirms
## makes the result independent of the real cursor.
func _hover(row: Button) -> bool:
	for _attempt: int in HOVER_SETTLE_FRAMES:
		_push_motion(row.get_global_rect().get_center())
		await get_tree().process_frame
		if row.get_draw_mode() == BaseButton.DRAW_HOVER:
			return true
	return false


## Parks the mouse in a corner far from the plate and waits for the engine to agree
## nothing is hovered. Same reasoning as [method _hover].
func _unhover(rows: Array[Button]) -> bool:
	for _attempt: int in HOVER_SETTLE_FRAMES:
		_push_motion(Vector2(4, 4))
		await get_tree().process_frame
		var any: bool = false
		for row: Button in rows:
			if row.get_draw_mode() == BaseButton.DRAW_HOVER:
				any = true
		if not any:
			return true
	return false


## Synthesised rather than warped, so the run neither moves the operator's real
## cursor nor depends on where it was sitting.
func _push_motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev)


func _check_theme(row: Button) -> void:
	var focus_box: StyleBox = row.get_theme_stylebox("focus")
	var hover_box: StyleBox = row.get_theme_stylebox("hover")
	_expect(focus_box != null,
		"rows resolve a 'focus' StyleBox from the theme",
		"rows resolve NO 'focus' StyleBox — flat rows would have no keyboard cue but font colour, which is identical to hover's by design")
	_expect(focus_box != hover_box,
		"the 'focus' StyleBox is a different resource from 'hover'",
		"'focus' and 'hover' resolve to the SAME StyleBox resource — they cannot render differently")
	_checks.append("      focus box: %s | hover box: %s | row is flat: %s"
		% [_box_desc(focus_box), _box_desc(hover_box), row.flat])


func _box_desc(box: StyleBox) -> String:
	if box == null:
		return "<none>"
	if box is StyleBoxEmpty:
		return "StyleBoxEmpty (draws nothing)"
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		return "StyleBoxFlat border=%d colour=%s centre=%s" \
			% [flat.border_width_top, flat.border_color, flat.draw_center]
	return box.get_class()


## Reads [param row] out of [param img] as a [Sample] — see that class for why one
## average is not enough.
func _sample(img: Image, row: Button) -> Sample:
	var empty := Color(0, 0, 0, 0)
	if row == null:
		return Sample.new(empty, empty, PackedColorArray())
	var own: Rect2i = Rect2i(row.get_global_rect())
	# Grown by RING_PX so a cue drawn outside the rect (see RING_PX) is inside the
	# sampled area, then clipped to the image so an edge row cannot read out of bounds.
	var r: Rect2i = own.grow(RING_PX).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		_failures.append("row '%s' has no usable on-screen rect (%s) — nothing was sampled"
			% [row.text, r])
		return Sample.new(empty, empty, PackedColorArray())
	var ring_total := Vector4.ZERO
	var whole_total := Vector4.ZERO
	var ring_n: int = 0
	var whole_n: int = 0
	var px := PackedColorArray()
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var c: Color = img.get_pixel(x, y)
			var v := Vector4(c.r, c.g, c.b, c.a)
			# "whole" stays the row's OWN rect. Widening it to the grown rect would
			# pull in the neighbouring row's label and make every row look alike.
			px.append(c)
			if own.has_point(Vector2i(x, y)):
				whole_total += v
				whole_n += 1
			# The band is 2*RING_PX deep, centred on the row's own boundary: inside
			# it for an ordinary border, outside it for an expanded one.
			var on_edge: bool = (x - own.position.x) < RING_PX \
				or (own.end.x - x) <= RING_PX \
				or (y - own.position.y) < RING_PX \
				or (own.end.y - y) <= RING_PX
			if on_edge:
				ring_total += v
				ring_n += 1
	return Sample.new(_mean(ring_total, ring_n), _mean(whole_total, whole_n), px)


func _mean(total: Vector4, n: int) -> Color:
	if n == 0:
		return Color(0, 0, 0, 0)
	return Color(total.x / n, total.y / n, total.z / n, total.w / n)


## Fraction of [param a]'s pixels that differ from [param b]'s by more than
## [constant PIXEL_EPSILON] on any channel, over the row's grown rect. Two samples
## of the SAME row in two frames; 0.0 means the row is untouched.
func _changed_fraction(a: Sample, b: Sample) -> float:
	if a.pixels.size() == 0 or a.pixels.size() != b.pixels.size():
		return 0.0
	var moved: int = 0
	for i: int in a.pixels.size():
		var p: Color = a.pixels[i]
		var q: Color = b.pixels[i]
		if absf(p.r - q.r) > PIXEL_EPSILON or absf(p.g - q.g) > PIXEL_EPSILON \
				or absf(p.b - q.b) > PIXEL_EPSILON:
			moved += 1
	return float(moved) / float(a.pixels.size())


func _differs(a: Color, b: Color) -> bool:
	return _delta(a, b) > DIFF_EPSILON


func _delta(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


func _save(img: Image, name: String) -> void:
	var path: String = "%s/%s.png" % [OUT_DIR, name]
	var err: Error = img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_failures.append("could not write %s (error %d)" % [path, err])


func _expect(ok: bool, pass_msg: String, fail_msg: String) -> void:
	if ok:
		_checks.append("  PASS  %s" % pass_msg)
	else:
		_checks.append("  FAIL  %s" % fail_msg)
		_failures.append(fail_msg)


func _log_measurements(a_focus: Sample, b_focus: Sample, c_focus: Sample, \
		a_hover: Sample, b_hover: Sample, c_hover: Sample) -> void:
	_checks.append("")
	_checks.append("  Sampled rows. 'ring' = a %dpx band straddling the row's own boundary" % RING_PX)
	_checks.append("  (the focus box draws OUTSIDE the rect); 'whole' = the row's own rect.")
	_checks.append("    focus row  A neither          ring %s  whole %s" % [_fmt(a_focus.ring), _fmt(a_focus.whole)])
	_checks.append("    focus row  B focused          ring %s  whole %s" % [_fmt(b_focus.ring), _fmt(b_focus.whole)])
	_checks.append("    focus row  C focus + hover    ring %s  whole %s" % [_fmt(c_focus.ring), _fmt(c_focus.whole)])
	_checks.append("    hover row  A neither          ring %s  whole %s" % [_fmt(a_hover.ring), _fmt(a_hover.whole)])
	_checks.append("    hover row  B neighbour focused ring %s  whole %s" % [_fmt(b_hover.ring), _fmt(b_hover.whole)])
	_checks.append("    hover row  C + hovered        ring %s  whole %s" % [_fmt(c_hover.ring), _fmt(c_hover.whole)])
	_checks.append("")
	_checks.append("  Deltas (mean per-channel, threshold %.3f). Each is one row across two" % DIFF_EPSILON)
	_checks.append("  frames differing in exactly one thing:")
	_checks.append("    focus cue   (focus row, B vs A)    ring %.4f  whole %.4f"
		% [_delta(b_focus.ring, a_focus.ring), _delta(b_focus.whole, a_focus.whole)])
	_checks.append("    hover cue   (hover row, C vs B)    ring %.4f  whole %.4f"
		% [_delta(c_hover.ring, b_hover.ring), _delta(c_hover.whole, b_hover.whole)])
	_checks.append("")
	_checks.append("  Pixels actually moved, over the row's rect grown by %dpx so an" % RING_PX)
	_checks.append("  outline drawn outside the button is counted (the metric an average hides):")
	_checks.append("    focus cue moves %.1f%% of the row's pixels" % (_focus_changed * 100.0))
	_checks.append("    hover cue moves %.1f%% of the row's pixels" % (_hover_changed * 100.0))
	_checks.append("")
	_checks.append("  ⚠ hover row A-vs-C would read ring %.4f, but that is the FOCUSED row's"
		% _delta(c_hover.ring, a_hover.ring))
	_checks.append("    outline bleeding into its neighbour's band, not a hover cue. Not used.")


func _fmt(c: Color) -> String:
	return "(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]


func _report() -> void:
	print("")
	print("=== S8-09 — Redot 26.2 dual-focus parity (action-menu.md Accessibility) ===")
	for line: String in _checks:
		print(line)
	print("")
	if _failures.is_empty():
		print("VERDICT: PASS — mouse hover and keyboard focus are independent state in")
		print("         Redot 26.2, and the focused row carries a mark the hovered row")
		print("         does not. The spec's assumption holds.")
	else:
		print("VERDICT: FAIL — %d check(s) failed:" % _failures.size())
		for f: String in _failures:
			print("  - %s" % f)
	print("")
	if _hover_renders:
		print("Hover DOES render, but only just: it moves %.1f%% of the row's pixels (the"
			% (_hover_changed * 100.0))
		print("  glyphs alone) against %.1f%% for focus, and lifts them from LABEL_ENABLED"
			% (_focus_changed * 100.0))
		print("  (0.90, 0.94, 1.00) to white — a change too small to register in the row's")
		print("  mean colour at all. Flat Buttons suppress the theme's hover StyleBox, so")
		print("  there is no box to draw and the font colour is all hover has.")
		print("  ⇒ The two cues ARE tellable apart, because focus is a box and hover is not.")
		print("    But hover on its own is close to invisible. Whether that is enough for")
		print("    the spec's third attention state is a design call, not a build failure.")
	else:
		print("NOTE (not a failure): mouse-hover produced NO pixel change at all. Focus is")
		print("  distinguishable from hover only because hover draws nothing, which meets")
		print("  the spec's letter but not its 'three distinct attention states'. A design")
		print("  call for the spec's owner.")
	print("Frames: %s" % OUT_DIR)
