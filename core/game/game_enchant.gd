## Enchanting as a shop service (data/shops/enchant.json; specified in docs/SHOP_SERVICES.md). A shop whose `services` hold a row of kind
## `enchant` binds one more affix into a piece of made gear the heir carries or wears: the piece's id is rebuilt with the affix and the
## next rarity (a made piece has exactly as many affixes as its rarity says), an essence of the affix leaves the family's stores
## (`GameCraft`) and gold leaves the purse. Pure rules: `plan` says what a choice would do and why not and spends nothing, `apply` does
## it. The only dice are a risky shop's failure roll, keyed on the seed, the piece, the affix and the family's enchanting count, never
## the dynasty's. Nothing is saved but the stores' `enchanted` count and the new id in the pack or the worn slot; the autopilot never asks.
class_name GameEnchant
extends RefCounted

const PATH := "res://data/shops/enchant.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## The enchanting row of a shop's `services` ({} for a shop that does not enchant).
static func row(shop_id: String) -> Dictionary:
	for sv in GameShops.def(shop_id).get("services", []):
		if str(sv.get("kind", "")) == "enchant":
			return sv
	return {}


## The rarity a piece takes with `n` affixes (craft.json `rarity_by_essences`: the same ladder crafting uses).
static func rarity_for(n: int) -> String:
	return str(GameCraft.setting("rarity_by_essences").get(str(n), ""))


## The made pieces the heir has: worn ones first, then the pack ([{id, worn: slot or ""}]).
static func pieces(d: GameDynasty) -> Array:
	var out: Array = []
	for slot in d.heir.equipment:
		var id := str(d.heir.equipment[slot])
		if id != "" and GameLoot.is_generated(id):
			out.append({"id": id, "worn": str(slot)})
	for id in d.heir.inventory:
		if GameLoot.is_generated(str(id)):
			out.append({"id": str(id), "worn": ""})
	return out


## The highest tier of piece this shop here can work: the town's `shop_tier` plus the shop's `tier_bonus`, held to the row's `tier_cap`.
static func tier_limit(d: GameDynasty, shop_id: String) -> int:
	return mini(int(row(shop_id).get("tier_cap", 99)), int(d.world.here().get("shop_tier", 1)) + int(GameShops.def(shop_id).get("tier_bonus", 0)))


## "" when the shop can enchant this piece at all, else why not (as a line).
static func why_not_piece(d: GameDynasty, shop_id: String, id: String) -> String:
	if row(shop_id).is_empty():
		return text("no_service", {"shop": GameShops.name_of(shop_id)})
	var parts := GameLoot.parse(id)
	var nm := GameItems.item_name(id)
	if parts.is_empty():
		return text("not_gear", {"item": nm})
	if str(parts["mythic"]) != "":
		return text("mythic")
	if (parts["affixes"] as Array).size() >= 3 or rarity_for((parts["affixes"] as Array).size() + 1) == "":
		return text("full", {"item": nm})
	if int(parts["tier"]) > tier_limit(d, shop_id):
		return text("too_fine", {"shop": GameShops.name_of(shop_id), "tier": int(parts["tier"]), "cap": tier_limit(d, shop_id)})
	return ""


## The affixes that could be bound into a piece: [{id, name, have (essences held), tier}], those its slot and material tier allow and it
## does not already hold, in the data's order.
static func options(d: GameDynasty, id: String) -> Array:
	var parts := GameLoot.parse(id)
	var out: Array = []
	if parts.is_empty():
		return out
	for a in GameLoot.data()["affixes"]:
		var aid := str(a["id"])
		if str(parts["slot"]) in a["slots"] and int(a["min_tier"]) <= int(parts["tier"]) and aid not in parts["affixes"]:
			out.append({"id": aid, "name": str(a["name"]), "have": GameCraft.essence_have(d, aid), "tier": int(a["min_tier"])})
	return out


## The fee for binding one more affix into a piece (gold; the shop's prices and the Enchanter's calling count).
static func price(d: GameDynasty, shop_id: String, id: String) -> int:
	var parts := GameLoot.parse(id)
	if parts.is_empty():
		return 0
	var tier := int(parts["tier"])
	var base := float(row(shop_id).get("base_fee", 0)) * float(tier * tier) * (1.0 + float(setting("affix_step")) * (parts["affixes"] as Array).size())
	return maxi(1, int(round(base * GameItems.price_mult(d) * GameSubclass.perk(d.heir, "forge_fee_mult"))))


## The chance a risky shop's binding fails (0 for a safe one and for tier 1).
static func fail_chance(shop_id: String, id: String) -> float:
	if str(row(shop_id).get("risk", "safe")) != "risky":
		return 0.0
	var parts := GameLoot.parse(id)
	return 0.0 if parts.is_empty() else clampf(float(setting("fail_per_tier")) * float(int(parts["tier"]) - 1), 0.0, 0.9)


## What binding `affix` into piece `id` would do, nothing spent: {ok, why, id, new_id, new_name, fee, fail, essence}.
static func plan(d: GameDynasty, shop_id: String, id: String, affix: String) -> Dictionary:
	var h := d.heir
	var nm := GameItems.item_name(id)
	var fail := func(why: String) -> Dictionary: return {"ok": false, "why": why, "id": id, "new_id": "", "new_name": "", "fee": 0, "fail": 0.0, "essence": GameCraft.essence_have(d, affix)}
	if not d.world.has_service(shop_id):
		return fail.call(GameShops.text("not_here", {"shop": GameShops.name_of(shop_id)}))
	if not GameShops.is_open(d, shop_id):
		return fail.call(GameShops.shut_line(d, shop_id))
	if d.battle != null:
		return fail.call(text("in_fight"))
	var carried := false
	for p in pieces(d):
		if str(p["id"]) == id:
			carried = true
			break
	if not carried:
		return fail.call(text("not_carried", {"name": h.name, "item": nm}))
	var why := why_not_piece(d, shop_id, id)
	if why != "":
		return fail.call(why)
	var label := GameCraft._affix_label(affix)
	if not GameLoot.data()["_affix"].has(affix):
		return fail.call(text("bad_affix", {"affix": affix, "item": nm}))
	var parts := GameLoot.parse(id)
	if affix in parts["affixes"]:
		return fail.call(text("has_affix", {"item": nm, "affix": label}))
	var fits := false
	for o in options(d, id):
		if str(o["id"]) == affix:
			fits = true
	if not fits:
		return fail.call(text("bad_affix", {"affix": label, "item": nm}))
	var n: int = (parts["affixes"] as Array).size() + 1
	var new_id := GameLoot.make_id(rarity_for(n), str(parts["slot"]), str(parts["form"]), str(parts["material"]), (parts["affixes"] as Array) + [affix], "", int(parts["grade"]), int(parts["quality"]))
	var item := GameLoot.build(new_id)
	if item.is_empty():
		return fail.call(text("bad_affix", {"affix": label, "item": nm}))
	var fee := price(d, shop_id, id)
	var out := {"ok": true, "why": "", "id": id, "new_id": new_id, "new_name": str(item["name"]), "fee": fee, "fail": fail_chance(shop_id, id), "essence": GameCraft.essence_have(d, affix)}
	if GameCraft.essence_have(d, affix) < 1:
		out["ok"] = false
		out["why"] = text("no_essence", {"name": h.name, "affix": label})
	elif h.gold < fee:
		out["ok"] = false
		out["why"] = text("no_gold", {"name": h.name, "price": GameText.num(fee)})
	elif not GameCarry.can_carry(h, new_id) and not _worn(d, id):
		out["ok"] = false
		out["why"] = text("no_room", {"item": str(item["name"])})
	return out


static func _worn(d: GameDynasty, id: String) -> bool:
	for slot in d.heir.equipment:
		if str(d.heir.equipment[slot]) == id:
			return true
	return false


## Binds the affix: spends the essence and the fee (a risky shop's failure keeps both and changes nothing else) and puts the new id in the
## place of the old one, worn or in the pack. Returns the line.
static func apply(d: GameDynasty, shop_id: String, id: String, affix: String) -> String:
	var p := plan(d, shop_id, id, affix)
	if not p["ok"]:
		return str(p["why"])
	var h := d.heir
	var label := GameCraft._affix_label(affix)
	GameCraft.add_essence(d, affix, -1)
	h.gold -= int(p["fee"])
	var counter := str(setting("counter"))
	var count := int(d.stores.get(counter, 0))
	d.stores[counter] = count + 1
	if float(p["fail"]) > 0.0:
		var r := RandomNumberGenerator.new()
		r.seed = hash([d.seed_value, id, affix, count])
		if r.randf() < float(p["fail"]):
			var line := text("failed", {"essence": label, "price": GameText.num(int(p["fee"])), "item": GameItems.item_name(id)})
			d._say(line)
			return line
	var old_name := GameItems.item_name(id)
	var done := false
	for slot in h.equipment:
		if str(h.equipment[slot]) == id:
			h.equipment[slot] = str(p["new_id"])
			done = true
			break
	if not done:
		var i := h.inventory.find(id)
		if i >= 0:
			h.inventory[i] = str(p["new_id"])
	var line := text("enchanted", {"name": h.name, "item": old_name, "affix": label, "new": str(p["new_name"]), "price": GameText.num(int(p["fee"]))})
	d._say(line)
	return line


## The price of buying an essence of an affix outright at a shop with an enchanting row.
static func essence_price(d: GameDynasty, shop_id: String, affix: String) -> int:
	var tier := int(GameLoot.data()["_affix"].get(affix, {}).get("min_tier", 1))
	return maxi(1, int(round(float(setting("essence_fee")) * float(tier) * GameItems.price_mult(d))))


static func buy_essence(d: GameDynasty, shop_id: String, affix: String) -> String:
	var h := d.heir
	if row(shop_id).is_empty() or not d.world.has_service(shop_id):
		return text("no_service", {"shop": GameShops.name_of(shop_id)})
	if not GameShops.is_open(d, shop_id):
		return GameShops.shut_line(d, shop_id)
	if not GameLoot.data()["_affix"].has(affix):
		return text("bad_affix", {"affix": affix, "item": ""})
	var cost := essence_price(d, shop_id, affix)
	if h.gold < cost:
		return text("no_gold", {"name": h.name, "price": GameText.num(cost)})
	h.gold -= cost
	GameCraft.add_essence(d, affix, 1)
	var line := text("bought_essence", {"name": h.name, "affix": GameCraft._affix_label(affix), "price": GameText.num(cost)})
	d._say(line)
	return line


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "text"]:
		if not dat.has(k):
			return ["enchant.json: %s is missing" % k]
	GameData.load_all()
	var s: Dictionary = dat["settings"]
	for k in ["affix_step", "fail_per_tier", "essence_fee", "counter"]:
		if not s.has(k):
			bad.append("enchant.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["affix_step"]) < 0.0 or float(s["fail_per_tier"]) < 0.0 or float(s["fail_per_tier"]) > 0.3 or float(s["essence_fee"]) <= 0.0:
		bad.append("enchant.json: affix_step and fail_per_tier are not negative (fail_per_tier at most 0.3) and essence_fee is positive")
	for k in ["enchanted", "failed", "bought_essence", "no_service", "not_gear", "mythic", "full", "too_fine", "bad_affix", "has_affix", "no_essence", "no_gold", "no_room", "not_carried", "in_fight"]:
		if not dat["text"].has(k):
			bad.append("enchant.json: text.%s is missing" % k)
	# the ladder crafting uses must take a piece from 0, 1 and 2 affixes up one, and the three-affix rarity must not be mythic
	for n in [1, 2, 3]:
		var r := rarity_for(n)
		if r == "" or not GameLoot.data()["_rarity"].has(r) or bool(GameLoot.data()["_rarity"][r].get("mythic", false)) or int(GameLoot.data()["_rarity"][r]["affixes"]) != n:
			bad.append("enchant.json: craft.json rarity_by_essences['%d'] is not a non-mythic rarity of %d affixes" % [n, n])
	var found := false
	for sh in GameShops.data()["shops"]:
		for sv in sh.get("services", []):
			if str(sv.get("kind", "")) == "enchant":
				found = true
				if float(sv.get("base_fee", 0)) <= 0.0 or str(sv.get("risk", "")) not in ["safe", "risky"] or int(sv.get("tier_cap", 0)) < 1:
					bad.append("shops.json: the enchant service of '%s' needs base_fee above 0, risk safe or risky and tier_cap of 1 or more" % sh["id"])
	if not found:
		bad.append("shops.json: no shop has an enchant service")
	return bad
