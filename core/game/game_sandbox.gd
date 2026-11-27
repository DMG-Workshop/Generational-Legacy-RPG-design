## The open world as it runs (roadmap items 39, 45, 48, 49, 50, 52): the heir walks the generated ground, creatures are kept
## round them (spawned as the heir comes near, let go when they fall far behind), the companions follow or work by their
## orders, and the family digs and builds. Pure rules, no screen: the screen calls these and draws what they hold.
## Nothing here is saved and no die of the dynasty's is drawn; the heir starts where the text game has them. The autopilot
## never calls it, so a seeded life is unchanged.
## Run: godot --headless --path . -s res://tests/test_game_sandbox.gd
class_name GameSandbox
extends RefCounted

const PATH := "res://data/world/sandbox.json"
static var _cache: Dictionary = {}

var d: GameDynasty
var heir := Vector2i.ZERO          # the heir's tile on the open world
var creatures: Array = []          # GameBehaviour agents
var companions: Array = []         # GameCompanions agents
var tick := 0
var next_uid := 1
var log: Array = []                # {kind, text} lines for the screen, oldest first
var route: Array = []              # tiles still to walk to (set by set_route), the next one first
var space := "world"               # where the heir is: the open world, or the id of an interior they have gone into (never saved)
var outside := Vector2i.ZERO       # the open-world tile to come back to when the heir goes out of an interior
var interior: Dictionary = {}      # the cells of the interior the heir is in (GameInterior.cells), {} on the open world
var denizens: Array = []           # the creatures of the dungeon the heir is in (GameBehaviour agents with a key, room and boss flag), never saved
var fight_foes: Array = []         # the dungeon creatures in the fight now on, for after_fight
var fight_site: Dictionary = {}    # the landmark of the wilds whose guards are the fight now on ({} for none), for after_fight (GameWildsFights)
var armed: Dictionary = {}         # landmarks whose approach has already set their guards on the heir this visit (id -> their range); runtime only
var heir_y := GameBuild.SURFACE    # the heir's layer: the surface, or a storey above it (-2 and up); never saved, a visit starts on the ground
var walk_goal := Vector2i(-1, -1)  # the tile a walk in legs is going to (GameTravel.walk), (-1, -1) for none; never saved
var walk_place := ""               # the town that walk is for
var walk_replans := 0              # how many times it has been planned again after being stopped
var _occupied := {}                # "x,z" -> true, the tiles a creature stands on at spawn time


## A sandbox for a dynasty, with the heir where the text game has them and the world kept round them.
static func start(dyn: GameDynasty) -> GameSandbox:
	var s := GameSandbox.new()
	s.d = dyn
	var w := GameSpaces.where(dyn)
	var t := Vector2i(int(w["x"]), int(w["z"]))
	if t.x < 0 or t.y < 0:
		var a := GameWorldGen.anchor(dyn.world.location)
		t = Vector2i(int(a.get("x", 0)), int(a.get("z", 0)))
	var back := s._remembered()
	if back != Vector2i(-1, -1):
		t = back
	var got_away := false
	if not dyn.sandbox_escape.is_empty() and dyn.battle == null:
		# A fight the heir fled from: they come back to the open world clear of it, not beside the creature.
		t = Vector2i(int(dyn.sandbox_escape["x"]), int(dyn.sandbox_escape["z"]))
		dyn.sandbox_escape = {}
		got_away = true
	s.heir = t
	s.companions = GameCompanions.agents_for(dyn, float(t.x) + 0.5, float(t.y) + 0.5)
	s.refresh()
	if got_away:
		s.log.append({"kind": "fight", "text": s._text("escaped", {"heir": dyn.heir.name})})
	return s


## The saved position, checked: whole numbers inside the world, a generation and a place name; {} when anything is missing or
## of the wrong kind (a damaged save never crashes the load).
static func load_at(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	for k in ["x", "z", "gen"]:
		if not v.has(k) or typeof(v[k]) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(v[k])) or is_inf(float(v[k])):
			return {}
	if not v.has("place") or typeof(v["place"]) != TYPE_STRING:
		return {}
	var x := int(v["x"])
	var z := int(v["z"])
	if not GameWorldGen.in_bounds(x, z):
		return {}
	return {"x": x, "z": z, "gen": int(v["gen"]), "place": str(v["place"])}


## Where the heir stood last time, if that still holds: the same heir (generation) at the same place of the text game, on a
## tile they can stand on. (-1, -1) when there is none, and the heir starts at the place's door as before.
func _remembered() -> Vector2i:
	var at := d.sandbox_at
	if at.is_empty() or int(at["gen"]) != d.gen or str(at["place"]) != str(d.world.location):
		return Vector2i(-1, -1)
	var t := Vector2i(int(at["x"]), int(at["z"]))
	if not GamePath.passable(GamePath.world_ground(d), Vector3i(t.x, -1, t.y), {"water": false, "ignore_blocks": false}):
		return Vector2i(-1, -1)
	return t


## Writes where the heir stands onto the dynasty, to be saved with it. Upstairs it keeps the last place on the ground, because
## the storey is not saved and a column of floors is not a place to start from.
func remember() -> void:
	if heir_y != GameBuild.SURFACE or space != "world":
		return
	d.sandbox_at = {"x": heir.x, "z": heir.y, "gen": d.gen, "place": str(d.world.location)}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


func heir_point() -> Vector2:
	return Vector2(float(heir.x) + 0.5, float(heir.y) + 0.5)


## Which storey the heir is on: 0 is the ground, 1 and up are above it.
func storey() -> int:
	return GameBuild.SURFACE - heir_y


## "Upstairs, storey 1." while above the ground, else the room the heir is in (or "").
func place_line() -> String:
	if space != "world":
		var name := str(GameSpaces.space(space).get("name", space))
		var who := GamePeople.near(space, heir.x, heir.y)
		if not who.is_empty() and heir != GameInterior.entry():
			return GamePeople.text("near", {"name": str(who["name"])})
		var room := GameInterior.room_at(space, heir.x, heir.y)
		if room == "":
			return _text("inside_in", {"place": name})
		var room_name := room
		for r in GameSpaces.rooms(space):
			if str(r["id"]) == room:
				room_name = str(r["name"])
		return _text("inside_at", {"place": name, "room": room_name.to_lower()})
	var line := GameBuild.room_line(d, heir.x, heir.y, heir_y)
	if storey() > 0:
		line = _text("upstairs_at", {"n": storey()}) if line == "" else "%s %s" % [_text("upstairs_at", {"n": storey()}), line]
	var u := GameBuild.room_use(d, heir.x, heir.y, heir_y)
	if u.is_empty() and storey() == 0:
		var stall_hint := GameNightLife.stall_hint(d, heir.x, heir.y)
		if stall_hint != "":
			return stall_hint if line == "" else "%s %s" % [line, stall_hint]
		var trial_site := GameTrials.site_hint(d, heir.x, heir.y)
		if trial_site != "":
			return trial_site if line == "" else "%s %s" % [line, trial_site]
		var site := GameWildsSites.hint(d, heir.x, heir.y)
		if site != "":
			return site if line == "" else "%s %s" % [line, site]
	return line if u.is_empty() else "%s %s" % [line, str(u["hint"])]


## Whether the heir can step onto a tile: a neighbour in the open world, dry and not blocked (a tree, a rock outcrop, a wall).
func can_step(dx: int, dz: int) -> Dictionary:
	if absi(dx) > 1 or absi(dz) > 1 or (dx == 0 and dz == 0):
		return {"ok": false, "why": _text("not_a_step")}
	var to := heir + Vector2i(dx, dz)
	if space != "world":
		# Indoors the heir walks the floor, a tile at a time, never cutting a corner of a wall.
		var diagonal := dx != 0 and dz != 0
		if not GameInterior.passable(interior, to.x, to.y) or (diagonal and not (GameInterior.passable(interior, heir.x + dx, heir.y) and GameInterior.passable(interior, heir.x, heir.y + dz))):
			return {"ok": false, "why": _text("blocked")}
		return {"ok": true, "why": ""}
	if not GameWorldGen.in_bounds(to.x, to.y):
		return {"ok": false, "why": _text("edge")}
	var ground := GamePath.world_ground(d)
	if storey() > 0:
		# On a storey the heir walks the same rules as everything else (GamePath): built floors, no cutting a corner.
		var here := Vector3i(heir.x, heir_y, heir.y)
		for nb in GamePath.neighbours(ground, here, GamePath.data()["movers"]["walker"]):
			if nb[0] == Vector3i(to.x, heir_y, to.y):
				return {"ok": true, "why": ""}
		return {"ok": false, "why": _text("blocked")}
	if not GamePath.passable(ground, Vector3i(to.x, -1, to.y), {"water": false, "ignore_blocks": false}):
		return {"ok": false, "why": _text("blocked")}
	return {"ok": true, "why": ""}


## The heir takes one step. The creatures and companions catch up with the new place.
func move(dx: int, dz: int) -> Dictionary:
	var c := can_step(dx, dz)
	if not c["ok"]:
		return c
	if space == "world":
		_leave_print(heir)
	heir += Vector2i(dx, dz)
	_arrive()
	GameTravel.after_step(self)   # a pin the heir has come to comes off
	refresh()
	if space != "world":
		_dungeon_arrive()
	return {"ok": true, "why": ""}


## Walking into a place's ground (a town or the wilds round an anchor) is arriving there: the family's place becomes it, as a
## journey on the map would make it, but with no years spent (the open world has its own clock), no arrival event and no dice.
## The place is marked visited and its quests told. Leaving it for open ground changes nothing: the family is still at the last
## place walked into. Only on the ground of the open world.
func _arrive() -> void:
	if space != "world" or heir_y != GameBuild.SURFACE:
		return
	var place := str(GameSpaces.space(GameSpaces.at_tile(heir.x, heir.y)).get("place", ""))
	if place == "" or place == str(d.world.location) or GameWorld.place(place).is_empty():
		return
	var dest: Dictionary = GameWorld.place(place)
	var first: bool = place not in d.world.visited
	d.world.visit(place)
	var line := _text("arrived", {"heir": d.heir.name, "place": str(dest["name"])})
	log.append({"kind": "arrive", "text": line})
	if first:
		log.append({"kind": "arrive", "text": GameMessages.text("life", "no_one_walked", {"house": d.dynasty_name, "dest": dest["name"], "description": dest.get("description", "")})})
	var msgs: Array = []
	d.quests.on_arrive(d, place, msgs)
	for m in msgs:
		log.append({"kind": "arrive", "text": str(m)})
	arrived = place


## The place the heir has just walked into, until the screen has said so (runtime only).
var arrived := ""


## The crowd settings must make sense: a share above 0 and up to 1, a safe distance of 0 or more, at least one creature at a time and one
## appearing at a time.
static func validate() -> Array:
	var bad: Array = []
	var s: Dictionary = data()["settings"]
	for k in ["spawn_share", "spawn_safe", "max_creatures", "spawn_burst"]:
		if not s.has(k):
			bad.append("sandbox.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["spawn_share"]) <= 0.0 or float(s["spawn_share"]) > 1.0:
		bad.append("sandbox.json: spawn_share must be above 0 and at most 1")
	if float(s["spawn_safe"]) < 0.0 or float(s["spawn_safe"]) > float(s["radius"]):
		bad.append("sandbox.json: spawn_safe must be 0 up to the spawn radius")
	if int(s["max_creatures"]) < 1 or int(s["spawn_burst"]) < 1:
		bad.append("sandbox.json: max_creatures and spawn_burst must be at least 1")
	for k in ["spawn_rest_seconds", "spawn_town_margin"]:
		if not s.has(k) or typeof(s[k]) not in [TYPE_INT, TYPE_FLOAT] or float(s[k]) < 0.0:
			bad.append("sandbox.json: settings.%s must be a number of 0 or more" % k)
	bad.append_array(GameLevels.validate())
	bad.append_array(GameSmoke.validate())
	var mm: Variant = data().get("minimap")
	if typeof(mm) != TYPE_DICTIONARY:
		bad.append("sandbox.json: minimap (the colours of a town's buildings, wall and gates) is missing")
	else:
		for k in ["building", "city_wall", "gate"]:
			var col: Variant = (mm as Dictionary).get(k)
			if typeof(col) != TYPE_ARRAY or (col as Array).size() != 3:
				bad.append("sandbox.json: minimap.%s needs a colour [r, g, b]" % k)
	return bad


## The world-clock second before which `refresh` spawns nothing new: set when a fight ends (runtime only, never saved).
var rest_until := 0.0


## Whether a tile is inside a town: within the town's wall ring (plus `spawn_town_margin`), on its cleared ground or in any area's
## ground (GameSpaces.at_tile). Nothing spawns there.
static func in_town(x: int, z: int) -> bool:
	if GameWalls.cleared(x, z):
		return true
	for place in GameWalls.walled():
		var a := GameWorldGen.anchor(str(place))
		if Vector2(x - int(a["x"]), z - int(a["z"])).length() <= GameWalls.radius(str(place)) + float(setting("spawn_town_margin")):
			return true
	return GameSpaces.at_tile(x, z) != GameSpaces.root_id()


## The band id of a creature of `level` against the heir (trivial, easy, even, hard or deadly).
func con(level: int) -> String:
	return GameLevels.con(level, d.heir.level)


## The level of a creature agent, 0 for one made without a level (a dungeon's: its fights keep the old rules).
static func level_of(a: Dictionary) -> int:
	return int(a.get("level", 0))


## Spawns the creatures the world has in the square round the heir and lets go of those far behind.
func refresh() -> void:
	if space != "world":
		return   # nothing lives or spawns indoors
	if storey() == 0:
		for lm in GameWildsSites.discover_near(d, heir.x, heir.y):
			log.append({"kind": "site", "text": GameWilds.text("found", {"heir": d.heir.name, "name": GameWildsSites.name_of(lm)})})
		for gid in GameGates.discover_near(d, heir.x, heir.y):
			log.append({"kind": "site", "text": GameGates.text("gate_found", {"heir": d.heir.name, "name": GameGates.name_of(str(gid))})})
		GameGates.tend(d)
	var night := GameDay.is_night(d)
	var radius := int(setting("radius"))
	var kept: Array = []
	for a in creatures:
		if _distance(a, heir) <= radius + int(setting("keep")):
			kept.append(a)
	creatures = kept
	_occupied.clear()
	for a in creatures:
		_occupied[_key(int(floor(float(a["x"]))), int(floor(float(a["z"]))))] = true
	# What the ground would spawn is thinned out: only `spawn_share` of the tiles that roll a creature keep it (a roll keyed on the tile,
	# so the same ground always holds the same few), none starts within `spawn_safe` of the heir, no more than `max_creatures`
	# live at once, and no more than `spawn_burst` appear at a time (the rest come in as the heir walks on), the ones the tile rolls favour first. Nothing here draws the dynasty's dice.
	var share := float(setting("spawn_share"))
	var safe := float(setting("spawn_safe"))
	var room := int(setting("max_creatures")) - creatures.size()
	if room <= 0 or d.world_seconds < rest_until:
		return   # a full crowd, or the breather after a fight: nothing new comes
	var found: Array = []   # [roll, x, z, id]
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := heir.x + dx
			var z := heir.y + dz
			var k := _key(x, z)
			if _occupied.has(k) or not GameWorldGen.in_bounds(x, z):
				continue
			if Vector2(dx, dz).length() < safe:
				continue
			var id := GameSpawn.spawn_at(d, x, -1, z, 0, night)
			if id == "":
				continue
			var keep_roll := RandomNumberGenerator.new()
			keep_roll.seed = hash([d.seed_value, "spawn_share", x, z])
			var r := keep_roll.randf()
			if r >= share:
				continue
			if in_town(x, z) or GameSmoke.covers(d, float(x) + 0.5, float(z) + 0.5):
				continue   # none within a town's walls or cleared ground, and none in a smoke pot's cloud
			found.append([r, x, z, id])
	found.sort_custom(func(p, q): return p[0] < q[0])
	for i in mini(mini(room, int(setting("spawn_burst"))), found.size()):
		var f: Array = found[i]
		var agent := GameBehaviour.new_agent(next_uid, str(f[3]), float(f[1]) + 0.5, float(f[2]) + 0.5)
		agent["level"] = GameLevels.level_for(d, int(f[1]), int(f[2]))   # its own level, a pure function of the seed, the tile and the heir's level (GameLevels)
		creatures.append(agent)
		next_uid += 1
		_occupied[_key(int(f[1]), int(f[2]))] = true


## How the weather scales the seconds between the heir's steps on foot: 1 in clear weather, above 1 in snow (data/world/weather_effects.json).
## The sandbox screen multiplies its walk and run pace by it; nothing else in the open world's rules does.
func step_pace() -> float:
	return GameWeatherFx.walk_mult(d) if space == "world" else 1.0


## The tiles the heir has crossed in snow, newest last, as {x, z, at (world seconds)}: only the look (the screen draws them), never saved.
var prints: Array = []


## Notes a footprint on the tile the heir leaves, when the weather leaves them.
func _leave_print(from: Vector2i) -> void:
	if not GameWeatherFx.prints_now(d):
		if not prints.is_empty():
			prints.clear()
		return
	prints.append({"x": from.x, "z": from.y, "at": d.world_seconds})
	var keep := int(GameWeatherFx.setting("max_prints"))
	if prints.size() > keep:
		prints = prints.slice(prints.size() - keep)


## The interior whose door is on the tile the heir stands on ("" when there is none): a dungeon's door on the open world, a
## town service's or the family house's in its town. Only from the open world's ground floor.
func door_here() -> String:
	if space != "world" or storey() > 0:
		return ""
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior":
			var door: Dictionary = GameSpaces.space(id).get("door", {})
			if int(door.get("x", -1)) == heir.x and int(door.get("z", -1)) == heir.y:
				return id
	return ""


## Goes in by the door the heir stands at: the heir is on the interior's floor at its entrance, the open world waits. {ok, text}.
func enter() -> Dictionary:
	var id := door_here()
	if id == "":
		return {"ok": false, "text": _text("no_door")}
	var cells := GameInterior.cells(id)
	if cells.is_empty():
		return {"ok": false, "text": _text("no_door")}
	outside = heir
	walk_goal = GameTravel.NONE
	space = id
	interior = GameDungeons.walk_cells(id, d) if GameDungeons.is_dungeon(id) else cells
	heir = GameInterior.entry()
	route = []
	denizens = _spawn_denizens(id) if GameDungeons.is_dungeon(id) else []
	if GameDungeons.is_dungeon(id):
		companions = _seat_companions()
	fight_foes = []
	var line := _text("entered", {"heir": d.heir.name, "place": str(GameSpaces.space(id).get("name", id)).to_lower()})
	log.append({"kind": "door", "text": line})
	return {"ok": true, "text": line}


## Goes out by the entrance, back to the door on the open world. {ok, text}.
func leave() -> Dictionary:
	if space == "world":
		return {"ok": false, "text": _text("no_door")}
	if heir != GameInterior.entry():
		return {"ok": false, "text": _text("no_exit")}
	var from_dungeon := GameDungeons.is_dungeon(space)
	space = "world"
	interior = {}
	denizens = []
	fight_foes = []
	if from_dungeon:   # the party comes out with the heir, to stand beside the door
		companions = GameCompanions.agents_for(d, float(outside.x) + 0.5, float(outside.y) + 0.5)
	heir = outside
	route = []
	refresh()
	var line := _text("left", {"heir": d.heir.name})
	log.append({"kind": "door", "text": line})
	return {"ok": true, "text": line}


## The refusal for using a gate from where the heir is, or "": a fight, indoors, upstairs.
func gate_block() -> String:
	if d.battle != null or not d.pending_event.is_empty():
		return GameGates.text("refuse_fight")
	if space != "world":
		return GameGates.text("refuse_inside")
	if storey() > 0 or heir_y != GameBuild.SURFACE:
		return GameGates.text("refuse_up")
	return ""


## Stands at a gate and steps through it to another gate of its road (`dest` a gate id) or into the realm it is the door of (`dest` "realm:<id>"):
## the charge of a flickering arch is paid, the trip takes world-clock seconds by distance (GameClock.feed, so the years run as they always do),
## and the heir comes out on the open tile in front of the far gate with the companions who follow beside them, the creatures of the old place
## left behind and the new place arrived at (`_arrive`). No dice of the dynasty's are drawn. {ok, text, lines?}.
func step_through(gate: String, dest: String) -> Dictionary:
	if not GameGates.has(gate):
		return {"ok": false, "text": GameGates.text("no_gate")}
	var block := gate_block()
	if block != "":
		return {"ok": false, "text": block}
	if GameGates.near(d, heir.x, heir.y) != gate:
		return {"ok": false, "text": GameGates.text("far", {"heir": d.heir.name})}
	var plan := GameGates.travel_plan(d, gate, dest)
	if not bool(plan["ok"]):
		return {"ok": false, "text": str(plan["why"])}
	var paid := GameGates.pay_charge(d, plan["charge"])
	var lines: Array = GameClock.feed(d, float(plan["seconds"]))
	if d.state != "life":   # the years of the trip ended the heir's life: the screen shows the succession
		return {"ok": true, "text": paid, "lines": lines, "ended": true}
	var line := ""
	if dest.begins_with("realm:"):
		line = _enter_realm(gate, dest.substr(6))
	else:
		var f := GameGates.front_of(d, dest)
		creatures = []
		_occupied.clear()
		route = []
		heir = f
		heir_y = GameBuild.SURFACE
		_seat_followers()
		refresh()
		_arrive()
		line = GameGates.text("stepped", {"heir": d.heir.name, "name": GameGates.name_of(gate), "dest": GameGates.name_of(dest), "place": GameGates.place_name(d, dest)})
	if paid != "":
		line += " " + paid
	log.append({"kind": "site", "text": line})
	d._say(line)
	return {"ok": true, "text": line, "lines": lines}


## The companions who follow come with the heir and stand beside them; one who holds a post (stay, guard, gather) keeps it.
func _seat_followers() -> void:
	var fresh := GameCompanions.agents_for(d, float(heir.x) + 0.5, float(heir.y) + 0.5)
	var out: Array = []
	for a in fresh:
		var id := str(a["id"])
		var kept: Dictionary = {}
		for old in companions:
			if str(old["id"]) == id and GameCompanions.order_of(d, id) != GameCompanions.FOLLOW:
				kept = old
		out.append(kept if not kept.is_empty() else a)
	companions = out


## Through a realm's gate into its arrival ground (GameGates.arrival_cells): a small walled clearing of the realm with the return gate on the
## tile the heir comes in on. The way back is the interior's usual way out, `leave()`, and it always works.
func _enter_realm(gate: String, realm: String) -> String:
	outside = GameGates.front_of(d, gate)
	space = GameGates.realm_space(realm)
	interior = GameGates.arrival_cells(realm)
	heir = GameInterior.entry()
	route = []
	denizens = []
	fight_foes = []
	return GameGates.text("realm_in", {"heir": d.heir.name, "name": GameGates.name_of(gate), "realm": GameRealms.name_of(realm)})


## The realm the heir is in ("" on the open world or in an ordinary interior).
func realm_here() -> String:
	return GameGates.realm_of_space(space)


## How fast the clock the heir lives by runs: the realm's flow while they are in a realm's arrival ground, else 1 (the screen scales what it feeds
## GameClock by this, so the time goes through pass_time as ever).
func time_flow() -> float:
	var r := realm_here()
	return 1.0 if r == "" else float(GameRealms.flow({"in_realm": r}))


## Casts one of the heir's spells on a dungeon's floor (GameCasting.self_cast): {ok, text, kind}. Only in a dungeon and out of a fight.
func cast(id: String) -> Dictionary:
	if space == "world" or not GameDungeons.is_dungeon(space) or d.battle != null:
		return {"ok": false, "text": GameCasting.text("self_unknown"), "kind": ""}
	var r := GameCasting.self_cast(d, id)
	log.append({"kind": "dungeon", "text": str(r["text"])})
	return r


## The Use action: out by the entrance of an interior; on the open world, in by a door, else what the room the heir stands in
## lets them do (a bedroom the family built: rest). {ok, text}.
func use() -> Dictionary:
	if space != "world":
		if heir != GameInterior.entry():
			var p := GamePeople.near(space, heir.x, heir.y)
			if not p.is_empty():
				var t := GamePeople.talk(d, space, p)
				log.append({"kind": "talk", "text": str(t["text"])})
				return t
			var rested := GameGoal.home_rest(self)   # the family house's bedroom: use it to rest (the guided start teaches it)
			if not rested.is_empty():
				return rested
			var thing := GameDungeons.thing_near(space, heir.x, heir.y, d)
			if not thing.is_empty():
				var u := GameDungeons.use_thing(d, space, thing)
				log.append({"kind": "dungeon", "text": str(u["text"])})
				if u.has("opened"):   # a door unlocked: it can be walked through now
					var oc: Vector2i = u["opened"]
					interior[GameInterior.key(oc.x, oc.y)] = "door"
				for c in u["dirty"]:
					dirty.append(c)
				return u
		return leave()
	if door_here() != "":
		return enter()
	if storey() == 0:
		var who := GameTalk.beside(d, heir, GameDay.hour(d))
		if not who.is_empty():
			var t := GameTalk.talk(d, who, GameDay.hour(d))
			log.append({"kind": "talk", "text": str(t["text"])})
			return t
		var stall := GameNightLife.stall_near(d, heir.x, heir.y)   # the day's market stall: its trader's panel
		if not stall.is_empty():
			var st := GameNightLife.stall_use(d, stall)
			log.append({"kind": "site", "text": str(st["text"])})
			return st
	var u := GameBuild.room_use(d, heir.x, heir.y, heir_y)
	if u.is_empty():
		var trial_site := GameTrials.site_near(d, heir.x, heir.y) if storey() == 0 else {}
		if not trial_site.is_empty():   # a trial's master, at its site: the screen opens the Trials panel
			var spoke := GameTrials.site_use(d, str(trial_site["id"]))
			log.append({"kind": "site", "text": str(spoke["text"])})
			return spoke
		var gate := GameGates.near(d, heir.x, heir.y) if storey() == 0 else ""
		if gate != "":   # a waygate: the screen opens its panel (GatePanel); the world waits
			GameGates.tend(d)
			var gt := GameGates.hint(d, heir.x, heir.y)
			log.append({"kind": "site", "text": gt})
			return {"ok": true, "text": gt, "open": "gate", "gate": gate}
		var site := GameWildsSites.near(d, heir.x, heir.y) if storey() == 0 else {}
		if not site.is_empty():
			var r := GameWildsSites.use(d, site)
			log.append({"kind": "site", "text": str(r["text"])})
			if r.has("fight"):   # searching sprang the guards
				begin_landmark_fight(site, r["fight"])
			elif r.has("door"):   # an explored cave leads on: the heir comes out on the dungeon's door tile
				heir = Vector2i(int(r["door"]["x"]), int(r["door"]["z"]))
				route = []
				refresh()
			return r
		return {"ok": false, "text": GameBuild.text("nothing_to_use")}
	match str(u["kind"]):
		"keep":
			return {"ok": true, "text": GameBuild.text("kennel_holds", {"places": GameBuild.kennel_places(d), "kept": d.roster.size(), "cap": GameRoster.cap(d)})}
		"craft":
			# The screen opens the workshop for it (GameCraft with forge "home"); nothing changes here.
			return {"ok": true, "text": GameBuild.text("forge_lit"), "open": "workshop", "forge": "home"}
		"rest":
			var msgs := d.rest_for(float(u["years"]))
			for m in msgs:
				log.append({"kind": "rest", "text": str(m)})
			return {"ok": true, "text": str(msgs[0]) if not msgs.is_empty() else ""}
	return {"ok": false, "text": GameBuild.text("nothing_to_use")}


## What stands at a point of the open world, for the screen to name when it is clicked: {kind, name}, or {} for bare ground. The
## nearest of the heir, a creature, a companion, someone out of doors, a landmark of the wilds and a building of a town, within
## `name_reach` tiles (sandbox.json). Pure: nothing changes and no die is drawn.
func name_at(fx: float, fz: float) -> Dictionary:
	if space != "world":
		return {}
	var reach := float(setting("name_reach"))
	var here := Vector2(fx, fz)
	var found := {"best": {}, "dist": reach + 1.0}   # (a lambda changes what it is handed, not the variables around it)
	var consider := func(kind: String, nm: String, x: float, z: float, slack: float = 0.0, id: String = "", level: int = 0):
		var dist := maxf(0.0, Vector2(x, z).distance_to(here) - slack)
		if dist <= reach and dist < float(found["dist"]) and nm != "":
			found["dist"] = dist
			found["best"] = {"kind": kind, "name": nm, "id": id}
			if level > 0:
				found["best"]["level"] = level   # a creature's own level and how it stands against the heir's
				found["best"]["con"] = con(level)
	consider.call("heir", d.heir.name, float(heir.x) + 0.5, float(heir.y) + 0.5)
	if storey() == 0:
		for s in GameNightLife.stalls_in(d, Rect2i(floori(fx) - 2, floori(fz) - 2, 5, 5)):
			consider.call("person", GameNightLife.text("trader"), float(s["x"]) + 0.5, float(s["z"]) + 0.5)
	for a in creatures:
		var def := {}
		for c in GameData.creatures:
			if str(c["id"]) == str(a["id"]):
				def = c
		consider.call("creature", str(def.get("name", a["id"])), float(a["x"]), float(a["z"]), 0.0, str(a["id"]), level_of(a))
	for a in companions:
		var nm := ""
		for m in d.party.members:
			if str(m["id"]) == str(a["id"]):
				nm = str(m.get("name", a["id"]))
		consider.call("companion", nm, float(a["x"]), float(a["z"]), 0.0, str(a["id"]))
	if storey() == 0:
		for w in GameVillagers.walkers_near(d, fx, fz, reach + 1.0, GameDay.hour(d)):
			consider.call("person", str(w["job"]), float(w["x"]), float(w["z"]))
		if found["best"].is_empty():   # the ground itself, named only when no one stands on it
			for lm in GameWildsSites.within(d, fx, fz, reach + 2.0):
				consider.call("landmark", GameWildsSites.name_of(lm), float(lm["x"]) + 0.5, float(lm["z"]) + 0.5, 0.5)
		if found["best"].is_empty():
			var b := GameTown.at(int(floor(fx)), int(floor(fz)))
			if not b.is_empty():
				consider.call("building", _building_name(b), fx, fz)
	return found["best"]


## What the heir can do with a thing `name_at` found, for the popup the mouse opens over it: [{id, label}], in the order the data
## lists them (`thing_menu` in sandbox.json, labels in `text`). A companion also offers each order but the one it has. Pure: nothing
## here is done, the screen does what an id says. Empty for what is not a thing.
func thing_actions(named: Dictionary) -> Array:
	var out: Array = []
	if named.is_empty():
		return out
	var kind := str(named.get("kind", ""))
	for id in data()["thing_menu"].get(kind, []):
		out.append({"id": str(id), "label": _text("act_" + str(id))})
	if kind == "companion" and d.party.has_member(str(named.get("id", ""))):
		var now := str(d.party.member(str(named["id"])).get("order", GameCompanions.FOLLOW))
		for o in GameCompanions.ORDERS:
			if o != now:
				out.append({"id": "order:" + str(o), "label": _text("act_order", {"order": GameCompanions.order_name(str(o))})})
	return out


## Does what a companion's order action says (`order:<order>` for the thing's id): {ok, text}.
func give_order(named: Dictionary, action: String) -> Dictionary:
	if not action.begins_with("order:") or str(named.get("kind", "")) != "companion":
		return {"ok": false, "text": ""}
	return GameCompanions.set_order(d, str(named.get("id", "")), action.trim_prefix("order:"))


func _building_name(b: Dictionary) -> String:
	var kind := str(b["kind"]).replace("_", " ").capitalize()
	return kind


## The people who have spoken first today (their id -> the day) and when anyone last did (the world clock's seconds): runtime only,
## so a new visit may be greeted again. The decision itself is GameTalk's, a pure function of the seed, the person, the day and the tile.
var talk_seen := {}
var talk_last := GameTalk.NEVER


## Someone out in the town calls out to the heir (GameTalk.greeting): {who, text (their words), line (with their job), offers} and the
## greeting is noted, or {} when nobody does. Never indoors, upstairs, in a fight or with the heir fallen; the screen also holds it off
## while a panel is open.
func greeting() -> Dictionary:
	if space != "world" or storey() > 0 or d.battle != null or d.state != "life":
		return {}
	var g := GameTalk.greeting(d, heir, GameDay.hour(d), talk_seen, talk_last)
	if g.is_empty():
		return {}
	talk_seen[str(g["who"]["id"])] = GameDay.day_number(d)
	talk_last = GameDay.seconds(d)
	log.append({"kind": "talk", "text": str(g["line"])})
	return g


## Climbs from where the heir stands: `dir` -1 up (the cell must be stairs and the one above something to stand on), +1 down
## (the cell below must be stairs). The build level follows the heir. {ok, why}.
func climb(dir: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "why": _text("indoors")}
	var ground := GamePath.world_ground(d)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var here := Vector3i(heir.x, heir_y, heir.y)
	if dir < 0:
		if not GamePath._is_stairs(ground, here):
			return {"ok": false, "why": _text("no_stairs")}
		var up := Vector3i(heir.x, heir_y - 1, heir.y)
		if heir_y - 1 < GameBuild.top_y() or not GamePath.passable(ground, up, mover):
			return {"ok": false, "why": _text("stairs_blocked")}
		heir_y -= 1
	else:
		var below := Vector3i(heir.x, heir_y + 1, heir.y)
		if heir_y >= GameBuild.SURFACE or not GamePath._is_stairs(ground, below):
			return {"ok": false, "why": _text("stairs_bottom")}
		heir_y += 1
	route = []
	build_level = storey()
	var line := _text("climbed_up", {"heir": d.heir.name, "n": storey()}) if dir < 0 else (_text("climbed_down", {"heir": d.heir.name}) if storey() == 0 else _text("climbed_part", {"heir": d.heir.name, "n": storey()}))
	log.append({"kind": "climb", "text": line})
	return {"ok": true, "why": "", "text": line}


## If the floor the heir stands on has gone, they drop to the ground (to the nearest tile they can stand on, if a wall is there).
func check_footing() -> void:
	if heir_y == GameBuild.SURFACE:
		return
	var ground := GamePath.world_ground(d)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var cell := Vector3i(heir.x, heir_y, heir.y)
	if GamePath.passable(ground, cell, mover) and not GamePath._built_kind(ground, cell).is_empty():
		return
	heir_y = GameBuild.SURFACE
	build_level = 0
	route = []
	if not GamePath.passable(ground, Vector3i(heir.x, GameBuild.SURFACE, heir.y), mover):
		for r in range(1, 5):
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) == r and GamePath.passable(ground, Vector3i(heir.x + dx, GameBuild.SURFACE, heir.y + dz), mover):
						heir += Vector2i(dx, dz)
						log.append({"kind": "climb", "text": _text("fell", {"heir": d.heir.name})})
						refresh()
						return
	log.append({"kind": "climb", "text": _text("fell", {"heir": d.heir.name})})


## One tick of the open world: the creatures act, then the companions (told of the creatures near them), and their events
## go to the log.
func step(ticks: int = 1) -> void:
	for _i in ticks:
		tick += 1
		if space != "world":
			_dungeon_tick()
			continue   # the open world is outside: its creatures and companions wait
		check_footing()
		var night := GameDay.is_night(d)
		var threats := _threats()
		if GameSmoke.clear_if_out(d):
			log.append({"kind": "smoke", "text": GameSmoke.text("thinned")})
		var hidden := GameSmoke.covers(d, heir_point().x, heir_point().y)   # a heir inside the cloud is not seen from outside it
		var cview := GameWeatherFx.apply(d, GameBehaviour.world_view(d, [] if hidden else [{"x": heir_point().x, "z": heir_point().y}], night))   # with the weather's sight, speeds and shelter
		creatures = GameBehaviour.step_all(creatures, cview, d.seed_value, tick)
		creatures = _smoke_drives(creatures, cview)
		if _contact():
			return
		if _landmark_approach():
			return
		companions = GameCompanions.reconcile(d, companions, heir_point().x, heir_point().y)
		GamePath.sync(path_cache, d)
		var router := GamePath.cached_router(GamePath.world_ground(d), path_cache)
		var out := GameCompanions.step_all(d, companions, GameCompanions.view(d, heir_point().x, heir_point().y, threats, router), tick)
		companions = out["agents"]
		for e in out["events"]:
			if str(e["type"]) == "engage":
				_guard_fights(e)
				continue
			log.append({"kind": "companion", "text": GameCompanions.event_text(e)})
			if str(e.get("type", "")) == "gathered":
				dirty.append(Vector2i(int(e["x"]), int(e["z"])))
		var keep_lines := int(setting("log_lines"))
		if log.size() > keep_lines:
			log = log.slice(log.size() - keep_lines)


## Tiles whose look has changed since the screen last drew them (a node gathered, a shaft dug), for it to redraw (runtime only).
var dirty: Array = []


## The companions' step cache (runtime only): their routes are found once for each (from, to) while the ground holds.
var path_cache := GamePath.new_cache()


## The cache's line for a pathing readout.
func path_line() -> String:
	return GamePath.cache_line(path_cache)


## A guard is at the creature it went out to meet (`engage`): they fight (GameCompanions.duel). A win drives the creature out of
## the world (the next `refresh` may bring another of its place back) and the family gets a share of its gold; a loss leaves the
## guard hurt and resting at their post (`rest_until`) and the creature where it is; a guard too hurt to fight says so and rests.
func _guard_fights(e: Dictionary) -> void:
	var at := Vector2(float(e["x"]), float(e["z"]))
	var hit := -1
	var best := INF
	for i in creatures.size():
		var a: Dictionary = creatures[i]
		var dist := Vector2(float(a["x"]), float(a["z"])).distance_to(at)
		if dist < best and dist <= 1.0:
			best = dist
			hit = i
	if hit < 0:
		return
	var id := str(e["id"])
	var r := GameCompanions.duel(d, id, str(creatures[hit]["id"]), tick)
	if r.is_empty():
		return
	var name := str(d.party.member(id).get("name", id))
	var foe := str(r["foe"]).to_lower()
	for c in companions:
		if str(c["id"]) == id and (not bool(r["won"])):
			c["rest_until"] = tick + int(GameCompanions.setting("guard_rest_ticks"))
	if bool(r["refused"]):
		log.append({"kind": "guard", "text": GameCompanions.text("guard_too_hurt", {"name": name, "foe": foe})})
	elif bool(r["won"]):
		creatures.remove_at(hit)
		var key := "guard_won_gold" if int(r["gold"]) > 0 else "guard_won"
		log.append({"kind": "guard", "text": GameCompanions.text(key, {"name": name, "foe": foe, "gold": int(r["gold"])})})
	else:
		log.append({"kind": "guard", "text": GameCompanions.text("guard_hurt", {"name": name, "foe": foe})})


## Plans a walk from the heir to a tile of the open world over the ground as it is now (GamePath, a walker). Sets the
## route when found and returns {ok, why, steps}; the heir then walks it one tile at a time with `walk_one`.
func set_route(target: Vector2i) -> Dictionary:
	route = []
	walk_goal = GameTravel.NONE   # a route of its own ends a walk in legs
	if space != "world":
		return {"ok": false, "why": _text("indoors"), "steps": 0}
	if storey() > 0:
		return {"ok": false, "why": _text("upstairs_route"), "steps": 0}
	if target == heir:
		return {"ok": true, "why": "", "steps": 0}
	if not GameWorldGen.in_bounds(target.x, target.y):
		return {"ok": false, "why": _text("edge"), "steps": 0}
	var found := GamePath.find(GamePath.world_ground(d), Vector3i(heir.x, -1, heir.y), Vector3i(target.x, -1, target.y),
		"walker", int(setting("route_nodes")))
	if not found["found"]:
		return {"ok": false, "why": _text("no_route"), "steps": 0}
	var path: Array = found["path"]
	for i in range(1, path.size()):
		route.append(Vector2i(path[i].x, path[i].z))
	return {"ok": true, "why": "", "steps": route.size()}


## The heir takes the next tile of the route. False when there is no route or the way is now blocked (the route is dropped).
func walk_one() -> bool:
	if route.is_empty():
		return false
	var next: Vector2i = route[0]
	var r := move(next.x - heir.x, next.y - heir.y)
	if not r["ok"]:
		route = []
		GameTravel.stalled(self)   # a walk in legs is planned again (a gate has shut), or given up
		return false
	route.pop_front()
	if route.is_empty() and walk_goal != GameTravel.NONE:
		GameTravel.plan_next(self)   # the next leg of a walk in legs
	return true


## Ends any walk the heir is on: the route and the goal of a walk in legs.
func cancel_walk() -> void:
	route = []
	walk_goal = GameTravel.NONE
	walk_place = ""
	walk_replans = 0


## Pins a town and walks there (GameTravel.walk): {ok, text}.
func walk_there(place_id: String) -> Dictionary:
	return GameTravel.walk(self, place_id)


## Books a coach to a town for gold (GameTravel.book): {ok, text}. Draws no dice.
func book_travel(place_id: String) -> Dictionary:
	return GameTravel.book(self, place_id)


## Gives a companion an order (`GameCompanions.set_order`): {ok, text}.
func order(id: String, which: String) -> Dictionary:
	return GameCompanions.set_order(d, id, which)


## Gives a companion the next order in turn (follow, stay, gather, guard, then follow again): {ok, text}.
func cycle_order(id: String) -> Dictionary:
	if not d.party.has_member(id):
		return GameCompanions.set_order(d, id, GameCompanions.FOLLOW)   # not in the party: the same refusal
	var orders: Array = GameCompanions.ORDERS
	var next: String = orders[(orders.find(GameCompanions.order_of(d, id)) + 1) % orders.size()]
	return GameCompanions.set_order(d, id, next)


## Sends a companion to a place with an order (`stay` holds it, `guard` guards it, `follow` brings them back to the heir): {ok, text}.
## The order is the party member's, as `GameCompanions.set_order` has it; where they go is the runtime agent's post.
func send_order(id: String, order: String, x: float, z: float) -> Dictionary:
	var r := GameCompanions.set_order(d, id, order)
	if r["ok"] and order != GameCompanions.FOLLOW:
		companions = GameCompanions.place(companions, id, order, x, z)
	return r


## Gives an order to everyone in the party, or to the one companion `only` (""): the lines they say.
func order_party(order: String, only: String = "") -> Array:
	var lines: Array = []
	for m in d.party.members:
		if only == "" or str(m["id"]) == only:
			var r := GameCompanions.set_order(d, str(m["id"]), order)
			lines.append(str(r["text"]))
	return lines


## The storey the build controls work on: 0 is the ground floor, 1 and up are above it (not saved; a visit starts on the ground).
var build_level := 0


## The layer of the build level (GameBuild's y).
func build_y() -> int:
	return GameBuild.SURFACE - build_level


## The build level as the Level button says it: "ground", the storey's number, or "roof" for the layer over the top storey.
func level_name() -> String:
	if build_level == 0:
		return "ground"
	return "roof" if build_level > int(GameBuild.setting("max_storeys")) else str(build_level)


## Steps the build level up a storey, and back to the ground after the top one.
func cycle_level() -> int:
	build_level = (build_level + 1) % (int(GameBuild.setting("max_storeys")) + 2)   # the last step is the roof layer
	return build_level


## The pieces the family may build, in the data's order (wall, floor, road, door).
func build_kinds() -> Array:
	return GameBuild.pieces().keys()


## Why a piece cannot go on the tile `dx, dz` from the heir (GameBuild.check), or "" when it can.
func build_check(kind: String, dx: int, dz: int) -> String:
	if space != "world":
		return _text("indoors")
	var t := heir + Vector2i(dx, dz)
	return GameBuild.check(d, kind, t.x, build_y(), t.y)


## Takes the piece on the tile `dx, dz` from the heir down, with its refund (GameBuild.remove): {ok, text}.
func remove_at(dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var t := heir + Vector2i(dx, dz)
	var out := GameBuild.remove(d, t.x, build_y(), t.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## Mends the piece on the tile `dx, dz` from the heir (GameRepair.repair): {ok, text}.
func repair_at(dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var t := heir + Vector2i(dx, dz)
	var out := GameRepair.repair(d, t.x, build_y(), t.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## Forages the nodes beside the heir (GameForage): {ok, text}. Not indoors or upstairs.
func forage() -> Dictionary:
	if space != "world":
		return {"ok": false, "text": GameForage.text("indoors")}
	if storey() > 0:
		return {"ok": false, "text": GameForage.text("upstairs")}
	var out := GameForage.forage(d, heir.x, heir.y)
	if out["ok"]:
		log.append({"kind": "forage", "text": str(out["text"])})
		dirty.append(Vector2i(int(out["x"]), int(out["z"])))
	return out


## Digs the cell `depth` below the surface straight under the heir (`GameMine.dig`): {ok, why, ...}.
func dig(depth: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "why": _text("indoors"), "text": _text("indoors")}
	if storey() > 0:
		return {"ok": false, "why": _text("upstairs_dig"), "text": _text("upstairs_dig")}
	var out := GameMine.dig(d, GameWorldGen.MINE_SITE, heir.x, depth, heir.y)
	if out["ok"]:
		log.append({"kind": "dig", "text": _text("dug", {"depth": depth})})
		dirty.append(heir)
		var h := GameMine.hazard(d, GameWorldGen.MINE_SITE, heir.x, depth, heir.y)
		out["hazard"] = h
		if bool(h["hit"]):
			log.append({"kind": "hazard", "text": str(h["text"])})
	return out


## Places a piece on the tile `dx, dz` from the heir at the surface (`GameBuild.place`): {ok, text}.
func build(kind: String, dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var to := heir + Vector2i(dx, dz)
	var out := GameBuild.place(d, kind, to.x, build_y(), to.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## The sizes of house the screen offers, [w, h] in tiles (any size from 3 by 3 can be raised by `build_house`).
func house_sizes() -> Array:
	return GameBuild.setting("house_sizes")


## The tiles a house of `w` by `h` takes with its door `dx, dz` from the heir (the tile in front of its south wall).
func house_rect(w: int, h: int, dx: int, dz: int) -> Rect2i:
	var door := heir + Vector2i(dx, dz)
	return Rect2i(door.x - (w - 1) / 2, door.y - (h - 1), w, h)


## Raises a whole house (`GameBuild.build_house`) with its door on the tile `dx, dz` from the heir: {ok, text, rect}. Ground floor
## only, outdoors.
func build_house(w: int, h: int, dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors"), "rect": Rect2i()}
	if build_level != 0:
		return {"ok": false, "text": _text("house_ground"), "rect": Rect2i()}
	var door := heir + Vector2i(dx, dz)
	var out := GameBuild.build_house(d, w, h, door.x, door.y)
	out["rect"] = house_rect(w, h, dx, dz)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## A creature that is hunting the heir and has reached them starts a fight (GameDynasty.start_encounter), with any others that
## are hunting them within `contact_join` tiles, up to `contact_max` in all. The creatures in the fight are taken out of the
## open world. Only while no fight is on and the heir is living; returns whether one began.
## Whether a creature at (x, z) can strike the heir: within `rng` tiles and with nothing that stops a reach on the line between them
## (a wall, a tower, a building, a shut gate: `GameWalls.line_clear`), so a creature pressed against the outside of a wall cannot
## fight the heir on the other side of it. Ranged and area reach follow the same line (see docs/REACH.md).
func reaches_heir(a: Dictionary, rng: float) -> bool:
	var at := Vector2(float(a["x"]), float(a["z"]))
	if at.distance_to(heir_point()) > rng:
		return false
	return GameWalls.line_clear(at, heir_point(), GameWalls.shut_now(d), float(setting("reach_step")))


## The creatures inside a smoke cloud give up whatever they were doing and go out of it (GameBehaviour.drive_from): no dice, and the
## mode is overridden here, after the behaviour step, so a hunter inside the cloud is a runner by the time contact is looked at.
func _smoke_drives(list: Array, view: Dictionary) -> Array:
	var c: Variant = GameSmoke.centre(d)
	if c == null:
		return list
	var out: Array = []
	for a in list:
		if str(a["mode"]) != "dead" and Vector2(float(a["x"]), float(a["z"])).distance_to(c) <= GameSmoke.radius():
			out.append(GameBehaviour.drive_from(a, c, view, float(GameSmoke.data()["drive"])))
		else:
			out.append(a)
	return out


## Breaks a smoke pot where the heir stands: a cloud for `smoke.seconds` of the world clock. {ok, text}. Refused indoors, upstairs, in a
## fight, with none, and while the cloud already burns here. Draws no dice.
func use_smoke() -> Dictionary:
	var h := d.heir
	if space != "world":
		return {"ok": false, "text": GameSmoke.text("indoors")}
	if storey() > 0:
		return {"ok": false, "text": GameSmoke.text("upstairs")}
	if d.battle != null:
		return {"ok": false, "text": GameSmoke.text("fight")}
	if GameSmoke.count(h) <= 0:
		return {"ok": false, "text": GameSmoke.text("none", {"heir": h.name})}
	if GameSmoke.active(d) and GameSmoke.covers(d, heir_point().x, heir_point().y) and GameSmoke.left(d) > float(GameSmoke.data()["seconds"]) * 0.5:
		return {"ok": false, "text": GameSmoke.text("already", {"left": GameSmoke.clock_text(GameSmoke.left(d))})}
	GameSmoke.take_one(h)
	GameSmoke.light(d, heir_point().x, heir_point().y)
	var line := GameSmoke.text("lit", {"heir": h.name})
	log.append({"kind": "smoke", "text": line})
	return {"ok": true, "text": line}


func _contact() -> bool:
	if d.battle != null or d.state != "life" or storey() > 0 or space != "world":
		return false   # nothing reaches the heir upstairs or indoors
	if GameSmoke.covers(d, heir_point().x, heir_point().y):
		return false   # nor a heir inside a smoke cloud
	var me := heir_point()
	var first := -1
	for i in creatures.size():
		var a: Dictionary = creatures[i]
		if str(a["mode"]) == "chase" and reaches_heir(a, float(setting("contact_range"))):
			first = i
			break
	if first < 0:
		return false
	var ids: Array = []
	var gone: Array = []
	var levels: Array = []   # each creature's own level (GameLevels), in the order of the ids
	for i in creatures.size():
		var a: Dictionary = creatures[i]
		if ids.size() >= int(setting("contact_max")):
			break
		if i == first or (str(a["mode"]) == "chase" and reaches_heir(a, float(setting("contact_join")))):
			ids.append(str(a["id"]))
			levels.append(level_of(a))
			gone.append(a)
	var fight := d.start_encounter(ids, "", 1.0, levels)
	if fight == null:
		return false
	var away := _escape_tile(Vector2(float(creatures[first]["x"]), float(creatures[first]["z"])))
	d.sandbox_escape = {"x": away.x, "z": away.y}
	for a in gone:
		creatures.erase(a)
	var names: Array = fight.enemies.map(func(e): return str(e["name"]))
	log.append({"kind": "fight", "text": _text("contact", {"foes": GameMessages.text("life", "list_comma").join(names), "heir": d.heir.name})})
	return true


## The tile `escape_tiles` away from the heir on the side opposite `from` (a creature's point), stopping at the last tile on the
## way that can be stood on; the heir's own tile when there is none.
func _escape_tile(from: Vector2) -> Vector2i:
	var dir := heir_point() - from
	dir = dir.normalized() if dir.length() > 0.001 else Vector2(0, 1)
	var ground := GamePath.world_ground(d)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var best := heir
	for i in range(1, int(setting("escape_tiles")) + 1):
		var t := Vector2i(floori(heir_point().x + dir.x * float(i)), floori(heir_point().y + dir.y * float(i)))
		if not GameWorldGen.in_bounds(t.x, t.y) or not GamePath.passable(ground, Vector3i(t.x, GameBuild.SURFACE, t.y), mover):
			break
		best = t
	return best


## After a fight on the map is over: if it was fled from, the heir gets clear of it now (the record `_contact` made), else
## nothing changes. The creatures that fought are put back by the next `refresh`.
func after_fight() -> void:
	if d.battle != null:
		return
	rest_until = d.world_seconds + float(setting("spawn_rest_seconds"))   # a breather: nothing new spawns for a while after any fight
	if d.last_xp_line != "":
		log.append({"kind": "fight", "text": d.last_xp_line})   # "+N XP" in the journal
		d.last_xp_line = ""
	if not fight_foes.is_empty():
		_after_dungeon_fight()
		return
	if not fight_site.is_empty():
		_after_landmark_fight()
	if d.sandbox_escape.is_empty():
		return
	heir = Vector2i(int(d.sandbox_escape["x"]), int(d.sandbox_escape["z"]))
	d.sandbox_escape = {}
	route = []
	refresh()
	log.append({"kind": "fight", "text": _text("escaped", {"heir": d.heir.name})})


## The creatures within THREAT_NEAR tiles of the heir, as {x, z} points (the companions' threats).
func _threats() -> Array:
	var out: Array = []
	for a in creatures:
		if Vector2(float(a["x"]), float(a["z"])).distance_to(heir_point()) <= float(setting("threat_near")):
			out.append({"x": float(a["x"]), "z": float(a["z"])})
	return out


func _distance(a: Dictionary, t: Vector2i) -> float:
	return maxf(absf(float(a["x"]) - (float(t.x) + 0.5)), absf(float(a["z"]) - (float(t.y) + 0.5)))


func _key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


func _text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- landmark fights

## The creatures that live at the landmarks round the heir, idling there now (GameWildsFights.dwellers), as agent-like dictionaries the screen draws: not in
## `creatures`, so they never chase or start a fight (the landmark's own trigger does). Only on the open world's ground, in sight (`see_range`).
func landmark_dwellers() -> Array:
	var out: Array = []
	if space != "world" or storey() > 0:
		return out
	var me := heir_point()
	for lm in GameWildsSites.within(d, me.x, me.y, float(GameWilds.setting("see_range"))):
		out.append_array(GameWildsFights.dwellers(d, lm, GameDay.hour(d)))
	return out


## Each tick: the landmarks the heir has come within `range` of whose guards have not yet been set on them this visit (GameWildsFights.can_trigger), the
## first of which starts its fight. A landmark is let off `armed` once the heir is `leave_mult` times its range away, so leaving and coming back is a new
## visit (still held by the landmark's own cooldown). Nothing happens upstairs, indoors, in a fight or with the heir fallen.
func _landmark_approach() -> bool:
	if d.battle != null or d.state != "life" or storey() > 0 or space != "world":
		return false
	var me := heir_point()
	for id in armed.keys():
		var p := GameWildsSites.parse_id(str(id))
		if Vector2(float(p.x) + 0.5, float(p.y) + 0.5).distance_to(me) > float(GameWilds.setting("leave_mult")) * float(armed[id]):
			armed.erase(id)
	for lm in GameWildsSites.within(d, me.x, me.y, 8.0):
		var b := GameWildsFights.block(lm)
		if b.is_empty() or armed.has(str(lm["id"])) or not "approach" in b["triggers"]:
			continue
		if Vector2(float(lm["x"]) + 0.5, float(lm["z"]) + 0.5).distance_to(me) > float(b["range"]):
			continue
		var plan := GameWildsFights.plan(d, lm, "approach")
		if plan.is_empty():
			continue
		armed[str(lm["id"])] = float(b["range"])
		log.append({"kind": "site", "text": str(plan["text"])})
		return begin_landmark_fight(lm, plan)
	return false


## Starts the fight a landmark sends (`plan` is GameWildsFights.plan): its foes by the hunt's own rules, the heir's way clear behind them, the first blow
## theirs on an ambush unless the heir is already hurt below `surprise_min_hp`. Marks the landmark fought (its cooldown starts). Returns whether a fight began.
func begin_landmark_fight(lm: Dictionary, plan: Dictionary) -> bool:
	var fight := d.start_encounter(plan["foes"], str(lm["area"]), float(plan["level_mult"]))
	if fight == null:
		return false
	GameWildsFights.mark_fought(d, lm)
	fight_site = {"id": str(lm["id"]), "lm": lm, "foes": plan["foes"]}
	var away := _escape_tile(Vector2(float(lm["x"]) + 0.5, float(lm["z"]) + 0.5))
	d.sandbox_escape = {"x": away.x, "z": away.y}
	if bool(plan["ambush"]) and float(d.heir.hp) >= float(GameWilds.setting("surprise_min_hp")) * float(d.heir.max_hp()):
		fight.heir_skip = true
		log.append({"kind": "fight", "text": GameWilds.text("surprised", {"heir": d.heir.name})})
	return true


## After a landmark's fight: a win clears it and pays its bonus find; a flight or defeat leaves it as it was (its cooldown running).
func _after_landmark_fight() -> void:
	var site := fight_site
	fight_site = {}
	route = []
	var lm: Dictionary = site["lm"]
	if d.last_result == "victory":
		for line in GameWildsFights.won(d, lm):
			log.append({"kind": "site", "text": str(line)})
	else:
		log.append({"kind": "site", "text": GameWildsFights.fled(d, lm)})


# ---------------------------------------------------------------- dungeons

## The creatures of a dungeon as agents (GameDungeons.inhabitants), each with its slot's key, room and boss flag.
func _spawn_denizens(id: String) -> Array:
	var out: Array = []
	for h in GameDungeons.inhabitants(d, id):
		var a := GameBehaviour.new_agent(next_uid, str(h["creature"]), float(h["x"]) + 0.5, float(h["z"]) + 0.5)
		a["key"] = str(h["key"])
		a["room"] = str(h["room"])
		a["boss"] = bool(h["boss"])
		next_uid += 1
		out.append(a)
	return out


## The rooms the heir can be seen from: the one they stand in, or on a door both it joins.
func _heir_rooms() -> Array:
	var r := GameInterior.room_at(space, heir.x, heir.y)
	if r != "":
		return [r]
	var out: Array = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := GameInterior.room_at(space, heir.x + dir.x, heir.y + dir.y)
		if n != "" and n not in out:
			out.append(n)
	return out


func _room_walk(room: String, x: int, z: int) -> bool:
	return GameInterior.passable(interior, x, z) and GameInterior.room_at(space, x, z) == room


## A tick in a dungeon: each room's creatures act (GameBehaviour, held inside their room, seeing the heir only when the heir is in
## or at the door of that room), and a chaser that reaches the heir starts a fight.
func _dungeon_tick() -> void:
	if d.battle != null or d.state != "life":
		return
	if denizens.is_empty():
		_dungeon_companions()
		return
	var by_room := {}
	for a in denizens:
		var k := str(a["room"])
		if not by_room.has(k):
			by_room[k] = []
		by_room[k].append(a)
	var seen_in := _heir_rooms()
	var next: Array = []
	for room in by_room:
		var group: Array = by_room[room]
		var targets: Array = [{"x": heir_point().x, "z": heir_point().y}] if room in seen_in else []
		var r: String = room
		var view := {"targets": targets, "night": false, "walkable": func(x: float, z: float) -> bool: return _room_walk(r, floori(x), floori(z))}
		var moved := GameBehaviour.step_all(group, view, d.seed_value, tick)
		for i in moved.size():
			if not _room_walk(r, floori(float(moved[i]["x"])), floori(float(moved[i]["z"]))):
				moved[i]["x"] = group[i]["x"]   # a flier does not go through a wall
				moved[i]["z"] = group[i]["z"]
		next.append_array(moved)
	denizens = next
	_dungeon_companions()
	_dungeon_contact()


## A creature of the dungeon in `chase` that reaches the heir fights them: it and others of its room hunting within
## `contact_join`, up to `contact_max`, by GameDynasty.start_encounter at the dungeon's danger; a lair's boss alone, as the
## legend (GameDynasty.start_legend_at). The creatures are taken out of the room until the fight is over.
func _dungeon_contact() -> bool:
	var me := heir_point()
	var first := -1
	for i in denizens.size():
		var a: Dictionary = denizens[i]
		if str(a["mode"]) == "chase" and Vector2(float(a["x"]), float(a["z"])).distance_to(me) <= float(setting("contact_range")):
			first = i
			break
	if first < 0:
		return false
	var place := GameDungeons.place_of(space)
	var lead: Dictionary = denizens[first]
	var gone: Array = []
	var fight: GameBattle = null
	if bool(lead["boss"]):
		fight = d.start_legend_at(str(lead["id"]))
		gone = [lead]
	else:
		var ids: Array = []
		for a in denizens:
			if ids.size() >= int(setting("contact_max")):
				break
			if bool(a["boss"]) or str(a["room"]) != str(lead["room"]):
				continue
			if a == lead or (str(a["mode"]) == "chase" and Vector2(float(a["x"]), float(a["z"])).distance_to(me) <= float(setting("contact_join"))):
				ids.append(str(a["id"]))
				gone.append(a)
		fight = d.start_encounter(ids, place)
	if fight == null:
		return false
	d.sandbox_escape = {"x": outside.x, "z": outside.y, "space": space}
	for a in gone:
		denizens.erase(a)
	fight_foes = gone
	var names: Array = fight.enemies.map(func(e): return str(e["name"]))
	log.append({"kind": "fight", "text": _text("contact", {"foes": GameMessages.text("life", "list_comma").join(names), "heir": d.heir.name})})
	return true


## After a dungeon fight: a win kills the creatures for `foe_years` and leaves their drops (GameDungeonLoot.roll_drop); a flight
## or a defeat puts them back where they live and the heir at the way out.
func _after_dungeon_fight() -> void:
	var foes := fight_foes
	fight_foes = []
	d.sandbox_escape = {}
	route = []
	if space == "world" or not GameDungeons.is_dungeon(space):
		return
	var place := GameDungeons.place_of(space)
	if d.last_result == "victory":
		for a in foes:
			GameDungeons.mark(d, "k", place, str(a["key"]))
			var got := GameDungeonLoot.roll_drop(d, place, str(a["key"]), str(a["id"]), bool(a["boss"]))
			for line in GameDungeonLoot.give(d, got):
				log.append({"kind": "dungeon", "text": str(line)})
	else:
		for a in foes:
			a["x"] = float(a["home_x"])
			a["z"] = float(a["home_z"])
			a["mode"] = "idle"
			a["target"] = {}
			denizens.append(a)
		heir = GameInterior.entry()
		companions = _seat_companions()
		log.append({"kind": "fight", "text": _text("escaped", {"heir": d.heir.name})})


## The party's agents standing on the floor nearest the way in (a breadth-first walk from it), one cell each.
func _seat_companions() -> Array:
	var out := GameCompanions.agents_for(d, 0.5, 0.5)
	var e := GameInterior.entry()
	var seen := {e: true}
	var queue: Array = [e]
	var cells: Array = []
	while not queue.is_empty() and cells.size() < out.size():
		var c: Vector2i = queue.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if not seen.has(n) and GameInterior.passable(interior, n.x, n.y):
				seen[n] = true
				queue.append(n)
				cells.append(n)
	for i in out.size():
		var at: Vector2i = cells[i] if i < cells.size() else e
		out[i]["x"] = float(at.x) + 0.5
		out[i]["z"] = float(at.y) + 0.5
		out[i]["post_x"] = out[i]["x"]
		out[i]["post_z"] = out[i]["z"]
	return out


## The party in a dungeon: GameCompanions' own state machine on the dungeon's floor (their steps held to walkable cells), their
## threats the creatures of the room the heir is in (never the lair's boss). A guard that reaches one fights it (`engage`).
func _dungeon_companions() -> void:
	if companions.is_empty() and d.party.members.is_empty():
		return
	companions = GameCompanions.reconcile(d, companions, heir_point().x, heir_point().y)
	var rooms := _heir_rooms()
	var threats: Array = []
	for a in denizens:
		if not bool(a["boss"]) and str(a["room"]) in rooms:
			threats.append({"x": float(a["x"]), "z": float(a["z"])})
	var view := GameCompanions.view(d, heir_point().x, heir_point().y, threats)
	view["indoors"] = true
	view["walkable"] = func(x: float, z: float) -> bool: return GameInterior.passable(interior, floori(x), floori(z))
	var out := GameCompanions.step_all(d, companions, view, tick)
	companions = out["agents"]
	for a in companions:   # a regroup or a seat may land in a wall: they stand with the heir instead
		if not GameInterior.passable(interior, floori(float(a["x"])), floori(float(a["z"]))):
			a["x"] = heir_point().x
			a["z"] = heir_point().y
	for e in out["events"]:
		if str(e["type"]) == "engage":
			_dungeon_guard_fights(e)
		elif str(e["type"]) != "gathered":
			log.append({"kind": "companion", "text": GameCompanions.event_text(e)})


## A guard at a creature of the dungeon: GameCompanions.duel, as on the open world. A win kills it for `foe_years` (and leaves its
## drops); a loss leaves the guard hurt and resting.
func _dungeon_guard_fights(e: Dictionary) -> void:
	var at := Vector2(float(e["x"]), float(e["z"]))
	var hit := -1
	var best := INF
	for i in denizens.size():
		var a: Dictionary = denizens[i]
		var dist := Vector2(float(a["x"]), float(a["z"])).distance_to(at)
		if not bool(a["boss"]) and dist < best and dist <= 1.0:
			best = dist
			hit = i
	if hit < 0:
		return
	var id := str(e["id"])
	var foe_a: Dictionary = denizens[hit]
	var r := GameCompanions.duel(d, id, str(foe_a["id"]), tick)
	if r.is_empty():
		return
	var name := str(d.party.member(id).get("name", id))
	var foe := str(r["foe"]).to_lower()
	for c in companions:
		if str(c["id"]) == id and (not bool(r["won"])):
			c["rest_until"] = tick + int(GameCompanions.setting("guard_rest_ticks"))
	if bool(r["refused"]):
		log.append({"kind": "guard", "text": GameCompanions.text("guard_too_hurt", {"name": name, "foe": foe})})
	elif bool(r["won"]):
		denizens.remove_at(hit)
		var place := GameDungeons.place_of(space)
		GameDungeons.mark(d, "k", place, str(foe_a["key"]))
		var key := "guard_won_gold" if int(r["gold"]) > 0 else "guard_won"
		log.append({"kind": "guard", "text": GameCompanions.text(key, {"name": name, "foe": foe, "gold": int(r["gold"])})})
		for line in GameDungeonLoot.give(d, GameDungeonLoot.roll_drop(d, place, str(foe_a["key"]), str(foe_a["id"]), false)):
			log.append({"kind": "dungeon", "text": str(line)})
	else:
		log.append({"kind": "guard", "text": GameCompanions.text("guard_hurt", {"name": name, "foe": foe})})


## The heir has stepped on a cell of a dungeon: a hidden trap goes off, and the cell is redrawn (it shows once sprung).
func _dungeon_arrive() -> void:
	var t := GameDungeons.step_on(d, space, heir.x, heir.y, GameCasting.ward_up(d))
	if bool(t.get("warded", false)):
		GameCasting.spend_ward(d)
	var text := str(t.get("text", ""))
	if text != "":
		log.append({"kind": "dungeon", "text": text})
		dirty.append(heir)
