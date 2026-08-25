## ActionMenu — the contextual action menu that opens on a selected entity
## (`design/ux/action-menu.md`; `command-action-interface.md` CR-1/CR-4).
##
## [b]The surface CR-1's interaction loop always named and never had.[/b] The loop
## is [i]select -> menu -> verb -> preview -> commit[/i], and every piece of it
## except this one has existed since Story 001: [method CommandFSM.menu_model]
## decides which verbs are legal, which are disabled, and why; [CommandInterface]
## owns the previews and the commit. What was missing was somewhere to DRAW that
## model, so the vertical slice stood in one keyboard key per command. That
## stand-in cannot express CR-4's central rule — "a verb the entity has but cannot
## use right now is shown [b]disabled with its reason[/b], not hidden" — because a
## key that does nothing is indistinguishable from a key that does not exist. This
## widget exists to make an unavailable verb VISIBLE.
##
## [b]Renders a model it does not compute.[/b] Every verb, every enabled flag and
## every reason comes from [method CommandFSM.menu_model]; every produce row comes
## from [method CommandFSM.produce_options]. This class contains no legality rule,
## no cost arithmetic and no balance constant — it is the Pass-Through Invariant
## (TR-cmdui-010) applied to the presentation layer. It also never dispatches an
## [Action]: it reports which row the player picked and the scene glue routes that
## into [CommandInterface].
##
## [b]Deliberately a plain [Control], not a [CanvasLayer] and not a [Popup].[/b]
## A [Popup] would be modal-ish, would steal the whole window's input, and would
## sit outside the HUD's [member GameSettings.ui_scale] factor. The menu must stay
## non-modal (the board keeps rendering and the HUD keeps updating underneath it)
## and must scale with everything else, so it is an ordinary Control the caller
## parents into whatever screen-space layer it already owns.
##
## [b]ASCII-only labels.[/b] The engine fallback font has no glyph for a padlock,
## a bullet or a right-pointing triangle, and they render as "tofu" boxes — the
## same trap `vertical_slice_root.gd`'s status overlay documents. The submenu
## affordance is [code]>[/code] and the disabled marker is a dash, both of which
## exist in every font this game will ever load.
##
## Usage:
## [codeblock]
## var menu := ActionMenu.new()
## menu.configure(false) # reduced_motion
## hud_layer.add_child(menu)
## menu.verb_chosen.connect(_on_verb)
## menu.open(state, entity, anchor_screen_px, tile_width_screen_px)
## [/codeblock]
class_name ActionMenu
extends Control

## Emitted when the player activates an ENABLED verb row that is not Wait and not
## Produce. Carries a [enum CommandFSM.Verb] value. Produce is excluded because it
## opens the submenu instead of choosing anything (see [signal produce_type_chosen]),
## and Wait is excluded because it has its own signal.
signal verb_chosen(verb: int)

## Emitted when the player activates an enabled row of the Produce submenu. This —
## not [signal verb_chosen] — is the Produce commitment, because a produce order is
## meaningless without the type it deploys.
signal produce_type_chosen(unit_type: UnitTypeDef)

## Emitted when the player activates an enabled row of the player-level Build
## picker ([method open_build_options]). Separate from
## [signal produce_type_chosen] because Build belongs to the player and Produce to
## a producer (CR-5) — the caller routes them into different flows.
signal build_type_chosen(structure_type: StructureTypeDef)

## Emitted when the player backs out of the TOP-LEVEL menu (submenu back-out is
## handled internally and never reaches the caller). The caller deselects.
signal dismissed()

## Emitted when the player activates Wait. Distinct from [signal dismissed] even
## though the slice currently treats them identically: Wait is a deliberate "this
## entity is finished", dismissal is "I did not mean to open this", and the GDD
## intends them to diverge once the simulation can record a stood-down entity
## (`design/ux/action-menu.md` OQ-1). Collapsing them today would erase the
## distinction that OQ-1 needs in order to be resolvable.
signal waited()

## Panel ground and frame, taken from [HudPanel] rather than re-picked, so the menu
## reads as part of the same HUD instead of as a second visual language.
const BACKING: Color = HudPanel.BACKING
## See [constant BACKING].
const BORDER: Color = HudPanel.BORDER

## Enabled verb label.
const LABEL_ENABLED: Color = Color(0.90, 0.94, 1.0)
## The label of the row the keyboard/gamepad is ON. Brighter than a resting row,
## because focus must read as MORE present than its neighbours, and paired with the
## theme's own focus outline so the cue is never carried by brightness alone —
## which also keeps it distinguishable from mouse-hover (the Godot 4.6 dual-focus
## case the GDD's input notes call out).
const LABEL_FOCUS: Color = Color(1.0, 1.0, 1.0)

## Disabled verb label — greyscale, never a hue. Hue means ownership on this
## screen (art-bible), so tinting a dead row red would collide with that, and
## *Affordability Dimming* forbids a hue-based unavailability signal outright.
##
## ★ Raised from [code]Color(0.46, 0.50, 0.56)[/code] on 2026-08-24. The plate is
## 88% opaque, so whatever is behind it bleeds through: over the board's dark
## ground the old value measured 4.65:1, but over the tan over-cap move overlay —
## the brightest thing that can sit under a menu — it fell to 4.27:1, under the
## 4.5:1 WCAG AA floor for body text at this size. Sized against that worst case
## with headroom, not against the comfortable one. See the spec's contrast table.
const LABEL_DISABLED: Color = Color(0.50, 0.54, 0.60)
## The shortcut hint. Dim on purpose: it is there to be learned, not read.
const HINT: Color = Color(0.52, 0.60, 0.70)
## Disablement reason text. Dimmer than an enabled label and warmer than the hint,
## so "why not" never competes with "what".
const REASON: Color = Color(0.62, 0.56, 0.50)

const FONT_SIZE: int = 14
const ROW_HEIGHT: float = 26.0
## Horizontal gap between a row's verb label and its right-hand hint/reason
## column. Also the minimum, since row widths are computed as
## [code]label + GAP + hint[/code].
const COLUMN_GAP: float = 24.0
## How far the right-hand hint/reason column is held off the row's right edge.
const HINT_INSET_PX: float = 6.0
const PAD_X: float = 12.0
const PAD_Y: float = 8.0

## Clearance between the selected entity's anchor and the menu's near edge, as a
## multiple of the on-screen tile width. One full tile is what keeps the plate off
## the entity's own sprite AND off the eight tiles around it — the tiles a Move or
## Attack preview is most likely to light up (`design/ux/action-menu.md`,
## placement rule 1).
const CLEARANCE_TILES: float = 1.0

## Keep-on-screen margin used by the placement flip and the vertical clamp.
const SAFE_MARGIN_PX: float = 12.0

## Opacity the parent plate drops to while the submenu is open, so focus reads as
## having moved without the parent disappearing (the player must still see which
## verb they are inside).
const PARENT_DIM: float = 0.55

const FADE_IN_SEC: float = 0.15
const FADE_OUT_SEC: float = 0.10
const SUBMENU_FADE_SEC: float = 0.12

## What [constant CommandFSM.Verb.CANCEL_BUILD]'s row says once it is ARMED and one
## more activation will destroy the structure. See [method _on_verb_row_pressed]
## for why that verb alone takes two presses.
const CONFIRM_LABEL: String = "Confirm cancel"

## The armed row's right-hand column — it replaces the shortcut hint, because the
## only thing worth saying at that moment is what the next press does.
const CONFIRM_HINT: String = "destroys it"

## Verb labels. Held here rather than on [CommandFSM] because they are
## player-facing copy owned by the UX spec, and [CommandFSM] is pure logic that no
## localisation pass should ever have to open.
const VERB_LABELS: Dictionary = {
	CommandFSM.Verb.MOVE: "Move",
	CommandFSM.Verb.ATTACK: "Attack",
	CommandFSM.Verb.PRODUCE: "Produce",
	CommandFSM.Verb.WAIT: "Wait",
	CommandFSM.Verb.CANCEL_BUILD: "Cancel Build",
}

## The input action whose CURRENT binding is drawn as each verb's shortcut hint.
## Read live from the [InputMap] on every open, never hardcoded, so a player who
## has rebound Move sees the key they chose (`design/ux/action-menu.md` AC-15).
## A verb absent from this map simply shows no hint.
const VERB_SHORTCUTS: Dictionary = {
	CommandFSM.Verb.MOVE: &"board_act",
	CommandFSM.Verb.ATTACK: &"board_attack",
	CommandFSM.Verb.PRODUCE: &"board_produce",
}

## Player-facing phrasing per [enum CommandFSM.Reason] flag. Whole strings, never
## assembled from fragments, so a translator can reorder freely
## (`design/ux/action-menu.md`, Localization).
##
## [b]The economic reasons name the BINDING POOL[/b] — "needs Credits", "needs AP"
## — never a generic "unaffordable" (CR-8 / D-2 / AC-6b). Which pool fell short is
## the actionable half of the message: one is fixed by waiting a turn, the other by
## selling or building differently.
const REASON_LABELS: Dictionary = {
	CommandFSM.Reason.OUT_OF_RANGE: "no route",
	CommandFSM.Reason.INSUFFICIENT_AP: "needs AP",
	CommandFSM.Reason.NO_TARGETS: "no targets",
	CommandFSM.Reason.ALREADY_ATTACKED: "already attacked",
	CommandFSM.Reason.NOT_A_PRODUCER: "not a producer",
	CommandFSM.Reason.NOT_COMPLETED: "still building",
	CommandFSM.Reason.PRODUCTION_CAP_REACHED: "cap reached",
	CommandFSM.Reason.NO_DEPLOY_SPACE: "no space",
	CommandFSM.Reason.NOT_UNDER_CONSTRUCTION: "nothing to cancel",
	CommandFSM.Reason.INSUFFICIENT_CREDITS: "needs Credits",
	CommandFSM.Reason.POPULATION_CAP_REACHED: "at pop cap",
}

## Player-facing phrasing for an [enum Action.Reason] a validator returned when a
## commit was REJECTED (see [signal CommandInterface.commit_rejected]).
##
## [b]Deliberately here, beside [constant REASON_LABELS], and not in the scene
## glue that renders it.[/b] These are two different enums —
## [enum CommandFSM.Reason] says why a verb is greyed out, [enum Action.Reason]
## says why a dispatched commit was refused — but they are the same VOICE speaking
## to the same player about the same action, moments apart. Split across two files
## they would drift into two vocabularies ("needs AP" here, "not enough action
## points" there), which is precisely the drift that made the pre-menu interface
## hard to read.
const COMMIT_REJECTION_LABELS: Dictionary = {
	Action.Reason.NOT_ACTIVE_PLAYER: "not your turn",
	Action.Reason.CANT_AFFORD: "needs AP",
	Action.Reason.CANT_AFFORD_CREDITS: "needs Credits",
	Action.Reason.ILLEGAL_TARGET: "not a legal target",
	Action.Reason.OUT_OF_RANGE: "out of range",
	Action.Reason.TILE_OCCUPIED: "that tile is taken",
	Action.Reason.NOT_LEGAL_BUILD_TILE: "can't build there",
	Action.Reason.PRODUCTION_CAP_REACHED: "cap reached",
	Action.Reason.NOT_COMPLETED: "still building",
	Action.Reason.NOT_PRODUCIBLE: "this producer can't make that",
	Action.Reason.NOT_LEGAL_DEPLOY_TILE: "can't deploy there",
	Action.Reason.NOT_UNDER_CONSTRUCTION: "nothing to cancel",
	Action.Reason.GAME_OVER: "the match is over",
	Action.Reason.NO_SUCH_ENTITY: "that entity is gone",
}


## One line explaining a rejected commit, for [param reason].
##
## Falls back to a generic phrase rather than an empty string for an unmapped
## reason: a rejection the interface cannot name is still a rejection the player
## must be told about, and saying nothing is the failure mode being fixed. The
## fallback names the code so a bug report can carry it.
static func commit_rejection_text(reason: int) -> String:
	return COMMIT_REJECTION_LABELS.get(reason, "the action was refused (code %d)" % reason)


## Order the reason flags are read in when a row carries several. Fixed rather than
## derived from the enum's numeric order so the wording of a multi-reason row is
## deterministic — a row that reads "no targets, needs AP" today must not read
## "needs AP, no targets" tomorrow because a flag value changed.
const REASON_ORDER: Array[int] = [
	CommandFSM.Reason.NOT_A_PRODUCER,
	CommandFSM.Reason.NOT_UNDER_CONSTRUCTION,
	CommandFSM.Reason.NOT_COMPLETED,
	CommandFSM.Reason.ALREADY_ATTACKED,
	CommandFSM.Reason.OUT_OF_RANGE,
	CommandFSM.Reason.NO_TARGETS,
	CommandFSM.Reason.PRODUCTION_CAP_REACHED,
	CommandFSM.Reason.NO_DEPLOY_SPACE,
	CommandFSM.Reason.POPULATION_CAP_REACHED,
	CommandFSM.Reason.INSUFFICIENT_CREDITS,
	CommandFSM.Reason.INSUFFICIENT_AP,
]

## When true every fade duration collapses to zero
## ([member GameSettings.reduced_motion]). Injected through [method configure]
## rather than read off the [code]Settings[/code] autoload, so a test can exercise
## both paths without an autoload (coding standards: DI over singletons).
var _reduced_motion: bool = false

## True while the plate is showing a STANDALONE picker (the player-level Build
## list) rather than a verb menu with a submenu hanging off it. The two need
## different placement — one hangs off an entity on the board, the other off a HUD
## control — and different teardown, since a standalone picker has no parent plate
## to restore.
var _picker_only: bool = false

var _plate: PanelContainer = null
var _rows_box: VBoxContainer = null
var _submenu: PanelContainer = null
var _submenu_box: VBoxContainer = null

## Anchor and clearance from the last [method open]/[method place] call, retained
## so [method _reposition] can re-run on a camera move or window resize without the
## caller having to re-supply them.
var _anchor: Vector2 = Vector2.ZERO
var _tile_width_px: float = 128.0

## The entity the open menu belongs to, so the caller can ask whether a stale menu
## is still about the current selection.
var _entity_id: int = -1

## Guard so the fade-out tween cannot leave a hidden plate that a later
## [method open] then fades in from a half-finished alpha.
var _fade: Tween = null

## The [enum CommandFSM.Verb] currently ARMED — one further activation commits it.
## -1 when nothing is armed, which is almost always.
##
## Only [constant CommandFSM.Verb.CANCEL_BUILD] ever arms. See
## [method _on_verb_row_pressed].
var _armed_verb: int = -1


func _init() -> void:
	# The menu is a positioned overlay, not a laid-out child: it sets its own
	# top-left in screen space and must never be stretched by an ancestor preset.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	# The Control itself is inert; only its rows take input. Without this the
	# invisible full-size root would eat board clicks around the plate.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Sets the one behavioural knob. Call before [method open]; safe to call again at
## any time (a settings change mid-match takes effect on the next open).
func configure(reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion


## Whether a menu is currently on screen.
func is_open() -> bool:
	return visible


## The entity id the open menu belongs to, or -1 when closed. The caller uses this
## to tell "the menu is already showing this entity" (leave it alone) from "the
## selection moved" (rebuild it).
func entity_id() -> int:
	return _entity_id


## Whether the Produce submenu is the layer currently taking input. Back-out
## routing needs this: a back-out with the submenu open closes only the submenu.
func is_submenu_open() -> bool:
	return _submenu != null and _submenu.visible


## Builds and shows the menu for [param entity] under [param state], anchored at
## [param anchor_screen] (the entity's ground point in this Control's parent
## space) with [param tile_width_px] being one board tile's CURRENT on-screen
## width — passed in rather than read off [BoardRenderer] because it varies with
## camera zoom, and the menu must keep its one-tile clearance at any zoom.
##
## Rebuilds from scratch every call. That is deliberate: the menu re-opens after
## every commit with a re-filtered model (AC-12), and diffing rows against the
## previous model would be more code than rebuilding five of them.
func open(state: GameState, entity: EntityState, anchor_screen: Vector2, \
		tile_width_px: float) -> void:
	_entity_id = entity.entity_id if entity != null else -1
	_armed_verb = -1 # a re-filtered menu is a fresh decision, never a half-made one.
	_picker_only = false
	_anchor = anchor_screen
	_tile_width_px = tile_width_px
	_close_submenu()
	_build_plate()
	_fill_rows(
		CommandFSM.menu_model(state, entity),
		CommandFSM.produce_options(state, entity),
		_refund_text(state, entity)
	)
	_reposition()
	_show_with_fade()
	_focus_first_enabled()


## Re-runs placement against the retained anchor. Called when the camera moves or
## the window resizes: the anchor is a board position and the menu is screen-space,
## so the two drift apart without this.
func place(anchor_screen: Vector2, tile_width_px: float) -> void:
	_anchor = anchor_screen
	_tile_width_px = tile_width_px
	if visible:
		_reposition()


## Hides the menu and drops its rows. Idempotent — closing a closed menu is a
## no-op, never an error, because several unrelated events (deselect, end turn,
## game over, opponent's turn) each legitimately want to close it.
func close() -> void:
	if not visible:
		return
	_close_submenu()
	_picker_only = false
	_armed_verb = -1
	_entity_id = -1
	if _plate != null:
		_plate.visible = true
	if _reduced_motion:
		visible = false
		return
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", 0.0, FADE_OUT_SEC)
	_fade.tween_callback(func() -> void: visible = false)


## Routes a back-out (Esc / right-click / pad B) into the menu, returning whether
## the menu CONSUMED it.
##
## [b]The return value is the whole point[/b] — it is what lets the caller layer
## back-out over pause without either one guessing. With the submenu open this
## closes the submenu and returns true; with only the menu open it closes and
## emits [signal dismissed] and returns true; with nothing open it returns false
## and the caller is free to treat the same key as Pause
## (`design/ux/action-menu.md`, decision 1).
func back_out() -> bool:
	# ★ An armed destructive verb disarms FIRST, and consumes the press doing it.
	# Backing out of "are you sure" must mean "no" — not "yes, and also close the
	# menu", and not "ignore that and deselect", which would leave the player
	# unsure whether they had just destroyed something.
	if _armed_verb != -1:
		_disarm()
		return true
	if is_submenu_open():
		_close_submenu()
		_focus_first_enabled()
		return true
	if visible:
		close()
		dismissed.emit()
		return true
	return false


# --- Construction -----------------------------------------------------------

## Creates (or clears) the plate and its row container.
func _build_plate() -> void:
	if _plate == null:
		_plate = PanelContainer.new()
		_plate.name = "MenuPlate"
		_plate.add_theme_stylebox_override("panel", _plate_style())
		add_child(_plate)
		_rows_box = VBoxContainer.new()
		_rows_box.name = "Rows"
		_rows_box.add_theme_constant_override("separation", 2)
		_plate.add_child(_rows_box)
	_plate.modulate.a = 1.0
	for child: Node in _rows_box.get_children():
		child.queue_free()
		_rows_box.remove_child(child)


## The shared plate [StyleBoxFlat]. A fresh instance per plate rather than one
## shared constant because the submenu dims its parent via
## [member CanvasItem.modulate], and a shared StyleBox would be fine today but
## would silently couple the two the first time either wants its own tint.
func _plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKING
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(PAD_Y)
	style.content_margin_left = PAD_X
	style.content_margin_right = PAD_X
	return style


## Populates the top-level rows from [param model], and remembers
## [param produce_options] for the submenu the Produce row opens.
##
## [b]Every verb in the model gets a row, including the disabled ones[/b] (CR-4).
## The one exception is Cancel Build, which is dropped when disabled: it is
## disabled for every unit and every completed structure — i.e. almost always —
## and a permanent "Cancel Build - nothing to cancel" row on a scout teaches
## nothing and costs a row on every menu in the game. A verb that is disabled
## because of the SITUATION is informative; a verb that is disabled because it
## does not apply to this KIND of entity is noise.
func _fill_rows(model: Array[CommandFSM.VerbEntry], \
		produce_options: Array[CommandFSM.ProduceOption], refund: String = "") -> void:
	var items: Array[Dictionary] = []
	for entry: CommandFSM.VerbEntry in model:
		if entry.verb == CommandFSM.Verb.CANCEL_BUILD and not entry.enabled:
			continue
		var right: String = ""
		if not entry.enabled:
			right = reason_text(entry.reason)
		elif entry.verb == CommandFSM.Verb.PRODUCE:
			# ASCII ">" rather than a triangle: the fallback font has no glyph for
			# one and would draw a tofu box.
			right = "> " + _shortcut_for(entry.verb)
		elif entry.verb == CommandFSM.Verb.CANCEL_BUILD:
			# The refund shows BEFORE either press, not after — the
			# Hold-to-Confirm Refund pattern's "see the cost before you commit"
			# promise, applied to a negative-outcome action.
			right = refund
		else:
			right = _shortcut_for(entry.verb)
		items.append({
			"label": VERB_LABELS.get(entry.verb, "?"),
			"right": right,
			"enabled": entry.enabled,
			"is_reason": not entry.enabled,
			"on_press": _on_verb_row_pressed.bind(entry.verb, produce_options),
			"verb": entry.verb,
		})
	_fill(_rows_box, items)


## Shared row-building for all three list kinds — verb menu, Produce submenu and
## Build picker. Each [param items] entry is
## [code]{label, right, enabled, is_reason, on_press}[/code].
##
## [b]One filler, not three[/b]: the three lists differ only in what their rows say
## and what pressing one does, and every visual rule they share (the two-column
## width, focus skipping disabled rows, the reason colour) is a rule that must not
## be able to drift between them.
func _fill(box: VBoxContainer, items: Array[Dictionary]) -> void:
	var widest: float = 0.0
	var rows: Array[Button] = []
	for item: Dictionary in items:
		var row: Button = _make_row(
			item["label"], item["right"], item["enabled"], item["is_reason"]
		)
		row.pressed.connect(item["on_press"])
		# Tagged so _row_for can find a row whose LABEL has changed (an armed
		# destructive verb no longer reads as its own name).
		row.set_meta(&"verb", item.get("verb", -1))
		row.set_meta(&"right", item["right"]) # what _disarm restores.
		box.add_child(row)
		rows.append(row)
		widest = maxf(widest, _row_width(row, item["label"], item["right"]))
	# Applied after the loop so every row in a list is the same width — a ragged
	# list of buttons reads as a rendering fault rather than as a menu.
	for row: Button in rows:
		row.custom_minimum_size.x = widest


## One row's cost/reason column, shared by the Produce and Build pickers.
##
## The cost is shown on DISABLED rows too: the price is precisely what explains
## the disablement, so hiding it would defeat the row.
static func _cost_text(credit_cost: int, ap_cost: int, enabled: bool, reason: int) -> String:
	var text: String = "%d CR + %d AP" % [credit_cost, ap_cost]
	if not enabled:
		text += "  " + reason_text(reason)
	return text


## The Cancel Build row's right-hand column: what the player gets back. Empty for
## anything that is not an owned under-construction structure, which is every
## entity whose row would have been dropped anyway.
##
## Read through [method CommandFSM.cancel_build_preview] — the same Pass-Through
## query the FSM uses — never off the structure type's own cost field.
static func _refund_text(state: GameState, entity: EntityState) -> String:
	if not (entity is StructureState):
		return ""
	var structure: StructureState = entity
	if structure.build_status != StructureState.BuildStatus.UNDER_CONSTRUCTION:
		return ""
	return "+%d AP back" % CommandFSM.cancel_build_preview(state, structure)


## Builds one row. [param is_reason] switches the right-hand column's colour from
## "this is a shortcut" to "this is why not".
func _make_row(label: String, right: String, enabled: bool, is_reason: bool) -> Button:
	var row := Button.new()
	row.text = label
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_font_size_override("font_size", FONT_SIZE)
	row.flat = true
	row.disabled = not enabled
	# A disabled Button is not focusable in Godot, which is exactly the wanted
	# behaviour: the row stays VISIBLE and READABLE but keyboard focus steps over
	# it, so traversal only ever stops somewhere that does something. Same
	# visible-but-inert treatment the Settings screen's reset buttons use.
	row.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	# All five Button font states are set explicitly, not just the default one.
	# Godot's theme supplies its own hover/pressed/focus colours, and leaving them
	# in place made the FOCUSED row — the one the keyboard is on — render dimmer
	# than the rows around it, i.e. exactly backwards from what focus should read as.
	row.add_theme_color_override("font_color", LABEL_ENABLED if enabled else LABEL_DISABLED)
	row.add_theme_color_override("font_focus_color", LABEL_FOCUS)
	row.add_theme_color_override("font_hover_color", LABEL_FOCUS)
	row.add_theme_color_override("font_pressed_color", LABEL_FOCUS)
	row.add_theme_color_override("font_disabled_color", LABEL_DISABLED)
	if right != "":
		var hint := Label.new()
		hint.text = right
		hint.add_theme_font_size_override("font_size", FONT_SIZE)
		hint.add_theme_color_override("font_color", REASON if is_reason else HINT)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Pulled in from the button's right edge by the same inset the width
		# calculation reserves, so the last character never sits on the frame.
		hint.offset_right = -HINT_INSET_PX
		hint.offset_left = HINT_INSET_PX
		# The hint is decoration on top of the button; letting it take the mouse
		# would punch a dead zone through the middle of a clickable row.
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hint)
	return row


## Pixel width a row needs for its two columns not to collide. Measured with the
## row's own font because the plate hugs its content and Godot's [Button] minimum
## size accounts only for its own text, never for the [Label] laid over it.
func _row_width(row: Button, label: String, right: String) -> float:
	var font: Font = row.get_theme_font("font")
	if font == null:
		return 0.0
	var left_w: float = font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
	).x
	var right_w: float = 0.0
	if right != "":
		right_w = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# The Button's own StyleBox eats horizontal room INSIDE the width we are about to
	# set, so a width of exactly label+gap+hint clips the right-hand column by
	# however much the theme happens to inset. Measured off the live stylebox rather
	# than guessed, because the number is a theme's to choose, not ours.
	var inset: float = 0.0
	var style: StyleBox = row.get_theme_stylebox("normal")
	if style != null:
		inset = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	return left_w + COLUMN_GAP + right_w + inset


## Human-readable phrasing for a [enum CommandFSM.Reason] bitmask, in
## [constant REASON_ORDER]. Every set flag is named, comma-separated — AC-8b's
## "no reason is hidden for the player to discover later" is a rendering
## requirement as much as a model one, and a UI that showed only the first flag
## would break it while the model stayed correct.
##
## Public so the disabled-row wording can be asserted directly by a test without
## building a plate.
static func reason_text(mask: int) -> String:
	var parts := PackedStringArray()
	for flag: int in REASON_ORDER:
		if mask & flag:
			parts.append(REASON_LABELS[flag])
	return ", ".join(parts)


## The player's CURRENT binding for [param verb]'s shortcut, bracketed, or an
## empty string when the verb has no shortcut or the action is unbound. Read from
## the live [InputMap] every time so a rebind is reflected without this widget
## knowing the Settings screen exists.
func _shortcut_for(verb: int) -> String:
	if not VERB_SHORTCUTS.has(verb):
		return ""
	var action: StringName = VERB_SHORTCUTS[verb]
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			var name: String = OS.get_keycode_string(code)
			if name != "":
				return "[%s]" % name
	return ""


# --- Submenu ----------------------------------------------------------------

## Opens the per-type Produce submenu beside the parent plate, dims the parent and
## moves focus into it.
## Public entry for the [P] accelerator, which opens the submenu without the
## player having clicked the Produce row. Same code path as the row, so the two
## cannot behave differently.
func open_produce_submenu(options: Array[CommandFSM.ProduceOption]) -> void:
	_open_submenu(options)


func _open_submenu(options: Array[CommandFSM.ProduceOption]) -> void:
	var items: Array[Dictionary] = []
	for option: CommandFSM.ProduceOption in options:
		items.append({
			"label": option.unit_type.display_name,
			"right": _cost_text(option.credit_cost, option.ap_cost, option.enabled, option.reason),
			"enabled": option.enabled,
			"is_reason": not option.enabled,
			"on_press": _on_produce_row_pressed.bind(option.unit_type),
		})
	_build_submenu(items)


## Opens the player-level Build picker as a STANDALONE plate at
## [param anchor_screen] — no parent verb menu, because Build has no selected
## entity to hang off (CR-5). Reached from the HUD's persistent Build control.
##
## Uses the submenu plate rather than the verb plate so that opening the Build
## picker never disturbs an action menu the player may already have open on
## something else.
func open_build_options(options: Array[CommandFSM.BuildOption], \
		anchor_screen: Vector2, tile_width_px: float) -> void:
	_anchor = anchor_screen
	_tile_width_px = tile_width_px
	_entity_id = -1
	_close_submenu()
	_picker_only = true # set AFTER the close, which reads it.
	if _plate != null:
		_plate.visible = false
	var items: Array[Dictionary] = []
	for option: CommandFSM.BuildOption in options:
		items.append({
			"label": option.structure_type.display_name,
			"right": _cost_text(option.credit_cost, option.ap_cost, option.enabled, option.reason),
			"enabled": option.enabled,
			"is_reason": not option.enabled,
			"on_press": _on_build_row_pressed.bind(option.structure_type),
		})
	_build_submenu(items)
	_show_with_fade()


## Creates the second plate and fills it with [param items]. Shared by the Produce
## submenu and the Build picker, which differ only in what opens them.
func _build_submenu(items: Array[Dictionary]) -> void:
	_close_submenu()
	_submenu = PanelContainer.new()
	_submenu.name = "OptionPlate"
	_submenu.add_theme_stylebox_override("panel", _plate_style())
	add_child(_submenu)
	_submenu_box = VBoxContainer.new()
	_submenu_box.add_theme_constant_override("separation", 2)
	_submenu.add_child(_submenu_box)
	_fill(_submenu_box, items)
	if _plate != null and _plate.visible:
		_plate.modulate.a = PARENT_DIM
	_submenu.modulate.a = 1.0 if _reduced_motion else 0.0
	_reposition()
	if not _reduced_motion:
		create_tween().tween_property(_submenu, ^"modulate:a", 1.0, SUBMENU_FADE_SEC)
	_focus_first_enabled_in(_submenu_box)


## Tears the submenu down and restores the parent plate's opacity. Safe to call
## when no submenu exists.
func _close_submenu() -> void:
	if _submenu != null:
		_submenu.queue_free()
		_submenu = null
		_submenu_box = null
	if _plate != null and not _picker_only:
		_plate.modulate.a = 1.0
		_plate.visible = true


# --- Placement --------------------------------------------------------------

## Places the plate (and the submenu, when open) around [member _anchor].
##
## Right of the entity by default; mirrored to the left when the right-hand
## placement would pass the viewport's safe margin; clamped vertically but
## [b]never horizontally[/b] (`design/ux/action-menu.md`, placement rules 1-3).
##
## [b]Why vertical-only clamping.[/b] Sliding the plate vertically keeps it beside
## the entity. Sliding it horizontally would push it OVER the entity — which is
## the exact thing the one-tile clearance exists to prevent, so a horizontal clamp
## would quietly undo rule 1 at precisely the board edges where rule 2 already has
## a better answer.
func _reposition() -> void:
	if _picker_only:
		_reposition_picker()
		return
	if _plate == null:
		return
	# Deferred sizing: a Container's size is only correct after it has laid out,
	# and open() places on the same frame it builds. get_combined_minimum_size()
	# is the value the layout will settle on, so use it directly.
	var plate_size: Vector2 = _plate.get_combined_minimum_size()
	var gap: float = _tile_width_px * CLEARANCE_TILES
	var view: Vector2 = get_viewport_rect().size
	var sub_size := Vector2.ZERO
	if _submenu != null:
		sub_size = _submenu.get_combined_minimum_size()

	# Rule 2 tests the pair, not the plate alone: flipping the plate to the left
	# only to have its submenu run off the right edge would trade one overflow for
	# another. The submenu opens outward, away from the entity, on whichever side
	# the plate lands.
	var span: float = plate_size.x + sub_size.x
	var right_edge: float = _anchor.x + gap + span
	var to_the_left: bool = right_edge > view.x - SAFE_MARGIN_PX

	var plate_x: float = _anchor.x - gap - plate_size.x if to_the_left else _anchor.x + gap
	var plate_y: float = clampf(
		_anchor.y - plate_size.y * 0.5,
		SAFE_MARGIN_PX,
		maxf(SAFE_MARGIN_PX, view.y - plate_size.y - SAFE_MARGIN_PX)
	)
	_plate.position = Vector2(plate_x, plate_y)
	_plate.size = plate_size

	if _submenu != null:
		var sub_x: float = plate_x - sub_size.x if to_the_left else plate_x + plate_size.x
		var sub_y: float = clampf(
			plate_y, SAFE_MARGIN_PX, maxf(SAFE_MARGIN_PX, view.y - sub_size.y - SAFE_MARGIN_PX)
		)
		_submenu.position = Vector2(sub_x, sub_y)
		_submenu.size = sub_size


## Places a STANDALONE picker so its bottom-right corner lands on
## [member _anchor], then clamps it onto the screen.
##
## [b]A different rule from the verb menu's, on purpose.[/b] The verb menu hangs
## off an entity somewhere in the middle of the board and flips side to stay on
## screen. A picker hangs off a HUD control in a screen CORNER, where "flip to the
## other side" is meaningless and "grow inward from the corner" is the only
## placement that reads as belonging to the control that opened it. Anchoring the
## bottom-right corner is what makes it grow up-and-left out of the button rather
## than down-and-right off the screen.
func _reposition_picker() -> void:
	if _submenu == null:
		return
	var size: Vector2 = _submenu.get_combined_minimum_size()
	var view: Vector2 = get_viewport_rect().size
	_submenu.position = Vector2(
		clampf(_anchor.x - size.x, SAFE_MARGIN_PX,
			maxf(SAFE_MARGIN_PX, view.x - size.x - SAFE_MARGIN_PX)),
		clampf(_anchor.y - size.y, SAFE_MARGIN_PX,
			maxf(SAFE_MARGIN_PX, view.y - size.y - SAFE_MARGIN_PX))
	)
	_submenu.size = size


## The plate's current screen rect, for the placement tests and for a caller that
## needs to know what the menu is covering. Zero-sized when closed.
func plate_rect() -> Rect2:
	if _plate == null or not visible:
		return Rect2()
	return Rect2(_plate.position, _plate.get_combined_minimum_size())


# --- Focus + input ----------------------------------------------------------

func _show_with_fade() -> void:
	_kill_fade()
	visible = true
	if _reduced_motion:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", 1.0, FADE_IN_SEC)


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


## Moves keyboard focus to the first focusable row of the layer that currently
## owns input — the submenu when it is open, the plate otherwise.
func _focus_first_enabled() -> void:
	if is_submenu_open():
		_focus_first_enabled_in(_submenu_box)
	else:
		_focus_first_enabled_in(_rows_box)


## Grabs focus for the first row in [param box] that can take it. Silently does
## nothing when every row is disabled — which is a real state (an entity with no
## legal action and Wait dropped), and one where leaving focus on the board is the
## right outcome rather than an error.
func _focus_first_enabled_in(box: VBoxContainer) -> void:
	if box == null:
		return
	for child: Node in box.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


## A top-level verb row was activated.
func _on_verb_row_pressed(verb: int, produce_options: Array[CommandFSM.ProduceOption]) -> void:
	match verb:
		CommandFSM.Verb.PRODUCE:
			# Produce chooses nothing by itself — a produce order without a type is
			# not an order. The row opens the submenu and the SUBMENU commits.
			_open_submenu(produce_options)
		CommandFSM.Verb.CANCEL_BUILD:
			# ★ Two presses, not one (`design/ux/action-menu.md` decision 5).
			#
			# `interaction-patterns.md`'s [i]Hold-to-Confirm Refund[/i] governs this
			# verb: destroying an in-progress build for a partial refund has no undo,
			# and the pattern's own "when NOT to use Standard Cancel" clause names it
			# explicitly. A single-activation menu row is exactly the mis-click the
			# pattern exists to prevent.
			#
			# The gate here is ARM-THEN-CONFIRM rather than press-and-hold, and that
			# is deliberate: `accessibility-requirements.md` carries an open
			# Standard-tier commitment for a toggle alternative to that hold ("first
			# press arms, second confirms"), because a sustained press is a motor
			# requirement some players cannot meet. A menu row is the natural home for
			# it — so this satisfies the pattern and closes the accessibility item
			# with one mechanism instead of two.
			#
			# Double-click-proof in the same way the hold is: the row RELABELS on the
			# first press, so a double-click's second press lands on a button that now
			# reads "Confirm cancel" — the player sees what they are about to do even
			# if they do not stop in time. The refund is already visible on the row
			# before either press.
			if _armed_verb == verb:
				close()
				verb_chosen.emit(verb)
			else:
				_arm(verb)
		CommandFSM.Verb.WAIT:
			close()
			waited.emit()
		_:
			# Move / Attack hand off to the caller, which enters the matching preview.
			# The menu hides itself first: the preview it is about to open paints the
			# board, and a plate floating over that overlay would compete with the
			# very thing the player now has to read.
			_disarm() # picking a different verb abandons any armed one.
			close()
			verb_chosen.emit(verb)


## Arms [param verb]: relabels its row so the next activation reads as the
## destructive act it is, and keeps focus on it so a keyboard player confirms
## without having to re-find the row.
func _arm(verb: int) -> void:
	_armed_verb = verb
	var row: Button = _row_for(verb)
	if row == null:
		return
	row.text = CONFIRM_LABEL
	for child: Node in row.get_children():
		if child is Label:
			(child as Label).text = CONFIRM_HINT
			(child as Label).add_theme_color_override("font_color", REASON)
	row.grab_focus()
	# Arrowing away from an armed row abandons the confirmation. A destructive verb
	# left armed while the player is looking at something else is a trap: the next
	# Enter would fire it from a row they are no longer thinking about.
	if not row.focus_exited.is_connected(_disarm):
		row.focus_exited.connect(_disarm, CONNECT_ONE_SHOT)


## Cancels any armed verb and puts its row back the way it was. Safe to call when
## nothing is armed.
func _disarm() -> void:
	if _armed_verb == -1:
		return
	var row: Button = _row_for(_armed_verb)
	var verb: int = _armed_verb
	_armed_verb = -1
	if row == null:
		return
	row.text = VERB_LABELS.get(verb, "?")
	for child: Node in row.get_children():
		if child is Label:
			# Restores the REFUND for Cancel Build (its right column is the refund,
			# never a shortcut) and the shortcut for anything else that could arm.
			(child as Label).text = row.get_meta(&"right", "")
			(child as Label).add_theme_color_override("font_color", HINT)


## Whether [param verb]'s row is armed and one press from committing. Public so a
## test can assert the two-press gate without reaching into the node tree.
func is_armed(verb: int) -> bool:
	return _armed_verb == verb


## The top-level row carrying [param verb], or null. Matched on the verb its
## [signal Button.pressed] handler was bound to rather than on its label, because
## an armed row's label is deliberately not its verb's name any more.
func _row_for(verb: int) -> Button:
	if _rows_box == null:
		return null
	for child: Node in _rows_box.get_children():
		if child is Button and (child as Button).get_meta(&"verb", -1) == verb:
			return child
	return null


## A submenu type row was activated.
func _on_produce_row_pressed(unit_type: UnitTypeDef) -> void:
	close()
	produce_type_chosen.emit(unit_type)


## A Build picker row was activated.
func _on_build_row_pressed(structure_type: StructureTypeDef) -> void:
	close()
	build_type_chosen.emit(structure_type)
