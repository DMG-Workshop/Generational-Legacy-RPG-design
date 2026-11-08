## Carry limits (roadmap item 43). The heir carries what is worn and what is in the pack, by each item's weight
## (data/items/items.json, item 42), plus a little for each healing potion; the most is `base_capacity` plus
## `per_strength` times their Strength (data/items/carry.json). Past it, nothing more is picked up by choice: a
## purchase is refused and a find is sold where it lies. Gifts from events and quests are always taken. Pure
## functions of the heir's state: nothing here draws a die, and the capacity is set so the autopilot is never
## refused, so its results and the golden digests do not move.
class_name GameCarry
extends RefCounted

const PATH := "res://data/items/carry.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## How much the heir can carry.
static func capacity(h: GameHeir) -> float:
	return float(setting("base_capacity")) + float(setting("per_strength")) * h.stat("str")


## What the heir carries now: the pack, what is worn, and the healing potions.
static func carried(h: GameHeir) -> float:
	var w := float(h.potions) * float(setting("potion_weight"))
	for id in h.inventory:
		w += GameItems.weight_of(str(id))
	for id in h.equipment.values():
		if str(id) != "":
			w += GameItems.weight_of(str(id))
	return w


static func room(h: GameHeir) -> float:
	return capacity(h) - carried(h)


## Whether the heir is over the limit (only a gift can do it).
static func burdened(h: GameHeir) -> bool:
	return carried(h) > capacity(h) + 0.0001


## Whether one more of this item fits.
static func can_carry(h: GameHeir, id: String) -> bool:
	return GameItems.weight_of(id) <= room(h) + 0.0001


static func why_not(h: GameHeir, id: String) -> String:
	if can_carry(h, id):
		return ""
	return text("too_heavy", {"h": h.name, "name": GameItems.item_name(id), "weight": _n(GameItems.weight_of(id)), "carried": _n(carried(h)), "capacity": _n(capacity(h))})


## "12.4 of 61" for the screens.
static func summary(h: GameHeir) -> String:
	return "%s of %s" % [_n(carried(h)), _n(capacity(h))]


static func _n(x: float) -> String:
	return "%.1f" % x if x < 10.0 else str(int(round(x)))


## Leaves one of an item in the pack behind. Worn gear is not dropped (take it off first). Returns the line.
static func drop(d: GameDynasty, id: String) -> String:
	var h := d.heir
	if id not in h.inventory:
		return text("cannot_drop", {"name": GameItems.item_name(id)})
	h.inventory.erase(id)
	if not GameItems.owns(h, id):
		h.tainted_gear.erase(id)
	return text("dropped", {"h": h.name, "name": GameItems.item_name(id)})


## A find that does not fit is sold where it lies: the gold and the line to tell. {} when it fits.
static func sell_find(d: GameDynasty, id: String, find_text: String) -> String:
	var g := GameItems.sell_price(d, id)
	d.heir.gold += g
	return text("search_heavy", {"h": d.heir.name, "find": find_text, "gold": GameText.num(g)})


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	if dat.is_empty() or not dat.has("settings") or not dat.has("text"):
		return ["carry.json: needs settings and text"]
	for k in ["base_capacity", "per_strength", "potion_weight"]:
		if not dat["settings"].has(k) or float(dat["settings"][k]) < 0.0:
			bad.append("carry.json: settings.%s is missing or negative" % k)
	for k in ["too_heavy", "search_heavy", "dropped", "cannot_drop"]:
		if not dat["text"].has(k):
			bad.append("carry.json: text.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(dat["settings"]["base_capacity"]) <= 0.0:
		bad.append("carry.json: base_capacity must be above 0")
	# everything the shops sell must be carriable by a fresh heir, or it could never be bought
	GameData.load_all()
	var heaviest := 0.0
	for id in GameData.items:
		heaviest = maxf(heaviest, GameItems.weight_of(str(id)))
	if heaviest > float(dat["settings"]["base_capacity"]):
		bad.append("carry.json: the heaviest item weighs %s, more than base_capacity" % heaviest)
	return bad
