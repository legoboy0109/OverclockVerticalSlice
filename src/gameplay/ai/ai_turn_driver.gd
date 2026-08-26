## AITurnDriver — small, non-authoritative pacing loop for the AI's turn.
##
## Feature-layer system per ADR-0011 §3 (Loop driver). Owns real-time pacing
## between the AI's committed actions ONLY — it holds [b]zero authoritative
## state[/b] of its own, mirroring [code]MatchService[/code]'s
## logic-free-reference-holder discipline. Not an Autoload, not authoritative,
## instantiated once per match alongside [code]MatchService[/code] in the
## match-bootstrap scene (a detail this class does not itself pin down — see
## the class-level "Bootstrap call site" note below).
##
## [b]This is the one file in the AI Opponent epic allowed to
## [code]await[/code].[/b] [code]ai.gd[/code] ([AI]) is fully headless and
## contains no [code]await[/code] anywhere — [method AI.choose_action] never
## touches a [Node] or the scene tree (ADR-0011 §1/§3, TR-ai-001). Splitting
## pacing out to this [Node] is what lets [AI] stay unit-testable with no
## running [SceneTree].
##
## [b]The evaluate→commit loop (ADR-0011 §3, verbatim shape):[/b]
## [codeblock]
## var economy_investments := 0   # turn-scoped LOCAL var — never a field.
## while true:
##     var action := AI.choose_action(state, economy_investments)
##     if action == null:
##         break                                  # AC-9/AC-25: nothing left to do.
##     var result := state.apply_action(action)   # REAL state, not a clone;
##                                                  # fires action_applied synchronously
##                                                  # on success (ADR-0004).
##     if not result.ok:
##         continue                                # AC-24/AC-10: stale/rejected
##                                                  # candidate — re-loop immediately,
##                                                  # no AP spent, no pacing delay.
##     if _is_economy_or_research(action):
##         economy_investments += 1
##     if state.match_status == GameState.MatchStatus.GAME_OVER:
##         return                                   # AC-35: the AI's own lethal
##                                                  # commit ended the match — stop
##                                                  # immediately, never enumerate
##                                                  # again against a terminal state.
##     await get_tree().create_timer(AIBalance.ai.commit_pacing_sec).timeout
## state.apply_action(EndTurnAction.new-with-player(state.active_player))
## [/codeblock]
##
## [b]Termination (TR-ai-009):[/b] guaranteed by three exits —
## [code]action == null[/code] (no candidate cleared
## [code]AIBalance.ai.pass_threshold[/code]), [member GameState.match_status]
## flipping to [constant GameState.MatchStatus.GAME_OVER], or the
## [constant MAX_CONSECUTIVE_REJECTS] backstop. In the healthy case a rejected
## commit never counts as progress and never blocks termination, since
## [method AI.choose_action] is re-run against the SAME (unmutated-by-the-
## rejection) real [param state] next iteration, and the underlying board is
## always finite. But because that same determinism means a mis-proposed action
## is re-proposed [i]and re-rejected[/i] identically with no [code]await[/code]
## on the reject path, the consecutive-reject backstop converts that would-be
## infinite freeze into a graceful defensive turn-end (see the const below).
##
## [b]Bootstrap call site (explicitly out of this story's scope, ADR-0011 §3):[/b]
## invoked by whatever observes [member GameState.active_player] becoming a
## player with [member PlayerState.is_ai_controlled] == [code]true[/code]
## after a [method GameState.start_turn] — a top-level match script's
## [signal GameState.action_applied]/[method GameState.start_turn] handler.
## That wiring is a match-bootstrap detail reconciled later, not invented here.
class_name AITurnDriver
extends Node


## Structural termination backstop (TR-ai-009): a rejected commit mutates
## nothing, so a deterministic [method AI.choose_action] re-proposes the same
## action next iteration, and the reject path has no [code]await[/code] — an
## unbounded reject-[code]continue[/code] would spin synchronously forever and
## freeze the game thread. AC-24's stale-candidate recovery needs only a single
## retry (the next clone reflects the mutation), so this bounds consecutive
## rejections and ends the turn defensively once exceeded. NOT an [AIConfig]
## balance knob — a safety invariant, kept as a [code]const[/code] so it never
## enlarges the tuning surface. Well above any legitimate reject-then-recover
## streak; correct enumeration should never approach it.
const MAX_CONSECUTIVE_REJECTS := 8


## Runs one full AI turn against [param state]: the evaluate→commit loop
## (ADR-0011 §3) followed by a real [EndTurnAction] commit. Drives the
## [b]real, authoritative[/b] [param state] directly — never a clone (the
## clone/lookahead happens once per call inside [method AI.choose_action]
## itself). Returns once the turn has fully ended (either the loop broke on
## no candidate and [EndTurnAction] was submitted, or the AI's own commit
## ended the match and this method returned immediately per AC-35).
##
## [param economy_investments_committed] is intentionally a local variable,
## reset to 0 every call — [AI] itself carries no turn-lifecycle state
## (ADR-0011 §1), and neither does this driver.
func run_ai_turn(state: GameState) -> void:
	var economy_investments := 0
	# ★ Tracked SEPARATELY from economy_investments (2026-08-26). The two answer
	# different questions — "how much economy cadence have I spent?" vs "did I just
	# build something?" — and sharing one counter is what silently disabled the
	# cancel-build anti-oscillation gate from S6-09 onward. See
	# AI._score_cancel_build_candidates for the full incident.
	var builds_committed := 0
	var consecutive_rejects := 0

	while true:
		var action: Action = AI.choose_action(state, economy_investments, builds_committed)
		if action == null:
			break

		var result: ActionResult = state.apply_action(action)
		if not result.ok:
			# Bound the reject-continue so a mis-proposed (always-rejected) action
			# cannot freeze the turn (see MAX_CONSECUTIVE_REJECTS). A rejection
			# spends no AP and makes no progress; past the bound, end defensively.
			consecutive_rejects += 1
			if consecutive_rejects >= MAX_CONSECUTIVE_REJECTS:
				push_warning("AITurnDriver: %d consecutive rejected commits (last verb=%d reason=%d) — ending AI turn defensively" \
						% [consecutive_rejects, action.verb, result.reason])
				break
			continue
		consecutive_rejects = 0

		if _is_economy_or_research(action):
			economy_investments += 1
		if action.verb == Action.Verb.BUILD:
			builds_committed += 1

		if state.match_status == GameState.MatchStatus.GAME_OVER:
			return

		# ★ `process_always = false` (2026-08-24). SceneTree timers default to
		# process_always = TRUE, i.e. they keep firing while the tree is paused — so
		# with the default the AI would go on taking its turn behind the pause
		# overlay, quietly playing a game the player thinks is frozen. `pause.md`
		# flagged freeze semantics as an open question for the architecture team;
		# this is the answer for the one place the slice actually sleeps. The pacing
		# delay is presentation, so it should honour engine pause.
		await get_tree().create_timer(AIBalance.ai.commit_pacing_sec, false).timeout

	var end_turn := EndTurnAction.new()
	end_turn.player = state.active_player
	state.apply_action(end_turn)


## True iff [param action] counts toward the cadence cap
## [method AI.choose_action] gates on (ADR-0011 §1/§6, CR-5): a
## [BuildAction] targeting [constant StructureTypes.FACTORY], or a
## research-start action ([constant Action.Verb.RESEARCH] — forward-declared;
## the Research epic is not implemented in this corpus, so this branch is
## unreachable today but kept per ADR-0011 §3's literal loop shape, ready the
## instant a research-start verb exists).
static func _is_economy_or_research(action: Action) -> bool:
	if action.verb == Action.Verb.RESEARCH:
		return true
	# ★ S6-09: no BUILD is an economy investment any more. This read
	# `structure_type == ECONOMY_OUTPOST`, which was correct while that structure WAS
	# the economy; S6-03's mechanical rename carried the test onto the FACTORY, which
	# is a production building and grants no income at all. The throttle exists to
	# stop the AI spending a whole turn on economy actions (the PIVOT failure), and
	# since S6-01 the only such action is RESEARCH.
	return false
