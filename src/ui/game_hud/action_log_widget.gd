## ActionLogWidget — the append-newest-on-top action-log ring buffer
## (ADR-0016 §5, TR-hud-014). A reactive [HudReactiveControl] that, on each
## [signal GameState.action_applied], appends ONE entry per
## [member ActionResult.events] element in the events' fixed append order
## (ADR-0004's deterministic resolution order — so a single commit resolving a
## kill + an HQ-destroy logs each, in order). A fixed-capacity ring of
## [member HUDConfig.action_log_length] (default 20) drops the OLDEST when full;
## the display renders newest-on-top.
##
## Deterministic because the ordering is a property of [member ActionResult.events],
## not of signal-fire timing (ADR-0004's synchronous same-call-stack emit). The
## log is deliberately SILENT — the logged action already fired its own commit
## sound (Story 008 owns audio).
##
## [b]Testable model[/b]: [method entries] (append order) / [method entries_newest_first]
## (display order) / [method entry_count] are the blocking Logic surface (AC-14
## ordering, AC-15 ring-drop); [method _draw] renders the newest-first list
## (icon+text advisory).
##
## Usage:
## [codeblock]
## var log := ActionLogWidget.new()
## log.bind(reader)
## log.configure(HudBalance.hud)
## hud_layer.add_child(log)
## [/codeblock]
class_name ActionLogWidget
extends HudReactiveControl

## Default ring capacity if no [HUDConfig] was injected (matches the resource default).
const _DEFAULT_LOG_LENGTH: int = 20

var _config: HUDConfig = null

## The ring buffer in APPEND order (oldest first, newest last). Capped to the
## configured length; the oldest is dropped when a new append would exceed it.
var _entries: Array[Event] = []


func configure(config: HUDConfig) -> void:
	_config = config


## Overrides [method HudReactiveControl._on_action_applied]: append one entry per
## [member ActionResult.events] element, in append order, then coalesced redraw.
func _on_action_applied(result: ActionResult) -> void:
	for event: Event in result.events:
		_append(event)
	queue_redraw()


func _append(event: Event) -> void:
	_entries.append(event)
	var cap: int = _config.action_log_length if _config != null else _DEFAULT_LOG_LENGTH
	while _entries.size() > cap:
		_entries.pop_front() # drop the oldest.


# --- Display model (Integration-testable) ------------------------------------

## The ring buffer in APPEND order (oldest → newest). At most action_log_length.
func entries() -> Array[Event]:
	return _entries.duplicate()

## The entries in DISPLAY order (newest → oldest) — how the log renders.
func entries_newest_first() -> Array[Event]:
	var out: Array[Event] = _entries.duplicate()
	out.reverse()
	return out

## The current number of retained entries (== min(total appended, capacity)).
func entry_count() -> int:
	return _entries.size()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var y: float = 14.0
	for event: Event in entries_newest_first():
		draw_string(font, Vector2(4, y), _entry_text(event), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.85))
		y += 13.0


## Player-facing wording per event class, keyed by the event's global class name.
##
## ★ Added 2026-08-24. The log previously rendered the raw class name, so the one
## surface whose entire job is telling the player what just happened said
## "UnitDeployedEvent" at them. That was fine while nothing had ever been seen on
## screen; it is not something to ship. Wording is deliberately plain and
## past-tense, matching how the player would describe the same event out loud.
const ENTRY_LABELS: Dictionary = {
	&"UnitDeployedEvent": "Unit deployed",
	# ★ S8-28: production is multi-turn, so a produce commit changes NOTHING on the
	# board. Without an entry here the player presses Produce, watches Credits and AP
	# drain, and sees no other consequence — which reads as a bug, not as a build.
	&"ProductionStartedEvent": "Production started",
	&"ProductionCancelledEvent": "Production cancelled",
	&"UnitMovedEvent": "Unit moved",
	&"UnitDestroyedEvent": "Unit destroyed",
	&"DamageEvent": "Damage dealt",
	&"StructurePlacedEvent": "Construction started",
	&"StructureCompletedEvent": "Structure completed",
	&"StructureDestroyedEvent": "Structure destroyed",
	&"StructureCancelledEvent": "Construction cancelled",
	&"TechCompletedEvent": "Research complete",
	&"EntityStoodDownEvent": "Stood down",
	&"GameOverEvent": "Match over",
}


## A short label for [param event]'s log row (advisory text — the icon treatment
## remains a [code]/ux-design[/code] + [code]/art-bible[/code] concern).
##
## Falls back to the class name for an event class with no entry here, which keeps
## a newly-added event visible in the log rather than silently blank — a missing
## label should look like a missing label, not like nothing happening.
func _entry_text(event: Event) -> String:
	var script: Script = event.get_script()
	if script == null or script.get_global_name() == &"":
		return "Event"
	var key: StringName = script.get_global_name()
	return ENTRY_LABELS.get(key, String(key))
