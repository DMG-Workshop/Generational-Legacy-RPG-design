## The one material list (roadmap item 42). Every item in data/items/items.json names a `material` and a `weight`;
## its tags are the material's plus its own slot or kind, so harvesting, mining, crafting and the loot generator all
## extend one list. Pure functions of data: nothing here draws a die or touches the dynasty. Data:
## data/items/materials.json, checked by tools/check_data.gd.
class_name GameMaterials
extends RefCounted

const PATH := "res://data/items/materials.json"
const MAX_TIER := 9

static var _cache: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_by_id = {}
		for m in _cache["materials"]:
			_by_id[str(m["id"])] = m
	return _cache


static func ids() -> Array:
	data()
	var out: Array = _by_id.keys()
	out.sort()
	return out


static func has(id: String) -> bool:
	data()
	return _by_id.has(id)


static func get_material(id: String) -> Dictionary:
	data()
	return _by_id.get(id, {})


static func name_of(id: String) -> String:
	return str(get_material(id).get("name", id))


static func tier_of(id: String) -> int:
	return int(get_material(id).get("tier", 0))


static func tags_of(id: String) -> Array:
	return Array(get_material(id).get("tags", []))


## The materials of one tier, sorted by id (what a generator draws from).
static func of_tier(tier: int) -> Array:
	var out: Array = []
	for id in ids():
		if tier_of(str(id)) == tier:
			out.append(id)
	return out


## The materials carrying a tag, sorted by id.
static func with_tag(tag: String) -> Array:
	var out: Array = []
	for id in ids():
		if tag in tags_of(str(id)):
			out.append(id)
	return out


## Every problem in the material list and in what items say about it, each starting with where it is.
static func validate() -> Array:
	var bad: Array = []
	var dat = GameData.load_json(PATH)
	if typeof(dat) != TYPE_DICTIONARY or not dat.has("materials") or not dat.has("tags"):
		return ["materials.json: needs tags and materials"]
	var tags: Array = dat["tags"]
	var seen := {}
	for m in dat["materials"]:
		var id := str(m.get("id", ""))
		if id == "" or id != id.to_lower() or " " in id:
			bad.append("materials.json: '%s' is not a lower-case id with no spaces" % id)
		if seen.has(id):
			bad.append("materials.json: '%s' is listed twice" % id)
		seen[id] = true
		if str(m.get("name", "")) == "":
			bad.append("materials.json: '%s' has no name" % id)
		var tier := int(m.get("tier", 0))
		if tier < 1 or tier > MAX_TIER:
			bad.append("materials.json: '%s' has tier %d, not 1 to %d" % [id, tier, MAX_TIER])
		if not (m.get("tags") is Array) or m["tags"].is_empty():
			bad.append("materials.json: '%s' has no tags" % id)
		else:
			for t in m["tags"]:
				if str(t) not in tags:
					bad.append("materials.json: '%s' has the unknown tag '%s'" % [id, t])
		for k in ["weight_mult", "price_mult"]:
			if float(m.get(k, 0.0)) <= 0.0:
				bad.append("materials.json: '%s' needs a positive %s" % [id, k])
	for t in tags:
		var used := false
		for m in dat["materials"]:
			if t in m.get("tags", []):
				used = true
		if not used:
			bad.append("materials.json: the tag '%s' is on no material" % t)
	# the items
	GameData.load_all()
	var used_mats := {}
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		var mat := str(it.get("material", ""))
		if not seen.has(mat):
			bad.append("items.json: '%s' names the material '%s', which is not in materials.json" % [id, mat])
		else:
			used_mats[mat] = true
		if float(it.get("weight", 0.0)) <= 0.0:
			bad.append("items.json: '%s' needs a positive weight" % id)
		var tier := int(it.get("tier", 0))
		if tier < 1 or tier > MAX_TIER:
			bad.append("items.json: '%s' has tier %d, not 1 to %d" % [id, tier, MAX_TIER])
		var gear := str(it.get("slot", "")) != ""
		if gear and int(it.get("stack", 0)) != 0:
			bad.append("items.json: '%s' is gear and cannot stack" % id)
		if not gear and int(it.get("stack", 0)) <= 0:
			bad.append("items.json: '%s' is not gear and needs a stack size" % id)
		if str(id) != str(id).to_lower() or " " in str(id):
			bad.append("items.json: '%s' is not a lower-case id with no spaces" % id)
	for mat in seen:
		if not used_mats.has(mat):
			bad.append("materials.json: '%s' is used by no item" % mat)
	return bad
