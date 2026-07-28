## SelectionTarget — the payload of [signal CommandInterface.selection_changed]
## (ADR-0015 §6 / ADR-0016 §6 seam, TR-hud-013).
##
## A tiny value describing what the Command & Action Interface's selection /
## inspection currently points at, so the Game HUD's detail panel can re-render
## outward-in without the interface ever calling into a HUD node (preserving the
## HUD's leaf status, TR-hud-020).
##
## [member entity_id] == -1 means "no target" (nothing selected, nothing being
## inspected). [member pinned] distinguishes a persistent selection
## ([code]true[/code]) from a transient hover/inspect peek ([code]false[/code]) —
## the pinned-vs-peek VISUAL treatment is the HUD's / [code]/ux-design[/code]'s
## concern (CR-6, non-hue-redundant); this type only carries the flag.
##
## Usage:
## [codeblock]
## func _on_selection_changed(target: SelectionTarget) -> void:
##     if target.entity_id == -1:
##         _detail_panel.clear()
##     else:
##         _detail_panel.render(_reader.unit_info(target.entity_id), target.pinned)
## [/codeblock]
class_name SelectionTarget
extends RefCounted

## The targeted entity's id, or -1 for "no target".
var entity_id: int

## True for a persistent selection, false for a transient inspection (peek).
var pinned: bool


func _init(p_entity_id: int = -1, p_pinned: bool = false) -> void:
	entity_id = p_entity_id
	pinned = p_pinned
