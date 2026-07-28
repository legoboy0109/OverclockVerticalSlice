# Accessibility Requirements: OVERCLOCK

> **Status**: Draft
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-24
> **Accessibility Tier Target**: Standard
> **Platform(s)**: PC (Steam / Epic)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA
> - AbleGamers CVAA Guidelines
> - Xbox Accessibility Guidelines (XAG): N/A — no console release currently scoped
> - PlayStation Accessibility (Sony Guidelines): N/A — no console release currently scoped
> - Apple / Google Accessibility Guidelines: N/A — no mobile release currently scoped
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`, `design/art/art-bible.md` §4 (Non-Hue Semantic Layer)

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures the project-wide accessibility commitments,
> the feature matrix across all systems, the test plan, and the audit history.
> It is created once during Technical Setup by the UX designer and producer,
> then updated as features are added and audits are completed. If a feature
> conflicts with a commitment made here, this document wins — change the feature,
> not the commitment, unless the producer approves a formal revision.
>
> **When to update**: After each `/gate-check` pass, after any accessibility
> audit, and whenever a new game system is added to `systems-index.md`.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: Standard

**Rationale**: OVERCLOCK is a turn-based tactics game — the deterministic, self-paced turn structure eliminates the most severe motor barriers common in action/twitch games (no reaction-time combat, no simultaneous multi-input combos, no rapid-mashing). This significantly lowers the cost of Standard tier's motor requirements compared to a real-time game. The genre's real accessibility risk is visual/cognitive: a grid-tactics game with a unified AP economy asks players to track multiple simultaneous numeric states (AP remaining, unit HP, cover, cost previews) — exactly the failure mode Standard tier's difficulty/clarity requirements address. The project has also already committed, independently of this document, to a Non-Hue Semantic Layer (art bible §4) across every gameplay-critical signal — this substantially de-risks Standard tier's colorblind-mode requirement, since "never color-only" is already a locked design constraint, not new work this tier invents. Comprehensive tier's screen-reader and HUD-repositioning requirements need platform API integration (Godot AccessKit) and dedicated UI architecture beyond current Vertical Slice capacity for a solo/small team. Target platform is PC-only for now (Steam/Epic) — no console certification (XAG/Sony) currently forces a floor, so the tier choice is driven by team capacity and player-base reach, not a platform mandate.

**Features explicitly in scope (beyond tier baseline)**:
- Colorblind-safe presentation is elevated to a *structural* requirement rather than a togglable mode — because the Non-Hue Semantic Layer means no gameplay signal is ever color-only in the first place, there's no separate "colorblind mode" to build; the default presentation already passes.
- Extended/adjustable timing for the Hold-to-Confirm Refund pattern (`design/ux/interaction-patterns.md`) — its hold threshold needs a toggle-to-confirm alternative for players who can't sustain a hold, even though the base threshold is already "generous, not twitch."

**Features explicitly out of scope**:
- Subtitle system and all Auditory Accessibility dialogue-dependent items — narrative/VO is explicitly deferred past the Vertical Slice (`game-concept.md` MVP scope: "Explicitly NOT in the Vertical Slice: Full story, narrative, dialogue"). These will be authored when the narrative system is designed, not fabricated now against nonexistent content.
- Screen reader support (Comprehensive tier) — out of scope until team capacity or a dedicated accessibility pass is planned.
- Console platform API integration (Xbox/PlayStation) — no console release currently scoped.

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu UI | Standard | All menu screens | Not Started | 24px minimum at 1080p per template baseline; scale proportionally at 1440p (the project's confirmed target resolutions per `technical-preferences.md`). |
| Minimum text size — HUD | Standard | In-game HUD | Not Started | 20px minimum for critical readouts. The AP counter is already required to be the single largest numeral on the HUD (art bible §7.2) — this exceeds the 20px floor by construction; other HUD numerals (hp, cost previews) must still be verified against the floor once type is locked. |
| Minimum text size — subtitles | Standard | Voiced/captioned content | **Deferred** | Narrative/VO is out of Vertical Slice scope (see Commitment above) — no subtitle content exists to size yet. Revisit when the narrative system is designed. |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | Minimum 4.5:1 (WCAG AA body text) / 3:1 (large text). The art bible's "Dark Stage, neon actors" principle (§1) — dark neutral backgrounds behind saturated foreground elements — is favorable for contrast by construction, but exact locked color values still need a contrast-checker pass once palette is finalized. |
| Text contrast — subtitles | Standard | Subtitle display | **Deferred** | Same as subtitle sizing above — no content yet. |
| Colorblind mode — Protanopia / Deuteranopia / Tritanopia | Standard | All color-coded gameplay | **Structurally addressed, verification pending** | The Non-Hue Semantic Layer (art bible §4) already forbids any gameplay-critical signal from being color-only — Board Overlay Taxonomy, Affordability Dimming, and faction identity (see Color Audit below) all have non-hue backups by design. What remains is verifying the *locked palette values* read distinctly under each simulated colorblind mode (a Coblis pass), not inventing new non-color backups. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | See table below | See Color-as-Only-Indicator Audit — result: no unresolved color-only signal was found in current design docs. |
| UI scaling | Standard | All UI elements | Not Started | Range 75%–150%, default 100%, per template baseline. HUD scaling independent from menu scaling — worth confirming against the HUD's fixed-corner/top-center-spine layout (game-hud.md) once implemented. |
| High contrast mode | Comprehensive | — | **Out of scope** | Comprehensive-tier feature; not committed at Standard tier (see Commitment). |
| Brightness/gamma controls | Basic | Global | Not Started | Standard graphics-settings feature; no project-specific complication identified. |
| Screen flash / strobe warning | Basic | All VFX, especially the AP counter's flare-and-decay and combat resolution flashes | Not Started | The art bible's glow vocabulary (§2, §7.4) uses flare/decay effects on commit — these need a Harding FPA flash-rate audit once implemented, plus the standard pre-launch photosensitivity warning screen. Flagged now so it isn't forgotten once VFX are built. |
| Motion/animation reduction mode | Standard | All UI transitions, HUD animations | Not Started, but **cheap by design** | The *Snap, Never Tween* interaction pattern already establishes that every commit-flourish (flare, glow) is reinforcement riding on top of an instant snap, never load-bearing information. A reduced-motion toggle that strips flourishes loses zero information — this is explicitly noted as a design win in `interaction-patterns.md`. |
| Subtitles — on/off, speaker ID, style customization, SFX captions | Basic/Standard/Comprehensive | Voiced content | **Deferred** | No narrative/VO content exists yet (Vertical Slice scope excludes it). Author these rows when the narrative system's GDD is written. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Faction identity (units/structures) | Each faction owns a saturated neon hue (art bible §1 P2) | Which faction owns this entity | Distinct per-faction silhouette (Mass Distribution Bias: Rush forward-light / Boom rear-loaded / Neutral even — art bible §5.2, LOCKED) | **Resolved** |
| Board Overlay Taxonomy (9 classes) | Would naively be a "traffic light" hue system | Tile legality/affordability/outcome | Fill/hatch pattern distinction, never hue (art bible §4.3/§4.5, `interaction-patterns.md`) | **Resolved** |
| Affordability Dimming (menu verbs, build/research options) | Would naively be red = unaffordable | Action legality/affordability | Dim/hatch treatment, reason text attached, never red or hue-coded (`interaction-patterns.md`) | **Resolved** |
| Cost/damage preview readout, unaffordable state | Would naively be a red numeral | Insufficient AP | Dimming/hatching on the arrow/delta, never a red numeral, never negative (art bible §7.6, `interaction-patterns.md`) | **Resolved** |
| hp display | Would naively be a red-to-green health bar | Remaining hp | Pip-vs-numeric branch — discrete integer display, not a color gradient bar (`interaction-patterns.md`) | **Resolved** |

This audit came back clean because the Non-Hue Semantic Layer was locked as an art-bible constraint *before* this document existed — a rare case where accessibility work was front-loaded into core design rather than retrofitted.

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | All gameplay inputs (keyboard, mouse, gamepad) | Not Started | Every bound input (board cursor step, cycle/jump, commit, cancel, End Turn) must be rebindable independently across keyboard, mouse, and gamepad, with conflict warnings, per ADR-0014's `InputConfig` convention. |
| Input method switching | Standard | PC | **Structurally supported already** | ADR-0014's dual-focus/precedence-rule architecture (mouse-hover vs. board-cursor, "last-updated-wins") already means the game supports switching input methods mid-session with zero mode-switch friction — this is an existing architectural decision, not new accessibility work. UI prompt icons (showing correct button glyphs for the active method) still need implementation. |
| One-hand mode | Standard | Audit below | **Likely low-cost** | Every core interaction in this game (board cursor step, menu navigate, confirm, cancel) is a single sequential input, never a simultaneous two-hand chord — no interaction identified so far requires two hands at once. The one open item is *Hold-to-Confirm Refund*'s sustained hold, addressed by the toggle alternative below. Re-audit once implementation exists, but no structural blocker is visible in the design. |
| Hold-to-press alternatives | Standard | Hold-to-Confirm Refund (the only hold input in the design) | Not Started | The Cancel-Build refund's press-and-hold gate needs a toggle alternative (first press arms, second confirms) per this tier's requirement — even though the pattern's hold threshold is already "fixed, generous, not twitch-timing" (`interaction-patterns.md`), a toggle path costs little and removes the sustained-press requirement entirely for players who need it. |
| Rapid input alternatives | Standard | — | **N/A — no rapid input exists** | The game has no button-mashing or rapid-press mechanic anywhere in the design (turn-based, deterministic, self-paced). Re-check this row if a future system introduces one. |
| Input timing adjustments | Standard | Hold-to-Confirm Refund's hold duration | Not Started | Same mechanism as the hold-to-press alternative above — provide a timing multiplier (0.5x–3.0x per template baseline) on the hold threshold as a secondary option alongside the toggle. `InputConfig.input_lock_ms` (the 120ms post-commit debounce, ADR-0014) is explicitly **not** a player-facing timing requirement — it's a UX debounce the player never has to beat, so it needs no accessibility adjustment. |
| Aim assist | Standard | — | **N/A — no real-time aiming** | Targeting is grid-tile selection via the Hover-Preview-Commit Loop (click/confirm a highlighted tile), never real-time aim. This requirement doesn't apply to the genre. |
| Auto-sprint / movement assists | Standard | — | **N/A — no continuous-hold movement** | Movement is a discrete preview-then-commit action (select destination tile, confirm), never a held-direction continuous movement. This requirement doesn't apply. |
| Platforming / traversal assists | — | — | **N/A — no platforming** | Grid tactics, not a platformer. |
| HUD element repositioning | Comprehensive | — | **Out of scope** | Comprehensive-tier feature; not committed at Standard tier (see Commitment). |

This section came back lighter than the template's default action-game baseline because several rows are genuinely inapplicable to a turn-based grid-tactics game, not skipped — each N/A carries its reasoning rather than being silently omitted.

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | AI opponent behavior | Not Started | The AI Opponent GDD is deliberately scoped to "credible, not masterful" for the Vertical Slice, with a possible follow-on granular difficulty axis (aggression, tempo-competence) once the AI is more capable. Document actual adjustable parameters once the AI system is implemented — currently there's a single AI competence level, not a difficulty range. |
| Pause anywhere | Basic | All gameplay states | **Structurally easy** | The game is turn-based and only advances on player input during the local player's Action phase — there is no real-time pressure to pause against. The relevant equivalent check is: can the player step away mid-turn without losing progress? (yes, by construction — nothing times out). Revisit if any timed element (e.g. a future ranked/timed mode) is added later. |
| Tutorial persistence | Standard | Tutorials/help text | **Not designed yet** | No tutorial system exists in current GDDs — flagged as a future requirement, not yet a gap in existing design. Author this row's specifics once a tutorial/onboarding system is designed (game-concept.md's onboarding curve names "one system at a time" as the intended teaching approach — persistence of that teaching material should be designed alongside it). |
| Quest / objective clarity | Standard | Match win conditions, future campaign objectives | Partial | For skirmish/VS scope, the "objective" is the match's win condition, sourced from `match_status`/win-check (ADR-0010) — always inferable from the board state, not a hidden goal. Campaign-specific mission objectives don't exist yet (deferred past Vertical Slice) — author this row's campaign half when campaign missions are designed. |
| Visual indicators for audio-only information | Standard | All gameplay-critical SFX | See Auditory Accessibility | Cross-reference — the SFX audit lives in the Auditory Accessibility section below, since the source list (which sounds carry gameplay information) is the same data either way. |
| Reading time for UI | Standard | Auto-dismissing dialogs/toasts | Not Started | The only named auto-dismissing element in current GDDs is the `UNSPENT_AP_REMINDER` toast near End Turn (command-action-interface.md) — a non-blocking reminder, not actionable information requiring a read-time guarantee, so it's lower-risk than the template's default concern. Still needs its dismiss duration checked against the 5-second floor once implemented, and any future dialog/toast must be audited the same way before shipping. |
| Cognitive load documentation | Comprehensive | Per game system | **Elevated from Comprehensive — partially addressed already** | The unified AP economy asking players to weigh build/produce/move/attack/research simultaneously is a *named design risk* in `game-concept.md` ("Analysis paralysis"), with mitigations already committed at the design level: the "building momentum" pacing curve, Pillar 3's readable-board discipline, and the pre-commit action-menu (Hover-Preview-Commit Loop). This document doesn't need to invent new mitigations — it should track, per system, whether that existing design intent actually held once implemented (a QA/playtest concern more than a new feature). |
| Navigation assists | Standard | — | **N/A — no open-world navigation** | The game is a single bounded tactical grid per match, not an explorable world — there's no fast-travel, waypoint, or map-navigation system for this requirement to apply to. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | Voiced content | **Deferred** | No narrative/VO content exists yet (see Commitment) — nothing to subtitle. Author when narrative lands. |
| Closed captions for gameplay-critical SFX | Comprehensive | Identified SFX list (below) | See SFX audit below | Result: every currently-identified gameplay-critical sound cue already has a paired visual by architecture (ADR-0015/ADR-0016's single-`action_applied`-event design), so captions are largely redundant with existing visual feedback rather than a new gap. See audit table. |
| Mono audio option | Comprehensive | — | **Out of scope** | Comprehensive-tier feature; not committed at Standard tier. |
| Independent volume controls | Basic | Music / SFX / UI audio buses | Not Started | Three buses currently relevant (no Voice bus needed yet — no VO). Standard settings-menu feature, per template baseline (0–100%, default 80%, persisted to profile). Add a Voice bus when narrative/VO lands. |
| Visual representations for directional audio | Comprehensive | Off-screen audio events | **N/A — no off-screen threats** | The board is a single bounded, fully-visible tactical grid per match (no fog of war, no off-screen enemy positions per the deterministic/perfect-information design) — there's nothing "off-screen" for a directional-audio indicator to point toward. Re-check if fog-of-war or a larger scrollable map is ever added. |
| Hearing aid compatibility mode | Standard | High-frequency-only audio cues | **TBD — pending sound design** | No cue has been designed yet where information is carried *only* by a high-frequency tone with no accompanying visual (every identified cue already pairs with a visual, per the SFX audit below) — but this should be re-checked once the audio-director does the actual sound-design pass, not assumed permanently safe. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| AP-tick sound (on commit) | AP was spent, new value | AP counter's instant snap + flare-and-decay tick animation (ADR-0016 §2) | No — visual is sufficient and fires off the same event | **Resolved** |
| Turn-change stinger | It's now your/the opponent's turn | Self-clearing YOUR/ENEMY banner (ADR-0016 §8) | No — visual is sufficient and fires off the same event | **Resolved** |
| Structure/Tech completion cue | A build or research finished | On-board completion marker, updates individually even when cues dedupe (ADR-0016 §7) | No — visual is sufficient | **Resolved** |
| GameOver victory/defeat cue | The match has ended | Victory/defeat overlay, one-frame preemption of any in-flight banner (ADR-0016 §8) | No — visual is sufficient | **Resolved** |
| Attack-commit sound (per weight class) | An attack resolved | Commit-flash + exact damage number (ADR-0015 §6, combat GDD) | No — visual is sufficient | **Resolved** |
| AP-fill arpeggio (turn start) | AP refilled for the new turn | AP counter's fill-flourish animation (ADR-0016 §2) | No — visual is sufficient | **Resolved** |

Every currently-designed audio cue rides the same architectural event (`action_applied`/`start_turn`) as an already-required visual — this is a consequence of ADR-0015/0016's "one shared event, no independent reactive renders" design, not new accessibility work. This audit should be re-run once the audio-director's actual sound design exists, in case a cue is added that doesn't follow this pattern.

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Steam (PC) | Steam Input / SDL | Controller input remapping via Steam Input (system-level); in-game remapping still required independently for keyboard/mouse | Not Started | Steam Input's system-level remapping doesn't substitute for in-game remapping — both are needed per Motor Accessibility's full-remapping requirement. |
| PC (Screen Reader) | JAWS / NVDA / Windows Narrator via Godot AccessKit | Menu navigation announcements | **Out of scope for Standard tier** | Screen reader support is a Comprehensive-tier commitment (see Tier Commitment) — not planned for the current tier target. Godot 4.5+ AccessKit integration would be the mechanism if this is picked up later; verify against `docs/engine-reference/godot/` when that happens. |
| Xbox (GDK) | XAG | — | **N/A** | No console release currently scoped. |
| PlayStation 5 | Sony Accessibility Guidelines | — | **N/A** | No console release currently scoped. |
| iOS / Android | UIAccessibility/VoiceOver, AccessibilityService/TalkBack | — | **N/A** | No mobile release currently scoped. |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Grid & Terrain | Cover/terrain highlight overlays | None beyond board-cursor navigation | Terrain rules add one more state to track (cover, impassable) | None identified | Partial | Overlay-level non-hue treatment covered by Board Overlay Taxonomy; terrain-specific glyph legibility still pending art pass. |
| Game State & Turn Manager | Turn/round indicator, self-clearing banners, victory/defeat preemption | None beyond End Turn control | Turn-transition clarity | Turn-change stinger, GameOver cue | Yes | Fully covered via HUD patterns + resolved SFX audit. |
| AP Economy | AP counter (largest HUD numeral, non-hue) | None | **Named design risk** — central to the "analysis paralysis" concern (see Cognitive Accessibility) | AP-tick, fill-arpeggio | Partial | Visual/auditory resolved; cognitive load is a tracked design risk pending playtest validation, not a documentation gap. |
| Unit System | hp pip-vs-numeric (resolved); has-acted state's visual treatment **not yet specified** | None beyond selection | Tracking multiple units' simultaneous states | None unit-specific | Partial | hp display resolved; has-acted indicator needs a non-hue treatment defined — flagged as an open item below. |
| Movement System | Reachable-tile overlay, cost preview (both resolved) | None beyond board-cursor/cycle-jump | Low | None identified | Yes | Fully covered by Board Overlay Taxonomy + Inline Cost/Damage Readout. |
| Combat Resolution | Target overlay, 3-state blocked-shot distinction (resolved, non-hue) | None | Deterministic (no RNG) combat is itself a cognitive-accessibility win — no probability to parse | Attack-commit sound (resolved) | Yes | Predictability is a genre-level accessibility asset, not just a design pillar. |
| Base & Production | Build/deploy overlays, build-progress readouts, cancel-refund (all resolved) | Hold-to-Confirm Refund's hold gate (addressed in Motor Accessibility) | Shares AP Economy's decision-density risk | Completion cue (resolved) | Partial | Visual/auditory/motor resolved; cognitive load shares AP Economy's tracked, not-yet-validated risk. |
| Research / Tech | Research menu, tech status panel, in-progress timer | Cancel-refund shares the same hold-gate pattern | Shares AP Economy's decision-density risk | Completion cue (shared, resolved) | Partial | Same profile as Base & Production. |
| Command & Action Interface | The bulk of the interaction pattern library originates here | Board cursor + cycle/jump, no rapid input | Three simultaneous focus concepts (mouse/board-cursor/menu) — mitigated by the Three-State Focus Indicator's automatic precedence rule | Commit-flash is audio-silent by design (no double-play) | Yes | This is the system `interaction-patterns.md` was built to serve — the most thoroughly covered system in this matrix. |
| Game HUD | AP counter, hp branch, action log, detail panel, victory/defeat overlay | Build/End Turn buttons (Standard Button pattern) | Always-present chrome is deliberately minimal ("HUD hosts only two controls + two view toggles," game-hud.md) | Single-owner audio dispatch, total priority order (resolved) | Yes | Deliberately constrained HUD footprint keeps cognitive load low by design intent. |
| AI Opponent | N/A — no player-facing UI surface | N/A | N/A | N/A | N/A | The GDD itself states no direct UI surface — correctly excluded, not overlooked. |
| Faction Identity | Faction picker (hue + silhouette; non-hue backup already exists per art bible) — **picker itself not yet designed** | None beyond setup-screen selection | Experimental-faction acknowledgment gate *adds* a deliberate decision step — informed consent, not accidental friction | None identified | Not Started | The picker is an already-tracked gap in `interaction-patterns.md`'s Gaps & Patterns Needed — not a new finding here. |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — contrast analyzer on UI screenshots | All text/background combinations, all HUD/menu states | Body text ≥ 4.5:1, large text ≥ 3:1 | ux-designer | Not Started |
| Colorblind modes | Manual — Coblis simulator on gameplay screenshots | Board Overlay Taxonomy classes, faction hues, Affordability Dimming, hp display in Protanopia/Deuteranopia/Tritanopia | No gameplay-critical information lost in any mode; player can complete a match relying only on non-hue signals | ux-designer | Not Started |
| Input remapping | Manual — rebind all inputs, complete a full match | All board/menu inputs rebound across keyboard/mouse/gamepad | All actions accessible after remapping; no binding conflicts; bindings persist | qa-tester | Not Started |
| Hold-to-press toggle | Manual — enable Hold-to-Confirm Refund's toggle alternative, cancel an in-progress build | Toggle mode arms/confirms without a sustained hold | Refund completes via two discrete presses, no hold required | qa-tester | Not Started |
| Reduced motion mode | Manual — enable mode, play a full turn | AP counter flourishes, commit-flash, board overlay transitions | All flourishes suppressed; committed values still snap correctly; no information lost per *Snap, Never Tween* | ux-designer | Not Started |
| Color-as-only-indicator re-audit | Manual — repeat the audit above against actual implemented UI (not design docs) | Every row in this document's Color-as-Only-Indicator Audit | Implementation matches the "Resolved" status claimed at design time — flag any drift | ux-designer | Not Started — scheduled once UI implementation exists |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader support (menus) | Comprehensive | Requires Godot AccessKit integration and dedicated UI architecture beyond current Standard-tier commitment and team capacity | Affects blind/low-vision players who could otherwise navigate menus via OS-level screen reader | Revisit if the project moves to Comprehensive tier later; no structural blocker identified, just unscoped effort |
| Subtitle system | Basic/Standard | Not excluded — genuinely doesn't exist yet, since narrative/VO is out of Vertical Slice scope | None currently — there is no dialogue to be inaccessible | Author full subtitle requirements (sizing, contrast, speaker ID) as part of the narrative system's own design pass, not retrofitted here |
| Mono audio option, haptic alternatives | Comprehensive/Exemplary | Not committed at Standard tier | Affects players with single-sided deafness (mono) or who rely on haptic feedback | Revisit if tier is raised; no current mitigation beyond independent volume controls |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| — | — | — | — | No audits conducted yet — this document was authored pre-implementation, directly against design docs (GDDs, ADRs, art bible, interaction pattern library) | Scheduled: first internal review once HUD/Command Interface implementation exists |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Foundational accessibility standard — contrast ratios, text sizing, input requirements |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Comprehensive game-specific checklist organized by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing service and consulting with disabled gamers |
| Xbox Accessibility Guidelines (XAG) | https://docs.microsoft.com/gaming/accessibility/guidelines | Reference only — no console release currently scoped |
| PlayStation Accessibility Guidelines | https://www.playstation.com/en-us/accessibility/ | Reference only — no console release currently scoped |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free tool for simulating colorblind modes on screenshots |
| Accessible Games Database | https://accessible.games | Research and examples of accessible game design decisions |
| CVAA (21st Century Communications and Video Accessibility Act) | https://www.fcc.gov/consumers/guides/21st-century-communications-and-video-accessibility-act-cvaa | US legal requirement for games with communication features (voice chat, messaging) — not currently applicable (single-player only) |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| What non-hue visual treatment communicates the Unit System's "has-acted this turn" state? | ux-designer | Before `unit-system.md`'s screen specs are authored | Unresolved |
| Does Godot 4.6's AccessKit support what Comprehensive-tier screen reader support would need, if the project ever raises its tier target? | godot-specialist | Only if tier is reconsidered | Unresolved, not currently blocking |
| Should the Faction Picker's experimental-acknowledgment-gate and loadout-preview patterns be added to `interaction-patterns.md` before or as part of that screen's own `/ux-design` pass? | ux-designer | Before `/ux-design faction-picker` is run | Unresolved |
| When narrative/VO is designed, should subtitle requirements be authored as an update to this document or as a fresh pass? | producer | Before the narrative system's GDD is authored | Unresolved |
