## InputConfig — designer-tunable input-timing values for the Command & Action
## Interface (ADR-0014 / ADR-0015 §2, Story 004/007).
##
## Presentation-layer config [Resource] per ADR-0015 §2: the single home for
## input-timing thresholds this interface layer owns, mirroring the project's
## established owning-system config Resource pattern (e.g.
## [code]BaseProductionConfig[/code]). [CommandInterface] holds an injectable
## instance of this (never an autoload/[code].tres[/code] singleton) so a test
## can substitute a small threshold without touching real input timing.
##
## Usage:
## [codeblock]
## var config := InputConfig.new()
## config.cancel_build_hold_ms = 50 # a test's fast-forwarded threshold.
## [/codeblock]
class_name InputConfig
extends Resource

## How long (in milliseconds) the Cancel-Build affordance must be held before
## the destructive gesture commits (ADR-0015 §2, Story 004's bounded hold
## sub-condition inside [constant CommandFSM.State.ENTITY_SELECTED]).
## [b]Unpinned feel value[/b] — 500 is a placeholder pending a `/ux-design`
## playtest pass, not a balanced/final number.
@export var cancel_build_hold_ms: int = 500

## The commit-input debounce window (in milliseconds) — after a commit
## dispatches, new commit dispatch is inert for this long (ADR-0014,
## TR-cmdui-022, Story 007). A [b]UX debounce only[/b], NOT the single-commit
## correctness mechanism (that is structurally guaranteed by synchronous input
## dispatch + the FSM's immediate transition); it only gates new [b]commit[/b]
## dispatch — hover, board-cursor movement, and menu focus traversal stay live
## during the window. The cross-system invariant
## [code]input_lock_ms >= AP_TICK_DURATION_MS[/code] is enforced by the Game HUD
## epic's config loader once [code]HUDConfig[/code] exists (not here).
@export var input_lock_ms: int = 120
