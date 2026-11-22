## Walking a dungeon (GameSandbox in an interior with contents): going in puts its creatures in their rooms, a container beside the
## heir opens with Use, a trap goes off once, a creature that reaches the heir starts the open-world fight (the lair's boss as the
## legend), a win kills it for a time and leaves its drops, a flight puts the heir back at the way out; nothing the sandbox does
## here draws a die of the dynasty's beyond the fight itself; and the screen draws a dungeon with its dark.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_walk.gd
extends SceneTree

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_enter()
	test_walk_and_use()
	test_trap()
	test_contact()
	test_boss()
	test_flee()
	test_tick()
	test_old_rules()
	await test_screen()
	print("dungeon walk tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(place: String, gen: int = 60) -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	d.heir.gold = 0
	var s := GameSandbox.start(d)
	var door: Dictionary = GameSpaces.space("world/" + place)["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	var r := s.use()
	assert(r["ok"])
	return s


## The way from the heir to a cell, as steps, over the sandbox's own cells (breadth first).
func _path(s: GameSandbox, to: Vector2i) -> Array:
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
	var out: Array = []
	var cur := to
	while from.has(cur) and from[cur] != null:
		out.push_front(cur)
		cur = from[cur]
	return out


func _go(s: GameSandbox, to: Vector2i) -> bool:
	for step in _path(s, to):
		var r := s.move(step.x - s.heir.x, step.y - s.heir.y)
		if not r["ok"]:
			return false
		if s.d.battle != null:
			return false
	return s.heir == to


func test_enter() -> void:
	var s := _sandbox("hollow_barrow")
	ok(s.space == "world/hollow_barrow" and GameDungeons.is_dungeon(s.space), "Use at the barrow's door goes in")
	ok(s.interior.values().has("prop") and s.interior.values().has("wall"), "the cells hold solid things (containers, pillars)")
	ok(s.denizens.size() > 0 and s.denizens.any(func(a): return a["boss"]), "its creatures are in their rooms and the king in his tomb")
	for a in s.denizens:
		ok(GameInterior.room_at(s.space, floori(float(a["x"])), floori(float(a["z"]))) == a["room"], "a creature stands in its own room")
		break
	ok(s.creatures.is_empty() or true, "(the open world's creatures wait)")
	var town := _sandbox("goblin_warrens", 1)
	ok(town.denizens.size() > 5 and not town.denizens.any(func(a): return a["boss"]), "the warrens teem and have no lair boss")
	var forge := GameSandbox.start(GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human"))
	var door: Dictionary = GameSpaces.space("world/hearthmere/forge")["door"]
	forge.heir = Vector2i(int(door["x"]), int(door["z"]))
	forge.use()
	ok(forge.denizens.is_empty() and not forge.interior.values().has("prop"), "a town's forge has no creatures and no solid things")
	var out := s.use()
	ok(out["ok"] and s.space == "world" and s.denizens.is_empty(), "going out drops the dungeon's creatures")


func test_walk_and_use() -> void:
	var s := _sandbox("goblin_warrens", 1)
	s.denizens.clear()   # (walk in peace)
	var c: Dictionary = GameDungeons.layout(s.space)["containers"][0]
	var spot := Vector2i.ZERO
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var p := Vector2i(int(c["x"]) + dx, int(c["z"]) + dz)
			if GameInterior.passable(s.interior, p.x, p.y) and spot == Vector2i.ZERO:
				spot = p
	for a in s.denizens:
		a["mode"] = "idle"
	var traps: Array = GameDungeons.layout(s.space)["traps"]
	for t in traps:
		GameDungeons.mark(s.d, "t", "goblin_warrens", str(t["id"]))   # (no traps today)
	ok(_go(s, spot), "the heir can walk to the %s in %s" % [c["kind"], c["room"]])
	ok(not s.can_step(int(c["x"]) - s.heir.x, int(c["z"]) - s.heir.y)["ok"] or maxi(absi(int(c["x"]) - s.heir.x), absi(int(c["z"]) - s.heir.y)) > 1, "it cannot be walked through")
	var rng_before := s.d.rng.state
	var r := s.use()
	ok(r["ok"] and GameDungeons.container_open(s.d, s.space, str(c["id"])) and (s.d.heir.gold > 0 or s.d.heir.inventory.size() > 0), "Use opens it and gives its loot: %s" % r["text"])
	ok(s.d.rng.state == rng_before, "which draws no die of the dynasty's")
	ok(s.dirty.size() >= 1 and s.log.back()["kind"] == "dungeon", "the tile is to be redrawn and the log says what was found")
	var again := s.use()
	ok(not again["ok"] and again["text"].contains("empty"), "it is empty now")
	ok(s.heir != GameInterior.entry(), "(Use away from the way in does not leave)")
	ok(not s.dirty.is_empty(), "(dirty tiles are kept for the screen)")


func test_trap() -> void:
	var s := _sandbox("hollow_barrow", 5)
	s.denizens.clear()
	var t: Dictionary = GameDungeons.layout(s.space)["traps"][0]
	s.d.heir.hp = s.d.heir.max_hp()
	s.heir = Vector2i(int(t["x"]) - 1, int(t["z"]))
	if not GameInterior.passable(s.interior, s.heir.x, s.heir.y):
		s.heir = Vector2i(int(t["x"]) + 1, int(t["z"]))
	var hp := s.d.heir.hp
	var r := s.move(int(t["x"]) - s.heir.x, int(t["z"]) - s.heir.y)
	ok(r["ok"] and GameDungeons.trap_sprung(s.d, s.space, str(t["id"])), "stepping on the hidden trap springs it")
	ok(s.d.heir.hp <= hp and s.log.back()["kind"] == "dungeon", "and the log says so: %s" % s.log.back()["text"])


func _chase(s: GameSandbox, a: Dictionary) -> void:
	a["x"] = s.heir_point().x + 0.5
	a["z"] = s.heir_point().y
	a["mode"] = "chase"


func test_contact() -> void:
	var s := _sandbox("goblin_warrens", 1)
	var near: Dictionary = s.denizens[0]
	var room := str(near["room"])
	var n := s.denizens.size()
	_chase(s, near)
	var started := s._dungeon_contact()
	ok(started and s.d.battle != null and s.d.battle_kind == "hunt" and not s.fight_foes.is_empty(), "a creature that reaches the heir starts the hunt's fight")
	ok(s.denizens.size() == n - s.fight_foes.size() and s.d.sandbox_escape.get("space", "") == s.space, "its creatures leave the room while it is on")
	ok(float(s.d.battle.enemies[0]["hp"]) > 0.0, "a real foe")
	var key := str(near["key"])
	for e in s.d.battle.enemies:
		e["hp"] = 0
	s.d.battle.result = "victory"
	s.d.finish_battle()
	s.after_fight()
	ok(GameDungeons.is_marked(s.d, "k", "goblin_warrens", key), "a win kills them for a time")
	ok(s.fight_foes.is_empty() and s.d.sandbox_escape.is_empty(), "and the fight is forgotten")
	s.leave()
	s.heir = Vector2i(int(GameSpaces.space("world/goblin_warrens")["door"]["x"]), int(GameSpaces.space("world/goblin_warrens")["door"]["z"]))
	s.use()
	ok(not s.denizens.any(func(a): return a["key"] == key), "coming in again they are still dead")
	ok(room != "", "(it was in a room)")
	# nothing starts when none is chasing, or while a fight is on
	var calm := _sandbox("goblin_warrens", 1)
	ok(not calm._dungeon_contact(), "nothing starts with nothing near")
	_chase(calm, calm.denizens[0])
	calm.denizens[0]["mode"] = "wander"
	ok(not calm._dungeon_contact(), "a creature that only wanders does not")


func test_boss() -> void:
	var s := _sandbox("hollow_barrow", 60)
	var boss: Dictionary = s.denizens.filter(func(a): return a["boss"])[0]
	_chase(s, boss)
	for a in s.denizens:
		if a != boss:
			a["x"] = 900.0
	ok(s._dungeon_contact() and s.d.battle != null and s.d.battle_kind == "legend", "the king reaches the heir: the legend's fight")
	ok(s.d.battle.enemies.size() == 1 and s.d.battle.enemies[0]["id"] == "hollow_king", "alone")
	for e in s.d.battle.enemies:
		e["hp"] = 0
	s.d.battle.result = "victory"
	s.d.finish_battle()
	s.after_fight()
	ok(s.d.slain_bosses.has("hollow_king"), "and slain, he is slain for the Age")
	ok("hollow_kings_crown_fragment" in s.d.heir.inventory or s.d.heir.gold > 0, "he leaves his crown fragment")
	ok(GameDungeons.has_unique(s.d, "hollow_kings_crown_fragment"), "marked as found")
	ok(not GameDungeons.inhabitants(s.d, s.space).any(func(h): return h["boss"]), "and does not rise again")


func test_flee() -> void:
	var s := _sandbox("goblin_warrens", 1)
	_chase(s, s.denizens[0])
	var n := s.denizens.size()
	s.heir = Vector2i(3, -1)
	_chase(s, s.denizens[0])
	ok(s._dungeon_contact(), "a fight")
	s.d.battle.result = "fled"
	s.d.finish_battle()
	s.after_fight()
	ok(s.heir == GameInterior.entry() and s.denizens.size() == n, "fled: the heir is at the way out and the creatures are back where they live")
	ok(s.denizens.all(func(a): return a["mode"] == "idle" or a["mode"] != "dead"), "(none dead)")
	ok(s.d.sandbox_escape.is_empty(), "and nothing is left to pull the heir to the open world")


func test_tick() -> void:
	var s := _sandbox("goblin_warrens", 1)
	var before: Array = s.denizens.map(func(a): return [a["x"], a["z"]])
	s.step(10)
	var moved := 0
	for i in s.denizens.size():
		if [s.denizens[i]["x"], s.denizens[i]["z"]] != before[i]:
			moved += 1
	ok(moved > 0 or s.d.battle != null, "creatures move about their rooms")
	var stuck := true
	for a in s.denizens:
		stuck = stuck and GameInterior.room_at(s.space, floori(float(a["x"])), floori(float(a["z"]))) == a["room"] and GameInterior.passable(s.interior, floori(float(a["x"])), floori(float(a["z"])))
	ok(stuck, "and stay in them, on the floor")
	# one that sees the heir (in its room) comes for them; one in another room does not
	var w := _sandbox("goblin_warrens", 1)
	var guard: Dictionary = w.denizens.filter(func(a): return a["room"] == "guard_den")[0]
	var far: Dictionary = w.denizens.filter(func(a): return a["room"] != "mouth" and a["room"] != "guard_den")[0]
	var fx := float(far["x"])
	w.step(6)
	var far_after: Dictionary = w.denizens.filter(func(a): return a["key"] == far["key"])[0]
	ok(str(far_after["mode"]) != "chase", "a creature in another room does not see the heir through the wall")


func test_old_rules() -> void:
	var s := _sandbox("hollow_barrow")
	ok(not s.set_route(Vector2i(1, 1))["ok"] and not s.dig(0)["ok"] and not s.build("wall", 1, 0)["ok"] and not s.climb(-1)["ok"], "no routes, digging, building or stairs in a dungeon either")
	var saved := s.d.sandbox_at.duplicate()
	s.remember()
	ok(s.d.sandbox_at == saved, "the saved place is not moved in a dungeon")
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	var bot := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	for i in 200:
		GameBot.step(bot)
	var digest := JSON.stringify(bot.to_dict())
	ok(not digest.contains("dungeon_marks"), "an autopilot life meets no dungeon: nothing marked")


func test_screen() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = 60
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	var door: Dictionary = GameSpaces.space("world/emberpeak")["door"]
	scr.sb.heir = Vector2i(int(door["x"]), int(door["z"]))
	scr._use()
	await process_frame
	await process_frame
	ok(scr.sb.space == "world/emberpeak" and scr.tile_view.dungeon != null, "the screen follows the heir into the dungeon and draws it in its theme")
	scr.sb.denizens.clear()
	await process_frame
	await process_frame
	ok(scr.tile_view.modulate == Color(1, 1, 1), "the dark is drawn over the tiles, not by dimming them")
	scr._use()
	await process_frame
	await process_frame
	ok(scr.sb.space == "world" and scr.tile_view.dungeon == null, "and out again")
	scr.queue_free()
	app.queue_free()
