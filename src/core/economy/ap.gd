## AP — static utility class for the AP Economy income formula.
##
## Foundation-layer system per ADR-0006. Holds only pure/static functions that
## take a [GameState] explicitly — no instance fields of its own. Mirrors the
## verb-handler shape ADR-0002 established for Movement/Combat/Base &
## Production/Research (static, stateless, `state` passed explicitly).
##
## Story 001 implements only the income side of the contract:
## [method ap_income_breakdown] and [method income]. `current_ap`,
## `can_afford`, `spend`, `reset_turn`, and `discard` belong to Story 002/003
## and are intentionally NOT implemented here — this file is shared across all
## three AP stories and will be appended to, not re-authored.
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
