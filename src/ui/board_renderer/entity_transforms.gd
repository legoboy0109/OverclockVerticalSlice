## EntityTransforms — the move/attack/hit/destroyed motion numbers for §8.5,
## Presentation layer (Story 008 / sprint task S5-06).
##
## [b]The single source of truth for the motion values[/b], the way [EntityGlow]
## is for the glow values. [EntitySpriteFeed] owns the tweens; this class owns
## every number and curve choice they use, so retuning the feel means editing one
## file and no call sites.
##
## [b]These are renderer transforms, not art.[/b] Art-bible §8.5 lists Move,
## Attack and Hit as animation states, but the shipped assets are single-frame
## per state ([code]idle_01[/code] / [code]destroyed_01[/code] only — see
## [code]assets/art/README.md[/code]); there are no move or attack sheets and none
## are planned at vertical-slice scope. The states are therefore expressed as
## tweened transforms on the one sprite. Only Destroyed has real art, and it is
## the only state here that touches [member Sprite2D.texture].
##
## [b]Every value below is a feel value, not a locked one[/b] (contrast
## [constant EntityGlow.RUSH_HUE], which is palette-locked). Retune them from the
## S5-03 legibility session and the S5-07 sign-off, not from taste — §8.5's one
## hard constraint is that Move "must survive repetition", which is what keeps the
## lean small.
##
## Usage:
## [codeblock]
## sprite.rotation = EntityTransforms.lean_angle(travel_px)
## var away := EntityTransforms.nudge(target_px, attacker_px, EntityTransforms.RECOIL_DISTANCE_PX)
## [/codeblock]
class_name EntityTransforms
extends RefCounted

# --- Move lean ---------------------------------------------------------------

## Peak lean, in degrees, of a moving actor tipping into its direction of travel.
##
## [b]Deliberately small.[/b] §8.5 calls Move "the most-seen animation, must
## survive repetition" — a lean big enough to be striking on the first move is
## nauseating by the fiftieth. This is a tell, not a flourish.
const LEAN_ANGLE_DEG: float = 6.0

## Seconds to tip into the lean.
const LEAN_OUT_SEC: float = 0.09

## Seconds to settle back upright. Longer than the tip so the motion reads as
## momentum bleeding off rather than a snap back to attention.
const LEAN_SETTLE_SEC: float = 0.16

# --- Attack lunge ------------------------------------------------------------

## How far, in on-screen pixels, an attacker shoves toward its target at the peak
## of the lunge.
const LUNGE_DISTANCE_PX: float = 10.0

## Seconds out to the peak. [b]Short on purpose[/b] — §8.5 wants the attack
## "snappy, synced to the §2.2 flare spike"; the glow flare starts on the same
## frame ([method EntitySpriteFeed.flare]), so the body and the light spike
## together.
const LUNGE_OUT_SEC: float = 0.07

## Seconds back to rest. Roughly 2.5x the strike, which is what makes the pair
## read as a committed blow rather than a twitch.
const LUNGE_BACK_SEC: float = 0.18

# --- Hit recoil --------------------------------------------------------------

## How far, in on-screen pixels, a struck actor rocks away from its attacker.
##
## Smaller than [constant LUNGE_DISTANCE_PX] by design: §8.5 asks for a "brief
## plating-absorbs-impact recoil", so the armour wins. A recoil that out-travels
## the blow that caused it reads as a knockback, which is a mechanic this game
## does not have.
const RECOIL_DISTANCE_PX: float = 6.0

## Seconds out to the peak of the recoil — faster than the lunge, because impact
## is instantaneous where a swing is deliberate.
const RECOIL_OUT_SEC: float = 0.05

## Seconds to absorb and return. The slowest return of the three: this is the
## "absorbs" half of "plating absorbs impact".
const RECOIL_BACK_SEC: float = 0.22

# --- Destroyed beat ----------------------------------------------------------

## Seconds the destroyed cross-fade occupies.
##
## §8.5 locks the destroyed beat at [b]2-4 frames[/b], which is a count of
## ANIMATION frames at the art bible's low functional frame rate (~10 fps), not
## display frames — so the locked beat is roughly a fifth to two fifths of a
## second. 0.35s sits at the slow end of that, because we cross-fade two stills
## rather than playing a sequence and a fade needs longer than a cut to read.
##
## The beat is also the entire lifetime extension: an entity is gone from
## [method GameState.entities] the instant its hp hits zero, and
## [EntitySpriteFeed] holds its node alive for exactly this long so §8.5's
## power-down can play at all.
const DEATH_ECHO_SEC: float = 0.35

## Seconds of the beat spent fading the glow to nothing, as a fraction of
## [constant DEATH_ECHO_SEC]. The light dies FIRST and the body follows — a
## shutdown, not an explosion (§8.5 "no gibs", concept's no-shaming stance).
const DEATH_GLOW_FRACTION: float = 0.6

# --- Helpers -----------------------------------------------------------------

## The signed lean angle in RADIANS for an actor whose travel this frame was
## [param screen_delta] (a screen-space vector, y-down).
##
## Positive rotation tips a sprite's top to the right in Godot's 2D frame, so
## rightward travel leans right. Anchoring is what makes this read as a lean at
## all: the sprite's origin is its ground-contact point (bottom-centre, per
## [EntitySpriteFeed]'s pivot rule), so rotation pivots at the feet. Rotating a
## bbox-centred sprite would slide the feet through the floor instead.
##
## Returns 0 for travel with no horizontal component — a straight up-screen move
## has no side to lean toward, and leaning by tie-break would flicker.
static func lean_angle(screen_delta: Vector2) -> float:
	if is_zero_approx(screen_delta.x):
		return 0.0
	return deg_to_rad(LEAN_ANGLE_DEG) * signf(screen_delta.x)


## A screen-space nudge of [param distance] pixels pointing from [param from_px]
## toward [param to_px].
##
## Used both ways round: an attacker nudges toward its target (lunge), a struck
## actor nudges away from its attacker (recoil, arguments reversed). Coincident
## points return [constant Vector2.ZERO] rather than a fallback direction — a
## nudge with no meaningful direction is better skipped than guessed.
static func nudge(from_px: Vector2, to_px: Vector2, distance: float) -> Vector2:
	var delta: Vector2 = to_px - from_px
	if delta.is_zero_approx():
		return Vector2.ZERO
	return delta.normalized() * distance
