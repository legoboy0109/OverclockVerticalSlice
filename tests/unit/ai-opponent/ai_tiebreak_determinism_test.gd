# Story 005: Deterministic Tie-Break Comparator + Cross-Verb action_score
# comparison (`AI._is_better`) — Logic.
#
# Covers production/epics/ai-opponent/story-005-tiebreak-comparator.md QA Cases:
#   AC-1  : the exact three-tier comparator (score epsilon → ap_cost → entity_id).
#   AC-4  : highest action_score wins regardless of verb — no verb-priority bias
#           (the comparator takes no verb argument, so this is proven by
#           construction + a concrete produce-beats-attack case).
#   AC-23 : within-epsilon tie → lower ap_cost; further ap_cost tie → lower entity_id
#           (incl. two lethal attacks both floored to LETHAL_FLOOR_BONUS).
#   AC-18 : the five-candidate cross-verb scenario resolves in exact descending
#           score order (lethal 3.50 → Outpost 1.765 → Production 1.10 →
#           non-lethal 1.00 → Attack Tech 0.236) regardless of input fold order.
#   Determinism: replaying an identical tie selects the same candidate (pure,
#           no RNG — ADR-0003 Rule 4).
#   Edge  : two scores differing by EXACTLY score_tie_epsilon land on the TIE
#           side of the strict `>` (documented boundary).
#
# AI._is_better is a pure static comparator, so these are direct scalar calls —
# no GameState/scene fixtures needed. Deterministic every run.
extends GdUnitTestSuite


# A candidate as [score, ap_cost, entity_id], used for the AC-18 fold.
func _is_better_c(cand: Array, best: Array) -> bool:
	return AI._is_better(cand[0], cand[1], cand[2], best[0], best[1], best[2])


# Running-best fold over candidates (mirrors how every _score_* helper folds),
# returning the single winning candidate. Input order is caller-controlled so
# tests can prove order-independence.
func _select_best(candidates: Array) -> Array:
	var best: Array = candidates[0]
	for i: int in range(1, candidates.size()):
		if _is_better_c(candidates[i], best):
			best = candidates[i]
	return best


# AC-4 / AC-1: a strictly higher score wins even with a WORSE ap_cost and a
# WORSE entity_id — score dominates, and the comparator is verb-agnostic (it has
# no verb parameter at all).
func test_strictly_higher_score_wins_despite_worse_ap_cost_and_entity_id() -> void:
	assert_bool(AI._is_better(2.00, 9, 99, 1.00, 1, 1)).is_true()


# AC-1: a strictly lower score loses regardless of a better ap_cost/entity_id.
func test_strictly_lower_score_loses_despite_better_ap_cost_and_entity_id() -> void:
	assert_bool(AI._is_better(1.00, 1, 1, 2.00, 9, 99)).is_false()


# AC-4 concrete: a produce candidate (2.00) beats an attack candidate (1.00) —
# no fixed verb-priority order, purely score-driven.
func test_produce_score_beats_lower_attack_score_no_verb_priority() -> void:
	var attack: Array = [1.00, 2, 4]   # attack candidate
	var produce: Array = [2.00, 4, 7]  # produce candidate
	assert_array(_select_best([attack, produce])).is_equal(produce)
	# ...and order-independent:
	assert_array(_select_best([produce, attack])).is_equal(produce)


# AC-23 (ap_cost): two candidates tied on score (both lethal, floored to 3.50)
# break toward the LOWER ap_cost.
func test_tied_score_breaks_toward_lower_ap_cost() -> void:
	assert_bool(AI._is_better(3.50, 2, 5, 3.50, 3, 5)).is_true()
	assert_bool(AI._is_better(3.50, 3, 5, 3.50, 2, 5)).is_false()


# AC-23 (entity_id): tied on score AND ap_cost breaks toward the LOWER (oldest)
# entity_id — intentional per GDD Edge Cases / ADR-0003 Rule 4.
func test_tied_score_and_ap_cost_breaks_toward_lower_entity_id() -> void:
	assert_bool(AI._is_better(3.50, 2, 3, 3.50, 2, 7)).is_true()
	assert_bool(AI._is_better(3.50, 2, 7, 3.50, 2, 3)).is_false()


# A candidate is never "better" than an identical one (score==, ap_cost==,
# entity_id==) — the running-best keeps the incumbent, so the FIRST-enumerated
# of an exact triple-tie wins (entity-id-ascending enumeration ⇒ oldest).
func test_identical_candidate_is_not_strictly_better_than_incumbent() -> void:
	assert_bool(AI._is_better(3.50, 2, 5, 3.50, 2, 5)).is_false()


# Edge (boundary): a score exactly score_tie_epsilon ABOVE best is NOT strictly
# better (the `>` is strict) — it falls through to the TIE branch and is
# resolved by ap_cost. Proven by the pair below: with +epsilon, the LOWER
# ap_cost wins (tie behavior), not the epsilon-higher score.
func test_exactly_one_epsilon_higher_is_treated_as_a_tie_not_strictly_better() -> void:
	var eps: float = AIBalance.ai.score_tie_epsilon
	var base: float = 1.00
	# +epsilon score but WORSE ap_cost → loses (would WIN if +eps counted as strictly better).
	assert_bool(AI._is_better(base + eps, 3, 5, base, 2, 5)).is_false()
	# +epsilon score and BETTER ap_cost → wins (via the tie branch, not the score branch).
	assert_bool(AI._is_better(base + eps, 2, 5, base, 3, 5)).is_true()


# Edge (boundary, other side): a score clearly MORE than one epsilon above best
# is strictly better and wins regardless of ap_cost — confirms the boundary sits
# exactly at epsilon.
func test_more_than_one_epsilon_higher_is_strictly_better() -> void:
	var eps: float = AIBalance.ai.score_tie_epsilon
	var base: float = 1.00
	assert_bool(AI._is_better(base + eps * 4.0, 9, 99, base, 1, 1)).is_true()


# AC-18: the five-candidate cross-verb scenario. Folded from a SCRAMBLED input
# order, the winner is the lethal 3.50; extracting best repeatedly yields the
# exact descending order lethal → Outpost → Production → non-lethal → Attack Tech.
func test_five_candidate_cross_verb_scenario_resolves_in_exact_descending_order() -> void:
	var lethal: Array = [3.50, 2, 10]        # lethal attack (floored)
	var outpost: Array = [1.765, 4, 11]      # economy outpost
	var production: Array = [1.10, 4, 12]    # unit production
	var non_lethal: Array = [1.00, 2, 13]    # non-lethal attack
	var attack_tech: Array = [0.236, 10, 14] # attack tech research

	# Deliberately scrambled input order — the fold must be order-independent.
	var scrambled: Array = [production, attack_tech, lethal, non_lethal, outpost]
	assert_array(_select_best(scrambled)).is_equal(lethal)

	# Successive extraction (remove the winner, re-select) yields exact descending order.
	var remaining: Array = scrambled.duplicate()
	var order: Array = []
	while remaining.size() > 0:
		var best: Array = _select_best(remaining)
		order.append(best)
		remaining.erase(best)
	assert_array(order).is_equal([lethal, outpost, production, non_lethal, attack_tech])


# Determinism (ADR-0003 Rule 4): replaying an identical tie scenario selects the
# same candidate every time — the comparator is a pure function, no RNG.
func test_identical_tie_scenario_selects_same_candidate_on_replay() -> void:
	var a: Array = [3.50, 2, 8]
	var b: Array = [3.50, 2, 3]  # same score+cost, lower id → should always win
	var first: Array = _select_best([a, b])
	var second: Array = _select_best([a, b])
	assert_array(first).is_equal(b)
	assert_array(second).is_equal(b)
	assert_array(first).is_equal(second)
