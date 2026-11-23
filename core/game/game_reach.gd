## What a shot, a spell, a look, a shove or a blink may cross (core, no UI; `reach` in data/world/walls.json, rules in docs/REACH.md).
## `GameWalls.line_clear` is the melee rule; this is the rest, on the same tiles and the same sampling, and each kind of stopper lists the
## channels it stops (walk, melee, ranged, area, sight), so a grille stops a blow but not an arrow and a slit lets a look through.
## Everything is a pure function of the tiles and the arguments: no dice, nothing saved, no creature or battle is changed.
## `probe` (tests, and tiles the map does not have yet): a Callable(x, z) -> String giving a tile's kind ("" for open ground, or a key of
## `reach.stoppers`) in place of the world's own tiles. `shut` is whether the gates are shut (`GameWalls.shut_now`).
class_name GameReach
extends RefCounted

const CHANNELS := ["walk", "melee", "ranged", "area", "sight"]


static func data() -> Dictionary:
	return GameWalls.data()["reach"]


static func setting(key: String) -> Variant:
	return data()[key]


## The kind of stopper on a tile ("" for none): the world's wall, tower, jamb, a town or dungeon body ("building"), a shut gate.
static func kind_at(x: int, z: int, shut: bool, probe: Callable = Callable()) -> String:
	if probe.is_valid():
		return str(probe.call(x, z))
	var k := GameWalls.kind_at(x, z)
	if k in GameWalls.SOLID:
		return k
	if k == "gate" and shut:
		return "gate_shut"
	if GameTown.blocks(x, z) or GameDungeonArt.blocks(x, z):
		return "building"
	return ""


## Whether a kind of stopper stops a channel. A lobbed shot (`arc`) passes over a stopper no taller than the arc's height.
static func stops(kind: String, channel: String, arc: bool = false) -> bool:
	if kind == "":
		return false
	var def: Dictionary = (data()["stoppers"] as Dictionary).get(kind, {})
	if channel not in (def.get("stops", []) as Array):
		return false
	return not (arc and float(def.get("height", 0.0)) <= float(data()["arc"]["height"]))


static func tile_stops(x: int, z: int, channel: String, shut: bool, probe: Callable = Callable(), arc: bool = false) -> bool:
	return stops(kind_at(x, z, shut, probe), channel, arc)


## Whether the straight line from `a` to `b` (points in tiles) is clear of everything that stops `channel`. Sampled every `step` tiles; the
## tile the line starts in is not tested; a diagonal step between two stoppers that meet at a corner is stopped, one stopper beside it is not.
static func line_clear(a: Vector2, b: Vector2, channel: String, shut: bool, probe: Callable = Callable(), arc: bool = false, step: float = -1.0) -> bool:
	if step <= 0.0:
		step = float(setting("step"))
	var n := maxi(1, int(ceil(a.distance_to(b) / maxf(step, 0.05))))
	var from := Vector2i(floori(a.x), floori(a.y))
	var last := from
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / float(n))
		var t := Vector2i(floori(p.x), floori(p.y))
		if t == last:
			continue
		if t.x != last.x and t.y != last.y:
			if tile_stops(t.x, last.y, channel, shut, probe, arc) and tile_stops(last.x, t.y, channel, shut, probe, arc):
				return false
		last = t
		if t != from and tile_stops(t.x, t.y, channel, shut, probe, arc):
			return false
	return true


# ---------------------------------------------------------------- ranged

## Whether a shot from `a` at `b` can be fired: within `range` tiles and the line clear for a shot. An `arc` shot (lobbed) clears low
## stoppers, but only from `reach.arc.min_range` tiles out. A blocked shot is lost (the caller keeps its target and moves).
static func shot_ok(a: Vector2, b: Vector2, range: float, shut: bool, arc: bool = false, probe: Callable = Callable()) -> bool:
	var d := a.distance_to(b)
	if d > range:
		return false
	var lob := arc and d >= float(data()["arc"]["min_range"])
	return line_clear(a, b, "ranged", shut, probe, lob)


## Whether a body that flies may end a move on a tile: not on a solid one (it may cross the wall's column, not stand in it).
static func can_end_on(x: int, z: int, shut: bool, probe: Callable = Callable()) -> bool:
	return not tile_stops(x, z, "walk", shut, probe)


# ---------------------------------------------------------------- area

## The points a spread hits. `spec` is a spell's `target` ({shape: burst|cone|line|all|party, radius or range, angle (degrees), width});
## `dir` is where a cone or line points (a vector). A point is hit only if the line from `origin` to it is clear for `area`: a wall
## casts a shadow. `all` and `party` are the battle's own sets and are not clipped.
static func area_hits(origin: Vector2, spec: Dictionary, dir: Vector2, points: Array, shut: bool, probe: Callable = Callable()) -> Array:
	var shape := str(spec.get("shape", "burst"))
	var out: Array = []
	if shape in ["all", "party", "single"]:
		return points.duplicate()
	var reach := float(spec.get("radius", spec.get("range", 0.0)))
	var d := dir.normalized()
	for p in points:
		var v: Vector2 = p
		var off := v - origin
		var len := off.length()
		if len > reach:
			continue
		if len > 0.0001:
			if shape == "cone":
				if d == Vector2.ZERO or absf(rad_to_deg(d.angle_to(off))) > float(spec.get("angle", 90.0)) * 0.5:
					continue
			elif shape == "line":
				if d == Vector2.ZERO or off.dot(d) < 0.0 or absf(off.cross(d)) > float(spec.get("width", setting("line_width"))) * 0.5:
					continue
		if len <= 0.0001 or line_clear(origin, v, "area", shut, probe):
			out.append(v)
	return out


## Whether a spell can be aimed from `origin` at a fight centred on `target` (not across a wall).
static func aimable(origin: Vector2, target: Vector2, shut: bool, probe: Callable = Callable()) -> bool:
	return line_clear(origin, target, "area", shut, probe)


# ---------------------------------------------------------------- sight and pathing

## Whether a creature at `a` with `sight` tiles of sight acquires a target at `b`: in range and nothing that stops sight between.
static func sees(a: Vector2, b: Vector2, sight: float, shut: bool, probe: Callable = Callable()) -> bool:
	return a.distance_to(b) <= sight and line_clear(a, b, "sight", shut, probe)


## Whether a creature that already hunts a target keeps it: by distance alone, `lose_sight_mult` times its sight (a chase round a corner
## is not dropped at once). Smell and hearing (`alert_radius`, pack calls) are not sight and use no line at all.
static func keeps(a: Vector2, b: Vector2, sight: float, lose_sight_mult: float) -> bool:
	return a.distance_to(b) <= sight * lose_sight_mult


## Whether a creature in chase whose strike line is stopped gives up: no way round (`path_len` below 0) or one longer than
## `chase_detour_mult` (behaviour.json) times the straight distance. `path_len` is the walked length from `GamePath.find`.
static func loses_interest(strike_clear: bool, straight: float, path_len: float, detour_mult: float) -> bool:
	if strike_clear:
		return false
	return path_len < 0.0 or path_len > maxf(straight, 1.0) * detour_mult


## A flank point moved off a solid tile to the centre of the nearest tile a walker can stand on (ring by ring, nearest first).
static func flank_point(p: Vector2, shut: bool, probe: Callable = Callable(), max_ring: int = 6) -> Vector2:
	var tx := floori(p.x)
	var tz := floori(p.y)
	if not tile_stops(tx, tz, "walk", shut, probe):
		return p
	var best := p
	var best_d := INF
	for r in range(1, max_ring + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r or tile_stops(tx + dx, tz + dz, "walk", shut, probe):
					continue
				var c := Vector2(tx + dx + 0.5, tz + dz + 0.5)
				if p.distance_to(c) < best_d:
					best_d = p.distance_to(c)
					best = c
		if best_d < INF:
			return best
	return p


# ---------------------------------------------------------------- shove, pull, blink

## A body shoved from `p` along `dir` for up to `dist` tiles: it stops at the first tile that stops a walker (a diagonal squeezing between
## two such tiles is stopped too) and never goes through. Returns {pos, moved, blocked}.
static func knock(p: Vector2, dir: Vector2, dist: float, shut: bool, probe: Callable = Callable()) -> Dictionary:
	var d := dir.normalized()
	if d == Vector2.ZERO or dist <= 0.0:
		return {"pos": p, "moved": 0.0, "blocked": false}
	var step := float(setting("knock_step"))
	var pos := p
	var moved := 0.0
	while moved < dist - 0.0001:
		var inc := minf(step, dist - moved)
		var nxt := pos + d * inc
		if not _step_free(pos, nxt, shut, probe):
			return {"pos": pos, "moved": moved, "blocked": true}
		pos = nxt
		moved += inc
	return {"pos": pos, "moved": moved, "blocked": false}


## A pull of `target` toward `caster` by up to `dist`: it ends in front of the first stopper, and never nearer the caster than
## `reach.pull_gap` tiles.
static func pull(target: Vector2, caster: Vector2, dist: float, shut: bool, probe: Callable = Callable()) -> Dictionary:
	var gap := target.distance_to(caster) - float(setting("pull_gap"))
	return knock(target, caster - target, minf(dist, maxf(gap, 0.0)), shut, probe)


## Whether a blink from `a` to `b` works: within `range`, a clear line for a shot (it is not a walk) and a tile to stand on.
## A teleport to a named place is not a reach and needs only `can_end_on`.
static func blink_ok(a: Vector2, b: Vector2, range: float, shut: bool, probe: Callable = Callable()) -> bool:
	return a.distance_to(b) <= range and can_end_on(floori(b.x), floori(b.y), shut, probe) and line_clear(a, b, "ranged", shut, probe)


static func _step_free(a: Vector2, b: Vector2, shut: bool, probe: Callable) -> bool:
	var f := Vector2i(floori(a.x), floori(a.y))
	var t := Vector2i(floori(b.x), floori(b.y))
	if f == t:
		return true
	if tile_stops(t.x, t.y, "walk", shut, probe):
		return false
	if f.x != t.x and f.y != t.y:
		if tile_stops(t.x, f.y, "walk", shut, probe) and tile_stops(f.x, t.y, "walk", shut, probe):
			return false
	return true


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = GameWalls.data()
	if not dat.has("reach"):
		return ["walls.json: reach is missing"]
	var r: Dictionary = dat["reach"]
	for k in ["step", "stoppers", "arc", "knock_step", "pull_gap", "line_width"]:
		if not r.has(k):
			bad.append("walls.json: reach.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["step", "knock_step"]:
		if float(r[k]) <= 0.0 or float(r[k]) > 0.5:
			bad.append("walls.json: reach.%s must be above 0 and under half a tile, or a wall could be stepped over" % k)
	if float(r["line_width"]) <= 0.0:
		bad.append("walls.json: reach.line_width must be above 0")
	for k in ["wall", "tower", "jamb", "building", "gate_shut", "bars", "slit"]:
		if not (r["stoppers"] as Dictionary).has(k):
			bad.append("walls.json: reach.stoppers has no '%s'" % k)
	for k in r["stoppers"]:
		var def: Dictionary = r["stoppers"][k]
		if not (def.get("stops") is Array) or float(def.get("height", 0.0)) <= 0.0:
			bad.append("walls.json: reach.stoppers.%s needs a stops list and a height" % k)
			continue
		for c in def["stops"]:
			if str(c) not in CHANNELS:
				bad.append("walls.json: reach.stoppers.%s stops '%s', which is not a channel (%s)" % [k, c, ", ".join(CHANNELS)])
	for k in GameWalls.SOLID + ["building"]:
		var st: Array = r["stoppers"].get(k, {}).get("stops", [])
		for c in CHANNELS:
			if c not in st:
				bad.append("walls.json: reach.stoppers.%s must stop %s" % [k, c])
	for k in ["bars", "slit", "gate_shut"]:
		var st2: Array = r["stoppers"].get(k, {}).get("stops", [])
		if "walk" not in st2 or "melee" not in st2:
			bad.append("walls.json: reach.stoppers.%s must stop walk and melee" % k)
	return bad
