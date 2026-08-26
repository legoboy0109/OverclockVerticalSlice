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

const WIDTH: int = 12
const HEIGHT: int = 10
const HQ_A: Vector2i = Vector2i(2, 5)
const HQ_B: Vector2i = Vector2i(9, 5)

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
static func starting_builder_tile(hq_tile: Vector2i) -> Vector2i:
	var behind: int = -1 if hq_tile.x >= WIDTH / 2 else 1
	return Vector2i(hq_tile.x - behind, hq_tile.y)


## Minimum Manhattan distance any cover tile must keep from either HQ. Equal to
## `BaseProductionConfig.deploy_radius` (2) + 1 — see layout rule 2.
const MIN_HQ_CLEARANCE: int = 3

## The authored cover tiles, 8 of 120 (~7%).
##
## [codeblock]
##  y\x  0  1  2  3  4  5  6  7  8  9 10 11
##   0   .  .  .  .  .  .  .  .  .  .  .  .
##   1   .  .  .  .  .  .  .  .  .  .  .  .
##   2   .  .  .  .  .  .  .  .  .  .  .  .
##   3   .  .  .  C  .  C  C  .  C  .  .  .
##   4   .  .  .  .  .  .  .  .  .  .  .  .
##   5   .  .  A  .  .  .  .  .  .  B  .  .
##   6   .  .  .  .  .  .  .  .  .  .  .  .
##   7   .  .  .  C  .  C  C  .  C  .  .  .
##   8   .  .  .  .  .  .  .  .  .  .  .  .
##   9   .  .  .  .  .  .  .  .  .  .  .  .
## [/codeblock]
## [b]A[/b] / [b]B[/b] are the HQs. Two flank clusters, one above and one below the HQ rank,
## so a player who goes wide gets something to fight over — and the direct HQ-to-HQ lane at
## `y = 5` is deliberately left OPEN.
##
## ★★ [b]That empty lane is a measured decision, not a gap.[/b] The first layout ran 14 tiles
## and included the centre pair (5,5)/(6,5) plus outer tiles at y1/y9. It broke the S6-06
## gate in a very specific way:
## [codeblock]
##                        resolve on play      +1 handicap cell
##   no cover (S7-10)        19/22             1/6 reached the round cap
##   14 tiles, centre lane   15/22             5/6 reached the round cap
##   8 tiles, lane open      see below
## [/codeblock]
## Handicaps +2 and +3 were untouched at 25–30 turns either way; the damage was entirely in
## the **+1 cell — the nearly-even games**. Cover let a slightly-behind player hold, which is
## the intent, and then kept holding: the game stopped being a comeback and became a
## stalemate. ★ **Defensive terrain in the lane both sides must cross converts close games
## into draws.** Cover belongs where a player CHOOSES to fight, not where they are forced to.
const COVER_TILES: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(8, 3),
	Vector2i(3, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(8, 7),
]


## The shipping vertical-slice map: 12×10, two HQs, [constant COVER_TILES] as Cover, the rest
## Plain.
##
## [param plain] forces a terrain-free board — the pre-S7-11 map. Kept ONLY so a measurement
## can A/B against every batch recorded before cover existed; nothing that ships passes true.
static func build(plain: bool = false) -> MapDefinition:
	var map := MapDefinition.new()
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
	for tile: Vector2i in COVER_TILES:
		out[tile.y * WIDTH + tile.x] = GridState.Terrain.COVER
	return out


## True iff [param tile] is a Cover tile in the authored layout. A read-only convenience for
## tests and tools; runtime code asks [method GridState.is_cover], which is the live state.
static func is_cover_tile(tile: Vector2i) -> bool:
	return COVER_TILES.has(tile)
