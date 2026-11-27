## Fishing (data/world/fishing.json; ui/play/fishing_panel.gd draws it). The heir fishes from the bank of a sea, lake or river tile
## with a Fishing rod: a wait for a bite, then one tap to reel in. What bites is a pure function of the water body, the biome, the
## season, the hour and the weather, and every roll is a dice keyed on the seed, the tile, the hour and the cast number, never the
## dynasty's own, so a seeded life is exactly what it was and the autopilot (which never fishes) never meets any of this. A catch goes
## to the pack as a fish item, or to the family's stores as the `fish` material (small fish, and any fish a heavy pack cannot take),
## and feeds the record book: `GameDynasty.fishing` {caught: {item: {n, best}}, points}, saved only once something is caught and
## loaded clean. The cast number is runtime. No journal line is written, so replay fingerprints do not move.
## Run: godot --headless --path . -s res://tests/test_game_fishing.gd
class_name GameFishing
extends RefCounted

const PATH := "res://data/world/fishing.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func species() -> Array:
	return data()["species"]


## The species row of an item id ({} when it is none).
static func row(item: String) -> Dictionary:
	for s in species():
		if str(s["item"]) == item:
			return s
	return {}


static func fish_name(item: String) -> String:
	return str(row(item).get("name", item))


# ---------------------------------------------------------------- the rod, the bait and the bank

static func _count(h: GameHeir, id: String) -> int:
	var n := h.inventory.count(id)
	for bag in h.bags:
		n += (h.bags[bag] as Array).count(id)
	return n


static func rod_count(h: GameHeir) -> int:
	return _count(h, str(setting("rod")))


static func bait_count(h: GameHeir) -> int:
	return _count(h, str(setting("bait")))


## Takes one bait from the pack (or the first bag that holds one). False when there is none.
static func take_bait(h: GameHeir) -> bool:
	var id := str(setting("bait"))
	if h.inventory.has(id):
		h.inventory.erase(id)
		return true
	for bag in h.bags.keys():
		if (h.bags[bag] as Array).has(id):
			GameBags._remove(h, id)
			return true
	return false


## The nearest water to fish from at a tile: {x, z, body} within `bank_reach` tiles (sea, lake or river, never a ford), or {} when none.
static func spot(d: GameDynasty, x: int, z: int) -> Dictionary:
	var reach := float(setting("bank_reach"))
	var span := int(ceil(reach))
	var best := {}
	var best_dist := reach + 1.0
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var wx := x + dx
			var wz := z + dz
			if (dx == 0 and dz == 0) or not GameWorldGen.in_bounds(wx, wz):
				continue
			var dist := Vector2(dx, dz).length()
			if dist > reach or dist >= best_dist:
				continue
			var body := GameWorldGen.body_at(d.seed_value, wx, wz)
			if GameWorldGen.is_water(body):
				best_dist = dist
				best = {"x": wx, "z": wz, "body": body}
	return best


static func water_name(body: String) -> String:
	return str(data()["water_names"].get(body, "the water"))


## Why the heir cannot fish from this tile, or "" when they can (a rod and a bank).
static func why_not(d: GameDynasty, x: int, z: int) -> String:
	if rod_count(d.heir) <= 0:
		return text("no_rod", {"heir": d.heir.name})
	if spot(d, x, z).is_empty():
		return text("no_water")
	return ""


# ---------------------------------------------------------------- what bites

## What the water is like at a spot now: {body, biome, season, hour (0 to 23), weather}.
static func conditions(d: GameDynasty, sp: Dictionary) -> Dictionary:
	var look := GameDay.look(d)
	return {"body": str(sp["body"]), "biome": GameWorldGen.biome_at(d.seed_value, int(sp["x"]), int(sp["z"])),
		"season": str(look["season"]), "hour": int(floor(float(look["hour"]))) % 24, "weather": str(look["weather"])}


static func _in_hours(hour: int, win: Array) -> bool:
	var lo := int(win[0])
	var hi := int(win[1])
	return (hour >= lo and hour < hi) if lo <= hi else (hour >= lo or hour < hi)


## The odds of each fish under `cond` ({body, biome, season, hour, weather}): [{item, weight}] for the fish that can bite, in the list's
## order. With `bait`, the rarer fish are likelier. Pure.
static func odds(cond: Dictionary, bait: bool = false) -> Array:
	var out: Array = []
	for s in species():
		if str(cond["body"]) not in s["bodies"]:
			continue
		if s.has("biomes") and str(cond["biome"]) not in s["biomes"]:
			continue
		if s.has("seasons") and str(cond["season"]) not in s["seasons"]:
			continue
		if s.has("hours") and not _in_hours(int(cond["hour"]), s["hours"]):
			continue
		var w := float(s["weight"])
		w *= float(s.get("weather", {}).get(str(cond["weather"]), 1.0))
		w *= float(s.get("biome_mult", {}).get(str(cond["biome"]), 1.0))
		if bait and str(s["rarity"]) != "common":
			w *= float(setting("bait_rare_mult"))
		out.append({"item": str(s["item"]), "weight": w})
	return out


## The dice of one cast: keyed on the seed, the tile, the hour and the cast number (and what it is for), never the dynasty's own.
static func _dice(d: GameDynasty, sp: Dictionary, hour: int, cast_no: int, tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "fish_" + tag, int(sp["x"]), int(sp["z"]), hour, cast_no])
	return r


## The cast number to use next: catches so far and the casts made this run, so the same tile and hour do not give the same fish twice.
static func cast_number(d: GameDynasty) -> int:
	return total_caught(d) + d.fishing_casts


## Seconds until the bite: keyed, within `wait_min` to `wait_max`, shorter with bait and with the Angler level.
static func wait_seconds(d: GameDynasty, sp: Dictionary, cast_no: int, bait: bool) -> float:
	var cond := conditions(d, sp)
	var r := _dice(d, sp, int(cond["hour"]), cast_no, "wait")
	var t := r.randf_range(float(setting("wait_min")), float(setting("wait_max")))
	if bait:
		t *= float(setting("bait_wait_mult"))
	t *= maxf(float(setting("wait_floor_mult")), 1.0 - float(setting("level_wait_mult")) * float(level(d)))
	return t


## What bites on this cast: {item, cm, size (the tier's id), t (0 to 1 within the species' size range)}. Pure and repeatable.
static func bite(d: GameDynasty, sp: Dictionary, cast_no: int, bait: bool) -> Dictionary:
	var cond := conditions(d, sp)
	var table := odds(cond, bait)
	if table.is_empty():
		return {}
	var total := 0.0
	for o in table:
		total += float(o["weight"])
	var r := _dice(d, sp, int(cond["hour"]), cast_no, "bite")
	var pick := r.randf() * total
	var item := str(table[table.size() - 1]["item"])
	for o in table:
		pick -= float(o["weight"])
		if pick < 0.0:
			item = str(o["item"])
			break
	var rng := _dice(d, sp, int(cond["hour"]), cast_no, "size")
	var t := (rng.randf() + rng.randf()) * 0.5
	if bait:
		t += float(setting("bait_size_bonus"))
	t = clampf(t, 0.0, 1.0)
	var span: Array = row(item)["size"]
	var cm := snappedf(float(span[0]) + (float(span[1]) - float(span[0])) * t, 0.1)
	return {"item": item, "cm": cm, "size": size_id(t), "t": t}


static func size_id(t: float) -> String:
	for s in data()["sizes"]:
		if t <= float(s["upto"]):
			return str(s["id"])
	return str(data()["sizes"][data()["sizes"].size() - 1]["id"])


# ---------------------------------------------------------------- the reel-in skill check

## The marker's place (0 to 1) `t` seconds after the bite: it sweeps to and fro, a triangle wave of `bar_period` seconds.
static func marker(t: float) -> float:
	var period := float(setting("bar_period"))
	var p := fposmod(t / period, 1.0)
	return p * 2.0 if p < 0.5 else 2.0 - p * 2.0


## How wide the green zone is (0 to 1 of the bar): wider with the Angler level.
static func zone_width(d: GameDynasty) -> float:
	return minf(float(setting("zone_max")), float(setting("zone_width")) + float(setting("zone_per_level")) * float(level(d)))


## Where the zone's centre is for this cast (keyed, so the bar is the same bar for the same cast): the zone lies wholly on the bar.
static func zone_centre(d: GameDynasty, sp: Dictionary, cast_no: int) -> float:
	var w := zone_width(d)
	var r := _dice(d, sp, int(conditions(d, sp)["hour"]), cast_no, "zone")
	return r.randf_range(w * 0.5, 1.0 - w * 0.5)


## Whether a tap with the marker at `pos` is inside the zone.
static func hits(pos: float, centre: float, width: float) -> bool:
	return absf(pos - centre) <= width * 0.5 + 0.0001


# ---------------------------------------------------------------- the record book

static func caught(d: GameDynasty) -> Dictionary:
	return d.fishing.get("caught", {})


static func total_caught(d: GameDynasty) -> int:
	var n := 0
	for id in caught(d):
		n += int(caught(d)[id]["n"])
	return n


static func points(d: GameDynasty) -> int:
	return int(d.fishing.get("points", 0))


## The Angler level (0 up) for the points: the last level whose `at` has been reached.
static func level_for(pts: int) -> int:
	var lv := 0
	var levels: Array = data()["levels"]
	for i in levels.size():
		if pts >= int(levels[i]["at"]):
			lv = i
	return lv


static func level(d: GameDynasty) -> int:
	return level_for(points(d))


static func level_name(lv: int) -> String:
	var levels: Array = data()["levels"]
	return str(levels[clampi(lv, 0, levels.size() - 1)]["name"])


## Points still needed for the next level, or 0 at the top.
static func points_to_next(d: GameDynasty) -> int:
	var levels: Array = data()["levels"]
	var lv := level(d)
	return 0 if lv >= levels.size() - 1 else int(levels[lv + 1]["at"]) - points(d)


## Puts a catch in the book and in the pack or the stores: {text, new, best, to, level_up}. No journal line, no dice of the dynasty's.
static func land(d: GameDynasty, got: Dictionary) -> Dictionary:
	var item := str(got["item"])
	var s := row(item)
	var book: Dictionary = d.fishing.get("caught", {})
	var old: Dictionary = book.get(item, {})
	var is_new := old.is_empty()
	var cm := float(got["cm"])
	var is_best := not is_new and cm > float(old["best"])
	var before := level(d)
	book[item] = {"n": int(old.get("n", 0)) + 1, "best": maxf(cm, float(old.get("best", 0.0)))}
	d.fishing["caught"] = book
	d.fishing["points"] = points(d) + int(data()["rarities"][str(s["rarity"])]["points"])
	var to := str(s["to"])
	var heavy := false
	if to == "pack":
		if GameCarry.can_carry(d.heir, item):
			d.heir.inventory.append(item)
		else:
			to = "stores"
			heavy = true
	if to == "stores":
		GameCraft.add_material(d, str(setting("stores_material")), 1)
	var key := "caught_new" if is_new else ("caught_best" if is_best else "caught")
	var line := text(key, {"heir": d.heir.name, "size": str(got["size"]), "fish": str(s["name"]).to_lower(), "cm": _num(cm)})
	line += " " + (text("too_heavy") if heavy else text("to_pack" if to == "pack" else "to_stores"))
	var up := level(d) > before
	if up:
		line += " " + text("level_up", {"heir": d.heir.name, "level": level_name(level(d)), "n": level(d)})
	return {"text": line, "new": is_new, "best": is_best, "to": to, "level_up": up}


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v


## Worms turned up while foraging at the node (x, z): keyed on the seed, the node and the year, so it is the same for the same node.
## Puts them in the pack when they fit and returns how many ({0 for none}); draws no die of the dynasty's.
static func bait_find(d: GameDynasty, x: int, z: int) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "fish_worms", x, z, int(d.world.year)])
	if r.randf() >= float(setting("bait_find_chance")):
		return 0
	var n := r.randi_range(int(setting("bait_find_min")), int(setting("bait_find_max")))
	var got := 0
	for i in n:
		if not GameCarry.can_carry(d.heir, str(setting("bait"))):
			break
		d.heir.inventory.append(str(setting("bait")))
		got += 1
	return got


## The record book, one row per species in the list's order: {item, name, rarity, n, best (cm), size (tier of the best), caught}.
static func book(d: GameDynasty) -> Array:
	var out: Array = []
	for s in species():
		var e: Dictionary = caught(d).get(str(s["item"]), {})
		var best := float(e.get("best", 0.0))
		var span: Array = s["size"]
		var t := clampf((best - float(span[0])) / (float(span[1]) - float(span[0])), 0.0, 1.0)
		out.append({"item": str(s["item"]), "name": str(s["name"]), "rarity": str(s["rarity"]), "n": int(e.get("n", 0)), "best": best,
			"size": size_id(t) if not e.is_empty() else "", "caught": not e.is_empty()})
	return out


## What the Chronicle's Fishing tab says first: the Angler level, the catch so far and what the next level needs.
static func book_head(d: GameDynasty) -> String:
	if caught(d).is_empty():
		return text("book_empty")
	var kinds := 0
	for r in book(d):
		kinds += 1 if r["caught"] else 0
	var line := text("book_head", {"n": level(d), "level": level_name(level(d)), "caught": total_caught(d), "kinds": kinds, "all": species().size()})
	var need := points_to_next(d)
	if need > 0:
		line += " " + text("book_next", {"need": need, "next": level_name(level(d) + 1)})
	return line


## The line of one species in the book ("???" while it is not caught).
static func book_line(r: Dictionary) -> String:
	if not r["caught"]:
		return text("book_unknown")
	return text("book_row", {"fish": r["name"], "n": r["n"], "cm": _num(float(r["best"])), "size": r["size"]})


# ---------------------------------------------------------------- saving

## The saved book, checked: {} for anything damaged. Only species in the list with a whole count and a finite best length are kept.
static func load_state(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var out_caught := {}
	var src: Variant = (v as Dictionary).get("caught", {})
	if typeof(src) == TYPE_DICTIONARY:
		for id in src:
			var e: Variant = src[id]
			if typeof(e) != TYPE_DICTIONARY or row(str(id)).is_empty():
				continue
			var n: Variant = e.get("n", 0)
			var best: Variant = e.get("best", 0.0)
			if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or typeof(best) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or not is_finite(float(best)):
				continue
			if int(n) < 1 or float(best) <= 0.0:
				continue
			out_caught[str(id)] = {"n": int(n), "best": float(best)}
	if out_caught.is_empty():
		return {}
	var pts: Variant = (v as Dictionary).get("points", 0)
	var points_v := int(pts) if typeof(pts) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(pts)) and float(pts) >= 0.0 else 0
	return {"caught": out_caught, "points": points_v}


## What a save keeps: the book once something is caught, else {}.
static func to_save(d: GameDynasty) -> Dictionary:
	return {} if caught(d).is_empty() else {"caught": caught(d), "points": points(d)}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "rarities", "sizes", "levels", "species", "text", "water_names"]:
		if not dat.has(k):
			bad.append("fishing.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var st: Dictionary = dat["settings"]
	for k in ["rod", "bait", "stores_material", "bank_reach", "wait_min", "wait_max", "bait_wait_mult", "bait_rare_mult", "bait_size_bonus", "level_wait_mult", "wait_floor_mult", "bar_period", "zone_width", "zone_per_level", "zone_max", "no_timing_extra_wait", "bait_find_chance", "bait_find_min", "bait_find_max"]:
		if not st.has(k):
			bad.append("fishing.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["rod", "bait"]:
		if not GameData.items.has(str(st[k])):
			bad.append("fishing.json: settings.%s '%s' is not an item" % [k, st[k]])
	if not GameMaterials.has(str(st["stores_material"])):
		bad.append("fishing.json: settings.stores_material '%s' is not a material" % st["stores_material"])
	if float(st["bank_reach"]) < 1.0:
		bad.append("fishing.json: bank_reach must be at least 1 (the next tile)")
	if float(st["wait_min"]) <= 0.0 or float(st["wait_max"]) < float(st["wait_min"]):
		bad.append("fishing.json: the wait needs 0 < wait_min <= wait_max")
	if float(st["bar_period"]) <= 0.0:
		bad.append("fishing.json: bar_period must be above 0")
	if float(st["zone_width"]) <= 0.0 or float(st["zone_max"]) > 1.0 or float(st["zone_width"]) > float(st["zone_max"]):
		bad.append("fishing.json: the zone needs 0 < zone_width <= zone_max <= 1")
	for k in ["bait_wait_mult", "wait_floor_mult"]:
		if float(st[k]) <= 0.0 or float(st[k]) > 1.0:
			bad.append("fishing.json: %s must be above 0 and at most 1" % k)
	if float(st["bait_find_chance"]) < 0.0 or float(st["bait_find_chance"]) > 1.0 or int(st["bait_find_min"]) < 1 or int(st["bait_find_max"]) < int(st["bait_find_min"]):
		bad.append("fishing.json: the bait find needs a chance of 0 to 1 and 1 <= min <= max")
	for r in dat["rarities"]:
		if int(dat["rarities"][r].get("points", 0)) < 1:
			bad.append("fishing.json: rarity '%s' needs points of at least 1" % r)
	var last := 0.0
	for s in dat["sizes"]:
		if float(s["upto"]) <= last:
			bad.append("fishing.json: the size tiers must rise")
		last = float(s["upto"])
	if absf(last - 1.0) > 0.0001:
		bad.append("fishing.json: the last size tier must end at 1")
	var prev := -1
	for lv in dat["levels"]:
		if int(lv["at"]) <= prev or str(lv.get("name", "")) == "":
			bad.append("fishing.json: the levels need a name and rising points, from 0")
		prev = int(lv["at"])
	if not (dat["levels"] as Array).is_empty() and int(dat["levels"][0]["at"]) != 0:
		bad.append("fishing.json: the first level starts at 0 points")
	var bodies := ["sea", "lake", "river"]
	var seen := {}
	var covered := {}
	for s in dat["species"]:
		var id := str(s.get("item", ""))
		if seen.has(id):
			bad.append("fishing.json: '%s' is listed twice" % id)
		seen[id] = true
		var def: Dictionary = GameData.items.get(id, {})
		if def.is_empty():
			bad.append("fishing.json: fish '%s' is not an item" % id)
			continue
		if str(def.get("material", "")) != str(st["stores_material"]):
			bad.append("fishing.json: fish '%s' must be made of the stores material" % id)
		if int(def.get("price", 0)) < 1:
			bad.append("fishing.json: fish '%s' needs a price" % id)
		if str(s.get("name", "")) == "" or str(s.get("text", "")) == "":
			bad.append("fishing.json: fish '%s' needs a name and text" % id)
		if not dat["rarities"].has(str(s.get("rarity", ""))):
			bad.append("fishing.json: fish '%s' has an unknown rarity" % id)
		if float(s.get("weight", 0.0)) <= 0.0:
			bad.append("fishing.json: fish '%s' needs a weight above 0" % id)
		if str(s.get("to", "")) not in ["pack", "stores"]:
			bad.append("fishing.json: fish '%s' goes to pack or stores" % id)
		if not (s.get("bodies") is Array) or (s["bodies"] as Array).is_empty():
			bad.append("fishing.json: fish '%s' needs bodies of water" % id)
		else:
			for b in s["bodies"]:
				covered[str(b)] = true
				if str(b) not in bodies:
					bad.append("fishing.json: fish '%s' names the unknown water '%s'" % [id, b])
		var sz: Variant = s.get("size", [])
		if not (sz is Array) or (sz as Array).size() != 2 or float(sz[0]) <= 0.0 or float(sz[1]) <= float(sz[0]):
			bad.append("fishing.json: fish '%s' needs a size range [min, max] above 0" % id)
		for b in s.get("biomes", []) + (s.get("biome_mult", {}) as Dictionary).keys():
			if not GameWorldGen.data()["biomes"].has(str(b)):
				bad.append("fishing.json: fish '%s' names the unknown biome '%s'" % [id, b])
		for sea in s.get("seasons", []):
			if not _season_ids().has(str(sea)):
				bad.append("fishing.json: fish '%s' names the unknown season '%s'" % [id, sea])
		for w in (s.get("weather", {}) as Dictionary).keys():
			if not GameDay.data()["weather_look"].has(str(w)):
				bad.append("fishing.json: fish '%s' names the unknown weather '%s'" % [id, w])
		for k in ["weather", "biome_mult"]:
			for m in (s.get(k, {}) as Dictionary).values():
				if float(m) <= 0.0:
					bad.append("fishing.json: fish '%s' has a multiplier of 0 or less in %s" % [id, k])
		if s.has("hours"):
			var hw: Variant = s["hours"]
			if not (hw is Array) or (hw as Array).size() != 2 or int(hw[0]) < 0 or int(hw[0]) > 23 or int(hw[1]) < 0 or int(hw[1]) > 24:
				bad.append("fishing.json: fish '%s' needs hours [from, to] within 0 to 24" % id)
	for b in bodies:
		if not covered.has(b):
			bad.append("fishing.json: nothing bites in the %s" % b)
	var n := (dat["species"] as Array).size()
	if n < 8 or n > 12:
		bad.append("fishing.json: the book lists 8 to 12 fish, not %d" % n)
	for k in ["no_rod", "no_water", "indoors", "upstairs", "fight", "bank", "cast", "cast_bait", "waiting", "bite", "tap_to_reel", "easy_reel", "caught", "caught_new", "caught_best", "to_pack", "to_stores", "too_heavy", "missed", "missed_free", "level_up", "worms", "cast_again", "reel", "close", "bait_left", "no_bait", "book_empty", "book_head", "book_next", "book_row", "book_unknown", "act_fish", "walk_bank"]:
		if not dat["text"].has(k):
			bad.append("fishing.json: text.%s is missing" % k)
	return bad


static func _season_ids() -> Array:
	return (GameData.world["seasons"] as Array).map(func(s): return str(s["id"]))
