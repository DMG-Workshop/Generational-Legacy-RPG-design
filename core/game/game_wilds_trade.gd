## The wilds' merchant (a landmark kind with `trade` in data/world/wilds.json, whose `merchant` block says how it deals): a small shop the panel
## (ui/play/merchant_panel.gd) shows over the map, with **wares to buy**, **things the heir can sell** (gear of the kinds it wants and materials from the
## stores) and **barter** (materials for an item or for gold). Specified in docs/WILDS_ENCOUNTERS.md. Wares are generated, never listed: the landmark's
## `stock` pool for its area (and, if the block says `find`, one made piece from GameWildsLoot), picked on dice keyed on the seed, the landmark and the
## renewal period (`renew_gens` generations), so they are the same while the trader stays and change when it renews; what the family has bought is
## recorded in `GameDynasty.shop_sold` under `site:<id>` for the period (a purchase is gone until it renews). Prices use `GameItems.price_mult`, so a
## world event and the Caravaneer count (the town's faction does not apply out here). Nothing draws a die of the dynasty's, the autopilot never walks
## the wilds, and nothing new is saved but those marks.
class_name GameWildsTrade
extends RefCounted

const PREFIX := "site:"


static func def_of(lm: Dictionary) -> Dictionary:
	return GameWildsSites._def(str(lm["kind"])).get("merchant", {})


static func is_trader(lm: Dictionary) -> bool:
	return not lm.is_empty() and not def_of(lm).is_empty()


## The renewal period the wares belong to: a new set every `renew_gens` generations.
static func period(d: GameDynasty) -> int:
	return int(floor(float(d.gen - 1) / float(GameWilds.setting("renew_gens"))))


## The landmark that makes this trader wary: the nearest one within the trader's `wary` range that sends a fight (an `encounter` block) and is not cleared, or {}.
## A trader with no `wary` is never wary. The wagon opens again once the heir has won there (GameWildsFights.won) or the clearing runs out and is fought again.
static func wary_of(d: GameDynasty, lm: Dictionary) -> Dictionary:
	var r := 0.0 if lm.is_empty() else float(def_of(lm).get("wary", 0.0))
	if r <= 0.0:
		return {}
	for o in GameWildsSites.within(d, float(lm["x"]) + 0.5, float(lm["z"]) + 0.5, r):
		if str(o["id"]) != str(lm["id"]) and not GameWildsFights.block(o).is_empty() and not GameWildsFights.cleared(d, str(o["id"])):
			return o
	return {}


static func _mark_key(lm: Dictionary) -> String:
	return PREFIX + str(lm["id"])


static func _period_text(d: GameDynasty) -> String:
	return "g%d" % period(d)


static func sold_out(d: GameDynasty, lm: Dictionary, key: String) -> bool:
	var rec: Variant = d.shop_sold.get(_mark_key(lm))
	return rec != null and str((rec as Dictionary)["period"]) == _period_text(d) and (rec as Dictionary)["keys"].has(key)


static func _mark_sold(d: GameDynasty, lm: Dictionary, key: String) -> void:
	var mk := _mark_key(lm)
	var rec: Variant = d.shop_sold.get(mk)
	if rec == null or str((rec as Dictionary)["period"]) != _period_text(d):
		d.shop_sold[mk] = {"period": _period_text(d), "keys": []}
	if not (d.shop_sold[mk]["keys"] as Array).has(key):
		(d.shop_sold[mk]["keys"] as Array).append(key)


## The price of a ware: the item's price times the trade's markup and the world's prices.
static func price_of(d: GameDynasty, item: String) -> int:
	return maxi(1, int(round(float(GameItems.item_def(item).get("price", 0)) * float(GameWilds.setting("markup")) * GameItems.price_mult(d))))


## What the trader has for sale now, less what the family has bought: [{key, id, price}] (the generated wares, then the find).
static func wares(d: GameDynasty, lm: Dictionary) -> Array:
	var out: Array = []
	if not is_trader(lm):
		return out
	var md := def_of(lm)
	var def := GameWildsSites._def(str(lm["kind"]))
	var pool: Array = GameWildsSites._stock(def, str(lm["area"])).duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "wilds_trade", str(lm["id"]), period(d)])
	for i in range(pool.size() - 1, 0, -1):   # a shuffle on this trader's own dice
		var j := r.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var c: Array = md["stock_count"]
	var n := mini(pool.size(), r.randi_range(int(c[0]), int(c[1])))
	for i in n:
		var id := str(pool[i])
		var key := "item:" + id
		if not sold_out(d, lm, key):
			out.append({"key": key, "id": id, "price": price_of(d, id)})
	if bool(md.get("find", false)):
		var find := GameWildsLoot.roll(d, str(lm["area"]), str(lm["id"]), str(lm["kind"]), {"boost": 1.0, "n": period(d), "biome": str(lm["biome"]), "slots": {}})
		if find != "" and not GameItems.item_def(find).is_empty() and not bool(GameItems.item_def(find).get("unique", false)):
			var fkey := "find:" + find
			if not sold_out(d, lm, fkey):
				out.append({"key": fkey, "id": find, "price": int(round(float(price_of(d, find)) * 1.1))})
	return out


static func _ware(d: GameDynasty, lm: Dictionary, key: String) -> Dictionary:
	for w in wares(d, lm):
		if str(w["key"]) == key:
			return w
	return {}


## Buys a ware by its key. Returns the line (also in the journal).
static func buy(d: GameDynasty, lm: Dictionary, key: String) -> String:
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm)}
	var w := _ware(d, lm, key)
	if w.is_empty():
		return GameWilds.text("not_for_sale", vals)
	var id := str(w["id"])
	vals["item"] = GameItems.item_name(id)
	vals["price"] = int(w["price"])
	if GameItems.stack_max(id) <= 0 and GameItems.owns(d.heir, id):
		return GameMessages.text("life", "already_has", {"name": d.heir.name, "item": GameItems.item_name(id)})
	if d.heir.gold < int(w["price"]):
		return GameWilds.text("poor", vals)
	if not GameCarry.can_carry(d.heir, id):
		return GameWilds.text("full", vals)
	d.heir.gold -= int(w["price"])
	d.heir.inventory.append(id)
	_mark_sold(d, lm, key)
	var line := GameWilds.text("bought", vals)
	d._say(line)
	return line


## Whether the trader takes an item from the pack: of a slot or kind it wants, not unique, not worn.
static func wants(lm: Dictionary, id: String) -> bool:
	var md := def_of(lm)
	var it := GameItems.item_def(id)
	return not it.is_empty() and not bool(it.get("unique", false)) and GameItems.slot_of(id) in md.get("wants_slots", [])


static func sell_price(d: GameDynasty, lm: Dictionary, id: String) -> int:
	return maxi(1, int(round(float(GameItems.sell_price(d, id)) * float(def_of(lm).get("buy_share", 0.5)))))


## The pack's items the trader would buy: [{id, price}] (never what is worn).
static func sellable(d: GameDynasty, lm: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for id in d.heir.inventory:
		if wants(lm, str(id)) and not seen.has(str(id)):
			seen[str(id)] = true
			out.append({"id": str(id), "price": sell_price(d, lm, str(id)), "n": d.heir.inventory.count(id)})
	return out


static func sell(d: GameDynasty, lm: Dictionary, id: String) -> String:
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm), "item": GameItems.item_name(id)}
	if id not in d.heir.inventory:
		return GameShops.text("not_in_pack", {"name": d.heir.name, "item": GameItems.item_name(id)})
	if not wants(lm, id):
		return GameWilds.text("not_wanted", vals)
	var price := sell_price(d, lm, id)
	vals["price"] = price
	d.heir.inventory.erase(id)
	d.heir.gold += price
	var line := GameWilds.text("sold", vals)
	d._say(line)
	return line


## The materials in the stores the trader would buy: [{id, have, price}] (a material with one of the trader's `wants_tags`; `price` is for one).
static func sellable_materials(d: GameDynasty, lm: Dictionary) -> Array:
	var out: Array = []
	var md := def_of(lm)
	for m in GameMaterials.ids():
		var have := GameCraft.have(d, str(m))
		if have <= 0:
			continue
		for t in md.get("wants_tags", []):
			if str(t) in GameMaterials.tags_of(str(m)):
				out.append({"id": str(m), "have": have, "price": maxi(1, int(round(GameShops.unit_price(str(m)) * float(md.get("material_share", 0.5)))))})
				break
	return out


static func sell_material(d: GameDynasty, lm: Dictionary, material: String, n: int) -> String:
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm), "material": GameMaterials.name_of(material).to_lower()}
	for s in sellable_materials(d, lm):
		if str(s["id"]) == material:
			var k := clampi(n, 1, int(s["have"]))
			GameCraft.add_material(d, material, -k)
			d.heir.gold += k * int(s["price"])
			vals["n"] = k
			vals["price"] = k * int(s["price"])
			var line := GameWilds.text("sold_mats", vals)
			d._say(line)
			return line
	return GameWilds.text("not_wanted", {"name": vals["name"], "item": vals["material"]})


## The trader's barter rows: [{index, give: {material: n}, get: {item|gold}, ok (the stores hold it), give_text, get_text}].
static func barters(d: GameDynasty, lm: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = def_of(lm).get("barter", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var ok := true
		var gparts: Array = []
		for m in row["give"]:
			ok = ok and GameCraft.have(d, str(m)) >= int(row["give"][m])
			gparts.append("%d %s" % [int(row["give"][m]), GameMaterials.name_of(str(m)).to_lower()])
		var get_text := ("%s gold" % GameText.num(int(round(float(row["get"]["gold"]) * GameData.enemy_scale(d.gen))))) if row["get"].has("gold") else GameItems.item_name(str(row["get"]["item"]))
		out.append({"index": i, "give": row["give"], "get": row["get"], "ok": ok, "give_text": ", ".join(gparts), "get_text": get_text})
	return out


static func barter(d: GameDynasty, lm: Dictionary, index: int) -> String:
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm)}
	var rows := barters(d, lm)
	if index < 0 or index >= rows.size():
		return GameWilds.text("not_for_sale", vals)
	var b: Dictionary = rows[index]
	vals["give"] = b["give_text"]
	vals["get"] = b["get_text"]
	if not bool(b["ok"]):
		return GameWilds.text("no_materials", vals)
	if (b["get"] as Dictionary).has("item"):
		var id := str(b["get"]["item"])
		if GameItems.stack_max(id) <= 0 and GameItems.owns(d.heir, id):
			return GameMessages.text("life", "already_has", {"name": d.heir.name, "item": GameItems.item_name(id)})
		if not GameCarry.can_carry(d.heir, id):
			vals["item"] = GameItems.item_name(id)
			vals["price"] = 0
			return GameWilds.text("full", vals)
	for m in b["give"]:
		GameCraft.add_material(d, str(m), -int(b["give"][m]))
	if (b["get"] as Dictionary).has("gold"):
		d.heir.gold += int(round(float(b["get"]["gold"]) * GameData.enemy_scale(d.gen)))
	else:
		d.heir.inventory.append(str(b["get"]["item"]))
	var line := GameWilds.text("bartered", vals)
	d._say(line)
	return line


static func validate() -> Array:
	var bad: Array = []
	GameData.load_all()
	var found := false
	for kind in GameWilds.data()["landmarks"]:
		var def: Dictionary = GameWilds.data()["landmarks"][kind]
		var md: Dictionary = def.get("merchant", {})
		if bool(def.get("trade", false)) != not md.is_empty():
			bad.append("wilds.json: '%s' must have a merchant block exactly when it trades" % kind)
		if md.is_empty():
			continue
		found = true
		for k in ["stock_count", "buy_share", "material_share", "wants_slots", "wants_tags", "barter"]:
			if not md.has(k):
				bad.append("wilds.json: the merchant block of '%s' has no %s" % [kind, k])
		if not md.has("barter") or not md.has("stock_count"):
			continue
		var c: Array = md["stock_count"]
		if c.size() != 2 or int(c[0]) < 1 or int(c[1]) < int(c[0]) or int(c[1]) > 8:
			bad.append("wilds.json: '%s' stock_count is [min, max] of 1 to 8" % kind)
		if float(md["buy_share"]) <= 0.0 or float(md["buy_share"]) > 1.0 or float(md["material_share"]) <= 0.0 or float(md["material_share"]) > 1.0:
			bad.append("wilds.json: '%s' buy_share and material_share are above 0 and at most 1" % kind)
		if float(md.get("wary", 0.0)) < 0.0 or float(md.get("wary", 0.0)) > 40.0:
			bad.append("wilds.json: '%s' wary is a range of 0 to 40 tiles" % kind)
		for t in md["wants_tags"]:
			var used := false
			for m in GameMaterials.ids():
				used = used or str(t) in GameMaterials.tags_of(str(m))
			if not used:
				bad.append("wilds.json: '%s' wants the tag '%s', which no material has" % [kind, t])
		for s in md["wants_slots"]:
			if str(s) not in GameItems.SLOTS and str(s) != "remedy":
				bad.append("wilds.json: '%s' wants the unknown slot '%s'" % [kind, s])
		for row in md["barter"]:
			if not row.has("give") or not row.has("get") or (row["give"] as Dictionary).is_empty():
				bad.append("wilds.json: a barter row of '%s' needs give and get" % kind)
				continue
			for m in row["give"]:
				if not GameMaterials.has(str(m)) or int(row["give"][m]) < 1:
					bad.append("wilds.json: '%s' barters the unknown material or count '%s'" % [kind, m])
			var g: Dictionary = row["get"]
			if (g.has("item") and GameItems.item_def(str(g["item"])).is_empty()) or (not g.has("item") and not g.has("gold")) or (g.has("gold") and float(g["gold"]) <= 0.0):
				bad.append("wilds.json: a barter row of '%s' gets nothing real" % kind)
	if not found:
		bad.append("wilds.json: no landmark trades")
	for k in ["merchant_open", "sold", "sold_mats", "bartered", "not_wanted", "no_materials", "not_for_sale", "no_trader", "wary"]:
		if not GameWilds.data()["text"].has(k):
			bad.append("wilds.json: text.%s is missing" % k)
	return bad
