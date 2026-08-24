# Command & Action Interface

> ⚠ **Economy pivot (2026-08-05):** the single AP pool this document was written against has been
> split into **two resources** — tactical **AP** (`current_ap`) and banked **Credits**
> (`current_credits`), owned by **AP & Credits Economy** (#3). Move/Attack stay AP-only and are
> **unchanged**. Produce/Build/Research are now **dual-cost**: a Credit main cost (`credits_can_afford`)
> plus a small AP surcharge (`ap_can_afford`), both-or-neither. Every "AP Economy" reference below is
> now "AP & Credits Economy"; affordability, previews, and disablement reasons for economic verbs are
> updated accordingly. See `ap-economy.md` for the canonical model.
>
> **Status**: Designed — revised 2026-07-22 following full `/design-review` re-review (verdict NEEDS REVISION, 3 blockers fixed in-file; pending re-review). History: Designed 2026-07-22 → MAJOR REVISION NEEDED (11 blockers) → revised → NEEDS REVISION re-review (CR-10 tier gap, win-check FSM gap, CR-6a gesture constraint) → revised → **economy pivot revision (2026-08-05, this version)**.
> **Author**: user + agents (design-system skill, lean review mode)
> **Last Updated**: 2026-08-05 (economy pivot — dual-cost affordability)
> **Implements Pillar**: Pillar 3 — Readable Board, Deep Decisions (flagship); serves Pillar 1 (see the cost before you pay it)
> **Specialists consulted**: authoring — systems-designer (Formulas), art-director (Visual/Audio), qa-lead (Acceptance Criteria). Full `/design-review` (2026-07-22) — game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, art-director, audio-director, gameplay-programmer, godot-specialist, and creative-director (senior synthesis); verdict MAJOR REVISION NEEDED → revised. Re-review (2026-07-22) — same 9 specialists + creative-director; verdict NEEDS REVISION → revised. Economy pivot (2026-08-05) — dual-cost affordability propagated from `ap-economy.md`.
> **All 8 required sections complete** + Visual/Audio, UI Requirements, Open Questions.

## Overview

The **Command & Action Interface** is the pre-commit action layer that stands between the player's input and every AP-costed action in the game. It follows the Advance Wars / Fire Emblem command flow the concept prototype flagged as its highest-value missing affordance: the player **selects** a unit or structure, the interface **queries** the owning system for the legal set of things it can do and their exact cost (which tiles it can reach, which targets it can hit, where a structure can be built, what each costs in AP) using side-effect-free preview calls, **renders** that as on-board overlays and precise numbers, and only commits when the player **confirms** — routing the choice through a single atomic action so the board never changes until the player says so. It is not a system that decides outcomes; it is the system that makes the game's decisions *visible before they are paid for*. Every action type — move, attack, build, produce, cancel — flows through this same select → preview → confirm loop; there is no separate "macro screen," matching the game's one-economy-every-choice identity. Its load-bearing promise is that **a preview is a guarantee, not an estimate**: whatever cost or effect the interface shows, the committing system charges exactly that and no more. Without this layer the unified AP economy would feel fiddly and punishing — the player would be paying for choices blind, discovering a move's true cost or a shot's real damage only after committing it. With it, the depth of the AP triage stays in the *choices*, never in the interface (Pillar 3), and every spend feels deliberate rather than gambled (Pillar 1).

## Player Fantasy

**The feeling: total information, zero regret. You are a commander who never guesses.**

The Command & Action Interface serves the game's Core Fantasy of **mastery of tempo** by making the board an open book you interrogate before you act. You select a unit and the map lights up with exactly where it can go and what each step costs; you sweep a target and see the precise damage before a shot is fired; you weigh a new outpost and the AP price and build time sit right there in the menu. The emotion is the quiet confidence of *perfect information* — the *Into the Breach* promise that you are being tested on your judgment, never punished by a surprise. Every turn becomes a deliberate act of triage you can actually *see*: this move or that push, this tech or that turret, laid out with real numbers so the agonizing choice is honest.

**The anchor moment**: it's a knife-edge turn, you have 8 AP left, and you're deciding between two lines. You hover the Heavy's advance — *6 AP, and the reachable overlay shows the last two tiles are surcharged red because you'd be over-extending past its soft cap*. You back out, hover an attack on the enemy Trooper instead — *2 AP, preview says 4 damage, one short of the kill*. You feel the tradeoff in your gut **before you've spent a single point**, adjust, and commit the line you actually meant. Nothing was gambled. If it goes wrong, it was your read that was wrong — and next turn you'll read it better.

This is the **Pillar 3** fantasy in its purest form — *"the state is always visually legible at a glance, even though the decisions underneath are deep."* The interface is where "readable board" and "deep decisions" meet: it hides none of the depth and adds none of the confusion. Its highest compliment is to be **invisible** — the player should feel like they are commanding the battle directly, not operating a menu. When it works, the player never thinks about the UI at all; they only think about the *choice*.

> *Note: `creative-director` reviewed this framing in the full `/design-review` (2026-07-22) as senior synthesizer and endorsed the pillar alignment; the D-3 "honest guarantee" rewrite in this revision strengthens it further.*

## Detailed Design

### Core Rules

**CR-1 — The universal interaction loop.** Every AP-costed action follows one loop: **Select** an owned entity → open its **contextual action menu** → pick a verb to enter a **preview** mode → **hover** to see the exact cost/effect of each option → **single-click a highlighted option to commit**. The same loop drives move, attack, build, produce, and cancel. There is no separate macro screen and no action queue: each commit is one immediate, atomic `apply_action` call.

**CR-2 — Preview is a guarantee, not an estimate (load-bearing).** This interface never computes cost, damage, or legality itself. It *only* displays what the owning system's side-effect-free query returns, and commits by calling that system's atomic action. Consequently the number shown at preview is exactly the number charged at commit — for any previewed option, the committed cost/effect must be identical. If a query and its commit could ever disagree, that is a defect in the dependency, not something this interface papers over.

**CR-3 — Selection.** Left-clicking an entity the active player owns and that has at least one legal action selects it and opens its action menu. Clicking an enemy/neutral entity (or hovering any entity) shows a **read-only inspection** of its stats but never opens a command menu — you can only *command* your own entities on your own turn. Clicking empty terrain or pressing ESC deselects. Selecting a different owned entity switches selection directly.

**CR-4 — Contextual action menu.** On selection, the menu lists only the verbs that are *legal and affordable right now* for that entity: **Move** (if `reachable` non-empty), **Attack** (if `legal_targets` non-empty and not yet `has_attacked` and `ap_can_afford(attack_cost)` — AP-only, unchanged by the economy pivot), **Produce** (producers only, if `production_cap` remaining and any `producible_type` **dual-cost affordable** — `credits_can_afford(produce_cost) AND ap_can_afford(PRODUCE_AP_COST)` — with a legal deploy tile), **Cancel Build** (under-construction structures only), and **Wait** (always — ends this entity's involvement without spending). Build carries the same dual-cost gate (`credits_can_afford(build_cost) AND ap_can_afford(BUILD_AP_COST)`) at its player-level entry (CR-5). A verb the entity *has* but cannot use right now (e.g. Attack when unaffordable, or Produce/Build short in either pool) is shown **disabled with its reason**, not hidden — so the player learns why an option is unavailable rather than wondering where it went. **For an economic verb (Produce/Build/Research), the disablement reason names the *binding* pool** — whichever of `credits_can_afford`/`ap_can_afford` failed (see CR-8, D-2) — never a generic "unaffordable."

**CR-5 — Building structures (player-level entry).** Building a *new* structure is not tied to an existing entity (there is nothing to select yet), so it is initiated from a **player-level Build command** (a HUD button / hotkey — the entry affordance is co-owned with Game HUD #10). Choosing Build opens structure-type selection (each option showing `build_cost` + `build_time`, affordability-gated), then enters **build-placement preview** over `legal_build_tiles`. *Producing units* is different — it is initiated by selecting an owned **producer** structure (HQ / Production Outpost) and choosing Produce.

**CR-6 — Single-click commit; illegal clicks are inert.** Inside a preview mode, a left-click on a **highlighted legal option** commits immediately (spends AP, resolves, updates the board). A click on a non-highlighted tile/target does **not** commit anything — it either does nothing or backs out to the action menu (never an accidental spend on an illegal target). Because only legal options are clickable, the player cannot misclick AP onto an invalid action.

**CR-6a — Destructive commits require a distinct gesture.** The universal single-click of CR-6 applies to every *non-destructive* commit (move, attack, produce, build-placement) — a misclick there costs AP (and, for produce/build, Credits) the player was already choosing to spend and destroys no standing investment. **Cancel Build is the sole exception**: it is the one commit that irreversibly converts a standing Credit investment into a partial Credit refund (the AP surcharge already spent is never returned) with no undo (CR-7), so it does **not** fire on a bare single left-click. It commits only on a **distinct destructive gesture** (a dedicated Cancel-Build affordance plus a deliberate hold-or-double-activate — the exact gesture set by `/ux-design`), so that a stray click adjacent to an under-construction structure can never trigger a refund-destroy. This is the one place "zero regret" (Player Fantasy) overrides interaction uniformity: the gesture stays *one action*, but not a gesture a stray click can produce.

**Input-shape constraint on the eventual gesture (binding on `/ux-design`, not deferred with it):** whatever exact gesture `/ux-design` selects must satisfy two structural requirements this GDD fixes now, so the pixel-level choice cannot reopen a problem this doc already solved elsewhere: (1) it must be expressible as a bounded input-event sequence handled entirely within the existing `ENTITY_SELECTED` state — a duration-tracked "holding" sub-condition is acceptable as *internal* handling of the Cancel-Build affordance, but the choice may not require a new top-level FSM state (the States table is not amended by it); and (2) it must use an input-event category that a rapid, accidental double left-click cannot produce. A plain double-click of the same `InputEventMouseButton` the universal single-click already uses is explicitly **disallowed** as a valid Cancel-Build gesture, because it would be indistinguishable from the accidental double-click race `INPUT_LOCK_MS`/AC-27 already exist to make inert. (A held single input, a modifier-combined click, or a dedicated-affordance-plus-confirm sequence all satisfy this; an unmodified double left-click on the structure itself does not.)

**CR-7 — Pre-commit cancel vs. no post-commit undo.** *Before* the commit click, the player may back out of any preview freely with right-click or ESC — nothing is spent (this satisfies Movement's and Combat's "support cancel of a pending action before commit" requirement). *After* the commit click, there is **no undo**: AP is spent and the board change is final. The pre-commit preview is the sole safety net — which is exactly why CR-2's guarantee is load-bearing.

**CR-8 — Affordability gating (named handoff from AP & Credits Economy).** Every action's availability routes through AP & Credits Economy's dual afford queries. **Move and Attack** are AP-only — gated on `ap_can_afford(player, amount)` alone, unchanged by the pivot. **Produce, Build, and Research** are dual-cost — gated on `credits_can_afford(player, credit_cost) AND ap_can_afford(player, ap_surcharge)`, both-or-neither. An action the player cannot afford is shown **disabled/greyed with the shortfall visible in whichever pool binds** — a Credit shortfall ("needs 6 Credits, have 4"), an AP-surcharge shortfall ("needs 2 AP, have 1"), or both if both fail (D-2) — never offered as clickable. (AP & Credits Economy's GDD explicitly defers this "shown available vs. greyed" behavior to this GDD.)

**CR-9 — Mandated preview legibility (inherited hard requirements).** The preview overlays must render these distinctions the dependency GDDs require — they are not optional polish:
- **Move**: in-cap (base-cost) tiles vs. over-cap (surcharged) tiles must be visually distinct, and the overlay must reflect the unit's *current cumulative* `tiles_moved_this_turn` — so the cheap zone visibly shrinks when a partially-moved unit is reselected.
- **Move blockers**: pass-through friendly units (can cross, can't stop) read distinctly from blocking friendly structures, enemy blockers, and Impassable terrain.
- **Attack**: three visually-distinct blocked-shot states — blocked-by-friendly, out-of-range, and inside-AREA-dead-zone — never one generic grey-out. Damage preview shows the **post-cover, post-defense** number with a cover indicator on the defender's tile explaining *why* it is reduced.
- **Build**: the two legal-tile exclusion reasons — *not adjacent to a friendly entity* vs. *too close to an enemy structure* — read distinctly.
- **Under-construction structures**: show turns-remaining and read as unmistakably unfinished/inert.
- **Cancel Build**: the menu option shows the exact partial refund (`floor(build_cost × CANCEL_REFUND_RATE)`) before the commit gesture — and, per CR-6a, commits only on the **distinct destructive gesture**, never a bare single click.

**CR-10 — Recompute fresh, never cache stale (four tiers).** The distinction is load-bearing for performance and correctness — a reader of this rule alone must be able to predict every query this interface issues and when:
- **Tier 1 — Entry queries.** Set-level queries (`reachable()`, `legal_targets()`) are re-issued against live game state **once per preview entry, and again whenever the board changes mid-turn** (e.g. a blocker dies to a committed attack). The returned set is then held for the life of that preview.
- **Tier 2 — D-3's frontier batch.** `legal_targets(unit, from_tile)` is issued **once per PREVIEW_MOVE entry, as a batch across every tile in the just-computed `reachable()` frontier** (not once total, not per hover) — see the Formulas D-3 cost note for its fan-out shape. This is a distinct, more expensive tier than Tier 1's single query and must be budgeted separately in `/architecture-decision`.
- **Tier 3 — Hover reads.** Hovering does **NOT** re-run a set-level query. A hover is an **O(1) read** into the already-computed Tier-1/Tier-2 sets for the tile/target under the cursor — this is exactly what `reachable(unit)[tile]` denotes throughout Formulas. Overlays never display a stale set, but the interface also never re-flood-fills `reachable()` on every mouse-motion event.
- **Tier 4 — Commit-time point-check.** The commit click itself is **not** a recompute by this interface — it is a single-option legality re-validation performed *inside* the owning system's atomic `apply_action` (see Edge Cases: "tile becomes illegal between preview entry and commit"). This interface never re-issues a set-level query at commit time; it only reacts to `apply_action`'s accept/reject result.

**Board-change is defined against the logical game-state model, not the scene tree.** Per Game State & Turn Manager's render-decoupled, headless-simulatable state model (`entities()`, `entity_at`, occupancy from Grid & Terrain), Tier-1/Tier-2 queries read that authoritative logical model — never node presence in the render scene. This makes "the board changed" unambiguous and frame-timing-independent: a blocker is gone from `reachable()`'s input the instant the logical state model marks it removed, regardless of when the corresponding node is freed from the scene tree. Any implementation where these queries instead walk live scene-tree nodes is a violation of this rule, flagged as a hard implementation constraint for `/create-architecture`.

This matters because Movement's `reachable()` is a **Dijkstra/uniform-cost search, not an O(1) lookup**, and Tier 2 multiplies that cost across the reachable frontier — re-running either per hover tick (combined with `PREVIEW_HOVER_LATENCY_MS = 0`) would risk frame hitches on larger boards. Raw `InputEventMouseMotion` should be **tile-change-gated** (act on entering a new tile, not on every sub-tile motion event); flagged for `/architecture-decision`, alongside Tier 2's fan-out budget. Because all queries are side-effect-free, re-issuing them on board-change is safe — but *enforcing* that purity is a contract owed by the dependency systems, not something this interface can guarantee from the outside (see Dependencies).

**CR-11 — Turn-boundary scoping.** The command interface accepts action input only during the **active player's Action phase**. During Start-of-turn / End-of-turn resolution and the opponent's turn it is inert (inspection-only). The player ends their turn with an **End Turn** control, available whenever no preview is mid-flight; pressing End Turn while a preview is open backs out of the preview first (never commits by surprise). **Match-end is terminal, not another phase:** if a commit's own win-check transitions `match_status` to `GameOver(winner)` (Game State & Turn Manager's terminal state — "no further input accepted"), the interface finishes resolving that one atomic `apply_action` in full (exactly as it already does for entity-death, see States → Post-commit re-selection) and then goes **fully inert** — no selection, menu, preview, or even read-only inspection, and no End Turn control — mirroring Game HUD's "input otherwise frozen" on the same transition (game-hud.md CR-9). There is no path back to IDLE from this state; see States → `GAME_OVER`. **This also applies to the non-committing player's interface instance:** any interface — including one sitting inert during the opponent's Action phase — transitions to the terminal `GAME_OVER` state the moment it observes `match_status = GameOver`, not only when its own commit triggered the win-check. Both players' interfaces converge on `GAME_OVER` by reading `match_status` (as Game HUD already does), independent of who landed the final blow.

### States and Transitions

The interface is a small state machine. `own-actionable entity` = an entity the active player owns with ≥1 legal action.

| From state | Trigger | To state | Side effect |
|---|---|---|---|
| **IDLE** | Select own-actionable entity | ENTITY_SELECTED | Open action menu (filtered per CR-4) |
| IDLE | Player-level **Build** command | PREVIEW_BUILD | Show structure-type picker → `legal_build_tiles` overlay |
| IDLE | Hover/click enemy or neutral | IDLE | Read-only inspection panel (no menu) |
| IDLE | **End Turn** | (turn handoff) | Interface goes inert until next own turn |
| **ENTITY_SELECTED** | Pick **Move** | PREVIEW_MOVE | Render `reachable` overlay (in-cap vs over-cap) |
| ENTITY_SELECTED | Pick **Attack** | PREVIEW_ATTACK | Render `legal_targets` + blocked-state overlays |
| ENTITY_SELECTED | Pick **Produce** (producer) | PREVIEW_PRODUCE | Unit-type picker → `legal_deploy_tiles` overlay |
| ENTITY_SELECTED | Pick **Cancel Build** (under-constr.), then the **distinct destructive gesture** (CR-6a) | (commit) | `cancel_build()`; refund shown before the gesture; → ENTITY_SELECTED (refreshed), or IDLE if the structure was the selection and nothing else is actionable |
| ENTITY_SELECTED | Pick **Wait** | IDLE | Deselect; no AP spent |
| ENTITY_SELECTED | Select a different own-actionable entity | ENTITY_SELECTED | Switch selection, re-filter menu |
| ENTITY_SELECTED | ESC / click empty terrain | IDLE | Deselect |
| **PREVIEW_\*** | Hover a legal option | (same) | Update exact cost/effect readout — no commit |
| PREVIEW_MOVE / PREVIEW_ATTACK / PREVIEW_PRODUCE | **Left-click a highlighted legal option** | ENTITY_SELECTED (refreshed, **same actor**) | **COMMIT**: atomic `apply_action`; AP spent; board updates; win-check. If the commit *destroys the acting entity* (e.g. death to a counterattack), → IDLE (see post-commit note) |
| PREVIEW_BUILD | **Left-click a highlighted legal build tile** | ENTITY_SELECTED (the **newly-placed** structure), or IDLE if it has no legal action | **COMMIT**: atomic `apply_action`; AP spent; board updates. Build has no source entity, so it lands on the new structure — never a prior selection |
| PREVIEW_\* | Left-click a non-highlighted tile | ENTITY_SELECTED (or IDLE for Build) | Inert — back to menu, nothing spent |
| PREVIEW_\* | Right-click / ESC | ENTITY_SELECTED (or IDLE for Build) | Back out, nothing spent |
| *(any state above)* | A commit's win-check sets `match_status = GameOver` | **GAME_OVER** *(terminal)* | Overrides every other Trigger→To-state mapping for that one commit: the full atomic `apply_action` resolves first exactly as its row above describes, **then** the interface transitions to the terminal `GAME_OVER` state instead of its normal destination — no selection/menu/preview/inspection/End Turn accepted afterward (CR-11); Game HUD presents the victory/defeat overlay |

**Match-end terminates the interface.** If any commit's win-check sets `match_status = GameOver`, that overrides the commit's normal post-commit destination: the interface transitions to the terminal `GAME_OVER` state instead of ENTITY_SELECTED/IDLE, regardless of whether the acting entity survived. This mirrors Game HUD's own "input otherwise frozen" on the same transition (game-hud.md CR-9) — there is no return path to IDLE. See CR-11.

**Post-commit re-selection**: after a commit the interface returns to ENTITY_SELECTED for the *same* entity with its menu re-filtered against remaining AP / `has_attacked` / cumulative movement — so a **move → attack** sequence (two separate AP commits) feels like one fluid interaction despite being two atomic actions. If the entity has no remaining legal action, it auto-deselects to IDLE.

**If the acting entity is destroyed by the commit it just made** — e.g. an attacker that dies to a Defensive Structure's counterattack (`can_counterattack`, live in the Vertical Slice — Combat CR-7/8) — there is no actor to return to. The interface resolves the full atomic `apply_action` (the attack, any counterattack, and the win-check) and then **auto-deselects to IDLE**. The post-commit re-selection target is always *the actor as it exists after resolution*; a removed actor collapses to IDLE, never a dangling selection on a destroyed entity. (A **Build** commit is the mirror case — no source actor going *in* — and lands on the newly-placed structure per the States table.)

### Interactions with Other Systems

This interface **owns**: selection state, input routing, the action menu, overlay/preview rendering, and calling the atomic commit. It **never** owns: cost math, damage math, legality rules, or AP/Credit deduction — those live in the dependency systems. The contract per dependency:

| System | Side-effect-free queries this UI calls (preview) | Atomic commit this UI calls | What this UI renders |
|---|---|---|---|
| **Movement** | `reachable(unit) → {tile, min_cost, is_surcharged}` — the `is_surcharged` per-tile flag is **landed in Movement's GDD** (OQ-2 resolved), delivering CR-9's in-cap/over-cap split | `move(unit, dest)` | Reachable overlay w/ in-cap vs over-cap tiles, per-tile AP cost, pass-through vs blocking distinction |
| **Combat** | `legal_targets(unit)`, `preview_damage(atk, tgt)`, **`legal_targets(unit, from_tile)`** — hypothetical-tile targeting for the honest after-move attack preview (D-3); **landed in Combat's GDD** (OQ-1 resolved) | `attack(atk, tgt)` | Target highlights, exact post-mitigation damage + cover indicator, 3 blocked-shot states, honest "can attack after moving here" tile signal |
| **Base & Production** | `legal_build_tiles`, `legal_deploy_tiles`, `completed_outpost_count`, per-producer `production_cap` remaining | `build()`, `produce()`, `cancel_build()` | Structure/unit pickers w/ cost+time, placement/deploy overlays w/ 2 exclusion reasons, build-timer readout, cancel refund |
| **AP & Credits Economy** | `ap_can_afford(player, amount)`, `credits_can_afford(player, amount)`, `current_ap`, `current_credits`, `credit_income` | *(none — AP/Credits are spent inside each system's commit)* | Affordability gating on every menu entry (dual-gate for economic verbs, AP-only for Move/Attack); the live cost each preview subtracts from the displayed pool(s) — an economic action's preview subtracts from **both** displayed pools at once |
| **Game State & Turn Manager** | active-player / phase read | *(End Turn routes through turn manager)* | Interface active only in own Action phase; End Turn control |

**Ownership note:** the exact *visual style* of overlays and the AP-pool counter live with Game HUD (#10) and the art bible; this GDD owns the *interaction behavior and information content* of the preview, not its pixels. The player-level **Build** entry affordance is a coordination point co-owned with Game HUD (#10).

> *Lean review mode: `ux-designer` / `ui-programmer` not consulted for this section — reserved for Formulas & Acceptance Criteria. Flag for a UX pass before production.*

## Formulas

**This system deliberately owns no cost, damage, or legality arithmetic.** Per CR-2, every substantive formula lives in a dependency (`move_path_cost` → Movement, `damage_formula` → Combat, `credit_income` → AP & Credits Economy, cancel refund → Base & Production). The Credit cost of an economic action (`produce_cost`/`build_cost`/`research_cost`) is owned by the acting GDD (Base & Production / Research), and its AP surcharge (`PRODUCE_AP_COST`/`BUILD_AP_COST`/`RESEARCH_AP_COST`) is owned by AP & Credits Economy — this interface re-derives neither. What this interface *does* own is **read-only combination of those systems' pure query outputs into display values and enabled/disabled verb states** — no balance math, but real aggregation, now over **two pools' queries** instead of one. Four display-only derivations follow.

### D-1 · `projected_remaining_ap` — post-action AP readout

`projected_remaining_ap = current_ap(player) − previewed_ap_cost`

| Variable | Type | Range | Description |
|---|---|---|---|
| `current_ap(player)` | int | 0 – (FLAT_AP_PER_TURN + AP_CARRYOVER_CAP) | Live AP & Credits Economy query at **render time** |
| `previewed_ap_cost` | int | 0 – current_ap | The **exact, unmodified** return of the owning system's AP cost query for the previewed action — `reachable()`'s `min_cost` (Move), the queried `attack_cost`/`DEFENSIVE_ATTACK_COST` (Attack), or an economic action's **AP surcharge** (`PRODUCE_AP_COST`/`BUILD_AP_COST`/`RESEARCH_AP_COST`) — **passed through, never re-derived**. The Cancel Build refund credits `current_credits`, not AP (see D-1b) |
| `projected_remaining_ap` | int | 0 – current_ap for an **enabled** action; **may be < 0** when a *disabled* action is hovered (labeled "insufficient AP", never shown as a negative number — see Edge Cases / AC-24) | AP remaining immediately after this single action commits |

**Output range:** ≥ 0 for any action that passes the D-2 predicate (non-negativity is emergent from the affordability gate, not a `max(0,…)` clamp). **Worked example:** `current_ap = 9`; preview a Trooper's 3-tile in-cap move (`reachable` returns `min_cost = 6`) → `9 − 6 = 3`. Preview an attack instead (`attack_cost` query returns `2`) → `9 − 2 = 7`. Preview a Build instead (`BUILD_AP_COST` = 2) → `9 − 2 = 7`, shown **alongside** D-1b's `projected_remaining_credits` for the same preview. These are **separate, independent** previews — never summed (see D-4).

### D-1b · `projected_remaining_credits` — post-action Credit readout (economic actions only)

`projected_remaining_credits = current_credits(player) − previewed_credit_cost`

| Variable | Type | Range | Description |
|---|---|---|---|
| `current_credits(player)` | int | 0 – unbounded (banked, no cap) | Live AP & Credits Economy query at **render time** |
| `previewed_credit_cost` | int | 0 – current_credits | The **exact, unmodified** return of the acting system's Credit main-cost query for the previewed economic action (`produce_cost`, `build_cost`, or `research_cost`) — **passed through, never re-derived**. Move and Attack never populate this (`credit_cost = 0`, not previewed) |
| `projected_remaining_credits` | int | 0 – current_credits for an **enabled** action; **may be < 0** when a *disabled* action is hovered (labeled "insufficient Credits", never shown as a negative number — mirrors AC-24) | Credits remaining immediately after this single economic action commits |

**Output range:** ≥ 0 for any economic action that passes the D-2 predicate (non-negativity is emergent from `credits_can_afford`, not a clamp). **A Produce/Build/Research preview always shows both D-1 and D-1b together** — the projected AP remainder (surcharge) and the projected Credit remainder (main cost) — since the commit spends both pools atomically (both-or-neither, `ap-economy.md`). **Worked example:** `current_credits = 8`, preview a Build costing `build_cost = 4` Credits + `BUILD_AP_COST = 2` AP, `current_ap = 9` → `projected_remaining_credits = 8 − 4 = 4` shown alongside `projected_remaining_ap = 9 − 2 = 7`. Move/Attack previews never show this readout (D-1 only, per D-4).

### D-2 · `action_enabled` — compound legality + affordability predicate

**Move / Attack (AP-only, unchanged):** `action_enabled = is_legal(owning_system_query) AND ap_can_afford(player, previewed_ap_cost)`

**Produce / Build / Research (dual-cost):** `action_enabled = is_legal(owning_system_query) AND credits_can_afford(player, previewed_credit_cost) AND ap_can_afford(player, previewed_ap_cost)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `is_legal(owning_system_query)` | bool | {T, F} | The owning system's own legality result — Movement: `tile ∈ reachable(unit)`; Combat: target valid per `targeting_mode`/`min_range`/`attack_range` **AND** `!has_attacked`; Base & Production: build/produce/cancel preconditions |
| `ap_can_afford(player, previewed_ap_cost)` | bool | {T, F} | AP & Credits Economy's literal AP query — never reimplemented locally. Sole affordability conjunct for Move/Attack; the AP-surcharge conjunct for economic verbs |
| `credits_can_afford(player, previewed_credit_cost)` | bool | {T, F} | AP & Credits Economy's literal Credits query — never reimplemented locally. Only evaluated for economic verbs (Produce/Build/Research); Move/Attack never carry a Credit cost |
| `action_enabled` | bool | {T, F} | Verb shown selectable (T) or **disabled-with-reason** (F) |

**Output:** boolean. When false, the disablement **reason** is sourced from *which* conjunct failed — for Move/Attack that's illegal vs. insufficient AP; for an economic verb it's illegal vs. insufficient Credits vs. insufficient AP surcharge — all already in-hand from the queries, no new derivation. **When *multiple* conjuncts fail, all failing reasons are surfaced** (not just the first): showing only one would hide information the player needs, producing a second "gotcha" when they fix the first (Player Fantasy: no surprises — AC-8). An economic verb unaffordable in **either** pool shows that pool as its reason; unaffordable in **both** pools shows both. **Worked example (AP-only):** Sniper attack, `attack_cost` query = 2, `current_ap = 1`, target in range → Combat `is_legal = true`, `ap_can_afford = false` → disabled, reason "insufficient AP". Same sniper with the target *also* out of range → both fail → disabled, showing **both** "out of range" and "needs 2 AP, have 1". **Worked example (dual-cost):** Build, `build_cost = 6` Credits + `BUILD_AP_COST = 2`, `current_credits = 4`, `current_ap = 9`, tile legal → `is_legal = true`, `credits_can_afford = false`, `ap_can_afford = true` → disabled, reason "needs 6 Credits, have 4" (the binding pool is Credits; the AP leg passes silently).

### D-3 · `attack_possible_after_move` — honest after-move attack preview (move preview)

While previewing a **move**, each reachable tile may be marked by whether the unit could actually attack a legal target after moving there — an **honest legality-AND-affordability** signal, not a mere affordability hint. (This is the design chosen at review: fund the real hypothetical-tile query rather than ship a payable-but-maybe-illegal tint that would contradict CR-2's "a preview is a guarantee." See resolved OQ-1.)

`attack_possible_after_move(unit, tile) = NOT has_attacked(unit) AND (legal_targets(unit, from_tile = tile) is non-empty) AND ap_can_afford(player, reachable(unit)[tile].min_cost + attack_cost(unit))`

*(Move and Attack are both AP-only — this predicate never touches Credits; `ap_can_afford` here is the same AP & Credits Economy query as everywhere else in this GDD, unqualified by the pivot's Credit leg.)*

| Variable | Type | Range | Description |
|---|---|---|---|
| `has_attacked(unit)` | bool | {T, F} | Whether the unit has already attacked this turn — read via Combat; if true the whole predicate is false (no second attack is possible regardless of AP or position) |
| `legal_targets(unit, from_tile)` | set | ∅ … targets | **New Combat hypothetical-tile query** (OQ-1): the targets this unit could legally attack *if it were standing on `from_tile`* — accounts for range, blockers, and line-of-sight from that tile. Empty ⇒ no attack possible from there |
| `reachable(unit)[tile].min_cost` | int | 1 – current_ap | Pass-through move cost to that tile (O(1) read from the already-computed `reachable()` set) |
| `attack_cost(unit)` | int | 1 – 2 | **Queried** per-actor attack cost (2 units / 1 Defensive Structure) — pulled from a query, **never hardcoded** |
| result | bool | {T, F} | Whether the unit could legally *and* affordably attack after moving to `tile` |

**What it now guarantees (the point of the rewrite):** a tile marked "attack-possible" means a legal, affordable attack genuinely exists from there — the same class of promise as every other overlay (CR-2). It is defined **only for `tile ∈ reachable(unit)`**; tiles outside the reachable set are never marked (they are not previewed). The old failure modes are gone by construction: a unit with `has_attacked = true` is never marked (first conjunct), and a tile with no target in range is never marked (second conjunct). **Worked example:** `current_ap = 9`, Scout previewing a move to a tile costing 3, `attack_cost = 2`; `legal_targets(scout, from_tile) = {enemy Trooper}` (non-empty) and `ap_can_afford(player, 5) = true` → tile marked "attack-possible." Move the target out of range and the same tile is **not** marked, even though it remains payable.

> **Cost note (CR-10 Tier 2):** `legal_targets(unit, from_tile)` is fired as a **batch across the entire reachable frontier once per PREVIEW_MOVE entry** (not per hover) — this is a distinct, more expensive tier than a single Tier-1 set-level query, not an O(1) addition to it. Its `reachable`-sized fan-out (O(|reachable| × candidate targets)) is a perf item owed to `/architecture-decision` and the AI-lookahead budget (it must not be re-run per mouse-motion, and its cost must be budgeted separately from Tier 1).

### D-4 · Deliberate non-formulas

There is still **no combined move+attack projected-AP *number*** and **no aggregate multi-action spend** in this system — there is no action queue, and the interface never sums two actions into one displayed AP figure (or Credit figure) or simulates owning-system balance math (CR-2 / the Pass-Through Invariant forbid it). This also holds **across pools**: an economic action's D-1 (AP) and D-1b (Credits) readouts are two independent single-pool subtractions shown side by side, never combined into one blended number. D-3's honest after-move signal does **not** violate this: it is a **boolean** (attack possible: yes/no) built from a Combat legality query plus one exact AP-subtraction affordability check — it displays no synthesized post-move AP number and re-derives no formula. The interface *asks* Combat "could this unit hit anything from tile T?" and *asks* AP & Credits Economy "is move+attack affordable?"; it computes neither answer itself.

> **What this GDD requires of its dependencies (a constraint, not an assertion about their internals):** no dependency's commit path may charge more than its own preview query returned (CR-2), and `legal_targets(unit, from_tile)` must be a pure, side-effect-free query (see Dependencies). The interface cannot enforce these from the outside — they are contract obligations on Movement / Combat / Base & Production / AP & Credits Economy, verified in *their* test suites and an ADR.

### Pass-Through Invariant (governs D-1, D-1b, D-2, D-3)

> `projected_remaining_ap`, `projected_remaining_credits`, `action_enabled`, and `attack_possible_after_move` MUST be computed **exclusively** from the literal return values of owning-system queries for the specific previewed action, evaluated **at render time** — never cached across a frame in which underlying state could change (CR-10), and never re-derived by re-implementing an owning formula. **The interface holds zero copies of any owning-system balance constant** (`move_cost`, `SOFT_MOVE_PENALTY`, `attack_cost`, `COVER_DR`, `produce_cost`, `build_cost`, `research_cost`, `PRODUCE_AP_COST`, `BUILD_AP_COST`, `RESEARCH_AP_COST`, etc.). Any interface code path that references a balance constant by name is a violation of this GDD's core principle — now enforced across **two pools' worth** of constants, not one. This is a structural constraint — enforceable by code review / lint and a candidate implementation ADR, not merely a stated rule.

### Query-contract note (for architecture)

The required in-cap vs. over-cap move-tile distinction (CR-9) should be delivered by **Movement's query returning the split explicitly** (e.g. a per-tile `is_surcharged` flag alongside `min_cost`), *not* inferred by the UI from `min_cost` — average path cost does not cleanly separate a mixed in-cap/over-cap path, so UI-side inference would be fragile and could desync. Flag to `/architecture-decision` / a Movement query-contract refinement.

## Edge Cases

- **If a selected unit's `reachable` set is empty** (unaffordable, or fully boxed in by blockers/Impassable): the **Move** verb is shown *disabled with its reason* ("no affordable moves" vs. "no open tiles"), not hidden and not an error. The entity still selects.
- **If a unit's `legal_targets` set is empty**: the **Attack** verb is disabled with reason "no targets in range." No blocked-shot overlay is drawn (there's nothing to aim at).
- **If an action is unaffordable**: for Move/Attack (`ap_can_afford` false), the verb is disabled/greyed with the **AP shortfall visible** (e.g. "needs 2 AP, have 1"), never clickable (CR-8, D-2). For an economic verb (Produce/Build/Research), the verb is disabled/greyed with the shortfall shown for **whichever pool binds** — `credits_can_afford` false shows the Credit shortfall, `ap_can_afford` false (on the surcharge) shows the AP shortfall, and both show if both fail — never clickable (CR-8, D-2).
- **If the unit has already attacked this turn** (`has_attacked` true): the **Attack** verb is disabled with reason "already attacked," regardless of remaining AP.
- **If a producer's `production_cap` for the turn is exhausted**: **Produce** is disabled with reason "production limit reached this turn."
- **If a producer has no legal deploy tile** (all `manhattan==1` neighbors occupied/impassable): **Produce** is disabled with reason "no deploy space" — the producer reads as blocked, not broken.
- **If a build/deploy/target tile becomes illegal between preview entry and the commit click** (board changed by a prior commit this turn): the atomic `apply_action` **re-validates and rejects** (CR-10 Tier 4 — this point-check runs inside the dependency's commit, not as a recompute by this interface), spending **no AP**; the interface must handle the rejection gracefully — swallow it, refresh the overlay from a fresh Tier-1 query (CR-10), and keep the player in the menu. The UI never assumes a commit succeeds.
- **If the player selects a fully-spent entity** (no AP-costed action affordable): it still selects and shows its menu with **all AP verbs disabled-with-reason plus Wait** — so the player can inspect *why* it can't act rather than the entity being silently unselectable.
- **If the player selects an under-construction structure they own**: the menu offers only **Cancel Build** (showing the exact `floor(build_cost × CANCEL_REFUND_RATE)` refund) — the structure is inert until complete, so no Produce/Attack. A **Completed** structure is never offered Cancel Build (it can only be destroyed in combat, which refunds nothing and is not a player action).
- **If the player hovers an `attack_possible_after_move`-marked tile**: a legal, affordable attack genuinely exists from that tile — this is now a **guarantee**, same as every other overlay (CR-2). The old "affordable-but-maybe-no-target" ambiguity is designed out: D-3's predicate requires a non-empty `legal_targets(unit, from_tile)`, so a tile with no reachable target is never marked. A unit that has already attacked this turn (`has_attacked = true`) is likewise never marked, regardless of AP or position.
- **If the acting entity is destroyed by its own committed action** (e.g. it dies to a Defensive Structure's counterattack): the interface finishes resolving the atomic `apply_action` (attack → counter → win-check) and **auto-deselects to IDLE** — there is no post-commit re-selection onto a removed entity. See States → Post-commit re-selection.
- **If the player hovers a *disabled* action to see why** (and cost previews are shown for disabled actions too): `projected_remaining_ap` may be negative, but it must be labeled **"insufficient AP"**, never framed as "remaining AP will be −1." Likewise `projected_remaining_credits` may be negative but must be labeled **"insufficient Credits"**. Neither a disabled action's AP nor Credit readout is ever presented as a positive-framed remaining number.
- **If the player presses End Turn while a preview is mid-flight**: the interface **backs out of the preview first** (nothing committed), then ends the turn — a commit never fires by surprise from an End-Turn press.
- **If the player presses End Turn with unspent AP above the carryover cap**: End Turn is **allowed without blocking**; a dismissible, non-blocking **"X AP will be lost"** reminder is shown (configurable off — see Tuning Knobs) whenever `current_ap > AP_CARRYOVER_CAP`, since only the excess above the cap is lost at the next reset — unspent AP up to the cap carries over, it is not discarded (AP & Credits Economy's flat+capped-carryover model). Unspent Credits are never discarded — they bank with no cap, so no such reminder applies to Credits.
- **If two commit inputs arrive in rapid succession** (double-click / input race): input is **locked during commit resolution**; exactly one commit fires per legal click. A second click after the state has changed lands on a now-illegal (non-highlighted) option and is inert per CR-6.
- **If the player selects/inspects during the opponent's turn or a resolution phase**: **read-only inspection is allowed**; no command input is accepted until the player's Action phase resumes (CR-11).
- **If a Defensive Structure is the actor**: its **Attack** verb prices at the queried `DEFENSIVE_ATTACK_COST` (1), not `attack_cost` (2) — D-2's affordability predicate uses whichever cost the query returns for that actor, so the interface needs no special-casing.

## Dependencies

**Upstream — Hard** (this interface cannot function without these; it is pure presentation over their queries):

| System | Data interface consumed | Direction / nature |
|---|---|---|
| **Movement System** (#5) | `reachable(unit) → {tile, min_cost, is_surcharged}` (query); `move(unit, dest)` (commit) — **`is_surcharged` is landed in Movement's GDD** (OQ-2 resolved) | Hard — reachable overlay + cost preview |
| **Combat Resolution** (#6) | `legal_targets(unit)`, `preview_damage(atk, tgt)`, **`legal_targets(unit, from_tile)`** (queries); `attack(atk, tgt)` (commit) — **`legal_targets(unit, from_tile)` (hypothetical-tile targeting for D-3) is landed in Combat's GDD** (OQ-1 resolved) | Hard — target overlay, damage preview, 3 blocked-shot states, honest after-move attack signal |
| **Base & Production** (#7) | `legal_build_tiles`, `legal_deploy_tiles`, `completed_outpost_count`, per-producer `production_cap` remaining (queries); `build()`, `produce()`, `cancel_build()` (commits) | Hard — build/produce pickers, placement overlays, timers, refund preview |
| **AP & Credits Economy** (#3) | `ap_can_afford(player, amount)`, `credits_can_afford(player, amount)`, `current_ap(player)`, `current_credits(player)`, `credit_income(player)` (queries) | Hard — the dual affordability gate every verb routes through (D-2); the named "greyed vs. available" handoff, now spanning two pools |
| **Game State & Turn Manager** (#2) | reads `active_player` / phase / entities; routes all commits through `apply_action`; routes End Turn | Hard — scopes the interface to the active player's Action phase (CR-11); owns the atomic-commit entry point |

**Sibling / coordination (soft):**

- **Game HUD** (#10) — a co-presentation system, not a dependency this interface *needs* to function. **Game HUD is now authored (`design/gdd/game-hud.md`, 2026-07-22)** and its text documents all three #9↔#10 seams as resolved (game-hud.md CR-8, the "Ownership seam summary", and its Dependencies section): (1) the player-level **Build** entry affordance is the HUD's persistent Build button + hotkey, which hands off to this GDD's build-placement preview and atomic commit (CR-5); (2) the *visual style* of overlays and the AP-pool counter live with the HUD + art bible, while this GDD owns their *interaction behavior and information content*; (3) the inline `projected_remaining_ap` renders on the HUD's AP counter as `current → projected` (number owned here, counter owned by the HUD). Two of these seams carry cross-system timing/ownership constraints that must hold in both docs — see the Visual/Audio and Tuning-Knobs notes on `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` and the commit-flash↔AP-tick shared-signal ownership.

**Indirect (transitive, not a direct interface):**

- **Unit System** (#4) — the interface displays unit state (`has_attacked`, produce/attack costs, stats in the inspection panel), but **always through** the queries of Movement/Combat/Base & Production, never by reading Unit data directly. No direct Unit interface; listed for traceability only.

**Downstream dependents:** **None.** No system depends on the Command & Action Interface — it is a leaf presentation node. (This is expected for a UI system: it consumes many interfaces and is consumed by none.)

**Two reciprocal contract obligations (opened by the first design-review, landed same-day):**
1. **Movement (#5)** — the per-tile `is_surcharged` flag on `reachable()`'s return, delivering CR-9's in-cap/over-cap split (OQ-2). **Landed** in movement-system.md 2026-07-22.
2. **Combat (#6)** — the hypothetical-tile query `legal_targets(unit, from_tile)`, delivering D-3's honest after-move attack preview (OQ-1). **Landed** in combat-resolution.md 2026-07-22. Optionally `preview_damage(atk, tgt, from_tile)` if the after-move preview is later extended from a binary signal to a damage readout — not yet requested.

Both contracts' query signature + perf budget remain owed to `/architecture-decision`. Verified consistent by `/consistency-check` (2026-07-22, full scan) — signature, purity, and semantics match across all three docs.

**Purity enforcement (owed, not assumed):** CR-2/CR-10 lean on every preview query (`reachable`, `legal_targets`, `preview_damage`, `ap_can_afford`, `credits_can_afford`, and the two new hypothetical-tile queries) being genuinely **side-effect-free** — idempotent, mutating no game state (no AP, no Credits, no hp, no signals any other system treats as gameplay-meaningful). This interface cannot enforce that from the outside; it is a contract obligation on the dependency systems, verified in *their* test suites and named in the ADR — not something this UI's own tests can cover.

**Bidirectional-consistency check (verified 2026-07-22, re-confirmed by `/consistency-check` full scan same day; interface renamed AP Economy → AP & Credits Economy 2026-08-05 pivot, no reciprocity break):** Movement, Combat, Base & Production, AP & Credits Economy, and Game State & Turn Manager each already list Command & Action Interface as a downstream Hard dependent in their own Dependencies sections — reciprocity is clean for the *existing* interfaces, and the two reciprocal contracts above are now landed, not outstanding.

### ★ Reciprocal downstream — the wave-2 systems (added 2026-08-24, S6-09)

Cross-review **W-1**: All 3 systems below declare a dependency on this document, and this
document listed none of them. Reciprocity was **0/11 across the corpus** — every new GDD pointed
up, no old GDD pointed back, so reading only this file gave no hint that changing it would break
them. Restored mechanically; the relationship nature is copied from each new GDD's own
Dependencies table, which remains the authority.

| Downstream system | Nature |
|---|---|
| **Damage Types (#18)** | Hard |
| **Unit Abilities (#19)** | Hard |
| **Unit Upkeep (#15)** | Soft |

## Tuning Knobs

> **All knobs here are UX-feel values.** Per the Pass-Through Invariant, the Command & Action Interface owns **no balance constant** — cost/damage/income knobs live in Movement, Combat, Base & Production, and AP & Credits Economy. Changing any knob below alters *feel and legibility*, never game balance.

| Knob | Default | Safe range | What it affects / what breaks at extremes |
|---|---|---|---|
| `PREVIEW_HOVER_LATENCY_MS` | 0 (instant) | 0–120 ms | Delay before an overlay/cost readout appears on hover. 0 = maximally responsive (Pillar 3 ideal). Above ~120 ms the preview feels laggy and the "read before you commit" fantasy erodes. |
| `SHOW_COST_ON_DISABLED` | true | bool | Whether hovering a *disabled* verb still shows its cost + shortfall (see Edge Cases). true teaches players *why* they can't act; false declutters but hides the reason. |
| `UNSPENT_AP_REMINDER` | on | on / off | The non-blocking "X AP will be lost" End-Turn reminder (Section E decision). Player-configurable. off suits veterans; on protects new players. Never becomes *blocking* — that's a different (rejected) design. |
| `AFTER_MOVE_ATTACK_PREVIEW` | on | on / off | Whether D-3's honest "attack-possible-after-move" marker is drawn on reachable tiles. off falls back to pure one-action-at-a-time previews. Because the signal is now a *guarantee* (backed by `legal_targets(unit, from_tile)`), turning it off is a legibility/clutter choice (Pillar 3), **not** an honesty fix — there is no longer a misread-as-legality risk to mitigate. |
| `INPUT_LOCK_MS` | 120 ms | 60–250 ms | Post-commit **UX debounce** window. It is **not** the double-commit safety guard — true single-commit is guaranteed structurally by the engine's synchronous single-threaded input dispatch plus the FSM's immediate state transition (CR-6). This knob debounces a *rapid legal second click landing during the commit-flash/AP-tick window*. **Hard constraint: `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS`** (Game HUD #10's tick-down animation) so the input lock always outlasts the animation it must protect — otherwise the Section-C sequencing guarantee breaks. Default raised from 80→120 ms to satisfy this against the HUD's 120 ms `AP_TICK_DURATION_MS` default. Too low re-opens the visual-overlap window; too high makes fast deliberate play feel unresponsive. |
| `HOVER_AUDIO_DEBOUNCE_MS` | 60 ms | 40–120 ms | Minimum interval between hover-tick sounds, so sweeping the cursor across many tiles at `PREVIEW_HOVER_LATENCY_MS = 0` doesn't fire a stacked wall of ticks (audio fatigue — Visual/Audio D). Decoupled from `PREVIEW_HOVER_LATENCY_MS` (which governs *visual* readout latency); the hover tick re-fires on **tile change**, rate-limited to this interval. |
| `DESELECT_ON_COMMIT_IF_SPENT` | true | bool | Whether an entity auto-deselects after its last legal action commits (vs. staying selected showing an all-disabled menu). true keeps the board clean; false lets the player linger on a spent unit's inspection. |
| `MENU_KEYBOARD_NAV` | on | on / off | Whether the contextual action menu is fully keyboard/gamepad navigable (technical-preferences mandates click-reachability + keyboard where practical; this keeps the gamepad port feasible). off is mouse-only — acceptable only as a fallback, not a shipping default. |

**Knob interactions:** `SHOW_COST_ON_DISABLED = false` makes the "insufficient AP" labeling edge case moot (nothing shown to mislabel). `AFTER_MOVE_ATTACK_PREVIEW = off` removes D-3's marker, simplifying the move overlay to just in-cap/over-cap (CR-9) — the marker and the surcharge split must be visually distinct when both are on, so if legibility testing fails, prefer disabling the after-move marker over weakening the surcharge distinction (the surcharge split is a *hard* Movement requirement; the after-move preview is a *convenience*, though — unlike before — an honest one). **`INPUT_LOCK_MS` and Game HUD's `AP_TICK_DURATION_MS` are cross-system-coupled** (`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS`); they must be co-tuned by whoever owns each doc, and a lint/CI check enforcing the inequality is a candidate for the implementation ADR.

## Visual/Audio Requirements

> *No art bible exists yet — this section works from the Visual Identity Anchor in `game-concept.md` and is **provisional pending `/art-bible`**. It is the second precedent-setting Visual/Audio pass after Combat Resolution; color/channel assignments (brightness = affordability, pattern = exclusion reason, hue = actor/faction only) should be reconciled with Combat when the art bible is authored.*

### A · VFX / Visual Feedback

**Governing rule:** the **AP counter is the only element that animates on a real commit, and must never animate on anything else** (hover, cancel, illegal click, selection). It is the interface's trust-critical ledger — treat it like a ledger, not a decoration.

| Event | Animates | Stays still |
|---|---|---|
| **Selection** | Thin **neutral white/grey** outline breathe (~1.5s) on the entity — *never faction hue* (hue = ownership, not focus); action menu fades in (150ms) and doesn't move | The board — no camera pan/zoom |
| **Hover-preview** | Overlay/targets fade in ~80–100ms; numbers **snap in, never count up** (counting implies uncertainty, contradicting CR-2's guarantee) | Menu + selected entity — no relayout |
| **Commit / spend** | Flat faction-hue confirm flash on the tile/target (~40–50 ms) **synced within one frame** to a chunky discrete AP-counter tick-down — the two read as *one* event (see shared-signal note below) | Rest of board; menu re-filter is a silent recompute |
| **Illegal click** | Small contained shake (2–3px, ~150ms) on the target tile — *not* a red flash; reads "refused," not "error" (CR-6 already blocks the spend) | Overlays never flicker/reset on an illegal click |
| **Cancel / back-out** | Overlay fades out at the same rate it faded in (symmetry = "cost you nothing," reinforces CR-7) | **AP counter must not twitch** — motion only ever means a real spend |

> **Shared-signal ownership (commit-flash ↔ AP-tick).** The commit flash lives in **this system (#9)**; the AP-counter tick-down lives in **Game HUD (#10)**. "Synced within one frame" is only achievable if both animations fire off **one shared event**, not two independent reactive renders. **Ownership rule:** the atomic `apply_action` result (routed through Game State & Turn Manager) is the single trigger; #9's flash and #10's tick each subscribe to that one signal and start on the same frame. Neither system polls for an AP delta independently. This is the mechanism the ADR must lock in; without it the two animations can desync by a frame. Durations are given in **ms, not frame counts** (frame-rate-independent per coding standards); easing is deferred to `/ux-design` with the default convention **ease-out unless stated** (fades, flash, breathe) so nothing ships as unspecified linear motion.
>
> **Attack commit fires no interface audio** (Section D): on an attack commit, #9 renders only VFX; the *sound* is triggered by Combat's own resolution off the same shared event — exactly one system calls `play()`, so there is no double-trigger. This ownership must read identically in Combat's GDD.

### B · Overlay Color Language (the load-bearing part)

**The tension:** two faction hues + AP feedback already own "saturated hue = matters." Overlays need ~7 semantic classes **without minting new saturated hues.** Solution: overlays speak in **brightness** (bright = actionable/affordable, muted = excluded/inert), **pattern/hatch** (each exclusion reason its own pattern), **outline** (solid = hard stop, dashed = permeable, none = doesn't exist here), and **glyph** (the colorblind-critical tertiary layer). Saturated hue stays reserved for factions, AP, and the valid-target-lock accent.

1. **Move in-cap vs over-cap** — in-cap: bright cool-white, solid, static. Over-cap: same brightness + **warm amber-grey tint + 45° diagonal hatch** (hatch is the load-bearing signal; tint is redundant). Boundary seam drawn 1px brighter. Shrinking cap on reselection = just a smaller in-cap zone (CR-10), no special animation.
2. **Move blockers** — pass-through friendly: normal overlay + **dashed** unit outline. Blocking friendly structure: **solid outline, no fill**. Enemy blocker: terrain-dark + solid stop-glyph (*not* enemy hue — a blocked-marker isn't an actor). Impassable: **no overlay treatment at all** (terrain that stays dark *is* the signal).
3. **Attack targeting** — valid target: bright **target-lock accent** ring (bracket-corners shape) + damage number in **neutral white** for a non-lethal hit. **Lethal-hit exception (carried from Combat):** Combat's Visual/Audio establishes a distinct treatment when the previewed damage would *kill* the target — this GDD **inherits that exception** rather than dropping it (the earlier "no rarity ramp, per Combat" applied only to the *non-lethal* damage number). This is load-bearing for this system's own fantasy — the anchor moment ("*one short of the kill*") is only legible if lethal vs. one-short reads at a glance. The exact lethal treatment (color/glyph) is reconciled with Combat in `/art-bible`; that it must exist is not optional. Blocked-by-friendly: solid **stop-glyph** ("positioning rule, not punishment"). Out-of-range: ray **fades to nothing** (no glyph — "the world ends here"). AREA dead-zone: **muted/hatched non-neon** (reuses Combat's established dead-zone treatment). Cover: muted **shield/chevron glyph** on the defender tile (shape carries meaning, not color).
4. **Build placement** — legal tile: bright cool-white (same "go-tile" word as in-cap move + deploy). Not-adjacent-to-friendly: **dot-dither** + tiny friend-icon. Too-close-to-enemy: **steep/cross-hatch** (distinct angle from over-cap's 45°) + tiny enemy-icon. The two exclusions must be **pattern- and glyph-distinct**, not just color-distinct.
5. **Deploy overlay** — same bright cool-white "go-tile" treatment as legal build + in-cap move (one learned "you may place here" language).
6. **Under-construction structures** — eventual faction hue **heavily desaturated + reduced brightness** ("ghost of its finished self") + **scaffold-hatch** + neutral-white **turns-remaining numeral** badge. Desaturation itself = "not yet real." (The one place faction hue appears reduced — it still says *whose* it will be.)
7. **After-move attack marker (D-3)** — now that D-3 is an *honest* signal (a legal, affordable attack really does exist from the tile — see Formulas D-3), the marker **may read as actionable**, because it now truthfully promises one. Use a small **target-lock glyph echo** on the reachable tile (a shrunk/dimmed version of the attack-target bracket-corners of B.3), so its meaning — "you could attack from here" — is legible by shape-association with the real attack overlay, while its reduced size/brightness keeps it clearly a *move-overlay* annotation, not the live attack overlay itself. This must stay distinct from both the in-cap "go-tile" fill and the live target-lock ring. (The former glyph-only "must never look actionable" rationale is retired — the signal is a guarantee now, so looking actionable is correct.)
8. **Disabled menu verbs** — greyscale label + lock-glyph + reason text (UI chrome, safe to use standard disabled conventions; always paired with the reason per CR-4/CR-8).
9. **Action menu chrome** — dark neutral panel ("stage furniture, not an actor"), neutral-white verbs, with a **thin faction-hue accent edge** as the single restrained "this is your menu" touch.

### C · Anchor Principles & Risks

- **Load-bearing constraint:** Principle 3 (*Dark stage, neon actors*) + "neon means: this matters" *is* this system's design brief — every overlay decision keeps board-marking out of the neon register so faction/AP feedback stays legible.
- **Risk — neon overload / board wash-out (Pillar 3):** mitigated structurally — the state machine guarantees **only one overlay mode is active at a time** (IDLE / ENTITY_SELECTED / PREVIEW_* are mutually exclusive). Confirm in playtest that the commit-flash + AP-tick pairing doesn't feel like "too much" during rapid move→attack chains; the named lever if it does is shortening the flash or raising `INPUT_LOCK_MS` (not removing the AP-tick, which is trust-critical).
- **Risk — shared "go-tile" language across three verbs (named, not deferred):** in-cap move, legal build, and legal deploy all use the same bright cool-white "you may place/go here" treatment (B.1/B.4/B.5). This relies entirely on the player knowing *which preview mode they are in* (the state machine keeps only one active), with **no board-level disambiguation** of the fill itself. Acceptable because the modes are mutually exclusive and each is entered by an explicit verb, but it is a real legibility bet — the mode indicator (which verb is active) must be unmistakable. Reconcile in `/art-bible`; watch in playtest for "which action am I mid-preview of?" confusion.
- **Risk — the 9-class non-hue overlay taxonomy (B) is a heavy parse load** for a "read the board at a glance" pillar, and the vocabulary (multiple hatch angles, dot-dither, stop-glyph, bracket-corners, scaffold-hatch, crosshair echo…) assumes glyph literacy the onboarding curve must build progressively, not dump on turn one. **A dedicated legibility playtest — greyscale/colorblind-sim, timed board-reads — is a named required deliverable of `/art-bible`**, not an optional check.
- **Sequencing discipline (carried from Combat's pass):** the commit flash + AP-tick of one action must **fully resolve before the next preview renders**, even in a fast chain. This is enforced by the `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` constraint (Tuning Knobs) — at the prior 80 ms default the lock released *before* the 120 ms tick finished, breaking the guarantee; the default is now 120 ms with the inequality documented in both #9 and #10.
- **Highest-risk element:** the shared-signal sync between #9's commit flash and #10's AP-tick (Section A note) — it requires a single shared trigger, not two reactive renders, and is the item most likely to desync if the ADR doesn't lock the ownership. D-3 is **no longer** a top risk: funding the real `legal_targets(unit, from_tile)` query converted it from a possibly-misleading hint into a guarantee (Formulas D-3), so the former misread risk is designed out rather than merely styled around.

### D · Audio (synthwave-crisp — short, clean, synthetic)

| Event | Character |
|---|---|
| Select | Crisp short rising "confirm" blip (~80ms), same regardless of faction/unit |
| Hover | Near-silent soft tick, **debounced via `HOVER_AUDIO_DEBOUNCE_MS`** (default 60 ms; re-fires on tile change, rate-limited) so sweeping the cursor at `PREVIEW_HOVER_LATENCY_MS = 0` doesn't fire a stacked wall of ticks |
| Commit — Move | Short synth "whoosh-settle" (displacement, no literal footstep) |
| Commit — Attack | *No interface sound.* **Combat owns triggering** the per-weight-class cue off the shared `apply_action` event (Section A shared-signal note); #9 calls `play()` for zero attack audio, so exactly one system fires it — no double-trigger. This ownership must read identically in Combat's GDD. |
| Commit — Build | Heavier low "stamp/lock-in" — weighty, reflects the investment |
| Commit — Produce | Brief ascending arpeggio — "something new enters the world" |
| Cancel Build | **A commit-class event, not a refusal.** Inverse of the Build stamp (same voice, reversed) — reads as a *deliberate undoing that refunds Credits* (the AP surcharge already spent is not refunded), weighty like the Build stamp it mirrors. Do **not** file it with the illegal-click/back-out "nothing happened" sounds — it is a successful, Credit-refunding commit (see CR-6a, States table) and belongs in the commit family. |
| Illegal click | Soft low **deny tone** — muted, never a harsh buzzer ("not allowed," not "you erred") |
| Cancel / back-out | Quick downward "sweep-close," distinctly *calmer* than the deny tone (free action, not refusal) |
| AP fill (start of turn) | Ascending arpeggio scaling with income — the one "celebratory" beat |
| AP tick-down (per spend) | Sharp dry percussive "tick," **discrete and countable** by ear, paired 1:1 with the digit-drop |
| End Turn | Firm synth "hand-off" cue — must read as distinct from **all three** descending/resolving cues it neighbours: Combat's death power-down, Game HUD's defeat cue, and the HUD's enemy-turn stinger (never reads as a loss). Cross-check against game-hud.md Section C for the full "descending" set. |

**Retrigger / fatigue discipline (audio parallel to Section C's visual sequencing):** the same `INPUT_LOCK_MS`-gated sequencing that orders the *visuals* also governs audio — a commit-class stinger must resolve (or duck/truncate) before the next one plays, never stack. During a rapid move→attack→produce chain (AC-25), same-category retriggers **duck rather than layer**. Two ascending "celebratory" cues coexist within one turn (AP-fill arpeggio, Commit-Produce arpeggio) and **must be timbrally distinct** (different voice/interval), so a mid-turn produce is never mistaken for a turn-start fill. Reuse of the Build-stamp for #10's structure-complete is an open question on the HUD side (game-hud.md OQ-6) — cross-referenced here so the shared cue's start-vs-completion ambiguity is visible from both docs.

### E · Accessibility — Colorblind-Safe Redundancy

Because the whole language leans on brightness/pattern, the system is largely self-solving — but these distinctions must carry a **non-hue** redundant cue: in-cap vs over-cap (**hatch mandatory**, not just warm/cool tint); the four attack states (distinct **shapes**: bracket-corners vs stop-glyph vs fade vs hatch); cover (**glyph shape only**, no color-ramp — glyph-fill for tiers if ever added); build exclusions (**distinct glyphs** friend-icon vs enemy-icon, mandatory — hatch angle is a weak channel alone); under-construction (turns-remaining numeral as ultimate fallback). **One open gap larger than this GDD:** faction-hue-as-identity has no confirmed shape/pattern fallback yet — this interface can only consume whatever per-faction insignia the eventual art bible defines; re-flagged for `/art-bible`.

> 📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:command-action-interface` to produce per-asset visual descriptions and generation prompts from this section.

## UI Requirements

### Element inventory (what this system contributes to the screen)

| Element | Placement principle | Owner boundary |
|---|---|---|
| **Contextual action menu** | Floats near the selected entity, never covering it or the tiles it can act on; auto-repositions to stay on-screen at board edges | This GDD owns behavior/content; HUD + art bible own chrome style |
| **Board overlays** (reachable / targets / build / deploy) | Drawn on the grid itself, one mode at a time (state machine) | This GDD owns information content; visual style per Visual/Audio B |
| **Cost / damage readouts** | Anchored to the hovered tile/target, not a fixed panel — the number is where the eye already is (these transient per-tile readouts stay near the cursor; distinct from the persistent detail panel below) | This GDD |
| **`projected_remaining_ap` readout** | Renders on the HUD's AP counter as inline `current → projected` (game-hud.md's resolved seam), updating live on hover | Number owned here; the AP counter it renders on is Game HUD (#10) |
| **`projected_remaining_credits` readout** (D-1b, economic actions only) | Renders on the HUD's Credit counter as inline `current → projected`, shown **alongside** `projected_remaining_ap` for the same preview, updating live on hover | Number owned here; the counter it renders on is Game HUD (#10) — same seam as the AP readout, extended to the second pool |
| **End Turn control** | Fixed, always-visible location (corner); reachable at any time no preview is mid-flight (CR-11) | This GDD owns the interaction; HUD owns placement/style |
| **Detail / inspection panel** | **Edge-docked** (Game HUD owns placement — game-hud.md fixes this, resolving the earlier "near the entity" phrasing); its **content follows this GDD's selection/inspection target**, non-modal | This GDD owns *content*; HUD owns panel *chrome + placement* |
| **Unspent-AP reminder** | Non-blocking toast/inline near End Turn (Section E decision, `UNSPENT_AP_REMINDER`) | This GDD |

### Input mapping (mouse-primary; keyboard/gamepad-feasible)

Per `technical-preferences.md`: **every core action must be reachable by click, and by keyboard where practical**, so a gamepad/cursor port stays feasible.

| Input | Mouse | Keyboard / Gamepad |
|---|---|---|
| Select / commit | Left-click | Confirm key/button (A) on the focused tile/verb |
| Cancel / back-out | Right-click **or** ESC | Cancel key/button (B) |
| Move cursor / hover | Mouse move | D-pad / arrow keys move a **board cursor** (drives the same hover-preview). For **long-distance reach**, tile-to-tile stepping is too slow — provide a **cycle/jump**: a shoulder-button (or Tab) that jumps the cursor between *salient* tiles only (reachable-set members in Move; legal targets in Attack; legal tiles in Build/Deploy), so a distant target is one cycle-press away, not twenty steps |
| Open action verb | Click the menu verb | Focus + confirm the verb (menu is fully keyboard-navigable, `MENU_KEYBOARD_NAV`) |
| End Turn | Click the control | Dedicated shortcut (e.g. Enter / Start) |

- **No hover-only interactions** (per `technical-preferences.md`): every preview reachable by mouse-hover must also be reachable by moving the keyboard/gamepad board cursor onto the tile — the cursor position *is* the hover for non-mouse input.
- **Three distinct focus/attention states (not two).** The word "focused" covers two *architecturally different* things in this interface, plus a third the earlier draft omitted — all three need visually distinct, non-hue-redundant indicators:
  1. **Mouse-hover** — the tile/target under the pointer (existing hover treatment).
  2. **Board cursor** — the D-pad/arrow-key cursor position over the grid. This is **not a Godot `Control` focus concept**: Godot's `Control` focus-neighbor system is built for discrete UI widgets, not a free cursor over a `TileMapLayer`, so the board cursor is a **custom `BoardCursor` construct** (a `Vector2i` grid position driven from input actions), architecturally separate from menu focus. It needs its own on-board indicator, distinct from mouse-hover (they usually coincide, but can diverge). Visual/Audio B currently specifies no cursor glyph — an art-bible gap now named.
  3. **Menu keyboard-focus** — the highlighted verb in the contextual action menu. *This* is real Godot `Control` dual-focus, and it is where the **Godot 4.6 dual-focus caveat** genuinely applies: mouse focus and keyboard/gamepad focus are separate subsystems in 4.6, both can be active at once, so the menu needs a keyboard-focus indicator distinct from mouse-hover.
- **Input-precedence rule (design decision, resolved here — not deferred):** when mouse-hover and the board cursor point at different tiles, **the most-recently-moved input wins** — a mouse motion takes the hover; the next directional press hands it back to the board cursor. The cost/damage readout and D-3 marker follow that single active locus, so the CR-2 "which preview am I looking at" guarantee is never ambiguous.
- **Deferred to ADR (implementation, not design):** the *pixel rendering* of the three indicators, the `BoardCursor` ↔ `Control`-menu focus wiring, and confirming **Redot 26.2 inherited Godot 4.6's dual-focus behavior unmodified** (fork-divergence risk — verify, don't assume 4.6 parity). See OQ-6.

### UX flow (the one loop, restated as a player flow)

`Select entity → action menu (legal+affordable verbs) → pick verb → board enters preview (overlay + live cost/damage on hover) → single-click a highlighted option → commit (AP ticks, board updates) → menu re-filters for the same entity → repeat or Wait/deselect → End Turn`

Cancel (right-click/ESC) exits any preview to the menu, or the menu to IDLE, spending nothing at every step.

### Coordination boundary with Game HUD (#10)

This system owns **selection, previews, the action menu, and commit routing**. The HUD owns the **persistent AP counter, income breakdown, turn/round indicator, and action log**. **Game HUD (#10) is now authored** and the three seams are resolved in game-hud.md: (1) the player-level **Build** entry affordance is the HUD's persistent Build button + hotkey handing off to this GDD's build-placement preview (CR-5); (2) `projected_remaining_ap` renders inline on the HUD's AP counter as `current → projected`; (3) the detail/inspection panel's content follows this GDD's selection while the HUD owns its edge-docked chrome. The remaining cross-system constraints (not "seams to reconcile" but "invariants to hold in both docs") are `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` and the commit-flash↔AP-tick shared-signal ownership.

> **📌 UX Flag — Command & Action Interface**: This system has substantial UI requirements. In Pre-Production, run `/ux-design` to produce a UX spec for the action menu, board-overlay interaction, and the pre-commit flow **before** writing epics — stories should cite `design/ux/[screen].md`, not this GDD directly. (Noted against System #9 in the systems index.)

## Acceptance Criteria

Each criterion is independently verifiable by a QA tester without reading this GDD. **Type**: Logic (automatable unit/integration test — BLOCKING), Integration (multi-system — BLOCKING), or Visual-Feel (advisory — screenshot/playtest + lead sign-off). **Covers**: the Core Rule / Formula it verifies.

| # | Criterion | Type | Covers |
|---|---|---|---|
| AC-1 | GIVEN an owned unit with ≥1 legal action, WHEN selected, THEN the menu opens and every enabled verb independently satisfies its D-2 predicate — `is_legal AND ap_can_afford` for Move/Attack, `is_legal AND credits_can_afford AND ap_can_afford` for Produce/Build/Research; no failing verb appears enabled | Logic | CR-1, CR-4 |
| AC-2 | GIVEN an enemy/neutral entity, WHEN clicked or hovered, THEN the interface exposes read-only inspection data for it and **never enters ENTITY_SELECTED** (no command menu opens), in any phase | Logic | CR-3 |
| AC-3 | GIVEN Entity A selected, WHEN the player clicks empty terrain / ESC / a different owned entity B, THEN selection clears / clears / switches to B, menu re-filtered accordingly | Logic | CR-3 |
| AC-4 | GIVEN any previewed action showing exact value N, WHEN committed, THEN the resource(s) change by exactly N — Move/Attack change only AP; Produce/Build/Research change **both** `current_credits` (by the Credit main cost) **and** `current_ap` (by the AP surcharge), each by exactly its previewed value — tested once per action family (move/attack/produce/build) | Logic | CR-2 |
| AC-5 | GIVEN current_ap=9 and a previewed move costing 6, THEN `projected_remaining_ap` displays 3; a separate attack preview costing 2 independently displays 7 (never summed) | Logic | D-1, D-4 |
| AC-5b | GIVEN current_ap=9 and current_credits=8, and a previewed Build costing build_cost=4 Credits + BUILD_AP_COST=2, THEN `projected_remaining_credits` displays 4 **and** `projected_remaining_ap` displays 7, shown together for the same preview (never blended into one number) | Logic | D-1, D-1b, D-4 |
| AC-6 | GIVEN current_ap=1 and an attack costing 2, WHEN the menu renders, THEN Attack is disabled with reason "insufficient AP" and is not clickable | Logic | D-2, CR-8 |
| AC-6b | GIVEN current_credits=4 and a Build costing build_cost=6 Credits (current_ap sufficient for BUILD_AP_COST), WHEN the menu renders, THEN Build is disabled with reason "insufficient Credits" (the Credit pool is the binding shortfall) and is not clickable; GIVEN the reverse (Credits sufficient, AP surcharge short), THEN Build is disabled with reason "insufficient AP" instead | Logic | D-2, CR-4, CR-8 |
| AC-7 | GIVEN a unit with has_attacked=true, WHEN selected, THEN Attack is disabled with reason "already attacked," regardless of AP | Logic | D-2 |
| AC-8 | GIVEN a target both out-of-range AND unaffordable, WHEN Attack is evaluated, THEN Attack is disabled and **both** failure reasons are surfaced (range/legality AND the AP shortfall) — so fixing one does not reveal the other as a surprise | Logic | D-2 |
| AC-8b | GIVEN an economic verb (e.g. Build) that is both illegal (no legal tile) AND short in **both** Credits and AP, WHEN evaluated, THEN it is disabled and **all failing reasons are surfaced together** (legality, Credit shortfall, AP shortfall) — no reason is hidden for the player to discover later | Logic | D-2, CR-4 |
| AC-9 | GIVEN an empty `reachable` or `legal_targets` set, WHEN selected, THEN the verb is disabled with its specific reason, not hidden or erroring | Logic | CR-4, Edge |
| AC-10 | GIVEN a fully-spent entity / producer with `production_cap` exhausted / no legal deploy tile, WHEN selected, THEN it still selects, verbs disabled-with-reason, Wait clickable | Logic | CR-4, Edge |
| AC-11 | GIVEN current_ap=9, Scout, a reachable tile costing 3 with a legal enemy target in range from it, attack_cost 2, WHEN previewing the move, THEN that tile shows the D-3 attack-possible marker; a reachable tile with **no** target in range from it, and an 8-cost (move+attack unaffordable) tile, do **not** | Logic + Visual-Feel | D-3 |
| AC-12 | GIVEN a unit with has_attacked=true, THEN **no** tile is ever marked attack-possible regardless of AP or position; AND GIVEN a marked tile, WHEN the unit moves there, THEN a legal affordable attack genuinely exists (the marker is a guarantee, never a false promise) | Integration | D-3, Edge |
| AC-13 | GIVEN a move preview, WHEN the player clicks a non-highlighted tile, THEN no AP is spent and no move occurs | Logic | CR-6 |
| AC-14 | GIVEN any preview open, WHEN right-click / ESC, THEN nothing commits, no AP spent, interface backs out one level | Logic | CR-7 |
| AC-15 | GIVEN a committed action, WHEN any undo input, THEN no undo is available; the spent AP / applied effect stays final | Logic | CR-7 |
| AC-16 | GIVEN the Build command invoked in Action phase, THEN each structure type shows `build_cost` (Credits) + `BUILD_AP_COST` (AP surcharge) + `build_time`, is **dual-cost affordability-gated** (`credits_can_afford AND ap_can_afford`), and placement preview restricts to `legal_build_tiles` with the two exclusion reasons distinguishable by glyph/pattern (not color alone) | Logic + Visual-Feel | CR-5, CR-9 |
| AC-17 | GIVEN an under-construction structure, WHEN selected, THEN the menu offers only Cancel Build showing exact `floor(build_cost × CANCEL_REFUND_RATE)` **Credit** refund, AND the structure reads as unmistakably unfinished/inert with a turns-remaining numeral shown; a Completed structure never offers Cancel Build | Logic + Visual-Feel | CR-9, Edge |
| AC-18 | GIVEN the player performs the **distinct Cancel-Build gesture** (CR-6a), THEN `current_credits` increases by exactly the previewed refund (the `BUILD_AP_COST` surcharge already spent is **not** refunded — only the Credit main cost is) and the interface returns to ENTITY_SELECTED (refreshed) or IDLE; AND a **bare single left-click never triggers Cancel Build** | Logic | CR-6a, CR-9, States |
| AC-19 | GIVEN a blocker dies to a committed attack, WHEN re-entering Move preview for an affected unit, THEN the reachable overlay reflects the new board state — no reselect trick / reload | Integration | CR-10 |
| AC-20 | GIVEN a tile becomes illegal between preview entry and commit click, WHEN clicked, THEN the commit is rejected, no AP spent, overlay refreshes, player stays in menu | Integration | CR-10, Edge |
| AC-21 | GIVEN the opponent's turn / a resolution phase, WHEN clicking/hovering any entity, THEN inspection shows but no menu opens and nothing commits; command input resumes only in own Action phase | Logic | CR-11 |
| AC-22 | GIVEN a preview mid-flight, WHEN End Turn pressed, THEN the preview backs out first (nothing commits), then the turn ends | Integration | CR-11, Edge |
| AC-23 | GIVEN unspent AP > `AP_CARRYOVER_CAP`, WHEN End Turn pressed, THEN a non-blocking reminder shows, End Turn proceeds, and only the excess above the cap is lost at the next reset (AP up to the cap carries over, it is not discarded); GIVEN unspent Credits > 0, THEN no reminder shows and no Credits are ever lost (unbounded banking) | Logic + Visual-Feel | Edge, `UNSPENT_AP_REMINDER` |
| AC-24 | GIVEN an enabled action, THEN `projected_remaining_ap` ≥ 0. GIVEN a disabled-for-insufficient-AP action, THEN the value may be negative internally but the UI shows "insufficient AP," never a negative number | Logic | D-1, Edge |
| AC-24b | GIVEN an enabled economic action, THEN `projected_remaining_credits` ≥ 0. GIVEN a disabled-for-insufficient-Credits action, THEN the value may be negative internally but the UI shows "insufficient Credits," never a negative number | Logic | D-1b, Edge |
| AC-25 | GIVEN a unit that just committed a move and retains AP ≥ attack_cost with a target in range, WHEN the menu re-filters, THEN Attack appears enabled (move→attack = two atomic commits, one fluid sequence) | Integration | CR-4, States |
| AC-26 | GIVEN a Defensive Structure actor, WHEN previewing its attack, THEN the cost shown and subtracted is the queried `DEFENSIVE_ATTACK_COST` (1), not `attack_cost` (2) | Logic | D-2, Edge |
| AC-27 | GIVEN two commit inputs in rapid succession (double-click), THEN exactly one commit fires and the resource change applies exactly once (guaranteed structurally by synchronous input dispatch + immediate FSM transition; `INPUT_LOCK_MS` debounces the visual commit window), the second input inert | Integration | CR-6, Edge |
| AC-28 | GIVEN an attack preview with blocked-by-friendly, out-of-range, and AREA-dead-zone all present, THEN each is identifiable with color removed (greyscale/colorblind sim) via distinct shape/pattern alone, and the damage number is post-cover/post-defense with a cover glyph on the defender tile | Visual-Feel (advisory) | CR-9 |
| AC-29 | GIVEN a Move preview containing both in-cap and over-cap (surcharged) tiles, THEN the two sets are distinguishable with color removed (greyscale/colorblind sim) via hatch/pattern alone, and each tile's per-tile AP cost is shown | Visual-Feel (advisory) | CR-9 |
| AC-30 | GIVEN a unit with tiles_moved_this_turn > 0 that is reselected, WHEN Move preview reopens, THEN the in-cap tile set is recomputed against current tiles_moved_this_turn and is a strict subset of the unit's full-AP in-cap set (the cheap zone visibly shrinks) | Logic | CR-9, CR-10 |
| AC-31 | GIVEN a Move preview where pass-through-friendly, blocking-friendly-structure, enemy-blocker, and Impassable tiles are all present, THEN all four are visually distinguishable with color removed via distinct outline/glyph/treatment (not color alone) | Visual-Feel (advisory) | CR-9 |
| AC-32 | GIVEN an attacker that commits an attack on a Defensive Structure and dies to its counterattack, THEN `apply_action` fully resolves (attack, counter, win-check) and the interface auto-deselects to IDLE — no dangling selection on the destroyed attacker | Integration | States, Edge |
| AC-33 | GIVEN a Build commit on a legal tile, THEN the interface lands in ENTITY_SELECTED on the **newly-placed structure** (or IDLE if it has no legal action), never on a prior selection | Integration | CR-5, States |
| AC-34 | GIVEN a commit whose win-check sets `match_status = GameOver`, THEN the interface fully resolves the atomic `apply_action` (including any counterattack) exactly as a normal commit would, then transitions to the terminal `GAME_OVER` state — no selection, menu, preview, inspection, or End Turn accepted for the remainder of the session | Integration | CR-11, States |
| AC-35 | GIVEN the **non-committing** player's interface instance (inert during the opponent's Action phase) is active when the opponent's commit sets `match_status = GameOver`, THEN that instance also transitions to the terminal `GAME_OVER` state upon observing the change — no selection, menu, preview, inspection, or End Turn accepted afterward — even though this instance's own commit did not trigger the win-check | Integration | CR-11, States |

> **Routing note — not QA criteria (structural / code-conformance, route to `/architecture-decision`, enforce via review/lint):**
> 1. D-3's predicate composes Combat's `legal_targets(unit, from_tile)` + AP & Credits Economy's `ap_can_afford` — it never *re-implements* targeting or cost math locally.
> 2. The interface holds **zero references to any owning-system balance constant** by name.
> 3. No display value is ever **re-derived by re-implementing an owning formula** (the third Pass-Through Invariant clause — same class as 1–2, previously omitted from this note).
> 4. Every preview query (including the two new hypothetical-tile queries) is **side-effect-free** — a purity contract owed by the dependency systems and verified in *their* test suites, not black-box-testable from this UI.

## Open Questions

| # | Question | Owner | Target resolution |
|---|---|---|---|
| OQ-1 | ~~Should the interface support **"can actually attack after moving here"** previews?~~ **RESOLVED 2026-07-22 — funded into VS scope** (design-review decision). D-3 is now an honest legality+affordability signal backed by a **new Combat query `legal_targets(unit, from_tile)`, landed in combat-resolution.md 2026-07-22**. Remaining work is the ADR (query signature + `reachable`-sized perf budget, see CR-10 Tier 2). Optional future extension: `preview_damage(atk, tgt, from_tile)` to upgrade the binary marker to an after-move damage readout. | technical-director / systems-designer / Combat #6 | `/create-architecture` (contract + perf budget) |
| OQ-2 | ~~Movement's `reachable()` should return an explicit **`is_surcharged` per-tile split**~~ **RESOLVED 2026-07-22 — landed in movement-system.md.** Remaining work is the ADR (final field name/shape). | technical-director (ADR) + Movement | During `/create-architecture` |
| OQ-3 | ~~**Game HUD (#10) coordination seams**~~ **RESOLVED 2026-07-22** — game-hud.md is authored and documents all three seams (Build button hand-off, inline `projected_remaining_ap` on the AP counter, detail-panel content-follows-#9 / chrome-owned-by-HUD). Residual is not a seam but two cross-doc invariants: `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` and the commit-flash↔AP-tick shared-signal ownership (Visual/Audio A). | — (resolved) | Done |
| OQ-4 | **Faction-hue colorblind identity fallback** — the one accessibility gap larger than this GDD (Visual/Audio E). The interface can only consume a per-faction insignia the art bible defines. | art-director | During `/art-bible` |
| OQ-5 | ~~Does single-click commit need an exception for destructive Cancel Build?~~ **RESOLVED 2026-07-22 — yes** (design-review decision): Cancel Build commits only on a **distinct destructive gesture** (CR-6a), never a bare single click. **Re-review 2026-07-22:** CR-6a now also fixes the gesture's structural shape (bounded within `ENTITY_SELECTED`, and using an input-event category a double-click of the same button cannot produce) so `/ux-design`'s eventual pixel-level choice cannot reopen the AC-27 double-click race or require a new FSM state. Only the exact affordance/timing is left to `/ux-design`. | ux-designer (final gesture) | `/ux-design` |
| OQ-6 | **Godot/Redot dual-focus + board-cursor architecture** (scope widened at review): three distinct focus states — mouse-hover, custom `BoardCursor` (not a Godot `Control` focus concept), and menu `Control` keyboard-focus — need distinct indicators; the `BoardCursor`↔menu-focus wiring and the pixel rendering are ADR work. **Also confirm Redot 26.2 inherited Godot 4.6 dual-focus behavior unmodified** (fork-divergence risk). Input-precedence (most-recently-moved-input wins) is resolved in-GDD (Input mapping). | technical-director / godot-specialist | During `/create-architecture` |
| OQ-7 | Does `SHOW_COST_ON_DISABLED = true` (showing cost + shortfall on disabled verbs) add useful teaching or clutter? Tune via the knob. | ux-designer / qa | First playtest |
