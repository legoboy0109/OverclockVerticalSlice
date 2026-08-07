## AP — static utility class for the tactical Action-Point pool.
##
## Foundation-layer system per ADR-0006. Holds only pure/static functions that
## take a [GameState] explicitly — no instance fields of its own. Mirrors the
## verb-handler shape ADR-0002 established for Movement/Combat/Base &
## Production/Research (static, stateless, `state` passed explicitly).
##
## [b]The tactical half of the two-pool economy (2026-08-05 AP<->Credits pivot).[/b]
## AP is a flat per-turn budget spent on moving and attacking, plus a small AP
## surcharge on each economic action. Unspent AP carries into the next turn up to
## [code]EconomyConfig.ap_carryover_cap[/code] — it is [b]not[/b] discarded, and it
## is [b]not[/b] income-driven (contrast the [Credits] economic pool, which is
## banked and funded by the diminishing-outpost income curve moved there from this
## module by the pivot).
##
## Surface: [method current_ap]/[method can_afford]/[method spend] (read/spend) and
## [method reset_turn] (start-of-turn flat + capped carryover). The pre-pivot
## [code]income[/code]/[code]ap_income_breakdown[/code] moved to [Credits]
## ([code]credit_income[/code]/[code]credit_income_breakdown[/code]);
## [code]discard[/code] was deleted (AP carries); the cancel-refund
## [code]credit[/code] moved to [code]Credits.credit[/code] (refunds are Credits).
##
## Usage:
## [codeblock]
## AP.reset_turn(state, 0)              # current_ap := flat + min(leftover, cap)
## var ok: bool = AP.spend(state, 0, 2) # spend 2 AP (e.g. an attack)
## [/codeblock]
class_name AP
extends RefCounted


## Thin read facade over [param player]'s [member PlayerState.current_ap],
## mirroring [method GameState.current_ap]. O(1) — a single array index, no
## computation.
static func current_ap(state: GameState, player: int) -> int:
	return state.per_player[player].current_ap


## Pure precondition query: can [param player] currently afford [param amount] AP?
## Deliberately [b]ungated[/b] on active-player — unlike [method spend], this must
## stay callable for any player so the AI's per-candidate evaluation loop and the
## HUD/Command-interface affordability preview can ask about either player's pool
## without it being their turn. Never mutates state. O(1) — two integer comparisons.
static func can_afford(state: GameState, player: int, amount: int) -> bool:
	return amount >= 0 and amount <= state.per_player[player].current_ap


## The sole spend-mutator of [member PlayerState.current_ap] (ADR-0006). Atomic:
## every precondition is checked before the single [code]-=[/code] write, so a
## rejected spend never partially mutates state and needs no rollback.
##
## Rejects if [param player] is not [member GameState.active_player] (only the
## active player's pool is mutable this way), rejects a negative [param amount],
## treats [param amount] of exactly 0 as a no-op success, and rejects spending
## more than [param player]'s current pool. Returns [code]true[/code] only when
## the deduction actually happened (or was a legal no-op).
##
## Called only from inside a verb handler's [code]apply()[/code] (ADR-0002 step 5)
## — for Move/Attack it is the sole cost; for an economic action it is the AP
## surcharge leg of the dual-cost spend (alongside [method Credits.spend]). O(1) —
## a fixed handful of comparisons plus one subtraction.
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


## Resets [param player]'s AP at start-of-turn to a flat budget plus capped
## carryover (ADR-0006 Rule 1/2, the pivot). Reads the leftover unspent AP still
## sitting in [member PlayerState.current_ap] (AP is never discarded at end of
## turn) and overwrites it with
## [code]flat_ap_per_turn + min(leftover, ap_carryover_cap)[/code]. Any leftover
## beyond the cap is lost, so start-of-turn AP is bounded by
## [code]flat_ap_per_turn + ap_carryover_cap[/code] (15 at defaults).
##
## Not income-driven: unlike the pre-pivot income snapshot this replaced, the
## value does not depend on the economy. Credit income is banked separately by
## [method Credits.add_income] (start-of-turn step 4b).
##
## Called only from [code]GameState.start_turn[/code]'s step 4a (ADR-0008). O(1):
## one config read plus one field write. Runs once per player per turn — not on
## any per-action or per-frame path.
##
## Usage:
## [codeblock]
## # current_ap held 3 unspent at end of last turn; cap 5, flat 10:
## AP.reset_turn(state, 0)              # current_ap == 10 + min(3, 5) == 13
## [/codeblock]
static func reset_turn(state: GameState, player: int) -> void:
	var cfg: EconomyConfig = Balance.economy
	var ps: PlayerState = state.per_player[player]
	var leftover: int = ps.current_ap
	ps.current_ap = cfg.flat_ap_per_turn + min(leftover, cfg.ap_carryover_cap)
