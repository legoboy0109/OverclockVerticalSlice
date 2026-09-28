## Maps — registry of every playable map, in picker order (generated from `game-data/Maps/`).
## ★ Added 2026-09-28 with the first larger maps. Loaded lazily via [method all] — reading a
## resource's fields at class-load time can run before its script is attached (see VSMap).
class_name Maps
extends RefCounted

const PATHS: Array[String] = [
	"res://data/maps/vertical_slice.tres",
	"res://data/maps/crossroads.tres",
	"res://data/maps/highlands.tres",
]


static func all() -> Array[MapDefinition]:
	var out: Array[MapDefinition] = []
	for p: String in PATHS:
		var m: MapDefinition = load(p)
		if m != null:
			out.append(m)
	return out
