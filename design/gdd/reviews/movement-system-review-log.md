# Movement System — Review Log

## Review — 2026-07-21 — Verdict: APPROVED (blocking items fixed in-file same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (senior synthesis)
Blocking items: 3 | Recommended: 8
Summary: Confirming re-review of the soft-cap surcharge revision. **Formula core independently
re-derived as sound** — systems-designer verified the reachable/Dijkstra correctness and the
reachable⇔billed agreement invariant from scratch (min-length ≡ min-cost licenses depth-only keying;
no degenerate boundary outputs; the invariant is actually *stronger* than "same tile sequence" — holds
for any equal-length path). qa-lead recomputed all 15 ACs by hand: all correct, 2026-07-20 fixes
landed cleanly. Three blocking gaps, all cheap/additive/in-file: (1) no AC pinned tie-break **path**
determinism (Rule 8) — added; (2) no AC for **board-change/no-stale-cache** recomputation — added;
(3) missing **`move_cost ≥ 1` monotonicity precondition** the BFS shortcut silently depends on —
added. Senior reviewer **overrode the game-designer's two BLOCKING calls to advisory**: the "does the
soft cap belong in VS" concern re-litigates a settled user decision (keep the mechanic, numbers
spike-gated), and the kiting non-solution is genuinely cross-system — both resolved to doc-honesty
notes (softened Player-Fantasy claim, explicit no-positional-deterrence decision, **named kiting
fallback owner+lever** replacing the bare TBD: Movement owns partial-ZoC, Combat owns move-then-attack
cost, game-designer picks from spike data). Also folded in: split enemy-vs-friendly-structure blocker
AC, impl-note precision (real `AStarGrid2D` constraint is `_compute_cost`'s missing depth param, not
"static weights"; softened the float-overcharge framing to its narrow boundary case), and flagged that
Grid's `neighbors()`/`is_passable()`/`occupant_at()` signatures aren't pinned in-repo yet (blocking for
*implementation*, not this doc). No formula-math or tuning change; numbers remain spike-gated to the
ranged-combat spike. Promoted to Approved per the senior call — no further re-review required.
Prior verdict resolved: Yes — supersedes the 2026-07-20 NEEDS REVISION (its 4 items verified still fixed).

## Review — 2026-07-20 — Verdict: NEEDS REVISION (blocking items addressed same session)
Scope signal: M
Specialists: systems-designer, game-designer, qa-lead, godot-specialist, creative-director (senior synthesis)
Blocking items: 4 | Recommended: ~8 advisories
Summary: Re-review of the 2026-07-20 soft-cap surcharge revision (`move_path_cost` + depth-dependent
`reachable`). The **formula core is proven sound** — anti-chunking algebraically airtight, no
degenerate outputs across all boundary inputs, Dijkstra/BFS correct under current uniform terrain.
But the **AC section was not updated to match the formula**: AC #1 asserted the pre-revision 5-tile
Scout reach, directly contradicting the doc's own 4-tile worked example (a spec that fails its own
test). Four blocking items: (1) reconcile the AC section to the formula — fix AC #1, disambiguate the
Trooper fresh-vs-sequential AC, add concrete numeric expected values to the over-cap/ceil/anti-chunking
ACs (and force the anti-chunking split to cross the cap), add the past-cap empty-reachable-set
boundary AC; (2) add the `reachable`⇔billed **agreement invariant** to the doc body + an AC (flagged
independently by systems-designer and qa-lead); (3) owe an ADR/implementation note — hand-rolled
search (built-in AStarGrid2D can't do depth-dependent cost), BFS length-shortcut valid only under
uniform terrain, fixed-point `PENALTY_X10` over a float penalty to kill a latent `ceil` 1-AP
overcharge; (4) elevate the Pillar-3 cheap-zone-shrink from a UX watch-item to a hard overlay
requirement (cumulative counter makes the same unit's reachable set change between selections).
Senior adjudication of the game-designer dissent (surcharge is "phantom-problem/wrong-target,
demote to provisional"): **keep the mechanic** — it is a deliberate user decision and its risky
numbers are already spike-gated — **and fix the execution**; the Heavy `cap 2 → 3 tiles = 12 AP`
mobility concern is a real tuning item routed to the ranged-combat spike, not a blocker.
**All 4 blocking items were applied to the GDD the same session** (AC rewrite, agreement invariant,
implementation note, overlay requirement). Open for the user: keep-vs-neuter `SOFT_MOVE_PENALTY`
(design-direction, theirs to settle), and whether to confirm with a re-review or accept to Approved.
Also surfaced (non-Movement): `CLAUDE.md` points to `docs/engine-reference/redot/VERSION.md` but only
`docs/engine-reference/godot/` exists — stale path, flag to technical-director.
Prior verdict resolved: Yes — the 2026-07-19 APPROVED predates the soft-cap revision; this re-review
covers the new formula and supersedes it pending confirm/accept.

## Review — 2026-07-19 — Verdict: APPROVED
Scope signal: M
Specialists: none (lean mode — single-session analysis)
Blocking items: 0 | Recommended: 2
Summary: Tight, implementable spec. All 8 sections present; upstream deps (Grid, Unit, AP, Game State) all exist and acknowledge Movement bidirectionally; `move_cost` values match the entity registry. Prototype's #1 fix (friendly pass-through) is directly and testably specified; determinism called out for AI/headless tests; ZoC/overwatch/difficult-terrain correctly punted to Alpha. Two advisory revisions applied on approval: (1) renamed section 3 "Detailed Design" → "Detailed Rules" for heading-standard compliance; (2) added a ranged-kiting interaction note to Open Questions (Movement is half of what enables the cross-cutting, unvalidated kiting risk).
Prior verdict resolved: First review

## Propagation entry — 2026-07-22 — from Command & Action Interface (#9) `/design-review`
Verdict unchanged (stays Approved). **Additive contract only.**
#9's design-review closed the long-standing in-cap/over-cap question (Movement OQ + #9 OQ-2) by making the split an explicit contract rather than a UI inference. Added to movement-system.md: `reachable()` return is now `{tile, min_cost, is_surcharged}` (was `{tile, min_cost}`) — `is_surcharged` true when a tile's `min_cost` includes ≥1 over-cap surcharge step. Updated the Public interface, the `reachable()` Output spec, and the Command-&-Action-Interface/HUD downstream row, plus a sourced cross-system flag. The flag is computed by the same Dijkstra pass that already produces `min_cost` (it knows per-depth whether a step crossed `soft_move_cap`), so no new traversal and no formula change — purely additive, no re-review required. Final field name/shape reconciled at `/create-architecture`.
