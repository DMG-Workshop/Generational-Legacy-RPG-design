## The heir's own spells (GameCasting.self_cast): the same system as a shop's spellcasting, paid in MP instead of gold. A healing spell mends the heir
## and the party, a cleansing one cures every sickness, a blessing is laid for the next fight; refusals pay nothing; a ward blessing, from the heir or
## from a shop, also turns the next hidden trap in a dungeon and is then spent on traps only. No die of the dynasty's is drawn, and the old dungeon-only
## spell table (GameDungeonSpells, `spells` in dungeons.json) is gone.
## Run: godot --headless --path . -s res://tests/test_game_self_cast.gd
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
	test_heal()
	test_cleanse()
	test_blessing()
	test_ward_and_traps()
	test_sandbox()
	test_save()
	print("self cast tests: %d checks, %d failures" % [checks, fails])
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
	ok(GameCasting.validate().is_empty(), "the casting data is valid: %s" % str(GameCasting.validate()))
	ok(GameDungeons.validate().is_empty(), "the dungeon data is valid: %s" % str(GameDungeons.validate()))
	ok(not GameDungeons.data().has("spells"), "the dungeons no longer keep a spell table of their own")
	var keep: Variant = GameCasting.data()["settings"]["trap_wards"]
	GameCasting.data()["settings"]["trap_wards"] = ["mass_heal"]
	ok(not GameCasting.validate().is_empty(), "a trap ward that is not a blessing fails the validator")
	GameCasting.data()["settings"]["trap_wards"] = keep
	var fights: Variant = GameCasting.data()["settings"]["self_fights"]
	GameCasting.data()["settings"]["self_fights"] = 0
	ok(not GameCasting.validate().is_empty(), "a blessing of no fights fails")
	GameCasting.data()["settings"]["self_fights"] = fights
	ok(GameCasting.validate().is_empty(), "(restored)")


func test_heal() -> void:
	var d := _dyn()
	ok(d.heir.spells.has("mass_heal") and d.heir.spells.has("ward"), "a level-40 cleric knows Mass Heal and Ward")
	var list := GameCasting.self_castable(d)
	ok(list.size() >= 2 and list.all(func(c): return GameCasting.kind_of(str(c["id"])) != ""), "the castable list holds only spells this system has a kind for (%d)" % list.size())
	var rng_before := d.rng.state
	var r := GameCasting.self_cast(d, "mass_heal")
	ok(not r["ok"] and d.heir.mp == d.heir.max_mp(), "a whole family wastes no MP: %s" % r["text"])
	d.heir.hp = 1
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 40, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	var mp := d.heir.mp
	r = GameCasting.self_cast(d, "mass_heal")
	var cost := GameCombat.ability_cost(GameCombat.spell("mass_heal"), d.heir.level)
	ok(r["ok"] and r["kind"] == "healing" and d.heir.hp > 1 and int(d.party.member("bren_cask")["hp"]) > 1, "Mass Heal mends the heir and the companion: %s" % r["text"])
	ok(d.heir.mp == mp - cost, "and costs its MP (%d)" % cost)
	ok(d.heir.hp <= d.heir.max_hp(), "never above the maximum")
	d.heir.hp = 1
	d.heir.mp = 0
	r = GameCasting.self_cast(d, "mass_heal")
	ok(not r["ok"] and d.heir.hp == 1 and r["text"].contains("MP"), "without the MP nothing happens: %s" % r["text"])
	ok(not GameCasting.self_cast(d, "fireball_of_doom")["ok"], "an unknown spell is refused")
	ok(not GameCasting.self_cast(d, "fireball")["ok"] or GameCasting.kind_of("fireball") != "", "a spell with no kind here is refused")
	var warrior := _dyn("warrior", 1)
	ok(GameCasting.self_castable(warrior).is_empty(), "a heir who knows none of them has nothing to cast")
	ok(not GameCasting.self_cast(warrior, "mass_heal")["ok"], "and cannot cast it")
	ok(d.rng.state == rng_before, "no die of the dynasty's was drawn")
	d.heir.mp = d.heir.max_mp()
	d.heir.hp = 1
	d.start_hunt("hunt")
	ok(d.battle != null and not GameCasting.self_cast(d, "mass_heal")["ok"], "never in a fight")


func test_cleanse() -> void:
	var d := _dyn()
	ok(d.heir.spells.has("cleanse"), "the cleric knows Cleanse")
	var r := GameCasting.self_cast(d, "cleanse")
	ok(not r["ok"] and d.heir.mp == d.heir.max_mp(), "with no sickness there is nothing to cleanse and nothing is paid: %s" % r["text"])
	var did := str(GameDisease.all()[0]["id"])
	GameDisease.infect(d.heir, did, "test")
	ok(d.heir.diseases.size() == 1, "a sick heir")
	var mp := d.heir.mp
	r = GameCasting.self_cast(d, "cleanse")
	ok(r["ok"] and r["kind"] == "cleansing" and d.heir.diseases.is_empty(), "Cleanse now really cures the sickness (it only healed in the dungeons before): %s" % r["text"])
	ok(d.heir.mp == mp - GameCombat.ability_cost(GameCombat.spell("cleanse"), d.heir.level), "for its MP")


func test_blessing() -> void:
	var d := _dyn()
	var mp := d.heir.mp
	var r := GameCasting.self_cast(d, "haste")
	if d.heir.spells.has("haste"):
		ok(r["ok"] and r["kind"] == "blessing" and str(GameCasting.blessing(d)["spell"]) == "haste", "a heir who knows Haste lays it for the next fight: %s" % r["text"])
		ok(int(GameCasting.blessing(d)["fights"]) == int(GameCasting.setting("self_fights")), "for the set number of fights")
		ok(not GameCasting.self_cast(d, "haste")["ok"], "the same blessing is not laid twice")
	r = GameCasting.self_cast(d, "ward")
	ok(r["ok"] and str(GameCasting.blessing(d)["spell"]) == "ward", "Ward is laid (replacing any other blessing): %s" % r["text"])
	ok(r["text"].contains("trap"), "and it says it turns a trap as well")
	var again := GameCasting.self_cast(d, "ward")
	var spent := d.heir.mp
	ok(not again["ok"] and d.heir.mp == spent, "a second ward is refused and free")
	ok(d.heir.mp < mp, "(the first cost MP)")
	ok(GameCasting.self_cast(d, "ward")["text"].contains("already"), "the refusal says it is already laid")


func test_ward_and_traps() -> void:
	var d := _dyn()
	ok(not GameCasting.ward_up(d), "no ward at first")
	var sp := "world/hollow_barrow"
	var t: Dictionary = GameDungeons.layout(sp)["traps"][0]
	d.heir.hp = d.heir.max_hp()
	GameCasting.self_cast(d, "ward")
	ok(GameCasting.ward_up(d), "a ward cast by the heir is up")
	var hp := d.heir.hp
	var s := GameDungeons.step_on(d, sp, int(t["x"]), int(t["z"]), GameCasting.ward_up(d))
	ok(not s["hit"] and d.heir.hp == hp and s["text"].contains("ward"), "a warded step turns the trap aside: %s" % s["text"])
	ok(GameDungeons.trap_sprung(d, sp, str(t["id"])), "(and the trap is spent)")
	GameCasting.spend_ward(d)
	ok(not GameCasting.ward_up(d), "the ward is spent on traps")
	ok(str(GameCasting.blessing(d).get("spell", "")) == "ward", "but it still blesses the next fight")
	# a ward bought at a shop turns a trap just the same (one system)
	var b := _dyn()
	b.world.location = "kingshold"
	b.heir.gold = 100000
	var span := float(GameDay.setting("day_seconds"))
	b.world_seconds = fposmod(12.0 / 24.0 - float(GameDay.setting("start_phase")), 1.0) * span   # noon: the shop is open
	GameCasting.cast(b, "spell_shop", "cast_ward")
	ok(GameCasting.ward_up(b), "a ward bought at the spell shop is a ward that turns traps")
	# a blessing that is not a trap ward does not
	b.blessing = {"spell": "haste", "fights": 1, "years": 1.0, "year": b.world.year, "gen": b.gen, "level": 1}
	ok(not GameCasting.ward_up(b), "haste turns no trap")


func test_sandbox() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	ok(not s.cast("mass_heal")["ok"], "on the open world a spell is not cast from the sandbox")
	var door: Dictionary = GameSpaces.space("world/hollow_barrow")["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	s.use()
	s.denizens.clear()
	d.heir.hp = 1
	var r := s.cast("mass_heal")
	ok(r["ok"] and d.heir.hp > 1 and s.log.back()["kind"] == "dungeon", "in a dungeon it is cast and logged: %s" % r["text"])
	ok(s.cast("ward")["ok"] and GameCasting.ward_up(d), "a ward is up")
	ok(not s.cast("ward")["ok"], "once")
	var t: Dictionary = GameDungeons.layout(s.space)["traps"][0]
	var hp := d.heir.hp
	s.heir = Vector2i(int(t["x"]) - 1, int(t["z"]))
	if not GameInterior.passable(s.interior, s.heir.x, s.heir.y):
		s.heir = Vector2i(int(t["x"]) + 1, int(t["z"]))
	s.move(int(t["x"]) - s.heir.x, int(t["z"]) - s.heir.y)
	ok(d.heir.hp >= hp and not GameCasting.ward_up(d), "the next trap was turned and the ward is spent on traps")
	s.heir = GameInterior.entry()
	s.use()
	ok(s.space == "world", "left the dungeon")
	ok(str(GameCasting.blessing(d).get("spell", "")) == "ward", "the ward still waits for the next fight (it is a blessing, not a flag of the visit)")


func test_save() -> void:
	var d := _dyn()
	GameCasting.self_cast(d, "ward")
	GameCasting.spend_ward(d)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(str(back.blessing.get("spell", "")) == "ward" and bool(back.blessing.get("trap_spent", false)) and not GameCasting.ward_up(back), "a spent ward survives a save and load as spent")
	var fresh := _dyn()
	GameCasting.self_cast(fresh, "ward")
	var back2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(fresh.to_dict())))
	ok(GameCasting.ward_up(back2) and not back2.blessing.has("trap_spent"), "a fresh ward stays fresh, with no mark")
	var old := {"spell": "ward", "fights": 1, "years": 1.0, "year": 0.0, "gen": 1, "level": 1}
	ok(GameCasting.load_blessing(old).has("spell") and not GameCasting.load_blessing(old).has("trap_spent"), "a save from before the mark loads as it was")
	var junk := old.duplicate()
	junk["trap_spent"] = "yes"
	ok(not GameCasting.load_blessing(junk).has("trap_spent"), "a damaged mark is dropped")
	ok(not _dyn().to_dict().has("blessing"), "nothing is written until something is cast")
