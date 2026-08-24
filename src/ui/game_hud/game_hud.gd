## GameHud — the Game HUD scene-assembly root: instantiates every HUD widget and
## wires it to the live game through the documented seams, in one place.
##
## This is the integration glue the per-widget Game HUD stories (001–008)
## deliberately deferred — each widget was built + unit/integration-tested in
## isolation; this node is where they become a single reactive surface. It is a
## [CanvasLayer] (the screen-space [Control] widgets are its children — including
## the two co-equal budget counters, the AP counter and the Credits counter added
## by the 2026-08-05 economy pivot per CR-3d — rendered above the world), and it
## additionally parents the world-space
## [OnBoardGlyphLayer] onto the board (a [Node2D] that must live under the board's
## transform to anchor glyphs over tiles) and owns the silent [HudAudioDispatcher].
##
## [b]One wiring entry point[/b] — [method assemble] — takes the read-only
## [GameStateReader] (every widget's data source, ADR-0016 §1), the [HUDConfig]
## (timing/behaviour knobs), the [CommandInterface] (#9 — the detail panel and the
## Build/End-Turn controls attach to it for `selection_changed` + control routing),
## the [BoardRenderer] (the glyph layer's `grid_to_screen` anchor source), the
## local player index, and the buildable structure list for the Build control.
## Each widget is bound + configured exactly as its own doc comment prescribes.
##
## [b]Read-only, outward-in[/b]: the HUD only ever reads through the facade and
## subscribes to signals; it never mutates state and never calls back into the
## board. Interaction (the Build/End-Turn buttons) routes through the injected
## [CommandInterface], never through the HUD.
##
## [b]Deferred seam (documented)[/b]: the AP-counter preview echo
## ([method ApCounterWidget.open_preview]/[method ApCounterWidget.close_preview])
## is driven by scene glue when #9 opens/closes a preview — [CommandInterface]
## exposes no preview-open signal today, so [method assemble] cannot auto-connect
## it. [method open_ap_preview]/[method close_ap_preview] are exposed as the
## passthrough the future wiring calls (a small CAI addendum, like
## `selection_changed` was, will let this auto-connect).
##
## [b]Layout is provisional[/b]: widget positions here are a functional,
## non-overlapping starting arrangement so the surface is legible; the final
## chrome/anchoring is the advisory Visual/Feel + `/ux-design` sign-off owed on
## the HUD (see `production/qa/evidence/hud-chrome-layout-evidence.md`).
##
## Usage:
## [codeblock]
## var hud := GameHud.new()
## hud.assemble(reader, HudBalance.hud, command_interface, board_renderer, 0,
##         [StructureTypes.FACTORY])
## world_root.add_child(hud) # CanvasLayer renders its widgets over the board.
## [/codeblock]
class_name GameHud
extends CanvasLayer

## The local (human) player index this HUD is oriented for. Set by [method assemble].
var _local_player: int = 0

# The assembled widgets (accessible via the getters below).
var _ap_counter: ApCounterWidget = null
var _ap_counter_opponent: ApCounterWidget = null
var _credits_counter: CreditsCounterWidget = null
var _credits_counter_opponent: CreditsCounterWidget = null
var _turn_banner: TurnBannerWidget = null
var _income_breakdown: IncomeBreakdownWidget = null
var _population: PopulationWidget = null

## The three grouping panels (2026-08-24). They own no state and read nothing —
## they are backing plates, so they are not [HudReactiveControl]s.
var _player_panel: HudPanel = null
var _opponent_panel: HudPanel = null
var _actions_panel: HudPanel = null
var _action_log: ActionLogWidget = null
var _controls: HudControlsWidget = null
var _detail_panel: DetailPanelWidget = null
var _game_over_overlay: GameOverOverlay = null
var _glyph_layer: OnBoardGlyphLayer = null
var _audio: HudAudioDispatcher = null

## Guard so a second [method assemble] is a no-op rather than a double build.
var _assembled: bool = false


## Instantiates and wires every HUD element to the live game. Call once, before
## or after this node enters the tree (each widget's [method HudReactiveControl.bind]
## is tree-order-safe). [param board] may be [code]null[/code] for a boardless
## surface (e.g. a menu) — the on-board glyph layer is then skipped.
func assemble(reader: GameStateReader, config: HUDConfig, cmd: CommandInterface, \
		board: BoardRenderer, local_player: int, \
		buildable_types: Array[StructureTypeDef] = []) -> void:
	if _assembled:
		return
	_assembled = true
	_local_player = local_player
	var opponent: int = 1 - local_player # VS is 1v1 (ADR-0011 minimal-VS scope).

	# --- Screen-space Control widgets (children of this CanvasLayer) ---
	# Draw order = child order; the victory/defeat overlay is added LAST so it
	# preempts every other widget on a game-ending frame (Story 006).

	# ★ 2026-08-24 — the readouts are GROUPED into titled panels instead of scattered
	# across four screen corners. Before this, the top-left held a bare "30" with no
	# unit on it, Credits sat under it unlabelled, population floated further down
	# again, and the opponent's state was dimmed into the opposite corner. Nothing
	# said which numbers belonged together, and every one of them drew straight onto
	# the board, so text competed with terrain for the same pixels.
	#
	# The widgets themselves are UNCHANGED — same display models, same bindings,
	# same tests. Only composition moved: each is now a child of a HudPanel that
	# supplies a ground, a frame and a title. That keeps this a layout change rather
	# than a rewrite of nine widgets.

	# --- YOU: the three budgets that drive every decision, in one place ---------
	_player_panel = HudPanel.new()
	_player_panel.configure("YOU", Vector2(232, 118))
	_player_panel.position = Vector2(16, 12)
	add_child(_player_panel)

	_ap_counter = ApCounterWidget.new()
	_ap_counter.bind(reader)
	_ap_counter.configure(config, local_player)
	_player_panel.add_content(_ap_counter, Vector2(0, 0))

	_credits_counter = CreditsCounterWidget.new()
	_credits_counter.bind(reader)
	_credits_counter.configure(config, local_player)
	_player_panel.add_content(_credits_counter, Vector2(0, 24))

	_population = PopulationWidget.new()
	_population.bind(reader)
	_population.configure(local_player)
	_player_panel.add_content(_population, Vector2(0, 52))

	# The income breakdown stays parented to the Credits counter — it is that
	# counter's on-demand detail, and anchoring it anywhere else would let the two
	# drift apart. It expands downward inside the panel.
	_income_breakdown = IncomeBreakdownWidget.new()
	_income_breakdown.bind(reader)
	_income_breakdown.configure(config, local_player)
	_income_breakdown.position = Vector2(96, -14)
	_credits_counter.add_child(_income_breakdown)

	# --- OPPONENT: same figures, muted, so the comparison is direct ------------
	if config.show_opponent_ap:
		_opponent_panel = HudPanel.new()
		_opponent_panel.configure("OPPONENT", Vector2(184, 88))
		_opponent_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_opponent_panel.position = Vector2(-200, 12)
		add_child(_opponent_panel)

		_ap_counter_opponent = ApCounterWidget.new()
		_ap_counter_opponent.bind(reader)
		_ap_counter_opponent.configure(config, opponent, true) # muted opponent AP.
		_opponent_panel.add_content(_ap_counter_opponent, Vector2(0, 0))

		_credits_counter_opponent = CreditsCounterWidget.new()
		_credits_counter_opponent.bind(reader)
		_credits_counter_opponent.configure(config, opponent, true) # muted opponent Credits.
		_opponent_panel.add_content(_credits_counter_opponent, Vector2(0, 24))

	_turn_banner = TurnBannerWidget.new()
	_turn_banner.bind(reader)
	_turn_banner.configure(config, local_player)
	_turn_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_banner.position = Vector2(-80, 12)
	add_child(_turn_banner)

	_action_log = ActionLogWidget.new()
	_action_log.bind(reader)
	_action_log.configure(config)
	_action_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_action_log.position = Vector2(16, -160)
	add_child(_action_log)

	# --- ACTIONS: the two commit verbs, on a ground so they read as buttons -----
	_actions_panel = HudPanel.new()
	_actions_panel.configure("ACTIONS", Vector2(200, 66))
	_actions_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_actions_panel.position = Vector2(-216, -82)
	add_child(_actions_panel)

	_controls = HudControlsWidget.new()
	_controls.bind(reader)
	_controls.configure(config, local_player, buildable_types)
	_controls.attach_interface(cmd)
	_actions_panel.add_content(_controls, Vector2(0, 0))

	_detail_panel = DetailPanelWidget.new()
	_detail_panel.bind(reader)
	_detail_panel.attach_interface(cmd)
	_detail_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_detail_panel.position = Vector2(-200, -80)
	add_child(_detail_panel)

	_game_over_overlay = GameOverOverlay.new()
	_game_over_overlay.bind(reader)
	_game_over_overlay.configure(local_player)
	_game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_game_over_overlay) # added last → renders on top (one-frame preempt).

	# --- World-space on-board glyph layer (parented onto the board) ---
	if board != null:
		_glyph_layer = OnBoardGlyphLayer.new()
		_glyph_layer.bind(reader, board, config)
		board.add_child(_glyph_layer)

	# --- Silent single-owner audio dispatcher (child of this node) ---
	_audio = HudAudioDispatcher.new()
	_audio.bind(reader)
	_audio.configure(config)
	add_child(_audio)


## Opens the AP-counter preview echo (scene glue calls this when #9 opens a
## preview — see the class doc comment's deferred-seam note). Verbatim passthrough
## to [method ApCounterWidget.open_preview]; a no-op before assembly.
func open_ap_preview(projected_ap: int, affordable: bool) -> void:
	if _ap_counter != null:
		_ap_counter.open_preview(projected_ap, affordable)


## Closes the AP-counter preview echo. Passthrough to
## [method ApCounterWidget.close_preview]; a no-op before assembly.
func close_ap_preview() -> void:
	if _ap_counter != null:
		_ap_counter.close_preview()


## Guarded cleanup: the on-board glyph layer is parented to the board (not this
## node), so free it explicitly on exit to avoid leaking it when the HUD is torn
## down independently of the board (all other widgets are this CanvasLayer's own
## children and free with it).
##
## [method @GlobalScope.is_instance_valid] covers the case where the board was
## already freed on an earlier frame — Godot invalidates its freed children, so
## the guard is false and this skips. If BOTH the board and this node are freed in
## the SAME frame, the layer is still only queued (thus "valid") when this runs,
## so this calls [method Node.queue_free] on it a second time — which Godot safely
## no-ops. Using [method Node.queue_free] here (never [method Object.free]) is what
## keeps that same-frame race harmless.
func _exit_tree() -> void:
	if is_instance_valid(_glyph_layer):
		_glyph_layer.queue_free()
		_glyph_layer = null


# --- Accessors (for scene glue + the assembly test) -------------------------

## The local player's AP counter.
func ap_counter() -> ApCounterWidget:
	return _ap_counter

## The opponent's muted AP counter, or [code]null[/code] if
## [member HUDConfig.show_opponent_ap] is false.
func opponent_ap_counter() -> ApCounterWidget:
	return _ap_counter_opponent

## The local player's Credits counter (the banked war chest, CR-3d).
func credits_counter() -> CreditsCounterWidget:
	return _credits_counter

## The opponent's muted Credits counter, or [code]null[/code] if
## [member HUDConfig.show_opponent_ap] is false (it gates both budgets, CR-3b).
func opponent_credits_counter() -> CreditsCounterWidget:
	return _credits_counter_opponent

## The turn/round indicator + YOUR/ENEMY banner.
func turn_banner() -> TurnBannerWidget:
	return _turn_banner

## The AP income breakdown readout.
func income_breakdown() -> IncomeBreakdownWidget:
	return _income_breakdown


## The population readout (`population-cap.md` AC-12), or [code]null[/code] before
## [method assemble].
func population_widget() -> PopulationWidget:
	return _population

## The append-only action log.
func action_log() -> ActionLogWidget:
	return _action_log

## The Build / End-Turn controls.
func controls() -> HudControlsWidget:
	return _controls

## The selection-following detail panel.
func detail_panel() -> DetailPanelWidget:
	return _detail_panel

## The victory/defeat overlay.
func game_over_overlay() -> GameOverOverlay:
	return _game_over_overlay

## The world-space on-board glyph layer (hp pips / markers), or [code]null[/code]
## if assembled without a board.
func glyph_layer() -> OnBoardGlyphLayer:
	return _glyph_layer

## The single-owner HUD audio dispatcher.
func audio() -> HudAudioDispatcher:
	return _audio
