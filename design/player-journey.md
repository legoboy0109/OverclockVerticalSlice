# Player Journey Map: OVERCLOCK

> **Status**: Draft
> **Author**: ux-designer + user
> **Last Updated**: 2026-07-27
> **Links To**: `design/gdd/game-concept.md`, `production/vertical-slice/scope.md`

---

## Journey Overview

The player arrives skeptical-but-curious — a mid-core strategy player who has heard "unified economy" and wants to know if that's a real hook or marketing language. Within the first session they get their answer in a single visible moment: an AP-triage decision they made on turn one or two visibly pays off three turns later, and the abstract pitch ("macro and micro are the same decision") becomes a felt fact. From there the relationship deepens through a sequence of tempo-reading skills — first learning to read their own AP curve, then learning to read the opponent's, then learning to time a push against it — each one unlocking a sharper, more confident read of the board. The peak emotional experience is not a blowout win; it is the *Zero Hour* stabilization beat: a close, undecided game where the player is one AP-allocation choice away from losing tempo permanently, and pulls it back through sequencing rather than luck. What sustains the player afterward is honest and asymmetric between v1 and the full vision: in the Vertical Slice, sustaining power is limited to "was that read correct, and can I do it cleaner next time" — a tight, self-competitive loop with a real but modest half-life. In the full game, sustaining power grows into campaign progression, faction mastery, and the discovery of genuinely different AP rhythms per faction. This document is explicit throughout about which of those two engines is driving the player at each phase, because OVERCLOCK v1 is single-player with no comeback mechanic and no live-service layer — its long-term retention case has to be earned by depth and replayability, not by an ever-refilling content pipeline.

---

## Target Player Archetype

A player who has finished at least one Advance Wars, Into the Breach, or StarCraft II and arrives with sharpened expectations from all three: they want a board they can read at a glance (Advance Wars), a system elegant enough that losses feel like their fault, not the game's (Into the Breach), and an economy with real tempo tension (StarCraft II). They are patient with systems that don't over-explain themselves — in fact they distrust excessive hand-holding as a signal of shallow depth — but they are *not* patient with an unreadable board or randomized outcomes; both read as "the game is hiding the truth from me," which they treat as a trust violation, not a feature. They read tooltips selectively (on first encounter with a new system, then never again) and they will actively route around any friction between "I have an idea" and "I can test it." They are here for a test of skill first, a power fantasy second, and they measure a session's worth by whether they learned something they can apply next time.

---

## Journey Phases

> **Scope note on phase applicability**: This journey map covers the *intended full-game* arc, but explicitly marks which phases the Vertical Slice (one short symmetric skirmish, Move+Attack+Produce, minimal AI, no persistence — see `production/vertical-slice/scope.md`) can actually exercise versus which remain aspirational, gated on post-VS systems (factions, research, campaign, persistence). **Phases 5 and 6 are retained but heavily caveated, not deleted** — see the honesty note at the head of each. Deleting them outright would understate a real design risk (v1 has no natural mechanism to reach 10+ hour engagement without the campaign layer that doesn't exist yet), and the template's own guidance is to be honest about fit rather than pad *or* silently cut a phase whose absence is itself the finding.

---

### Phase 1: First Contact (0-5 minutes)

**VS coverage**: **Fully exercised.** This is exactly what the VS's mandated iso-legibility playtest measures.

**Emotional state on arrival**: Skeptical-curious. They've read "one AP pool governs everything" somewhere and are mentally filing it as either a genuine hook or a reskinned resource system. They expect a turn-based tactics game and are scanning for whether this one has anything new to say.

**Primary question the player is asking**: "Is this actually different from Advance Wars, or is the unified-economy pitch just marketing?"

**Key experience the game must deliver**: The board must read at a glance the instant it appears — silhouette-first units, faction-hue ownership, a dark stage with neon actors (Pillar 3) — because if the player has to squint to parse *what's on the board* before they can even engage with *what to do about it*, the unified-economy pitch never gets a fair hearing. Immediately after that, the AP counter must visibly dominate the frame (the HUD spec's 1.8× dominance floor) so the player's very first read of the screen is "this number is the game." The first turn should force a real choice — move a unit, attack, or produce, all drawing from the same visible pool — small enough not to overwhelm, but real enough that the player feels the tradeoff land the moment they commit.

**Emotional state on exit**: "Okay, I see it — the AP pool actually is one thing, not three systems wearing one UI." Curious about what happens when the pool gets tighter.

**Risk if this phase fails**: If the board is unreadable at the shipping isometric camera, or if the AP counter reads as one more resource among several rather than *the* resource, the player concludes "this is Advance Wars with different chrome" and never engages with Pillar 1 at all — the entire hook goes unnoticed. This is precisely why the VS hard-gates Pillar 3 on this phase.

---

### Phase 2: Orientation (5-30 minutes)

**VS coverage**: **Fully exercised**, bounded by VS content — the "aha" here is allocation-triage under a flat, non-compounding income (see `scope.md` §7.1: the VS deliberately does not build the economic-snowball lever, so Orientation in the VS teaches *sequencing a fixed budget*, not yet *compounding an economy lead*). That distinction matters for calibrating what a VS playtester should be expected to discover versus what's still locked behind post-VS systems.

**Emotional state on arrival**: Intrigued but not committed. Forming a first mental model of what this game actually is under the tactics-genre surface.

**Primary question the player is asking**: "How does this actually work, and am I going to be good at this?"

**Key experience the game must deliver**: The first crystallizing "aha" is realizing that *building/producing and fighting compete for the exact same points* — there is no separate macro screen to retreat to when combat gets complicated. That reframe (Pillar 1 made concrete) should land within the first two or three turns. The second is the pre-commit action-preview affordance doing its job: because the game always shows move range, valid targets, and exact AP cost before commitment, the player's early predictions about "if I spend this, then that" start coming true — this is the mechanism by which Competence needs get met this early, and it is why Core Mechanic 6 (pre-commit preview) is load-bearing for this phase, not a nicety. The player should also catch a first glimpse of depth: noticing that ending a turn with unspent AP is a real loss (the `UNSPENT_AP_REMINDER` nudge), which plants the seed that *efficient* spending, not just *any* spending, is the actual skill.

**Emotional state on exit**: "I have a working model: I have a budget, everything competes for it, and the game tells me the cost before I pay it. I've made at least one decision I'm still thinking about." A sense that there's a "right" way to sequence a turn, even if they can't articulate it yet.

**Risk if this phase fails**: If the AP preview doesn't reliably predict the outcome (a cost estimate that's wrong, or a range that doesn't match what actually happens), the player's trust in the system breaks immediately — this genre's audience is unusually unforgiving of a board that lies to them, per the archetype above. If the unified-pool reframe never lands (e.g., produce and move feel like separate currencies because their UI doesn't visibly draw from the same counter), the player never discovers the actual hook and evaluates the game as a shallower Advance Wars clone.

---

### Phase 3: First Mastery (30 minutes - 2 hours)

**VS coverage**: **Partially exercised — this is the phase the VS's swing-back playtest targets, but only its allocation-triage half.** A single VS skirmish (30–90 min per the concept doc's session length) sits almost entirely inside this phase's time window. What the VS *can* prove: the first stabilization win. What it explicitly cannot prove (per `scope.md` §7.1, flat 10 AP/turn income, no build-outpost verb): the "compounds hardest" half of mastery — timing an economic snowball. That is real, named, and deferred, not accidentally missing.

**Emotional state on arrival**: They understand the rules and are now testing what's actually optimal — probing whether an early rush beats a slower buildup, whether producing is worth the AP it costs versus pushing an existing unit.

**Primary question the player is asking**: "What's the right sequencing, and what happens if I get good at reading the opponent's tempo instead of just my own?"

**Key experience the game must deliver**: The first genuine skill victory in OVERCLOCK is a **close-game stabilization** — the *Zero Hour* beat named explicitly in the Core Fantasy. The player is behind or even, feels the opponent's lead compounding, and pulls off a turn where correct AP sequencing (not a lucky roll — combat is deterministic) visibly closes the gap or wins the exchange. This is the single highest-value moment in the entire journey: it is the moment the "mastery of tempo" fantasy stops being a pitch line and becomes a memory. Crucially, because OVERCLOCK has no comeback mechanic, this moment must occur in a game that's genuinely still undecided — if the player's mental model becomes "I can always claw back a loss," that's a false lesson the game will punish them for the next time they try it against a decided game, so the fairness of this beat (and its refusal to fire once a game is truly lost) is itself part of what's being taught here. The player should also get their first taste of reading the *opponent's* AP state (the always-visible opponent-AP readout is deliberately perfect-information, not fog) — this is where "tempo reading" starts to feel like a distinct skill from "resource management."

**Emotional state on exit**: Proud of a specific turn, able to describe *why* it worked ("I held back my attack until they'd already spent their defensive AP"). Starting to form an opinion about the "right" way to open a game — even if that opinion is still rush-biased or boom-biased and not yet well-informed.

**Risk if this phase fails**: If the stabilization moment never happens — if games are decided too early to ever be "close," or if a losing player's correct plays don't visibly matter because the AI doesn't play a credible tempo game — the player never reaches flow and concludes the deterministic-combat promise is theoretical, not real. This is exactly the failure mode the VS's swing-back playtest (≥3 close/undecided samples) is designed to catch before it ships broadly.

---

### Phase 4: Depth Discovery (2-10 hours)

**VS coverage**: **Not exercised — explicitly post-VS, and the team should not expect a VS playtester to reach this phase.** This phase depends on systems the VS deliberately stubs or omits entirely: build-outpost, research/tech, and — the big one — faction asymmetry (Pillar 4, its own dedicated follow-up prototype per the concept doc). A single symmetric VS skirmish structurally cannot contain a Depth Discovery moment; there is only one map, one roster, two mirrored sides, and no tech tree to reveal.

**Emotional state on arrival**: They have a working strategy (probably rush- or boom-leaning, echoing the two archetypes the concept prototype already surfaced) and are starting to feel its ceiling — the same opening stops working against a slightly-better opponent or slightly-different map.

**Primary question the player is asking**: "Is there a deeper opening I haven't found? What does the research tree actually unlock, and how does another faction change the calculus?"

**Key experience the game must deliver**: This is where the compounding half of the tempo fantasy — currently deferred out of the VS — has to arrive: the build-outpost verb and research tree turn a flat-income triage puzzle into a genuine economic snowball game, and the player should discover that an early outpost investment reshapes their entire mid-game. This is also where Bartle Explorers get their real payoff: learning a second faction's AP curve (rush/tempo vs. boom/mass, per the Faction Design Seed) should *recontextualize* everything learned in Phase 3 — an opening that was correct against the first faction may be wrong against the second, and discovering that asymmetry is the "how deep does this go" answer. Per the template's design note, this depth must be discoverable through play, not require an external wiki — the pre-commit preview and always-visible opponent state (Pillar 3) need to keep paying off here just as they did in Orientation.

**Emotional state on exit**: Has rebuilt their opening at least once after a faction or research discovery invalidated the old one. Can now describe multiple viable strategies rather than one.

**Risk if this phase fails**: If factions turn out to be reskins rather than distinct AP strategies (the exact risk Pillar 4 names and defers to its own prototype), or if the research tree doesn't meaningfully reshape tempo, the player concludes the game "finished" at the end of Phase 3 and reports it as good-but-shallow — a real risk given the VS itself cannot test this and the full asymmetric-faction hypothesis remains unvalidated as of this writing.

---

### Phase 5: Habitual Play (10-50 hours)

> **Honesty note, per template guidance**: This phase is retained, not deleted — but flagged as the single largest open risk in this journey map. OVERCLOCK v1 is a single-player campaign-plus-skirmish game with **no live-service layer, no ladder, no seasonal content, and (per the Player Motivation Profile) Socializers are explicitly not a v1 target**. Whether this phase is reachable at all depends entirely on whether the eventual campaign (4-6 factions, "a campaign each," per the concept doc's Full Vision tier) delivers enough discrete content and replay incentive to sustain 10-50 hours *without* a social or competitive backbone. This is aspirational until that campaign exists — do not treat it as validated by anything in this document.

**Emotional state on arrival**: Considers themselves competent at the core tempo duel. Has a playstyle identity (a preferred faction, a signature opening). The game has become a "when I want a tight strategic session" habit rather than a novelty.

**Primary question the player is asking**: "Which faction's campaign haven't I finished? Can I clear this mission with a cleaner opening than last time? What's my personal best against the AI?"

**Key experience the game must deliver**: Because there's no PvP ladder in v1, Habitual Play has to be sustained almost entirely by **self-competition and campaign structure**: distinct per-faction campaigns provide externally-generated goals (Achiever motivation — "finish this faction's arc"), and the deterministic, no-luck combat model means a player's improving skill is legible against their own past performance ("I beat this mission in fewer turns / with less loss this time"). Natural session endings should leave forward tension — a campaign mission cliffhanger, an unstarted faction, a research branch not yet explored — echoing the concept doc's "next time I'd open differently" hook. Optional/replayable skirmish content (different maps, different AI difficulty) extends this without requiring new narrative content.

**Emotional state on exit**: Has a specific goal spanning multiple sessions (finish this faction's campaign; beat a personal best). Thinks of themselves as "someone who plays OVERCLOCK," even without any community to signal that identity to.

**Risk if this phase fails**: With no social scaffolding to fall back on, if the campaign content or self-competition hooks are thin, players simply stop returning once the "aha" of the core loop is exhausted — there's no login-reward, ladder-reset, or friend-pressure mechanism to pull them back. This is a retention risk worth surfacing to the game-designer and producer explicitly: **v1's Habitual Play case rests entirely on campaign content depth and the self-competitive legibility of deterministic combat — if either is weak, this phase may simply not occur for most players**, and no amount of UX polish can manufacture a hook that has no system behind it (per the Retention Hooks section's own guidance below).

---

### Phase 6: Long-Term Engagement (50+ hours)

> **Honesty note**: Retained per the same reasoning as Phase 5, but even more conditional. This phase is normally sustained by community, competitive standing, or creative expression shared with others (per the template) — all Socializer/Fellowship-adjacent mechanisms this project explicitly deprioritizes for v1 (Player Motivation Profile: "Fellowship: N/A — single-player focus for v1"). If OVERCLOCK reaches this phase for any meaningful slice of its audience in v1, it will most likely be through the Achiever/Explorer/Competitor lens only: mastering every faction, discovering every opening, and — if PvP ever ships (currently "a possible future," out of current scope) — climbing a skill ceiling against other humans. **Do not scope features against this phase for v1**; it is named here so the eventual decision to invest in PvP or community tooling is made deliberately, not by accident.

**Emotional state on arrival**: A veteran who has finished every faction's campaign and is playing for mastery's own sake — the tempo duel's stated "high skill ceiling" (Retention Hooks, concept doc) is the only thing left pulling them back.

**Primary question the player is asking**: "Is there a cleaner opening than the one I've settled on? Could I beat this AI (or, if PvP ever exists, another human) more decisively?"

**Key experience the game must deliver**: Absent community/PvP infrastructure, this phase can only be sustained by a skill ceiling that keeps yielding new discoveries — subtle AP-sequencing refinements, faction match-up knowledge, or optimal-play benchmarks the player sets for themselves. If a stronger AI or PvP mode is ever built (both currently out of scope), this phase's engine changes fundamentally: from solo mastery-chasing to competitive standing, which is a substantially stronger retention mechanism and the more likely long-term answer if this phase matters to the business.

**Emotional state on exit**: Considers themselves an expert on the game's systems, even if that expertise has nowhere social to go in v1.

**Risk if this phase fails**: For v1, this is the lowest-priority phase to protect — expect a small fraction of the audience to reach it, and expect it to be fragile without PvP or community features. The risk isn't so much "losing veteran players" (v1 doesn't have the infrastructure to keep them anyway) as **wrongly treating this phase as validated just because it exists on paper** — it should stay explicitly aspirational until PvP or a stronger AI is actually greenlit.

---

## Critical Moments

| Moment | Phase | Emotional Target | If It Fails |
|--------|-------|-----------------|-------------|
| First glance at the board after load | First Contact | Instant legibility — "I can already tell whose units are whose and what's dangerous" | Player squints to parse the board before engaging any system; the unified-economy pitch never gets a fair hearing (Pillar 3 hard-gate) |
| First AP spend (any verb) | First Contact | Satisfying, visible investment — "that came out of the same pool as everything else" | The unified-pool hook reads as marketing copy rather than a felt mechanic |
| First pre-commit preview (cost shown before commit) | Orientation | Trust — "the game told me exactly what this would cost, and it was right" | Player's predictions don't match outcomes; trust in the system's fairness breaks early, which this audience does not forgive |
| First AP-triage decision that visibly pays off 2-3 turns later | Orientation | Earned pride — "I set that up myself" | The tradeoff feels arbitrary or invisible; player never forms an opinion about "the right way to play" |
| First time ending a turn with wasted (unspent) AP | Orientation | A small sting of "I could have used that" — teaches efficiency matters | Player never notices AP loss as a cost, and never refines toward efficient sequencing |
| First time reading the opponent's AP state and timing a push around it | First Mastery | Delight — "I predicted what they'd do and played around it" | Opponent state reads as decorative rather than actionable; tempo-reading never becomes a distinct, learnable skill |
| The first close-game stabilization (the *Zero Hour* beat) | First Mastery | The peak of the journey — earned relief and pride, "I clawed that back through sequencing, not luck" | If it never happens, the game's central promise (mastery of tempo) never manifests; if it happens in a game that was actually already decided, it teaches a false, dangerous lesson (see next row) |
| A decided game staying decided despite a player's best late push | First Mastery | Respect for the system's honesty — "the game didn't let me get away with something I didn't earn" | If a decided game *does* reverse, the anti-comeback design promise breaks and every future stabilization win becomes suspect ("did I actually earn that, or would it have flipped anyway?") |
| First opening that visibly snowballs (rush or boom paying off cleanly) | First Mastery | Confidence — "I have a strategy now, not just a set of rules" | Player never settles on a repeatable approach and treats every game as unpredictable chaos rather than a skill test |
| First faction played that isn't the starting/default one | Depth Discovery | Recontextualizing awe — "everything I learned has to be rethought for this faction" | If the second faction plays like a reskin, the player concludes the game is shallower than the pitch promised (the exact Pillar 4 risk) |
| First outpost/research investment that reshapes a mid-game | Depth Discovery | Discovery — "the economy goes deeper than turn-one triage" | If compounding economy never feels different from flat income, the "compounds hardest" half of the core fantasy stays theoretical |
| Completing a faction's campaign for the first time | Habitual Play | Closure plus forward pull — "that story's done, but I want to see how the next faction plays" | Player feels finished and stops, with nothing pulling them into a second faction |
| Beating a personal-best turn count / margin on a replayed mission | Habitual Play | Self-competitive satisfaction — "I'm visibly better than I was" | Without a comparison point (no stats, no history), improvement is invisible and the loop feels directionless |
| First loss that the player can articulate the cause of (not "bad luck") | First Mastery / Habitual Play | Respect — "I know exactly what I'd do differently" | Deterministic combat's whole point is that losses are legible; if a loss ever feels arbitrary, the no-luck promise is broken and losses stop teaching anything |

---

## Retention Hooks

| Hook Type | Hook Description | Systems That Deliver It |
|-----------|-----------------|------------------------|
| **Session Start** | Curiosity about an untried opening, or an unresolved question from last session ("would that push have worked if I'd sequenced it differently?") | Deterministic combat (makes replay-and-compare meaningful); no systems currently *generate* this hook automatically (no daily reward, no changed-while-away world state) — it is entirely player-internal in v1 |
| **Session End** | "Next time I'd open differently" — the concept doc's named lingering hook; a specific decision the player is still turning over | Deterministic, no-luck combat resolution (so the "what if" is answerable by replaying, not chalked up to variance); the action log (lets a player review exactly what happened) |
| **Daily Return** | **No system delivers this in v1.** There is no daily quest, login reward, or time-gated resource — deliberately, per the premium/no-monetization-gate anti-pillar. | None — flagged as an intentional absence, not a gap to fill reflexively; a premium single-player strategy game does not need (and per anti-pillars should not have) a daily-return mechanic |
| **Long-Term** | Campaign completion per faction (Achiever), mastering each faction's distinct AP rhythm (Explorer), and self-competitive skill growth against deterministic combat (Competence) | Persistent campaign layer (STAR COMMAND, post-VS/post-Prototype), faction asymmetry (Pillar 4, its own prototype), research trees. **All three systems are post-VS** — this hook is currently a design intention, not a built system |

**Retention risk flag** (explicit): three of these four hook rows are either unbuilt (Long-Term) or structurally absent by design (Daily Return). OVERCLOCK v1's entire retention case rests on the Session Start/Session End hooks being strong enough on their own — which in turn rests entirely on the tempo-duel core loop being replayable and legible enough that "I'd open differently" is a genuine pull rather than a hopeful line in a design doc. This is not a flaw to fix with more hooks; a premium, single-player, no-comeback-mechanic strategy game is *supposed* to look like this. It is a fact to plan against: the campaign layer (Long-Term hook) is not a nice-to-have polish pass, it is the only planned system that gives players a reason to return past the ~10-hour mark, and its absence from the VS means this hook remains completely unvalidated until Alpha.

---

## Player Progression Feel

The primary progression feeling in OVERCLOCK is **skill improvement**, specifically of a narrow, legible kind: *tempo-reading*. This is deliberately not power growth (no gear treadmill, no stat inflation — deterministic combat and a flat unit roster within a mission mean a Trooper is a Trooper all game) and not world expansion (one contested sector per mission, not an unfolding map). It is the StarCraft II model of progression: the player doesn't get stronger, they get *sharper*.

At the **beginning** (First Contact/Orientation), this feels like catching up to the game's pace — early turns should feel simple enough that the player's reads mostly land, building the Competence foundation. At the **middle** (First Mastery/Depth Discovery), it should feel like the player's *predictions* about the opponent start outrunning their *reactions* — they stop being surprised by what the AI does and start anticipating it, timing their own pushes around a read rather than a hope. Encounters that felt tense in Orientation should feel controlled by First Mastery, not because units got stronger, but because sequencing got cleaner. At the **end** (Habitual Play/Long-Term, where reachable), the feeling is mastery expressed as *efficiency and margin* rather than raw victory — a veteran player should be able to look at a replayed mission and say "I did that in three fewer turns" or "I never let AP go unspent," a form of progression that's entirely self-referential and doesn't require the game to hand out new numbers. This is honest about the tradeoff: it's a progression feeling that rewards players who already like measuring their own improvement, and offers comparatively little to players whose progression itch is scratched by external validation (leaderboards, gear, cosmetics) — none of which v1 has.

---

## Anti-Patterns to Avoid

- **Player feels punished for experimenting with AP allocation**: Because losses are deterministic and legible, a player must always be able to trace *why* an allocation failed back to their own decision, never to hidden information or randomness. If a "bad" allocation choice ever fails for a reason the player couldn't have seen coming (a hidden AI behavior, an unclearly-costed action), it violates the entire no-luck promise and teaches the wrong lesson.
- **The stabilization swing fires in a game that was already decided**: This is the single most dangerous anti-pattern specific to OVERCLOCK. Because there is no comeback mechanic by design, any bug, tuning error, or AI weakness that lets a *decided* game reverse doesn't just feel unfair once — it retroactively poisons every future stabilization win, because the player can no longer tell whether their skillful comeback was earned or just the system being generous. This is exactly what the VS swing-back playtest is built to catch (`scope.md` §10: "in the decided set, none reverse").
- **Difficulty spike creates a wall, not a gate (AI competence outpaces the player's current tools)**: If the AI's tempo play escalates faster than the player's own toolkit (new units, research, factions) is introduced, players hit a wall they have no key for. The concept doc's stated onboarding curve (constrain AP/units early, introduce one system at a time: move → attack → produce → build → research) is the intended gate-not-wall answer — the AI's escalation and the system-unlock pacing must be kept in lockstep, not designed independently.
- **Player reaches the content ceiling (end of Phase 4) before the emotional arc completes**: Because Phases 5-6 depend entirely on the not-yet-built campaign and faction-asymmetry systems, there is a real risk that a player finishes the available VS/Alpha-era content, feels the "how deep does this go" question from Depth Discovery genuinely answered, and has nowhere further to go — with no live-service or social layer to paper over the gap. This is not hypothetical; it is the named condition of Phase 5/6 above.
- **Mandatory systems introduced too late to feel meaningful**: Research and build-outpost — both deferred out of the VS — must not be the *first* time a player encounters the compounding-economy half of the fantasy at full complexity. If a player's only exposure to flat-income triage is the VS-style experience and then research/outposts arrive all at once in a later build with no earlier low-stakes taste, the transition will feel like a different, harder game bolted onto the one they learned.
- **Treating Habitual/Long-Term Engagement as validated because they're described in this document**: Nothing in Phases 5-6 has been playtested — they are design intentions dependent on systems that don't exist yet (campaign, faction asymmetry, possibly PvP). The specific anti-pattern to avoid is scope creep or roadmap confidence that treats this document's description of those phases as evidence they will actually occur.

---

## Validation Questions

**First Contact (0-5 min)**
- [ ] "Without looking at any menus or tooltips, what do you think this game is about?"
- [ ] "Can you tell at a glance which units are yours and which are the enemy's?"
- [ ] "What's the first thing you want to do next?"

**Orientation (5-30 min)**
- [ ] "What does winning or succeeding look like to you right now?"
- [ ] "When the game showed you a cost before you committed to an action, did the actual result match what you expected?"
- [ ] "Is there anything you feel like you should understand but don't?"

**First Mastery (30 min - 2 hrs / one VS skirmish)**
- [ ] "What's the best decision you've made so far? Why did you make it?"
- [ ] "Was there a moment where you felt behind and then pulled it back? Walk me through that turn."
- [ ] "Did you ever feel like you won or lost because of luck, rather than your own decisions?"
- [ ] "What would you do differently if you started over?"

**Depth Discovery (2-10 hrs)** — *not reachable in the VS; ask only once factions/research exist*
- [ ] "Has the game surprised you? When? How did it feel?"
- [ ] "Does the second faction you tried feel like a genuinely different way to play, or a reskin of the first?"

**Habitual Play (10-50 hrs)** — *not reachable in the VS; ask only once campaign content exists*
- [ ] "What's your current goal? How long have you been working toward it?"
- [ ] "What's pulling you back to play again today — is it a story beat, a personal-best you're chasing, or something else?"

**General (any phase)**
- [ ] "If you had to stop playing right now, what would you be most eager to come back for?"
- [ ] "Is there anything you feel the game is not letting you do that you want to do?"

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does the VS's flat-income allocation-triage stabilization moment (Phase 3) land as "the peak experience" for a naive playtester, or does it feel muted without the compounding-economy half? | ux-designer, producer | VS playtest (Sprint 3/4) | Unresolved — this is exactly what the scope.md §7.1 swing-back playtest will surface; a muted result routes to PIVOT (add build-outpost), not to rewriting this document |
| Is the Phase 1 legibility hook robust for a player with no prior Advance Wars/Into the Breach/StarCraft II experience, or does this journey map's archetype assumption (genre-literate player) leave newcomers behind? | ux-designer, game-designer | Post-VS, before broader playtesting | Unresolved |
| Is Depth Discovery (Phase 4) actually discoverable without a guide once factions and research ship, or does the asymmetry need more explicit in-fiction signposting? | game-designer, ux-designer | Post faction-asymmetry prototype | Unresolved — cannot be answered until Pillar 4 is validated |
| Is a single-player campaign (no PvP, no social layer) sufficient to sustain Phase 5 (Habitual Play) for a meaningful fraction of the audience, or does OVERCLOCK need a PvP/leaderboard investment sooner than currently planned to protect retention past ~10 hours? | producer, game-designer, creative-director | Before Alpha scope lock | Unresolved — flagged as the single largest retention risk in this document (see Retention Hooks) |
| Should Phase 6 (Long-Term Engagement) be scoped for v1 at all, or should the roadmap explicitly de-risk by treating it as out-of-scope until/unless PvP is greenlit? | creative-director, producer | Before Alpha scope lock | Unresolved |
| Do `design/ux/hud.md`, `main-menu.md`, and `pause.md`'s arrival-context assumptions (mid-match, focused, self-paced; menu on cold boot; pause as a self-paced interrupt) hold up against this journey map's Phase 1-3 emotional-state descriptions? | ux-designer | Immediate — check on next revision of those specs | **Resolved in this pass**: yes, they are consistent — see alignment note below |

**Alignment check against `hud.md`, `main-menu.md`, `pause.md`**: All three specs' Open-Question placeholder ("no player-journey.md exists — arrival context designed from assumptions") can now be resolved by reference to this document. `main-menu.md`'s assumption of a neutral/anticipatory cold-boot arrival and a reflective/satisfied return-from-match state matches Phase 1's "skeptical-curious" arrival and the emotional range described across Phases 1-3. `pause.md`'s framing of pause as a voluntary, self-paced interrupt (not a safety valve against real-time pressure) matches this document's treatment of OVERCLOCK as a turn-based, no-time-pressure experience throughout. `hud.md`'s mid-match-focused-self-paced assumption for its "player context on arrival" aligns with the Orientation/First-Mastery phases' emphasis on legible, unhurried AP-triage decision-making. No contradictions found; each spec's Open Question item referencing this document (S2-08) should be marked resolved on their next revision pass.
