## Locked doors and keys in the dungeons (data/world/dungeons.json `locks` and `keys`): a shut door is a solid cell until its key is
## used, a key lies in a container of its room (found with Use, kept as a `y` mark, spent on the door, which stays open as a `d`
## mark), every dungeon can be walked through with its keys, nothing is saved until something is held or opened, and no die of the
## dynasty's is drawn.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_locks.gd
extends SceneTree

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_cells()
	test_walk()
	test_save()
	print("dungeon lock tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(place: String) -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = 5
	d.heir.gold = 0
	var s := GameSandbox.start(d)
	var door: Dictionary = GameSpaces.space("world/" + place)["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	s.use()
	s.denizens.clear()
	for t in GameDungeons.layout(s.space)["traps"]:
		GameDungeons.mark(s.d, "t", place, str(t["id"]))
	return s


func _go(s: GameSandbox, to: Vector2i) -> bool:
	var from := {s.heir: null}
	var queue: Array = [s.heir]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if not from.has(n) and GameInterior.passable(s.interior, n.x, n.y):
				from[n] = c
				queue.append(n)
	if not from.has(to):
		return false
	var steps: Array = []
	var cur := to
	while from[cur] != null:
		steps.push_front(cur)
		cur = from[cur]
	for st in steps:
		if not s.move(st.x - s.heir.x, st.y - s.heir.y)["ok"]:
			return false
	return s.heir == to


## A walkable cell beside a thing at (x, z) that the heir can stand on now.
func _beside(s: GameSandbox, x: int, z: int) -> Vector2i:
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(x, z) + dir
		if GameInterior.passable(s.interior, c.x, c.y) and GameInterior.room_at(s.space, c.x, c.y) != "":
			return c
	return Vector2i(-99, -99)


func test_data() -> void:
	ok(GameDungeons.validate().is_empty(), "the dungeon data is valid: %s" % str(GameDungeons.validate()))
	for place in GameDungeons.dungeon_ids():
		var sp: String = "world/" + place
		var lay: Dictionary = GameDungeons.layout(sp)
		ok(lay["locks"].size() >= 1, "%s has a locked door" % place)
		ok(GameDungeons.solvable(sp), "%s can be walked through with its keys" % place)
		for lk in lay["locks"]:
			var keyed: Array = lay["containers"].filter(func(c): return str(c.get("key", "")) == str(lk["key"]))
			ok(keyed.size() == 1, "%s: the %s has one key in a container" % [place, lk["name"]])
			ok(GameDungeons.layout(sp) == lay and GameInterior.cells(sp).get("%d,%d" % [lk["x"], lk["z"]], "") == "door", "(the lock is on a real door)")
	# a key behind its own door is caught
	var saved: Array = GameDungeons.data()["dungeons"]["hollow_barrow"]["keys"].duplicate(true)
	GameDungeons.data()["dungeons"]["hollow_barrow"]["keys"][0]["room"] = "tomb"
	GameDungeons._layouts.clear()
	ok(not GameDungeons.validate().is_empty(), "a key shut in a room behind a door that needs it fails the validator")
	GameDungeons.data()["dungeons"]["hollow_barrow"]["keys"] = saved
	GameDungeons._layouts.clear()
	ok(GameDungeons.validate().is_empty(), "(restored)")


func test_cells() -> void:
	var sp := "world/hollow_barrow"
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	var lk: Dictionary = GameDungeons.layout(sp)["locks"][0]
	var k := "%d,%d" % [lk["x"], lk["z"]]
	ok(GameDungeons.walk_cells(sp)[k] == "door", "without a dynasty every door is open, as before")
	var cells := GameDungeons.walk_cells(sp, d)
	ok(cells[k] == "locked" and not GameInterior.passable(cells, int(lk["x"]), int(lk["z"])), "a shut door is a cell that cannot be stood on")
	ok(GameDungeons.lock_closed(d, sp, int(lk["x"]), int(lk["z"])), "it reads as closed")
	var reach := GameInterior.reachable(cells)
	var behind := GameInterior.reachable(GameDungeons.walk_cells(sp))
	ok(reach.size() < behind.size(), "the rooms behind it cannot be reached while it is shut")
	d.dungeon_marks[GameDungeons.mark_key("d", "hollow_barrow", str(lk["id"]))] = 1.0
	ok(GameDungeons.walk_cells(sp, d)[k] == "door", "once opened it is a door")
	ok(GameDungeons.thing_near(sp, int(lk["x"]), int(lk["z"]), d).get("type", "") != "lock", "and Use no longer finds it")


func test_walk() -> void:
	var s := _sandbox("hollow_barrow")
	var sp := s.space
	var lay: Dictionary = GameDungeons.layout(sp)
	var vault: Dictionary = lay["locks"].filter(func(l): return l["id"] == "vault_door")[0]
	var rng_before := s.d.rng.state
	# no key: the door will not open and says what it wants
	var first := _beside(s, int(vault["x"]), int(vault["z"]))
	ok(first != Vector2i(-99, -99), "there is floor beside the vault door")
	ok(_go(s, first), "the heir walks to the vault door")
	var r := s.use()
	ok(not r["ok"] and r["text"].contains("locked") and r["text"].contains("bone key"), "without the key it stays shut: %s" % r["text"])
	ok(not s.can_step(int(vault["x"]) - s.heir.x, int(vault["z"]) - s.heir.y)["ok"], "and cannot be walked through")
	# the key lies in the ossuary
	var kc: Dictionary = lay["containers"].filter(func(c): return str(c.get("key", "")) == "bone_key")[0]
	ok(str(kc["room"]) == "ossuary", "the bone key is in the ossuary")
	var spot := _beside(s, int(kc["x"]), int(kc["z"]))
	ok(_go(s, spot), "the heir walks to the key's %s" % kc["kind"])
	var got := s.use()
	ok(got["ok"] and got["text"].contains("bone key") and GameDungeons.has_key(s.d, sp, "bone_key"), "Use gives the bone key: %s" % got["text"])
	ok(s.d.dungeon_marks.has("y:hollow_barrow:bone_key"), "(held as a y mark)")
	# the container refills later but never gives a second key
	GameDungeons.mark(s.d, "o", "hollow_barrow", str(kc["id"]))
	s.d.dungeon_marks["o:hollow_barrow:" + str(kc["id"])] = float(s.d.world.year) - 100.0
	s.use()
	ok(GameDungeons.has_key(s.d, sp, "bone_key"), "(still held)")
	# open the door
	ok(_go(s, first), "the heir walks back")
	var open := s.use()
	ok(open["ok"] and open["text"].contains("swings open"), "with the key the door opens: %s" % open["text"])
	ok(not GameDungeons.has_key(s.d, sp, "bone_key") and GameDungeons.lock_open(s.d, sp, "vault_door"), "the key is spent and the door stays open")
	ok(s.interior["%d,%d" % [vault["x"], vault["z"]]] == "door", "the sandbox's cell is a door now")
	ok(s.dirty.has(Vector2i(int(vault["x"]), int(vault["z"]))), "and the tile is redrawn")
	var through := Vector2i(int(vault["x"]), int(vault["z"]))
	ok(_go(s, through) and GameInterior.room_at(s.space, through.x + 0, through.y + 0) == "", "the heir stands in the doorway")
	ok(s.d.rng.state == rng_before, "no die of the dynasty's was drawn")
	ok(not s.d.dungeon_marks.has("y:hollow_barrow:bone_key"), "(key gone)")
	# a second visit: the door is open from the start
	s.use()
	var back := GameDungeons.walk_cells(sp, s.d)
	ok(back["%d,%d" % [vault["x"], vault["z"]]] == "door", "coming in again finds it open")
	var tomb: Dictionary = lay["locks"].filter(func(l): return l["id"] == "tomb_door")[0]
	ok(back["%d,%d" % [tomb["x"], tomb["z"]]] == "locked", "the tomb door is still shut")
	# the key to the tomb is in the bone vault, behind the door just opened
	var sc: Dictionary = lay["containers"].filter(func(c): return str(c.get("key", "")) == "king_seal")[0]
	ok(str(sc["room"]) == "bone_vault", "the king's seal is in the vault that the first key opens")


func test_save() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	ok(not d.to_dict().has("dungeon_marks"), "a house that has held no key saves no marks")
	d.dungeon_marks["y:hollow_barrow:bone_key"] = 3.0
	d.dungeon_marks["d:hollow_barrow:vault_door"] = 4.0
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.dungeon_marks == d.dungeon_marks, "a held key and an open door come back from a save")
	ok(GameDungeons.has_key(back, "world/hollow_barrow", "bone_key") and GameDungeons.lock_open(back, "world/hollow_barrow", "vault_door"), "and read as held and open")
	var junk := d.to_dict()
	junk["dungeon_marks"] = {"y:a": 1, "d:a:b": "x", "y:a:b": 2.0, "q:a:b": 1.0}
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(junk))).dungeon_marks.size() == 1, "damaged marks are dropped")
	var far := GameDungeons.is_marked(d, "d", "hollow_barrow", "vault_door")
	d.world.year += 1000.0
	ok(far == GameDungeons.is_marked(d, "d", "hollow_barrow", "vault_door"), "a held key and an open door never come back with the years")
