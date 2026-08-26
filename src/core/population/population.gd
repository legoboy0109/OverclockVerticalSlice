## Population — the infantry cap that bounds how many units may be on the board.
##
## Static utility class. The companion to [Upkeep], and the two must be read together:
## [b]the cap says how many units you may FIELD; upkeep says how long you can AFFORD
## them[/b] (`population-cap.md`, user decision 2026-08-24). Tuned as a pair — a cap set
## below the upkeep equilibrium makes upkeep inert, and one far above it is decorative.
##
## [b]Why a cap exists at all, beyond upkeep:[/b]
## [br]• It bounds the BOARD, not the wallet. Without it a rich player floods a 12x10 map
##   and the game becomes a stacking problem rather than a positional one.
## [br]• It makes unit QUALITY meaningful. With unlimited bodies, one strong expensive unit
##   is never worth more than several cheap ones.
## [br]• It is a primary faction-identity lever (three of the six factions define
##   themselves partly through it).
##
## Reads [code]StructureBalance.base_production[/code] for its constants.
class_name Population
extends RefCounted


## [param player]'s current infantry ceiling: the faction base, plus
## [member StructureTypeDef.cap_bonus] from every completed, living structure they own,
## clamped to [member BaseProductionConfig.cap_hard_ceiling].
##
## [b]Only COMPLETED structures grant cap.[/b] A Barracks under construction grants
## nothing — consistent with it paying no upkeep until completed ([Upkeep]), and with
## `build_time` being a deliberate vulnerable-investment window.
##
## [b]The cap therefore FALLS when a Barracks dies[/b] (PC-6). Units above the new ceiling
## are deliberately [b]not[/b] destroyed — the owner is simply production-locked until
## attrition brings them under. Losing a building must not kill soldiers.
static func effective_cap(state: GameState, player: int) -> int:
	var cfg: BaseProductionConfig = StructureBalance.base_production
	var total: int = cfg.base_infantry_cap
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var st: StructureState = e as StructureState
		if st.type == null or st.build_status != StructureState.BuildStatus.COMPLETED:
			continue
		total += st.type.cap_bonus
	return clampi(total, 0, cfg.cap_hard_ceiling)


## How many cap slots [param player] is currently using — every living unit they own
## whose type sets [member UnitTypeDef.counts_toward_cap].
##
## [b]`population-cap.md` PC-3 — "units under production count against the cap" — is
## implemented here as of S8-28.[/b] Production became multi-turn, so a producer can hold
## a paid-for unit that is not yet on the board, and this counts it.
##
## ★ This comment previously said PC-3 "needs no machinery here" because production was
## instant, and named this function as where the work would land if that ever changed.
## It changed, and this is that work — the note was right, and worth having written.
static func current_population(state: GameState, player: int) -> int:
	var count: int = 0
	for e: EntityState in state.entities():
		if e.owner != player or not (e is UnitState):
			continue
		var u: UnitState = e as UnitState
		# A null type is invalid state, not a chargeable slot — same reasoning as
		# Upkeep.total_upkeep, which iterates this identical entity list.
		if u.type == null or not u.type.counts_toward_cap:
			continue
		count += 1
	# ★ PC-3 (S8-28): a unit IN PRODUCTION occupies its slot from the moment production
	# is committed. Its costs are already spent, so without this a player could queue
	# past the cap and the check would do nothing — which is exactly the rationale
	# population-cap.md gives for the rule.
	for e: EntityState in state.entities():
		if e.owner != player or not (e is StructureState):
			continue
		var st: StructureState = e as StructureState
		if st.producing_type == null or not st.producing_type.counts_toward_cap:
			continue
		count += 1
	return count


## Whether [param player] may add one more [param unit_type] without exceeding their cap.
## Cap-exempt types are always allowed (PC-4).
static func can_field(state: GameState, player: int, unit_type: UnitTypeDef) -> bool:
	if unit_type == null or not unit_type.counts_toward_cap:
		return true
	return current_population(state, player) + 1 <= effective_cap(state, player)
