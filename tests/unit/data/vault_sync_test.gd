# The game-data/ Obsidian vault is the source of truth for units, structures, techs,
# factions and maps; tools/vault/build_data.py generates data/**/*.tres from it and stamps
# each file with the SHA-256 of its note.
#
# ★ This is what stops the two drifting: a note edited without regenerating, a data file
# hand-edited, or a note with no data file all fail here with the command that fixes them.
# (The converter's own --check does the same, but it is Python and CI only runs Godot.)
extends GdUnitTestSuite

const KINDS: Dictionary = {
	"Units": "res://data/units",
	"Structures": "res://data/structures",
	"Techs": "res://data/techs",
	"Factions": "res://data/factions",
	"Maps": "res://data/maps",
}
const FIX: String = "Run: python3 tools/vault/build_data.py"


# Every generated file, as {tres_path: [note_path, recorded_sha]}.
func _generated() -> Dictionary:
	var out: Dictionary = {}
	for kind: String in KINDS:
		for file: String in DirAccess.get_files_at(KINDS[kind]):
			if not file.ends_with(".tres"):
				continue
			var path: String = "%s/%s" % [KINDS[kind], file]
			var text: String = FileAccess.get_file_as_string(path)
			var note := RegEx.create_from_string("; GENERATED from (.+?\\.md)").search(text)
			var sha := RegEx.create_from_string("; source-sha256: ([0-9a-f]{64})").search(text)
			if note != null and sha != null:
				out[path] = [note.get_string(1), sha.get_string(1)]
	return out


func test_every_generated_file_matches_its_note() -> void:
	var generated: Dictionary = _generated()
	assert_int(generated.size()).override_failure_message(
		"No generated data files found — the vault pipeline is not in use.").is_greater(0)
	for tres: String in generated:
		var note: String = "res://" + generated[tres][0]
		assert_bool(FileAccess.file_exists(note)).override_failure_message(
			"%s was generated from %s, which no longer exists. %s" % [tres, note, FIX]).is_true()
		assert_str(FileAccess.get_sha256(note)).override_failure_message(
			"%s was edited after %s was generated. %s" % [note, tres, FIX]
		).is_equal(generated[tres][1])


func test_every_note_has_a_generated_file() -> void:
	var sources: Array = []
	for pair: Array in _generated().values():
		sources.append(pair[0])
	for kind: String in KINDS:
		var dir: String = "res://game-data/" + kind
		for file: String in DirAccess.get_files_at(dir):
			if not file.ends_with(".md"):
				continue
			var rel: String = "game-data/%s/%s" % [kind, file]
			assert_bool(sources.has(rel)).override_failure_message(
				"%s has no data file yet. %s" % [rel, FIX]).is_true()


func test_every_registered_type_comes_from_the_vault() -> void:
	# A hand-written .tres in a registry would silently bypass the vault.
	var generated: Dictionary = _generated()
	var registered: Array = []
	registered.append_array(UnitTypes.ALL)
	registered.append_array(StructureTypes.ALL)
	registered.append_array(Techs.ALL)
	registered.append_array([Factions.NEUTRAL, Factions.RUSH, Factions.BOOM, VSMap.data()])
	for res: Resource in registered:
		assert_bool(generated.has(res.resource_path)).override_failure_message(
			"%s is used by the game but was not generated from the vault." % res.resource_path
		).is_true()
