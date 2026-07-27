# GdUnit4 headless test runner — invoked by /smoke-check and local runs.
# Usage: ./redot --headless --script tests/gdunit4_runner.gd
#
# Defaults to running every suite under tests/unit/ and tests/integration/.
# Pass explicit `-a res://some/path` args to override the default scan set.
#
# This wraps GdUnit4's shipped CI runner (addons/gdUnit4/bin/GdUnitCmdTool.gd)
# so the project keeps a single stable entry point. Two things this wrapper adds:
#   1. Sensible default test paths, so the bare command above "just works".
#   2. --ignoreHeadlessMode — GdUnit4 blocks headless runs by default (UI
#      InputEvents don't propagate headless); our suites are pure-logic, so this
#      is safe. UI/feel tests belong in manual evidence, not this suite.
#
# The GdUnit4 addon is vendored at res://addons/gdUnit4/ (v6.1.3). CI uses the
# gdUnit4-action instead, which fetches its own copy — see tests/README.md.
extends SceneTree

const _DEFAULT_TEST_PATHS := ["res://tests/unit", "res://tests/integration"]
const _CI_RUNNER := "res://addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd"

var _cli_runner: Object


func _initialize() -> void:
	_cli_runner = load(_CI_RUNNER).new()
	# Feed GdUnit4 a clean, engine-flag-free arg list (its parser rejects unknown
	# args like --headless/--script). get_cmdline_args() returns _debug_cmd_args
	# when non-empty, so this fully overrides what the runner sees.
	_cli_runner._debug_cmd_args = _build_runner_args()
	root.add_child(_cli_runner)


func _build_runner_args() -> PackedStringArray:
	# GdUnit4's parser discards tokens until one contains the tool name, then parses
	# the rest — so lead with a sentinel program-name token or every arg is dropped.
	var args := PackedStringArray(["GdUnitCmdTool.gd", "--ignoreHeadlessMode"])
	var user_paths := _explicit_test_paths(OS.get_cmdline_args())
	var paths := user_paths if not user_paths.is_empty() else PackedStringArray(_DEFAULT_TEST_PATHS)
	for path in paths:
		args.append("-a")
		args.append(path)
	return args


# Extracts `-a <path>` pairs the caller passed on the real command line, if any.
func _explicit_test_paths(cmdline: PackedStringArray) -> PackedStringArray:
	var paths := PackedStringArray()
	for i in range(cmdline.size() - 1):
		if cmdline[i] == "-a":
			paths.append(cmdline[i + 1])
	return paths


func _finalize() -> void:
	if is_instance_valid(_cli_runner):
		_cli_runner.queue_free()
