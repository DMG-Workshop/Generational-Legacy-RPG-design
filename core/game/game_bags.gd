## Bags (data/items/bags.json; a bag is an item in items.json with a `bag` block). The heir carries bags to carry
## their loot: a bag holds a set number of things, adds to the most the heir can carry, and may hold other bags,
## without limit. A magic bag may also lighten what is in it, and cannot itself be put inside another bag.
##
## Each bag the heir owns is its own thing, `<id>#<n>`, so two satchels hold different things; a plain bag id found
## in the pack (bought, found or given) becomes one the first time any function here looks (`normalize`). What a
## bag holds is `GameHeir.bags` ({bag instance: [item ids]}), saved only once something is in a bag. Pure functions
## of the heir's state: nothing here draws a die, and a heir with no bag is exactly what they were before.
class_name GameBags
extends RefCounted

const PATH := "res://data/items/bags.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- what is a bag

## `satchel#3` is the third bag, made from `satchel`. Anything else is its own id.
static func base_id(id: String) -> String:
	return id.get_slice("#", 0)


static func is_instance(id: String) -> bool:
	return "#" in id


## The `bag` block of the item, or {} for what is not a bag.
static func def(id: String) -> Dictionary:
	var b: Variant = GameItems.item_def(base_id(id)).get("bag", {})
	return b if typeof(b) == TYPE_DICTIONARY else {}


static func is_bag(id: String) -> bool:
	return not def(id).is_empty()


static func is_magic(id: String) -> bool:
	return bool(def(id).get("magic", false))


static func slots(id: String) -> int:
	return int(def(id).get("slots", 0))


## The share of the weight inside that does not count.
static func lighten(id: String) -> float:
	return float(def(id).get("lighten", 0.0))


static func contents(h: GameHeir, bag: String) -> Array:
	var c: Variant = h.bags.get(bag, [])
	return (c as Array).duplicate() if typeof(c) == TYPE_ARRAY else []


static func free_slots(h: GameHeir, bag: String) -> int:
	return slots(bag) - contents(h, bag).size()


static func is_empty(h: GameHeir, bag: String) -> bool:
	return contents(h, bag).is_empty()


# ---------------------------------------------------------------- naming each bag

static func _number(id: String) -> int:
	var n := id.get_slice("#", 1)
	return int(n) if n.is_valid_int() else 0


## The highest bag number in use anywhere the heir keeps things.
static func _top(h: GameHeir) -> int:
	var top := 0
	for id in h.inventory:
		top = maxi(top, _number(str(id)))
	for bag in h.bags:
		top = maxi(top, _number(str(bag)))
		for id in h.bags[bag]:
			top = maxi(top, _number(str(id)))
	return top


## Turns every plain bag id in the pack into a bag of its own. Idempotent; nothing at all for a heir with no bag.
static func normalize(h: GameHeir) -> void:
	var next := -1
	for i in h.inventory.size():
		var id := str(h.inventory[i])
		if not is_instance(id) and is_bag(id):
			if next < 0:
				next = _top(h) + 1
			h.inventory[i] = "%s#%d" % [id, next]
			next += 1


# ---------------------------------------------------------------- where things are

## Where an item is: "" loose in the pack, the id of the bag holding it, or null when the heir does not have it.
static func where(h: GameHeir, id: String) -> Variant:
	if id in h.inventory:
		return ""
	for bag in h.bags:
		if id in h.bags[bag]:
			return str(bag)
	return null


## Whether a bag is somewhere the heir can reach: loose in the pack, or inside a bag that is.
static func reachable(h: GameHeir, bag: String) -> bool:
	var at: Variant = where(h, bag)
	var guard := 0
	while at != null and str(at) != "" and guard < 1000:
		at = where(h, str(at))
		guard += 1
	return at != null and str(at) == ""


## Every bag in `bag`, however deep.
static func inside(h: GameHeir, bag: String) -> Array:
	var out: Array = []
	var queue: Array = [bag]
	while not queue.is_empty():
		var b := str(queue.pop_front())
		for id in contents(h, b):
			if is_bag(str(id)):
				out.append(str(id))
				queue.append(str(id))
	return out


## Every bag the heir has, loose or inside another.
static func all_bags(h: GameHeir) -> Array:
	var out: Array = []
	for id in h.inventory:
		if is_bag(str(id)):
			out.append(str(id))
			out.append_array(inside(h, str(id)))
	return out


# ---------------------------------------------------------------- weight and room

## What a bag weighs with what is in it: its own weight, plus the weight of its contents less its lightening.
static func weight(h: GameHeir, id: String) -> float:
	var w := GameItems.weight_of(id)
	if not is_bag(id):
		return w
	var inner := 0.0
	for item in contents(h, id):
		inner += weight(h, str(item))
	return w + inner * (1.0 - lighten(id))


## What the bags add to the most the heir can carry.
static func carry_bonus(h: GameHeir) -> float:
	var sum := 0.0
	for bag in all_bags(h):
		sum += float(def(bag).get("carry", 0.0))
	return sum


# ---------------------------------------------------------------- putting in and taking out

static func _no(text_key: String, vals: Dictionary) -> Dictionary:
	return {"ok": false, "text": text(text_key, vals)}


## Puts an item the heir carries (loose, or in another bag) into a bag they can reach. {ok, text}.
static func put(h: GameHeir, item: String, bag: String) -> Dictionary:
	normalize(h)
	var nm := GameItems.item_name(item)
	var bn := GameItems.item_name(bag)
	if not is_bag(bag):
		return _no("not_a_bag", {"bag": bn})
	if where(h, bag) == null:
		return _no("no_such_bag", {"h": h.name, "bag": bn})
	if where(h, item) == null:
		return _no("not_carried", {"h": h.name, "item": nm})
	if item == bag or bag in inside(h, item):
		return _no("into_itself", {"bag": nm})
	if is_magic(item):
		return _no("magic_in_bag", {"item": nm})
	if free_slots(h, bag) <= 0:
		return _no("full", {"bag": bn, "slots": slots(bag)})
	_remove(h, item)
	if not h.bags.has(bag):
		h.bags[bag] = []
	(h.bags[bag] as Array).append(item)
	return {"ok": true, "text": text("put", {"h": h.name, "item": nm, "bag": bn})}


## Takes an item out of its bag and into the pack. {ok, text}.
static func take(h: GameHeir, item: String) -> Dictionary:
	normalize(h)
	var at: Variant = where(h, item)
	var nm := GameItems.item_name(item)
	if at == null:
		return _no("not_carried", {"h": h.name, "item": nm})
	if str(at) == "":
		return _no("not_in_bag", {"item": nm, "bag": "pack"})
	var bag := str(at)
	_remove(h, item)
	h.inventory.append(item)
	return {"ok": true, "text": text("took", {"h": h.name, "item": nm, "bag": GameItems.item_name(bag)})}


## Takes an item out of wherever it is, without putting it anywhere (the caller does).
static func _remove(h: GameHeir, item: String) -> void:
	var at: Variant = where(h, item)
	if at == null:
		return
	if str(at) == "":
		h.inventory.erase(item)
	else:
		(h.bags[str(at)] as Array).erase(item)
		if (h.bags[str(at)] as Array).is_empty():
			h.bags.erase(str(at))


## Why a bag may not be sold or left behind, "" if it may (a bag holding something would lose it).
static func why_not_let_go(h: GameHeir, id: String) -> String:
	if is_bag(id) and not is_empty(h, id):
		return text("bag_not_empty", {"bag": GameItems.item_name(id)})
	return ""


# ---------------------------------------------------------------- saving

## What the dynasty saves: {bag: [ids]} for the bags that hold something, nothing for the others.
static func to_dict(h: GameHeir) -> Dictionary:
	var out := {}
	for bag in h.bags:
		if not (h.bags[bag] as Array).is_empty() and reachable(h, str(bag)):
			out[str(bag)] = (h.bags[bag] as Array).duplicate()
	return out


## Loads what was saved, cleaned: only real bags, only things that exist, each thing once, no bag inside itself or
## inside a magic bag's rule-breaking place, no more than a bag's slots, and only what can be reached from the pack.
static func load_state(raw: Variant, inventory: Array) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var seen := {}
	for id in inventory:
		seen[str(id)] = true
	var pending: Array = []
	for id in inventory:
		pending.append(str(id))
	while not pending.is_empty():   # walk out from the pack, so only what is reachable is kept and nothing is counted twice
		var bag := str(pending.pop_front())
		if not is_bag(bag) or not raw.has(bag) or typeof(raw[bag]) != TYPE_ARRAY:
			continue
		var kept: Array = []
		for item in raw[bag]:
			var it := str(item)
			if seen.has(it) or GameItems.item_def(it).is_empty() or kept.size() >= slots(bag):
				continue
			if is_bag(it) and (is_magic(it) or not is_instance(it)):
				continue
			seen[it] = true
			kept.append(it)
			pending.append(it)
		if not kept.is_empty():
			out[bag] = kept
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	if dat.is_empty() or not dat.has("text"):
		return ["bags.json: needs text"]
	for k in ["put", "took", "not_carried", "no_such_bag", "not_a_bag", "into_itself", "magic_in_bag", "full", "not_in_bag", "bag_not_empty"]:
		if not dat["text"].has(k):
			bad.append("bags.json: text.%s is missing" % k)
	GameData.load_all()
	var count := 0
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if not it.has("bag"):
			continue
		count += 1
		var b: Variant = it["bag"]
		if typeof(b) != TYPE_DICTIONARY:
			bad.append("items.json: '%s' bag is not a block" % id)
			continue
		if "#" in str(id):
			bad.append("items.json: '%s' has a # in its id, which names the bag instances" % id)
		if int(b.get("slots", 0)) < 1:
			bad.append("items.json: bag '%s' needs at least 1 slot" % id)
		if float(b.get("carry", -1.0)) < 0.0:
			bad.append("items.json: bag '%s' needs a carry bonus of 0 or more" % id)
		var lighten_by := float(b.get("lighten", 0.0))
		if lighten_by < 0.0 or lighten_by > 0.9:
			bad.append("items.json: bag '%s' lightens by %s, not 0 to 0.9" % [id, lighten_by])
		if lighten_by > 0.0 and not bool(b.get("magic", false)):
			bad.append("items.json: bag '%s' lightens but is not magic" % id)
		if str(it.get("slot", "")) != "":
			bad.append("items.json: bag '%s' cannot be worn" % id)
	if count == 0:
		bad.append("items.json: there are no bags")
	return bad
