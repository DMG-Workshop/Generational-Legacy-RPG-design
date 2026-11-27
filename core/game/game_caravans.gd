## Caravans (data/world/roads.json `caravans`): a wagon and its trader walk each road between two towns, wait in each, and turn back. Where one
## is at any moment is a pure function of the seed, the road and the hour of the world clock (a hash of the seed and the road sets when it
## sets out), so the same hour shows the same wagon and nothing is saved. Use beside one opens the wilds merchant's panel
## (GameWildsTrade) with the wares of the landmark kind `caravan` (data/world/wilds.json): the stock is shuffled on a hash of the seed, the
## caravan and the generation's period, never the dynasty's dice, and what the family buys is recorded as GameWildsTrade does. The sandbox
## screen draws the wagon like a villager; the autopilot never walks the open world.
## Run: godot --headless --path . -s res://tests/test_game_roads.gd
class_name GameCaravans
extends RefCounted

const KIND := "caravan"
const PREFIX := "caravan:"


static func setting(key: String) -> Variant:
	return GameRoads.data()["caravans"][key]


## The links (indexes of GameRoads.links()) a caravan walks: between two towns, at least `min_length` long.
static func routes() -> Array:
	var out: Array = []
	var ls := GameRoads.links()
	for i in ls.size():
		var l: Dictionary = ls[i]
		if bool(setting("towns_only")) and (str(GameWorldGen.anchor(str(l["a"])).get("type", "")) != "town" or str(GameWorldGen.anchor(str(l["b"])).get("type", "")) != "town"):
			continue
		if float(l["length"]) >= float(setting("min_length")):
			out.append(i)
	return out


## The hours of the world clock since it began (a day is 24).
static func hours(d: GameDynasty) -> float:
	return GameDay.seconds(d) / float(GameDay.setting("day_seconds")) * 24.0


## The hours a trip along a link takes.
static func trip_hours(link: Dictionary) -> float:
	return float(link["length"]) / float(setting("tiles_per_hour"))


## The hours of the whole round: there, the wait, back, the wait.
static func cycle_hours(link: Dictionary) -> float:
	return 2.0 * (trip_hours(link) + float(setting("rest_hours")))


## How far into its round a caravan is at an hour (0 up to the cycle), its start keyed on the seed and the road.
static func clock_at(d: GameDynasty, index: int, hour: float) -> float:
	var l: Dictionary = GameRoads.links()[index]
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "caravan", index])
	var offset := r.randf() * maxf(float(setting("depart_hours")), cycle_hours(l))
	return fposmod(hour + offset, cycle_hours(l))


## Where a caravan is at an hour: {on_road (it is out walking), x, z (tiles, the middle of its tile), dx (+1 heading east, -1 west, 0 straight
## south or north), from, to (the place ids)}. When it is waiting in a town `on_road` is false and x and z are the town's centre.
static func state(d: GameDynasty, index: int, hour: float) -> Dictionary:
	var l: Dictionary = GameRoads.links()[index]
	var trip := trip_hours(l)
	var rest := float(setting("rest_hours"))
	var t := clock_at(d, index, hour)
	var a := Vector2(float(l["ax"]), float(l["az"]))
	var b := Vector2(float(l["bx"]), float(l["bz"]))
	var forward := t < trip + rest
	if t >= trip + rest:
		t -= trip + rest
	var walking := t < trip
	var share := clampf(t / trip, 0.0, 1.0)
	var from := a if forward else b
	var to := b if forward else a
	var at := from.lerp(to, share) if walking else to
	return {"on_road": walking, "x": at.x + 0.5, "z": at.y + 0.5, "dx": signi(int(round(to.x - from.x))) if walking else 0,
		"from": str(l["a"] if forward else l["b"]), "to": str(l["b"] if forward else l["a"]), "index": index}


## Whether a walking caravan is out in the open, not inside a town's wall.
static func out_in_the_open(st: Dictionary) -> bool:
	if not bool(st["on_road"]):
		return false
	var p := Vector2(float(st["x"]), float(st["z"]))
	for id in [st["from"], st["to"]]:
		var a := GameWorldGen.anchor(str(id))
		if p.distance_to(Vector2(float(a["x"]), float(a["z"]))) < GameRoads._ground(str(id)) + 1.0:
			return false
	return true


## The caravans out in the open now: [state] for each road that has one.
static func out(d: GameDynasty) -> Array:
	var res: Array = []
	var h := hours(d)
	for i in routes():
		var st := state(d, int(i), h)
		if out_in_the_open(st):
			res.append(st)
	return res


## The caravans out in the open within a rectangle of tiles (what the screen draws).
static func in_rect(d: GameDynasty, rect: Rect2i) -> Array:
	var res: Array = []
	for st in out(d):
		if rect.has_point(Vector2i(floori(float(st["x"])), floori(float(st["z"])))):
			res.append(st)
	return res


## The nearest caravan within `reach` tiles of a point, or {}.
static func near(d: GameDynasty, fx: float, fz: float, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach + 0.001
	for st in out(d):
		var dist := Vector2(float(st["x"]), float(st["z"])).distance_to(Vector2(fx, fz))
		if dist < best_d:
			best_d = dist
			best = st
	return best


## The caravan as a landmark of GameWildsTrade's kind (the merchant panel's `landmark`): its id is the road's, so what the family buys
## stays bought for the period; its stock is that of the town it set out from.
static func landmark(st: Dictionary) -> Dictionary:
	var l: Dictionary = GameRoads.links()[int(st["index"])]
	return {"id": PREFIX + str(int(st["index"])), "kind": KIND, "x": floori(float(st["x"])), "z": floori(float(st["z"])), "area": str(l["a"]),
		"biome": GameWorldGen.anchor(str(l["a"])).get("biome", "plains"), "name": GameRoads.text("caravan_name")}


## Use beside a caravan: {ok, text, open "merchant", landmark} (the screen opens the panel), or {} when none is near.
static func use(d: GameDynasty, fx: float, fz: float) -> Dictionary:
	var st := near(d, fx, fz, float(setting("reach")))
	if st.is_empty():
		return {}
	return {"ok": true, "text": GameRoads.text("caravan_use"), "open": "merchant", "landmark": landmark(st)}
