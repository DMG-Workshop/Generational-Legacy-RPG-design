## Spells in the dungeons (GameDungeonSpells; `spells` in data/world/dungeons.json): the heir casts what they know that works outside a
## fight. A heal mends the heir (and the party when the spell is a party one) for its own share and costs MP; a whole family wastes
## nothing; no MP or an unknown spell is refused; a ward turns the next hidden trap once. Only in a dungeon, never in a battle, no
## die of the dynasty's drawn.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_spells.gd
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
	test_cast()
	test_ward()
	test_sandbox()
	print("dungeon spell tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(class_id: String = "cleric", level: int = 40) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", class_id, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.learn_spells()
	d.heir.hp = d.heir.max_hp()
	d.heir.mp = d.heir.max_mp()
	return d


func test_data() -> void:
	ok(GameDungeons.validate().is_empty(), "the data is valid: %s" % str(GameDungeons.validate()))
	for id in GameDungeonSpells.entries():
		ok(not GameCombat.spell(str(id)).is_empty(), "%s is a spell of the game" % id)
	var keep: Variant = GameDungeons.data()["spells"]["ward"]["effect"]
	GameDungeons.data()["spells"]["ward"]["effect"] = "teleport"
	ok(not GameDungeons.validate().is_empty(), "an unknown effect fails the validator")
	GameDungeons.data()["spells"]["ward"]["effect"] = keep
	GameDungeons.data()["spells"]["nothing_at_all"] = {"effect": "heal"}
	ok(not GameDungeons.validate().is_empty(), "an entry that is not a spell fails")
	GameDungeons.data()["spells"].erase("nothing_at_all")
	ok(GameDungeons.validate().is_empty(), "(restored)")


func test_cast() -> void:
	var d := _dyn()
	ok(d.heir.spells.has("mass_heal") and d.heir.spells.has("ward"), "a level-40 cleric knows Mass Heal and Ward")
	var list := GameDungeonSpells.castable(d)
	ok(list.size() >= 2 and list.all(func(c): return GameDungeonSpells.entries().has(c["id"])), "the castable list holds only spells with an entry (%d)" % list.size())
	var rng_before := d.rng.state
	var r := GameDungeonSpells.cast(d, "mass_heal")
	ok(not r["ok"] and r["text"].contains("whole") and d.heir.mp == d.heir.max_mp(), "a whole family wastes no MP: %s" % r["text"])
	d.heir.hp = 1
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 40, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	var mp := d.heir.mp
	r = GameDungeonSpells.cast(d, "mass_heal")
	var cost := GameCombat.ability_cost(GameCombat.spell("mass_heal"), d.heir.level)
	ok(r["ok"] and d.heir.hp > 1 and int(d.party.member("bren_cask")["hp"]) > 1, "Mass Heal mends the heir and the companion: %s" % r["text"])
	ok(d.heir.mp == mp - cost, "and costs its MP (%d)" % cost)
	ok(d.heir.hp <= d.heir.max_hp(), "never above the maximum")
	d.heir.hp = 1
	d.heir.mp = 0
	r = GameDungeonSpells.cast(d, "mass_heal")
	ok(not r["ok"] and d.heir.hp == 1 and r["text"].contains("MP"), "without the MP nothing happens: %s" % r["text"])
	ok(not GameDungeonSpells.cast(d, "fireball_of_doom")["ok"], "an unknown spell is refused")
	var mage := _dyn("warrior", 1)
	ok(GameDungeonSpells.castable(mage).is_empty(), "a heir who knows none of them has nothing to cast")
	ok(not GameDungeonSpells.cast(mage, "mass_heal")["ok"], "and cannot cast it")
	ok(d.rng.state == rng_before, "no die of the dynasty's was drawn")


func test_ward() -> void:
	var d := _dyn()
	var cost := GameCombat.ability_cost(GameCombat.spell("ward"), d.heir.level)
	var r := GameDungeonSpells.cast(d, "ward")
	ok(r["ok"] and d.heir.mp == d.heir.max_mp() - cost, "Ward costs its MP: %s" % r["text"])
	var again := GameDungeonSpells.cast(d, "ward", true)
	ok(not again["ok"] and d.heir.mp == d.heir.max_mp() - cost, "a second ward while one is up is refused and free")
	var sp := "world/hollow_barrow"
	var t: Dictionary = GameDungeons.layout(sp)["traps"][0]
	d.heir.hp = d.heir.max_hp()
	var hp := d.heir.hp
	var s := GameDungeons.step_on(d, sp, int(t["x"]), int(t["z"]), true)
	ok(not s["hit"] and d.heir.hp == hp and s["text"].contains("ward"), "a warded step turns the trap aside: %s" % s["text"])
	ok(GameDungeons.trap_sprung(d, sp, str(t["id"])), "(and the trap is spent)")


func test_sandbox() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	ok(not s.cast("mass_heal")["ok"], "on the open world a spell is not cast here")
	var door: Dictionary = GameSpaces.space("world/hollow_barrow")["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	s.use()
	s.denizens.clear()
	d.heir.hp = 1
	var r := s.cast("mass_heal")
	ok(r["ok"] and d.heir.hp > 1 and s.log.back()["kind"] == "dungeon", "in a dungeon it is cast and logged: %s" % r["text"])
	ok(s.cast("ward")["ok"] and s.warded, "a ward is up")
	ok(not s.cast("ward")["ok"], "once")
	var t: Dictionary = GameDungeons.layout(s.space)["traps"][0]
	var hp := d.heir.hp
	s.heir = Vector2i(int(t["x"]) - 1, int(t["z"]))
	if not GameInterior.passable(s.interior, s.heir.x, s.heir.y):
		s.heir = Vector2i(int(t["x"]) + 1, int(t["z"]))
	s.move(int(t["x"]) - s.heir.x, int(t["z"]) - s.heir.y)
	ok(d.heir.hp >= hp and not s.warded, "the next trap was turned and the ward is gone")
	s.heir = GameInterior.entry()
	s.cast("ward")
	s.use()
	ok(s.space == "world" and not s.warded, "leaving drops a ward")
