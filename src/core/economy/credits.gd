## Credits — static utility class for the Credits economic pool + income formula.
##
## Foundation-layer system per ADR-0006 (the 2026-08-05 AP<->Credits pivot). The
## economic half of the two-pool economy: a banked war chest that accumulates
## across turns, funded by a finite research-tier income curve (re-based
## 2026-08-24 off the deleted Economy Outpost — see [method credit_income_breakdown]). Holds only pure/static
## functions that take a [GameState] explicitly — a line-for-line mirror of the
## [AP] tactical pool's afford/spend/read surface, plus the income formula it
## owns (moved here from [AP] by the pivot).
##
## Reads [code]Balance.economy[/code] ([EconomyConfig]) for the income-curve
## constants — never threaded through call sites as a parameter.
##
## [b]Deliberately excluded (see ADR-0006 Risks):[/b] no faction income-delta
## fold and no [code]BASE_INCOME_FLOOR[/code] guard — deferred to the Alpha
## faction-asymmetry prototype (ADR-0012); a no-op under the VS Neutral default.
##
## Usage:
## [codeblock]
## var total: int = Credits.credit_income(state, 0)
## Credits.add_income(state, 0)         # banks that income into current_credits
## var ok: bool = Credits.spend(state, 0, 4)
## [/codeblock]
class_name Credits
extends RefCounted


## Returns [param player]'s Credit income decomposed into its two additive terms —
## kept separate from [method credit_income] so the HUD income readout renders a
## per-term breakdown that can never drift from the total.
##
## [b]★ RE-BASED 2026-08-24 (S6-01).[/b] This returned
## [code]{base, outpost, econ_tech}[/code] and read a diminishing per-outpost curve.
## The Economy Outpost is [b]deleted[/b]; income now comes from completed economy
## research tiers only. The `outpost` and `econ_tech` keys are [b]removed, not
## zeroed[/b] — a phantom key would let the HUD render a line for a mechanic that
## no longer exists.
##
## [b]Why the shape changed at all:[/b] the vertical slice returned a PIVOT verdict —
## Credits were unbounded (peak 5,724, still climbing linearly at turn 200), so
## economy actions always outscored manoeuvring and no match ever resolved. The old
## curve tiered *down* but never *stopped*. A finite tier count is a hard ceiling,
## and it is the rate-bounding half of the fix (upkeep bounds the stock).
##
## [param player]'s tier is clamped into [code][0, max_economy_tier][/code]: income
## must never keep growing past the ceiling, and a negative tier must never subtract.
static func credit_income_breakdown(state: GameState, player: int) -> Dictionary:
	var cfg: EconomyConfig = Balance.economy
	var tier: int = clampi(state.per_player[player].economy_tier, 0, cfg.max_economy_tier)
	return {"base": cfg.base_income, "tiers": cfg.econ_tier_bonus * tier}


## Returns [param player]'s total Credit income for this turn — the sum of
## [method credit_income_breakdown]'s two terms. Pure, integer-only, O(1) with no
## cross-system reads at all (the old formula needed Base & Production's outpost
## count and Research's tech term; it now needs neither).
##
## [b]Range: 1000 .. 2500.[/b] That upper bound is a hard ceiling reached by
## researching every economy tier, and nothing in the game can raise it further.
static func credit_income(state: GameState, player: int) -> int:
	var b: Dictionary = credit_income_breakdown(state, player)
	return b["base"] + b["tiers"]


## Banks [param player]'s Credit income at start-of-turn (ADR-0006 Rule 6) —
## [b]adds[/b] [method credit_income] to the running [member PlayerState.current_credits]
## balance, never a reset-to-snapshot. Credits accumulate with no cap and no
## discard (contrast [method AP.reset_turn], which overwrites the flat AP pool).
##
## Called only from [code]GameState.start_turn[/code]'s step 4b (ADR-0008),
## after step 3's build/research timer advance, so a just-completed economy
## research tier counts toward this same turn's income. O(1) plus the O(1)
## [method credit_income] read. Runs once per player per turn — not on any
## per-action or per-frame path.
static func add_income(state: GameState, player: int) -> void:
	state.per_player[player].current_credits += credit_income(state, player)


## Thin read facade over [param player]'s [member PlayerState.current_credits],
## mirroring [method AP.current_ap]. O(1) — a single array index, no computation.
static func current_credits(state: GameState, player: int) -> int:
	return state.per_player[player].current_credits


## Pure precondition query: can [param player] afford [param amount] Credits?
## Mirror of [method AP.can_afford] — deliberately [b]ungated[/b] on active-player
## so the AI's per-candidate evaluation loop and the HUD/Command affordability
## preview can ask about either player's pool without it being their turn. Never
## mutates state. O(1) — two integer comparisons.
static func can_afford(state: GameState, player: int, amount: int) -> bool:
	return amount >= 0 and amount <= state.per_player[player].current_credits


## The sole spend-mutator of [member PlayerState.current_credits] (ADR-0006) — a
## mirror of [method AP.spend]. Atomic: every precondition is checked before the
## single [code]-=[/code] write, so a rejected spend never partially mutates state
## and needs no rollback.
##
## Rejects if [param player] is not [member GameState.active_player], rejects a
## negative [param amount], treats [param amount] of exactly 0 as a no-op success,
## and rejects spending more than the current pool. Called only from inside an
## economic verb handler's [code]apply()[/code] (the Credit leg of the dual-cost
## spend, alongside [method AP.spend] for the AP surcharge). O(1).
static func spend(state: GameState, player: int, amount: int) -> bool:
	if player != state.active_player:
		return false
	if amount < 0:
		return false
	if amount == 0:
		return true
	var ps: PlayerState = state.per_player[player]
	if amount > ps.current_credits:
		return false
	ps.current_credits -= amount
	return true


## Credits [param amount] Credits back to [param player]'s pool — the additive
## counterpart to [method spend], for the cancel-build refund (ADR-0017 D5).
## Moved from the pre-pivot [code]AP.credit[/code] by the pivot: cancelling an
## under-construction build refunds a fraction of its cost in [b]Credits[/b] (the
## pool the build was paid from), never AP. Keeps every
## [member PlayerState.current_credits] write inside this Credits module
## (control-manifest: a verb handler must never write the field directly).
##
## Gated to [param player] == [member GameState.active_player] (a cancel is a
## voluntary same-turn action by the structure's owner, who is the active player).
## Rejects a negative [param amount]; treats an [param amount] of exactly 0 as a
## no-op success (a 0-cost structure refunds nothing but the cancel still
## succeeds). There is no upper cap — a refund can legitimately raise the banked
## balance. Called only from inside [code]BaseProduction.apply_cancel[/code]
## (ADR-0002 step 5). O(1) — a fixed handful of comparisons plus one addition.
static func credit(state: GameState, player: int, amount: int) -> bool:
	if player != state.active_player:
		return false
	if amount < 0:
		return false
	if amount == 0:
		return true
	state.per_player[player].current_credits += amount
	return true
