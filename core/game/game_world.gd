## The world layer: places, roads, the calendar, weather and what the family has mapped.
## Pure data + rules; the dynasty owns one GameWorld and advances it as time passes.
class_name GameWorld
extends RefCounted

var location: String = ""
var year: float = 0.0            # years since the dynasty was founded
var weather_id: String = "clear"
var visited: Array = []          # places a family member has walked
var charted: Array = []          # places known from bought maps


static func create(rng: RandomNumberGenerator) -> GameWorld:
	var w := GameWorld.new()
	w.location = GameData.world["start"]
	w.visited = [w.location]
	w.roll_weather(rng)
	return w


# ---------------------------------------------------------------- calendar & weather

func season_index() -> int:
	return int(fposmod(year, 1.0) * 4.0) % 4


func season() -> Dictionary:
	return GameData.world["seasons"][season_index()]


func weather() -> Dictionary:
	for w in GameData.world["weather"]:
		if w["id"] == weather_id:
			return w
	return GameData.world["weather"][0]


## Combat modifier from the weather (dodge, crit, flee, mp_regen); 0 when none.
func combat_mod(key: String) -> float:
	return float(weather().get("combat", {}).get(key, 0.0))


func roll_weather(rng: RandomNumberGenerator) -> void:
	var sid: String = season()["id"]
	var total := 0.0
	for w in GameData.world["weather"]:
		total += float(w["weights"].get(sid, 0))
	var roll := rng.randf() * total
	for w in GameData.world["weather"]:
		roll -= float(w["weights"].get(sid, 0))
		if roll < 0.0:
			weather_id = w["id"]
			return


## Time passes: the calendar moves on and the weather turns.
func advance(years: float, rng: RandomNumberGenerator) -> void:
	year += years
	roll_weather(rng)


func date_text() -> String:
	return "%s of year %s" % [season()["name"], GameText.num(int(year) + 1)]


# ---------------------------------------------------------------- places & roads

static func place(id: String) -> Dictionary:
	for l in GameData.world["locations"]:
		if l["id"] == id:
			return l
	return {}


func here() -> Dictionary:
	return place(location)


func is_town() -> bool:
	return here().get("type", "") == "town"


func has_service(service: String) -> bool:
	return service in here().get("services", [])


## Roads out of `from` that are open given the dynasty's flags: [{to, years, requires_flag?}].
func roads(from: String, flags: Dictionary) -> Array:
	var out: Array = []
	for link in place(from).get("links", []):
		var need: String = link.get("requires_flag", "")
		if need == "" or flags.has(need):
			out.append(link)
	return out


func travel_years(link: Dictionary) -> float:
	return float(link["years"]) * float(weather().get("travel", 1.0))


## Shortest open route (by road time) to `target`, as a list of place ids after the current one.
func route_to(target: String, flags: Dictionary) -> Array:
	var dist := {location: 0.0}
	var prev := {}
	var open: Array = [location]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if cur == target:
			break
		for link in roads(cur, flags):
			var nd: float = dist[cur] + float(link["years"])
			if not dist.has(link["to"]) or nd < dist[link["to"]]:
				dist[link["to"]] = nd
				prev[link["to"]] = cur
				if link["to"] not in open:
					open.append(link["to"])
	if not prev.has(target):
		return []
	var path: Array = [target]
	while prev[path[0]] != location:
		path.push_front(prev[path[0]])
	return path


# ---------------------------------------------------------------- fog of war

func visit(id: String) -> void:
	location = id
	if id not in visited:
		visited.append(id)


func chart(ids: Array) -> int:
	var added := 0
	for id in ids:
		if id not in charted and id not in visited:
			charted.append(id)
			added += 1
	return added


## "visited", "charted", "seen" (a road leads there from somewhere walked) or "unknown".
func knowledge(id: String) -> String:
	if id in visited:
		return "visited"
	if id in charted:
		return "charted"
	for v in visited:
		for link in place(v).get("links", []):
			if link["to"] == id:
				return "seen"
	return "unknown"


func maps_for_sale() -> Array:
	var out: Array = []
	for m in GameData.world.get("maps", []):
		if location in m["sold_at"]:
			out.append(m)
	return out


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	return {"location": location, "year": year, "weather_id": weather_id, "visited": visited, "charted": charted}


static func from_dict(d: Dictionary) -> GameWorld:
	var w := GameWorld.new()
	w.location = d["location"]
	w.year = float(d["year"])
	w.weather_id = d["weather_id"]
	w.visited = Array(d["visited"])
	w.charted = Array(d["charted"])
	return w
