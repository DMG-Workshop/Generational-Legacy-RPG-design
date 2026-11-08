## Raids and theft on the house (roadmap item 61). A house with something worth taking can be raided as the years
## pass: GameDynasty._pass_years asks here, and for each whole year the world clock crosses a raid may come, rolled on
## dice keyed on the dynasty seed and the year, never the dynasty's. What is worth taking is animals in the pens and a
## house that has been built (the Hall, the Yard, the Ranch). It arrives as an event (the ones marked `raid` in
## events.json), so the heir settles it on the event screen: trust the guards, ride out and fight, pay, or try a
## trick. Guards deter a raid and help beat it off (GameRanch.guard_cut). A house that keeps nothing and has built
## nothing is never raided, so the autopilot, which does neither, is untouched. Data: data/creatures/raids.json.
class_name GameRaids
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/raids.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func kinds() -> Array:
	var ids: Array = data()["kinds"].keys()
	ids.sort()
	return ids


## What the animals the house keeps would fetch alive: the stock a raider sees.
static func stock_value(d: GameDynasty) -> int:
	var total := 0
	for e in d.roster:
		total += GameRanch.sell_price(e, d)
	return total


## What the house itself is worth to a raider: part of what was paid to build it (each track's levels at the
## house's own prices), by `house_value_share`.
static func house_value(d: GameDynasty) -> int:
	var base := float(GameData.bal("house_base_cost"))
	var growth := float(GameData.bal("house_cost_growth"))
	var spent := 0.0
	for track in GameHouse.TRACKS:
		for i in GameHouse.level(d, track):
			spent += base * pow(growth, i)
	return int(round(spent * float(setting("house_value_share"))))


## Whether there is anything to raid: animals in the pens, or a house that has been built.
static func has_target(d: GameDynasty) -> bool:
	return not d.roster.is_empty() or house_value(d) > 0


## What a raider sees to take: the stock and the house.
static func valuables(d: GameDynasty) -> int:
	return stock_value(d) + house_value(d)


## How far the guards put raiders off, 0 to deter_share: none with no guards, the most with the most.
static func deterrence(d: GameDynasty) -> float:
	return GameRanch.guard_cut(d) / float(GameRanch.data()["work"]["guard_cut_max"]) * float(setting("deter_share"))


## The chance that a raid comes in a year: 0 with nothing kept or built, else more with more to take, less with guards.
static func chance(d: GameDynasty) -> float:
	if not has_target(d):
		return 0.0
	var c := float(setting("base_chance")) + float(setting("per_stock_gold")) * float(valuables(d))
	return clampf(c, 0.0, float(setting("max_chance"))) * (1.0 - deterrence(d))


## The chance the guards beat a raid off outright when the heir trusts them: 0 with no guards.
static func beat_off_chance(d: GameDynasty) -> float:
	return GameRanch.guard_cut(d) / float(GameRanch.data()["work"]["guard_cut_max"]) * float(setting("beat_off_max"))


## Whether this kind of raid has anything to take now.
static func applicable(d: GameDynasty, kind: String) -> bool:
	var takes := str(data()["kinds"][kind]["takes"])
	if takes == "gold":
		return d.heir != null and d.heir.gold > 0
	if takes == "item":
		return d.heir != null and not d.heir.inventory.is_empty()
	return not d.roster.is_empty()


## Time passes: for each whole year the world clock crossed, a raid may come. At most one is started, and none while
## an event is waiting. `year_end` is the world's year now (a parameter so a test can set it).
static func on_years(d: GameDynasty, years: float, msgs: Array, year_end: float = -1.0) -> void:
	if not has_target(d) or years <= 0.0 or d.state != "life":
		return
	var end := d.world.year if year_end < 0.0 else year_end
	for y in range(int(floor(end - years)) + 1, int(floor(end)) + 1):
		if d.has_pending_event():
			return
		var r := RandomNumberGenerator.new()
		r.seed = hash([d.seed_value, "raid", y])
		if r.randf() >= chance(d):
			continue
		var kind := _pick(d, r)
		if kind == "":
			continue
		var ev_id := str(data()["kinds"][kind]["event"])
		if not GameEvents.begin(d, ev_id, "raid"):
			continue
		d.flags[str(setting("counter_flag"))] = int(d.flags.get(str(setting("counter_flag")), 0)) + 1
		var line := text("comes", {"title": GameEvents.event_title(d)})
		d._say(line)
		msgs.append(line)
		return


## Which kind of raid comes: by weight, among those that have something to take.
static func _pick(d: GameDynasty, r: RandomNumberGenerator) -> String:
	var ids: Array = kinds().filter(func(k): return applicable(d, str(k)))
	var total := 0.0
	for k in ids:
		total += float(data()["kinds"][k]["weight"])
	if total <= 0.0:
		return ""
	var roll := r.randf() * total
	for k in ids:
		roll -= float(data()["kinds"][k]["weight"])
		if roll < 0.0:
			return str(k)
	return str(ids.back())


## The heir trusts the guards (an event outcome's `defend`): they beat the raid off, or it takes what it came for.
## Keyed on the seed, the generation and how many raids there have been. Returns [{t, k}] for the event screen.
static func defend(d: GameDynasty, kind: String) -> Array:
	if d.state != "life" or not data()["kinds"].has(kind):
		return []
	var k: Dictionary = data()["kinds"][kind]
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "defend", d.gen, int(d.flags.get(str(setting("counter_flag")), 0)), kind])
	var who := str(k["who"])
	if r.randf() < beat_off_chance(d):
		return _said(text("beaten_off", {"who": who}), "good")
	match str(k["takes"]):
		"gold":
			if d.heir.gold <= 0:
				return _said(text("nothing_to_take"), "info")
			var want := maxi(int(setting("steal_gold_min")), int(round(float(d.heir.gold) * float(setting("steal_gold_share")))))
			var lost := mini(GameRanch.guarded_loss(d, want), d.heir.gold)
			d.heir.gold -= lost
			var saved := maxi(0, mini(want, d.heir.gold + lost) - lost)
			return _said(text("stole_gold_saved" if saved > 0 else "stole_gold", {"gold": GameText.num(lost), "saved": GameText.num(saved)}), "bad")
		"item":
			if d.heir.inventory.is_empty():
				return _said(text("nothing_carried"), "info")
			var taken: String = str(d.heir.inventory[r.randi() % d.heir.inventory.size()])
			d.heir.inventory.erase(taken)
			return _said(text("stole_item", {"item": GameItems.item_name(taken)}), "bad")
		_:
			if d.roster.is_empty():
				return _said(text("no_stock"), "info")
			var e: Dictionary = d.roster[r.randi() % d.roster.size()]
			var def := GameCombat.creature_def(str(e["species"]))
			var vals := {"name": str(e["name"]), "species": str(def.get("name", e["species"])).to_lower()}
			d.roster.erase(e)
			return _said(text("stole_animal" if str(k["takes"]) == "animal" else "killed_animal", vals), "bad")


static func _said(line: String, kind: String) -> Array:
	return [{"t": line, "k": kind}]


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "kinds", "text"]:
		if not dat.has(k):
			bad.append("raids.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["base_chance", "per_stock_gold", "max_chance", "deter_share", "beat_off_max", "steal_gold_share", "steal_gold_min", "counter_flag", "house_value_share"]:
		if not s.has(k):
			bad.append("raids.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["base_chance", "max_chance", "deter_share", "beat_off_max", "steal_gold_share", "house_value_share"]:
		if float(s[k]) < 0.0 or float(s[k]) > 1.0:
			bad.append("raids.json: %s must be between 0 and 1" % k)
	if float(s["max_chance"]) < float(s["base_chance"]):
		bad.append("raids.json: max_chance must be at least base_chance")
	if float(s["per_stock_gold"]) < 0.0 or float(s["steal_gold_min"]) < 0.0:
		bad.append("raids.json: per_stock_gold and steal_gold_min must be 0 or more")
	if dat["kinds"].is_empty():
		bad.append("raids.json: no kinds of raid")
	for kind in dat["kinds"]:
		var k: Dictionary = dat["kinds"][kind]
		for key in ["event", "weight", "takes", "who"]:
			if not k.has(key):
				bad.append("raids.json: kind '%s' has no %s" % [kind, key])
		if k.has("takes") and str(k["takes"]) not in ["gold", "animal", "kill", "item"]:
			bad.append("raids.json: kind '%s' takes '%s', which is not gold, animal, kill or item" % [kind, k["takes"]])
		if k.has("weight") and float(k["weight"]) <= 0.0:
			bad.append("raids.json: kind '%s' needs a positive weight" % kind)
		if k.has("event"):
			var ev := GameEvents.event_def(str(k["event"]))
			if ev.is_empty():
				bad.append("raids.json: kind '%s' names the event '%s', which does not exist" % [kind, k["event"]])
			elif not ev.get("raid", false):
				bad.append("raids.json: the event '%s' is not marked raid (it would turn up while exploring)" % k["event"])
	for ev in GameData.events:
		if ev.get("raid", false):
			var used := false
			for kind in dat["kinds"]:
				if str(dat["kinds"][kind].get("event", "")) == str(ev["id"]):
					used = true
			if not used:
				bad.append("raids.json: the raid event '%s' is used by no kind" % ev["id"])
	for key in ["comes", "beaten_off", "stole_gold", "stole_gold_saved", "nothing_to_take", "stole_animal", "killed_animal", "no_stock", "stole_item", "nothing_carried"]:
		if not dat["text"].has(key):
			bad.append("raids.json: text.%s is missing" % key)
	return bad
