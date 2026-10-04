## Companions hired for a fee who travel and fight beside the heir. Each companion is built
## like an heir (a GameHeir of their race and class, without traits) and is always rebuilt
## to the current heir's level and generation, so they keep pace across the whole dynasty.
class_name GameParty
extends RefCounted

# [{id, name, hp, mp, level, gen, due, battles, hired_gen}] - due is upkeep owed but not yet paid.
var members: Array = []
# companion id -> {name, status, gen, first_gen, battles, fallen: [names]}
# status: "serving", "dismissed" (rehire free), "left" (walked out unpaid), "fallen" (died for the house)
var history: Dictionary = {}

static var _taverns: Dictionary = {}


# ---------------------------------------------------------------- data

static func def(id: String) -> Dictionary:
	GameData.load_all()
	for c in GameData.companions:
		if c["id"] == id:
			return c
	return {}


static func tavern(place_id: String) -> Dictionary:
	if _taverns.is_empty():
		var raw = GameData.load_json("res://data/companions/companions.json")
		if typeof(raw) == TYPE_DICTIONARY:
			_taverns = raw.get("taverns", {})
	return _taverns.get(place_id, {})


static func max_size() -> int:
	return int(GameData.bal("party_max_size"))


## A companion's fighting body at a given level and generation (no hp/mp state applied).
static func build_unit(id: String, level: int, gen: int, name: String = "") -> GameHeir:
	var c := def(id)
	var u := GameHeir.new()
	u.name = name if name != "" else str(c.get("name", id))
	u.class_id = c.get("class", "warrior")
	u.race_id = c.get("race", "human")
	u.gen = gen
	u.level = maxi(1, level)
	# Hirelings fight at a share of an heir's strength; the companion's own bonus comes on top.
	var bonus: Dictionary = (c.get("bonus", {}) as Dictionary).duplicate()
	var power := float(GameData.bal("companion_power"))
	bonus["all_stats"] = (1.0 + float(bonus.get("all_stats", 0.0))) * power - 1.0
	bonus["hp"] = float(bonus.get("hp", 0.0)) + power - 1.0
	u.archetype_bonus = bonus
	u.lifespan = u.compute_lifespan()
	u.full_heal()
	u.set_meta("companion", id)
	return u


## The member's current fighting body, with their wounds.
func unit(d: GameDynasty, m: Dictionary) -> GameHeir:
	_sync_member(d, m)
	var u := build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"])
	u.hp = clampi(int(m["hp"]), 0, u.max_hp())
	u.mp = clampi(int(m["mp"]), 0, u.max_mp())
	return u


func fee(d: GameDynasty, id: String) -> int:
	if is_free_rehire(id):
		return 0
	return maxi(1, int(round(float(def(id).get("fee", 0)) * GameData.enemy_scale(d.gen))))


func upkeep(d: GameDynasty, id: String) -> int:
	return maxi(1, int(round(float(def(id).get("upkeep", 0)) * GameData.enemy_scale(d.gen))))


func upkeep_total(d: GameDynasty) -> int:
	var t := 0
	for m in members:
		t += upkeep(d, m["id"])
	return t


func is_free_rehire(id: String) -> bool:
	return history.has(id) and history[id]["status"] == "dismissed"


func display_name(id: String) -> String:
	if history.has(id):
		return history[id]["name"]
	return def(id).get("name", id)


func member(id: String) -> Dictionary:
	for m in members:
		if m["id"] == id:
			return m
	return {}


func has_member(id: String) -> bool:
	return not member(id).is_empty()


# ---------------------------------------------------------------- availability

## Why this companion cannot be hired by the current heir ("" if they can be).
func locked_reason(d: GameDynasty, id: String) -> String:
	var c := def(id)
	var req: Dictionary = c.get("requires", {})
	if history.has(id) and history[id]["status"] == "fallen":
		var back := int(history[id]["gen"]) + int(GameData.bal("companion_kin_gens"))
		if d.gen < back:
			return "In mourning until generation %d." % back
	if d.gen < int(req.get("min_gen", 1)):
		return "Not in this age."
	for f in req.get("flags", []):
		if not d.flags.has(f):
			return "Waiting on a deed your house has not done."
	for place_id in req.get("visited", []):
		if place_id not in d.world.visited:
			return "Talks only to those who have walked %s." % GameWorld.place(place_id).get("name", place_id)
	if d.heir.level < int(req.get("min_level", 1)):
		return "Wants an heir of level %d." % int(req.get("min_level", 1))
	return ""


## Companions who drink at this tavern and would hear an offer (met or not).
func at_tavern(_d: GameDynasty, place_id: String) -> Array:
	var out: Array = []
	for c in GameData.companions:
		if place_id in c.get("where", []) and not has_member(c["id"]):
			out.append(c["id"])
	return out


func available_here(d: GameDynasty) -> Array:
	if not d.world.has_service("tavern"):
		return []
	return at_tavern(d, d.world.location).filter(func(id): return locked_reason(d, id) == "")


## Why the heir cannot hire this companion right now ("" if they can).
func hire_block(d: GameDynasty, id: String) -> String:
	if d.state != "life":
		return "No one hires in mourning."
	if has_member(id):
		return "%s already rides with %s." % [display_name(id), d.heir.name]
	if not d.world.has_service("tavern") or id not in at_tavern(d, d.world.location):
		return "%s does not drink here." % display_name(id)
	var lock := locked_reason(d, id)
	if lock != "":
		return lock
	if members.size() >= max_size():
		return "The party is full (%d)." % max_size()
	if d.heir.gold < fee(d, id):
		return "Not enough gold (%d needed)." % fee(d, id)
	return ""


# ---------------------------------------------------------------- hire / dismiss

func hire(d: GameDynasty, id: String) -> String:
	var why := hire_block(d, id)
	if why != "":
		return why
	var price := fee(d, id)
	var returning := is_free_rehire(id)
	d.heir.gold -= price
	var nm := display_name(id)
	var u := build_unit(id, d.heir.level, d.gen, nm)
	members.append({"id": id, "name": nm, "hp": u.hp, "mp": u.mp, "level": u.level, "gen": d.gen,
		"due": 0.0, "battles": 0, "hired_gen": d.gen})
	var rec: Dictionary = history.get(id, {"first_gen": d.gen, "battles": 0, "fallen": []})
	rec["name"] = nm
	rec["status"] = "serving"
	rec["gen"] = d.gen
	history[id] = rec
	var c := def(id)
	var text: String
	if returning:
		text = "%s comes back to House %s's service and asks no fee." % [nm, d.dynasty_name]
	else:
		text = "%s, %s %s, joins %s for %d gold (upkeep %d a year)." % [nm, GameData.races[c["race"]]["name"], GameData.classes[c["class"]]["name"], d.heir.name, price, upkeep(d, id)]
	d._say(text)
	return text


func dismiss(d: GameDynasty, id: String) -> String:
	var m := member(id)
	if m.is_empty():
		return "No such companion."
	_settle(d, m)
	_part(d, m, "dismissed")
	var home: Array = def(id).get("where", [])
	var place: String = GameWorld.place(home[0]).get("name", "home") if not home.is_empty() else "home"
	var text := "%s is paid off and heads back to %s. They would come again without a fee." % [m["name"], place]
	d._say(text)
	return text


## Pay whatever whole gold of upkeep is owed; returns false if the heir cannot.
func _settle(d: GameDynasty, m: Dictionary) -> bool:
	var owed := int(floor(float(m["due"])))
	if owed <= 0:
		return true
	if d.heir.gold < owed:
		return false
	d.heir.gold -= owed
	m["due"] = float(m["due"]) - float(owed)
	return true


## A member leaves the party; the house's record keeps their battles and how they parted.
func _part(d: GameDynasty, m: Dictionary, status: String) -> void:
	members.erase(m)
	var rec: Dictionary = history.get(m["id"], {"name": m["name"], "first_gen": d.gen, "battles": 0, "fallen": []})
	rec["status"] = status
	rec["gen"] = d.gen
	rec["battles"] = int(rec.get("battles", 0)) + int(m["battles"])
	history[m["id"]] = rec


# ---------------------------------------------------------------- keeping pace

## Rebuild a member to the heir's level and generation, keeping the same share of health.
func _sync_member(d: GameDynasty, m: Dictionary) -> void:
	if int(m["level"]) == d.heir.level and int(m["gen"]) == d.gen:
		return
	var old := build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"])
	var neu := build_unit(m["id"], d.heir.level, d.gen, m["name"])
	m["hp"] = clampi(int(round(float(m["hp"]) * float(neu.max_hp()) / float(old.max_hp()))), 1, neu.max_hp())
	m["mp"] = clampi(int(round(float(m["mp"]) * float(neu.max_mp()) / maxf(1.0, float(old.max_mp())))), 0, neu.max_mp())
	m["level"] = d.heir.level
	m["gen"] = d.gen


func sync(d: GameDynasty) -> void:
	for m in members:
		_sync_member(d, m)


## The heir rests: companions recover fully too.
func rest(d: GameDynasty) -> void:
	sync(d)
	for m in members:
		var u := build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"])
		m["hp"] = u.max_hp()
		m["mp"] = u.max_mp()


## Upkeep and loyalty as years pass; append messages to `msgs`.
func on_years(d: GameDynasty, years: float, msgs: Array) -> void:
	sync(d)
	var mend := float(GameData.bal("companion_mend_per_year")) * years
	for m in members.duplicate():
		m["due"] = float(m["due"]) + float(upkeep(d, m["id"])) * years
		if not _settle(d, m):
			_part(d, m, "left")
			var text := "Wages go unpaid and %s walks out on %s. Winning them back will cost the full fee." % [m["name"], d.heir.name]
			d._say(text)
			msgs.append(text)
			continue
		var u := build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"])
		m["hp"] = mini(u.max_hp(), int(m["hp"]) + int(ceil(float(u.max_hp()) * mend)))
		m["mp"] = mini(u.max_mp(), int(m["mp"]) + int(ceil(float(u.max_mp()) * mend)))


## The family's companions stay on with the new heir; append messages to `msgs`.
func on_succession(d: GameDynasty, msgs: Array) -> void:
	if members.is_empty():
		return
	rest(d)
	var names: Array = members.map(func(m): return m["name"])
	var one := names.size() == 1
	msgs.append("%s stay%s with the family and swear%s to serve %s." % [" and ".join(names), "s" if one else "", "s" if one else "", d.heir.name])


# ---------------------------------------------------------------- battle

## Allies for a new battle (see GameBattle.allies). Each carries meta "companion" = id.
func battle_allies(d: GameDynasty) -> Array:
	var out: Array = []
	for m in members:
		var u := unit(d, m)
		if u.hp > 0:
			out.append(u)
	return out


## After a battle: write wounds back; the knocked-out die or are carried off. Says and returns messages.
func after_battle(d: GameDynasty, b: GameBattle) -> Array:
	var msgs: Array = []
	for u in b.allies:
		var m := member(str(u.get_meta("companion", "")))
		if m.is_empty():
			continue
		m["battles"] = int(m["battles"]) + 1
		m["mp"] = u.mp
		if u.hp > 0:
			m["hp"] = u.hp
			continue
		if d.rng.randf() < float(GameData.bal("companion_death_chance")):
			msgs.append(_fall(d, m))
		else:
			m["hp"] = maxi(1, int(round(float(u.max_hp()) * float(GameData.bal("companion_ko_recover_hp")))))
			msgs.append("%s is carried from the field, battered but breathing." % m["name"])
	for t in msgs:
		d._say(t)
	return msgs


func _fall(d: GameDynasty, m: Dictionary) -> String:
	var id: String = m["id"]
	_settle(d, m)
	_part(d, m, "fallen")
	var rec: Dictionary = history[id]
	var fallen: Array = rec.get("fallen", [])
	fallen.append(m["name"])
	rec["fallen"] = fallen
	var pattern: String = def(id).get("successor", "{given}")
	rec["name"] = pattern.replace("{given}", GameInheritance.random_name(d.rng))
	return "%s falls in the fighting and does not rise. House %s will remember." % [m["name"], d.dynasty_name]


# ---------------------------------------------------------------- autopilot

## Town errands the autopilot runs between actions (no time passes).
static func bot_tick(d: GameDynasty) -> void:
	var p := d.party
	if d.state != "life":
		return
	# Let the dearest go before wages fall due that cannot be paid.
	while not p.members.is_empty() and d.heir.gold < p.upkeep_total(d) * 2:
		var dear: Dictionary = p.members[0]
		for m in p.members:
			if p.upkeep(d, m["id"]) > p.upkeep(d, dear["id"]):
				dear = m
		p.dismiss(d, dear["id"])
	if p.members.size() >= max_size():
		return
	var best := ""
	for id in p.available_here(d):
		if best == "" or p.fee(d, id) < p.fee(d, best):
			best = id
	if best == "":
		return
	var years := float(GameData.bal("companion_bot_reserve_years"))
	var reserve := d.potion_price() * 3 + int(float(p.upkeep_total(d) + p.upkeep(d, best)) * years)
	if d.heir.gold >= p.fee(d, best) + reserve:
		p.hire(d, best)


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {"members": members, "history": history}


static func from_dict(v: Dictionary) -> GameParty:
	var p := GameParty.new()
	for raw in v.get("members", []):
		if typeof(raw) != TYPE_DICTIONARY or def(str(raw.get("id", ""))).is_empty():
			continue
		var id: String = raw["id"]
		p.members.append({
			"id": id, "name": str(raw.get("name", def(id)["name"])), "hp": int(raw.get("hp", 1)), "mp": int(raw.get("mp", 0)),
			"level": int(raw.get("level", 1)), "gen": int(raw.get("gen", 1)), "due": float(raw.get("due", 0.0)),
			"battles": int(raw.get("battles", 0)), "hired_gen": int(raw.get("hired_gen", 1)),
		})
	var h: Dictionary = v.get("history", {})
	for id in h:
		var r: Dictionary = h[id]
		p.history[id] = {
			"name": str(r.get("name", def(id).get("name", id))), "status": str(r.get("status", "dismissed")),
			"gen": int(r.get("gen", 1)), "first_gen": int(r.get("first_gen", 1)), "battles": int(r.get("battles", 0)),
			"fallen": Array(r.get("fallen", [])),
		}
	return p
