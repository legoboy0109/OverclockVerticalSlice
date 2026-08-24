# Change Impact Report — AP Economy → AP & Credits Economy (two-budget pivot)

- **GDD driving the change:** `design/gdd/ap-economy.md` (retitled "AP & Credits Economy")
- **Date:** 2026-08-05
- **Phase-1 GDD pivot committed:** `ed11e7c` (9 docs; not merged to main)
- **Review mode:** lean (TD-CHANGE-IMPACT director gate skipped)
- **Analysis:** main session (ADR-0006/0008 read directly) + general-purpose subagent (other 13 ADRs)

---

## Change Summary

The single **Action Points (AP)** pool was split into **two resources**:

- **AP** — a flat *tactical* budget (`FLAT_AP_PER_TURN` 10), unspent AP **carries over capped**
  (`AP_CARRYOVER_CAP` 5 → max 15), **no longer discarded**. Spends: move (1/2/3), attack (2), plus a
  small **AP surcharge** on each economic action (`PRODUCE_AP_COST` 1, `BUILD_AP_COST` 2,
  `RESEARCH_AP_COST` base 1 with per-tech `TechDef.ap_surcharge` override).
- **Credits** — a *banked economic* pool. `credit_income` = the old `ap_income` curve verbatim
  (base 10 + tiered outpost bonus + econ-tech), **added** each turn (no cap, no discard). Credits are the
  **main cost** of produce/build/research (the old AP cost numbers, re-denominated). Cancel refund = 50%
  **Credits**.
- **Dual-cost:** economic actions cost Credits **and** an AP surcharge, spent **both-or-neither**
  (legal iff both `can_afford`; enforced by ADR-0002 validate-before-mutate).
- **AI:** new knob **`CREDIT_TO_AP_RATE`** (1.0) converts Credit costs/values to AP-equivalent for
  value-per-cost scoring; affordability now gates on both pools.

**Key changes affecting architecture:**
1. `PlayerState` gains a `current_credits: int` field; `current_ap` no longer "turn-reset" (carries).
2. The income formula moves from `AP.income()` to `Credits.credit_income()` (same math → Credits).
3. `AP.discard()` is deleted; start-of-turn splits into AP flat+carry reset **+** Credit income add.
4. Economic verb handlers become dual-cost (Credits main + AP surcharge, both-or-neither).
5. HUD gains a second (Credits) counter; income breakdown re-denominates to Credits.
6. AI scoring gains `CREDIT_TO_AP_RATE` and a dual-pool affordability gate.

Unchanged: Movement and Combat (AP-only, untouched); the static-utility module shape; determinism/
integer invariants; the `Balance` autoload + `EconomyConfig`-as-`.tres` pattern; the forward-declared
`completed_outpost_count`/`economy_tech_income_bonus` contracts.

---

## Impact Analysis — 18 ADRs

**10 need changes · 5 Still Valid · 3 not economy-coupled (0004/0005/0013).** Ranked most-affected first.

### Revised in place — this pass ✅

#### ADR-0006 — AP economy data model & spend contract → **AP & Credits Economy Data Model & Spend Contract**
- **Assumed:** one `AP` pool; `income()` snapshot → `current_ap`; Rule 1 "end-of-turn discard (no
  banking)"; Rule 7 `0 ≤ current_ap ≤ income_this_turn`; unified `can_afford`/`spend`; 5-field `EconomyConfig`.
- **Resolution:** **Revised in place** (per user decision 2026-08-05). Two mirrored static classes `AP`
  (flat+carry, `discard()` deleted) + `Credits` (banked, owns `credit_income` moved from `AP.income`);
  `EconomyConfig` grows to 10 fields (AP budget + 3 surcharges); dual-cost contract added (validate both,
  spend both, safe under ADR-0002). Done in this report's pass.

### Update in place — next pass (against the approved anchor)

#### ADR-0002 — apply-action command model — 🔴 was: Likely Superseded → Update in place
- **Assumed:** "illegal action → zero state change, including AP"; step 5 "spends AP via `AP.spend()`";
  `EndTurnAction` "discard unspent AP".
- **Assessment:** the validate-before-mutate atomicity *pattern* survives and is in fact what makes
  dual-cost safe. But: (a) economic verbs need a **dual** affordability gate; (b) the single `AP.spend()`
  becomes a paired Credits+AP spend; (c) `EndTurnAction`'s "discard unspent AP" contradicts AP carryover.
- **Action:** revise Requirements ("enough AP" → "enough AP *and* Credits"); pipeline step-5 note + the
  handler invariant for the dual spend; delete the `EndTurnAction` AP-discard; add/generalize a
  `CANT_AFFORD_CREDITS` `Reason`; atomicity ACs for the both-or-neither cases.

#### ADR-0016 — Game HUD — 🔴 was: Likely Superseded → Update in place (large)
- **Assumed:** single AP counter + its animation FSM; `income_breakdown → {base,outpost,econ_tech}`;
  AP tick `N = old−new`; `ap_income_breakdown` forward-declared from AP Economy.
- **Assessment:** needs a **dual counter** (AP + Credits). `income_breakdown` re-denominates to Credits
  (`Credits.credit_income_breakdown`); Build/Produce/Research affordability is dual-cost; the AP-tick FSM
  assumed discard-per-turn (AP now carries; Credits bank) so tick semantics change; a Credits counter/
  render binding is added.
- **Action:** add Credits counter widget + binding; re-label income breakdown as Credit income; extend
  affordability reads to dual-cost; revisit the tick FSM against carryover/banking; repoint the
  forward-declared breakdown to `Credits`.

#### ADR-0008 — start-of-turn sequencing — 🟡 Update in place
- **Assumed:** `EndTurnAction.apply` step 1 `AP.discard()` ("unspent AP gone, no banking"); `start_turn`
  step 4 `AP.reset_turn()` ("snapshot + set current_ap").
- **Assessment:** the 4-step order + forward-declared-contracts decision survives. Step 1 `AP.discard()`
  is **removed** (AP carries). Step 4 **splits**: 4a `AP.reset_turn()` (flat+carry) + 4b
  `Credits.add_income()` (add credit_income) — and 4b must stay **after** the build-timer advance so a
  just-completed outpost counts this turn (the ordering guarantee now applies to Credit income).
- **Action:** update the diagram, Key Interfaces (`start_turn`, `EndTurnAction.apply`), the two GDD-rows,
  and the "just-completed counts this turn" validation criterion (now samples `Credits.credit_income`).

#### ADR-0011 — AI opponent decision loop — 🟡 Update in place
- **Assumed:** candidates sorted by "…then `ap_cost` asc"; `_is_better(… ap_cost …)`; tie-break "lowest
  `ap_cost`"; per-candidate `AP.can_afford`; exactly 15 `AIConfig` knobs; `LETHAL_FLOOR_BONUS >
  economy_ceiling_score` invariant vs AP-denominated build cost.
- **Assessment:** single-cost-axis (value-per-AP) scoring is exactly where `CREDIT_TO_AP_RATE` and the
  dual-cost gate land. Cost axis → AP-equivalent combined cost (`ap_surcharge + credit_cost ×
  CREDIT_TO_AP_RATE`); affordability → dual-pool; the `AIConfig` "15 knobs" claim → 16; the lethal-floor
  invariant re-validated (GDD says holds ≤ rate ~1.98).
- **Action:** add `CREDIT_TO_AP_RATE` to `AIConfig`; redefine the cost axis + `_is_better` tie-break to
  AP-equivalent; dual-pool `can_afford`; re-examine the ceiling invariant; reconcile the knob count.

#### ADR-0001 — state model ownership & lifecycle — 🟡 Update in place
- **Assumed:** `PlayerState { current_ap, income_this_turn }`; `current_ap` comment "turn-reset";
  read API `current_ap(player)`.
- **Assessment:** add `current_credits: int` (banked); the `current_ap` "turn-reset" comment is now wrong
  (carryover-capped). Structural decision (Resource + `duplicate_deep`) unaffected — a new int is free.
- **Action:** add `current_credits` (+ any Credit-income snapshot if needed) to the `PlayerState` Key
  Interface; fix the `current_ap` comment; add `current_credits(player)` accessor; extend clone-isolation
  ACs to the new field. (`income_this_turn` may be retired/kept as a HUD convenience — decide during the
  edit.)

#### ADR-0017 — base & production mechanics — 🟡 Update in place
- **Assumed:** `validate_produce`/`validate_build` gate on single `AP.can_afford`; `AP.spend(cost)`;
  cancel "credit `refund` AP to owner". *(The word "credit" here is the refund verb, NOT the new Credits
  resource — incidental wording to disambiguate.)*
- **Assessment:** Build/Produce are dual-cost (Credits main + `BUILD_AP_COST`/`PRODUCE_AP_COST`); the
  gate/spend are single-pool AP only; cancel refund must be **50% Credits** (`Credits.credit`).
- **Action:** validate → dual `can_afford`; apply → paired spend; cancel → `Credits.credit(floor(build_cost
  × cancel_refund_pct))`; read the AP surcharges from `EconomyConfig`; disambiguate "credit" wording.

#### ADR-0018 — research & tech mechanics — 🟡 Update in place
- **Assumed:** `validate_start_research` single `AP.can_afford`; `AP.spend(research_cost)`; cancel "AP
  credit refund". *("credit" again the refund verb, incidental.)*
- **Assessment:** research is dual-cost — Credits main + a **per-tech** AP surcharge (`RESEARCH_AP_COST`
  base 1, `TechDef.ap_surcharge` override). Cancel refund → 50% Credits.
- **Action:** dual affordability gate + paired spend; per-tech `ap_surcharge` read (falls back to
  `research_ap_cost`); cancel → Credits; note the `TechDef.ap_surcharge` dependency on ADR-0007;
  disambiguate "credit" wording.

#### ADR-0007 — entity & stat schema — 🟡 Update in place
- **Assumed:** `UnitTypeDef.produce_cost`, `StructureTypeDef.build_cost`, `TechDef.research_cost`;
  `economy_tech_income_bonus()` "AP.income() adds this verbatim".
- **Assessment:** the cost fields are now **Credit**-denominated (same numbers); a per-tech
  `TechDef.ap_surcharge: int` field is added (default = `research_ap_cost`, ADR-0018 reads it);
  `economy_tech_income_bonus` now feeds `Credits.credit_income`, not `AP.income`.
- **Action:** add `TechDef.ap_surcharge`; relabel `produce_cost`/`build_cost`/`research_cost` semantics as
  Credit-denominated; fix the `economy_tech_income_bonus` comment (`credit_income`). (Unit/structure
  surcharges stay flat config in `EconomyConfig`, not per-type — see ADR-0006 Alt 5.)

#### ADR-0015 — command & action interface FSM — 🟡 Update in place
- **Assumed:** `projected_remaining_ap = AP.current_ap − previewed_cost` (D-1); Pass-Through consumes
  `AP.can_afford/current_ap/income`; "the FSM never deducts AP".
- **Assessment:** the FSM architecture (pure core, pass-through, tiers, commit routing) is orthogonal to
  pool count and holds. Concrete display derivations assume one pool: `projected_remaining_ap` is
  single-axis; economic-verb affordability/preview readouts now show dual cost. Move/Attack previews
  unchanged (AP-only).
- **Action:** add a `projected_remaining_credits` sibling; extend menu-model affordability + preview
  readouts to the dual-cost queries for Build/Produce/Research. Pass-Through invariant/lint unaffected.

### Keep as-is — Still Valid

| ADR | Why unaffected |
|-----|----------------|
| **ADR-0010** combat resolution | Attack is AP-only, unchanged; `AP.spend(attack_cost)` untouched, `DEFENSIVE_ATTACK_COST` AP-only. |
| **ADR-0009** reachable-search / pathfinding | Move is AP-only, unchanged; BFS cost + `current_ap`-bounded frontier + `AP.spend` billing all still correct; Credits never touch movement. |
| **ADR-0014** input & focus architecture | Orthogonal to the resource model; the `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant is HUD animation timing (an ADR-0016 concern), not pool count. |
| **ADR-0003** determinism & RNG isolation | Credits are integer state (fine); `CREDIT_TO_AP_RATE` is an AI-scoring float, already permitted by Rule 4 (floats outside state, never selecting nondeterministically). |
| **ADR-0012** faction identity | Framework-only, Neutral-inert in the VS; the income-delta fold now targets `credit_income` (a relabel, not a structural change). **Editorial note only** — optionally note `effective_ap_income` folds into `credit_income`. Also carries the same Pillar-1 "single AP economy / never a second resource" line the game-concept.md pillar got reworded for — handled in the GDD sweep, not the ADR. |

*(ADR-0004 event/signal, ADR-0005 grid/map, ADR-0013 iso rendering — not economy-coupled; untouched.)*

---

## Consumer GDD sweep (design-layer, alongside the ADR updates)

These GDDs still describe one pool; they need real content, not just a rename:

| GDD | What changes |
|-----|--------------|
| `command-action-interface.md` | Affordability gating → dual (`credits_can_afford AND ap_can_afford`); `projected_remaining_ap` gains a `projected_remaining_credits` sibling; economic-action previews show both costs. |
| `game-hud.md` | Add a **Credits counter** (banked, +income flourish); income breakdown → Credit income; dual-cost affordability on Build/Produce/Research; AP counter no longer "discards" (carries). |
| `faction-identity.md` | Income deltas fold into `credit_income`; **Pillar-1 line** "only ever express through the single AP economy … never introduces a second resource" reworded to match game-concept.md's approved reconciliation ("Every Choice Is a Tradeoff"). |
| `unit-system.md` | **Stale worked examples invert** — e.g. "Heavy on floor income (10 AP) cannot produce, move, and attack" is now false (produce = 7 Credits + 1 AP surcharge, so it *can*). Rewrite the AP-economy interaction rows + examples; `produce_cost`/surcharge split. |
| `grid-terrain.md` | Minor — a resolved-open-question name reference to "AP Economy #3"; light touch. |
| `systems-index.md` | ⚠ Phase 1 retitled only the #3 row — the body still had stale single-currency descriptions ("per-turn action-point pool", "unspent AP is lost", "single-currency balance center", "Pillar 1's heart") + ~10 old-name refs. Cleaned in Phase 2: two-pool descriptions + name rename. |
| `combat-resolution.md` | Phase 1 touched only Pillar-1 taglines — its economy interface refs (`AP Economy`, `can_afford`/`spend(attack_cost)`) were still old-form. Cleaned: name → "AP & Credits Economy", `can_afford`/`spend` → `ap_can_afford`/`ap_spend` (attack stays AP-only, unchanged). |
| `ai-opponent.md` / `base-production.md` / `research-tech.md` | Fully pivoted in Phase 1; a few residual old-name refs cleaned (live prose only — dated status-history left verbatim). |
| `accessibility-requirements.md`, `difficulty-curve.md` | Name references; low priority, sweep for consistency. |

> **Sweep lesson:** the Phase-1 pivot updated document *bodies* but left the *system name* "AP Economy"
> and single-currency descriptions in the index + combat + cross-refs. Phase 2 caught these via a
> corpus-wide grep sweep after the ADR/GDD edits — worth re-running before any future gate.

*(Dated review-logs and cross-review snapshots under `design/gdd/reviews/` and `gdd-cross-review-*` are
historical artifacts — **not** edited.)*

---

## Resolution Decisions

| Decision | Choice |
|----------|--------|
| ADR-0006 structure | **Revise in place** (user, 2026-08-05) — one ADR stays the economy home; ~10 consumers keep their `ADR-0006` reference. |
| Cadence | **Checkpoint at the anchor** (user, 2026-08-05) — draft ADR-0006 + this report first, review, then propagate. |
| Pillar-1 wording | Already resolved for game-concept.md ("Every Choice Is a Tradeoff", committed `ed11e7c`); apply the same to faction-identity.md in the sweep. |

## Follow-up actions (Phase 2 remaining)

1. Update in place: ADR-0008, 0002, 0016, 0011, 0001, 0017, 0018, 0007, 0015 (against the approved 0006).
2. Consumer-GDD sweep (table above).
3. Editorial note on ADR-0012 (`effective_ap_income` → `credit_income`).
4. `/design-review design/gdd/ap-economy.md` on the delta; `/architecture-review` to re-validate the
   traceability matrix after all ADRs are updated.
5. Update `traceability-index.md` (Superseded/Revised Requirements) — the GDD rules re-numbered/added.
