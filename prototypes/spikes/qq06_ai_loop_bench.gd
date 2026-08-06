# QQ-06 performance spike — AI opponent decision-loop (ADR-0011) worst-case bench.
# THROWAWAY. Not part of the shipping game, not a GdUnit4 suite. Deleted or archived
# once ADR-0011's TR-ai-012 ms figure is recorded.
#
# Usage:
#   ./redot --headless --script prototypes/spikes/qq06_ai_loop_bench.gd
#
# Goal: produce a real wall-clock ms/pass number for one choose_action() enumeration
# pass at N<=24 units on the pinned 14x16 board, faithful to:
#   - ADR-0009's BFS-by-depth reachable() (flat PackedInt32Array visited-depth,
#     fixed N->E->S->W neighbor order, monotonic per-depth cost cutoff).
#   - ADR-0011 SS2's streaming max-scan enumeration (no candidate array materialized;
#     running-best tracked via a comparator), entity-id-ascending iteration order,
#     legal-attack-target scan over every reachable tile, cheap float scoring,
#     one GameState-clone stand-in per unit (the ADR flags clone cost explicitly).
#   - Never calls apply_action() during enumeration — pure scoring, commit is a
#     separate (unmodeled here) step.
#
# This is NOT the real AI/Movement/Combat code (none of it exists yet — this project
# is still in ADR/design phase for these systems). It is a representative worst-case
# shape built to pin a real number, per the QQ-06 task brief.

extends SceneTree

# ---- Pinned board size (ADR-0011 status block: "N<=24 units on the pinned 14x16 board") ----
const W := 14
const H := 16
const N_FRIENDLY := 24
const N_ENEMY := 8          # representative worst-case attack-target population

# ---- Representative AI/unit tunables (stand-ins for AIConfig / UnitConfig knobs) ----
const UNIT_AP := 6                # current_ap available to spend on movement this pass
const MOVE_COST := 1               # flat move cost per tile (uniform terrain, ADR-0009 scope)
const SOFT_MOVE_CAP := 4
const SOFT_MOVE_PENALTY_X10 := 20  # 2.0x fixed-point, mirrors UnitConfig
const ATTACK_RANGE := 1            # Manhattan distance gate for legal_targets_from stand-in

const HP_PER_AP := 1.5
const POSITIONAL_VALUE_PER_TILE_CLOSED := 0.16
const RETREAT_HP_FRACTION := 0.30
const RETREAT_VALUE_PER_TILE_FLED := 0.20
const LETHAL_FLOOR_BONUS := 3.5
const SCORE_TIE_EPSILON := 1e-6

const N_PASSES := 200              # repetitions of a full 24-unit choose_action() pass
const N_COMMITS_TO_SIMULATE := 5   # streaming re-enumeration: board shrinks by 1 unit/commit


# ----------------------------------------------------------------------------------
# Minimal stand-ins for GameState/UnitState — just enough fields for the enumeration
# shape to be faithful, NOT a reproduction of ADR-0001's real schema.
# ----------------------------------------------------------------------------------
class BenchUnit:
	var entity_id: int
	var pos: Vector2i
	var owner: int          # 0 = friendly (AI), 1 = enemy
	var hp: int
	var max_hp: int
	var attack: int

	func _init(id: int, p: Vector2i, own: int, h: int, mh: int, atk: int) -> void:
		entity_id = id
		pos = p
		owner = own
		hp = h
		max_hp = mh
		attack = atk


class BenchState:
	var friendlies: Array[BenchUnit] = []
	var enemies: Array[BenchUnit] = []
	# A modest typed structure sized to stand in for GameState.clone()'s per-call cost
	# (ADR-0011 SS1: "Because CR-2 states it as a Core Rule regardless" -- clone() runs
	# once per choose_action() call in the real design; this bench conservatively runs
	# an equivalent duplication once per UNIT to bias the estimate upward -- see report).
	var occupancy: Dictionary = {}   # Vector2i -> entity_id, stand-in for GridState occupancy


static func _make_occupancy(friendlies: Array[BenchUnit], enemies: Array[BenchUnit]) -> Dictionary:
	var occ := {}
	for u in friendlies:
		occ[u.pos] = u.entity_id
	for u in enemies:
		occ[u.pos] = u.entity_id
	return occ


static func _clone_state(state: BenchState) -> BenchState:
	# Stand-in for GameState.clone()/duplicate_deep(): deep-duplicate a modest typed
	# Dictionary/Array structure representative of what a real clone would copy
	# (occupancy map + unit list), per the task brief's "represent the clone-per-eval
	# cost" instruction.
	var clone := BenchState.new()
	clone.occupancy = state.occupancy.duplicate(true)
	for u in state.friendlies:
		clone.friendlies.append(BenchUnit.new(u.entity_id, u.pos, u.owner, u.hp, u.max_hp, u.attack))
	for u in state.enemies:
		clone.enemies.append(BenchUnit.new(u.entity_id, u.pos, u.owner, u.hp, u.max_hp, u.attack))
	return clone


# ----------------------------------------------------------------------------------
# ADR-0009-faithful BFS-by-depth reachable(). Flat PackedInt32Array visited-depth,
# fixed N->E->S->W neighbor order, monotonic per-depth cost, early-out once
# cost_at_depth exceeds the unit's available AP.
# ----------------------------------------------------------------------------------
static func _is_traversable(occ: Dictionary, friendly_ids: Dictionary, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	var p := Vector2i(x, y)
	if not occ.has(p):
		return true
	var occupant_id: int = occ[p]
	return friendly_ids.has(occupant_id)   # friendly units pass through; enemies block


static func _is_valid_destination(occ: Dictionary, x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	return not occ.has(p)


static func _cost_for_depth(depth: int) -> int:
	var base_tiles: int = max(0, min(depth, SOFT_MOVE_CAP))
	var overcap_tiles: int = depth - base_tiles
	var surcharge: int = (MOVE_COST * SOFT_MOVE_PENALTY_X10 + 9) / 10
	return base_tiles * MOVE_COST + overcap_tiles * surcharge


static func _neighbors_in_fixed_order(x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n := Vector2i(x + d.x, y + d.y)
		if n.x >= 0 and n.x < W and n.y >= 0 and n.y < H:
			out.append(n)
	return out


static func _reachable(occ: Dictionary, friendly_ids: Dictionary, start: Vector2i, current_ap: int) -> Array:
	var visited_depth := PackedInt32Array()
	visited_depth.resize(W * H)
	visited_depth.fill(-1)

	visited_depth[start.y * W + start.x] = 0
	var frontier: Array[Vector2i] = [start]
	var results: Array = []   # Array of [tile: Vector2i, cost: int]
	var depth := 0

	while not frontier.is_empty():
		depth += 1
		var cost_at_depth := _cost_for_depth(depth)
		if cost_at_depth > current_ap:
			break
		var next_frontier: Array[Vector2i] = []
		for pos in frontier:
			for n in _neighbors_in_fixed_order(pos.x, pos.y):
				var idx := n.y * W + n.x
				if visited_depth[idx] != -1:
					continue
				if not _is_traversable(occ, friendly_ids, n.x, n.y):
					continue
				visited_depth[idx] = depth
				next_frontier.append(n)
				if _is_valid_destination(occ, n.x, n.y):
					results.append([n, cost_at_depth])
		frontier = next_frontier

	return results


# ----------------------------------------------------------------------------------
# Combat.legal_targets_from() stand-in: scan enemies, Manhattan-distance gate.
# ----------------------------------------------------------------------------------
static func _legal_targets_from(enemies: Array[BenchUnit], tile: Vector2i) -> Array[BenchUnit]:
	var out: Array[BenchUnit] = []
	for e in enemies:
		var dist: int = abs(e.pos.x - tile.x) + abs(e.pos.y - tile.y)
		if dist <= ATTACK_RANGE:
			out.append(e)
	return out


# ----------------------------------------------------------------------------------
# Cheap float scoring stand-in, representative of AIConfig's formula shape
# (hp_per_ap-weighted lethal/damage value, positional value, retreat check).
# ----------------------------------------------------------------------------------
static func _score_move_candidate(unit: BenchUnit, dest: Vector2i, move_cost: int, nearest_enemy_dist_before: int) -> float:
	var nearest_after := 9999
	var dist_closed: int = max(0, nearest_enemy_dist_before - abs(dest.x - unit.pos.x) - abs(dest.y - unit.pos.y))
	var positional_value: float = float(dist_closed) * POSITIONAL_VALUE_PER_TILE_CLOSED
	var retreat_bonus: float = 0.0
	if float(unit.hp) / float(unit.max_hp) < RETREAT_HP_FRACTION:
		retreat_bonus = float(dist_closed) * RETREAT_VALUE_PER_TILE_FLED
	return positional_value + retreat_bonus - float(move_cost) * 0.01


static func _score_attack_candidate(unit: BenchUnit, target: BenchUnit) -> float:
	var dmg: int = min(target.hp, unit.attack)
	var value: float = float(dmg) * HP_PER_AP
	if dmg >= target.hp:
		value += LETHAL_FLOOR_BONUS
	return value


static func _is_better(score: float, ap_cost: int, entity_id: int,
		best_score: float, best_ap_cost: int, best_entity_id: int) -> bool:
	if score > best_score + SCORE_TIE_EPSILON:
		return true
	if score < best_score - SCORE_TIE_EPSILON:
		return false
	if ap_cost != best_ap_cost:
		return ap_cost < best_ap_cost
	return entity_id < best_entity_id


# ----------------------------------------------------------------------------------
# One full choose_action() enumeration pass: entity-id-ascending iteration over every
# friendly unit, per-unit clone-stand-in, reachable() + legal_targets_from() per unit,
# streaming max-scan (no candidate array materialized).
# ----------------------------------------------------------------------------------
static func _choose_action_pass(state: BenchState) -> Dictionary:
	var friendly_ids := {}
	for u in state.friendlies:
		friendly_ids[u.entity_id] = true

	# Deterministic entity-id-ascending order (ADR-0011 SS2).
	var sorted_friendlies := state.friendlies.duplicate()
	sorted_friendlies.sort_custom(func(a, b): return a.entity_id < b.entity_id)

	var best_score := -INF
	var best_ap_cost := 999999
	var best_entity_id := -1
	var best_action := {}
	var candidates_evaluated := 0

	for unit in sorted_friendlies:
		# Per-unit GameState-clone stand-in (conservative: real design clones once per
		# choose_action() call, not per-unit; this bench biases upward per task brief).
		var lookahead := _clone_state(state)

		var nearest_enemy_dist := 9999
		for e in lookahead.enemies:
			var d: int = abs(e.pos.x - unit.pos.x) + abs(e.pos.y - unit.pos.y)
			if d < nearest_enemy_dist:
				nearest_enemy_dist = d

		var reachable_tiles := _reachable(lookahead.occupancy, friendly_ids, unit.pos, UNIT_AP)

		# Zero-move case: legal_targets(state, unit) from current tile.
		for target in _legal_targets_from(lookahead.enemies, unit.pos):
			var score := _score_attack_candidate(unit, target)
			candidates_evaluated += 1
			if _is_better(score, 0, unit.entity_id, best_score, best_ap_cost, best_entity_id):
				best_score = score
				best_ap_cost = 0
				best_entity_id = unit.entity_id
				best_action = {"verb": "attack", "unit": unit.entity_id, "target": target.entity_id}

		# Move + move-and-attack combo, per reachable tile.
		for entry in reachable_tiles:
			var dest: Vector2i = entry[0]
			var cost: int = entry[1]

			var move_score := _score_move_candidate(unit, dest, cost, nearest_enemy_dist)
			candidates_evaluated += 1
			if _is_better(move_score, cost, unit.entity_id, best_score, best_ap_cost, best_entity_id):
				best_score = move_score
				best_ap_cost = cost
				best_entity_id = unit.entity_id
				best_action = {"verb": "move", "unit": unit.entity_id, "dest": dest}

			for target in _legal_targets_from(lookahead.enemies, dest):
				var atk_score := _score_attack_candidate(unit, target) + move_score * 0.1
				candidates_evaluated += 1
				if _is_better(atk_score, cost, unit.entity_id, best_score, best_ap_cost, best_entity_id):
					best_score = atk_score
					best_ap_cost = cost
					best_entity_id = unit.entity_id
					best_action = {"verb": "move_attack", "unit": unit.entity_id, "dest": dest, "target": target.entity_id}

	return {"action": best_action, "score": best_score, "candidates": candidates_evaluated}


# ----------------------------------------------------------------------------------
# Board setup: 14x16 flat grid, 24 friendlies + 8 enemies, spread to maximize
# reachable-frontier overlap (worst-case-ish, not best-case clustering).
# ----------------------------------------------------------------------------------
static func _build_worst_case_state() -> BenchState:
	var state := BenchState.new()
	var id := 0

	# Friendlies: spread across the board in a grid pattern so most units have a
	# non-trivial reachable frontier and multiple enemies within scoring range.
	var placed := 0
	for y in range(H):
		for x in range(W):
			if placed >= N_FRIENDLY:
				break
			if (x + y) % 3 == 0:   # spread pattern, avoids exact overlap with enemy placement below
				state.friendlies.append(BenchUnit.new(id, Vector2i(x, y), 0, 8, 10, 3))
				id += 1
				placed += 1
		if placed >= N_FRIENDLY:
			break

	var enemy_placed := 0
	for y in range(H):
		for x in range(W):
			if enemy_placed >= N_ENEMY:
				break
			if (x + y) % 5 == 1:
				state.enemies.append(BenchUnit.new(1000 + id, Vector2i(x, y), 1, 6, 10, 2))
				id += 1
				enemy_placed += 1
		if enemy_placed >= N_ENEMY:
			break

	state.occupancy = _make_occupancy(state.friendlies, state.enemies)
	return state


# ----------------------------------------------------------------------------------
# Bench driver.
# ----------------------------------------------------------------------------------
func _initialize() -> void:
	print("=== QQ-06 AI decision-loop performance spike (ADR-0011 / TR-ai-012) ===")
	print("Board: %dx%d, N_FRIENDLY=%d, N_ENEMY=%d, AP/unit=%d" % [W, H, N_FRIENDLY, N_ENEMY, UNIT_AP])
	print("")

	var base_state := _build_worst_case_state()
	print("Actual friendly count placed: %d, enemy count placed: %d" % [base_state.friendlies.size(), base_state.enemies.size()])

	# --- Sanity pass: confirm enumeration shape produces plausible candidate counts ---
	var sanity := _choose_action_pass(base_state)
	print("Sanity pass: candidates_evaluated=%d, best_score=%.4f, best_action=%s" % [sanity["candidates"], sanity["score"], str(sanity["action"])])
	print("")

	# --- Timed passes: N_PASSES repetitions of a full choose_action() enumeration ---
	var durations_usec: Array[int] = []
	for i in range(N_PASSES):
		var t0 := Time.get_ticks_usec()
		_choose_action_pass(base_state)
		var t1 := Time.get_ticks_usec()
		durations_usec.append(t1 - t0)

	durations_usec.sort()
	var n := durations_usec.size()
	var min_usec: int = durations_usec[0]
	var max_usec: int = durations_usec[n - 1]
	var sum_usec := 0
	for d in durations_usec:
		sum_usec += d
	var mean_usec: float = float(sum_usec) / float(n)
	var p95_idx: int = int(ceil(0.95 * n)) - 1
	p95_idx = clamp(p95_idx, 0, n - 1)
	var p95_usec: int = durations_usec[p95_idx]
	var median_usec: int = durations_usec[n / 2]

	print("=== Full choose_action() pass timing (N=%d passes, 24 units, 14x16 board) ===" % n)
	print("  min:    %.4f ms" % (min_usec / 1000.0))
	print("  mean:   %.4f ms" % (mean_usec / 1000.0))
	print("  median: %.4f ms" % (median_usec / 1000.0))
	print("  p95:    %.4f ms" % (p95_usec / 1000.0))
	print("  max:    %.4f ms" % (max_usec / 1000.0))
	print("")

	# --- Streaming multi-commit simulation: board shrinks by 1 friendly per commit ---
	print("=== Streaming re-enumeration across %d commits (unit removed after each) ===" % N_COMMITS_TO_SIMULATE)
	var shrink_state := _build_worst_case_state()
	var commit_durations_usec: Array[int] = []
	for c in range(N_COMMITS_TO_SIMULATE):
		if shrink_state.friendlies.is_empty():
			break
		var t0 := Time.get_ticks_usec()
		_choose_action_pass(shrink_state)
		var t1 := Time.get_ticks_usec()
		var dur := t1 - t0
		commit_durations_usec.append(dur)
		print("  commit %d: %d friendlies remaining -> %.4f ms" % [c + 1, shrink_state.friendlies.size(), dur / 1000.0])
		shrink_state.friendlies.pop_back()   # simulate commit consuming/removing a unit's turn
		shrink_state.occupancy = _make_occupancy(shrink_state.friendlies, shrink_state.enemies)

	var total_commit_usec := 0
	for d in commit_durations_usec:
		total_commit_usec += d
	print("  total across %d commits: %.4f ms" % [commit_durations_usec.size(), total_commit_usec / 1000.0])
	print("")

	print("=== Done ===")
	quit()
