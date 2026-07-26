## AP — static utility class for the AP Economy income formula.
##
## Foundation-layer system per ADR-0006. Holds only pure/static functions that
## take a [GameState] explicitly — no instance fields of its own. Mirrors the
## verb-handler shape ADR-0002 established for Movement/Combat/Base &
## Production/Research (static, stateless, `state` passed explicitly).
##
## Story 001 implements the income side of the contract: [method
## ap_income_breakdown] and [method income]. Story 002 adds the read/spend
## side: [method current_ap], [method can_afford], and [method spend].
## Story 003 adds the turn-boundary writers: [method reset_turn] (start-of-turn
## frozen-income snapshot) and [method discard] (end-of-turn zero, no banking).
## This file is shared across all three AP stories — extended incrementally,
## never re-authored.
##
## [b]Deliberately excluded (see ADR-0006 Risks):[/b] no faction income-delta
## fold and no `BASE_INCOME_FLOOR` guard — ADR-0006 explicitly defers both to
## the Alpha faction-asymmetry prototype (ADR-0012). Under the VS Neutral
## default this is a no-op regardless, since Neutral's deltas are all 0.
##
## Usage:
## [codeblock]
## var total: int = AP.income(state, 0)
## var breakdown: Dictionary = AP.ap_income_breakdown(state, 0)
## # breakdown == { "base": 10, "outpost": 0, "econ_tech": 0 } for n=0, no tech
## [/codeblock]
class_name AP
extends RefCounted


## Returns [param player]'s AP income decomposed into its three additive terms
## — kept separate from [method income] so the HUD income readout (TR-hud-019,
## ADR-0016) can render a per-term breakdown that can never drift from the
## total (`income()` is defined as this dictionary's sum).
##
## `n` is [param player]'s completed-outpost count, floored to 0 (non-negativity
## enforced by construction — a negative count from a caller bug never drives
## income below `base_income`). `econ_tech` is added [b]verbatim[/b] — it is
## already the fully-tiered, `has_economy_tech`-guarded, capped term computed
## by [code]Research.economy_tech_income_bonus()[/code]; re-applying
## `economy_tech_tier_threshold` here would double-apply the cap (the
## 2026-07-24 /architecture-review C3 regression: bonus was 36 at n=6 instead
## of 6 when the cap was squared).
static func ap_income_breakdown(state: GameState, player: int) -> Dictionary:
	var cfg: EconomyConfig = Balance.economy
	var n: int = max(0, BaseProduction.completed_outpost_count(state, player))
	var base: int = cfg.base_income
	var outpost: int = cfg.outpost_bonus_tier1 * min(n, cfg.tier_threshold) \
		+ cfg.outpost_bonus_tier2 * max(0, n - cfg.tier_threshold)
	var econ_tech: int = Research.economy_tech_income_bonus(state, player)
	return {"base": base, "outpost": outpost, "econ_tech": econ_tech}


## Returns [param player]'s total AP income for this turn — the sum of
## [method ap_income_breakdown]'s three terms. Pure, integer-only, O(1) plus
## two O(1) forward-declared cross-system reads.
static func income(state: GameState, player: int) -> int:
	var b: Dictionary = ap_income_breakdown(state, player)
	return b["base"] + b["outpost"] + b["econ_tech"]


## Thin read facade over [param player]'s [member PlayerState.current_ap],
## mirroring [method GameState.current_ap]. O(1) — a single array index, no
## computation.
static func current_ap(state: GameState, player: int) -> int:
	return state.per_player[player].current_ap


## Pure precondition query: can [param player] currently afford [param
## amount]? Deliberately [b]ungated[/b] on active-player — unlike [method
## spend], this must stay callable for any player so the AI's per-candidate
## evaluation loop and the HUD/Command-interface affordability preview can ask
## about either player's pool without it being their turn. Never mutates
## state. O(1) — two integer comparisons.
static func can_afford(state: GameState, player: int, amount: int) -> bool:
	return amount >= 0 and amount <= state.per_player[player].current_ap


## The sole mutator of [member PlayerState.current_ap] (ADR-0006). Atomic: every
## precondition is checked before the single [code]-=[/code] write, so a
## rejected spend never partially mutates state and needs no rollback.
##
## Rejects if [param player] is not [member GameState.active_player] (Rule 7
## — only the active player's pool is mutable this way), rejects a negative
## [param amount], treats [param amount] of exactly 0 as a no-op success, and
## rejects spending more than [param player]'s current pool. Returns
## [code]true[/code] only when the deduction actually happened (or was a
## legal no-op).
##
## Called only from inside a verb handler's [code]apply()[/code] (ADR-0002
## step 5) — this function does not know or care who calls it. O(1) — a
## fixed handful of comparisons plus one subtraction.
static func spend(state: GameState, player: int, amount: int) -> bool:
	if player != state.active_player:
		return false
	if amount < 0:
		return false
	if amount == 0:
		return true
	var ps: PlayerState = state.per_player[player]
	if amount > ps.current_ap:
		return false
	ps.current_ap -= amount
	return true


## Freezes [param player]'s AP income for the whole turn (start-of-turn
## reset, ADR-0006 Rule 1/5). Evaluates [method income] exactly once and
## stores the result in [member PlayerState.income_this_turn], then sets
## [member PlayerState.current_ap] equal to it. No mid-turn recompute: once
## frozen, the snapshot is immune to same-turn increases (an outpost
## completing later this turn) and decreases (an outpost destroyed later
## this turn) alike — only the [i]next[/i] call to [method reset_turn]
## re-evaluates it.
##
## Calling this twice for the same player in the same turn with no
## intervening [method discard] is well-defined: the second call
## re-evaluates [method income] fresh and overwrites both fields
## (last-write-wins). There is no accumulation or banking across the two
## calls — both are plain field overwrites, never additive.
##
## Called only from [code]GameState.start_turn[/code]'s step 4 (ADR-0008),
## after step 3's build/research timer advance, so a just-completed Economy
## Outpost counts toward this same turn's income. This function is the
## writer only — the calling/timing contract belongs to GS Story 003; this
## story does not wire that call.
##
## O(1): two field writes plus one [method income] call (itself O(1) per
## Story 001, bounded outpost/tech term, no scan). Runs once per player per
## turn via ADR-0008 step 4 — not on any per-action or per-frame path.
##
## Usage:
## [codeblock]
## AP.reset_turn(state, 0)
## # state.per_player[0].income_this_turn == AP.income(state, 0) at call time
## # state.per_player[0].current_ap == state.per_player[0].income_this_turn
## [/codeblock]
static func reset_turn(state: GameState, player: int) -> void:
	var ps: PlayerState = state.per_player[player]
	ps.income_this_turn = income(state, player)
	ps.current_ap = ps.income_this_turn


## Discards [param player]'s unspent AP at end of turn (ADR-0006 Rule 1) — a
## hard, observable write to exactly 0, not merely "treated as irrelevant."
## No banking: whatever remained in [member PlayerState.current_ap] is gone;
## the next [method reset_turn] call starts fresh from [method income] alone,
## never `income + leftover`.
##
## Called only from [code]EndTurnAction.apply()[/code] before switching
## players (ADR-0008). This function is the writer only — the calling/timing
## contract belongs to GS Story 003; this story does not wire that call.
##
## O(1): a single field write.
##
## Usage:
## [codeblock]
## AP.discard(state, 0)
## # state.per_player[0].current_ap == 0
## [/codeblock]
static func discard(state: GameState, player: int) -> void:
	state.per_player[player].current_ap = 0
