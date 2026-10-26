## The wait between uses of the life screen's two autopilot buttons ("life": Auto: this life, "gens":
## Auto: 10 gens). Real time, so it runs while the game is closed: the moment each button is ready
## again is kept as Unix time in user://settings.cfg (not in the dynasty save), and read back capped
## to one cooldown from now, so a hand-edited file or a changed clock cannot lock a button for long.
## Lengths live in data/ui/mobile.json. Only the buttons ask; GameBot and the harness never do.
## Tests set `clock` to a Callable returning seconds, so nothing sleeps.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")

static var clock := Callable()   # empty: the system clock
static var ready_at := {}        # id -> Unix time the button is ready; empty until read from disk


static func ids() -> Array:
	return ["life", "gens"]


static func now() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_unix_time_from_system()


## The cooldown length of `id`, in seconds.
static func seconds(id: String) -> float:
	return maxf(0.0, float(UiSettings.setting("autopilot_%s_cooldown_seconds" % id)))


static func _key(id: String) -> String:
	return "autopilot_%s_ready_at" % id


## Forget what was read, so the next question reads the file again.
static func forget() -> void:
	ready_at = {}


static func _at(id: String) -> float:
	if not ready_at.has(id):
		var raw: Variant = UiSettings.stored(_key(id), 0.0)   # files from before the setting have no key
		var v := float(raw) if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT else 0.0   # anything else reads as ready
		ready_at[id] = 0.0 if is_nan(v) or is_inf(v) else minf(v, now() + seconds(id))
	return ready_at[id]


## Seconds until `id` may be used again; 0 when it may be used now.
static func remaining(id: String) -> float:
	return clampf(_at(id) - now(), 0.0, seconds(id))


static func is_ready(id: String) -> bool:
	return remaining(id) <= 0.0


## `id` was just used: it is ready again one cooldown from now.
static func start(id: String) -> void:
	ready_at[id] = ceilf(now() + seconds(id))   # whole seconds: the file keeps no more digits than that
	UiSettings.store(_key(id), ready_at[id])


## True while any button is still counting down.
static func any_active() -> bool:
	for id in ids():
		if not is_ready(id):
			return true
	return false


## Seconds as M:SS, rounded up so the last second shows 0:01 and never 0:00.
static func format(secs: float) -> String:
	var t := int(ceil(maxf(secs, 0.0)))
	return "%d:%02d" % [t / 60, t % 60]


## The button's text: its own, with the time left while it counts down.
static func label(id: String, text: String) -> String:
	return text if is_ready(id) else "%s (%s)" % [text, format(remaining(id))]


static func tip(id: String, what: String) -> String:
	if is_ready(id):
		return "%s Cooldown %s" % [what, format(seconds(id))]
	return "Ready in %s" % format(remaining(id))
