## CreditsCounterWidget — the reactive Control that renders the Credits counter
## (the game's *banked economic* war chest), the AP counter's co-equal introduced
## by the 2026-08-05 economy pivot. ADR-0016 §2/§8, CR-3d, TR-hud-005/019.
##
## A thin [BudgetCounterWidget] subclass: all the FSM wiring, preview echo, settle
## timing, opponent muting, and the Integration-testable display model live in the
## shared base — this class supplies only the Credits-specific pieces. It reads the
## [b]Credits[/b] pool ([method GameStateReader.current_credits]) and renders in a
## distinct war-chest hue family (CR-3d — held apart from the AP counter's tactical
## hue so tempo and war chest never blur) with a [code]CR[/code] label so the two
## persistent counters are distinguishable by more than hue alone (accessibility,
## CR-3d). The provisional gold hue + [code]CR[/code] label are placeholders; the
## final AP-vs-Credit hue split and glyph are an /art-bible decision (OQ-9).
##
## [b]Accumulate-don't-reset[/b] (CR-3d): unlike the AP counter, Credits BANK — the
## start-of-turn income [i]adds to[/i] the running pile rather than overwriting it,
## and the pool never discards at end of turn. This difference lives entirely in
## the engine ([method Credits.add_income] vs [method AP.reset_turn]); this widget
## sees only "committed value rose at a turn boundary -> income flourish" (AC-29),
## exactly the base's shared behaviour, because it reads the pool verbatim and never
## computes the addition itself (Pass-Through Invariant). An economic spend ticks it
## down by the Credit cost (AC-30); a Cancel-Build refund raises it mid-turn WITHOUT
## a flourish. The on-demand Credit income breakdown ([IncomeBreakdownWidget]) is
## anchored to this counter (CR-3d).
##
## Usage:
## [codeblock]
## var counter := CreditsCounterWidget.new()
## counter.bind(reader)                       # HudReactiveControl DI
## counter.configure(HudBalance.hud, local_player)
## hud_layer.add_child(counter)
## # when CAI opens an affordable economic preview costing C Credits at A on hand:
## counter.open_preview(A - C, true)          # shows A -> A-C (AC-31)
## [/codeblock]
class_name CreditsCounterWidget
extends BudgetCounterWidget


## Selects the Credits pool (verbatim, Pass-Through Invariant).
func _read_committed_value() -> int:
	return _reader.current_credits(_player)


## The war-chest/Credits neon hue (muted for the opponent counter, CR-3b).
## Provisional gold — distinct from the AP counter's tactical cyan-green (OQ-9).
func _budget_color() -> Color:
	return Color(0.5, 0.46, 0.35) if _is_opponent else Color(1.0, 0.82, 0.25)


## The committed value with a `CR` resource label (accessibility distinctness,
## CR-3d) and the persistent OPPONENT prefix on the opponent counter (CR-3b).
func _committed_text() -> String:
	return "OPPONENT CR %d" % _committed if _is_opponent else "CR %d" % _committed


## "credits" for the "insufficient credits" unaffordable-preview text.
func _insufficient_noun() -> String:
	return "credits"


## Whether an unaffordable Credit preview is open — renders "insufficient credits".
## Credits-named alias for [method BudgetCounterWidget.insufficient_budget].
func insufficient_credits() -> bool:
	return insufficient_budget()
