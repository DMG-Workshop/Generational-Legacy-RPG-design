## Spellcasting as a shop service (data/shops/casting.json; specified in docs/SHOP_SERVICES.md). A shop whose `services` hold rows of kind
## `cast` casts a party-shaped spell of data/spells/spells.json for the heir, for gold (a purchase: the heir's own mana is not spent):
## healing and cleansing take effect at once (the party mended, every sickness cured), a blessing (ward, haste, rejuvenation) is laid on the
## party for the NEXT fight and applied when it begins, one at a time, for a fight or a year and until the heir dies. A cast has a cooldown
## of a day of the world clock per shop and spell. No dice are drawn. `GameDynasty.blessing` and `casts_used` are saved only when set and
## loaded clean here; `GameDynasty._begin_battle` asks `on_battle`. The autopilot never casts, so no seeded life or golden digest moves.
## The heir's OWN spells (`self_castable`, `self_cast`) are the same system paid in MP: the same kinds, the same effects, the same blessing; a ward
## blessing (`trap_wards`) also turns the next hidden trap of a dungeon (`ward_up`, `spend_ward`).
class_name GameCasting
extends RefCounted

const PATH := "res://data/shops/casting.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func spell(id: String) -> Dictionary:
	return GameCombat.spell(id)


## The casting rows of a shop's `services` ([] for a shop that does not cast).
static func rows(shop_id: String) -> Array:
	return GameShops.def(shop_id).get("services", []).filter(func(sv): return str(sv.get("kind", "")) == "cast")


static func row(shop_id: String, service_id: String) -> Dictionary:
	for sv in rows(shop_id):
		if str(sv["id"]) == service_id:
			return sv
	return {}


## "healing", "cleansing" or "blessing" (what the spell does when bought), "" for a spell not for sale.
static func kind_of(spell_id: String) -> String:
	return str(setting("kinds").get(spell_id, ""))


## How much stronger a caster of `level` makes the spell (1.0 at level 1).
static func level_mult(sv: Dictionary) -> float:
	return 1.0 + float(setting("level_step")) * float(int(sv.get("caster_level", 1)) - 1)


static func price(d: GameDynasty, sv: Dictionary) -> int:
	var mp := int(spell(str(sv["spell"])).get("mp", 0))
	return maxi(1, int(round(float(mp) * float(setting("mp_gold")) * (1.0 + float(setting("price_step")) * float(int(sv.get("caster_level", 1)) - 1)) * GameItems.price_mult(d))))


## The day the world clock is at, as a mark: the world year and the day of the world clock (GameDay). The life screen's clock stands
## still, so a cooldown there lasts until the open world's day has passed.
static func day_mark(d: GameDynasty) -> String:
	return "%d|%d" % [int(floor(d.world.year)), int(floor(d.world_seconds / float(GameDay.setting("day_seconds"))))]


static func _used_key(d: GameDynasty, shop_id: String, service_id: String) -> String:
	return "%s|%s|%s" % [d.world.location, shop_id, service_id]


static func on_cooldown(d: GameDynasty, shop_id: String, sv: Dictionary) -> bool:
	return bool(sv.get("daily", true)) and str(d.casts_used.get(_used_key(d, shop_id, str(sv["id"])), "")) == day_mark(d)


## The blessing laid on the party that still holds ({} when none, or when it has lapsed: its fights used, its year gone, its heir dead).
static func blessing(d: GameDynasty) -> Dictionary:
	var b := d.blessing
	if b.is_empty():
		return {}
	if int(b.get("fights", 0)) <= 0 or int(b.get("gen", -1)) != d.gen or d.world.year - float(b.get("year", 0.0)) >= float(b.get("years", 1.0)):
		return {}
	return b


## What buying `service_id` at `shop_id` would do, nothing spent: {ok, why, price, kind}.
static func plan(d: GameDynasty, shop_id: String, service_id: String) -> Dictionary:
	var h := d.heir
	var sv := row(shop_id, service_id)
	var fail := func(why: String) -> Dictionary: return {"ok": false, "why": why, "price": 0 if sv.is_empty() else price(d, sv), "kind": ""}
	if sv.is_empty():
		return fail.call(text("no_service", {"shop": GameShops.name_of(shop_id)}))
	if not d.world.has_service(shop_id):
		return fail.call(GameShops.text("not_here", {"shop": GameShops.name_of(shop_id)}))
	if not GameShops.is_open(d, shop_id):
		return fail.call(GameShops.shut_line(d, shop_id))
	var sp := spell(str(sv["spell"]))
	var kind := kind_of(str(sv["spell"]))
	if sp.is_empty() or kind == "":
		return fail.call(text("not_for_sale", {"spell": str(sv["spell"])}))
	if d.battle != null:
		return fail.call(text("in_fight"))
	var cost := price(d, sv)
	var out := {"ok": true, "why": "", "price": cost, "kind": kind}
	if on_cooldown(d, shop_id, sv):
		out["ok"] = false
		out["why"] = text("cooldown", {"shop": GameShops.name_of(shop_id), "spell": str(sp["name"])})
	elif h.gold < cost:
		out["ok"] = false
		out["why"] = text("no_gold", {"name": h.name, "price": GameText.num(cost)})
	elif kind == "healing" and not _needs_mending(d):
		out["ok"] = false
		out["why"] = text("no_need", {"name": h.name})
	elif kind == "cleansing" and h.diseases.is_empty():
		out["ok"] = false
		out["why"] = text("cleansed_none", {"name": h.name})
	elif kind == "blessing" and str(blessing(d).get("spell", "")) == str(sv["spell"]) and int(blessing(d).get("level", 1)) >= int(sv.get("caster_level", 1)):
		out["ok"] = false
		out["why"] = text("same", {"spell": str(sp["name"])})
	return out


static func _needs_mending(d: GameDynasty) -> bool:
	if d.heir.hp < d.heir.max_hp():
		return true
	for m in d.party.members:
		if int(m["hp"]) < d.party._body(d, m).max_hp():
			return true
	return false


## Buys and casts it. Returns the line (also written to the journal).
static func cast(d: GameDynasty, shop_id: String, service_id: String) -> String:
	var p := plan(d, shop_id, service_id)
	if not p["ok"]:
		return str(p["why"])
	var h := d.heir
	var sv := row(shop_id, service_id)
	var sp := spell(str(sv["spell"]))
	var shop := GameShops.name_of(shop_id)
	h.gold -= int(p["price"])
	d.casts_used[_used_key(d, shop_id, service_id)] = day_mark(d)
	var cost := GameText.num(int(p["price"]))
	var line := ""
	match str(p["kind"]):
		"healing":
			var share: float = float(sp.get("pct_max_hp", 0.0)) * level_mult(sv)
			var healed := mini(h.max_hp() - h.hp, int(ceil(share * float(h.max_hp()))))
			h.hp += maxi(0, healed)
			for m in d.party.members:
				var mx: int = d.party._body(d, m).max_hp()
				m["hp"] = mini(mx, int(m["hp"]) + int(ceil(share * float(mx))))
			line = text("healed", {"name": h.name, "price": cost, "shop": shop, "what": "%d%% of their health" % int(round(share * 100.0))})
		"cleansing":
			var n := 0
			for e in h.diseases.duplicate():
				if GameDisease.cure(h, str(e["id"])):
					n += 1
			var share2: float = float(sp.get("pct_max_hp", 0.0)) * level_mult(sv)
			h.hp = mini(h.max_hp(), h.hp + int(ceil(share2 * float(h.max_hp()))))
			line = text("cleansed", {"name": h.name, "price": cost, "shop": shop, "what": "%d sickness%s washed away" % [n, "" if n == 1 else "es"]})
		"blessing":
			var old := str(blessing(d).get("spell", ""))
			d.blessing = {"spell": str(sv["spell"]), "fights": int(sv.get("fights", 1)), "years": float(sv.get("years", 1.0)), "year": d.world.year, "gen": d.gen, "level": int(sv.get("caster_level", 1))}
			line = text("blessed", {"name": h.name, "price": cost, "shop": shop, "spell": str(sp["name"])})
			if old != "" and old != str(sv["spell"]):
				line += " " + text("replaced", {"old": str(spell(old).get("name", old))})
	d._say(line)
	return line


## ---- the heir's own spells, paid in MP ----------------------------------------------------------------------------------------------

## The spells the heir knows that this system has a kind for: [{id, name, cost, kind, can, why}] in their spell-list order. `can` is whether
## they have the MP; `why` says what is lacking when they do not.
static func self_castable(d: GameDynasty) -> Array:
	var out: Array = []
	if d.heir == null:
		return out
	for id in d.heir.spells:
		if kind_of(str(id)) == "":
			continue
		var sp := GameSkillTree.spell(d.heir, str(id))
		if sp.is_empty():
			continue
		var cost := GameCombat.ability_cost(sp, d.heir.level)
		var enough := d.heir.mp >= cost
		out.append({"id": str(id), "name": str(sp.get("name", id)), "cost": cost, "kind": kind_of(str(id)), "can": enough,
			"why": "" if enough else text("self_no_mp", {"name": str(sp.get("name", id)), "cost": cost})})
	return out


## The heir casts one of their own spells, outside a fight, for MP: {ok, text, kind}. Refused (nothing paid) for a spell not known or
## not of a kind here, without the MP, a healing spell when everyone is whole, a cleansing one with no sickness, or a blessing already
## laid. The effects are the shop's own: healing mends the heir and the party, cleansing cures every sickness, a blessing is laid for
## the next fight. No dice are drawn.
static func self_cast(d: GameDynasty, id: String) -> Dictionary:
	var kind := kind_of(id)
	if d.heir == null or d.battle != null or id not in d.heir.spells or kind == "":
		return {"ok": false, "text": text("self_unknown"), "kind": ""}
	var sp := GameSkillTree.spell(d.heir, id)
	if sp.is_empty():
		return {"ok": false, "text": text("self_unknown"), "kind": ""}
	var h := d.heir
	var name := str(sp.get("name", id))
	var cost := GameCombat.ability_cost(sp, h.level)
	if h.mp < cost:
		return {"ok": false, "text": text("self_no_mp", {"name": name, "cost": cost}), "kind": kind}
	var line := ""
	match kind:
		"healing":
			if not _needs_mending(d):
				return {"ok": false, "text": text("no_need", {"name": h.name}), "kind": kind}
			h.mp -= cost
			var pct := float(sp.get("pct_max_hp", 0.1))
			var n := _mend_heir(h, pct)
			var mended: Array = [h.name]
			for m in d.party.members:
				var body = d.party._body(d, m)
				var room: int = body.max_hp() - int(m["hp"])
				if room <= 0:
					continue
				m["hp"] = int(m["hp"]) + mini(room, GameBattle.heal_amount(h, body, {"pct_max_hp": pct}))
				mended.append(str(m["name"]))
			line = text("self_healed", {"h": h.name, "spell": name, "who": GameMessages.text("life", "list_and").join(mended), "n": n})
		"cleansing":
			if h.diseases.is_empty():
				return {"ok": false, "text": text("cleansed_none", {"name": h.name}), "kind": kind}
			h.mp -= cost
			var cured := 0
			for e in h.diseases.duplicate():
				if GameDisease.cure(h, str(e["id"])):
					cured += 1
			_mend_heir(h, float(sp.get("pct_max_hp", 0.0)))
			line = text("self_cleansed", {"h": h.name, "spell": name, "what": "%d sickness%s washed away" % [cured, "" if cured == 1 else "es"]})
		"blessing":
			if str(blessing(d).get("spell", "")) == id:
				return {"ok": false, "text": text("same", {"spell": name}), "kind": kind}
			h.mp -= cost
			d.blessing = {"spell": id, "fights": int(setting("self_fights")), "years": float(setting("self_years")), "year": d.world.year, "gen": d.gen, "level": 1}
			line = text("self_blessed", {"h": h.name, "spell": name})
			if id in setting("trap_wards"):
				line += text("self_ward")
	d._say(line)
	return {"ok": true, "text": line, "kind": kind}


static func _mend_heir(h: GameHeir, pct: float) -> int:
	var n := maxi(0, mini(GameBattle.heal_amount(h, h, {"pct_max_hp": pct}), h.max_hp() - h.hp))
	h.hp += n
	return n


## Whether a ward of the kind that turns traps is up and not yet used on one (a dungeon asks this before a hidden trap goes off).
static func ward_up(d: GameDynasty) -> bool:
	var b := blessing(d)
	return not b.is_empty() and str(b["spell"]) in setting("trap_wards") and not bool(b.get("trap_spent", false))


## The ward has turned a trap aside: it will not turn another, though it still blesses the next fight.
static func spend_ward(d: GameDynasty) -> void:
	if ward_up(d):
		d.blessing["trap_spent"] = true


## Called as a fight begins: lays the blessing's statuses on the heir and every companion, then spends one of its fights.
static func on_battle(d: GameDynasty, b: GameBattle) -> void:
	var bl := blessing(d)
	if bl.is_empty():
		d.blessing = {}
		return
	var sp := spell(str(bl["spell"]))
	var mult := 1.0 + float(setting("level_step")) * float(int(bl.get("level", 1)) - 1)
	var refs: Array = ["heir"]
	for i in b.allies.size():
		refs.append("ally:%d" % i)
	for st in sp.get("statuses", []):
		for ref in refs:
			b.apply_status(str(ref), str(st["id"]), float(st.get("potency", 0.0)) * mult, int(st.get("turns", 1)), "heir")
	b._say(text("blessing_on", {"spell": str(sp.get("name", bl["spell"]))}))
	bl["fights"] = int(bl["fights"]) - 1
	d.blessing = bl if int(bl["fights"]) > 0 else {}


static func load_blessing(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var spell_id: Variant = (v as Dictionary).get("spell")
	if typeof(spell_id) != TYPE_STRING or kind_of(str(spell_id)) != "blessing":
		return {}
	var out := {"spell": str(spell_id)}
	for k in ["fights", "gen", "level"]:
		var n: Variant = (v as Dictionary).get(k)
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or int(n) < 0 or int(n) != n:
			return {}
		out[k] = int(n)
	for k in ["years", "year"]:
		var f: Variant = (v as Dictionary).get(k)
		if typeof(f) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(f)) or is_inf(float(f)):
			return {}
		out[k] = float(f)
	if typeof((v as Dictionary).get("trap_spent")) == TYPE_BOOL and bool((v as Dictionary)["trap_spent"]):
		out["trap_spent"] = true
	return out if int(out["fights"]) > 0 else {}


static func load_used(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in (v as Dictionary):
		if typeof(k) == TYPE_STRING and typeof((v as Dictionary)[k]) == TYPE_STRING and str(k).count("|") == 2:
			out[str(k)] = str((v as Dictionary)[k])
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "text"]:
		if not dat.has(k):
			return ["casting.json: %s is missing" % k]
	GameData.load_all()
	var s: Dictionary = dat["settings"]
	for k in ["mp_gold", "level_step", "price_step", "kinds", "self_fights", "self_years", "trap_wards"]:
		if not s.has(k):
			bad.append("casting.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["mp_gold"]) <= 0.0 or float(s["level_step"]) < 0.0 or float(s["level_step"]) > 0.2 or float(s["price_step"]) < 0.0:
		bad.append("casting.json: mp_gold is positive, level_step 0 to 0.2 and price_step not negative")
	for sid in s["kinds"]:
		var sp := spell(str(sid))
		var kind := str(s["kinds"][sid])
		if sp.is_empty():
			bad.append("casting.json: '%s' is not a spell" % sid)
		elif str(sp.get("target", {}).get("shape", "")) != "party":
			bad.append("casting.json: '%s' is not a party spell (a shop does not aim at foes)" % sid)
		elif kind not in ["healing", "cleansing", "blessing"]:
			bad.append("casting.json: '%s' has the unknown kind '%s'" % [sid, kind])
		elif kind == "healing" and not sp.has("pct_max_hp"):
			bad.append("casting.json: the healing spell '%s' has no pct_max_hp" % sid)
		elif kind == "blessing":
			if sp.get("statuses", []).is_empty():
				bad.append("casting.json: the blessing '%s' has no statuses to lay on the party" % sid)
			for st in sp.get("statuses", []):
				if GameCombat.status_def(str(st["id"])).is_empty():
					bad.append("casting.json: the blessing '%s' lays the unknown status '%s'" % [sid, st["id"]])
	if int(s["self_fights"]) < 1 or float(s["self_years"]) <= 0.0:
		bad.append("casting.json: self_fights is at least 1 and self_years above 0")
	for w in s["trap_wards"]:
		if kind_of(str(w)) != "blessing":
			bad.append("casting.json: trap_wards names '%s', which is not a blessing" % w)
	for k in ["healed", "cleansed", "cleansed_none", "blessed", "replaced", "blessing_on", "no_service", "not_for_sale", "no_gold", "no_need", "cooldown", "in_fight", "same",
			"self_unknown", "self_no_mp", "self_healed", "self_cleansed", "self_blessed", "self_ward"]:
		if not dat["text"].has(k):
			bad.append("casting.json: text.%s is missing" % k)
	var found := false
	for sh in GameShops.data()["shops"]:
		var seen := {}
		for sv in sh.get("services", []):
			if str(sv.get("kind", "")) != "cast":
				continue
			found = true
			for k in ["id", "name", "desc", "spell", "caster_level", "fights", "years"]:
				if not sv.has(k):
					bad.append("shops.json: a cast service of '%s' has no %s" % [sh["id"], k])
			if seen.has(str(sv.get("id", ""))):
				bad.append("shops.json: '%s' has two cast services '%s'" % [sh["id"], sv.get("id")])
			seen[str(sv.get("id", ""))] = true
			if kind_of(str(sv.get("spell", ""))) == "":
				bad.append("shops.json: the cast service '%s' of '%s' sells '%s', which is not for sale" % [sv.get("id"), sh["id"], sv.get("spell")])
			if int(sv.get("caster_level", 0)) < 1 or int(sv.get("fights", 0)) < 1 or float(sv.get("years", 0.0)) <= 0.0:
				bad.append("shops.json: the cast service '%s' of '%s' needs caster_level and fights of at least 1 and years above 0" % [sv.get("id"), sh["id"]])
	if not found:
		bad.append("shops.json: no shop has a cast service")
	return bad
