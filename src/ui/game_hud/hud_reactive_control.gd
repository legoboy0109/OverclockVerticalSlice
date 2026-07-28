## HudReactiveControl — reusable base [Control] establishing the Game HUD's
## coalescing-redraw mechanism (ADR-0016 §8, TR-hud-002/023).
##
## Holds an injected [GameStateReader] (never a live [GameState] — TR-hud-003)
## and subscribes to [signal GameState.action_applied] via the reader's
## signal-subscription broker. On any commit, this reacts by calling native
## [method CanvasItem.queue_redraw] only — never a hand-rolled
## [method Node._process] dirty-flag poll (control-manifest, ADR-0016 §8).
## [method CanvasItem.queue_redraw] natively coalesces N calls within one frame
## into exactly one [method CanvasItem._draw] that frame, so a single commit
## firing N events (or N commits within one frame) yields one redraw, not N.
##
## This class establishes the mechanism only — it wires no widget content
## (no AP counter, income breakdown, log, detail panel, or on-board glyphs).
## Those are later Game HUD stories, each subclassing this base and overriding
## [method CanvasItem._draw] to render from the injected [member _reader].
##
## [b]bind() is safe before or after tree entry[/b]: [method bind] may be
## called either BEFORE [method Node._ready] runs (the typical flow —
## instantiate, [method bind], then [method Node.add_child]) or AFTER this node
## is already inside the tree (a dynamic-attach flow — [method Node.add_child]
## then [method bind]). Either path results in exactly one subscription: the
## reader's broker guards on [method Signal.is_connected], so subscribing twice
## (once from [method bind] if already in-tree, once from [method Node._ready]
## if bound beforehand) is a safe no-op, never a double connection.
##
## Usage:
## [codeblock]
## # Typical flow: instantiate, bind, then add to the tree.
## var widget := HudReactiveControl.new()
## widget.bind(reader)
## hud_layer.add_child(widget) # _ready() subscribes.
##
## # Dynamic-attach flow: already in the tree, bound later.
## var widget2 := HudReactiveControl.new()
## hud_layer.add_child(widget2) # _ready() runs first; _reader is null, no-op.
## widget2.bind(reader) # bind()'s is_inside_tree() branch subscribes now.
## [/codeblock]
class_name HudReactiveControl
extends Control

## The injected read-only facade this widget renders from. Never a live
## [GameState] (TR-hud-003, ADR-0016 §1). Set via [method bind].
var _reader: GameStateReader


## Injects [param reader] (DI seam, mirrors [CommandInterface]'s setter
## convention). Safe to call either before or after this node enters the tree —
## see this class's doc comment. If this node is already inside the tree when
## [method bind] is called, subscribes immediately; otherwise [method Node._ready]
## performs the subscription once this node enters the tree.
func bind(reader: GameStateReader) -> void:
	_reader = reader
	if is_inside_tree():
		_reader.subscribe_action_applied(_on_action_applied)


func _ready() -> void:
	if _reader != null:
		_reader.subscribe_action_applied(_on_action_applied)


## Reacts to a successful commit by requesting a coalesced redraw only — no
## rendering, no state read, happens here (subclasses read from [member _reader]
## inside their own [method CanvasItem._draw] override). Never calls
## [method Node.set_process] / holds a dirty-flag [bool] (control-manifest
## forbidden pattern, ADR-0016 §8).
func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


## Guarded unsubscribe on tree exit (mirrors [CommandInterface]'s convention) —
## so connections never accumulate across a match restart within one process.
## Idempotent via the reader's own [code]is_connected[/code] guard.
func _exit_tree() -> void:
	if _reader != null:
		_reader.unsubscribe_action_applied(_on_action_applied)
