## The dungeons' loot generator (data/items/dungeon_loot.json). `roll(d, dungeon, container, tier)` says what a container holds
## (gold, made items, materials, and a named unique), and `roll_drop` what a creature killed in a dungeon leaves. Both are pure
## functions of the dynasty's seed, the dungeon, the container (or creature) key and the cycle (how many refill periods of the
## world's calendar have passed), never the dynasty's own dice, so opening a chest changes nothing a life rolls and a chest holds
## the same in a replay. Items are built from GameLoot's own parts, so they are ordinary item ids (`gen:...` or an items.json id)
## and everything that knows items (carrying, wearing, `GameItems.sell_price`) works. It grows with the world: the generation opens
## material tiers (`GameLoot.tier_ceiling`), adds grades (`GameLoot.grade_of`) and scales the gold. `give` puts a roll into the
## heir's pack, purse and the family's stores. The screens ask for it (the sandbox), never the rules of a life, so the autopilot
## and the golden digests do not move.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_loot.gd
class_name GameDungeonLoot
extends RefCounted

const PATH := "res://data/items/dungeon_loot.json"
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## Whether an item is one of the named uniques some dungeon holds (so it is obtained by finding it there).
static func is_unique_found_somewhere(item: String) -> bool:
	for p in data()["dungeons"]:
		for u in data()["dungeons"][p].get("uniques", []):
			if str(u["item"]) == item:
				return true
	return false


## The refill period count the world's calendar is at: a container gives new things after each `refill_years`.
static func cycle_of(d: GameDynasty) -> int:
	return int(floor(d.world.year / maxf(1.0, float(GameDungeons.setting("refill_years")))))


## The depth of a container's room: doors from the entrance. A container id is "<room>#<n>".
static func depth_of(dungeon: String, container: String) -> int:
	var space := "world/" + dungeon
	var room := container.split("#")[0]
	var ent := GameSpaces.entrance_room(space)
	if room == ent or ent == "":
		return 0
	return GameSpaces.route_rooms(space, ent, room).size()


static func _rng(d: GameDynasty, tags: Array) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "dungeon_loot"] + tags)
	return r


static func _range(r: RandomNumberGenerator, a: Array) -> int:
	return r.randi_range(int(a[0]), int(a[1]))


static func _rarity_index(id: String) -> int:
	var rows: Array = GameLoot.data()["rarities"]
	for i in rows.size():
		if str(rows[i]["id"]) == id:
			return i
	return 0


## The table of a dungeon for a tier of container: {tier, dungeon, kind} merged as a plain dictionary.
static func _table(dungeon: String, tier: String) -> Dictionary:
	return {"tier": data()["tiers"].get(tier, {}), "dungeon": data()["dungeons"].get(dungeon, {})}


## What a container holds: {gold, items: [ids], materials: {id: n}, uniques: [ids]}. `kind` shifts the slots and gold;
## `depth` (-1: from the container id) raises the chance of the rare. `cycle` -1 is the world's now.
static func roll(d: GameDynasty, dungeon: String, container: String, tier: String, kind: String = "chest", depth: int = -1, cycle: int = -1) -> Dictionary:
	var out := {"gold": 0, "items": [], "materials": {}, "uniques": []}
	var t: Dictionary = data()["tiers"].get(tier, {})
	var dg: Dictionary = data()["dungeons"].get(dungeon, {})
	if t.is_empty() or dg.is_empty():
		return out
	if depth < 0:
		depth = depth_of(dungeon, container)
	if cycle < 0:
		cycle = cycle_of(d)
	var kd: Dictionary = data()["kinds"].get(kind, {})
	var r := _rng(d, [dungeon, container, tier, cycle])
	var boost := float(t["rarity_boost"]) * (1.0 + float(setting("depth_boost")) * float(depth))
	if d.heir != null:
		boost *= GameSubclass.perk(d.heir, "rarity_mult")
	var gold := lerpf(float(t["gold"][0]), float(t["gold"][1]), r.randf())
	gold *= pow(GameData.enemy_scale(d.gen), float(setting("gold_gen_power"))) * float(dg.get("gold_mult", 1.0)) * float(kd.get("gold_mult", 1.0))
	out["gold"] = maxi(1, int(round(gold)))
	var n := _range(r, t["rolls"])
	for i in n:
		var made := r.randf() < float(t["item_chance"])
		var item_seed := r.randi()
		var mat_roll := r.randf()
		var mat_seed := r.randi()
		if made:
			var ir := RandomNumberGenerator.new()
			ir.seed = item_seed
			var id := _roll_item(ir, d.gen, boost, str(t["min_rarity"]), dg, kd)
			if id != "":
				out["items"].append(id)
		elif mat_roll < float(t["material_chance"]):
			var mr := RandomNumberGenerator.new()
			mr.seed = mat_seed
			var m := _roll_material(mr, d.gen, dg)
			if not m.is_empty():
				out["materials"][m["id"]] = int(out["materials"].get(m["id"], 0)) + int(m["n"])
	var room_role := _role_of(dungeon, container)
	for u in dg.get("uniques", []):
		if str(u["role"]) == room_role and not GameDungeons.has_unique(d, str(u["item"])) and r.randf() < float(u["chance"]):
			out["uniques"].append(str(u["item"]))
	return out


static func _role_of(dungeon: String, container: String) -> String:
	var room := container.split("#")[0]
	for rm in GameSpaces.rooms("world/" + dungeon):
		if str(rm["id"]) == room:
			return str(rm.get("role", ""))
	return ""


## One made item for a dungeon, built from GameLoot's forms, materials, affixes and rarities.
static func _roll_item(r: RandomNumberGenerator, gen: int, boost: float, min_rarity: String, dg: Dictionary, kd: Dictionary) -> String:
	var dat := GameLoot.data()
	var rarity_id := GameLoot.pick_rarity(r, boost)
	if _rarity_index(rarity_id) < _rarity_index(min_rarity):
		rarity_id = min_rarity
	var rarity: Dictionary = dat["_rarity"][rarity_id]
	var slot_rows: Array = []
	var weights: Dictionary = dg.get("slot_weights", dat["settings"]["slot_weights"])
	var mult: Dictionary = kd.get("slot_mult", {})
	for s in weights:
		var w := float(weights[s]) * float(mult.get(s, 1.0))
		if w > 0.0:
			slot_rows.append({"id": s, "weight": w})
	if slot_rows.is_empty():
		return ""
	slot_rows.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var slot := str(GameLoot.pick_weighted(r, slot_rows)["id"])
	var cap := mini(GameLoot.top_tier(), GameLoot.tier_ceiling(gen) + int(rarity["overreach"]) + int(dg.get("tier_shift", 0)))
	var form_bias: Dictionary = dg.get("form_bias", {})
	var forms: Array = []
	for f in dat["forms"]:
		if str(f["slot"]) == slot:
			var has := false
			for t in range(1, cap + 1):
				if not GameLoot.materials_at(f, t).is_empty():
					has = true
			if has:
				forms.append({"f": f, "id": str(f["id"]), "weight": float(form_bias.get(str(f["id"]), 1.0))})
	if forms.is_empty():
		return ""
	var form: Dictionary = GameLoot.pick_weighted(r, forms)["f"]
	var tier_rows: Array = []
	for t in range(1, cap + 1):
		if not GameLoot.materials_at(form, t).is_empty():
			tier_rows.append({"id": t, "weight": pow(float(rarity["tier_bias"]), t)})
	var tier := int(GameLoot.pick_weighted(r, tier_rows)["id"])
	var tag_bias: Dictionary = dg.get("material_tag_bias", {})
	var mat_rows: Array = []
	for m in GameLoot.materials_at(form, tier):
		var w := 1.0
		for tag in GameMaterials.tags_of(str(m)):
			w *= float(tag_bias.get(str(tag), 1.0))
		mat_rows.append({"id": str(m), "weight": w})
	mat_rows.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var material := str(GameLoot.pick_weighted(r, mat_rows)["id"])
	var affixes := GameLoot.pick_affixes(r, slot, tier, int(rarity["affixes"]))
	var mythic := ""
	if rarity.get("mythic", false):
		var pool: Array = dat["mythics"].filter(func(m): return slot in m["slots"])
		mythic = str(pool[r.randi() % pool.size()]["id"])
	var q := r.randi_range(int(rarity["quality_floor"]), GameLoot.QUALITY_MAX)
	return GameLoot.make_id(rarity_id, slot, str(form["id"]), material, affixes, mythic, GameLoot.grade_of(gen), q)


static func _roll_material(r: RandomNumberGenerator, gen: int, dg: Dictionary) -> Dictionary:
	var rows: Array = []
	var cap := GameLoot.tier_ceiling(gen) + int(dg.get("tier_shift", 0))
	for m in dg.get("materials", []):
		if GameMaterials.has(str(m["id"])) and GameMaterials.tier_of(str(m["id"])) <= cap:
			rows.append({"id": str(m["id"]), "weight": float(m["weight"]), "n": m["n"]})
	if rows.is_empty():
		return {}
	var pick: Dictionary = GameLoot.pick_weighted(r, rows)
	return {"id": str(pick["id"]), "n": r.randi_range(int(pick["n"][0]), int(pick["n"][1]))}


## What a creature killed in a dungeon leaves (`key` is the slot's key): a roll of the dungeon's `drops` tier for that creature, or
## {} when it leaves nothing. The boss of a lair always leaves its dungeon's uniques of the `boss_lair` role (not yet found).
static func roll_drop(d: GameDynasty, dungeon: String, key: String, creature: String, boss: bool = false) -> Dictionary:
	var dg: Dictionary = data()["dungeons"].get(dungeon, {})
	if dg.is_empty():
		return {}
	var drops: Dictionary = dg.get("drops", {})
	var spec: Dictionary = drops.get(creature, drops.get("default", {}))
	var r := _rng(d, [dungeon, "drop", key, creature, cycle_of(d)])
	var chance := float(spec.get("chance", 0.0)) * (GameSubclass.perk(d.heir, "drop_mult") if d.heir != null else 1.0)
	var out := {}
	if boss or r.randf() < chance:
		var tier := "hoard" if boss else str(spec.get("tier", "plain"))
		out = roll(d, dungeon, key + "#drop", tier, "chest", 2 if boss else 1)
		if boss:
			for u in dg.get("uniques", []):
				if str(u["role"]) == "boss_lair" and not GameDungeons.has_unique(d, str(u["item"])) and str(u["item"]) not in out["uniques"]:
					out["uniques"].append(str(u["item"]))
	return out


## Puts a roll into the dynasty: gold to the heir, materials to the family's stores, items into the pack (one too heavy to carry is
## sold on the spot, as the generator's finds are). Returns the lines to show. Marks the uniques as found.
static func give(d: GameDynasty, got: Dictionary) -> Array:
	var lines: Array = []
	if got.is_empty() or d.heir == null:
		return lines
	var h := d.heir.name
	if int(got.get("gold", 0)) > 0:
		d.heir.gold += int(got["gold"])
		lines.append(GameDungeons.text("found_gold", {"h": h, "n": GameText.num(int(got["gold"]))}))
	for m in got.get("materials", {}):
		GameCraft.add_material(d, str(m), int(got["materials"][m]))
		lines.append(GameDungeons.text("found_materials", {"h": h, "n": int(got["materials"][m]), "material": GameMaterials.name_of(str(m)).to_lower()}))
	for id in got.get("items", []):
		lines.append(_give_item(d, str(id)))
	for id in got.get("uniques", []):
		if GameDungeons.has_unique(d, str(id)):
			continue
		GameDungeons.mark_unique(d, str(id))
		lines.append(GameDungeons.text("found_unique", {"h": h, "name": GameItems.item_name(str(id))}))
		if GameCarry.can_carry(d.heir, str(id)):
			d.heir.inventory.append(str(id))
		else:
			lines.append(GameCarry.sell_find(d, str(id), GameItems.item_name(str(id))))
	return lines


static func _give_item(d: GameDynasty, id: String) -> String:
	var def := GameItems.item_def(id)
	if def.is_empty():
		return ""
	if not GameCarry.can_carry(d.heir, id):
		return GameCarry.sell_find(d, id, "a " + str(def["name"]))
	d.heir.inventory.append(id)
	var rarity := str(def.get("rarity", ""))
	var key := "find"
	if rarity == "mythic":
		key = "find_mythic"
	elif rarity in ["epic", "legendary"]:
		key = "find_rare"
	var rn := str(GameLoot.data()["_rarity"].get(rarity, {}).get("name", "")).to_lower()
	return GameLoot.text(key, {"h": d.heir.name, "name": str(def["name"]), "rarity": rn, "a": "a"})


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "tiers", "kinds", "dungeons"]:
		if not dat.has(k):
			bad.append("dungeon_loot.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var rar: Array = GameLoot.data()["rarities"].map(func(x): return str(x["id"]))
	for t in dat["tiers"]:
		var s: Dictionary = dat["tiers"][t]
		for k in ["rolls", "gold"]:
			if typeof(s.get(k)) != TYPE_ARRAY or (s[k] as Array).size() != 2 or float(s[k][0]) > float(s[k][1]) or float(s[k][0]) < 0.0:
				bad.append("dungeon_loot.json: tier '%s' needs %s as [low, high]" % [t, k])
		if int(s.get("rolls", [0, 0])[1]) < 1:
			bad.append("dungeon_loot.json: tier '%s' gives no rolls" % t)
		if float(s.get("item_chance", -1)) < 0.0 or float(s.get("item_chance", 2)) > 1.0 or float(s.get("material_chance", -1)) < 0.0 or float(s.get("material_chance", 2)) > 1.0:
			bad.append("dungeon_loot.json: tier '%s' needs item_chance and material_chance from 0 to 1" % t)
		if float(s.get("rarity_boost", 0)) <= 0.0:
			bad.append("dungeon_loot.json: tier '%s' needs a rarity_boost above 0" % t)
		if str(s.get("min_rarity", "")) not in rar:
			bad.append("dungeon_loot.json: tier '%s' has an unknown min_rarity" % t)
	for k in dat["kinds"]:
		if not GameDungeons.data()["kinds"].has(k):
			bad.append("dungeon_loot.json: '%s' is not a container kind of dungeons.json" % k)
	for k in GameDungeons.data()["kinds"]:
		if not dat["kinds"].has(k):
			bad.append("dungeon_loot.json: the container kind '%s' has no entry" % k)
	var forms: Array = GameLoot.data()["forms"].map(func(f): return str(f["id"]))
	for id in dat["dungeons"]:
		var dg: Dictionary = dat["dungeons"][id]
		if GameSpaces.kind("world/" + id) != "interior":
			bad.append("dungeon_loot.json: '%s' is not a dungeon" % id)
			continue
		for s in dg.get("slot_weights", {}):
			if s not in GameItems.SLOTS or float(dg["slot_weights"][s]) < 0.0:
				bad.append("dungeon_loot.json: %s has a bad slot weight '%s'" % [id, s])
		for f in dg.get("form_bias", {}):
			if f not in forms:
				bad.append("dungeon_loot.json: %s biases the unknown form '%s'" % [id, f])
		var tags := {}
		for m in GameMaterials.ids():
			for tg in GameMaterials.tags_of(str(m)):
				tags[tg] = true
		for tg in dg.get("material_tag_bias", {}):
			if not tags.has(tg):
				bad.append("dungeon_loot.json: %s biases the unknown material tag '%s'" % [id, tg])
		if dg.get("materials", []).is_empty():
			bad.append("dungeon_loot.json: %s lists no materials" % id)
		for m in dg.get("materials", []):
			if not GameMaterials.has(str(m["id"])) or float(m["weight"]) <= 0.0 or int(m["n"][0]) < 1 or int(m["n"][1]) < int(m["n"][0]):
				bad.append("dungeon_loot.json: %s has a bad material entry %s" % [id, str(m)])
		var roles := {}
		for rm in GameSpaces.rooms("world/" + id):
			roles[str(rm.get("role", ""))] = true
		for u in dg.get("uniques", []):
			var def: Dictionary = GameData.items.get(str(u["item"]), {})
			if def.is_empty() or not bool(def.get("unique", false)):
				bad.append("dungeon_loot.json: %s names '%s', which is not a unique item of items.json" % [id, u["item"]])
			if not roles.has(str(u["role"])):
				bad.append("dungeon_loot.json: %s puts '%s' in a '%s' room, which it has none of" % [id, u["item"], u["role"]])
			if float(u["chance"]) <= 0.0 or float(u["chance"]) > 1.0:
				bad.append("dungeon_loot.json: %s has a unique chance outside (0, 1]" % id)
		var drops: Dictionary = dg.get("drops", {})
		if not drops.has("default"):
			bad.append("dungeon_loot.json: %s has no default drop" % id)
		for c in drops:
			var spec: Dictionary = drops[c]
			if c != "default" and GameBehaviour._def(str(c)).is_empty():
				bad.append("dungeon_loot.json: %s drops from '%s', which is no creature" % [id, c])
			if not dat["tiers"].has(str(spec.get("tier", ""))) or float(spec.get("chance", -1)) < 0.0 or float(spec.get("chance", 2)) > 1.0:
				bad.append("dungeon_loot.json: %s has a bad drop for '%s'" % [id, c])
		for p in GameDungeons.dungeon_ids():
			if not dat["dungeons"].has(p):
				bad.append("dungeon_loot.json: the dungeon '%s' has no loot table" % p)
	return bad
