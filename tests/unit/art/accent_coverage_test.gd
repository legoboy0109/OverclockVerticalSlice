# Accent coverage — the ownership signal, gated (S8-05).
#
# ★★ WHY THIS EXISTS. S5-03 measured the Sniper carrying hue on **13.3%** of its body against a
# roster mean of 50.1%, and rated it a BLOCKING legibility defect: it is the longest-ranged unit,
# the one most needing identification at distance without selection. It shipped, and it survived
# an entire art sprint, **because nothing measured it**. S5-03's own recommendation #2 was to add
# this check; that recommendation then sat open for two sprints.
#
# ★ The rule it encodes, from S5-03's measurements: contrast in this art splits between accent and
# mass. Accent-vs-stage passes everywhere (4.26–7.17:1); whole-unit-vs-stage never does
# (1.80–2.46:1). Units are a dark chassis plus a neon accent doing 100% of the ownership work.
# ⇒ **An archetype's accent coverage IS its legibility.** Heavy (62%) and Sniper (13%) shared a
#   palette; coverage was the entire difference.
#
# This runs in the suite rather than in the asset pipeline on purpose. A pipeline check runs when
# someone remembers to run it; the defect this exists to catch got through precisely because
# nothing ran automatically.
extends GdUnitTestSuite

const _ART := "res://assets/art/units"
const _ARCHETYPES: Array[String] = ["scout", "trooper", "heavy", "sniper"]

## Faction tokens that carry OWNERSHIP and must therefore carry hue.
const _OWNED_FACTIONS: Array[String] = ["rush", "boom"]

# --- Thresholds -------------------------------------------------------------------------------
# Measured on the shipped roster 2026-08-25: trooper 42.5 · sniper 43.5 · scout 45.4 · heavy 62.4.
# Bands are set with real headroom either side so ordinary re-authoring does not trip them; they
# exist to catch a COLLAPSE, not to police art direction.

## The Sniper defect measured 13.3%. The lowest shipping archetype is the Trooper at 42.5%, which
## the art bible names as the roster's baseline control — so 30 sits ~12 points below anything
## shipping and ~17 above the defect.
const _MIN_COVERAGE_PCT: float = 30.0

## Above this the "dark chassis + neon accent" identity inverts — the unit becomes mostly accent,
## and whole-unit-vs-stage contrast (which never passes) starts carrying the read instead.
## Highest shipping is Heavy at 62.7%.
const _MAX_COVERAGE_PCT: float = 75.0

## ★ Neutral is REQUIRED to be achromatic, not merely allowed to be. art-bible §4.2:
## "Neutral / unaligned — Achromatic, S 0–10%, L 70–80% — hue-less BY DESIGN, the value-neutral
## default, not a third ideology." Measured 0.0–0.5% across the roster, which is correct.
## ⚠ This assertion runs the OPPOSITE way to the owned factions. A gate that demanded coverage
##   here would fail correct art — which is exactly what a first draft of this suite did.
const _MAX_NEUTRAL_COVERAGE_PCT: float = 10.0

## rush and boom are recolours of one master, so their coverage should differ only by rounding.
## Measured deltas are all ≤ 0.5 points. A larger gap means one faction's derive went wrong.
const _MAX_FACTION_DELTA_PCT: float = 3.0

## Roster spread, highest archetype over lowest. 1.5x today; it was 4.7x with the Sniper defect
## present, so this catches a drift back toward that without demanding uniformity.
const _MAX_ROSTER_SPREAD: float = 2.5

# --- Coverage measurement ---------------------------------------------------------------------
# Mirrors tools/analyse_legibility.py TEST 3 exactly: body = alpha > 40/255; a body pixel counts as
# accent when HSV saturation > 0.45 AND value > 60/255. Godot's Color.s/.v ARE (max-min)/max and
# max, so the two implementations agree by construction rather than by coincidence.
const _ALPHA_FLOOR: float = 40.0 / 255.0
const _VALUE_FLOOR: float = 60.0 / 255.0
const _SAT_FLOOR: float = 0.45


func _sprite_path(archetype: String, faction: String) -> String:
	return "%s/unit_%s_%s_e_idle_01.png" % [_ART, archetype, faction]


## Percentage of an archetype's body pixels that carry a saturated accent, or -1.0 if the sprite
## is absent. Returns -1 rather than 0 so "missing" and "achromatic" never collapse into the same
## number — they are different failures and want different messages.
func _coverage_pct(path: String) -> float:
	if not ResourceLoader.exists(path):
		return -1.0
	var tex: Texture2D = load(path)
	if tex == null:
		return -1.0
	var img: Image = tex.get_image()
	if img == null:
		return -1.0
	if img.is_compressed():
		# Lossy import would skew saturation; decompress before measuring rather than trusting it.
		img.decompress()
	var body: int = 0
	var accent: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a <= _ALPHA_FLOOR:
				continue
			body += 1
			if c.s > _SAT_FLOOR and c.v > _VALUE_FLOOR:
				accent += 1
	if body == 0:
		return -1.0
	return 100.0 * float(accent) / float(body)


func test_every_owned_faction_sprite_carries_enough_accent_to_read_as_owned() -> void:
	# ★ The assertion the Sniper defect would have failed. Ownership is hue-only in shipped art
	# (S5-08 measured the non-hue backup absent roster-wide), so a unit with little saturated area
	# has little ownership signal no matter how good its ΔE is.
	var checked: int = 0
	for archetype: String in _ARCHETYPES:
		for faction: String in _OWNED_FACTIONS:
			var path: String = _sprite_path(archetype, faction)
			var pct: float = _coverage_pct(path)
			assert_float(pct).override_failure_message(
				"Missing or unreadable sprite: %s" % path).is_greater(-1.0)
			checked += 1
			assert_float(pct).override_failure_message(
				("%s %s carries accent on %.1f%% of its body, below the %.1f%% floor.\n" % [archetype, faction, pct, _MIN_COVERAGE_PCT]) +
				"Ownership in this art is hue-only, so coverage IS the ownership signal — the " +
				"Sniper shipped at 13.3%% and was rated a BLOCKING legibility defect (S5-03).\n" +
				"Fix the ART, not this threshold: raise saturated coverage via " +
				"tools/asset-pipeline/promote_accent.py and re-derive. Do NOT touch the silhouette."
			).is_greater_equal(_MIN_COVERAGE_PCT)
			assert_float(pct).override_failure_message(
				("%s %s carries accent on %.1f%% of its body, above the %.1f%% ceiling. " % [archetype, faction, pct, _MAX_COVERAGE_PCT]) +
				"Past this the dark-chassis/neon-accent identity inverts and whole-unit contrast " +
				"— which never passes against the stage — starts carrying the read."
			).is_less_equal(_MAX_COVERAGE_PCT)
	# ⚠ Guard the scan itself: a path typo would otherwise make this suite pass vacuously.
	assert_int(checked).override_failure_message(
		"Scanned no sprites — the path pattern is wrong and this suite is asserting nothing."
	).is_equal(_ARCHETYPES.size() * _OWNED_FACTIONS.size())


func test_neutral_stays_achromatic() -> void:
	# ★ Runs the OPPOSITE way to the test above, and deliberately. art-bible §4.2 requires Neutral
	# to be "Achromatic — S 0-10% — hue-less BY DESIGN, the value-neutral default, not a third
	# ideology". Neutral means UNOWNED, so carrying ownership hue would be the defect here.
	# ⚠ A first draft of this suite asserted a coverage FLOOR for every faction and would have
	#   failed correct art. Neutral measured 0.0-0.5% across the roster, which is right.
	for archetype: String in _ARCHETYPES:
		var path: String = _sprite_path(archetype, "neutral")
		var pct: float = _coverage_pct(path)
		if pct < 0.0:
			continue # Neutral art is optional per archetype; absence is not a failure here.
		assert_float(pct).override_failure_message(
			("%s neutral carries accent on %.1f%% of its body, above the %.1f%% ceiling. " % [archetype, pct, _MAX_NEUTRAL_COVERAGE_PCT]) +
			"Neutral is UNOWNED and must stay achromatic (art-bible §4.2) — hue on it reads as " +
			"an ownership claim the entity does not have."
		).is_less_equal(_MAX_NEUTRAL_COVERAGE_PCT)


func test_the_two_owned_factions_agree_per_archetype() -> void:
	# rush and boom are recolours of a single master, so their coverage should differ only by
	# rounding. A real gap means one faction's derive chain (recolor -> facings -> runtime ->
	# state variants) went wrong for that archetype alone — a failure that is invisible on the
	# board because each sprite looks fine in isolation.
	for archetype: String in _ARCHETYPES:
		var rush: float = _coverage_pct(_sprite_path(archetype, "rush"))
		var boom: float = _coverage_pct(_sprite_path(archetype, "boom"))
		if rush < 0.0 or boom < 0.0:
			continue
		assert_float(absf(rush - boom)).override_failure_message(
			"%s: rush %.1f%% vs boom %.1f%% — a %.1f-point gap between two recolours of one master. One derive went wrong." % [archetype, rush, boom, absf(rush - boom)]
		).is_less_equal(_MAX_FACTION_DELTA_PCT)


func test_the_roster_does_not_drift_apart_in_ownership_signal() -> void:
	# ★ The spread was 4.7x with the Sniper defect present and is 1.5x now. This catches a drift
	# back toward one unit being far harder to identify than its neighbours, which is the shape of
	# the original defect rather than any single unit's absolute value.
	var means: Dictionary = {}
	for archetype: String in _ARCHETYPES:
		var total: float = 0.0
		var n: int = 0
		for faction: String in _OWNED_FACTIONS:
			var pct: float = _coverage_pct(_sprite_path(archetype, faction))
			if pct >= 0.0:
				total += pct
				n += 1
		if n > 0:
			means[archetype] = total / float(n)
	assert_int(means.size()).override_failure_message(
		"No archetype means computed — the scan found nothing.").is_greater(0)
	var lo: float = INF
	var hi: float = 0.0
	var lo_name: String = ""
	var hi_name: String = ""
	for archetype: String in means:
		var v: float = means[archetype]
		if v < lo:
			lo = v
			lo_name = archetype
		if v > hi:
			hi = v
			hi_name = archetype
	assert_float(hi / maxf(lo, 0.001)).override_failure_message(
		"Ownership-signal spread is %.1fx (%s %.1f%% to %s %.1f%%), past the %.1fx limit. " % [hi / maxf(lo, 0.001), lo_name, lo, hi_name, hi, _MAX_ROSTER_SPREAD] +
		"It was 4.7x when the Sniper defect was live — one unit far harder to identify than its " +
		"neighbours is the shape of that defect, whatever the absolute numbers."
	).is_less_equal(_MAX_ROSTER_SPREAD)


# --- Cover prop ground contact (S8-10) --------------------------------------------------------

func test_a_cover_prop_sits_on_its_tile_not_above_it() -> void:
	# ★ Reported from play 2026-08-26: cover floated half a tile north of the ground, the exact
	# defect structures had in S6-29 and fixed the same way.
	#
	# A prop is anchored bottom-centre at grid_to_screen(), which returns the tile CENTRE. That is
	# right for a unit — feet ARE the bottom of the art — and wrong for anything standing on a base
	# diamond, whose lowest drawn pixel is the diamond's bottom VERTEX, half a tile-height below
	# the centre. The inset is the correction.
	assert_float(BoardRenderer.COVER_PROP_GROUND_INSET_PX).override_failure_message(
		"The cover ground inset must be half a tile height (%.1f). Anything else re-floats the " % (BoardRenderer.TILE_HEIGHT_PX * 0.5) +
		"prop or sinks it — and it must stay DERIVED from the tile metrics, not a literal."
	).is_equal_approx(BoardRenderer.TILE_HEIGHT_PX * 0.5, 0.001)


func test_the_cover_inset_matches_the_structure_inset_rule() -> void:
	# ★ Both are "half the base diamond's height for something drawn one tile wide". Pinning them
	# to each other means a change to the projection ratio moves both, and a change to only one is
	# visible here as a disagreement rather than as a subtly floating sprite on the board.
	assert_float(BoardRenderer.COVER_PROP_GROUND_INSET_PX).is_equal_approx(
		EntitySpriteFeed.STRUCTURE_GROUND_INSET_PX, 0.001)
