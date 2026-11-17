## Damage and repair of what the family built (roadmap item 50): a piece is damaged by levels and wrecked at the top, what
## rested on it falls, a damaged roof no longer covers its room, mending costs part of the piece's cost, the vandals' raid hits
## pieces, a built piece adds to what a raider sees, damage saves and loads clean, and no dice of the dynasty's are drawn.
## Run: godot --headless --path . -s res://tests/test_game_repair.gd
extends SceneTree

var fails := 0
var checks := 0
const S := -1


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
	test_hurt()
	test_collapse()
	test_roof()
	test_repair()
	test_vandals()
	test_raid_sight()
	test_saving()
	test_sandbox()
	print("repair tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 500)
	d.heir.gold = 500
	return d


func _base() -> Vector2i:
	var b := GameBuild.base()
	return Vector2i(int(b["x"]), int(b["z"]))


func _ring(d: GameDynasty, x: int, z: int, n: int, y: int) -> void:
	for i in n:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + n - 1), Vector2i(x, z + i), Vector2i(x + n - 1, z + i)]:
			d.built[GameBuild.key(pos.x, y, pos.y)] = "wall"


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameBuild.validate()))
	var r: Dictionary = GameBuild.data()["repair"]
	var keep: Variant = r["max_damage"]
	r["max_damage"] = 1
	ok(not GameBuild.validate().is_empty(), "a wreck level of 1 (never merely damaged) is caught")
	r["max_damage"] = keep
	var share: Variant = r["repair_share"]
	r["repair_share"] = 0.0
	ok(not GameBuild.validate().is_empty(), "free mending is caught")
	r["repair_share"] = share
	ok(GameBuild.validate().is_empty(), "and mending the data clears it")


func test_hurt() -> void:
	var d := _fresh()
	var b := _base()
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	ok(GameRepair.level(d, b.x, S, b.y) == 0, "a new piece is whole")
	var h := GameRepair.hurt(d, b.x, S, b.y)
	ok(bool(h["ok"]) and not bool(h["wrecked"]) and GameRepair.level(d, b.x, S, b.y) == 1, "one blow damages it")
	ok(GameRepair.damaged(d) == [GameBuild.key(b.x, S, b.y)], "and it is listed")
	h = GameRepair.hurt(d, b.x, S, b.y)
	ok(bool(h["wrecked"]) and GameBuild.kind_at(d, b.x, S, b.y) == "" and d.damage.is_empty(), "a second wrecks it: removed, no damage left behind")
	ok(not bool(GameRepair.hurt(d, b.x, S, b.y)["ok"]), "nothing to hurt there now")


func test_collapse() -> void:
	var d := _fresh()
	var b := _base()
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	d.built[GameBuild.key(b.x, S - 1, b.y)] = "wall"
	d.built[GameBuild.key(b.x, S - 2, b.y)] = "wall"
	var c := GameBuild.collapse(d)
	ok(c == 0, "what is held stands")
	GameRepair.hurt(d, b.x, S, b.y, 2)
	ok(GameBuild.kind_at(d, b.x, S - 1, b.y) == "" and GameBuild.kind_at(d, b.x, S - 2, b.y) == "", "wrecking the bottom wall brings down the two above")
	var h := _fresh()
	h.built[GameBuild.key(b.x, S, b.y)] = "wall"
	h.built[GameBuild.key(b.x, S - 1, b.y)] = "wall"
	h.damage[GameBuild.key(b.x, S - 1, b.y)] = 1
	GameRepair.hurt(h, b.x, S, b.y, 2)
	ok(h.damage.is_empty(), "damage on what fell goes with it")
	# a door loses its frame
	var e := _fresh()
	for pos in [Vector2i(b.x, b.y), Vector2i(b.x + 2, b.y)]:
		e.built[GameBuild.key(pos.x, S, pos.y)] = "wall"
	e.built[GameBuild.key(b.x + 1, S, b.y)] = "door"
	GameRepair.hurt(e, b.x, S, b.y, 2)
	ok(GameBuild.kind_at(e, b.x + 1, S, b.y) == "", "a door whose wall is wrecked falls")


func test_roof() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x, b.y, 4, S)
	for c in GameBuild.rooms(d)[0]["cells"]:
		d.built[GameBuild.key(c.x, S - 1, c.y)] = "roof"
	ok(bool(GameBuild.rooms(d)[0]["roofed"]), "a roofed room")
	var cell: Vector2i = GameBuild.rooms(d)[0]["cells"][0]
	GameRepair.hurt(d, cell.x, S - 1, cell.y)
	ok(not bool(GameBuild.rooms(d)[0]["roofed"]), "a damaged roof leaks: the room is not roofed")
	ok(bool(GameRepair.repair(d, cell.x, S - 1, cell.y)["ok"]) and bool(GameBuild.rooms(d)[0]["roofed"]), "mending it roofs the room again")


func test_repair() -> void:
	var d := _fresh()
	var b := _base()
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	ok(GameRepair.repair(d, b.x, S, b.y)["text"] == GameBuild.text("undamaged"), "a whole piece needs no mending")
	GameRepair.hurt(d, b.x, S, b.y)
	var c := GameRepair.cost(d, b.x, S, b.y)
	ok(int(c["materials"]["oak"]) == 1 and int(c["gold"]) == 0, "a wall's damage costs half its two oak: %s" % str(c))
	var oak := GameCraft.have(d, "oak")
	var r := GameRepair.repair(d, b.x, S, b.y)
	ok(bool(r["ok"]) and GameRepair.level(d, b.x, S, b.y) == 0 and GameCraft.have(d, "oak") == oak - 1, "mending spends the oak and clears the damage")
	# a road has gold only
	d.built[GameBuild.key(b.x + 1, S, b.y)] = "road"
	d.damage[GameBuild.key(b.x + 1, S, b.y)] = 1
	c = GameRepair.cost(d, b.x + 1, S, b.y)
	ok(c["materials"].is_empty() and int(c["gold"]) >= 1, "a road is mended with gold: %s" % str(c))
	d.heir.gold = 0
	ok(not bool(GameRepair.repair(d, b.x + 1, S, b.y)["ok"]) and GameRepair.level(d, b.x + 1, S, b.y) == 1, "no gold, no mending, and nothing is spent")
	d.heir.gold = 100
	var due := int(GameRepair.cost(d, b.x + 1, S, b.y)["gold"])
	ok(bool(GameRepair.repair(d, b.x + 1, S, b.y)["ok"]) and d.heir.gold == 100 - due, "mending the road took its gold (%d)" % due)
	GameCraft.add_material(d, "oak", -GameCraft.have(d, "oak"))
	d.built[GameBuild.key(b.x + 2, S, b.y)] = "wall"
	d.damage[GameBuild.key(b.x + 2, S, b.y)] = 1
	var why := GameRepair.why_not(d, b.x + 2, S, b.y)
	ok(why.contains("oak"), "no oak, and it says so: %s" % why)
	# taking a damaged piece down clears it
	d.built[GameBuild.key(b.x + 3, S, b.y)] = "wall"
	d.damage[GameBuild.key(b.x + 3, S, b.y)] = 1
	ok(bool(GameBuild.remove(d, b.x + 3, S, b.y)["ok"]) and not d.damage.has(GameBuild.key(b.x + 3, S, b.y)), "taking a damaged piece down clears its damage")


func test_vandals() -> void:
	var d := _fresh()
	var b := _base()
	ok(not GameRaids.applicable(d, "vandals"), "nothing built, no vandals")
	ok(GameRaids.defend(d, "vandals")[0]["k"] == "info", "and they find nothing to break")
	for i in 6:
		d.built[GameBuild.key(b.x + i, S, b.y)] = "wall"
	ok(GameRaids.applicable(d, "vandals"), "built pieces draw them")
	var before := d.rng.state
	var out := GameRaids.defend(d, "vandals")
	ok(d.rng.state == before, "no dice of the dynasty's are drawn")
	ok(out[0]["k"] == "bad" or out[0]["k"] == "good", "they hit, or the guards beat them off")
	var a := _fresh()
	var c := _fresh()
	for i in 6:
		a.built[GameBuild.key(b.x + i, S, b.y)] = "wall"
		c.built[GameBuild.key(b.x + i, S, b.y)] = "wall"
	GameRaids.defend(a, "vandals")
	GameRaids.defend(c, "vandals")
	ok(a.damage == c.damage and a.built == c.built, "the same house meets the same damage")
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var e := _fresh()
	for i in 6:
		e.built[GameBuild.key(b.x + i, S, b.y)] = "wall"
	var lines := GameRepair.vandalise(e, r)
	ok(lines.size() == int(GameRepair.setting("vandal_hits")), "they strike vandal_hits pieces: %d" % lines.size())
	var hurt := 0
	for k in e.damage:
		hurt += 1
	ok(hurt == lines.size(), "each blow left a mark")
	ok(GameEvents.event_def("raid_vandals").get("raid", false) == true, "the event is a raid")


func test_raid_sight() -> void:
	var d := _fresh()
	var plain := GameRaids.house_value(d)
	ok(plain == 0, "a plain house shows nothing")
	var b := _base()
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	ok(GameRaids.house_value(d) > plain, "a built piece adds to what a raider sees: %d" % GameRaids.house_value(d))
	ok(GameRaids.has_target(d), "and makes the house a target")


func test_saving() -> void:
	var d := _fresh()
	var b := _base()
	ok(not d.to_dict().has("damage"), "an undamaged house writes no damage key")
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	d.built[GameBuild.key(b.x + 1, S, b.y)] = "wall"
	d.damage[GameBuild.key(b.x, S, b.y)] = 1
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.damage == d.damage, "damage comes back through JSON")
	var raw := d.to_dict()
	raw["damage"] = {GameBuild.key(b.x, S, b.y): 1, "9,9,9": 1, GameBuild.key(b.x + 1, S, b.y): 7, "bad": 1}
	ok(GameDynasty.from_dict(raw).damage == {GameBuild.key(b.x, S, b.y): 1}, "a bad key, a piece not built and a level at the wreck are dropped")
	raw["damage"] = "nonsense"
	ok(GameDynasty.from_dict(raw).damage.is_empty(), "a damaged value of the wrong type loads as none")
	var old := _fresh().to_dict()
	ok(GameDynasty.from_dict(old).damage.is_empty(), "an old save has none")


func test_sandbox() -> void:
	var d := _fresh()
	var b := _base()
	var sb := GameSandbox.start(d)
	var t := sb.heir + Vector2i(1, 0)
	d.built[GameBuild.key(t.x, S, t.y)] = "wall"
	GameRepair.hurt(d, t.x, S, t.y)
	var r := sb.repair_at(1, 0)
	ok(bool(r["ok"]) and d.damage.is_empty(), "the sandbox mends the piece beside the heir")
	ok(not bool(sb.repair_at(0, 1)["ok"]), "and says there is nothing to mend elsewhere")
	ok(b.x >= 0, "base known")
