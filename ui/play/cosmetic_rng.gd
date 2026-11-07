## The dice of the view. Anything that looks different from one time to the next for show only (a painted
## scene's scatter, particles, an idle animation's timing, camera shake) draws from these, never from the
## dynasty's seeded dice and never from Godot's global ones. A view therefore cannot change a life, and the
## same seed with the same commands plays the same with the view on or off (tests/test_game_cosmetic.gd
## holds every file under ui/ to this).
class_name CosmeticRng
extends RefCounted


## Dice that roll the same every time for `key`: a picture that must be painted the same on every visit.
static func keyed(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = key.hash()
	return r


## Dice that differ on every run, for effects that should: seeded from the clock.
static func loose() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = Time.get_ticks_usec()
	return r
