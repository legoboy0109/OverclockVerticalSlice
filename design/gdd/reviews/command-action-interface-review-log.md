# Review Log — Command & Action Interface (#9)

## Review — 2026-07-22 — Verdict: MAJOR REVISION NEEDED → revised (pending re-review)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, art-director, audio-director, gameplay-programmer, godot-specialist, creative-director (senior synthesis)
Blocking items: 11 | Recommended: ~9
Summary: First review of #9. All 9 specialists independently found a real blocking issue — surface polish masked a layer of unresolved cross-system contracts. Creative-director's synthesis: strongest-written GDD in the corpus, but three Tier-1 items were direct Pillar-3 / "zero regret" violations (D-3's trained-then-broken trust, Cancel Build's unconfirmed destructive single-click + its audio misclassification) and four Tier-2 items were cross-system contracts that were self-contradictory (`reachable()` signature), undefined (three FSM dead-end transitions), or broken at default tuning (INPUT_LOCK_MS < AP_TICK, unspecified flash↔tick sync). Verdict MAJOR REVISION NEEDED because those are substantive design decisions, not copy-edits.

**Two design decisions taken by the user during the revise-now pass:**
- **D-3** — *funded the real query* (rather than cutting it): rewrote `attack_affordable_after_move` → `attack_possible_after_move`, an honest legality+affordability signal backed by a new Combat query `legal_targets(unit, from_tile)`. The has_attacked bug and the "looks-like-a-promise" pillar violation are now resolved by construction. Resolves OQ-1 into VS scope.
- **Cancel Build** — *distinct destructive gesture* (new CR-6a): commits only on a deliberate distinct gesture, never a bare single left-click. Universal single-click preserved for all non-destructive commits. Resolves OQ-5.

**Blockers resolved in-file (11):** D-3 honest-query rewrite; Cancel Build gesture; Cancel Build audio reclassified commit-class; `reachable()` contract reconciled (both internal tables + `is_surcharged` marked pending → then propagated to Movement); 3 FSM transitions defined (PREVIEW_BUILD commit landing on the new structure, entity-death-mid-resolution → IDLE, has_attacked in D-3); `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` constraint (default 80→120 ms) + reframed as UX debounce; commit-flash↔AP-tick shared-signal ownership + attack-cue single-owner (Combat); CR-10 two-tier (entry-compute vs O(1) hover) + tile-change-gated input; 3 new CR-9 coverage ACs + entity-death + Build-landing ACs (AC-29..33); stale HUD "Not Started" / OQ-3 resolved + detail-panel edge-docked; three focus states named + input-precedence resolved in-GDD.

**Recommended also applied:** AC-8 both-reasons; D-1 negative-range annotation; routing note 3rd + 4th structural claims; Combat lethal-hit exception restored (B.3); go-tile + 9-class legibility risks named for `/art-bible`; audio fatigue/throttle rule + `HOVER_AUDIO_DEBOUNCE_MS`.

**Deferred (correctly scoped, not blocking the GDD):** dual-focus / board-cursor rendering + Redot-26.2-inherits-4.6 confirmation → `/create-architecture` (OQ-6); overlay-legibility playtest gate + go-tile disambiguation + 4-channel-vs-Combat reconciliation → `/art-bible`; final Cancel-Build gesture + long-distance board-cursor reach → `/ux-design`.

**Reciprocal contracts opened & propagated (same session):** Combat #6 (`legal_targets(unit, from_tile)`) and Movement #5 (`reachable().is_surcharged`) — both additive, verdicts unchanged; recorded in their own review logs.

**Housekeeping (outside GDD):** CLAUDE.md's `@docs/engine-reference/redot/VERSION.md` include is dangling — only `docs/engine-reference/godot/` exists.

Prior verdict resolved: First review
Next: re-review in a fresh session (`/clear` first — full re-review runs ~10 agents).

## Review — 2026-07-22 — Verdict: NEEDS REVISION → revised → Approved
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, art-director, audio-director, gameplay-programmer, godot-specialist, creative-director (senior synthesis)
Blocking items: 3 | Recommended: ~14
Summary: Re-review confirming the prior 11 blockers held (none re-litigated). Three new blockers surfaced, one via a genuine three-specialist convergence: systems-designer, gameplay-programmer, and godot-specialist each independently found a different symptom of the same root cause — CR-10's stated "two-tier" recompute model didn't actually describe D-3's frontier-wide query fan-out, the commit-time re-validation point, or the timing relationship to Godot's deferred `queue_free()`. Fixed by rewriting CR-10 to four named tiers and mandating queries read Game State & Turn Manager's logical headless model, not the scene tree. Second blocker (gameplay-programmer): no FSM state existed for a commit whose own win-check ends the match — fixed with a terminal `GAME_OVER` state mirroring Game State & Turn Manager's/Game HUD's existing terminal-state pattern, plus AC-34. Third blocker (ux-designer, gameplay-programmer): CR-6a's deferred Cancel-Build gesture wasn't reconciled against this doc's own AC-27 double-click debounce — fixed with a binding input-shape constraint on `/ux-design`'s eventual choice. All three resolved without needing a new user design decision — each was resolvable from already-established patterns in sibling GDDs (Game State & Turn Manager, Game HUD) or this doc's own existing machinery (AC-27, `INPUT_LOCK_MS`).
Recommended items not applied this pass (routed to their correct owners): art-director's overlay-signifier cap and go-tile mode-indicator gap → `/art-bible`; audio-director's Cancel-Build sonic spec and duck-parameter spec → `/audio-direction`; qa-lead's AC-27/AC-11/AC-16-17-23 rewrites, ux-designer's cycle/jump-nav spec and detail-panel desync risk, ui-programmer's BoardCursor contract, gameplay-programmer's apply_action rollback guarantee, godot-specialist's OQ-6 language tightening and the still-dangling `docs/engine-reference/redot/` include → deferred to `/ux-design`, `/create-architecture`, or a future polish pass.
Prior verdict resolved: Yes — all 11 first-round blockers confirmed still resolved.
Next: none required — Approved. Systems-index.md updated (#9 → Approved).
