## SaveGame — saving and resuming a skirmish in progress (user decision 2026-09-29: autosave at the
## start of each of the player's turns + three manual slots; "Save & Quit to Menu" in the pause menu).
##
## [b]Format: explicit JSON, not Godot resource files.[/b] A [code].tres[/code] save would be one
## call to write, but loading one can instantiate any script it names — a shared or tampered save
## becomes a way to run code. Here the only things ever rebuilt are the five state classes in
## [constant _CLASSES], and every reference to shared game data (unit / structure / tech / faction
## types) is stored as its [code]res://data/[/code] path and re-resolved through the normal loader,
## so it comes back as the very same object the rest of the game holds — identity checks such as
## [method StructureState.is_hq] keep working.
##
## [b]Fields are discovered, not listed.[/b] Every [code]@export[/code] property of a state class
## is written, so a field added later is saved without touching this file; a field missing from an
## older save keeps its default. Only [code]@export[/code] fields are state — the static dispatch
## tables on [GameState] rebuild themselves on first use.
##
## Usage:
## [codeblock]
## SaveGame.write(SaveGame.AUTOSAVE, state)          # during the player's turn
## var loaded: SaveGame.Loaded = SaveGame.read(SaveGame.AUTOSAVE)
## if loaded != null:
##     SaveGame.pending = loaded                     # the slice picks it up instead of a new match
##     get_tree().change_scene_to_file("res://scenes/vertical_slice.tscn")
## [/codeblock]
class_name SaveGame
extends RefCounted

const VERSION: int = 1
const _DIR: String = "user://saves"
## ★ The test runner sets OVERCLOCK_TESTS=1 (as for MatchSettings): tests that start a real match
## would otherwise autosave over the player's own saves.
const _TEST_DIR: String = "user://test_saves"
const AUTOSAVE: String = "autosave"
## Manual slots, in the order the Save/Load screens show them.
const MANUAL_SLOTS: Array[String] = ["slot1", "slot2", "slot3"]

## Only these classes are ever instantiated from a save file.
const _CLASSES: Dictionary = {
	"GameState": preload("res://src/core/game_state/game_state.gd"),
	"GridState": preload("res://src/core/grid/grid_state.gd"),
	"PlayerState": preload("res://src/core/game_state/player_state.gd"),
	"UnitState": preload("res://src/core/unit/unit_state.gd"),
	"StructureState": preload("res://src/core/structure/structure_state.gd"),
}
## Shared game data may only be referenced from here.
const _DATA_ROOT: String = "res://data/"

## A save that is ready to resume: the state plus the per-match settings that live outside it.
class Loaded extends RefCounted:
	var state: GameState
	var ap_per_turn: int
	var map: MapDefinition


## Summary of a slot for the Save/Load screens, without loading the whole match.
class SlotInfo extends RefCounted:
	var slot: String
	var exists: bool = false
	var label: String = ""
	var saved_at: int = 0


## Set by the menu before switching to the match scene; the slice consumes and clears it.
static var pending: Loaded = null

## Set while decoding when anything is refused or missing, so a save with even one bad reference
## is rejected whole rather than loaded with a hole in it.
static var _failed: bool = false


# --- Files ------------------------------------------------------------------------------------

## The folder saves live in (a separate one under tests).
static func dir() -> String:
	return _TEST_DIR if OS.get_environment("OVERCLOCK_TESTS") == "1" else _DIR


static func path_for(slot: String) -> String:
	return "%s/%s.json" % [dir(), slot]


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


## Saves [param state] (with the match's AP per turn and map, which live outside it) to [param slot].
## Written to a temporary file and renamed into place, so a crash mid-write never leaves a
## half-written save behind. Returns OK or the failing [enum Error].
static func write(slot: String, state: GameState) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(dir())
	if err != OK:
		push_error("SaveGame: cannot create %s (%s)" % [dir(), error_string(err)])
		return err
	var text: String = JSON.stringify(to_dict(state, Balance.economy.flat_ap_per_turn, VSMap.data()))
	var tmp: String = path_for(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	err = DirAccess.rename_absolute(tmp, path_for(slot))
	if err != OK:
		push_error("SaveGame: cannot move %s into place (%s)" % [tmp, error_string(err)])
	return err


## The save in [param slot], or null if it is missing, unreadable, from a newer version, or refers
## to something that no longer exists (each logged).
static func read(slot: String) -> Loaded:
	if not exists(slot):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if not (parsed is Dictionary):
		push_error("SaveGame: %s is not a valid save" % path_for(slot))
		return null
	return from_dict(parsed)


static func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path_for(slot))


## Label and time for [param slot] — reads only the save's small header.
static func info(slot: String) -> SlotInfo:
	var i := SlotInfo.new()
	i.slot = slot
	if not exists(slot):
		return i
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if parsed is Dictionary and (parsed as Dictionary).get("meta") is Dictionary:
		var meta: Dictionary = parsed["meta"]
		i.exists = true
		i.label = str(meta.get("label", ""))
		i.saved_at = int(meta.get("saved_at", 0))
	return i


# --- State <-> Dictionary -------------------------------------------------------------------

## The whole save as plain data: header, per-match settings and the encoded [param state].
static func to_dict(state: GameState, ap_per_turn: int, map: MapDefinition) -> Dictionary:
	return {
		"version": VERSION,
		"meta": {"label": describe(state, map), "saved_at": int(Time.get_unix_time_from_system())},
		"ap_per_turn": ap_per_turn,
		"map": map.resource_path if map != null else "",
		"state": _encode_object(state),
	}


## Rebuilds a save from [method to_dict]'s output; null (logged) if it cannot be trusted.
static func from_dict(d: Dictionary) -> Loaded:
	if int(d.get("version", 0)) > VERSION:
		push_error("SaveGame: save is from a newer version (%s)" % d.get("version"))
		return null
	_failed = false
	var state: Variant = _decode_object(d.get("state"), "GameState")
	if _failed or not (state is GameState):
		push_error("SaveGame: the saved match could not be rebuilt")
		return null
	var out := Loaded.new()
	out.state = state
	out.ap_per_turn = int(d.get("ap_per_turn", 20))
	out.map = _resolve(str(d.get("map", "")), "MapDefinition") as MapDefinition
	if out.map == null:
		push_error("SaveGame: the saved map no longer exists")
		return null
	return out


## "Highlands — Democratic Alliance vs Holy Cosmic Empire — round 12".
static func describe(state: GameState, map: MapDefinition) -> String:
	var names := PackedStringArray()
	for p: PlayerState in state.per_player:
		names.append(p.faction.display_name if p.faction != null else "?")
	return "%s — %s — round %d" % [map.display_name if map != null else "?", " vs ".join(names), state.round_number]


static func _encode_object(obj: Object) -> Dictionary:
	var cls: String = _class_of(obj)
	var out: Dictionary = {"$class": cls}
	for p: Dictionary in obj.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE) or not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key: String = p["name"]
		if cls == "GameState" and key == "entities_by_id":
			var list: Array = []
			for id: int in (obj.get(key) as Dictionary):
				list.append(_encode_object(obj.get(key)[id]))
			out[key] = list
			continue
		out[key] = _encode_value(obj.get(key))
	return out


static func _encode_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY:
			return Array(v)
		TYPE_ARRAY:
			var arr: Array = []
			for e: Variant in v:
				arr.append(_encode_value(e))
			return arr
		TYPE_DICTIONARY:
			# Only the per-unit ability tallies are plain dictionaries: StringName -> int.
			var pairs: Array = []
			for k: Variant in v:
				pairs.append([String(k), _encode_value(v[k])])
			return {"$pairs": pairs}
		TYPE_OBJECT:
			if v == null:
				return null
			if v is Resource and (v as Resource).resource_path.begins_with("res://"):
				return {"$ref": (v as Resource).resource_path}
			return _encode_object(v)
	push_error("SaveGame: cannot save a value of type %s" % type_string(typeof(v)))
	return null


static func _decode_object(d: Variant, expected: String) -> Object:
	if not (d is Dictionary) or not _CLASSES.has(str((d as Dictionary).get("$class", ""))):
		_failed = true
		return null
	var cls: String = d["$class"]
	if expected != "" and cls != expected and not (expected == "EntityState" and cls in ["UnitState", "StructureState"]):
		return null
	var obj: Object = (_CLASSES[cls] as Script).new()
	for p: Dictionary in obj.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE) or not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key: String = p["name"]
		if not (d as Dictionary).has(key):
			continue   # an older save: the field keeps its default
		if cls == "GameState" and key == "entities_by_id":
			var byid: Dictionary = {}
			for e: Variant in d[key]:
				var ent: Object = _decode_object(e, "EntityState")
				if ent == null:
					return null
				byid[(ent as EntityState).entity_id] = ent
			obj.set(key, byid)
			continue
		var value: Variant = _decode_value(d[key], p)
		if typeof(value) == TYPE_ARRAY and typeof(obj.get(key)) == TYPE_ARRAY:
			# Typed arrays must be refilled in place — assigning an untyped Array is refused.
			var target: Array = obj.get(key)
			target.clear()
			for e: Variant in value:
				target.append(e)
			continue
		obj.set(key, value)
	return obj


static func _decode_value(v: Variant, prop: Dictionary) -> Variant:
	var t: int = int(prop["type"])
	match t:
		TYPE_BOOL:
			return bool(v)
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_STRING:
			return str(v)
		TYPE_STRING_NAME:
			return StringName(str(v))
		TYPE_VECTOR2I:
			return Vector2i(int(v[0]), int(v[1])) if v is Array and (v as Array).size() == 2 else Vector2i.ZERO
		TYPE_PACKED_BYTE_ARRAY:
			return PackedByteArray(v)
		TYPE_PACKED_INT32_ARRAY:
			return PackedInt32Array(v)
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			if v is Dictionary and (v as Dictionary).get("$pairs") is Array:
				for pair: Variant in v["$pairs"]:
					out[StringName(str(pair[0]))] = pair[1] if typeof(pair[1]) != TYPE_FLOAT else int(pair[1])
			return out
		TYPE_ARRAY:
			# Typed arrays of objects (per_player, cargo, completed_techs): hint_string is the class.
			# Godot writes the element type as "Class" or "type/hint:Class" — the class is after the last ':'.
			var elem_class: String = str(prop.get("hint_string", "")).get_slice(":", str(prop.get("hint_string", "")).count(":"))
			var arr: Array = []
			for e: Variant in (v if v is Array else []):
				arr.append(_decode_element(e, elem_class))
			return arr
		TYPE_OBJECT:
			return _decode_element(v, str(prop.get("class_name", "")))
	return v


static func _decode_element(v: Variant, cls: String) -> Variant:
	if v == null:
		return null
	if v is Dictionary and (v as Dictionary).has("$ref"):
		return _resolve(str(v["$ref"]), cls)
	if v is Dictionary and (v as Dictionary).has("$class"):
		return _decode_object(v, cls)
	return v


## Loads shared game data by path — only from res://data/ and only if it is the expected type.
static func _resolve(path: String, cls: String) -> Resource:
	if not path.begins_with(_DATA_ROOT) or not path.ends_with(".tres") or ".." in path:
		push_error("SaveGame: refusing to load %s" % path)
		_failed = true
		return null
	if not ResourceLoader.exists(path):
		push_error("SaveGame: %s no longer exists" % path)
		_failed = true
		return null
	var res: Resource = load(path)
	if cls != "" and res != null and not _is_class(res, cls):
		push_error("SaveGame: %s is not a %s" % [path, cls])
		_failed = true
		return null
	return res


static func _class_of(obj: Object) -> String:
	var script: Script = obj.get_script()
	return script.get_global_name() if script != null else obj.get_class()


static func _is_class(obj: Object, cls: String) -> bool:
	var script: Script = obj.get_script()
	while script != null:
		if script.get_global_name() == cls:
			return true
		script = script.get_base_script()
	return obj.is_class(cls)
