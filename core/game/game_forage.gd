## Foraging by the heir (roadmap item 44; data/world/forage.json). The Forage action takes the nearest ungathered node within
## `reach` of the heir (GameCompanions.scan's nodes), adds its amount times the heir's class share to the family's stores and marks
## it gathered with the same marks the companions use, so it regrows on the same calendar. No dice; nothing new is saved.
class_name GameForage
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/world/forage.json")
	return _cache


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## The heir's class share of what a node gives.
static func share(d: GameDynasty) -> float:
	var table: Dictionary = data()["classes"]
	return float(table.get(d.heir.class_id, table["default"]))


## The nodes in reach of a tile, nearest first (GameCompanions.scan, cut to `reach`).
static func in_reach(d: GameDynasty, x: int, z: int) -> Array:
	var out: Array = []
	var here := Vector2(float(x) + 0.5, float(z) + 0.5)
	for n in GameCompanions.scan(d, Vector2(float(x), float(z))):
		if Vector2(float(n["x"]) + 0.5, float(n["z"]) + 0.5).distance_to(here) <= float(data()["settings"]["reach"]):
			out.append(n)
	return out


## Gathers the nearest node in reach of the tile (x, z): {ok, text, n, material}.
static func forage(d: GameDynasty, x: int, z: int) -> Dictionary:
	var nodes := in_reach(d, x, z)
	if nodes.is_empty():
		return {"ok": false, "text": text("nothing"), "n": 0, "material": ""}
	var node: Dictionary = nodes[0]
	var n := maxi(1, int(round(float(node["amount"]) * share(d))))
	GameCraft.add_material(d, str(node["material"]), n)
	d.gathered[GameCompanions.node_key(int(node["x"]), int(node["z"]))] = float(d.world.year)
	var line := text("foraged", {"heir": d.heir.name, "n": n, "material": GameMaterials.name_of(str(node["material"])).to_lower()})
	d._say(line)
	return {"ok": true, "text": line, "n": n, "material": str(node["material"]), "x": int(node["x"]), "z": int(node["z"])}


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "classes", "text"]:
		if not dat.has(k):
			bad.append("forage.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(dat["settings"].get("reach", 0.0)) < 1.0:
		bad.append("forage.json: reach must be at least 1 (the heir's own tile)")
	if not dat["classes"].has("default"):
		bad.append("forage.json: classes needs a default")
	for c in dat["classes"]:
		if float(dat["classes"][c]) <= 0.0:
			bad.append("forage.json: the share for '%s' must be above 0" % c)
		if str(c) != "default" and not GameData.classes.has(str(c)):
			bad.append("forage.json: '%s' is not a class" % c)
	for k in ["foraged", "nothing", "indoors", "upstairs"]:
		if not dat["text"].has(k):
			bad.append("forage.json: text.%s is missing" % k)
	return bad
