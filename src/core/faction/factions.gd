## Factions — thin logic-free registry of FactionDef consts (Story 007 stub).
##
## Mirrors [code]UnitTypes[/code]/[code]Balance[/code]'s "preload once, expose
## by reference" idiom (ADR-0006/0007). [code]class_name[/code] + [code]const[/code]
## rather than an Autoload: a [code]const[/code] resolves statically as
## [code]Factions.NEUTRAL[/code] with no [code]project.godot[/code] registration
## needed (ADR-0012 §2's [code]preload()[/code]'d registry-const pattern).
##
## [b]This is a minimal Story 007 stub[/b] — the Faction Identity epic
## supersedes it with the full [code]NEUTRAL[/code]/[code]RUSH[/code]/[code]BOOM[/code]
## registry (ADR-0012 §2). Only [code]NEUTRAL[/code] exists here, so this
## story's Neutral no-op regression test (AC-1) is a genuine registry read,
## never a fresh [code]FactionDef.new()[/code].
class_name Factions
extends RefCounted

const NEUTRAL: FactionDef = preload("res://data/factions/neutral.tres")
