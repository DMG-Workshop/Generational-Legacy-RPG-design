## Companions hired for a fee who travel and fight beside the heir. Each companion is built
## like an heir (a GameHeir of their race and class, without traits) and is always rebuilt
## to the current heir's level and generation, so they keep pace across the whole dynasty.
## Companions age with the world calendar, grow old, and die or retire, in service or not.
class_name GameParty
extends RefCounted

# [{id, name, hp, mp, level, gen, due, battles, hired_gen}] - due is upkeep owed but not yet paid.
var members: Array = []
# companion id -> {name, status, gen, first_gen, battles, fallen: [names], line, past: [...],
#                  born?, rolled?, back_year?}
# status: "serving", "dismissed" (rehire free), "left" (walked out unpaid), "fallen" (died for the house),
#         "dead" (old age), "retired". name, born and rolled belong to whoever holds the role now;
# born (a world year) is set once that person is first hired. line counts the holders before them,
# past keeps the last few: {name, end: fell|died|retired, age, year, gen, served}.
var history: Dictionary = {}

static var _taverns: Dictionary = {}
static var _settings: Dictionary = {}


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


## Ageing tunables from the "settings" object in companions.json.
static func setting(key: String) -> Variant:
	if _settings.is_empty():
		var raw = GameData.load_json("res://data/companions/companions.json")
		if typeof(raw) == TYPE_DICTIONARY:
			_settings = raw.get("settings", {})
	return _settings[key]


static func max_size() -> int:
	return int(GameData.bal("party_max_size"))


## A companion's fighting body at a given level and generation (no hp/mp state applied).
## Hirelings have `companion_power` of an untrained heir's stats and health at the same level,
## generation, race and class; the companion's own data bonus comes on top. `frailty` is the
## share of that power old age has taken.
static func build_unit(id: String, level: int, gen: int, name: String = "", frailty: float = 0.0) -> GameHeir:
	var c := def(id)
	var u := _plain_body(c, level, gen)
	u.name = name if name != "" else str(c.get("name", id))
	var power := float(GameData.bal("companion_power")) * (1.0 - clampf(frailty, 0.0, 0.95))
	var bonus: Dictionary = (c.get("bonus", {}) as Dictionary).duplicate()
	var hp_share := power * (1.0 + float(bonus.get("hp", 0.0)))
	bonus["all_stats"] = (1.0 + float(bonus.get("all_stats", 0.0))) * power - 1.0
	bonus["hp"] = 0.0
	u.archetype_bonus = bonus
	# VIT feeds health too, so weaker stats alone would shrink health by power squared at high
	# levels; set the health bonus so the share holds at level 1 and level 5000 alike.
	var plain_hp := float(_plain_body(c, level, gen).max_hp())
	var mult := 1.0 + u.trait_total("max_hp")
	bonus["hp"] = mult * (hp_share * plain_hp / float(u.max_hp()) - 1.0)
	u.lifespan = u.compute_lifespan()
	u.full_heal()
	u.set_meta("companion", id)
	return u


static func _plain_body(c: Dictionary, level: int, gen: int) -> GameHeir:
	var u := GameHeir.new()
	u.class_id = c.get("class", "warrior")
	u.race_id = c.get("race", "human")
	u.gen = gen
	u.level = maxi(1, level)
	return u


## The member's current fighting body, with their wounds.
func unit(d: GameDynasty, m: Dictionary) -> GameHeir:
	_sync_member(d, m)
	var u := _body(d, m)
	u.hp = clampi(int(m["hp"]), 0, u.max_hp())
	u.mp = clampi(int(m["mp"]), 0, u.max_mp())
	return u


## The member's body at their recorded level and generation, as old as they are now, unwounded.
func _body(d: GameDynasty, m: Dictionary) -> GameHeir:
	return build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"], decline(d, m["id"]))


## What whoever holds this role now would bring to the current heir (for the tavern).
func offer_unit(d: GameDynasty, id: String) -> GameHeir:
	return build_unit(id, d.heir.level, d.gen, display_name(id), decline(d, id))


# ---------------------------------------------------------------- age

## A fraction in [0, 1) fixed for this house, role, holder and purpose: no dice are thrown, so
## an age or lifespan reads the same before a hire, after it and after a reload.
static func _fixed(d: GameDynasty, id: String, line: int, what: String) -> float:
	return float(("%d:%s:%d:%s" % [d.seed_value, id, line, what]).hash() & 0xFFFFFF) / 16777216.0


func line_of(id: String) -> int:
	return int(history.get(id, {}).get("line", 0))


## The age whoever holds the role now is first hired at (data age, or the race's adult age plus a few years).
func hire_age(d: GameDynasty, id: String) -> float:
	var c := def(id)
	var n := line_of(id)
	var span: Variant = c.get("successor_age", c.get("age")) if n > 0 else c.get("age")
	if span == null:
		var adult := float(GameData.races.get(c.get("race", "human"), {}).get("start_age", 18))
		var extra: Array = setting("default_age_after_adult")
		span = [adult + float(extra[0]), adult + float(extra[1])]
	var lo := float(span[0]) if typeof(span) == TYPE_ARRAY else float(span)
	var hi := float(span[1]) if typeof(span) == TYPE_ARRAY else float(span)
	return float(roundi(lerpf(lo, hi, _fixed(d, id, n, "age"))))


## Expected lifespan (the median age of death) of whoever holds the role now: the data's own, or
## the race's, shifted a little for each person.
func lifespan(d: GameDynasty, id: String) -> float:
	var c := def(id)
	var base := float(c["lifespan"]) if c.has("lifespan") else _plain_body(c, 1, 1).compute_lifespan()
	var spread := float(setting("lifespan_spread"))
	return base * (1.0 + spread * (2.0 * _fixed(d, id, line_of(id), "span") - 1.0))


func old_age(d: GameDynasty, id: String) -> float:
	return lifespan(d, id) * float(setting("old_fraction"))


## Age now. Someone never hired is met at their hire age, whatever the year.
func age(d: GameDynasty, id: String) -> float:
	var rec: Dictionary = history.get(id, {})
	if rec.has("born"):
		return d.world.year - float(rec["born"])
	return hire_age(d, id)


func is_old(d: GameDynasty, id: String) -> bool:
	return age(d, id) >= old_age(d, id)


## Share of a companion's power old age has taken: grows with each year past old age, capped.
func decline(d: GameDynasty, id: String) -> float:
	var span := lifespan(d, id)
	var past := age(d, id) - span * float(setting("old_fraction"))
	if past <= 0.0:
		return 0.0
	return minf(float(setting("decline_cap")), float(setting("decline_per_lifespan")) * past / span)


## "Age 34 of ~83" with old age and its toll when it has come.
func age_text(d: GameDynasty, id: String) -> String:
	var text := "Age %d of ~%d" % [int(age(d, id)), int(round(lifespan(d, id)))]
	if is_old(d, id):
		text += ", " + old_text(d, id)
	return text


## "old" and, once it shows, how much weaker: "old: 12% weaker".
func old_text(d: GameDynasty, id: String) -> String:
	var pct := int(round(decline(d, id) * 100.0))
	return "old" if pct == 0 else "old: %d%% weaker" % pct


func _place_name(id: String) -> String:
	var c := def(id)
	var home: Array = c.get("where", [])
	var place_id: String = c.get("retires_to", home[0] if not home.is_empty() else "")
	return GameWorld.place(place_id).get("name", "home")


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
	var status: String = history.get(id, {}).get("status", "")
	if status == "fallen":
		var back := int(history[id]["gen"]) + int(GameData.bal("companion_kin_gens"))
		if d.gen < back:
			return "In mourning until generation %s." % GameText.num(back)
	if status in ["dead", "retired"]:
		if not c.has("successor"):
			return "No one has come to take up the work."
		var year := float(history[id].get("back_year", 0.0))
		if d.world.year < year:
			return "%s may take up the work from year %s." % [history[id]["name"], GameText.num(int(year) + 1)]
	if d.era_gen() < int(req.get("min_gen", 1)):
		return "Not yet in this Age."
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
		return "Not enough gold (%s needed)." % GameText.num(fee(d, id))
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
	var rec: Dictionary = history.get(id, {"first_gen": d.gen, "battles": 0, "fallen": [], "line": 0, "past": []})
	if not rec.has("born"):
		rec["born"] = d.world.year - hire_age(d, id)
		rec["rolled"] = d.world.year
	rec["name"] = nm
	rec["status"] = "serving"
	rec["gen"] = d.gen
	history[id] = rec
	var u := offer_unit(d, id)
	members.append({"id": id, "name": nm, "hp": u.hp, "mp": u.mp, "level": u.level, "gen": d.gen,
		"due": 0.0, "battles": 0, "hired_gen": d.gen})
	var c := def(id)
	var text: String
	if returning and is_old(d, id):
		text = "%s, %d now and slower than before, comes back to House %s's service and asks no fee." % [nm, int(age(d, id)), d.dynasty_name]
	elif returning:
		text = "%s comes back to House %s's service and asks no fee." % [nm, d.dynasty_name]
	else:
		text = "%s, %s %s, joins %s for %s gold (upkeep %s a year)." % [nm, GameData.races[c["race"]]["name"], GameData.classes[c["class"]]["name"], d.heir.name, GameText.num(price), GameText.num(upkeep(d, id))]
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
	var rec: Dictionary = history.get(m["id"], {"name": m["name"], "first_gen": d.gen, "battles": 0, "fallen": [], "line": 0, "past": []})
	rec["status"] = status
	rec["gen"] = d.gen
	rec["battles"] = int(rec.get("battles", 0)) + int(m["battles"])
	history[m["id"]] = rec


# ---------------------------------------------------------------- keeping pace

## Rebuild a member to the heir's level and generation, keeping the same share of health.
func _sync_member(d: GameDynasty, m: Dictionary) -> void:
	if int(m["level"]) == d.heir.level and int(m["gen"]) == d.gen:
		return
	var frail := decline(d, m["id"])
	var old := build_unit(m["id"], int(m["level"]), int(m["gen"]), m["name"], frail)
	var neu := build_unit(m["id"], d.heir.level, d.gen, m["name"], frail)
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
		var u := _body(d, m)
		m["hp"] = u.max_hp()
		m["mp"] = u.max_mp()


## Age, upkeep and loyalty as years pass; append messages to `msgs`.
func on_years(d: GameDynasty, years: float, msgs: Array) -> void:
	sync(d)
	_grow_old(d, msgs)
	var mend := float(GameData.bal("companion_mend_per_year")) * years
	for m in members.duplicate():
		m["due"] = float(m["due"]) + float(upkeep(d, m["id"])) * years
		if not _settle(d, m):
			_part(d, m, "left")
			var text := "Wages go unpaid and %s walks out on %s. Winning them back will cost the full fee." % [m["name"], d.heir.name]
			d._say(text)
			msgs.append(text)
			continue
		var u := _body(d, m)
		m["hp"] = mini(u.max_hp(), int(m["hp"]) + int(ceil(float(u.max_hp()) * mend)))
		m["mp"] = mini(u.max_mp(), int(m["mp"]) + int(ceil(float(u.max_mp()) * mend)))


## Everyone the house has hired grows older with the calendar, in its service or not. Past old
## age each year may bring death (the same odds an heir faces) or, failing that, retirement.
func _grow_old(d: GameDynasty, msgs: Array) -> void:
	var ids := history.keys()
	ids.sort()   # a loaded save lists records in another order; the dice must fall the same way
	for id in ids:
		var rec: Dictionary = history[id]
		if not rec.has("born"):
			continue
		var born := float(rec["born"])
		var was := float(rec.get("rolled", d.world.year)) - born
		var now := d.world.year - born
		rec["rolled"] = d.world.year
		var old := old_age(d, id)
		var from := maxf(was, old)
		if now > from:
			var body := GameHeir.new()
			body.lifespan = lifespan(d, id)
			if d.rng.randf() < body.old_age_death_chance(from, now):
				_end(d, id, "died", msgs)
				continue
			if d.rng.randf() < 1.0 - exp(-float(setting("retire_per_lifespan")) * (now - from) / body.lifespan):
				_end(d, id, "retired", msgs)
				continue
		if was < old and now >= old and has_member(id):
			var text := "%s, %d now, is growing old. Each year will take a little from their strength." % [rec["name"], int(now)]
			d._say(text)
			msgs.append(text)


## Whoever holds the role dies of old age or retires. In service, the house says goodbye; away
## from it, word reaches the heir. A successor in the data takes up the work after a few years.
func _end(d: GameDynasty, id: String, how: String, msgs: Array) -> void:
	var rec: Dictionary = history[id]
	var nm: String = rec["name"]
	var years := int(age(d, id))
	var m := member(id)
	var serving := not m.is_empty()
	var text: String
	if serving:
		_settle(d, m)
		_part(d, m, "dead" if how == "died" else "retired")
		if how == "died":
			text = "%s dies of old age at %d, still sworn to House %s." % [nm, years, d.dynasty_name]
		else:
			var line: String = def(id).get("farewell", setting("farewell"))
			text = line.format({"name": nm, "heir": d.heir.name, "place": _place_name(id), "age": years})
	else:
		rec["status"] = "dead" if how == "died" else "retired"
		rec["gen"] = d.gen
		if how == "died":
			text = "Word reaches %s: %s, who once rode with House %s, has died of old age at %d." % [d.heir.name, nm, d.dynasty_name, years]
		else:
			text = "Word reaches %s: %s, who once rode with House %s, has retired to %s at %d." % [d.heir.name, nm, d.dynasty_name, _place_name(id), years]
	_close_line(d, id, {"name": nm, "end": how, "age": years, "year": int(d.world.year) + 1, "gen": d.gen, "served": serving})
	if def(id).has("successor"):
		rec["name"] = str(def(id)["successor"]).replace("{given}", GameInheritance.random_name(d.rng))
		rec["back_year"] = d.world.year + float(setting("successor_wait_years"))
	d._say(text)
	msgs.append(text)


## The holder's story is over: keep it in the record and clear their age and battles for whoever
## comes next.
func _close_line(_d: GameDynasty, id: String, entry: Dictionary) -> void:
	var rec: Dictionary = history[id]
	entry["battles"] = int(rec.get("battles", 0))
	rec["battles"] = 0
	var past: Array = rec.get("past", [])
	past.append(entry)
	rec["past"] = past.slice(maxi(0, past.size() - int(setting("past_kept"))))
	rec["line"] = int(rec.get("line", 0)) + 1
	rec.erase("born")
	rec.erase("rolled")
	rec.erase("back_year")


## The family's companions stay on with the new heir; append messages to `msgs`.
func on_succession(d: GameDynasty, msgs: Array) -> void:
	if members.is_empty():
		return
	rest(d)
	var names: Array = members.map(func(m): return m["name"])
	var one := names.size() == 1
	msgs.append("%s stay%s with the family and swear%s to serve %s." % [names_text(names), "s" if one else "", "s" if one else "", d.heir.name])


## "Bren", "Bren and Maddy", "Bren, Maddy and Oriel".
static func names_text(names: Array) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, names.size() - 1))), names.back()]


# ---------------------------------------------------------------- battle

## Allies for a new battle (see GameBattle.allies). Each carries meta "companion" = id.
func battle_allies(d: GameDynasty) -> Array:
	var out: Array = []
	for m in members:
		var u := unit(d, m)
		if u.hp > 0:
			out.append(u)
	return out


## After a battle: write wounds back; the knocked-out die or are carried off. Returns the
## messages for the caller to journal after the battle's own result.
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
	return msgs


func _fall(d: GameDynasty, m: Dictionary) -> String:
	var id: String = m["id"]
	var years := int(age(d, id))
	_settle(d, m)
	_part(d, m, "fallen")
	var rec: Dictionary = history[id]
	var fallen: Array = rec.get("fallen", [])
	fallen.append(m["name"])
	rec["fallen"] = _recent_fallen(fallen)
	_close_line(d, id, {"name": m["name"], "end": "fell", "age": years, "year": int(d.world.year) + 1, "gen": d.gen, "served": true})
	var pattern: String = def(id).get("successor", "{given}")
	rec["name"] = pattern.replace("{given}", GameInheritance.random_name(d.rng))
	return "%s falls in the fighting and does not rise. House %s will remember." % [m["name"], d.dynasty_name]


## The names of the last few who fell in a role; `line` still counts every holder.
static func _recent_fallen(fallen: Array) -> Array:
	return fallen.slice(maxi(0, fallen.size() - int(GameAges.setting("party_fallen_kept"))))


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
	var pick := _bot_choice(d)
	if pick == "":
		return
	# Fill an empty place first. A full party swaps whoever has grown too frail to fight for
	# someone fresh, never taking the frail back. Away from a tavern a frail companion beats none.
	if p.members.size() >= max_size():
		var frail := ""
		for m in p.members:
			if p.decline(d, m["id"]) >= float(setting("bot_dismiss_decline")) and (frail == "" or p.decline(d, m["id"]) > p.decline(d, frail)):
				frail = m["id"]
		if frail == "":
			return
		p.dismiss(d, frail)
	p.hire(d, pick)


## The cheapest companion at this tavern the autopilot would hire now: unlocked, not frail, and
## affordable with a reserve for potions and years of wages kept. "" if none.
static func _bot_choice(d: GameDynasty) -> String:
	var p := d.party
	var best := ""
	for id in p.available_here(d):
		if p.decline(d, id) < float(setting("bot_dismiss_decline")) and (best == "" or p.fee(d, id) < p.fee(d, best)):
			best = id
	if best == "":
		return ""
	var years := float(GameData.bal("companion_bot_reserve_years"))
	var reserve := d.potion_price() * 3 + int(float(p.upkeep_total(d) + p.upkeep(d, best)) * years)
	return best if d.heir.gold >= p.fee(d, best) + reserve else ""


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {"members": members, "history": history}


## `d` (the dynasty being loaded, its seed and world already set) lets a save from before
## companions aged give everyone met an age from the data.
static func from_dict(v: Dictionary, d: GameDynasty = null) -> GameParty:
	var p := GameParty.new()
	for raw in v.get("members", []):
		if typeof(raw) != TYPE_DICTIONARY or def(str(raw.get("id", ""))).is_empty() or p.has_member(str(raw["id"])):
			continue
		var id: String = str(raw["id"])
		p.members.append({
			"id": id, "name": str(raw.get("name", def(id)["name"])), "hp": int(raw.get("hp", 1)), "mp": int(raw.get("mp", 0)),
			"level": int(raw.get("level", 1)), "gen": int(raw.get("gen", 1)), "due": float(raw.get("due", 0.0)),
			"battles": int(raw.get("battles", 0)), "hired_gen": int(raw.get("hired_gen", 1)),
		})
	var h = v.get("history", {})
	if typeof(h) != TYPE_DICTIONARY:
		h = {}
	for id in h:
		if typeof(h[id]) != TYPE_DICTIONARY or def(str(id)).is_empty():
			continue
		var r: Dictionary = h[id]
		var rec := {
			"name": str(r.get("name", def(id)["name"])), "status": str(r.get("status", "dismissed")),
			"gen": int(r.get("gen", 1)), "first_gen": int(r.get("first_gen", 1)), "battles": int(r.get("battles", 0)),
			"fallen": Array(r.get("fallen", [])),
		}
		if rec["status"] == "fallen" and (rec["fallen"] as Array).is_empty():
			rec["fallen"] = [def(id)["name"]]
		# Before ageing, only the fallen had come before whoever holds the role now.
		rec["line"] = int(r.get("line", (rec["fallen"] as Array).size()))
		rec["fallen"] = _recent_fallen(rec["fallen"])
		rec["past"] = []
		for e in r.get("past", []):
			if typeof(e) == TYPE_DICTIONARY:
				rec["past"].append({"name": str(e.get("name", "")), "end": str(e.get("end", "died")), "age": int(e.get("age", 0)),
					"year": int(e.get("year", 1)), "gen": int(e.get("gen", 1)), "served": bool(e.get("served", true)),
					"battles": int(e.get("battles", 0))})
		for key in ["born", "rolled", "back_year"]:
			if r.has(key):
				rec[key] = float(r[key])
		p.history[str(id)] = rec
	if d != null:
		for m in p.members:
			if not p.history.has(m["id"]):
				p.history[m["id"]] = {"name": m["name"], "status": "serving", "gen": int(m["gen"]), "first_gen": int(m["hired_gen"]),
					"battles": 0, "fallen": [], "line": 0, "past": []}
		for id in p.history:
			var rec: Dictionary = p.history[id]
			if rec["status"] in ["serving", "dismissed", "left"] and not rec.has("born"):
				rec["born"] = d.world.year - p.hire_age(d, id)
				rec["rolled"] = d.world.year
	return p
