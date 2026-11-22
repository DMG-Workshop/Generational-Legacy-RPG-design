## The shelves of the shops (data/shops/shops.json `stock`), generated and never listed. A shelf is a pure function of the dynasty's
## seed, the generation, the town, the shop, the year and the season: the same shop in another town, or in another season, stocks
## differently, and the dynasty's own dice are never drawn (every pool has a generator of its own, keyed on those). A pool draws
## from the items list (`items`: by kinds, own tags or ids, and an item's `seasons`), from the loot generator (`loot`: made-up gear
## of a slot and forms, up to a rarity), from the materials list (`materials`: bundles of raw material) or from the farm market
## (`animals`). Pure: nothing saved.
class_name GameShopStock
extends RefCounted

const RARITY_ORDER := ["common", "fine", "rare", "epic", "legendary", "mythic"]


## What a shop has on its shelves for the dynasty here and now: [{key, kind: item | material | animal, id, n}]. `n` is the size of a
## bundle of material (1 for the rest). [] for a shop that is not in this town.
static func stock(d: GameDynasty, shop_id: String) -> Array:
	if d == null or d.world == null or not d.world.has_service(shop_id):
		return []
	return build(d.seed_value, d.gen, d.world.location, int(d.world.here().get("shop_tier", 1)), shop_id, int(floor(d.world.year)), str(d.world.season()["id"]))


## The shelf of `shop_id` in `place` (a town of shop tier `tier`) in a year and season, for a dynasty of that seed and generation.
static func build(seed_value: int, gen: int, place: String, tier: int, shop_id: String, year: int, season: String) -> Array:
	GameData.load_all()
	var def := GameShops.def(shop_id)
	var out: Array = []
	if def.is_empty():
		return out
	var base := hash([seed_value, place, shop_id, year, season])
	var seen := {}
	var cap := tier + int(def.get("tier_bonus", 0))
	var pools: Array = def["stock"]
	for i in pools.size():
		var pool: Dictionary = pools[i]
		var r := RandomNumberGenerator.new()
		r.seed = hash([base, i])
		var rows: Array = []
		match str(pool["type"]):
			"items":
				rows = _items(pool, r, cap, season)
			"loot":
				rows = _loot(pool, r, gen, cap)
			"materials":
				rows = _materials(pool, r, cap)
			"animals":
				rows = _animals(pool)
		for e in rows:
			if not seen.has(e["key"]):
				seen[e["key"]] = true
				out.append(e)
	return out


static func _count(pool: Dictionary, r: RandomNumberGenerator, available: int) -> int:
	var c: Array = pool["count"]
	return mini(available, r.randi_range(int(c[0]), int(c[1])))


static func _draw(list: Array, n: int, r: RandomNumberGenerator) -> Array:
	var pick := list.duplicate()
	for i in range(pick.size() - 1, 0, -1):   # a shuffle on the pool's own dice
		var j := r.randi_range(0, i)
		var t = pick[i]
		pick[i] = pick[j]
		pick[j] = t
	return pick.slice(0, n)


## Whether an item of the list is for sale on this pool: not gear, not unique, in season, of a tier the shop stocks, and named by the pool.
static func item_fits(pool: Dictionary, id: String, cap: int, season: String) -> bool:
	var it: Dictionary = GameData.items.get(id, {})
	var named: bool = id in pool["ids"]
	if it.is_empty() or it.get("unique", false) or (str(it.get("slot", "")) != "" and not named):
		return false
	if not named:
		var kinds: Array = pool["kinds"]
		var tags: Array = pool["tags"]
		if kinds.is_empty() and tags.is_empty():
			return false
		if not kinds.is_empty() and str(it.get("kind", "")) not in kinds:
			return false
		if not tags.is_empty() and not tags.any(func(t): return t in it.get("tags", [])):
			return false
		if str(it.get("slot", "")) != "":
			return false
	if int(it.get("tier", 1)) > mini(int(pool.get("tier_max", 9)), cap) and not named:
		return false
	var seasons: Array = it.get("seasons", [])
	return seasons.is_empty() or season in seasons


static func _items(pool: Dictionary, r: RandomNumberGenerator, cap: int, season: String) -> Array:
	var ids: Array = GameData.items.keys()
	ids.sort()
	var fits: Array = ids.filter(func(id): return item_fits(pool, str(id), cap, season))
	var rows: Array = _draw(fits, _count(pool, r, fits.size()), r)
	rows.sort_custom(func(a, b): return float(GameData.items[a]["price"]) < float(GameData.items[b]["price"]))
	return rows.map(func(id): return {"key": str(id), "kind": "item", "id": str(id), "n": 1})


static func _animals(pool: Dictionary) -> Array:
	var out: Array = []
	for sp in pool["species"]:
		if GameFarm.price(str(sp)) > 0:
			out.append({"key": "animal:%s" % sp, "kind": "animal", "id": str(sp), "n": 1})
	return out


static func _materials(pool: Dictionary, r: RandomNumberGenerator, cap: int) -> Array:
	var ids: Array = []
	for m in GameMaterials.ids():
		var listed: bool = str(m) in pool["ids"] or pool["tags"].any(func(t): return t in GameMaterials.tags_of(str(m)))
		if listed and GameMaterials.tier_of(str(m)) <= cap + 1:
			ids.append(m)
	return _draw(ids, _count(pool, r, ids.size()), r).map(func(m): return {"key": "mat:%s" % m, "kind": "material", "id": str(m), "n": int(pool["bundle"])})


## Made-up gear of the pool's slot and forms: the rarity between its floor and ceiling, the material from what the generation and the
## town's tier allow (a tier above the town's), affixes by the rarity, as GameLoot.roll_item does; unique mythics are never sold.
static func _loot(pool: Dictionary, r: RandomNumberGenerator, gen: int, cap: int) -> Array:
	var dat := GameLoot.data()
	var rarities: Array = []
	var lo := RARITY_ORDER.find(str(pool.get("rarity_min", "common")))
	var hi := RARITY_ORDER.find(str(pool.get("rarity_max", "fine")))
	for x in dat["rarities"]:
		var k := RARITY_ORDER.find(str(x["id"]))
		if k >= lo and k <= hi and not x.get("mythic", false):
			rarities.append(x)
	var out: Array = []
	if rarities.is_empty():
		return out
	var wanted := _count(pool, r, 99)
	var tries := 0
	while out.size() < wanted and tries < int(GameShops.setting("max_loot_tries")) * maxi(1, wanted):
		tries += 1
		var rarity: Dictionary = GameLoot._pick_weighted(r, rarities)
		var slot := str(pool["slot"])
		var forms: Array = dat["forms"].filter(func(f): return str(f["slot"]) == slot and str(f["id"]) in pool["forms"])
		var limit := clampi(mini(GameLoot.tier_ceiling(gen), cap + 1), 1, GameLoot.top_tier())
		forms = forms.filter(func(f): return not GameLoot._materials_for(f, limit).is_empty())
		if forms.is_empty():
			break
		var form: Dictionary = forms[r.randi() % forms.size()]
		var tier_rows: Array = []
		for t in range(1, limit + 1):
			if not GameLoot._materials_at(form, t).is_empty():
				tier_rows.append({"id": t, "weight": pow(float(rarity["tier_bias"]), t)})
		var t := int(GameLoot._pick_weighted(r, tier_rows)["id"])
		var mats: Array = GameLoot._materials_at(form, t)
		var material := str(mats[r.randi() % mats.size()])
		var affixes := GameLoot._pick_affixes(r, slot, t, int(rarity["affixes"]))
		var q := r.randi_range(int(rarity["quality_floor"]), GameLoot.QUALITY_MAX)
		var id := GameLoot.make_id(str(rarity["id"]), slot, str(form["id"]), material, affixes, "", GameLoot.grade_of(gen), q)
		if GameLoot.build(id).is_empty() or out.any(func(e): return e["key"] == id):
			continue
		out.append({"key": id, "kind": "item", "id": id, "n": 1})
	out.sort_custom(func(a, b): return float(GameLoot.build(a["id"]).get("price", 0)) < float(GameLoot.build(b["id"]).get("price", 0)))
	return out
