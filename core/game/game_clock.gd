## The world clock: real time, for a world that runs while the player moves in it, turned into the same spans
## of years that actions pass. Hunting, resting and training pass whole years through GameDynasty.pass_time;
## a sandbox feeds this clock the seconds that go by instead, and it hands the world one `clock_span_years`
## at a time through the very same call, so ageing, wages, disease, weather, the death roll and the Ages work
## alike under either. Time not yet a whole span is carried (and saved) until the next feed. The clock holds
## still while a fight is on, an event waits for an answer, or the heir has died and the line is choosing.
## Logic only: the caller decides what "a second" is. Tunables: balance.json "clock_*".
class_name GameClock
extends RefCounted


## Whether the world may move on right now.
static func running(d: GameDynasty) -> bool:
	return d.state == "life" and d.battle == null and d.pending_event.is_empty()


## Seconds of play it takes a year to pass.
static func seconds_per_year() -> float:
	return maxf(0.001, float(GameData.bal("clock_seconds_per_year")))


## The least time the world lives through at once, in years (what an action's year already is).
static func span_years() -> float:
	return maxf(0.01, float(GameData.bal("clock_span_years")))


## `seconds` of real time go by. Returns the messages of whatever the world lived through. Held time is lost,
## not saved up: a fight does not bank years.
static func feed(d: GameDynasty, seconds: float, msgs: Array = []) -> Array:
	if seconds <= 0.0 or not running(d):
		return msgs
	d.clock_carry += seconds / seconds_per_year()
	var span := span_years()
	while d.clock_carry >= span and running(d):
		d.clock_carry -= span
		d.pass_time(span, msgs)
	return msgs


## Years the clock holds, not yet lived through.
static func carried(d: GameDynasty) -> float:
	return d.clock_carry
