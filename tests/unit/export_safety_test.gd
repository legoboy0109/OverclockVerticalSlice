# Export safety — nothing in src/ or tools/ may depend on a symbol that only
# exists under tests/.
#
# ★ WHY THIS SUITE EXISTS. Twice in two days a production-called class turned out
# to be declared under `tests/`:
#
#   - `Structure` (found 2026-08-25, S6 close-out) — called by
#     `GameState.start_turn` step 2 on every turn.
#   - `Research`  (found 2026-08-25, S7-01)       — called by
#     `GameState.start_turn` step 3 on every turn, AND by `Unit.effective_attack`
#     and `Unit.effective_defense`, i.e. the core combat path.
#
# Neither ever failed a test run, and neither ever would. GDScript's `class_name`
# is project-global and the editor registers it from ANYWHERE in the project, so
# in-editor and headless runs both resolve it fine. The failure only appears in an
# export preset that excludes `tests/` — the normal thing to do — where the script
# declaring the class is simply not in the package and the referencing script
# fails to resolve a global class.
#
# ⇒ That is the worst shape a bug can have: invisible in every build a developer
#   runs, fatal in the build a player runs. A green suite is not evidence against
#   it, which is exactly why this check has to be structural rather than
#   behavioural.
#
# This suite reads source text rather than exercising behaviour. That is unusual
# and deliberate: the property under test is about FILE LAYOUT, and no amount of
# running the game can observe it.
extends GdUnitTestSuite

const _TEST_ROOT := "res://tests"
const _PRODUCTION_ROOTS: Array[String] = ["res://src", "res://tools"]

## Symbols allowed to be declared under tests/ despite appearing in production
## text. Keep this empty if at all possible — an entry here is a claim that a
## match is a false positive, not a licence to ship the dependency.
const _ALLOWED: Array[String] = []


func test_no_production_code_references_a_class_declared_under_tests() -> void:
	# Arrange — every `class_name` declared anywhere under tests/.
	var test_classes: Dictionary = _class_names_under(_TEST_ROOT)
	assert_bool(test_classes.is_empty()).override_failure_message(
		"Expected to find at least one class_name under tests/ (test helpers " +
		"declare them). Finding none means this scan is broken, not that the " +
		"project is clean — a scan that silently matches nothing always passes."
	).is_false()

	# Act — scan production text for a whole-word reference to each of them.
	var offenders: Array[String] = []
	for symbol: String in test_classes:
		if symbol in _ALLOWED:
			continue
		for path: String in _production_scripts():
			var hits: Array[int] = _reference_lines(path, symbol)
			if hits.is_empty():
				continue
			offenders.append("%s references `%s` (declared in %s) at line(s) %s" % [
				path, symbol, test_classes[symbol], str(hits)
			])

	# Assert
	assert_array(offenders).override_failure_message(
		"Production code depends on a class declared under tests/.\n\n" +
		"An export preset that excludes tests/ strips the declaring script, and " +
		"the referencing script then fails to resolve a global class — a crash in " +
		"the shipped build and in no build a developer runs.\n\n" +
		"FIX: move the declaring script into src/ (see " +
		"src/core/research/research.gd and src/core/structure/structure.gd for the " +
		"two precedents), rather than adding the symbol to _ALLOWED.\n\n" +
		"Offenders:\n  " + "\n  ".join(offenders)
	).is_empty()


func test_the_two_known_promotions_stayed_promoted() -> void:
	# A regression pin on the specific fixes, independent of the general scan
	# above — the scan proves "no offenders", this proves "these two, in src/".
	# If the general scan is ever weakened, these still fail.
	assert_bool(FileAccess.file_exists("res://src/core/structure/structure.gd")) \
		.override_failure_message("Structure must live in src/ — see its header.").is_true()
	assert_bool(FileAccess.file_exists("res://src/core/research/research.gd")) \
		.override_failure_message("Research must live in src/ — see its header.").is_true()
	assert_bool(FileAccess.file_exists("res://tests/helpers/stubs/structure_stub.gd")) \
		.override_failure_message("structure_stub.gd came back — it was promoted, not copied.").is_false()
	assert_bool(FileAccess.file_exists("res://tests/helpers/stubs/research_stub.gd")) \
		.override_failure_message("research_stub.gd came back — it was promoted, not copied.").is_false()


func test_no_resource_an_autoload_preloads_references_that_autoload() -> void:
	# ★ WHY. `UnitBalance` (Autoload) held `var units: UnitConfig = preload(
	# ".../unit_config.tres")`, and `unit_config.gd` read `UnitBalance.units...`
	# back. GDScript must resolve an Autoload's script type to typecheck a member
	# access on it, so that is a PARSE-TIME cycle, not a runtime ordering quirk.
	#
	# The editor resolves it (fully-populated global class cache, incremental
	# re-parse) and so does the headless suite. A packaged build resolves each
	# script once in dependency order, and a cycle has no valid order:
	#
	#   Parse Error: Could not resolve external class member "units".
	#     at: GDScript::reload (res://src/core/unit/unit_config.gd:40)
	#
	# ⇒ Same shape as the class-under-tests defect above: invisible in every build
	#   a developer runs, fatal in the one a player runs. Found only when this
	#   project's first-ever export was attempted, in Sprint 7.
	#
	# The rule this pins: a config Resource holds data and pure functions over data
	# it is GIVEN. The Autoload may know the Resource; the Resource must not know
	# the Autoload. Put the convenience wrapper on the Autoload — see
	# UnitBalance.surcharge_for.

	# Arrange — autoload name -> its script path, read from project.godot.
	var autoloads: Dictionary = _autoloads()
	assert_bool(autoloads.is_empty()).override_failure_message(
		"Found no autoloads in project.godot. The project has several, so this " +
		"means the parse is broken — and a scan that matches nothing always passes."
	).is_false()

	# Act
	var offenders: Array[String] = []
	for name: String in autoloads:
		for tres: String in _preloaded_resources(autoloads[name]):
			var script_path: String = _script_of_resource(tres)
			if script_path == "":
				continue
			var hits: Array[int] = _reference_lines(script_path, name)
			if hits.is_empty():
				continue
			offenders.append("%s (script of %s, preloaded by autoload %s) references `%s` at line(s) %s" % [
				script_path, tres, name, name, str(hits)
			])

	# Assert
	assert_array(offenders).override_failure_message(
		"A Resource script reaches back to the Autoload that preloads it.\n\n" +
		"This is a parse-time cycle. It resolves in the editor and in this suite, " +
		"and it makes the EXPORTED build fail to load the script outright.\n\n" +
		"FIX: move the Autoload-reading wrapper onto the Autoload and leave the " +
		"Resource holding pure functions over injected data — see " +
		"UnitBalance.surcharge_for and UnitConfig.surcharge_with_penalty.\n\n" +
		"Offenders:\n  " + "\n  ".join(offenders)
	).is_empty()


## Autoload name -> script path, parsed from project.godot's [autoload] section.
## Values carry a leading "*" (run-as-Node marker) which is stripped.
func _autoloads() -> Dictionary:
	var found: Dictionary = {}
	var in_section: bool = false
	for raw: String in _read("res://project.godot").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("["):
			in_section = line == "[autoload]"
			continue
		if not in_section or line == "" or line.begins_with(";"):
			continue
		var eq: int = line.find("=")
		if eq == -1:
			continue
		var name: String = line.substr(0, eq).strip_edges()
		var path: String = line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if path.begins_with("*"):
			path = path.substr(1)
		if name != "" and path.begins_with("res://"):
			found[name] = path
	return found


## Every `res://...` path this script preloads.
func _preloaded_resources(script_path: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in _read(script_path).split("\n"):
		var code: String = _strip_comment(line)
		var at: int = code.find("preload(")
		while at != -1:
			var open_q: int = code.find("res://", at)
			if open_q == -1:
				break
			var close_q: int = code.find("\"", open_q)
			if close_q == -1:
				break
			out.append(code.substr(open_q, close_q - open_q))
			at = code.find("preload(", close_q)
	return out


## The `script` path a `.tres` binds, or "" if it binds none.
##
## ★ Read as text rather than via `load()`: loading the resource would execute the
## very resolution this test exists to reason about, and would also make the check
## depend on the class cache being warm.
func _script_of_resource(path: String) -> String:
	if not path.ends_with(".tres"):
		return ""
	for line: String in _read(path).split("\n"):
		# ext_resource lines look like:
		#   [ext_resource type="Script" path="res://..." id="1_x"]
		if not line.begins_with("[ext_resource"):
			continue
		if line.find("type=\"Script\"") == -1:
			continue
		var key: int = line.find("path=\"")
		if key == -1:
			continue
		var start: int = key + 6
		var end: int = line.find("\"", start)
		if end != -1:
			return line.substr(start, end - start)
	return ""


## Maps every `class_name X` declared under [param root] to the file declaring it.
func _class_names_under(root: String) -> Dictionary:
	var found: Dictionary = {}
	for path: String in _scripts_under(root):
		var text: String = _read(path)
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if not trimmed.begins_with("class_name "):
				continue
			var symbol: String = trimmed.substr("class_name ".length()).strip_edges()
			# `class_name Foo extends Bar` is legal on one line.
			var space: int = symbol.find(" ")
			if space != -1:
				symbol = symbol.substr(0, space)
			if symbol != "":
				found[symbol] = path
	return found


## Lines in [param path] carrying a whole-word reference to [param symbol] in
## executable code — comments and string-literal contents do not count.
##
## ★ Comments must be ignored or this check is useless: production files discuss
## forward-declared systems constantly ("the real Research epic lands with…"), and
## a scan that flagged prose would be silenced within a day.
func _reference_lines(path: String, symbol: String) -> Array[int]:
	var hits: Array[int] = []
	var lines: PackedStringArray = _read(path).split("\n")
	for i: int in lines.size():
		var code: String = _blank_strings(_strip_comment(lines[i]))
		if code.strip_edges() == "":
			continue
		if _has_whole_word(code, symbol):
			hits.append(i + 1)
	return hits


## Drops a trailing `#` comment, [b]preserving string contents[/b]. Quotes are
## tracked while scanning so a `"#"` inside a literal is not mistaken for a
## comment start.
##
## ⚠ Deliberately does NOT blank string literals — [method _preloaded_resources]
## needs the `"res://..."` inside them. Reference scanning wants them gone and
## composes [method _blank_strings] on top. ★ These were one function for a while
## and that was a bug: blanking strings here silently made the preload scan find
## nothing, so the cycle check passed while the cycle was present — a check that
## cannot fail, which is worse than no check. Caught only by re-introducing the
## defect on purpose and watching the suite stay green.
func _strip_comment(line: String) -> String:
	var out: String = ""
	var in_single: bool = false
	var in_double: bool = false
	for i: int in line.length():
		var c: String = line[i]
		if c == "\"" and not in_single:
			in_double = not in_double
		elif c == "'" and not in_double:
			in_single = not in_single
		elif c == "#" and not in_single and not in_double:
			return out
		out += c
	return out


## Replaces the CONTENTS of every string literal with spaces, keeping the quotes
## and the line's length.
##
## ★ Required or the reference scan cries wolf: `action_log_widget.gd` maps an
## event to the display text `"Research complete"` — prose that happens to contain
## a class name. A check that cries wolf gets silenced, and the silencing mechanism
## here is `_ALLOWED`, i.e. exactly the escape hatch that would let a genuine
## offender through later.
func _blank_strings(line: String) -> String:
	var out: String = ""
	var in_single: bool = false
	var in_double: bool = false
	for i: int in line.length():
		var c: String = line[i]
		if c == "\"" and not in_single:
			in_double = not in_double
			out += c
		elif c == "'" and not in_double:
			in_single = not in_single
			out += c
		elif in_single or in_double:
			out += " "
		else:
			out += c
	return out


## Whole-word match — `Research` must not match `ResearchLab` or `my_research`.
func _has_whole_word(text: String, word: String) -> bool:
	var from: int = 0
	while true:
		var at: int = text.find(word, from)
		if at == -1:
			return false
		var before_ok: bool = at == 0 or not _is_ident_char(text[at - 1])
		var after: int = at + word.length()
		var after_ok: bool = after >= text.length() or not _is_ident_char(text[after])
		if before_ok and after_ok:
			return true
		from = at + 1
	return false


func _is_ident_char(c: String) -> bool:
	return c == "_" or (c >= "0" and c <= "9") \
		or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _production_scripts() -> Array[String]:
	var all: Array[String] = []
	for root: String in _PRODUCTION_ROOTS:
		all.append_array(_scripts_under(root))
	return all


func _scripts_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var path: String = root + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scripts_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
