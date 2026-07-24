# Review Log — Game HUD (#10)

Tracks `/design-review` verdicts for `design/gdd/game-hud.md` so re-reviews can see what changed.

## Review — 2026-07-22 — Verdict: NEEDS REVISION → revised in-file (re-review pending)
Scope signal: M
Specialists: ux-designer, ui-programmer, game-designer, systems-designer, qa-lead, godot-specialist, gameplay-programmer, audio-director + creative-director (senior). Full mode, 8 specialists.
Blocking items: 5 | Recommended: 10 | Nice-to-have: 3

**Summary (creative-director senior verdict):** The design is coherent and on-pillar — the know/act split and AP-counter-as-first-class-neon are the right load-bearing calls; no pillar-/identity-level objections after the creative pass that Lean-mode authoring skipped. The problems were specification holes, not design errors. Five blockers, all resolvable in-file or via already-scheduled ADR/UX passes. Two were verified directly against source: the Pass-Through formula leak (vs. `entities.yaml`) and the Structure-complete audio-ownership error (a factual error vs. #9's audio table).

**The 5 blockers (all fixed same session — user chose "Revise now"):**
1. **Pass-Through Invariant self-violation** [systems-designer + ui-programmer + CD] — Edge Case hardcoded `1 × min(0, 6) = 0`, naming two AP-Economy constants the HUD's own invariant forbids. Fixed: dropped the formula; added a required decomposition-query-shape contract; added `game-hud.md` to `ECONOMY_TECH_INCOME_BONUS` + `ECONOMY_TECH_TIER_THRESHOLD` `referenced_by`.
2. **CR-1 render-event contract hand-waved** [ui-programmer + godot + qa + gameplay] — no signal names/payloads/ordering, "tick" undefined. Fixed: added push-not-poll contract (signal-bus + dirty-flag coalescing + read-only facade) as ADR seed; AC-1/AC-2 rewritten testable.
3. **Structure-complete audio owner factually wrong** [audio-director + CD] — listed "Shared w/ #9" but it fires on Base & Production's build-timer completion, which #9 has no hook into. Fixed: owner = Base & Production; every shared audio row given a single `play()` owner; AC-20 tests call-site count.
4. **State-model gaps** [ux-designer] — `EndTurn(P)` control-liveness undefined; detail panel silently swaps persistent-selection vs. transient-inspection with identical chrome. Fixed: States table marks controls inert in `EndTurn(P)` (+AC-27); CR-6 mandates distinct visual state + fixes data-flow direction.
5. **CR-3 "state machine" was prose** [ui-programmer + gameplay] — unspecified transition conflicts. Fixed: added CR-3a animation-state table + transition rules (mutual-exclusion, preview echo snaps, upstream serialization).

**User design decisions (3):** OQ-4 whose-AP → persistent OPPONENT label + tint (CR-3b); PIP_MAX_HP boundary → change comparison to `≥`; defeat cue → weighty & desolate (timbral guardrail, not intensity cap), flagged for CD tone pass.

**Also applied (recommended):** AC-3/5/9 split into Logic + Visual-Feel; new AC-23–28; broadened AC-21 to all 5 pass-through mappings; CR-9 coverage flag; mandated late-game legibility playtest + neon contrast floor; OQ-8 camera model; OQ-5 corrected (Redot-parity-unconfirmed vs. Godot 4.6); accessibility E expanded (AP counter luminance audit, glyph-scaling floor, Build button, demote audio to supplementary); CR-8 handoff cue; victory-preemption latency bound (AC-17).

**Files touched:** `design/gdd/game-hud.md` (extensive), `design/registry/entities.yaml` (2 `referenced_by` additions).
Prior verdict resolved: First review.
**Re-review owed:** run `/design-review design/gdd/game-hud.md` in a FRESH session to confirm the 5 blockers are closed and no regressions introduced.

## Review — 2026-07-22 — Verdict: APPROVED (2nd `/design-review`, re-review)
Scope signal: M
Specialists: ux-designer, ui-programmer, game-designer, systems-designer, qa-lead, godot-specialist, gameplay-programmer, audio-director + creative-director (senior). Full mode, 8 specialists.
Blocking items: 2 (both fixed in-file same session) | Recommended: 9 (all folded in same session)

**Summary (creative-director senior verdict):** The 5 first-pass blockers are genuinely closed (3 clean, 2 CLOSED-WITH-RESIDUE — no reopening). The 2 new blockers were the predictable result of two *same-session* first-pass fixes (CR-3a's animation state machine and CR-3b's opponent-AP display) never being cross-checked against each other. Both are small in-file edits, not re-architecture. Everything the specialists over-flagged (test-harness dependency, OQ-5, camera model, chess analogy) was correctly ADR-scoped, already-resolvable, or already-conceded in-doc, and was demoted. Verdict: NEEDS REVISION of the mildest kind → both blockers fixed in-file this session → APPROVED (CD explicitly said a lean re-check of just CR-3a + the audio priority paragraph suffices; no third full 8-specialist spin needed).

**The 2 blockers (both fixed same session):**
1. **CR-3a "mutually exclusive by construction" contradicted by CR-3b + no GameOver transition** [systems-designer F1, gameplay-programmer F1, ui-programmer, ux-designer — 4-specialist convergence, strongest signal]. CR-3a's fill-flourish/preview-echo exclusivity claim and 4-state table didn't account for the counter also rendering opponent AP (CR-3b + `SHOW_OPPONENT_FILL_FLOURISH`), the turn-boundary race (preview open as `PlayerTurn` exits — different signal subscribers, no ordering guarantee), or an in-flight AP tick when the winning commit fires `GameOver`. Fixed: added a whose-AP orthogonal dimension to CR-3a; rewrote the exclusivity rule to hold across the whose-AP boundary; added a synchronous preview-echo force-clear on any turn transition; added a `GameOver` terminal-transition rule (AP-tick snaps to final value within AC-17's one-frame bound, hp-pip drain plays ungated); extended AC-17.
2. **Audio had no *total* priority order for the start-of-turn cluster** [audio-director, cross-grounded in base-production Rule 6 + research-tech Rule 5]. Build/research completion cues fire in the same start-of-turn step as the AP-income snapshot, so a 3–4-way frame cluster is real (stinger + AP-fill + deduped completion + possibly GameOver); the deduped completion cue was placed nowhere in the priority stack. Fixed: replaced pairwise rules with a single total order `GameOver > turn-stinger > completion cue > AP-fill` (GameOver hard-cuts; others duck under `HUD_AUDIO_DUCK_MS`).

**Recommended items folded in same session (9):** "the ONE"→"the one *persistent*" element (3 spots); chess-analogy→RTS-read framing in Player Fantasy; `SHOW_OPPONENT_AP` flagged mechanics-adjacent; **OQ-5 closed** (Redot 26.2 dual-focus confirmed via `ClassDB` binary introspection — `grab_click_focus`/`grab_focus`, distinct `focus`/`hover` StyleBox; concrete ADR guidance added to Input Notes; only traversal *order* left to `/ux-design`); OQ-8 camera-model downgraded from "blocks architecture" to a routine bounded fork (fixed camera near-certain at 14×16); AC-1 split into AC-1a (coalescing, testable now) + AC-1b (deferred pending harness); AC-2/AC-20 wording softened to not hardcode a test technique; CR-11 "no #9 duplication" coverage added to AC-2; Defensive-Structure-at-hp-10 boundary named in knob-interactions prose + flourish/tick ratio floor; explicit Pass-Through Invariant carve-out for local animation diff-state.

**Files touched:** `design/gdd/game-hud.md` (extensive — CR-3a, CR-3b, Audio mix-priority, Player Fantasy, Table A, Input Notes, Tuning Knobs, Formulas Pass-Through box, Edge/D-risk, AC-1/2/17/20, OQ-5/OQ-8, status header).
Prior verdict resolved: **Yes** — first review's NEEDS REVISION (5 blockers) confirmed closed.
**Still owed downstream (tracked, not blocking):** CR-1 signal-bus ADR (aggregate vs. typed-signal fork; `_process`-only emission constraint; autoload init-order; injectable read-interface + audio-playback seam for AC-1b/AC-2/AC-20/AC-21 harness); defeat-cue creative-director tone pass; `/ux-design` for `hud.md` (resolved with #9); the late-game glyph-density legibility playtest before Production.
