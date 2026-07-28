## InputConfig — designer-tunable input-timing values for the Command & Action
## Interface (ADR-0015 §2, Story 004).
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
