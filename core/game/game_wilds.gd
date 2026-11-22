## The wilds' look (data/world/wilds.json): what lies on the ground of the open world besides the land itself. Every biome has
## tones (translucent patches over the ground) and decor (tufts, flowers, reeds, boulders...), every body of water its own marks, a
## tree node takes the look of the biome's trees (birch, pine, willow, dead tree, fungus), and each `wilds` place of world.json has a
## signature of its own within its radius (Whisperwood's ancient trees and fog, Mirefen's black pools, Elderglade's ring of standing
## stones, Greenvale's hedged fields...). Pure functions of the seed and a tile, thinned near towns, dungeons and roads: no die of the
## dynasty's is drawn, nothing is saved and what GameWorldGen.tile gives (height, water, node) is not touched, so the guarantees of the
## land hold. ui/play/tile_view.gd draws it; the landmarks are GameWildsSites.
class_name GameWilds
extends RefCounted

const PATH := "res://data/world/wilds.json"
const TAG := 240   # the noise tags used here (GameWorldGen._lat) run from this up

static var _cache: Dictionary = {}
static var _tables: Dictionary = {}
static var _rings: Dictionary = {}
static var _areas: Array = []


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_tables = {}
		_rings = {}
		_areas = []
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## Every glyph the wilds draws, by id (8 rows of 8 and a palette, as in sandbox.json).
static func glyphs() -> Dictionary:
	return data()["glyphs"]


static func glyph_ids() -> Array:
	var out: Array = glyphs().keys()
	out.sort()
	return out


# ---------------------------------------------------------------- areas

## The wilds places that have a signature: [{id, x, z, radius, biome}].
static func areas() -> Array:
	if _areas.is_empty():
		for id in data()["areas"]:
			var a := GameWorldGen.anchor(str(id))
			if a.is_empty():
				continue
			_areas.append({"id": str(id), "x": float(a["x"]), "z": float(a["z"]), "radius": float(data()["areas"][id]["radius"]), "biome": str(a["biome"])})
	return _areas


## The area a tile belongs to and how strongly: {id, s}. s is 1 up to `area_fade` of the radius and falls to 0 at the radius, and an
## area only claims land of its own biome ("" and 0 elsewhere, which is the generic land of the biome).
static func area_at(x: int, z: int, biome: String) -> Dictionary:
	var best := {"id": "", "s": 0.0}
	for a in areas():
		if str(a["biome"]) != biome:
			continue
		var dist := Vector2(float(x) - float(a["x"]), float(z) - float(a["z"])).length()
		if dist >= float(a["radius"]):
			continue
		var s := 1.0 - smoothstep(float(a["radius"]) * float(setting("area_fade")), float(a["radius"]), dist)
		if s > float(best["s"]):
			best = {"id": str(a["id"]), "s": s}
	return best


## The area id a tile counts as (spawns, landmarks, loot), "" for generic land: where the area's claim is at least a quarter.
static func area_of(x: int, z: int, biome: String) -> String:
	var a := area_at(x, z, biome)
	return str(a["id"]) if float(a["s"]) >= 0.25 else ""


# ---------------------------------------------------------------- thinning

## How much of the full decoration a tile gets, 0 to 1: none inside a town's, plot's or dungeon's ground and its margin, rising to full
## over `town_fade` tiles, and less near a road.
static func thin(x: int, z: int) -> float:
	var f := 1.0
	for a in GameWorldGen.zones():
		var r := float(a["radius"])
		if r <= 0.0:
			continue
		var clear := float(setting("dungeon_clear")) if str(a["type"]) == "dungeon" else float(setting("town_clear"))
		var dist := Vector2(float(x) - float(a["x"]), float(z) - float(a["z"])).length() - r
		f = minf(f, smoothstep(clear, clear + float(setting("town_fade")), dist))
		if f <= 0.0:
			return 0.0
	var rd := GameWorldGen.road_distance(float(x), float(z))
	return minf(f, lerpf(float(setting("road_floor")), 1.0, smoothstep(float(setting("road_clear")), float(setting("road_fade")), rd)))


# ---------------------------------------------------------------- tables

## The merged rows for a biome, or for an area (its own, with the biome's filling what it lacks): {tones, decor, trees, max_tone, max_decor}.
static func table(biome: String, area: String) -> Dictionary:
	var key := biome + "|" + area
	data()
	if _tables.has(key):
		return _tables[key]
	var base: Dictionary = data()["ground"].get(biome, {})
	var spec: Dictionary = data()["areas"].get(area, {}) if area != "" else {}
	var out := {}
	for k in ["tones", "decor", "trees"]:
		out[k] = spec[k] if spec.has(k) else base.get(k, [] if k != "trees" else {})
	out["max_tone"] = _bound(out["tones"])
	out["max_decor"] = _bound(out["decor"])
	_tables[key] = out
	return out


static func _bound(rows: Array) -> float:
	var total := 0.0
	for r in rows:
		total += float(r["p"]) * (2.0 if r.has("clump") else 1.0)
	return total


static func _near_water(seed_value: int, x: int, z: int) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if GameWorldGen.water_at(seed_value, x + off.x, z + off.y):
			return true
	return false


## One row of a table for a roll u (0 to 1), or "".
static func _pick(rows: Array, u: float, seed_value: int, x: int, z: int, h: int, scale: float, water: Array) -> String:
	var acc := 0.0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if r.has("near"):
			if water[0] == null:
				water[0] = _near_water(seed_value, x, z)
			if not water[0]:
				continue
		if r.has("min_h") and h < int(r["min_h"]):
			continue
		if r.has("max_h") and h > int(r["max_h"]):
			continue
		var p := float(r["p"]) * scale
		if r.has("clump"):
			var n := GameWorldGen._noise(seed_value, TAG + 20 + i, float(x) / float(r["clump"]), float(z) / float(r["clump"]))
			p *= 2.0 * smoothstep(0.42, 0.68, n)
		acc += p
		if u < acc:
			return str(r["glyph"])
	return ""


## What is drawn on a tile over its ground: the thing (a tuft, a flower, a stone of the ring, a hedge) or else a tone patch, or "".
## `t` is a GameWorldGen tile ({x, z, biome, height, body}). Landmarks (GameWildsSites) are drawn before this.
static func ground_glyph(seed_value: int, t: Dictionary) -> String:
	var x := int(t["x"])
	var z := int(t["z"])
	if not GameWorldGen.in_bounds(x, z):
		return ""
	var body := str(t.get("body", ""))
	var h := int(t.get("height", 0))
	var water := [null]
	if body != "":
		var wt: Dictionary = data()["water"].get(body, {})
		if wt.is_empty():
			return ""
		var u := GameWorldGen._lat(seed_value, TAG, x, z)
		var g := _pick(wt["decor"], u, seed_value, x, z, h, 1.0, water)
		return g
	var biome := str(t["biome"])
	var area := area_at(x, z, biome)
	var id := ""
	if str(area["id"]) != "" and GameWorldGen._lat(seed_value, TAG + 3, x, z) < float(area["s"]):
		id = str(area["id"])
		var special := _special(seed_value, id, x, z)
		if special[0] != "":
			return str(special[0])
	var tab := table(biome, id)
	var u1 := GameWorldGen._lat(seed_value, TAG, x, z)
	var u2 := GameWorldGen._lat(seed_value, TAG + 1, x, z)
	var tone_special := str(special_tone(id, x, z)) if id != "" else ""
	if u1 >= float(tab["max_decor"]) and u2 >= float(tab["max_tone"]) and tone_special == "":
		return ""
	var scale := thin(x, z)
	if scale <= 0.0:
		return ""
	if u1 < float(tab["max_decor"]):
		var g2 := _pick(tab["decor"], u1, seed_value, x, z, h, scale, water)
		if g2 != "":
			return g2
	if tone_special != "" and u2 < scale:
		return tone_special
	if u2 < float(tab["max_tone"]):
		return _pick(tab["tones"], u2, seed_value, x, z, h, scale, water)
	return ""


## [decor glyph, tone glyph] an area's special layout gives a tile: the ring's stones and the lattice's hedges, crops and furrows.
static func _special(seed_value: int, area: String, x: int, z: int) -> Array:
	var spec: Dictionary = data()["areas"][area]
	if spec.has("ring"):
		var g := str(_ring(area).get(x * 100003 + z, ""))
		if g != "":
			return [g, ""]
	if spec.has("lattice"):
		var l: Dictionary = spec["lattice"]
		var c := int(l["cell"])
		var cx := floori(float(x) / float(c))
		var cz := floori(float(z) / float(c))
		var lx := x - cx * c
		var lz := z - cz * c
		var here := GameWorldGen._lat(seed_value, TAG + 40, cx, cz) < float(l["field_p"])
		if lx == 0 or lz == 0:
			var west := GameWorldGen._lat(seed_value, TAG + 40, cx - 1, cz) < float(l["field_p"])
			var north := GameWorldGen._lat(seed_value, TAG + 40, cx, cz - 1) < float(l["field_p"])
			var edge: bool = here or (lx == 0 and west) or (lz == 0 and north)
			if edge and GameWorldGen._lat(seed_value, TAG + 41, x, z) < float(l["hedge_p"]) * thin(x, z):
				return [str(l["hedge"]), ""]
		elif here:
			if GameWorldGen._lat(seed_value, TAG + 42, x, z) < float(l["crop_p"]) * thin(x, z):
				return [str(l["crop"]), ""]
			return ["", str(l["field"])]
	return ["", ""]


## The tone an area lays by its own rule: a ring's inside, or the furrows of a field.
static func special_tone(area: String, x: int, z: int) -> String:
	var spec: Dictionary = data()["areas"][area]
	if spec.has("ring"):
		var r: Dictionary = spec["ring"]
		var a := GameWorldGen.anchor(area)
		var dist := Vector2(float(x) - float(a["x"]) - float(r["center"][0]), float(z) - float(a["z"]) - float(r["center"][1])).length()
		if dist < float(r["inside"]):
			return str(r["inside_tone"])
	return ""


## The tiles of an area's rings: x * 100003 + z -> glyph.
static func _ring(area: String) -> Dictionary:
	data()
	if _rings.has(area):
		return _rings[area]
	var out := {}
	var r: Dictionary = data()["areas"][area]["ring"]
	var a := GameWorldGen.anchor(area)
	var cx := float(a["x"]) + float(r["center"][0])
	var cz := float(a["z"]) + float(r["center"][1])
	for ring in r["rings"]:
		var n := int(ring["count"])
		for i in n:
			var ang := TAU * float(i) / float(n) + 0.35
			var tx := int(round(cx + float(ring["radius"]) * cos(ang)))
			var tz := int(round(cz + float(ring["radius"]) * sin(ang)))
			out[tx * 100003 + tz] = str(ring["glyph"])
	_rings[area] = out
	return out


## The look of a node on a tile: the glyph it is drawn with, one of the biome's (or area's) trees for an oak or yew, else the node's own.
static func node_look(seed_value: int, t: Dictionary) -> String:
	var node: Dictionary = t.get("node", {})
	if node.is_empty():
		return ""
	var kind := str(node["kind"])
	var x := int(t["x"])
	var z := int(t["z"])
	var biome := str(t["biome"])
	var area := area_at(x, z, biome)
	var id := str(area["id"]) if float(area["s"]) > 0.0 and GameWorldGen._lat(seed_value, TAG + 3, x, z) < float(area["s"]) else ""
	var rows: Array = table(biome, id)["trees"].get(kind, [])
	if rows.is_empty():
		return kind
	var total := 0.0
	for r in rows:
		total += float(r["w"])
	var roll := GameWorldGen._lat(seed_value, TAG + 5, x, z) * total
	for r in rows:
		roll -= float(r["w"])
		if roll < 0.0:
			return str(r["glyph"])
	return str(rows.back()["glyph"])


# ---------------------------------------------------------------- the data

static func _row_problems(rows: Variant, where: String, glyph_ok: Callable) -> Array:
	var bad: Array = []
	if typeof(rows) != TYPE_ARRAY:
		return ["wilds.json: %s is not a list" % where]
	var total := 0.0
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY or not r.has("glyph") or not r.has("p"):
			bad.append("wilds.json: a row of %s needs a glyph and a p" % where)
			continue
		if not glyph_ok.call(str(r["glyph"])):
			bad.append("wilds.json: %s names the glyph '%s', which is not drawn" % [where, r["glyph"]])
		if float(r["p"]) <= 0.0 or float(r["p"]) > 1.0:
			bad.append("wilds.json: %s has a p outside 0 to 1" % where)
		if r.has("near") and str(r["near"]) != "water":
			bad.append("wilds.json: %s has a near that is not water" % where)
		if r.has("clump") and float(r["clump"]) <= 0.0:
			bad.append("wilds.json: %s has a clump of no size" % where)
		total += float(r["p"])
	if total > 0.95:
		bad.append("wilds.json: %s fills more than 0.95 of a tile" % where)
	return bad


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "ground", "water", "areas", "placement", "ores", "landmarks", "text", "glyphs"]:
		if not dat.has(k):
			bad.append("wilds.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var surface: Array = GameWorldGen.data()["biomes"].keys()
	var known := func(g: String) -> bool: return dat["glyphs"].has(g) or GameWorldGen.data()["nodes"].has(g)
	var s: Dictionary = dat["settings"]
	for k in ["town_clear", "town_fade", "road_clear", "road_fade", "road_floor", "dungeon_clear", "area_fade", "cell", "margin", "min_gap", "tries", "see_range", "use_reach", "renew_gens", "dungeon_near", "found_cap", "markup", "offer_reach"]:
		if not s.has(k):
			bad.append("wilds.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["cell"]) < 12 or int(s["margin"]) * 2 >= int(s["cell"]) or int(s["margin"]) < 4:
		bad.append("wilds.json: a cell must be at least 12 tiles and have a margin of 4 or more, under half of it")
	if float(s["area_fade"]) <= 0.0 or float(s["area_fade"]) >= 1.0 or float(s["road_floor"]) < 0.0 or float(s["road_floor"]) > 1.0:
		bad.append("wilds.json: area_fade must be within 0 and 1, and road_floor within 0 and 1")
	if float(s["use_reach"]) <= 0.0 or float(s["see_range"]) < float(s["use_reach"]) or int(s["renew_gens"]) < 1:
		bad.append("wilds.json: use_reach must be above 0, see_range at least that, and renew_gens at least 1")
	for id in dat["glyphs"]:
		var g: Dictionary = dat["glyphs"][id]
		if GameBuild.pieces().has(id) or GamePath.data()["terrain"].has(id) or ["water", "dug", "person", "exit", "deep", "snow", "ford"].has(id) or GameWorldGen.data()["nodes"].has(id):
			bad.append("wilds.json: the glyph '%s' has the name of a kind the tile view already has" % id)
		if typeof(g) != TYPE_DICTIONARY or typeof(g.get("rows")) != TYPE_ARRAY or (g["rows"] as Array).size() != 8 or typeof(g.get("palette")) != TYPE_DICTIONARY:
			bad.append("wilds.json: glyph '%s' needs 8 rows and a palette" % id)
	for b in surface:
		if not dat["ground"].has(b):
			bad.append("wilds.json: the biome '%s' has no ground" % b)
	for b in dat["ground"]:
		var def: Dictionary = dat["ground"][b]
		if b not in surface:
			bad.append("wilds.json: ground names the biome '%s', which the world does not have" % b)
		for k in ["tones", "decor"]:
			bad.append_array(_row_problems(def.get(k), "ground %s %s" % [b, k], known))
		bad.append_array(_tree_problems(def.get("trees"), "ground %s" % b, known))
	for body in ["sea", "lake", "river", "ford"]:
		if not dat["water"].has(body):
			bad.append("wilds.json: water has no rows for '%s'" % body)
		else:
			bad.append_array(_row_problems(dat["water"][body].get("decor", null), "water %s" % body, known))
	var seen := {}
	for id in dat["areas"]:
		var a: Dictionary = dat["areas"][id]
		var place: Dictionary = GameWorld.place(str(id))
		if place.is_empty() or str(place.get("type", "")) != "wilds":
			bad.append("wilds.json: the area '%s' is not a wilds place of world.json" % id)
			continue
		if float(a.get("radius", 0)) < 12.0 or float(a["radius"]) > 60.0:
			bad.append("wilds.json: the area '%s' needs a radius of 12 to 60 tiles" % id)
		for k in ["tones", "decor"]:
			bad.append_array(_row_problems(a.get(k), "area %s %s" % [id, k], known))
		bad.append_array(_tree_problems(a.get("trees"), "area %s" % id, known))
		var sig := JSON.stringify([a.get("tones"), a.get("decor"), a.get("trees"), a.get("ring"), a.get("lattice")])
		if seen.has(sig):
			bad.append("wilds.json: the areas '%s' and '%s' look the same" % [id, seen[sig]])
		seen[sig] = id
		if a.has("ring"):
			for ring in a["ring"].get("rings", []):
				if not known.call(str(ring["glyph"])):
					bad.append("wilds.json: the ring of '%s' uses the glyph '%s', which is not drawn" % [id, ring["glyph"]])
			if not known.call(str(a["ring"].get("inside_tone", ""))):
				bad.append("wilds.json: the ring of '%s' has an inside_tone that is not drawn" % id)
		if a.has("lattice"):
			for k in ["hedge", "field", "crop"]:
				if not known.call(str(a["lattice"].get(k, ""))):
					bad.append("wilds.json: the lattice of '%s' has a %s that is not drawn" % [id, k])
		for f in a.get("fixed", []):
			if not dat["landmarks"].has(str(f.get("kind", ""))):
				bad.append("wilds.json: the area '%s' fixes the unknown landmark '%s'" % [id, f.get("kind", "")])
			elif str(f["kind"]) == "lair" and str(place.get("lair", "")) == "":
				bad.append("wilds.json: the area '%s' has a lair but world.json gives it no legend" % id)
		if not a.has("placement"):
			bad.append("wilds.json: the area '%s' has no placement" % id)
		else:
			bad.append_array(_placement_problems(a["placement"], "area %s" % id))
	for l in GameData.world["locations"]:
		if str(l["type"]) == "wilds" and not dat["areas"].has(str(l["id"])):
			bad.append("wilds.json: the wilds place '%s' has no area of its own" % l["id"])
	for b in surface:
		if not dat["placement"].has(b):
			bad.append("wilds.json: the biome '%s' has no placement" % b)
		else:
			bad.append_array(_placement_problems(dat["placement"][b], "placement %s" % b))
		if not dat["ores"].has(b):
			bad.append("wilds.json: the biome '%s' has no ores" % b)
		else:
			for o in dat["ores"][b]:
				if not GameMaterials.has(str(o.get("id", ""))):
					bad.append("wilds.json: ores for '%s' name the unknown material '%s'" % [b, o.get("id", "")])
	for k in dat["landmarks"]:
		bad.append_array(_landmark_problems(str(k), dat["landmarks"][k], known))
	for k in ["found", "hint", "hint_done", "nothing", "dungeon_line", "dungeon_none", "legend_unknown", "offer", "bought", "poor", "full", "sold_out", "tithe", "map_title", "map_line", "map_more", "map_none", "in_wilds"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("wilds.json: text.%s is missing" % k)
	return bad


static func _tree_problems(trees: Variant, where: String, known: Callable) -> Array:
	var bad: Array = []
	if typeof(trees) != TYPE_DICTIONARY:
		return ["wilds.json: %s trees is not a table" % where]
	for kind in trees:
		if not GameWorldGen.data()["nodes"].has(kind):
			bad.append("wilds.json: %s has trees for '%s', which is not a node" % [where, kind])
		for r in trees[kind]:
			if not known.call(str(r.get("glyph", ""))) or float(r.get("w", 0)) <= 0.0:
				bad.append("wilds.json: %s has a tree look with an unknown glyph or no weight" % where)
	return bad


static func _placement_problems(p: Dictionary, where: String) -> Array:
	var bad: Array = []
	if float(p.get("p", -1)) < 0.0 or float(p.get("p", 2)) > 1.0:
		bad.append("wilds.json: %s needs a p from 0 to 1" % where)
	var kinds: Dictionary = p.get("kinds", {})
	if kinds.is_empty():
		bad.append("wilds.json: %s has no kinds" % where)
	for k in kinds:
		if not data()["landmarks"].has(k):
			bad.append("wilds.json: %s places the unknown landmark '%s'" % [where, k])
		elif str(k) in ["lair", "fae_ring"]:
			bad.append("wilds.json: %s places '%s', which is only ever fixed" % [where, k])
		if float(kinds[k]) <= 0.0:
			bad.append("wilds.json: %s gives '%s' no weight" % [where, k])
	return bad


static func _landmark_problems(k: String, def: Dictionary, known: Callable) -> Array:
	var bad: Array = []
	for f in ["name", "verb", "done", "layout", "center", "outcomes"]:
		if not def.has(f):
			bad.append("wilds.json: the landmark '%s' has no %s" % [k, f])
	if not bad.is_empty():
		return bad
	var layout: Array = def["layout"]
	var cells := 0
	for r in layout:
		for g in r:
			if g == ".":
				continue
			cells += 1
			if not known.call(str(g)):
				bad.append("wilds.json: the landmark '%s' draws the glyph '%s', which is not drawn" % [k, g])
	if cells == 0 or layout.size() > 3 or layout.any(func(r): return (r as Array).size() > 3):
		bad.append("wilds.json: the landmark '%s' needs a layout of 1 to 3 tiles each way with something in it" % k)
	var c: Array = def["center"]
	if c.size() != 2 or int(c[1]) < 0 or int(c[1]) >= layout.size() or int(c[0]) < 0 or int(c[0]) >= (layout[int(c[1])] as Array).size() or str(layout[int(c[1])][int(c[0])]) == ".":
		bad.append("wilds.json: the landmark '%s' has a center that is not on one of its glyphs" % k)
	if bool(def.get("trade", false)):
		if typeof(def.get("stock")) != TYPE_DICTIONARY or not def["stock"].has("default"):
			bad.append("wilds.json: the trading landmark '%s' needs a stock with a default" % k)
		else:
			for list in def["stock"].values():
				for id in list:
					if GameItems.item_def(str(id)).is_empty():
						bad.append("wilds.json: '%s' sells the unknown item '%s'" % [k, id])
	elif (def["outcomes"] as Array).is_empty():
		bad.append("wilds.json: the landmark '%s' has no outcomes" % k)
	for o in def["outcomes"]:
		if float(o.get("w", 0)) <= 0.0 or str(o.get("text", "")) == "":
			bad.append("wilds.json: an outcome of '%s' needs a weight and a text" % k)
		if o.has("if") and str(o["if"]) not in ["legend_stirring", "legend_slain"]:
			bad.append("wilds.json: an outcome of '%s' has the unknown condition '%s'" % [k, o["if"]])
		if o.has("hurt") and (float(o["hurt"]) <= 0.0 or float(o["hurt"]) > 0.5):
			bad.append("wilds.json: an outcome of '%s' hurts by more than half or not at all" % k)
		for f in ["gold", "ore"]:
			if o.has(f) and ((o[f] as Array).size() != 2 or int(o[f][1]) < int(o[f][0])):
				bad.append("wilds.json: an outcome of '%s' has a bad %s range" % [k, f])
		if o.has("material") and not GameMaterials.has(str(o["material"].get("id", ""))):
			bad.append("wilds.json: an outcome of '%s' gives an unknown material" % k)
	return bad
