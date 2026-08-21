## capture_evidence.gd — windowed screenshot harness for Visual/Feel evidence (S5-07).
##
## [b]Why this exists.[/b] Every Visual/Feel acceptance criterion in this project has
## been carried as "OWED — requires a windowed session" since Story 002, because the
## headless dummy rasteriser cannot render: it happily stores instance uniforms,
## runs tweens and builds textures without ever producing a pixel. That is the exact
## false positive that hid Story 007's squared-alpha glow bug through a fully green
## suite. This harness closes the gap by rendering the REAL presentation stack —
## BoardRenderer, EntitySpriteFeed, EntityGlow, EntityTransforms, OwnershipMarker,
## the real art and the real shader — into a real framebuffer, and saving frames.
##
## It is deliberately NOT a test. It asserts nothing; it produces images for a human
## to sign off, which is what the testing standards say Visual/Feel evidence is.
##
## Usage (needs a display — this will open a window, then close itself):
## [codeblock]
## ./redot tools/CaptureEvidence.tscn
## [/codeblock]
## Frames land in `production/qa/evidence/s5-07-windowed/`.
##
## [b]A normal scene, not a `--script` SceneTree main loop.[/b] The SceneTree form
## created a rendering device but never produced a drawn frame, so the capture
## awaited a post-draw that never came and hung. A scene run through the ordinary
## main loop renders normally — do not "simplify" this back to `--script`.
extends Node2D

const OUT_DIR: String = "res://production/qa/evidence/s5-07-windowed"
const VIEW_SIZE: Vector2i = Vector2i(1280, 720)

## Board origin, chosen so a 6x6 patch sits centred in the viewport.
const ORIGIN: Vector2 = Vector2(640.0, 200.0)

## Engine time scale used while capturing the §8.5 motion transforms. Tweens run on
## engine time, so slowing the clock stretches a 0.35s beat over ~7 real seconds and
## makes a mid-flight capture reliable regardless of frame rate. See the comment at
## the motion section for why this is load-bearing rather than cosmetic.
const SLOW_MOTION_SCALE: float = 0.05

var _root: Node2D
var _board: BoardRenderer
var _feed: EntitySpriteFeed
var _shots: int = 0


func _ready() -> void:
	get_window().size = VIEW_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run()


func _run() -> void:
	_build_board()
	await _capture("01-board-idle",
		"Board at rest: real terrain, real entity art, glow breathing, ownership decals on structures.")

	# --- Glow: AP-available vs AP-spent (S5-02 AC-4, the Pillar-1 read) ---------
	# Captured at PINNED breathe phases, not wherever the sine happened to be.
	# The first pass of this harness caught the breathe near its trough and made the
	# available-vs-spent gap look far smaller than it is — an artefact of the
	# capture, not a property of the glow. Peak and trough are both captured so the
	# envelope is documented rather than a single arbitrary sample.
	_feed.actionable_predicate = func(_e: EntityState) -> bool: return true
	_feed.sync(_entities())
	_set_breathe_phase(0.25) # sin peak -> BREATHE_MAX
	await _capture("02-glow-ap-available-peak",
		"AP-available at the breathe PEAK (pulse 0.85) — the brightest an idle actor gets.")
	_set_breathe_phase(0.75) # sin trough -> BREATHE_MIN
	await _capture("02b-glow-ap-available-trough",
		"AP-available at the breathe TROUGH (pulse 0.25) — the dimmest an idle actor gets. The gap between this and 03 is the WORST case for the Pillar-1 read.")
	_feed.actionable_predicate = func(_e: EntityState) -> bool: return false
	_feed.sync(_entities())
	await _capture("03-glow-ap-spent",
		"Every actor AP-spent — glow clamped to 0.08. Compare against 02 (best case) and 02b (worst case): this is the Pillar-1 'can it still act' read.")
	_feed.actionable_predicate = Callable()
	_feed.sync(_entities())

	# --- S5-06 motion transforms ------------------------------------------------
	# ★ Time is slowed for this whole section. The transforms are 0.05-0.35s long,
	# and _capture_after accumulates REAL frame deltas — so on a slow or unfocused
	# window a single frame can exceed the entire beat and every capture lands after
	# it finished. The first run of this harness did exactly that: it produced a
	# "death echo" frame with the unit already gone and no wreck, which looked like a
	# product bug and was not one. Slowing the clock makes the captures independent
	# of frame rate. Do not remove this without replacing it with something that is.
	Engine.time_scale = SLOW_MOTION_SCALE
	var mover: int = 11
	_feed.lean(mover, Vector2(80.0, 40.0))
	await _capture_after("04-move-lean-peak", 0.09,
		"Move lean at peak: the unit tips into its direction of travel, pivoting at its feet.")
	await _settle()

	var attacker: int = 11
	var target: int = 21
	_feed.lunge(attacker, target)
	_feed.flare(attacker)
	_feed.recoil(target, attacker)
	await _capture_after("05-attack-lunge-and-recoil", 0.07,
		"Attack at peak: attacker lunges toward its target with the glow flare on the same frame; target rocks away.")
	await _settle()

	_feed.power_down(21)
	await _capture_after("06-death-echo-mid", EntityTransforms.DEATH_ECHO_SEC * 0.5,
		"Destroyed beat, halfway: idle art cross-fading into destroyed art, glow falling to zero. A power-down, not an explosion.")
	await _capture_after("07-death-echo-late", EntityTransforms.DEATH_ECHO_SEC * 0.4,
		"Destroyed beat, late: the wreck has taken over and the light is gone.")
	await _settle()

	Engine.time_scale = 1.0

	# --- S5-08 ownership markers -------------------------------------------------
	_feed.marker_policy = EntitySpriteFeed.MarkerPolicy.ALL
	_feed.sync(_entities())
	await _capture("08-markers-all",
		"marker_policy = ALL (rejected): a decal under every entity. Compare 09 — this is the clutter that drove the STRUCTURES_ONLY decision.")
	_feed.marker_policy = EntitySpriteFeed.MarkerPolicy.STRUCTURES_ONLY
	_feed.sync(_entities())
	await _capture("09-markers-structures-only",
		"marker_policy = STRUCTURES_ONLY (shipped): ownership declared where the measurement found it weak, board otherwise clean.")

	# --- Overlays under/over the marker layer ------------------------------------
	var tiles: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 3)]
	_board.set_overlay(tiles, BoardRenderer.OverlayClass.MOVE_IN_CAP)
	await _capture("10-overlay-over-marker",
		"A reachable-range overlay across an owned tile: ownership must stay legible THROUGH the highlight (MarkerLayer draws above OverlayTileMapLayer).")
	_board.clear_overlay()

	print("\ncaptured %d frames -> %s" % [_shots, OUT_DIR])
	get_tree().quit()


# --- Scene construction -------------------------------------------------------

func _build_board() -> void:
	_root = Node2D.new()
	_root.position = ORIGIN
	add_child(_root)
	_board = BoardRenderer.new()
	_root.add_child(_board)
	var grid := GridState.new()
	grid.width = 8
	grid.height = 8
	grid.terrain = PackedByteArray()
	grid.terrain.resize(64)
	grid.terrain.fill(GridState.Terrain.PLAIN)
	grid.occupancy = PackedInt32Array()
	grid.occupancy.resize(64)
	grid.occupancy.fill(GridState.EMPTY_OCCUPANT)
	grid.terrain[grid.index(5, 1)] = GridState.Terrain.COVER
	_board.paint_terrain(grid)
	_feed = EntitySpriteFeed.new(_board, [Factions.RUSH, Factions.BOOM] as Array[FactionDef])
	_feed.sync(_entities())


## A representative board: both factions, a structure each, a mixed unit roster.
func _entities() -> Array[EntityState]:
	return [
		_structure(1, 0, Vector2i(1, 1), StructureTypes.HQ),
		_structure(2, 1, Vector2i(5, 5), StructureTypes.HQ),
		_unit(11, 0, Vector2i(2, 3), UnitTypes.TROOPER),
		_unit(12, 0, Vector2i(1, 4), UnitTypes.SCOUT),
		_unit(13, 0, Vector2i(3, 4), UnitTypes.HEAVY),
		_unit(21, 1, Vector2i(3, 3), UnitTypes.TROOPER),
		_unit(22, 1, Vector2i(4, 4), UnitTypes.SCOUT),
		_unit(23, 1, Vector2i(5, 3), UnitTypes.SNIPER),
	] as Array[EntityState]


func _unit(id: int, owner: int, tile: Vector2i, type: UnitTypeDef) -> UnitState:
	var u := UnitState.new()
	u.entity_id = id
	u.owner = owner
	u.position = tile
	u.type = type
	u.current_hp = type.hp
	return u


func _structure(id: int, owner: int, tile: Vector2i, type: StructureTypeDef) -> StructureState:
	var s := StructureState.new()
	s.entity_id = id
	s.owner = owner
	s.position = tile
	s.type = type
	s.current_hp = type.hp
	s.build_status = StructureState.BuildStatus.COMPLETED
	return s


# --- Capture ------------------------------------------------------------------

## Advances the glow clock and real time by [param seconds], then captures. Used to
## catch a tween mid-flight rather than at rest — a settled frame proves nothing
## about motion.
func _capture_after(name: String, seconds: float, caption: String) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		var dt: float = await _frame()
		_feed.advance_glow(dt)
		# get_process_delta_time() is already scaled by Engine.time_scale, so this
		# accumulates the same clock the tweens are running on — which is the whole
		# point: `seconds` is expressed in tween time, not wall time.
		elapsed += dt
	await _capture(name, caption)


## Drives the glow clock to a known point in the breathe cycle, as a FRACTION of
## the period: 0.25 is the sine peak (BREATHE_MAX), 0.75 the trough (BREATHE_MIN).
##
## Without this the harness samples whatever phase the sine happened to be in when
## the frame landed, which makes the AP-available/AP-spent comparison depend on
## capture timing rather than on the glow. Pinning it is what makes two runs of
## this tool comparable to each other.
func _set_breathe_phase(fraction: float) -> void:
	var target: float = EntityGlow.BREATHE_PERIOD_SEC * fraction
	var delta: float = target - fmod(_feed.state_timer(), EntityGlow.BREATHE_PERIOD_SEC)
	if delta < 0.0:
		delta += EntityGlow.BREATHE_PERIOD_SEC
	_feed.advance_glow(delta)


## Lets every in-flight tween finish so the next capture starts from rest.
##
## Runs at NORMAL speed even inside the slowed motion section: settling is dead time
## with nothing to capture, and at 0.05x a 2-second settle costs 40 REAL seconds and
## blew the whole run past its timeout. Only the moments being photographed need the
## slow clock.
func _settle() -> void:
	var restore: float = Engine.time_scale
	Engine.time_scale = 1.0
	var elapsed: float = 0.0
	while elapsed < 1.2:
		var dt: float = await _frame()
		_feed.advance_glow(dt)
		elapsed += dt
	Engine.time_scale = restore


func _frame() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _capture(name: String, caption: String) -> void:
	# Two frames plus an explicit post-draw wait: the first commits any pending
	# tree/uniform change, the second guarantees it reached the framebuffer we are
	# about to read back.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUT_DIR, name]
	image.save_png(ProjectSettings.globalize_path(path))
	_shots += 1
	print("  [%02d] %s — %s" % [_shots, name, caption])
