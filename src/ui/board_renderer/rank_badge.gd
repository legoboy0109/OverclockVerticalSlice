## RankBadge — the veteran rank mark drawn beside a promoted unit (promotion-veterancy.md PVOQ-3,
## built 2026-09-28).
##
## 1–3 gold chevrons for Veteran / Elite / Champion, stacked. ★ Gold, not a faction hue: colour
## already means "which player" (OQ-11), so rank uses a channel that cannot be confused with
## ownership, and it is bright enough to read in greyscale. Dark outline so it holds on any floor.
## Drawn procedurally and cached per rank, like [OwnershipMarker] — no art dependency.
class_name RankBadge
extends RefCounted

const CHEVRON_W: int = 26
const CHEVRON_H: int = 10
const GAP: int = 3
const PAD: int = 4
const GOLD: Color = Color(1.0, 0.82, 0.25)
const OUTLINE: Color = Color(0.08, 0.06, 0.02)
## A dark plate behind the chevrons: gold alone vanished against an orange unit's legs in the
## first mock-up, so the plate guarantees contrast whatever it overlaps.
const PLATE: Color = Color(0.05, 0.06, 0.09, 0.85)

static var _cache: Dictionary = {}


## The badge for [param rank] (1..3), or null for rank 0 — a recruit carries no mark.
static func texture_for(rank: int) -> ImageTexture:
	if rank <= 0:
		return null
	rank = mini(rank, 3)
	if _cache.has(rank):
		return _cache[rank]
	var w: int = CHEVRON_W + PAD * 2
	var h: int = rank * CHEVRON_H + (rank - 1) * GAP + PAD * 2 + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(PLATE)
	# Round the plate's corners so it reads as a badge, not a glitch.
	for c: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		img.set_pixelv(c, Color(0, 0, 0, 0))
	for i: int in rank:
		_chevron(img, PAD, PAD + i * (CHEVRON_H + GAP))
	var tex := ImageTexture.create_from_image(img)
	_cache[rank] = tex
	return tex


## One upward-pointing chevron with its top-left at ([param ox], [param oy]): outline pass, then
## the gold stroke inset by a pixel.
static func _chevron(img: Image, ox: int, oy: int) -> void:
	for pass_i: int in 2:
		var col: Color = OUTLINE if pass_i == 0 else GOLD
		var thick: int = 4 if pass_i == 0 else 2
		for x: int in CHEVRON_W:
			# A "^": y rises linearly to the centre and falls after it.
			var t: float = absf(float(x) - (CHEVRON_W - 1) / 2.0) / ((CHEVRON_W - 1) / 2.0)
			var y: int = oy + int(round(t * (CHEVRON_H - thick)))
			for dy: int in thick:
				var py: int = y + dy + (1 if pass_i == 1 else 0)
				if py >= 0 and py < img.get_height():
					img.set_pixel(ox + x, py, col)


static func clear_cache() -> void:
	_cache.clear()
