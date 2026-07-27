# Difficulty Curve: OVERCLOCK

> **Status**: Draft
> **Author**: game-designer + k.mansius
> **Last Updated**: 2026-07-27
> **Links To**: `design/gdd/game-concept.md`
> **Relevant GDDs**: `design/gdd/ap-economy.md`, `design/gdd/combat-resolution.md`, `design/gdd/movement-system.md`, `design/gdd/base-production.md`, `design/gdd/research-tech.md`, `design/gdd/ai-opponent.md`, `design/gdd/command-action-interface.md`, `design/gdd/game-hud.md`
> **Cross-References**: `design/player-journey.md` (emotional-arc companion doc, authored in parallel — see callouts below), `production/vertical-slice/scope.md` (VS validation scope)

---

## Difficulty Philosophy

OVERCLOCK's philosophy is **Accessible entry, optional depth**, but arrived at through a genre-specific mechanism rather than difficulty settings: the game is **deterministic and self-paced**, which structurally lowers the floor without diluting the ceiling. There is no dice roll to get unlucky against (anti-pillar — Pillar 2, "Tempo Is the Skill") and no clock forcing a decision before the player is ready (turn-based, no time pressure). A new player's losses are always legible as *decisions*, never as *variance* or *reflexes* — which means every loss is, in principle, something the player could have played around. That legibility is what makes the entry accessible: the game never asks "were you lucky?", only "did you sequence your AP well?" The skill ceiling, meanwhile, is effectively unbounded — tempo mastery (reading an opponent's AP curve, timing a push to land before their spike, stabilizing a close game under pressure) is a StarCraft II-adjacent depth well that a mid-core/hardcore audience can spend hundreds of hours climbing.

The player is permitted to feel **out-planned**, never **cheated**. Frustration is allowed and even desirable in the mid-to-late game — that is the resistance that makes tempo mastery meaningful — but it must always resolve into "I see what they did and I can counter it next time," not "that felt random" or "I had no time to think." Because the game has **no rubber-band or comeback mechanic** (see Core Fantasy, `game-concept.md`), the design must not intervene to soften a *decided* game — that would betray Pillar 2. The intervention point for difficulty design is entirely upstream: onboarding, AI tuning, and starting-position design must produce games that *stay close* long enough for the tempo-duel fantasy to be felt, rather than papering over blowouts after the fact. Acceptable cost of failure is high in absolute terms (a lost mission can mean 30–90 minutes) but is mitigated by self-contained missions (a loss doesn't erase campaign progress, it teaches an opening to try differently) and by turn-based pacing (no execution punishment — a misread is always recoverable in-turn until it's committed).

---

## Difficulty Axes

OVERCLOCK is a deterministic turn-based tempo duel, so several axes common to action games are deliberately near-zero by genre design. This is worth stating explicitly per the template's guidance — a game can look "easy" on the axes players usually associate with difficulty while still being genuinely hard on the axes that actually carry this game's challenge.

| Axis | Description | Primary Systems | Player Control? |
|------|-------------|----------------|-----------------|
| **Execution difficulty** | Near-zero by design. There is no timing window, no input precision, no reflex test — selecting a unit, previewing a move, and committing are self-paced, mouse-driven actions with no fail state of their own (Command & Action Interface's pre-commit preview shows the exact outcome before the player pays for it). The only "execution" failure is a misclick, which the pre-commit menu is built to prevent. | Command & Action Interface, Board Renderer | Yes — effectively fully controlled; the game does not force a physical skill test |
| **Time pressure** | Near-zero. Turn-based with no per-turn clock in the VS or MVP scope. The player can sit on a decision as long as they want. Any perceived pressure is *self-imposed* (wanting to keep pace with an opponent) rather than system-imposed. | Game State & Turn Manager | Yes — fully controlled; no timer exists to remove |
| **Decision complexity** | **The primary axis.** Every turn is a genuine multi-verb triage — move, attack, produce, (build, research in the full game) — all drawing from one AP pool (Pillar 1). The player must evaluate several candidate actions of *different types* against each other on a shared "AP well spent" intuition, which is a harder cognitive task than comparing options within a single system. Complexity scales directly with the number of unlocked verbs and the number of units/structures in play. | AP Economy, Command & Action Interface, all verb systems | Partially — the pre-commit preview and one-turn-at-a-time pacing reduce the *load*, but the number of live decisions is inherent to the genre and cannot be reduced without hollowing out the fantasy |
| **Knowledge difficulty** | High and central. Because combat is deterministic, a player who knows the damage formula, the roster's efficiency bands (e.g., Trooper's hp/AP dominance at range 2), and the opponent's likely AP curve has a durable, learnable edge over one who does not. Reading "who is ahead on tempo right now" is itself a knowledge skill the game does not spell out numerically mid-match by default (only via the HUD's on-demand income breakdown). | Combat Resolution, AP Economy, Unit System, Game HUD | Yes — entirely acquirable through in-game discovery, the HUD's decompositions, and repeated play; no external wiki dependency required, though experienced players will develop one |
| **Resource pressure** | Present and genre-central, but shaped by AP scarcity rather than item/consumable scarcity. Every turn, AP is the single scarce resource contested across five (eventually) uses; there is no way to "save up" beyond one turn (no banking — `ap_reset_policy`), so pressure is renewed every turn rather than accumulating dread over a long resource drought. | AP Economy, Base & Production, Research & Tech | Yes — through build order, allocation discipline, and (full game) tech choices that shift income |
| **Positional/tempo pressure** | A genre-specific axis worth naming on its own: the cost of being *behind on tempo* compounds (Pillar 2 — "invest AP so it compounds faster than theirs"). This is not classic resource pressure (you always have your flat/tiered income) — it's the compounding gap between two AP curves. Once a game is *decided*, this axis is intentionally irreversible (no comeback mechanic); while a game is *close/undecided*, this axis is the one skilled stabilization play acts on. | AP Economy, Base & Production (outposts), AI Opponent (starting-position/tempo-competence scaling) | Partially — the player can always try to close a tempo gap through better sequencing, but cannot "opt out" of the axis existing; this is the intended forced-challenge dimension of the whole game |

---

## Difficulty Curve Overview

> The 1–10 scale below is relative to OVERCLOCK's own design intent, not a cross-genre absolute. Because execution and time-pressure axes are near-zero throughout (see above), even a "10/10" late-campaign mission is a 10/10 on decision complexity, knowledge, and tempo pressure — never on reflexes.

| Phase | Duration | Difficulty Level (1–10) | Primary Challenge Type | New Systems Introduced | Target Player State |
|-------|----------|------------------------|----------------------|----------------------|---------------------|
| Onboarding skirmish | 0–30 min (first mission) | 2/10 | Knowledge (systems introduced one at a time) | Move → Attack → Produce, sequentially | Safe, curious, building a working mental model |
| Early campaign | 30 min – ~4 hrs (first 2–4 missions) | 3–4/10 | Decision complexity (multi-verb triage begins) | Build (outposts), full unified-AP triage with 4 verbs | Learning, occasional losses with a clear "I see why" |
| Mid campaign — opening | ~4–15 hrs | 5–6/10 | Knowledge + decision complexity | Research/Tech, asymmetric faction identity, tougher AI tempo competence | Engaged, developing "opening builds," starting to read opponents |
| Mid campaign — depth | ~15–30 hrs | 6–7/10 | Tempo/positional pressure | Higher-tier AI starting positions, faction-vs-faction matchup knowledge | Genuinely challenged; losses now come from being out-tempoed, not confusion |
| Late campaign | ~30–50 hrs | 7–8/10 | Tempo pressure + decision complexity combined | Full tech trees, hardest AI tempo competence, tightest starting-position parity | Mastery-seeking; every mission is a real duel; close/undecided games are common |
| Skirmish endgame / mastery | 50+ hrs, replayable | 8–10/10 | All axes combined, player-vs-player-equivalent AI | None (mastery content — hardest AI tier, hardest faction matchups) | Expert play; players compare openings and matchup knowledge; self-imposed challenge (e.g., speed-to-win) |

**VS validation note**: the Vertical Slice validates only the **Onboarding skirmish** row above, and only its opening turns — a single symmetric Move+Attack+Produce skirmish with flat income and a "credible, not masterful" AI (see `production/vertical-slice/scope.md`). Everything from "Early campaign" onward — Build, Research, faction asymmetry, AI tempo-tier scaling, and the full campaign arc — is full-game design intent captured here for forward planning, not something the VS can build or test. Where a row or lever below depends on systems the VS does not implement, it is marked **[Full-game]**.

---

## Onboarding Ramp

### What the Player Knows at Each Stage

| Time | What the Player Knows | What They Do Not Know Yet |
|------|-----------------------|--------------------------|
| 0 min | Nothing except what the title screen and mission briefing communicate: this is a turn-based tactics game about a contested sector. | Everything — the AP system, the roster, the win condition, the board. |
| ~2 min | How to select a unit and read its move-range preview (Move introduced first, in isolation). | Attack, Produce, the AP cost of anything beyond movement, that AP is shared across verbs at all. |
| ~6 min | How to select a target and read the pre-commit damage preview (Attack introduced second, in isolation, after Move is internalized). | That Attack and Move draw from the *same* pool — this is the first moment the unified economy becomes visible. |
| ~12 min | The core tension: AP is one pool, and Move + Attack already compete for it. Has made at least one real triage choice (push now vs. hold and produce). | Production, that a stronger roster is available, whether their triage choice was optimal. |
| ~20 min | Produce is introduced; the player now juggles three verbs against one budget — the full VS-scope triage. | Build (outposts) and Research — deferred to later missions in the full campaign; not present in the VS at all. |
| ~30 min | Has a working mental model of "AP is the whole game" and has experienced at least one moment of visible cause-and-effect (a push that worked or didn't). | Late-game depth: faction identity, tech trees, tempo-reading against a competent opponent. |

### Mechanic Introduction Sequence

This sequence is a direct, load-bearing design commitment from `game-concept.md`'s Flow State Design section: *"complexity is introduced one system at a time (move → attack → produce → build → research)."* Two new mechanics are never introduced in the same encounter.

| Mechanic | Introduced At | Introduction Method | Stakes at Introduction |
|----------|--------------|--------------------|-----------------------|
| Move (core verb) | First 0–2 min | Guided first turn: one unit, one obvious destination, no opposition on the board yet. Pre-commit range preview does the teaching — the player sees the cost before committing. | None — no enemy present, fully reversible until commit, first move is essentially risk-free. |
| Attack | ~2–6 min | Introduced against a single, weak, clearly-telegraphed enemy unit (Scout-tier) once Move is used at least once. Pre-commit damage preview shows exact outcome pre-commit (deterministic combat means "preview = result," a strong teaching property no RNG game gets for free). | Low — the first attackable enemy is weak enough that a suboptimal attack doesn't lose the mission; the player learns the damage formula empirically without punishment. |
| Produce | ~12–20 min | Introduced once the player has felt the Move/Attack AP tension at least once (i.e., has hit a turn where they couldn't do everything they wanted). Framed as "spend AP now to have more options later" — this is the first explicitly economic decision. | Low — early missions give enough AP headroom that a first suboptimal produce choice doesn't cascade into a loss; the opponent's production pace in this window is intentionally gentle. |
| Build (outposts) **[Full-game]** | Mission 2–3 of the campaign (post-VS) | Introduced as an explicit economic upgrade path once the player has run the three-verb triage in at least one full mission. Framed via the closeout/boom archetype seeded in the concept prototype. | Low–Moderate — an outpost is a real investment (4 AP, exposed for 1 turn while under construction) but campaign-early missions give a forgiving board so a lost outpost doesn't decide the game. |
| Research / Tech **[Full-game]** | Mission 3–5 of the campaign (post-VS) | Introduced last, after the player has internalized the four-verb core loop. Framed as a long-horizon investment (3–4 turn payback) — deliberately the "advanced" mechanic since it rewards planning several turns ahead, the hardest skill in the game. | Moderate — a Research Lab is a real AP and tempo commitment; by this point the player has enough roster and economy fluency to absorb a misplaced bet without it being unrecoverable. |

### The First Failure

The first meaningful failure is designed to occur in the **Early campaign** phase (not the tutorial mission itself — the onboarding skirmish's opponent AI is deliberately gentle enough that a first-time player should be able to win or draw close with reasonable play). The intended first failure is an **AP-triage failure**: the player over-commits to one verb (typically over-producing or over-extending an attack) and finds themselves unable to respond to the AI's counter-push the following turn.

Because combat and economy are fully deterministic and the HUD exposes the AP-spend history (action log — `game-hud.md`), the causal chain is always inspectable after the fact: the player can look at the action log and see exactly which turn they under-invested in defense, or over-invested in an attack that didn't pay off. There is no hidden roll to blame. The retry cost is a full mission replay (self-contained missions, no permanent campaign loss) — moderate in time (session length 30–90 min) but zero in permanent stakes, matching the "high absolute cost, but self-contained and clearly diagnosable" philosophy stated above. The game does not need an explicit "here's what went wrong" tutorial popup for this: the deterministic damage preview and the action log are the feedback mechanism, consistent with Pillar 3 (Readable Board, Deep Decisions) — the board and its history should already tell the story.

### When the Player First Feels Competent

The designed moment of first competence is **the first successful pre-planned attack sequence**: the moment the player uses the pre-commit preview to line up a move-then-attack (or a produce-then-hold) that plays out *exactly* as previewed, and that plan visibly worked better than a reactive alternative would have. Because combat has zero randomness, this moment is achievable and repeatable in a way action games with hit-chance cannot guarantee — the player's read of the board becomes a *reliable* prediction, not a probabilistic one. This is intended to land within the first 20–30 minutes (within the onboarding skirmish itself, once Produce is live and the player has run at least one full three-verb turn).

This is systemically supported by the Command & Action Interface's pre-commit preview (showing exact move range, exact targets, exact AP cost, and exact projected damage before commit) and by deterministic Combat Resolution (what was previewed is exactly what happens). The game communicates success the same way it communicates everything else — visibly, on the board, with no separate "you did it!" fanfare needed; the predicted outcome simply happening as previewed *is* the payoff. This moment is the seed of "Tempo Is the Skill" as a felt experience, not just a stated pillar.

*Cross-reference: this moment should be the anchor beat for the "First Mastery" phase of the player-journey emotional arc (`design/player-journey.md`) — the difficulty design and the emotional-arc design should agree on the same timestamp and trigger condition for this beat.*

---

## Difficulty Spikes and Valleys

| Name | Location in Game | Type | Purpose | Recovery Design |
|------|-----------------|------|---------|-----------------|
| First Attack Encounter | ~2–6 min, onboarding skirmish | Spike (knowledge, minor) | Tests that the player has internalized Move well enough to now weigh it against Attack. Deliberately small — a single weak enemy, not a real threat. | No recovery design needed at this scale — the encounter is low-stakes by construction; the "recovery" is simply that the next enemy is not harder. |
| First AP Triage Turn (Move+Attack+Produce all live) | ~20 min, onboarding skirmish | Spike (decision complexity) | Tests the core unified-economy fantasy for the first time with all VS-scope verbs live simultaneously. This is the moment Pillar 1 becomes real to the player. | The mission's win condition is HQ destruction only, with a generous AP floor (10/turn) — a single suboptimal triage turn does not lose the mission outright; the player gets several more turns to course-correct. |
| First Mission Win/Loss (skirmish resolution) | End of onboarding skirmish, ~30–60 min | Spike (culmination) | The first full test of the loop end-to-end: read the board, triage AP over several turns, reach a win or loss. | Win → immediate positive reinforcement (win/loss screen, campaign unlocks next mission — full game). Loss → self-contained, no campaign penalty, action log available to diagnose; player can immediately retry. |
| Outpost Introduction Mission **[Full-game]** | Campaign mission 2–3 | Spike (new system) | Introduces the Build verb and the compounding-economy half of the tempo fantasy (deferred entirely from the VS — see `production/vertical-slice/scope.md` §7). | A forgiving early-campaign board (per Onboarding Ramp table) ensures a first mishandled outpost investment doesn't cost the mission. |
| Post-Onboarding Valley | Immediately after the first campaign win, before mission 2 **[Full-game]** | Valley | Player feels the "I won a real tempo duel" high; campaign layer (STAR COMMAND) gives a moment to review unlocked units/tech before the next mission's pressure begins. | N/A — this *is* the recovery from the onboarding spike; it doubles as the setup beat for introducing Build. |
| Research Introduction Mission **[Full-game]** | Campaign mission 3–5 | Spike (new system, highest decision-complexity jump in onboarding) | Introduces the final unified-AP verb; from this point forward every mission uses the complete five-verb triage. | Same forgiving-board principle as the Outpost mission; additionally, Research's long payback horizon (3–4 turns) means a single early misstep here rarely decides a mission by itself. |
| Mid-Campaign Faction-Matchup Wall **[Full-game]** | ~15 hrs, first mission against a meaningfully different AI faction archetype | Spike (knowledge) | Forces the player to learn that a rush-oriented opponent and a boom-oriented opponent demand different openings — tests whether the player has generalized their tempo-reading skill or just memorized one opponent's pattern. | Action log + HUD income breakdown make the "what did they do differently" diagnosis legible without an explicit hint system; losing this mission once is an intended, informative beat, not a wall to be removed. |
| Pre-Endgame Valley **[Full-game]** | ~28–30 hrs, just before the campaign's final missions | Valley | Breathing room before the hardest AI tempo tier; player reflects on faction mastery built up over the campaign. | N/A — designed relief before the late-campaign difficulty ramp. |

---

## Balancing Levers

| Lever | Phase(s) | Effect | Current Setting | Tuning Range | Notes |
|-------|----------|--------|----------------|-------------|-------|
| `BASE_INCOME` (AP/turn) | All | Higher = more AP headroom = lower resource pressure and more forgiving triage mistakes | 10 AP/turn (VS: flat, no outposts) | 8–14 (full game, pre-outpost) | Owned by `ap-economy.md`. VS deliberately holds this flat with no outpost bonus (`production/vertical-slice/scope.md` §5) — full game adds `outpost_income_tiers` on top. |
| `outpost_income_tiers` **[Full-game]** | Early campaign onward | Higher tier bonuses = economy investment compounds faster = raises the ceiling of "how far behind can you fall if you don't invest" | +2 AP/outpost (1–4), +1 AP/outpost (5+) | Tier1 1–3, Tier2 0–2 | Owned by `ap-economy.md`. This is the primary lever for how hard the "compounding" half of the tempo fantasy bites — the VS explicitly cannot exercise it (see Known Limitation below). |
| `attack_cost` (AP) | All | Higher = attacking is a bigger fraction of the turn's budget = raises decision-complexity weight of every combat choice | 2 AP | 1–3 | Owned by `combat-resolution.md`. Not intended to vary by campaign phase — a stable denominator keeps the player's AP intuition transferable mission to mission (an implicit onboarding-friendliness requirement). |
| Unit roster cost/power curve (`produce_cost`, `hp`, `attack`) | All | Governs decision complexity of production choices and the pace of combat resolution (time-to-kill) | Scout 2/hp3/atk2, Trooper 4/hp6/atk3, Heavy 7/hp10/atk5, Sniper 5/hp3/atk6 | See `entities.yaml` for full ranges/rationale | Owned by `unit-system.md`. Already tuned once (Heavy 6→7) to remove a dominant strategy — see `entities.yaml` note. Not phase-varying; roster identity stays constant, availability gates (HQ-only Scout vs. Outpost-unlocked roster) are the actual difficulty lever, not stat retuning. |
| `production_outpost.build_cost` / `build_time` **[Full-game]** | Early campaign onward | Higher cost/longer build time = raises the stakes and delay of unlocking the non-Scout roster = raises decision complexity of the Build verb's timing | build_cost 9, build_time 2 turns | 6–12 / 1–3 turns | Owned by `base-production.md`. This is also the named lever for closeout-drag mitigation — see Cross-System Difficulty Interactions. |
| Research costs/times (`research_cost`, `research_time`) **[Full-game]** | Mid campaign onward | Higher cost/time = Research becomes a longer-horizon bet = raises the "plan ahead" skill demand, the hardest knowledge-difficulty test in the game | Attack Tech 10 AP/3 turns, Defense Tech 10 AP/4 turns, Economy Tech 7 AP/3 turns | See `research-tech.md` | Owned by `research-tech.md`. This is the primary late-onboarding gate knob — how far into the campaign Research becomes viable to commit to. |
| AI tempo-competence tier **[Full-game]** | All (scales per mission/skirmish difficulty selection) | Higher tier = AI evaluates/commits closer to a theoretically-optimal `action_score` ordering every turn, and starts from a stronger or more even board position = raises tempo/positional pressure directly | VS/onboarding tier: "credible, not masterful" heuristic scoring (see `ai-opponent.md`) | To be defined: 3–4 discrete tiers spanning onboarding-gentle to mastery-competitive | Owned by `ai-opponent.md`. **This is the single most important full-game difficulty lever** — because execution/time-pressure axes are near-zero, "how good is the opponent's tempo play" is the primary way the game gets harder late-campaign. The VS's single AI configuration is one point on what should become a tier ladder; defining the full ladder is an Open Question below. |
| AI starting-position parity **[Full-game]** | Mid–late campaign | Less parity (AI starts with a tempo/positional head start) = raises difficulty without touching AI competence itself | VS: perfect symmetry (parity) | Symmetric (onboarding) to AI +1 "effective outpost" head start (late campaign) | New lever, not yet owned by an existing GDD — likely lands in `ai-opponent.md` or a future mission/level-design doc. Distinguished deliberately from AI competence: this lets late-campaign missions escalate without making the AI's *decision quality* superhuman, preserving the "out-planned, not cheated" philosophy. |
| New-mechanic introduction density | Onboarding only | More mechanics introduced per unit time = higher cognitive load; fewer = risk of pacing boredom | 1 new verb per encounter, ~1 per 10–20 min (VS: 3 verbs in ~20 min) | 1 per 8 min (max) to 1 per 25 min (slow) | Cross-cutting — no single GDD owns this; it's a campaign/mission-sequencing decision. VS's 3-verb-in-20-min pace is faster than the general floor because the VS is a single short skirmish, not a multi-mission campaign; the full-game campaign should relax this pace (Build and Research get dedicated missions, not compressed into one). |

---

## Player Skill Assumptions

| Skill | Introduced In | Expected Mastered By | Taught By | First Hard Test |
|-------|--------------|---------------------|-----------|-----------------|
| Reading the pre-commit preview (move range / target / AP cost / damage) | 0–6 min, onboarding skirmish | End of onboarding skirmish, ~30 min | Command & Action Interface's mandatory preview-before-commit flow — the player cannot act without seeing the preview first, so this is taught by the interaction model itself, not a popup | First AP Triage Turn (~20 min) — the player must read three previews against one budget in the same turn |
| Unified AP triage across verbs (Move/Attack/Produce, then Build/Research) | ~12–20 min, onboarding skirmish, and re-taught incrementally as each new verb unlocks **[Full-game beyond Produce]** | End of onboarding for the 3-verb VS core; end of early campaign (mission ~3–5) for the full 5-verb version | Direct play pressure — the AP pool visibly runs out before every desired action is affordable, forcing the tradeoff to be felt, not explained | First Mission Win/Loss (onboarding) for the 3-verb version; Research Introduction Mission for the full 5-verb version |
| Deterministic-combat planning (using the damage formula to predict outcomes rather than react to them) | ~2–6 min (first Attack) | Mid campaign, ~10–15 hrs | The preview-equals-result property of deterministic combat itself — every attack is a free lesson in the damage formula | Mid-Campaign Faction-Matchup Wall — the first opponent whose unit mix forces genuine pre-attack calculation rather than "attack the weakest thing" |
| Tempo-reading (judging who is ahead on AP-compounding, not just board position) | Implicitly from the first triage turn; explicitly supported once the HUD's income breakdown is used **[deepens across full campaign]** | Late campaign, ~30+ hrs | Organic play + the HUD's on-demand income decomposition (`game-hud.md`) — the game does not spell out "you are behind" as a UI callout by default, consistent with Pillar 3's "complexity lives in the choices, not the UI" | Any close/undecided mid-to-late game where a stabilization swing is possible — this is the skill the whole "swing-back" fantasy (`game-concept.md`, MVP requirement #6) is built to test |
| Opening-build construction (a reliable, repeatable early sequence of AP spends) | Early campaign, once Build is live **[Full-game]** | Mid campaign, ~15–20 hrs | Repetition across multiple missions/skirmishes plus the rush/boom archetype seed from the concept prototype | Mid-Campaign Faction-Matchup Wall — an opening that beats a rush opponent may lose to a boom opponent; this is the first test that a single memorized opening is insufficient |
| Long-horizon investment planning (Research's 3–4 turn payback) **[Full-game]** | Mid campaign, once Research is live | Late campaign, ~30+ hrs | Direct feedback loop of committing AP now for a benefit several turns later — the hardest skill in the game because the cost is immediate and legible but the payoff is delayed and must be mentally tracked | Late-campaign missions where an opponent has clearly out-teched the player's Research timing |

---

## Accessibility Considerations

### What Can Be Adjusted

| Adjustment | Method | Effect on Experience | Tradeoff |
|-----------|--------|---------------------|----------|
| AI tempo-competence tier selection **[Full-game]** | Skirmish/mission difficulty setting (player-facing tier ladder, see Balancing Levers) | Lowers or raises positional/tempo pressure without touching knowledge or decision-complexity axes — the player still faces the same triage complexity, just against a less/more capable opponent | A lower tier changes the felt intensity of the "duel" fantasy but does not remove the core loop; this is the primary and most important accessibility lever for this genre, since it's the only axis that meaningfully varies in "hardness" at all |
| Extended time between turns | None needed — already unlimited (turn-based, no per-turn clock) | N/A | N/A — listed here only to confirm explicitly that no accessibility work is required on this axis; the genre gives it for free |
| UI scaling / colorblind-safe faction hues | Settings menu (art-bible / UX scope, not this doc's domain) | Preserves Pillar 3 legibility (silhouette-first units, faction = hue) for players with color-vision differences | Requires the art bible's faction-hue palette to be validated against colorblind simulation — flagged here as a dependency on `design/art/art-bible.md`, owned by `art-director`/`ux-designer`, not `game-designer` |
| Action-log / income-breakdown visibility | Always-on HUD element (`game-hud.md`) | Surfaces knowledge-difficulty information (what happened, what the AP breakdown is) without the game needing a separate "easy mode" hint system | None significant — this is designed as a universal legibility aid, not a difficulty-reducing toggle, so it does not undermine competence for anyone who chooses to use it |

### What Cannot Be Adjusted (and Why)

| Fixed Element | Why It Cannot Change | Design Reasoning |
|--------------|---------------------|-----------------|
| Deterministic combat (no hit-chance, no crit variance) | This is an anti-pillar (`game-concept.md`) — introducing randomness as an "easy mode" would remove the exact property (predictable outcomes reward planning) that makes the game's skill expression legible at any difficulty | Making combat probabilistic for lower difficulties would not lower difficulty in a way consistent with the game's identity — it would change what kind of game it is |
| The unified AP pool (no parallel "easy mode" resource track) | Anti-pillar — a parallel resource that let players sidestep the core tradeoff would violate Pillar 1 at its foundation, for any player, at any difficulty | The single-pool tension *is* the game; an accessibility mode that removes it removes the product, not just the difficulty |
| No rubber-band / comeback mechanic once a game is decided | Core design stance (`game-concept.md` Core Fantasy) — this cannot vary by difficulty setting because it defines what "winning" and "stabilizing" mean throughout the whole difficulty curve; a decided-game reversal on easy mode would teach the wrong lesson about what skill the game rewards | The asymmetry (decided games stay decided; close games are winnable through skill) is what makes the stabilization skill meaningful — diluting it at low difficulty would make low-difficulty play teach bad habits that later difficulty tiers punish |
| Turn-based structure (no real-time or timed-turn mode) | Anti-pillar — real-time play would compromise Pillar 3 (Readable Board, Deep Decisions) and the deliberate weight of AP allocation | Time pressure is not a difficulty axis this game uses at all (see Difficulty Axes); adding it as an option would introduce a challenge type the rest of the design never accounts for |

---

## Cross-System Difficulty Interactions

| System A | System B | Combined Effect | Intended? |
|----------|----------|----------------|-----------|
| Decision complexity (new-verb introduction) | Resource pressure (limited early AP) | Introducing a new verb (e.g., Produce, then Build, then Research) while the player is still tight on AP forces them to learn a new option *and* optimize simultaneously | No — mitigated by design: each new verb is introduced in a mission/encounter with generous AP headroom (see Mechanic Introduction Sequence "Stakes at Introduction" column), so the player can experiment with the new verb without an immediate optimization penalty |
| AI tempo-competence tier **[Full-game]** | Resource pressure (flat vs. tiered income) | A high-tier AI paired with the flat-income VS-era economy would produce an unwinnable tempo gap, since the player has no compounding lever to close it with — this interaction only becomes safe once outposts (compounding income) are live | Partial — intended once Build is unlocked (full game); explicitly **not** intended in the VS, which is why the VS pairs its flat economy with a deliberately gentle "credible, not masterful" AI tier, never a harder one |
| Knowledge difficulty (deterministic combat mastery) | Decision complexity (multi-verb triage) | A player who has mastered damage-formula prediction but not yet AP triage can still lose missions on triage alone — the two skills are additive, not substitutable; over-indexing tutorial time on one does not compensate for the other | Yes — intentional. This is why Move and Attack are taught before Produce (knowledge foundation first) and why Produce/Build/Research are taught after (triage complexity builds on a settled knowledge base), per the Mechanic Introduction Sequence |
| AI starting-position parity **[Full-game]** | Tempo/positional pressure | Removing starting parity (giving the AI a head start in later campaign tiers) directly stacks with the "once decided, stays decided" design stance — an early AI lead in a high-difficulty mission could become unrecoverable faster than in a symmetric mission | Partial — intended as the primary late-campaign difficulty escalation, but must be tuned carefully: the sample-floor validation methodology used in the VS's swing-back playtest (`production/vertical-slice/scope.md` §9 — ≥3 close/undecided and ≥3 decided games) should be reused for any future asymmetric-start tier to confirm it still produces winnable *close* games, not just harder blowouts |
| Closeout-drag risk (HQ-as-sole-corner-producer) | Losing-player behavior under decided-game conditions | A losing player who spam-produces from a cornered HQ can drag out an already-decided game — this is a named risk (`game-concept.md`, `production/vertical-slice/scope.md` §7.2) distinct from difficulty tuning, but it interacts with difficulty design because a dragged-out decided game erodes the "decided games stay decided and resolve cleanly" promise this whole curve is built around | No — flagged as an open design problem for `base-production.md`/`combat-resolution.md` (production caps, rising per-turn cost, forward-deploy structures, or an attrition mechanic); the VS is explicitly capturing observational data on this (§9) without gating on it yet |

---

## Validation Checklist

### Onboarding (0–30 min) — **VS-validatable**
- [ ] Players with no prior tactics-genre experience complete the onboarding skirmish's opening turns without external help, using only the pre-commit preview as guidance
- [ ] Zero playtesters cite confusion about what a given AP cost means or what a previewed action will do
- [ ] At least one playtester reaches the "First AP Triage Turn" beat and can articulate the tradeoff out loud (even informally, e.g., "I want to attack but then I can't produce")
- [ ] The First Failure (an AP-triage misstep) produces a visible learning response — the playtester can identify what they'd do differently using only the action log, without being told
- [ ] The First Competence moment (a pre-planned attack landing exactly as previewed) is reached by the median playtester within 30 minutes

### Early Campaign (30 min – 4 hrs) **[Full-game — not VS-validatable]**
- [ ] Players reach a full 5-verb triage understanding by the end of the Research Introduction Mission
- [ ] No playtester cites Build or Research as introduced "too suddenly" given the forgiving-board mitigation at each introduction point
- [ ] Players can describe their current mission goal and their current AP allocation strategy without prompting

### Mid Campaign (4–30 hrs) **[Full-game — not VS-validatable]**
- [ ] Players organically discover at least one opening build without being told one
- [ ] The Mid-Campaign Faction-Matchup Wall produces a loss that playtesters correctly diagnose as "different opponent archetype," not "unfair" or "random"
- [ ] No single difficulty axis dominates playtester complaints — frustration should distribute across knowledge, decision complexity, and tempo pressure roughly evenly, not concentrate on one
- [ ] Playtesters report wanting to try a different opening or faction matchup next session

### Late Campaign / Endgame (30+ hrs) **[Full-game — not VS-validatable]**
- [ ] Players report the hardest AI tempo tier feels like a culmination of everything learned, not an artificial stat wall
- [ ] Losses at the hardest difficulty tier are diagnosable via the action log/HUD breakdown, matching the "out-planned, not cheated" philosophy
- [ ] Players who complete the campaign at a given faction express interest in trying another faction's distinct AP strategy (Pillar 4)

### Swing-Back / Anti-Comeback Specific (cross-cutting, all phases) — **VS-validatable at onboarding scale**
- [ ] In a sample of close/undecided games, at least one flips via stabilization play (not luck — combat is deterministic, so any flip is attributable to a specific sequencing decision)
- [ ] In a sample of decided games, none reverse — validates that the "no rubber-band" design stance holds in practice, not just on paper
- [ ] *(VS scope note: the VS can only test the allocation-triage version of this — a fixed flat-income budget being sequenced under pressure — not the full economic-snowball version that depends on outposts; see Known Limitation in `production/vertical-slice/scope.md` §7.1.)*

### Accessibility
- [ ] The AI tempo-competence tier ladder, once implemented, produces a genuinely different felt experience at each tier without changing the deterministic-combat or unified-AP-pool foundations
- [ ] Colorblind playtesters can distinguish faction ownership by shape/pattern cues in addition to hue (validated against the art bible, not this doc, but flagged here as a dependency)
- [ ] Playtesters using a lower AI tier report feeling like they are playing the "same game," not a diminished one

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| What are the discrete AI tempo-competence tiers for the full game, and how many should there be? The VS validates exactly one point ("credible, not masterful") on what should become a ladder. | game-designer, ai-programmer | TBD — full-game AI design phase, post-VS | Unresolved — requires the VS's AI heuristic (`ai-opponent.md`) to be extended or parameterized once a PROCEED verdict is reached; likely 3–4 tiers spanning onboarding-gentle to mastery-competitive |
| How should AI starting-position parity vary across campaign difficulty, and what sample-floor methodology validates it stays "close-game-producing" rather than just "harder"? | game-designer, systems-designer | TBD — full-game campaign design phase | Unresolved — proposed approach is to reuse the VS swing-back playtest's sample-floor methodology (`production/vertical-slice/scope.md` §9) for any future asymmetric-start tier |
| Does the onboarding pacing (3 verbs introduced in ~20 minutes in the VS) need to relax once Build and Research are added as dedicated-mission introductions in the full campaign, or does the VS's faster pace hold up for the first 3 verbs even in the full game? | game-designer | TBD — first full-campaign mission-sequencing pass | Unresolved — requires a playtest of the full 5-verb onboarding arc, not just the VS's 3-verb slice |
| How does the closeout-drag risk (decided-game production spam from a cornered HQ) interact with the "decided games stay decided" difficulty philosophy — does a dragged-out decided game count as a difficulty-curve failure even though it isn't a swing-back failure? | game-designer, systems-designer | TBD — pending VS closeout-drag observational data (`production/vertical-slice/scope.md` §9) | Unresolved — explicitly deferred until the VS produces data; this doc should be revisited once that data exists |
| Should the player-facing difficulty *selector* (if one exists) be framed as "AI skill tiers" only, or should it also expose starting-position parity as a separate, named toggle so players understand these are two different levers? | game-designer, ux-designer | TBD — full-game UX design phase | Unresolved — depends on `design/player-journey.md` and future UX work on how difficulty is communicated to the player before a mission starts |
| Does the emotional arc in `design/player-journey.md` agree with this document's placement of the "First Competence" beat at the pre-planned-attack moment, or does it identify a different anchor point? | game-designer | TBD — reconcile with the companion doc | Unresolved — flagged for reconciliation against `design/player-journey.md` |

---

This document is **full-game design intent**. The only rows/sections the Vertical Slice can actually build and playtest are: the Onboarding Ramp's Move→Attack→Produce sequence, the corresponding Difficulty Spikes/Valleys through "First Mission Win/Loss," the allocation-triage half of swing-back validation, and the corresponding Validation Checklist items marked VS-validatable above. Everything marked **[Full-game]** — Build/Research onboarding, faction-matchup difficulty, AI tempo-tier ladder, starting-position parity scaling, and the full campaign-length curve — is forward design work to guide `ai-opponent.md`, `base-production.md`, and `research-tech.md` as they mature past VS scope, and to be revisited once VS playtest data (especially closeout-drag and swing-back results) lands.
