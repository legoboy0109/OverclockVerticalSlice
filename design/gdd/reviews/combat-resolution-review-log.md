# Combat Resolution — Review Log

## Review — 2026-07-21 — Verdict: NEEDS REVISION → ACCEPTED (blocking items fixed in-file same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 4 | Recommended: 7
Summary: First independent `/design-review` of the Combat Resolution GDD (was user-approved,
pending review). All 8 sections present; dependency graph clean (Grid, Unit, AP, Game State,
Base & Production, Research all exist and reciprocate). systems-designer independently verified
the damage formula is degenerate-proof at all boundaries (min `2−1−2=-1` clamps to 1; max 7) and
re-verified the shots-to-kill matrix as arithmetically correct (retracted a suspected error).
Four blocking items — all cheap, in-file, and touching **zero spike-gated numbers**: (1)
**[systems-designer]** the defense-stacking constraint was mathematically violated by the doc's own
shipped HQ (`def 2` + `COVER_DR 1` = 3, floor-locking low-attack attackers), with an unenforced
"keep structures off Cover" mitigation — resolved by the user's chosen fix: **structures are
cover-immune** (Combat Rule 6; a structure defender never gains `cover_reduction`, so HQ mitigation
is exactly `defense 2` on any tile), synced to base-production.md + entities.yaml; (2) **[qa-lead]**
the determinism AC was ill-formed ("byte-identical"/"same state" undefined, implied nonexistent
serialization infra) — rewritten to a defined field-wise state-equality predicate over two clones +
clone-isolation split into its own AC; (3) **[qa-lead]** AC coverage gaps — added ACs for structure
cover-immunity, attacker-on-Cover (no offensive bonus), `preview_damage == actual` guarantee,
same-attack idempotency, AREA ring inclusive exact-boundary (dist 2 & 4 legal) + the
`min_range ≤ attack_range` schema invariant, and the structure-as-attacker path (Defensive Structure
via `attack()`); (4) **[game-designer, CD-elevated]** the "structures never counter" Edge Case
contradicted Rule 7 + the Defensive Structure (first `can_counterattack = true` entity) — corrected
to name the exception.
Senior adjudication (creative-director, **CD-GDD-ALIGN: CONCERNS**): the game-designer's three
BLOCKING calls partly re-litigate the settled, user-approved spike-gating posture — ruled **advisory**
per the Movement precedent (where a CD overrode exactly this "should it be in the VS" re-litigation).
Sustained the doc-honesty *portions* as advisory-high: name the Sniper no-counter fallback lever
(replace 3 cross-refs to one pre-committed decision rule), add a Player-Fantasy defense of
counters-off (the doc conflates "no RNG" with "no retaliation"; Into-the-Breach clarity relies on
enemy-intent telegraphing OVERCLOCK lacks), and acknowledge the initiative-decisive matrix cells
(Sniper-v-Sniper, Heavy-v-Sniper are 1-shot both directions). These advisories were **not applied**
(user chose the blocking-only path) and remain open for a future pass.
Specialist disagreement surfaced to user: game-designer dissents on the *risk posture itself*
(unvalidated ranged core shipping as "Designed"), not just details — overridden to advisory by
precedent, not disproof.
All 4 blocking items were applied to the GDD the same session; cross-doc sync to base-production.md
(2 Edge-Case/audit notes + HQ_DEFENSE knob) and entities.yaml (damage_formula, COVER_DR,
grid_terrain_types, HQ note) completed. User accepted the revisions to Approved without a re-review.
Prior verdict resolved: First review.

## Propagation entry — 2026-07-22 — from Command & Action Interface (#9) `/design-review`
Verdict unchanged (stays Approved). **Additive contract only.**
#9's design-review chose to fund an honest "can attack after moving here" preview (its D-3), which requires a new hypothetical-tile query on Combat. Added to combat-resolution.md: `legal_targets(unit, from_tile) -> set<target>` — a pure/side-effect-free overload evaluating targeting as if the unit stood on `from_tile`, without moving it. Added to the Public interface, the downstream-dependents note, and a sourced cross-system flag. Cost is `reachable`-sized (called once per Move-preview entry across the reachable frontier) → perf budget owed to `/create-architecture`. Optional future `preview_damage(attacker, target, from_tile)` noted, not in VS scope. No change to damage math, resolution, or any existing contract — purely additive, so no re-review required.
