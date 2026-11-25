## Smoke pots (data/world/sandbox.json `smoke`, the item `smoke_pot`). Using one lights a cloud on the heir's tile for a while of the
## world clock: while it lasts nothing spawns inside it, the creatures in it give up and are driven out, and a creature outside cannot
## start a fight with a heir who stands inside it. The cloud is `GameDynasty.smoke` ({x, z, until}, world-clock seconds), saved only
## while it burns and loaded clean. Pure rules: no dice. Only the open world uses it, so the autopilot never meets a pot.
## Run: godot --headless --path . -s res://tests/test_game_smoke.gd
class_name GameSmoke
extends RefCounted


static func data() -> Dictionary:
	return GameSandbox.data()["smoke"]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func item_id() -> String:
	return str(data()["item"])


static func radius() -> float:
	return float(data()["radius"])


## Whether a cloud burns now.
static func active(d: GameDynasty) -> bool:
	return not d.smoke.is_empty() and float(d.smoke["until"]) > d.world_seconds


## Seconds of the cloud left (0 when none).
static func left(d: GameDynasty) -> float:
	return maxf(0.0, float(d.smoke["until"]) - d.world_seconds) if not d.smoke.is_empty() else 0.0


## "2:10" for the seconds left, the way the status pane shows it.
static func clock_text(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [floori(float(s) / 60.0), s % 60]


## The cloud's centre as a point, or null when none burns.
static func centre(d: GameDynasty) -> Variant:
	if not active(d):
		return null
	return Vector2(float(d.smoke["x"]), float(d.smoke["z"]))


## Whether the point (x, z) is inside the cloud.
static func covers(d: GameDynasty, x: float, z: float) -> bool:
	var c: Variant = centre(d)
	return c != null and Vector2(x, z).distance_to(c) <= radius()


## The pots the heir has, loose in the pack or in a bag.
static func count(h: GameHeir) -> int:
	var n := h.inventory.count(item_id())
	for bag in h.bags:
		n += (h.bags[bag] as Array).count(item_id())
	return n


## Takes one pot from the pack (or the first bag that holds one). False when there is none.
static func take_one(h: GameHeir) -> bool:
	if h.inventory.has(item_id()):
		h.inventory.erase(item_id())
		return true
	for bag in h.bags.keys():
		if (h.bags[bag] as Array).has(item_id()):
			GameBags._remove(h, item_id())
			return true
	return false


## Lights a cloud at (x, z). The clock is not advanced.
static func light(d: GameDynasty, x: float, z: float) -> void:
	d.smoke = {"x": x, "z": z, "until": d.world_seconds + float(data()["seconds"])}


## A cloud that has burned out is dropped (called by the sandbox's step).
static func clear_if_out(d: GameDynasty) -> bool:
	if not d.smoke.is_empty() and not active(d):
		d.smoke = {}
		return true
	return false


# ---------------------------------------------------------------- saving

## The saved cloud, kept only while it burns: {} for anything else (a wrong kind, a number that is not finite, a point outside the world,
## a cloud already out). A time further off than one cloud can last is cut to the longest it can.
static func load_state(v: Variant, now: float) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var s: Dictionary = v
	for k in ["x", "z", "until"]:
		if not s.has(k) or typeof(s[k]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(s[k])):
			return {}
	if not GameWorldGen.in_bounds(int(floor(float(s["x"]))), int(floor(float(s["z"])))):
		return {}
	var until := float(s["until"])
	if until <= now:
		return {}
	return {"x": float(s["x"]), "z": float(s["z"]), "until": minf(until, now + float(data()["seconds"]))}


static func validate() -> Array:
	var bad: Array = []
	var sm: Variant = GameSandbox.data().get("smoke", null)
	if typeof(sm) != TYPE_DICTIONARY:
		return ["sandbox.json: smoke is missing"]
	for k in ["item", "radius", "seconds", "drive", "puffs", "text"]:
		if not (sm as Dictionary).has(k):
			bad.append("sandbox.json: smoke.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(sm["radius"]) < 1.0 or float(sm["seconds"]) <= 0.0 or float(sm["drive"]) <= 0.0 or int(sm["puffs"]) < 1:
		bad.append("sandbox.json: smoke needs a radius of at least 1, seconds, drive and puffs above 0")
	for k in ["lit", "none", "indoors", "upstairs", "fight", "already", "thinned", "timer"]:
		if not (sm["text"] as Dictionary).has(k):
			bad.append("sandbox.json: smoke.text.%s is missing" % k)
	GameData.load_all()
	if not GameData.items.has(str(sm["item"])):
		bad.append("sandbox.json: smoke.item '%s' is not an item" % sm["item"])
	return bad
