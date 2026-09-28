## VSMap — the single authored definition of the vertical slice's battlefield.
##
## [b]One source of truth, deliberately.[/b] Before S7-11 this map was hand-built in FOUR
## places — [VerticalSliceRoot], `tools/simulate_matches.gd`, `tools/diagnose_cliff.gd` and
## `tools/diagnose_ai.gd` — each filling its own [PackedByteArray]. They agreed only because
## they were all trivially plain. ★ The moment the map gained terrain, that agreement would
## have quietly stopped being true, and `simulate_matches.gd`'s own header demands it mirror
## the slice or "a looser rule here would silently simulate a different [game] than the one
## that ships." This class is that mirror, made structural instead of remembered.
##
## [b]Cover, and why it took until S7-11 to exist.[/b] Cover has been fully implemented since
## the Foundation sprints — [member CombatConfig.cover_dr], [method GridState.is_cover],
## cover-prop rendering in [BoardRenderer], and `tile_cover_clean.png` art generated in Sprint
## 4. [b]No map ever placed a single cover tile.[/b] Every measurement the project has taken —
## the S6-06 resolution gate, the S5-04 swing-back playtest, the S7-09 skill-floor sweep — ran
## on a board where every tile was identical, so the only variables in an exchange were unit
## count and position. S7-10 measured the consequence: unit count dominated by construction,
## and one extra Trooper was a ~60% force advantage no combat tuning could offset.
##
## Cover is the game's built-in answer to that: a defender who is numerically losing can win an
## exchange by standing somewhere better.
##
## [b]Layout rules, all three load-bearing:[/b]
## [br]1. [b]Mirror-symmetric[/b] about the vertical axis (`x → width - 1 - x`). The batch
##    already alternates the starting player because on a symmetric board that is the only
##    asymmetry there is; an asymmetric layout would hand one seat an edge and every
##    "not seat-determined" reading downstream would be measuring the map.
## [br]2. [b]Nothing within 2 tiles of an HQ.[/b] `deploy_radius` is 2, so cover inside that
##    ring would interact with unit deployment — and the deploy rule has already produced one
##    game-ending defect (the S6-15 spawn-ring latch). Terrain has no business near it.
## [br]3. [b]Authored as a tile list, not a formula.[/b] A designer must be able to read and
##    move these. An earlier procedural version was unreadable and, worse, unreviewable.
##
## Usage:
## [codeblock]
## var map: MapDefinition = VSMap.build()
## [/codeblock]
class_name VSMap
extends RefCounted

## ★ 2026-09-28: the board is DATA now — authored in `game-data/Maps/Vertical Slice.md` (a
## text grid) and generated into this resource by `tools/vault/build_data.py`. Everything
## below is derived from it, so an edited map reaches the slice, the simulator and every
## test through this one class, exactly as the layout rules above require.
const DATA_PATH: String = "res://data/maps/vertical_slice.tres"

## ⚠ LOADED ON FIRST USE, never at class-load time. A `preload` read by a static
## initializer ran before the resource's own script was attached whenever VSMap happened to
## load early — `DATA.width` then failed on a bare `Resource`. The full suite passed only
## because of the order its files loaded in. Properties with getters keep every caller's
## `VSMap.WIDTH` syntax unchanged while deferring the load to the first read.
static var _data: MapDefinition = null


## ★ 2026-09-28 (bigger maps): VSMap is now "the CURRENT map" — whichever one the skirmish setup
## screen selected (default: the vertical-slice board). Every reader (the slice, MatchSetup, the
## simulator, the tools) goes through here, so selecting a map changes all of them at once.
static func select(map: MapDefinition) -> void:
	_data = map


## The current map (see the vault note named in its header).
static func data() -> MapDefinition:
	if _data == null:
		_data = load(DATA_PATH) as MapDefinition
	return _data


static var WIDTH: int:
	get: return data().width
static var HEIGHT: int:
	get: return data().height
static var HQ_A: Vector2i:
	get: return data().hq_tiles[0]
static var HQ_B: Vector2i:
	get: return data().hq_tiles[1]

## The tile each seat's free starting Builder occupies — directly BEHIND its HQ,
## i.e. one step further from the enemy (S8-29, user decision 2026-08-26).
##
## ★ [b]Why a starting Builder at all:[/b] since S8-13 the HQ makes only Builders and
## every fighting unit comes from a Barracks, so the opening is a fixed
## Builder → walk → Barracks sequence before anything can happen. Seeding the Builder
## removes the most scripted turn in the game — the one where the only legal play is
## the same play every time.
##
## ⚠ [b]BEHIND, not in front.[/b] The Builder is defenceless (`attack_range` 0), so
## placing it toward the enemy would hand the opponent a free kill on turn one. Behind
## also leaves the HQ's forward deploy ring clear for the units that come later.
##
## ★ Single-sourced here on purpose: [VerticalSliceRoot] and `tools/simulate_matches.gd`
## both seed this, and the simulator exists to mirror the slice. A hand-copied tile rule
## in two files is exactly the drift that produced the S7-15 placement-bias confound.
static func starting_builder_tile(hq_tile: Vector2i, enemy_hq: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	# ★ Bigger maps: "behind" = one step AWAY from the enemy HQ along whichever axis separates
	# them most, so it holds for top-vs-bottom maps too, not only left-vs-right.
	if enemy_hq == Vector2i(-1, -1):
		enemy_hq = HQ_B if hq_tile == HQ_A else HQ_A
	var d: Vector2i = hq_tile - enemy_hq
	if absi(d.x) >= absi(d.y):
		return hq_tile + Vector2i(signi(d.x), 0)
	return hq_tile + Vector2i(0, signi(d.y))


## Minimum Manhattan distance any cover tile must keep from either HQ. Equal to
## `BaseProductionConfig.deploy_radius` (2) + 1 — see layout rule 2.
const MIN_HQ_CLEARANCE: int = 3

## The cover tiles, in row-major order, read off [constant DATA].
##
## ★ Why the centre lane (`y = 5`) is left open is recorded in the map's vault note — it is a
## measured decision (cover in the lane both sides must cross turned close games into
## round-cap draws), and it belongs next to the grid a designer edits.
static var COVER_TILES: Array[Vector2i]:
	get: return _cover_tiles()


static func _cover_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: MapDefinition = data()
	for i: int in d.authored_terrain.size():
		if d.authored_terrain[i] == GridState.Terrain.COVER:
			out.append(Vector2i(i % d.width, i / d.width))
	return out


## The shipping vertical-slice map: 12×10, two HQs, [constant COVER_TILES] as Cover, the rest
## Plain.
##
## [param plain] forces a terrain-free board — the pre-S7-11 map. Kept ONLY so a measurement
## can A/B against every batch recorded before cover existed; nothing that ships passes true.
static func build(plain: bool = false) -> MapDefinition:
	var map := MapDefinition.new()
	map.display_name = data().display_name
	map.width = WIDTH
	map.height = HEIGHT
	map.mode = MapDefinition.Mode.AUTHORED
	map.authored_terrain = terrain(plain)
	map.hq_tiles = [HQ_A, HQ_B]
	map.deploy_tiles = []
	return map


## The authored terrain bytes, row-major (`y * WIDTH + x`).
##
## ⚠ Returns a fresh array rather than mutating one passed in. A [PackedByteArray] is a value
## type in GDScript, so a `fill_cover(terrain)` helper writes to a local copy and the caller
## keeps its original — which is exactly how the first cover experiment (S7-10) silently
## no-opped and returned a sweep byte-identical to the no-cover baseline.
static func terrain(plain: bool = false) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(WIDTH * HEIGHT)
	out.fill(GridState.Terrain.PLAIN)
	if plain:
		return out
	return data().authored_terrain.duplicate()


## True iff [param tile] is a Cover tile in the authored layout. A read-only convenience for
## tests and tools; runtime code asks [method GridState.is_cover], which is the live state.
static func is_cover_tile(tile: Vector2i) -> bool:
	return COVER_TILES.has(tile)
