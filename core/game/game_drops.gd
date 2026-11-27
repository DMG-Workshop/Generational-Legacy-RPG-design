## Loot on the open world's ground. A fight begun in the open world and won leaves what the dead carried where they fell, as
## small objects (a coin pile, a bundle, a gem, an egg) that the heir picks up by walking over them, instead of the
## Search the bodies / Leave them choice (which the text game and the battle result keep).
## Nothing about the loot's rules changes: the search is played by `GameLoot.search_dead`, with its dice keyed and drawn exactly
## as before, on a COPY of the dynasty; the copy's gains (gold, potions, items, materials, young) become drops, and what the
## search would have cost (a sickness) is paid by the first thing taken from that fight. The dynasty's own dice end where the
## search left them, so a seeded life is the same either way. The autopilot never plays an open-world fight, so none of its
## runs, hunts or golden digests move. Drops are `GameDynasty.drops`, saved only while some lie (older saves have none).
## Where they land is keyed on the seed and the hunt, never the dynasty's dice.
## Run: godot --headless --path . -s res://tests/test_game_drops.gd
class_name GameDrops
extends RefCounted

const PATH := "res://data/world/drops.json"
const SHAPES := ["coins", "bundle", "gem", "egg"]
const KINDS := ["gold", "potion", "item", "material", "essence", "egg"]
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- making drops

## The fight's dead (`d.loot`) searched and left on the ground round `spots` (the points where the foes fell, in order): returns
## the drops made ([] when there is nothing to search, or the heir is not in a life). `walkable` is a Callable(Vector2i) -> bool for
## tiles a drop may land on (any tile when unset).
static func scatter(d: GameDynasty, spots: Array, walkable: Callable = Callable()) -> Array:
	if d.state != "life" or d.loot.is_empty():
		return []
	var risk := GamePlague.risk_text(d)
	var found := _search_copy(d)
	d.loot = {}
	d.rng.state = int(found["rng_state"])   # the dice end exactly where a search of the bodies leaves them
	var made: Array = []
	var until := d.world_seconds + float(setting("ttl_seconds"))
	var gid := _next_uid(d)
	var sick: Array = found["sick"]
	var spare: Array = []
	if int(found["gold"]) > 0:
		spare.append({"kind": "gold", "gold": int(found["gold"])})
	if int(found["potions"]) > 0:
		spare.append({"kind": "potion", "n": int(found["potions"])})
	for id in found["items"]:
		spare.append({"kind": "item", "item": str(id)})
	if not (found["mats"] as Dictionary).is_empty():
		spare.append({"kind": "material", "mats": found["mats"]})
	if not (found["ess"] as Dictionary).is_empty():
		spare.append({"kind": "essence", "ess": found["ess"]})
	for e in found["eggs"]:
		spare.append({"kind": "egg", "species": str(e["species"]), "name": str(e["name"]), "born": str(e["born"])})
	var taken := {}
	for p in d.drops:
		taken[_tile_key(Vector2i(floori(float(p["x"])), floori(float(p["z"]))))] = true
	var r := RandomNumberGenerator.new()
	for i in spare.size():
		var drop: Dictionary = spare[i]
		r.seed = hash([d.seed_value, "drop", d.total_hunts, i])
		var at := _spot(r, spots, i, taken, walkable)
		taken[_tile_key(at)] = true
		drop["uid"] = gid + i
		drop["gid"] = gid
		drop["x"] = float(at.x) + 0.5
		drop["z"] = float(at.y) + 0.5
		drop["until"] = until
		drop["sick"] = sick.duplicate()
		made.append(drop)
	d.drops.append_array(made)
	var cap := int(setting("max_drops"))
	if d.drops.size() > cap:
		d.drops = d.drops.slice(d.drops.size() - cap)
	if not made.is_empty():
		var line := text("scattered", {"foes": _foes_text(found["foe_names"])})
		d._say(line + " " + risk)
	return made


## The search of the bodies played on a copy of the dynasty (every die as the real search draws it, the pack's weight left to the
## pickup): what it gained as {gold, potions, items, mats, ess, eggs, sick, rng_state, foe_names}.
static func _search_copy(d: GameDynasty) -> Dictionary:
	var names: Array = (d.loot.get("foes", []) as Array).map(func(f): return str(f.get("name", f.get("id", ""))))
	var copy := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	copy.heir.inventory = []
	var gold0 := copy.heir.gold
	var potions0 := copy.heir.potions
	var roster0: Array = copy.roster.map(func(e): return int(e["id"]))
	var mats0: Dictionary = GameCraft.materials(copy).duplicate()
	var ess0: Dictionary = GameCraft.essences(copy).duplicate()
	GameLoot.search_dead(copy)
	var mats := {}
	for k in GameCraft.materials(copy):
		var n := int(GameCraft.materials(copy)[k]) - int(mats0.get(k, 0))
		if n > 0:
			mats[k] = n
	var ess := {}
	for k in GameCraft.essences(copy):
		var n2 := int(GameCraft.essences(copy)[k]) - int(ess0.get(k, 0))
		if n2 > 0:
			ess[k] = n2
	var eggs: Array = []
	for e in copy.roster:
		if int(e["id"]) not in roster0:
			eggs.append({"species": str(e["species"]), "name": str(e["name"]), "born": str(e.get("born", "egg"))})
	var sick: Array = []
	for e in copy.heir.diseases:
		if not GameDisease.has(d.heir, str(e["id"])):
			sick.append(str(e["id"]))
	return {"gold": maxi(0, copy.heir.gold - gold0), "potions": maxi(0, copy.heir.potions - potions0), "items": copy.heir.inventory.duplicate(),
		"mats": mats, "ess": ess, "eggs": eggs, "sick": sick, "rng_state": copy.rng.state, "foe_names": names}


static func _foes_text(names: Array) -> String:
	var shown: Array = []
	for n in names:
		if str(n) not in shown:
			shown.append(str(n))
	return GameMessages.text("life", "list_comma").join(shown)


static func _next_uid(d: GameDynasty) -> int:
	var top := 0
	for p in d.drops:
		top = maxi(top, int(p["uid"]))
	return top + 1


static func _tile_key(t: Vector2i) -> String:
	return "%d,%d" % [t.x, t.y]


## A free tile near the i-th spot (spots are taken in turn): the ones round it from a keyed start, the spot's own tile when none is free.
static func _spot(r: RandomNumberGenerator, spots: Array, i: int, taken: Dictionary, walkable: Callable) -> Vector2i:
	var base: Vector2 = spots[i % spots.size()] if not spots.is_empty() else Vector2.ZERO
	var home := Vector2i(floori(base.x), floori(base.y))
	var reach := int(setting("spread"))
	var ring: Array = []
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			ring.append(Vector2i(home.x + dx, home.y + dz))
	var start := r.randi() % ring.size()
	for k in ring.size():
		var t: Vector2i = ring[(start + k) % ring.size()]
		if taken.has(_tile_key(t)):
			continue
		if walkable.is_valid() and not bool(walkable.call(t)):
			continue
		return t
	return home


# ---------------------------------------------------------------- what lies there

## The drops still lying (their time has not run out).
static func lying(d: GameDynasty) -> Array:
	return d.drops.filter(func(p): return float(p["until"]) > d.world_seconds)


## A drop's rarity: an item's own, else its kind's.
static func rarity_of(p: Dictionary) -> String:
	if str(p["kind"]) == "item":
		var r := str(GameItems.item_def(str(p.get("item", ""))).get("rarity", "common"))
		return r if _rank(r) >= 0 else "common"
	return str(data()["kinds"][str(p["kind"])]["rarity"])


## The shape a drop is drawn as: its kind's, but an item of `gem_from` or better is a gem.
static func shape_of(p: Dictionary) -> String:
	if str(p["kind"]) == "item" and _rank(rarity_of(p)) >= _rank(str(setting("gem_from"))):
		return "gem"
	return str(data()["kinds"][str(p["kind"])]["shape"])


## Whether a drop throws a light beam: its rarity is `beam_from` or better.
static func beams(p: Dictionary) -> bool:
	return _rank(rarity_of(p)) >= _rank(str(setting("beam_from")))


## What a drop is called ("40 gold", "Iron Sword", "A young wolf").
static func label_of(p: Dictionary) -> String:
	match str(p["kind"]):
		"gold":
			return text("gold", {"n": GameText.num(int(p.get("gold", 0)))})
		"potion":
			return text("potion" if int(p.get("n", 1)) == 1 else "potions", {"n": int(p.get("n", 1))})
		"item":
			return GameItems.item_name(str(p["item"]))
		"material":
			return text("material")
		"essence":
			return text("essence")
		"egg":
			return text("egg", {"species": str(GameCombat.creature_def(str(p.get("species", ""))).get("name", p.get("species", ""))).to_lower()})
	return ""


static func _rank(rarity: String) -> int:
	var rows: Array = GameLoot.data()["rarities"]
	for i in rows.size():
		if str(rows[i]["id"]) == rarity:
			return i
	return -1


# ---------------------------------------------------------------- picking up

## One look at the ground: drops past their time are gone, and each one within `reach` of the heir (a point, in tiles) is taken if it
## can be. `warned` (the caller's, runtime) remembers the ones already said to be too heavy, so a heir standing by one is told once.
## Returns the news: [{text, kind, bad}] in the order it happened.
static func collect(d: GameDynasty, heir_point: Vector2, warned: Dictionary = {}) -> Array:
	var news: Array = []
	if d.drops.is_empty():
		return news
	var now := d.world_seconds
	if d.drops.any(func(p): return float(p["until"]) <= now):
		d.drops = d.drops.filter(func(p): return float(p["until"]) > now)
		news.append({"text": text("gone"), "kind": "gone", "bad": false})
	var reach := float(setting("reach"))
	for p in d.drops.duplicate():
		var uid := int(p["uid"])
		if Vector2(float(p["x"]), float(p["z"])).distance_to(heir_point) > reach:
			warned.erase(uid)
			continue
		var got := _take(d, p)
		if bool(got["took"]):
			d.drops.erase(p)
			warned.erase(uid)
			news.append({"text": str(got["text"]), "kind": str(p["kind"]), "bad": false})
			news.append_array(_sickness(d, p))
		elif not warned.has(uid):
			warned[uid] = true
			news.append({"text": str(got["text"]), "kind": str(p["kind"]), "bad": true})
	return news


## The sickness the search of that fight's dead cost, paid with the first thing taken from them (once for the fight).
static func _sickness(d: GameDynasty, p: Dictionary) -> Array:
	var out: Array = []
	var sick: Array = p.get("sick", [])
	if sick.is_empty():
		return out
	for q in d.drops:
		if int(q["gid"]) == int(p["gid"]):
			q["sick"] = []
	for id in sick:
		if GameDisease.infect(d.heir, str(id), "corpse"):
			var line := text("caught", {"h": d.heir.name, "disease": GameDisease.disease_name(str(id))})
			d._say(line)
			out.append({"text": line, "kind": "sick", "bad": true})
	return out


## Takes one drop into the heir's hands if it can be: {took, text}. A thing too heavy for the pack stays (and says so); young with no
## room in the house stay.
static func _take(d: GameDynasty, p: Dictionary) -> Dictionary:
	var h := d.heir
	var line := ""
	match str(p["kind"]):
		"gold":
			h.gold += int(p["gold"])
			line = text("took_gold", {"h": h.name, "gold": GameText.num(int(p["gold"]))})
		"potion":
			h.potions += int(p["n"])
			line = text("took_potion", {"h": h.name, "what": label_of(p).to_lower()})
		"item":
			var id := str(p["item"])
			var nm := GameItems.item_name(id)
			if GameItems.stack_max(id) > 0 and GameItems.count(h, id) >= GameItems.stack_max(id):
				var g := GameItems.sell_price(d, id)
				h.gold += g
				line = text("took_sold", {"h": h.name, "name": nm, "gold": GameText.num(g)})
			elif not GameCarry.can_carry(h, id):
				return {"took": false, "text": text("heavy", {"name": nm, "weight": GameCarry._n(GameItems.weight_of(id)), "room": GameCarry._n(maxf(0.0, GameCarry.room(h)))})}
			else:
				h.inventory.append(id)
				var rare := _rank(rarity_of(p)) >= _rank("rare")
				line = text("took_item_rare" if rare else "took_item", {"h": h.name, "name": nm, "rarity": str((GameLoot.data()["_rarity"].get(rarity_of(p), {}) as Dictionary).get("name", "")).to_lower()})
		"material", "essence":
			var parts: Array = []
			var mats: Dictionary = p.get("mats", {}) if str(p["kind"]) == "material" else {}
			var ess: Dictionary = p.get("ess", {}) if str(p["kind"]) == "essence" else {}
			for k in mats:
				GameCraft.add_material(d, str(k), int(mats[k]))
				parts.append(GameMessages.text("life", "stock_units_got", {"n": int(mats[k]), "name": GameMaterials.name_of(str(k)).to_lower()}))
			for k in ess:
				GameCraft.add_essence(d, str(k), int(ess[k]))
				parts.append(GameMessages.text("life", "essence_of_got", {"n": int(ess[k]), "affix": GameCraft._affix_label(str(k))}))
			line = text("took_material", {"h": h.name, "list": GameMessages.text("life", "list_comma").join(parts)})
		"egg":
			var young := GameBirth.young_name(str(p["species"]))
			var e := GameRoster.add(d, str(p["species"]), str(p["name"]))
			if e.is_empty():
				return {"took": false, "text": text("egg_full", {"young": young})}
			d.set_flag(str(GameFinding.setting("found_flag")))
			line = text("took_egg_hatch" if str(e.get("born", "egg")) == "young" else "took_egg", {"h": h.name, "young": young, "name": str(e["name"])})
	d._say(line)
	return {"took": true, "text": line}


# ---------------------------------------------------------------- saving

## A saved list made safe: wrong shapes, unknown kinds and numbers that are not numbers are dropped; what is kept is rebuilt with
## only the fields it uses.
static func load_list(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var seen := {}
	for r in raw:
		if typeof(r) != TYPE_DICTIONARY or str(r.get("kind", "")) not in KINDS:
			continue
		var ok := true
		for k in ["uid", "gid", "x", "z", "until"]:
			if typeof(r.get(k)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(r[k])):
				ok = false
		if not ok or seen.has(int(r["uid"])) or not GameWorldGen.in_bounds(floori(float(r["x"])), floori(float(r["z"]))):
			continue
		var p := {"kind": str(r["kind"]), "uid": int(r["uid"]), "gid": int(r["gid"]), "x": float(r["x"]), "z": float(r["z"]), "until": float(r["until"]), "sick": []}
		if typeof(r.get("sick")) == TYPE_ARRAY:
			for s in r["sick"]:
				if not GameDisease.def(str(s)).is_empty():
					p["sick"].append(str(s))
		var keep := true
		match p["kind"]:
			"gold":
				p["gold"] = maxi(0, int(r.get("gold", 0)))
			"potion":
				p["n"] = maxi(1, int(r.get("n", 1)))
			"item":
				var id := str(r.get("item", ""))
				keep = not GameItems.item_def(id).is_empty()
				p["item"] = id
			"material", "essence":
				var key := "mats" if p["kind"] == "material" else "ess"
				var tab := {}
				if typeof(r.get(key)) == TYPE_DICTIONARY:
					for k in r[key]:
						if typeof(r[key][k]) in [TYPE_INT, TYPE_FLOAT] and int(r[key][k]) > 0:
							tab[str(k)] = int(r[key][k])
				keep = not tab.is_empty()
				p[key] = tab
			"egg":
				keep = GameBirth.born(str(r.get("species", ""))) != "none"
				p["species"] = str(r.get("species", ""))
				p["name"] = str(r.get("name", ""))
				p["born"] = str(r.get("born", "egg"))
		if not keep:
			continue
		seen[p["uid"]] = true
		out.append(p)
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "kinds", "text"]:
		if not dat.has(k):
			return ["drops.json: %s is missing" % k]
	var s: Dictionary = dat["settings"]
	for k in ["reach", "ttl_seconds", "fade_seconds", "spread", "max_drops", "gem_from", "beam_from", "beam_tiles", "bob_tiles", "bob_hz", "label_min_cell"]:
		if not s.has(k):
			bad.append("drops.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["reach"]) <= 0.0 or float(s["reach"]) > 3.0:
		bad.append("drops.json: reach must be above 0 and at most 3 tiles")
	if float(s["fade_seconds"]) < 0.0 or float(s["ttl_seconds"]) <= float(s["fade_seconds"]):
		bad.append("drops.json: ttl_seconds must be longer than fade_seconds, which is not negative")
	if int(s["spread"]) < 0 or int(s["spread"]) > 3 or int(s["max_drops"]) < 1:
		bad.append("drops.json: spread is 0 to 3 and max_drops at least 1")
	for k in ["gem_from", "beam_from"]:
		if _rank(str(s[k])) < 0:
			bad.append("drops.json: %s is not a rarity of the loot data" % k)
	for k in KINDS:
		var row: Variant = dat["kinds"].get(k)
		if typeof(row) != TYPE_DICTIONARY:
			bad.append("drops.json: kinds.%s is missing" % k)
			continue
		if _rank(str(row.get("rarity", ""))) < 0:
			bad.append("drops.json: kinds.%s has a rarity the loot data does not know" % k)
		if str(row.get("shape", "")) not in SHAPES:
			bad.append("drops.json: kinds.%s has an unknown shape" % k)
	for k in ["scattered", "took_gold", "took_item", "took_item_rare", "took_potion", "took_material", "took_egg", "took_egg_hatch", "took_sold", "heavy", "egg_full", "caught", "gone", "ground_note", "gold", "potion", "potions", "material", "essence", "egg"]:
		if not dat["text"].has(k):
			bad.append("drops.json: text.%s is missing" % k)
	return bad
