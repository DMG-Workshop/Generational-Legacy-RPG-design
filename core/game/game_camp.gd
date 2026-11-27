## Camping (data/world/camp.json, the item `tent`): pitch a camp on open ground, rest by its fire, cook one meal from the stores, and have it
## keep the dark off. The camp is `GameSandbox.camp` ({x, z, since (world-clock seconds), rests, cooks}, empty for none): runtime only, never saved,
## struck when the heir walks `strike_tiles` away or `seconds` go by. Pure rules over the sandbox and the dynasty: no dice of its own (a rest lets
## `rest_years` of a year pass through GameDynasty.pass_time, as any rest does), and the autopilot never meets a tent: the old shops do not stock it.
## Run: godot --headless --path . -s res://tests/test_game_camp.gd
class_name GameCamp
extends RefCounted

const PATH := "res://data/world/camp.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func item_id() -> String:
	return str(data()["settings"]["item"])


## The tents the heir has, loose in the pack or in a bag.
static func count(h: GameHeir) -> int:
	var n := h.inventory.count(item_id())
	for bag in h.bags:
		n += (h.bags[bag] as Array).count(item_id())
	return n


static func active(sb: GameSandbox) -> bool:
	return not sb.camp.is_empty()


static func point(sb: GameSandbox) -> Vector2:
	return Vector2(float(sb.camp["x"]) + 0.5, float(sb.camp["z"]) + 0.5) if active(sb) else Vector2(-1.0, -1.0)


## Whether the heir is close enough to the fire to use it.
static func at_fire(sb: GameSandbox) -> bool:
	return active(sb) and sb.space == "world" and sb.storey() == 0 and sb.heir_point().distance_to(point(sb)) <= setting("reach")


## The radius round the fire in which creatures start no fight: the night's, or the day's (0 for none).
static func radius(sb: GameSandbox) -> float:
	return setting("night_radius") if GameDay.is_night(sb.d) else setting("day_radius")


## Whether a point is inside the fire's keep-off ring.
static func covers(sb: GameSandbox, x: float, z: float) -> bool:
	return active(sb) and radius(sb) > 0.0 and Vector2(x, z).distance_to(point(sb)) <= radius(sb)


## Whether a creature agent (it stands inside the ring) starts no fight.
static func shields(sb: GameSandbox, a: Dictionary) -> bool:
	return covers(sb, float(a["x"]), float(a["z"]))


## Why a camp cannot be pitched here ("" when it can).
static func why_not(sb: GameSandbox) -> String:
	var h := sb.d.heir
	if sb.space != "world":
		return text("indoors")
	if sb.storey() > 0:
		return text("upstairs")
	if sb.d.battle != null:
		return text("fight")
	if active(sb):
		return text("already")
	if count(h) <= 0:
		return text("none", {"heir": h.name})
	if GameSmoke.covers(sb.d, sb.heir_point().x, sb.heir_point().y):
		return text("smoke")
	if near_place(sb.heir_point()):
		return text("town")
	return ""


## Whether a point is within `town_margin` tiles of a town's or dungeon's ground or a plot of the family's.
static func near_place(p: Vector2) -> bool:
	for a in GameWorldGen.zones():
		var r := GameRoads._ground(str(a["id"])) if str(a["type"]) != "plot" else float(a["radius"])
		if r > 0.0 and p.distance_to(Vector2(float(a["x"]), float(a["z"]))) <= r + setting("town_margin"):
			return true
	return GameWalls.cleared(floori(p.x), floori(p.y))


## Pitches a camp where the heir stands. {ok, text}.
static func pitch(sb: GameSandbox) -> Dictionary:
	var why := why_not(sb)
	if why != "":
		return {"ok": false, "text": why}
	sb.camp = {"x": sb.heir.x, "z": sb.heir.y, "since": sb.d.world_seconds, "rests": int(setting("rests")), "cooks": int(setting("cooks"))}
	var line := text("pitched", {"heir": sb.d.heir.name})
	if GameDay.is_night(sb.d) and setting("night_radius") > 0.0:
		line += " " + text("safe_night")
	sb.log.append({"kind": "camp", "text": line})
	return {"ok": true, "text": line}


## Takes the camp down. {ok, text}.
static func strike(sb: GameSandbox, far: bool = false) -> Dictionary:
	if not active(sb):
		return {"ok": false, "text": text("no_camp")}
	sb.camp = {}
	var line := text("struck_far", {"heir": sb.d.heir.name}) if far else text("struck")
	sb.log.append({"kind": "camp", "text": line})
	return {"ok": true, "text": line}


## Pitch if there is no camp, else strike it.
static func toggle(sb: GameSandbox) -> Dictionary:
	return strike(sb) if active(sb) else pitch(sb)


## One tick of the world clock: the camp burns out after `seconds` and is struck when the heir has walked far from it (on the open world).
static func tick(sb: GameSandbox) -> void:
	if not active(sb):
		return
	if sb.d.world_seconds - float(sb.camp["since"]) >= setting("seconds"):
		sb.camp = {}
		sb.log.append({"kind": "camp", "text": text("burned_out")})
		return
	if sb.space == "world" and sb.storey() == 0 and sb.heir_point().distance_to(point(sb)) > setting("strike_tiles"):
		strike(sb, true)


## The tile a fled fight ends on: the camp's, when it is within `escape_range` of the heir; (-1, -1) otherwise.
static func escape_tile(sb: GameSandbox) -> Vector2i:
	if active(sb) and sb.heir_point().distance_to(point(sb)) <= setting("escape_range"):
		return Vector2i(int(sb.camp["x"]), int(sb.camp["z"]))
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- the fire

static func _hurt(sb: GameSandbox) -> bool:
	var d := sb.d
	if d.heir.hp < d.heir.max_hp() or d.heir.mp < d.heir.max_mp():
		return true
	for m in d.party.members:
		var u: GameHeir = d.party._body(d, m)
		if int(m["hp"]) < u.max_hp() or int(m["mp"]) < u.max_mp():
			return true
	return false


## Rests at the camp: heals the heir and the party by a share of their health and mana, and lets a little of a year pass. {ok, text}.
static func rest(sb: GameSandbox) -> Dictionary:
	var d := sb.d
	if not at_fire(sb):
		return {"ok": false, "text": text("no_camp") if not active(sb) else text("far", {"n": int(round(sb.heir_point().distance_to(point(sb))))})}
	if d.battle != null:
		return {"ok": false, "text": text("fight")}
	if int(sb.camp["rests"]) <= 0:
		return {"ok": false, "text": text("no_rests")}
	if not _hurt(sb):
		return {"ok": false, "text": text("no_need")}
	sb.camp["rests"] = int(sb.camp["rests"]) - 1
	var h := d.heir
	var hs := setting("heal_share")
	var ms := setting("mp_share")
	h.hp = mini(h.max_hp(), h.hp + int(ceil(hs * float(h.max_hp()))))
	h.mp = mini(h.max_mp(), h.mp + int(ceil(ms * float(h.max_mp()))))
	d.party.sync(d)
	for m in d.party.members:
		var u: GameHeir = d.party._body(d, m)
		m["hp"] = mini(u.max_hp(), int(m["hp"]) + int(ceil(hs * float(u.max_hp()))))
		m["mp"] = mini(u.max_mp(), int(m["mp"]) + int(ceil(ms * float(u.max_mp()))))
	var msgs: Array = d.pass_time(setting("rest_years"), [text("rested", {"heir": h.name})])
	for m in msgs:
		sb.log.append({"kind": "camp", "text": str(m)})
	return {"ok": true, "text": str(msgs[0]) if not msgs.is_empty() else text("rested", {"heir": h.name})}


static func _cook_def() -> Dictionary:
	return data()["cook"]


## What is missing from the stores for the meal ("" when it can be cooked): the first material that falls short.
static func missing(d: GameDynasty) -> String:
	var takes: Dictionary = _cook_def()["takes"]
	for m in takes:
		if GameCraft.have(d, str(m)) < int(takes[m]):
			return GameMaterials.name_of(str(m)).to_lower() if GameMaterials.has(str(m)) else str(m)
	return ""


## Cooks the meal at the fire: takes its materials from the stores, mends the heir and lays the blessing on the next fight. {ok, text}.
static func cook(sb: GameSandbox) -> Dictionary:
	var d := sb.d
	if not at_fire(sb):
		return {"ok": false, "text": text("no_camp") if not active(sb) else text("far", {"n": int(round(sb.heir_point().distance_to(point(sb))))})}
	if d.battle != null:
		return {"ok": false, "text": text("fight")}
	if int(sb.camp["cooks"]) <= 0:
		return {"ok": false, "text": text("no_cooks")}
	var need := missing(d)
	if need != "":
		return {"ok": false, "text": text("no_food", {"heir": d.heir.name, "need": need})}
	var def := _cook_def()
	for m in def["takes"]:
		GameCraft.add_material(d, str(m), -int(def["takes"][m]))
	sb.camp["cooks"] = int(sb.camp["cooks"]) - 1
	var h := d.heir
	var before := h.hp
	h.hp = mini(h.max_hp(), h.hp + int(ceil(float(def["heal"]) * float(h.max_hp()))))
	d.blessing = {"spell": str(def["spell"]), "fights": int(def["fights"]), "years": float(def["years"]), "year": d.world.year, "gen": d.gen, "level": int(def["level"])}
	var line := text("cooked", {"heir": h.name, "meal": str(def["name"]), "heal": h.hp - before})
	sb.log.append({"kind": "camp", "text": line})
	return {"ok": true, "text": line}


## Use beside the fire: rest if anyone is hurt and the camp has rest in it, else cook, else say how the camp stands. {} when there is no fire near.
static func use(sb: GameSandbox) -> Dictionary:
	if not at_fire(sb):
		return {}
	if int(sb.camp["rests"]) > 0 and _hurt(sb):
		return rest(sb)
	if int(sb.camp["cooks"]) > 0 and missing(sb.d) == "":
		return cook(sb)
	var line := text("status", {"rests": int(sb.camp["rests"]), "cooks": int(sb.camp["cooks"])})
	return {"ok": true, "text": line}


## Does one of the thing menu's actions ("rest", "cook", "strike", "camp"). {ok, text}.
static func act(sb: GameSandbox, action: String) -> Dictionary:
	match action:
		"rest":
			return rest(sb)
		"cook":
			return cook(sb)
		"strike":
			return strike(sb)
		"camp":
			return toggle(sb)
	return {"ok": false, "text": ""}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "cook", "text"]:
		if not dat.has(k):
			return ["camp.json: %s is missing" % k]
	var s: Dictionary = dat["settings"]
	for k in ["reach", "strike_tiles", "seconds", "rests", "rest_years", "heal_share", "mp_share", "cooks", "night_radius", "day_radius", "escape_range", "town_margin"]:
		if not s.has(k) or typeof(s[k]) not in [TYPE_INT, TYPE_FLOAT]:
			bad.append("camp.json: settings.%s must be a number" % k)
	if not bad.is_empty():
		return bad
	if float(s["reach"]) < 1.0 or float(s["strike_tiles"]) <= float(s["reach"]) or float(s["seconds"]) <= 0.0:
		bad.append("camp.json: reach must be at least 1, strike_tiles above reach and seconds above 0")
	if int(s["rests"]) < 0 or int(s["cooks"]) < 0 or float(s["rest_years"]) < 0.0 or float(s["rest_years"]) > 0.25:
		bad.append("camp.json: rests and cooks are 0 or more and rest_years 0 to a quarter of a year")
	if float(s["heal_share"]) <= 0.0 or float(s["heal_share"]) > 1.0 or float(s["mp_share"]) < 0.0 or float(s["mp_share"]) > 1.0:
		bad.append("camp.json: heal_share is above 0 and at most 1, mp_share 0 to 1 (a full rest is the family house's, not a tent's)")
	if float(s["night_radius"]) < 0.0 or float(s["day_radius"]) < 0.0 or float(s["day_radius"]) > float(s["night_radius"]) or float(s["night_radius"]) >= float(GameSmoke.data()["radius"]):
		bad.append("camp.json: the fire's rings are 0 or more, the day's no wider than the night's, and both smaller than a smoke pot's cloud")
	GameData.load_all()
	if not GameData.items.has(str(s.get("item", ""))) or not bool(GameData.items[str(s["item"])].get("camp", false)):
		bad.append("camp.json: settings.item must be an item with camp: true")
	if str(s.get("item", "")) in GameItems.SHOPS or str(GameData.items.get(str(s.get("item", "")), {}).get("shop", "")) != "":
		bad.append("camp.json: the tent must not be sold by an old shop (the autopilot would meet it)")
	var c: Dictionary = dat["cook"]
	for k in ["id", "name", "takes", "heal", "spell", "level", "fights", "years"]:
		if not c.has(k):
			bad.append("camp.json: cook.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for m in c["takes"]:
		if not GameMaterials.has(str(m)) or int(c["takes"][m]) < 1:
			bad.append("camp.json: the meal takes '%s', which is not a material or not at least 1" % m)
	if float(c["heal"]) < 0.0 or float(c["heal"]) > 1.0 or int(c["fights"]) < 1 or int(c["level"]) < 1:
		bad.append("camp.json: the meal's heal is 0 to 1, its fights and level at least 1")
	if GameCasting.kind_of(str(c["spell"])) != "blessing":
		bad.append("camp.json: the meal's spell '%s' is not a blessing" % c["spell"])
	for k in ["name", "pitched", "struck", "struck_far", "burned_out", "none", "indoors", "upstairs", "fight", "town", "smoke", "already", "no_camp", "far", "rested", "no_need", "no_rests", "cooked", "no_food", "no_cooks", "status", "act_camp", "act_rest", "act_cook", "act_strike", "safe_night"]:
		if not dat["text"].has(k) or str(dat["text"][k]) == "":
			bad.append("camp.json: text.%s is missing" % k)
	return bad
