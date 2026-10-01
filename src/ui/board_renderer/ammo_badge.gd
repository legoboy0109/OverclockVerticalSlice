## AmmoBadge — the board mark on a vehicle/aircraft that is out of ammo (user request 2026-10-01).
##
## A hollow white bullet with a slash through it, on the same dark plate as [RankBadge]. ★ White,
## not red: orange/cyan already mean "which player" and gold means rank, so the one free channel
## that reads on both hues (and in greyscale) is white. Drawn procedurally and cached once — no
## art dependency. Sits on the unit's LEFT; rank chevrons sit on its right, so both can show.
class_name AmmoBadge
extends RefCounted

const W: int = 26
const H: int = 30
const PLATE: Color = Color(0.05, 0.06, 0.09, 0.88)
const INK: Color = Color(0.96, 0.96, 0.98)
const OUTLINE: Color = Color(0.0, 0.0, 0.0)

static var _tex: ImageTexture = null


static func texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(PLATE)
	for c: Vector2i in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
		img.set_pixelv(c, Color(0, 0, 0, 0))
	# Bullet outline: a round-nosed cartridge 10 px wide, centred.
	var cx: int = W / 2
	var left: int = cx - 5
	var right: int = cx + 4
	var top: int = 5
	var bottom: int = H - 6
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			var nose: bool = y < top + 5
			var inside: bool = true
			if nose:
				# Rounded tip: a half-ellipse over the top 5 rows.
				var dx: float = (x - (left + right) / 2.0) / 5.0
				var dy: float = (top + 5 - y) / 5.0
				inside = dx * dx + dy * dy <= 1.0
			if not inside:
				continue
			var edge: bool = x == left or x == right or y == bottom or y == top + 7
			if nose:
				var dx2: float = (x - (left + right) / 2.0) / 3.6
				var dy2: float = (top + 5 - y) / 3.6
				edge = dx2 * dx2 + dy2 * dy2 > 1.0
			if edge:
				img.set_pixel(x, y, INK)
	# The slash: bottom-left to top-right, 2 px of ink on a 4 px outline so it reads over the bullet.
	for i: int in range(0, H - 6):
		var x: int = 3 + int(round(float(i) * (W - 7) / float(H - 7)))
		var y: int = H - 4 - i
		for d: int in range(-1, 3):
			if x + d >= 0 and x + d < W:
				img.set_pixel(x + d, y, OUTLINE)
		for d: int in range(0, 2):
			if x + d < W:
				img.set_pixel(x + d, y, INK)
	_tex = ImageTexture.create_from_image(img)
	return _tex
