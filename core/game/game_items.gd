## Items, equipment, town shops and the temple. Item effects use the same stat names as trait
## effects and are added into GameHeir.trait_total, so equipped gear works everywhere a trait does.
## Shop actions take no time. Each returns a message for the journal; the caller records it.
class_name GameItems
extends RefCounted

const SLOTS := ["weapon", "armor", "trinket"]
const SHOPS := ["forge", "store", "temple"]
const ITEMS_PATH := "res://data/items/items.json"

static var _labels: Dictionary = {}
static var _labels_loaded := false


static func item_def(id: String) -> Dictionary:
	GameData.load_all()
	return GameData.items.get(id, {})


static func item_name(id: String) -> String:
	return str(item_def(id).get("name", id))


static func slot_of(id: String) -> String:
	return str(item_def(id).get("slot", ""))


# ---------------------------------------------------------------- describing effects

static func _effect_labels() -> Dictionary:
	if not _labels_loaded:
		var raw = GameData.load_json(ITEMS_PATH)
		_labels = raw.get("effect_labels", {}) if typeof(raw) == TYPE_DICTIONARY else {}
		_labels_loaded = true
	return _labels


## "+10% damage" for one effect. Values are fractions (0.1 = 10%).
static func effect_text(stat: String, value: float) -> String:
	var pct := value * 100.0
	var num: String = ("%d" % int(round(absf(pct)))) if is_equal_approx(pct, round(pct)) else ("%.1f" % absf(pct))
	var label: String = str(_effect_labels().get(stat, stat.replace("_", " ")))
	return "%s%s%% %s" % ["-" if pct < 0.0 else "+", num, label]


## Short text for a list of effects: "+10% damage, +3% crit".
static func describe_effects(effects: Array) -> String:
	var parts: Array = []
	for e in effects:
		parts.append(effect_text(str(e["stat"]), float(e["value"])))
	return ", ".join(parts) if not parts.is_empty() else "no effect"


## Short effects text for an item, for shop rows and reward messages.
static func describe(id: String) -> String:
	return describe_effects(item_def(id).get("effects", []))


## "Steel Sword (+20% damage)": an item's name with what it does.
static func name_with_effects(id: String) -> String:
	return "%s (%s)" % [item_name(id), describe(id)]


# ---------------------------------------------------------------- shops

static func shop_tier(d: GameDynasty) -> int:
	return int(d.world.here().get("shop_tier", 0))


## The shop services in this town, in display order.
static func shops_here(d: GameDynasty) -> Array:
	return SHOPS.filter(func(s): return d.world.has_service(s))


## Item ids one shop here sells: its own wares up to the town's tier. Unique items are never sold.
static func stock(d: GameDynasty, service: String) -> Array:
	GameData.load_all()
	if not d.world.has_service(service):
		return []
	var tier := shop_tier(d)
	var out: Array = []
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if it.get("shop", "") == service and not it.get("unique", false) and int(it.get("tier", 1)) <= tier:
			out.append(id)
	out.sort_custom(func(a, b): return _shelf_order(a, b))
	return out


static func _shelf_order(a: String, b: String) -> bool:
	var da := item_def(a)
	var db := item_def(b)
	var sa := SLOTS.find(da.get("slot", ""))
	var sb := SLOTS.find(db.get("slot", ""))
	if sa != sb:
		return sa < sb
	if int(da.get("tier", 1)) != int(db.get("tier", 1)):
		return int(da.get("tier", 1)) < int(db.get("tier", 1))
	return float(da.get("price", 0)) < float(db.get("price", 0))


static func sold_here(d: GameDynasty, id: String) -> bool:
	for s in shops_here(d):
		if id in stock(d, s):
			return true
	return false


## Shop price multiplier: generation scaling, the heir's persuasion, the house's infamy.
static func price_mult(d: GameDynasty) -> float:
	var persuasion := clampf(d.heir.trait_total("persuasion"), 0.0, float(GameData.bal("shop_persuasion_cap")))
	return GameData.enemy_scale(d.gen) * (1.0 + d.echo_total("infamy")) * (1.0 - persuasion)


static func price(d: GameDynasty, id: String) -> int:
	return maxi(1, int(round(float(item_def(id).get("price", 0)) * price_mult(d))))


## What a merchant pays for an item: a fraction of its value, less for an infamous house.
static func sell_price(d: GameDynasty, id: String) -> int:
	var v := float(item_def(id).get("price", 0)) * GameData.enemy_scale(d.gen) * float(GameData.bal("sell_fraction"))
	return maxi(1, int(round(v / (1.0 + d.echo_total("infamy")))))


static func equipped(h: GameHeir, slot: String) -> String:
	return str(h.equipment.get(slot, ""))


static func owns(h: GameHeir, id: String) -> bool:
	return id in h.inventory or id in h.equipment.values()


static func buy(d: GameDynasty, id: String) -> String:
	var h := d.heir
	if item_def(id).is_empty():
		return "No such item."
	var iname := item_name(id)
	if not sold_here(d, id):
		return "No one in %s sells the %s." % [d.world.here()["name"], iname]
	if owns(h, id):
		return "%s already owns a %s." % [h.name, iname]
	var cost := price(d, id)
	if h.gold < cost:
		return "Not enough gold for the %s (%d needed)." % [iname, cost]
	h.gold -= cost
	h.inventory.append(id)
	if slot_of(id) in SLOTS and equipped(h, slot_of(id)) == "":
		_wear(h, id)
		return "%s buys the %s for %d gold and puts it on." % [h.name, iname, cost]
	return "%s buys the %s for %d gold. It goes in the pack." % [h.name, iname, cost]


## Wear an item from the pack; whatever was in that slot goes back in the pack.
static func equip(d: GameDynasty, id: String) -> String:
	var h := d.heir
	if id not in h.inventory:
		return "The %s is not in the pack." % item_name(id)
	if slot_of(id) not in SLOTS:
		return "The %s cannot be worn." % item_name(id)
	var old := _wear(h, id)
	if old != "":
		return "%s takes up the %s and packs away the %s." % [h.name, item_name(id), item_name(old)]
	return "%s takes up the %s." % [h.name, item_name(id)]


static func unequip(d: GameDynasty, slot: String) -> String:
	var h := d.heir
	var id := equipped(h, slot)
	if id == "":
		return "Nothing is worn there."
	var keep := _vitals(h)
	h.equipment[slot] = ""
	h.inventory.append(id)
	_restore_vitals(h, keep)
	return "%s packs away the %s." % [h.name, item_name(id)]


static func sell(d: GameDynasty, id: String) -> String:
	var h := d.heir
	if shops_here(d).is_empty():
		return "No one in %s buys gear." % d.world.here()["name"]
	if id not in h.inventory:
		return "The %s is not in the pack." % item_name(id)
	var gold := sell_price(d, id)
	h.inventory.erase(id)
	h.gold += gold
	return "%s sells the %s for %d gold." % [h.name, item_name(id), gold]


## Moves `id` from the pack into its slot. Returns the item it replaced ("" if none).
static func _wear(h: GameHeir, id: String) -> String:
	var slot := slot_of(id)
	var old := equipped(h, slot)
	var keep := _vitals(h)
	h.inventory.erase(id)
	if old != "":
		h.inventory.append(old)
	h.equipment[slot] = id
	_restore_vitals(h, keep)
	return old


## Changing gear changes max HP/MP; the heir keeps the same share of each, not the same number.
static func _vitals(h: GameHeir) -> Array:
	var hp_frac := float(h.hp) / float(maxi(1, h.max_hp()))
	var mp_frac := float(h.mp) / float(h.max_mp()) if h.max_mp() > 0 else 1.0
	return [hp_frac, mp_frac, h.hp > 0]


static func _restore_vitals(h: GameHeir, keep: Array) -> void:
	h.hp = clampi(int(round(float(keep[0]) * float(h.max_hp()))), 1 if keep[2] else 0, h.max_hp())
	h.mp = clampi(int(round(float(keep[1]) * float(h.max_mp()))), 0, h.max_mp())


# ---------------------------------------------------------------- temple

static func is_curse(id: String) -> bool:
	return GameData.trait_def(id).get("category", "") == "curse" or id in GameData.bal("cleansable_traits")


## Curses the temple can lift: expressed ones first, then those carried dormant.
static func curses_on(h: GameHeir) -> Array:
	var out: Array = []
	for t in h.traits + h.dormant:
		if is_curse(t) and t not in out:
			out.append(t)
	return out


## Times the living heir has used a temple service ("cleanse" or "prayer"). The count is kept on
## the dynasty for the current heir only, so a new heir starts at zero.
static func temple_uses(d: GameDynasty, kind: String) -> int:
	if int(d.shop_state.get("heir", -1)) != d.heir.id:
		return 0
	return int(d.shop_state.get(kind, 0))


static func _count_use(d: GameDynasty, kind: String) -> void:
	var n := temple_uses(d, kind) + 1
	if int(d.shop_state.get("heir", -1)) != d.heir.id:
		d.shop_state = {"heir": d.heir.id}
	d.shop_state[kind] = n


static func cleanse_price(d: GameDynasty) -> int:
	var p := float(GameData.bal("cleanse_cost")) * price_mult(d) * pow(float(GameData.bal("cleanse_cost_growth")), temple_uses(d, "cleanse"))
	return maxi(1, int(round(p)))


static func prayer_price(d: GameDynasty) -> int:
	var p := float(GameData.bal("prayer_cost")) * price_mult(d) * pow(float(GameData.bal("prayer_cost_growth")), temple_uses(d, "prayer"))
	return maxi(1, int(round(p)))


static func can_pray(d: GameDynasty) -> bool:
	return d.heir.fate_value > float(GameData.bal("fate_min")) + 0.00005


## Lift a curse from the heir entirely: it is neither expressed nor carried to children born later.
static func cleanse(d: GameDynasty, trait_id: String) -> String:
	var h := d.heir
	if not d.world.has_service("temple"):
		return "There is no temple in %s." % d.world.here()["name"]
	if trait_id not in curses_on(h):
		return "%s carries no %s to lift." % [h.name, GameData.trait_name(trait_id)]
	var cost := cleanse_price(d)
	if h.gold < cost:
		return "The priests ask %d gold to lift %s." % [cost, GameData.trait_name(trait_id)]
	h.gold -= cost
	h.traits.erase(trait_id)
	h.dormant.erase(trait_id)
	h.refresh_derived()
	_count_use(d, "cleanse")
	return "The priests of %s lift %s from %s for %d gold. No child born after this will carry it." % [d.world.here()["name"], GameData.trait_name(trait_id), h.name, cost]


## Prayer lowers the heir's Fate Value, never below the floor.
static func pray(d: GameDynasty) -> String:
	var h := d.heir
	if not d.world.has_service("temple"):
		return "There is no temple in %s." % d.world.here()["name"]
	if not can_pray(d):
		return "The priests say %s's fate is as light as prayer can make it." % h.name
	var cost := prayer_price(d)
	if h.gold < cost:
		return "An offering of %d gold is needed to pray." % cost
	h.gold -= cost
	var before := h.fate_value
	h.fate_value = snappedf(maxf(float(GameData.bal("fate_min")), h.fate_value - float(GameData.bal("prayer_fate_drop"))), 0.0001)
	_count_use(d, "prayer")
	return "%s keeps a vigil at the temple and offers %d gold. Fate Value %d%% -> %d%%." % [h.name, cost, int(round(before * 100.0)), int(round(h.fate_value * 100.0))]


# ---------------------------------------------------------------- autopilot

## "melee" or "magic": whichever the heir hits harder with.
static func fighting_style(h: GameHeir) -> String:
	return "magic" if h.magic_power() > h.attack_power() else "melee"


## How much an item helps a fighter of `style` (bot_gear_weights in balance.json). "" scores 0.
static func gear_score(id: String, style: String) -> float:
	if id == "":
		return 0.0
	var weights: Dictionary = GameData.bal("bot_gear_weights").get(style, {})
	var s := 0.0
	for e in item_def(id).get("effects", []):
		s += float(e["value"]) * float(weights.get(e["stat"], 0.0))
	return s


static func bot_reserve(d: GameDynasty) -> int:
	return d.potion_price() * int(GameData.bal("bot_gold_reserve_potions"))


## Town errands the autopilot runs between actions (no time passes): wear the best gear carried,
## buy clear upgrades without touching the potion reserve, sell what was outgrown, and visit the
## temple to lift a curse or ease a heavy fate when gold allows.
static func bot_tick(d: GameDynasty) -> void:
	if d.state != "life" or d.battle != null:
		return
	var h := d.heir
	var style := fighting_style(h)
	var margin := float(GameData.bal("bot_upgrade_margin"))
	var displaced: Array = []   # gear the bot itself replaced; anything else in the pack is left alone
	for slot in SLOTS:
		var best := ""
		var best_score := gear_score(equipped(h, slot), style) + margin
		for id in h.inventory:
			if slot_of(id) == slot and gear_score(id, style) > best_score:
				best = id
				best_score = gear_score(id, style)
		if best != "":
			displaced.append(equipped(h, slot))
			d._say(equip(d, best))
	if shops_here(d).is_empty():
		return
	var reserve := bot_reserve(d)
	var wares: Array = []
	for s in shops_here(d):
		wares.append_array(stock(d, s))
	for slot in SLOTS:
		var best := ""
		var best_score := gear_score(equipped(h, slot), style) + margin
		for id in wares:
			if slot_of(id) != slot or owns(h, id):
				continue
			var sc := gear_score(id, style)
			if sc > best_score and h.gold - price(d, id) >= reserve:
				best = id
				best_score = sc
		if best != "":
			d._say(buy(d, best))
			if equipped(h, slot) != best:
				displaced.append(equipped(h, slot))
				d._say(equip(d, best))
	for id in displaced:
		if id != "" and id in h.inventory and not item_def(id).get("unique", false):
			d._say(sell(d, id))
	if not d.world.has_service("temple"):
		return
	var worst := ""
	for t in h.traits:
		if is_curse(t) and (worst == "" or float(GameData.trait_def(t).get("fate_modifier", 0.0)) > float(GameData.trait_def(worst).get("fate_modifier", 0.0))):
			worst = t
	if worst != "" and h.gold - cleanse_price(d) >= reserve:
		d._say(cleanse(d, worst))
	var trials_left := "elder_years" not in h.milestones_done
	if trials_left and h.fate_value >= float(GameData.bal("bot_pray_fate")) and can_pray(d) and h.gold - prayer_price(d) >= reserve * 2:
		d._say(pray(d))
