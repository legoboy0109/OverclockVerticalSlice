# ADR-0013 headless re-confirmation: exact round-trip identity of grid_to_screen()/
# screen_to_grid() over the full pinned 14x16 board. THROWAWAY. Not a GdUnit4 suite —
# a plain SceneTree script, consistent with prototypes/qq05-reachable-bench and
# prototypes/spikes/qq06_ai_loop_bench.gd.
#
# This does NOT re-derive the math (already godot-specialist-verified via python,
# max err ~7e-15) — it re-confirms the same identity holds when run through the
# live GDScript BoardTransform class this spike's scene actually uses, so the
# interactive scene and this self-check are provably using the same formula.
#
# Usage:
#   ./redot --headless --script prototypes/adr0013-iso-spike/headless_roundtrip_check.gd

extends SceneTree

const GRID_WIDTH := 14
const GRID_HEIGHT := 16

func _initialize() -> void:
	var transform := BoardTransform.new()
	var failures: Array[String] = []
	var checked := 0

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile := Vector2i(x, y)
			var screen_pos := transform.grid_to_screen(tile)
			var round_tripped := transform.screen_to_grid(screen_pos)
			checked += 1
			if round_tripped != tile:
				failures.append(
					"tile %s -> screen %s -> %s (MISMATCH)" % [tile, screen_pos, round_tripped]
				)

	print("---------------------------------------------------------")
	print("ADR-0013 round-trip self-check: grid_to_screen -> screen_to_grid")
	print("Board: %dx%d (%d tiles checked)" % [GRID_WIDTH, GRID_HEIGHT, checked])
	print("TILE_WIDTH_PX=%s TILE_HEIGHT_PX=%s origin_offset_px=%s" % [
		BoardTransform.TILE_WIDTH_PX, BoardTransform.TILE_HEIGHT_PX, transform.origin_offset_px
	])

	if failures.is_empty():
		print("RESULT: PASS — all %d tiles round-tripped exactly." % checked)
	else:
		print("RESULT: FAIL — %d/%d tiles mismatched:" % [failures.size(), checked])
		for line in failures:
			print("  " + line)
	print("---------------------------------------------------------")

	quit(0 if failures.is_empty() else 1)
