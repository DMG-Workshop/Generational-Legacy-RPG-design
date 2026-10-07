## Companion ageing: ages against the world calendar, old age and its toll, death and retirement
## (in service and away from it), successors, succession, the tavern and life-screen lines,
## save/load (old saves too), the autopilot and determinism.
## Run: godot --headless --path . -s res://tests/test_game_aging.gd
extends SceneTree

const Tavern := preload("res://ui/play/tavern_panel.gd")
const DIR := "res://tests/fixtures/"

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _new(seed_val: int = 77, race: String = "human") -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Aldo", "warrior", "faetouched", race)
	d.pending_event = {}
	d.heir.gold = 100000
	return d


## Years pass for the world and the party, not the heir.
func _years(d: GameDynasty, years: float) -> Array:
	var msgs: Array = []
	d.world.advance(years, d.rng)
	d.party.on_years(d, years, msgs)
	return msgs


## Settings overrides for one test; `_restore` puts the data back.
var _saved: Dictionary = {}


func _tune(key: String, value: Variant) -> void:
	if not _saved.has(key):
		_saved[key] = GameParty.setting(key)
	GameParty._settings[key] = value


func _restore() -> void:
	for k in _saved:
		GameParty._settings[k] = _saved[k]
	_saved = {}


func _init() -> void:
	GameData.load_all()
	test_data()
	test_ageing_over_years()
	test_old_age_and_decline()
	test_death_in_service()
	test_retirement_in_service()
	test_offscreen_end()
	test_no_successor()
	test_pale_warden_successor()
	test_fallen_keeps_the_line()
	test_succession()
	test_distribution()
	test_tavern_lines()
	test_save_load()
	test_old_saves()
	test_bot()
	test_determinism()
	print("aging tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	GameParty.setting("old_fraction")
	for key in ["old_fraction", "decline_per_lifespan", "decline_cap", "lifespan_spread", "retire_per_lifespan",
			"successor_wait_years", "default_age_after_adult", "past_kept", "past_shown", "bot_dismiss_decline", "farewell"]:
		ok(GameParty._settings.has(key), "setting %s" % key)
	var d := _new(11)
	for c in GameData.companions:
		var id: String = c["id"]
		ok(c.has("age"), "%s has an age at hire" % id)
		ok(c.has("farewell") and str(c["farewell"]).contains("{name}"), "%s has a farewell line" % id)
		ok(not GameWorld.place(c.get("retires_to", "")).is_empty(), "%s retires to a real place" % id)
		var adult := float(GameData.races[c["race"]]["start_age"])
		var a := d.party.hire_age(d, id)
		ok(a >= adult and a < d.party.old_age(d, id), "%s is hired as an adult before old age (%d, old at %d)" % [id, int(a), int(d.party.old_age(d, id))])
		ok(a == floorf(a), "%s hire age is a whole year" % id)
		var span := d.party.lifespan(d, id)
		var base := float(c.get("lifespan", GameData.races[c["race"]]["lifespan"]))
		var spread := float(GameParty.setting("lifespan_spread"))
		ok(span >= base * (1.0 - spread) - 0.001 and span <= base * (1.0 + spread) + 0.001, "%s lifespan %.1f near %d" % [id, span, int(base)])
	ok(absf(d.party.lifespan(d, "pale_warden") / 700.0 - 1.0) <= float(GameParty.setting("lifespan_spread")) + 0.001, "the Pale Warden's own lifespan overrides her race's")
	# Each house meets different people: ages and lifespans differ by seed but never by asking twice.
	var e := _new(12)
	var differs := false
	for c in GameData.companions:
		differs = differs or e.party.hire_age(e, c["id"]) != d.party.hire_age(d, c["id"]) or e.party.lifespan(e, c["id"]) != d.party.lifespan(d, c["id"])
		ok(d.party.hire_age(d, c["id"]) == d.party.hire_age(d, c["id"]), "hire age is fixed")
	ok(differs, "another house meets them at other ages")
	# A companion with no age in the data is met a few years past the race's adult age.
	var probe := {"id": "probe_noage", "name": "Probe", "race": "dwarf", "class": "warrior", "where": ["hearthmere"], "fee": 1, "upkeep": 1, "requires": {}}
	GameData.companions.append(probe)
	var extra: Array = GameParty.setting("default_age_after_adult")
	var pa := d.party.hire_age(d, "probe_noage")
	ok(pa >= 22.0 + float(extra[0]) and pa <= 22.0 + float(extra[1]), "default hire age from the race (%d)" % int(pa))
	GameData.companions.erase(probe)


func test_ageing_over_years() -> void:
	var d := _new(21)
	var p := d.party
	var met := p.age(d, "bren_cask")
	ok(met == p.hire_age(d, "bren_cask"), "a stranger is met at their hire age")
	_years(d, 30.0)
	ok(p.age(d, "bren_cask") == met, "someone never hired does not age on the shelf")
	p.hire(d, "bren_cask")
	ok(absf(float(p.history["bren_cask"]["born"]) - (d.world.year - met)) < 0.001, "birth year is set against the calendar at hire")
	ok(p.age(d, "bren_cask") == met, "hired at that age")
	_years(d, 4.0)
	ok(absf(p.age(d, "bren_cask") - (met + 4.0)) < 0.001, "four years on, four years older")
	p.dismiss(d, "bren_cask")
	_years(d, 6.0)
	ok(absf(p.age(d, "bren_cask") - (met + 10.0)) < 0.001, "a dismissed companion keeps ageing at home")
	var text := p.hire(d, "bren_cask")
	ok(text.contains("asks no fee") and absf(p.age(d, "bren_cask") - (met + 10.0)) < 0.001, "rehired at their true age")
	# The heir's own ageing does not move the calendar; only the world's years count.
	var before := p.age(d, "bren_cask")
	d.heir.age += 5.0
	ok(p.age(d, "bren_cask") == before, "age follows the world year, not the heir")
	d._pass_years(2.0, [])
	ok(absf(p.age(d, "bren_cask") - before - 2.0) < 0.001, "years spent on actions age companions")


func test_old_age_and_decline() -> void:
	var d := _new(31)
	var p := d.party
	d.heir.level = 40
	p.hire(d, "bren_cask")
	var span := p.lifespan(d, "bren_cask")
	var old := p.old_age(d, "bren_cask")
	ok(absf(old - span * float(GameParty.setting("old_fraction"))) < 0.001, "old age is a share of the lifespan")
	var rec: Dictionary = p.history["bren_cask"]
	var young := p.unit(d, p.members[0])
	rec["born"] = d.world.year - (old - 1.0)
	rec["rolled"] = d.world.year
	ok(not p.is_old(d, "bren_cask") and p.decline(d, "bren_cask") == 0.0, "a year short of old age, no decline")
	ok(not p.age_text(d, "bren_cask").contains("old"), "not called old yet: %s" % p.age_text(d, "bren_cask"))
	_tune("retire_per_lifespan", 0.0)
	var msgs: Array = []
	var guard := 0
	while not msgs.any(func(m): return str(m).contains("growing old")) and guard < 4:
		guard += 1
		msgs.append_array(_years(d, 1.0))
	ok(p.has_member("bren_cask") and msgs.any(func(m): return str(m).contains("Bren Cask, %d now, is growing old" % int(p.age(d, "bren_cask")))), "crossing old age is told once: %s" % str(msgs))
	ok(d.journal.any(func(l): return str(l).contains("is growing old")), "and journaled")
	var later := _years(d, 1.0)
	ok(not later.any(func(m): return str(m).contains("growing old")), "only once")
	_restore()
	ok(p.is_old(d, "bren_cask"), "now old")
	var want := float(GameParty.setting("decline_per_lifespan")) * (p.age(d, "bren_cask") - old) / span
	ok(absf(p.decline(d, "bren_cask") - want) < 0.0001, "decline grows with the years past old age (%.3f)" % want)
	var u := p.unit(d, p.members[0])
	var share := 1.0 - p.decline(d, "bren_cask")
	ok(absf(u.attack_power() / young.attack_power() - share) < 0.01, "an old companion hits that much softer (%.3f vs %.3f)" % [u.attack_power() / young.attack_power(), share])
	ok(absf(float(u.max_hp()) / float(young.max_hp()) - share) < 0.02, "and has that much less health")
	ok(p.age_text(d, "bren_cask").contains("old: %d%% weaker" % int(round(p.decline(d, "bren_cask") * 100.0))), "the tavern line says so: %s" % p.age_text(d, "bren_cask"))
	ok(str(Tavern.summary_lines(d)[0]).begins_with("Bren Cask (%d, old: %d%% weaker), Human Warrior" % [int(p.age(d, "bren_cask")), int(round(p.decline(d, "bren_cask") * 100.0))]), "the life screen says so: %s" % Tavern.summary_lines(d)[0])
	# Just past the threshold the toll does not show yet: "old", never "0% weaker".
	var keep: float = rec["born"]
	rec["born"] = d.world.year - (old + 0.1)
	ok(p.is_old(d, "bren_cask") and p.age_text(d, "bren_cask").ends_with(", old") and str(Tavern.summary_lines(d)[0]).contains("(%d, old)" % int(p.age(d, "bren_cask"))), "newly old: %s / %s" % [p.age_text(d, "bren_cask"), Tavern.summary_lines(d)[0]])
	rec["born"] = keep
	# The decline is capped, however long they last.
	rec["born"] = d.world.year - span * 3.0
	ok(p.decline(d, "bren_cask") == float(GameParty.setting("decline_cap")), "decline capped")
	ok(p.unit(d, p.members[0]).attack_power() > 0.0, "a capped companion still fights")
	# Wounds never exceed the shrunken body.
	p.members[0]["hp"] = young.max_hp()
	ok(p.unit(d, p.members[0]).hp <= p.unit(d, p.members[0]).max_hp(), "health clamps to the old body")
	# Decline is the same share at level 1 and level 5000, generation 1 and 300.
	for spec in [[1, 1], [5000, 300]]:
		var fresh := GameParty.build_unit("bren_cask", spec[0], spec[1])
		var aged := GameParty.build_unit("bren_cask", spec[0], spec[1], "", 0.2)
		ok(absf(aged.attack_power() / fresh.attack_power() - 0.8) < 0.01, "20%% decline holds at L%d g%d" % spec)


## Force the end of the current holder: far past their lifespan, death is near certain.
func _force_end(d: GameDynasty, id: String, how: String) -> Array:
	_tune("retire_per_lifespan", 0.0 if how == "died" else 1000000.0)
	var rec: Dictionary = d.party.history[id]
	var span := d.party.lifespan(d, id)
	rec["born"] = d.world.year - (span * (1.6 if how == "died" else 0.71))
	rec["rolled"] = d.world.year - (span * 0.01 if how == "retired" else 0.0)
	var msgs := _years(d, 1.0)
	_restore()
	return msgs


func test_death_in_service() -> void:
	var d := _new(41)
	var p := d.party
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	p.member("bren_cask")["battles"] = 7
	var span := p.lifespan(d, "bren_cask")
	var msgs := _force_end(d, "bren_cask", "died")
	ok(not p.has_member("bren_cask") and p.members.size() == 1, "Bren dies and leaves the party")
	var line := msgs.filter(func(m): return str(m).contains("dies of old age"))
	ok(line.size() == 1 and str(line[0]).begins_with("Bren Cask dies of old age at ") and str(line[0]).contains("House %s" % d.dynasty_name), "death told: %s" % str(msgs))
	ok(d.journal.has(line[0]), "death journaled")
	var rec: Dictionary = p.history["bren_cask"]
	ok(rec["status"] == "dead" and int(rec["line"]) == 1, "recorded dead, the line moves on")
	var e: Dictionary = rec["past"].back()
	ok(e["name"] == "Bren Cask" and e["end"] == "died" and e["served"] and int(e["year"]) == int(d.world.year) + 1, "past entry: %s" % str(e))
	ok(int(e["age"]) == int(span * 1.6 + 1.0) and not rec.has("born"), "age at death kept (%d), birth year cleared for the next" % int(e["age"]))
	ok(str(rec["name"]).ends_with(" Cask") and rec["name"] != "Bren Cask", "a successor takes the name: %s" % rec["name"])
	# He cannot be hired again; his kin can after a few years, at their own age and for a fee.
	ok(p.hire_block(d, "bren_cask") != "", "no rehire right after death")
	ok(p.locked_reason(d, "bren_cask").contains("from year"), "the wait is told: %s" % p.locked_reason(d, "bren_cask"))
	ok(p.fee(d, "bren_cask") > 0, "the successor wants the full fee")
	_years(d, float(GameParty.setting("successor_wait_years")))
	ok(p.locked_reason(d, "bren_cask") == "", "the successor comes after the wait")
	var kin_age := p.hire_age(d, "bren_cask")
	var text := p.hire(d, "bren_cask")
	ok(text.contains("joins") and p.member("bren_cask")["name"] == rec["name"], "the successor is hired: %s" % text)
	ok(absf(p.age(d, "bren_cask") - kin_age) < 0.001 and kin_age < p.old_age(d, "bren_cask"), "at their own age (%d)" % int(kin_age))
	ok(p.history["bren_cask"]["past"].size() == 1, "the dead stay in the record")
	# Battles belong to whoever fought them: Bren's stay with Bren, the successor starts at none.
	ok(int(e["battles"]) == 7 and int(rec["battles"]) == 0, "Bren's 7 battles go with him (%d), the role starts over (%d)" % [int(e["battles"]), int(rec["battles"])])
	var t = Tavern.new()
	t.dynasty = d
	var card: Control = t._member_card(p.member("bren_cask"))
	ok(_texts(card).has("Battles 0"), "the successor's card counts no battles: %s" % str(_texts(card)))
	card.free()
	ok(t._records().any(func(l): return str(l).begins_with("Bren Cask died of old age at") and str(l).ends_with("in the house's service (7 battles).")), "Bren's line keeps his battles: %s" % str(t._records()))
	t.free()


func test_retirement_in_service() -> void:
	var d := _new(42)
	var p := d.party
	d.heir.level = 5
	d.world.visit("brinehaven")
	p.hire(d, "grull_one_tusk")
	var msgs := _force_end(d, "grull_one_tusk", "retired")
	ok(not p.has_member("grull_one_tusk"), "Grull retires and leaves the party")
	var rec: Dictionary = p.history["grull_one_tusk"]
	var e: Dictionary = rec["past"].back()
	ok(rec["status"] == "retired" and e["end"] == "retired" and e["name"] == "Grull One-Tusk", "retirement recorded")
	var want: String = str(GameParty.def("grull_one_tusk")["farewell"]).format({"name": "Grull One-Tusk", "heir": d.heir.name, "place": "Brinehaven", "age": int(e["age"])})
	ok(msgs.has(want) and d.journal.has(want), "the goodbye uses the data's farewell: %s" % str(msgs))
	ok(p.hire_block(d, "grull_one_tusk") != "", "a retired companion cannot be rehired")
	ok(p.display_name("grull_one_tusk") != "Grull One-Tusk", "whoever comes next has another name")


func test_offscreen_end() -> void:
	var d := _new(43)
	var p := d.party
	p.hire(d, "maddy_thorn")
	p.dismiss(d, "maddy_thorn")
	var msgs := _force_end(d, "maddy_thorn", "died")
	var rec: Dictionary = p.history["maddy_thorn"]
	ok(rec["status"] == "dead", "a dismissed companion dies at home")
	ok(msgs.any(func(m): return str(m).begins_with("Word reaches Aldo: Maddy Thorn, who once rode with House")), "word reaches the heir: %s" % str(msgs))
	ok(not rec["past"].back()["served"], "recorded as away from the house")
	var t = Tavern.new()
	t.dynasty = d
	var lines: Array = t._records()
	ok(lines.any(func(l): return str(l).begins_with("Maddy Thorn died of old age at") and str(l).ends_with("after leaving the house's service.")), "the tavern says so: %s" % str(lines))
	ok(t._rumour("maddy_thorn").contains("cup turned down for Maddy Thorn"), "the barkeep remembers: %s" % t._rumour("maddy_thorn"))
	t.free()
	# Someone who walked out unpaid also grows old and may retire far away.
	p.hire(d, "bren_cask")
	p.history["bren_cask"]["status"] = "left"
	p.members.clear()
	msgs = _force_end(d, "bren_cask", "retired")
	ok(p.history["bren_cask"]["status"] == "retired" and msgs.any(func(m): return str(m).contains("has retired to Brinehaven at")), "a walked-out companion retires off-screen: %s" % str(msgs))


func test_no_successor() -> void:
	var d := _new(44)
	var p := d.party
	var c := GameParty.def("bren_cask")
	var pattern: String = c["successor"]
	c.erase("successor")
	p.hire(d, "bren_cask")
	_force_end(d, "bren_cask", "died")
	ok(p.history["bren_cask"]["name"] == "Bren Cask", "with no successor in the data the name stays")
	_years(d, 50.0)
	ok(p.locked_reason(d, "bren_cask") == "No one has come to take up the work.", "and no one ever takes up the work")
	ok(not p.available_here(d).has("bren_cask") and p.hire(d, "bren_cask") != "" and not p.has_member("bren_cask"), "never hireable again")
	c["successor"] = pattern


func test_pale_warden_successor() -> void:
	var d := _new(45)
	var p := d.party
	d.gen = 60
	d.heir.gen = 60
	d.heir.level = 50
	d.set_flag("rift_open")
	d.world.visit("kingshold")
	ok(p.hire(d, "pale_warden").contains("joins"), "the Pale Warden rides with the house")
	var age0 := p.age(d, "pale_warden")
	ok(age0 >= 380.0 and age0 <= 420.0, "she is centuries old (%d)" % int(age0))
	ok(not p.is_old(d, "pale_warden"), "and not yet old")
	_force_end(d, "pale_warden", "died")
	var rec: Dictionary = p.history["pale_warden"]
	ok(str(rec["name"]).ends_with(" of the White Scale"), "her successor: %s" % rec["name"])
	ok(p.locked_reason(d, "pale_warden").begins_with(str(rec["name"])), "the successor waits: %s" % p.locked_reason(d, "pale_warden"))
	_years(d, float(GameParty.setting("successor_wait_years")))
	ok(p.locked_reason(d, "pale_warden") == "", "then comes to Kingshold")
	var a := p.hire_age(d, "pale_warden")
	ok(a >= 140.0 and a <= 200.0, "the successor's own age from the data (%d)" % int(a))
	ok(p.hire(d, "pale_warden").contains("joins"), "and can be hired")


func test_fallen_keeps_the_line() -> void:
	var d := _new(46)
	var p := d.party
	d.heir.level = 5
	d.world.visit("brinehaven")
	p.hire(d, "old_netta")
	var age0 := int(p.age(d, "old_netta"))
	p._fall(d, p.members[0])
	var rec: Dictionary = p.history["old_netta"]
	ok(rec["status"] == "fallen" and rec["fallen"] == ["Old Netta"], "battle death rules unchanged")
	ok(int(rec["line"]) == 1 and rec["past"].back()["end"] == "fell" and int(rec["past"].back()["age"]) == age0, "the fallen are in the house's past with their age")
	ok(str(rec["name"]).begins_with("Young "), "kin: %s" % rec["name"])
	var a := p.hire_age(d, "old_netta")
	ok(a >= 60.0 and a <= 90.0, "Young %s is met at the successor's age (%d)" % [rec["name"], int(a)])
	ok(p.locked_reason(d, "old_netta").begins_with("In mourning"), "mourning is by generation as before")


func test_succession() -> void:
	var d := _new(51)
	var p := d.party
	d.heir.level = 5
	d.world.visit("ironford")
	p.hire(d, "hulda_stonebrow")
	d.world.visit("hearthmere")
	p.hire(d, "bren_cask")
	p.history["hulda_stonebrow"]["born"] = d.world.year - 70.0
	p.history["bren_cask"]["born"] = d.world.year - 60.0
	var hulda0 := p.age(d, "hulda_stonebrow")
	_tune("retire_per_lifespan", 0.0)
	var heirs := 0
	var bren_gone_at := -1
	for i in 5:
		_years(d, 12.0)
		d.heir.gold = 100000
		d._die("test")
		var before := p.age(d, "hulda_stonebrow")
		d.choose_heir(0)
		heirs += 1
		ok(p.age(d, "hulda_stonebrow") == before, "no years pass at the hand-over")
		if bren_gone_at < 0 and not p.has_member("bren_cask"):
			bren_gone_at = heirs
	_restore()
	ok(p.has_member("hulda_stonebrow"), "a dwarf serves on through %d heirs (now %d)" % [heirs, int(p.age(d, "hulda_stonebrow"))])
	ok(absf(p.age(d, "hulda_stonebrow") - hulda0 - 60.0) < 0.01, "and has aged with every year of them")
	ok(bren_gone_at > 0 and p.history["bren_cask"]["status"] == "dead", "a human hired with her is long gone (by heir %d)" % bren_gone_at)
	var u := p.unit(d, p.member("hulda_stonebrow"))
	ok(u.level == d.heir.level and u.gen == d.gen, "she keeps pace with the new heir")


## Across many people of each race: median age at death near the lifespan, a minority retire.
func test_distribution() -> void:
	var n := 240
	for race in GameData.races:
		var id: String = "probe_" + race
		var probe := {"id": id, "name": "Probe", "successor": "{given} Probe", "race": race, "class": "warrior", "where": ["hearthmere"], "fee": 1, "upkeep": 1, "requires": {}}
		GameData.companions.append(probe)
		var base := float(GameData.races[race]["lifespan"])
		var res := {}
		for mode in ["no_retire", "retire"]:
			if mode == "no_retire":
				_tune("retire_per_lifespan", 0.0)
			var d := _new(600 + race.length() * 13)
			var p := d.party
			var died: Array = []
			var exits: Array = []
			var retired := 0
			var step := maxf(1.0, base / 85.0)
			for k in n:
				p.history[id] = {"name": "Probe", "status": "dismissed", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": k, "past": []}
				p.history[id]["born"] = d.world.year - (p.old_age(d, id) - 1.0)
				p.history[id]["rolled"] = d.world.year
				var guard := 0
				while p.history[id]["status"] == "dismissed" and guard < 2000:
					guard += 1
					d.world.year += step
					p._grow_old(d, [])
				var e: Dictionary = p.history[id]["past"].back()
				exits.append(float(e["age"]) / base)
				if e["end"] == "died":
					died.append(float(e["age"]) / base)
				else:
					retired += 1
			_restore()
			res[mode] = {"died": _median(died), "exit": _median(exits), "retired": float(retired) / float(n)}
		GameData.companions.erase(probe)
		var a: Dictionary = res["no_retire"]
		var b: Dictionary = res["retire"]
		ok(a["retired"] == 0.0 and absf(a["died"] - 1.0) < 0.05, "%s: median death at %.2f of the lifespan (%d)" % [race, a["died"], int(base)])
		ok(absf(b["died"] - 1.0) < 0.06, "%s: with retirement, those who die still die near the lifespan (%.2f)" % [race, b["died"]])
		ok(b["retired"] > 0.12 and b["retired"] < 0.4, "%s: a minority retire (%.0f%%)" % [race, b["retired"] * 100.0])
		ok(b["exit"] > 0.85 and b["exit"] < 1.02, "%s: half have left service by %.2f of the lifespan" % [race, b["exit"]])
		print("  %s (%d): median death %.2f, with retirement death %.2f exit %.2f retired %.0f%%" % [race, int(base), a["died"], b["died"], b["exit"], b["retired"] * 100.0])


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func test_tavern_lines() -> void:
	var d := _new(61)
	var p := d.party
	var t = Tavern.new()
	t.dynasty = d
	var card: Control = t._offer_card("bren_cask")
	ok(_texts(card).any(func(s): return s == "Age %d of ~%d" % [int(p.hire_age(d, "bren_cask")), int(round(p.lifespan(d, "bren_cask")))]), "a seeker's card shows age and lifespan: %s" % str(_texts(card)))
	card.free()
	p.hire(d, "bren_cask")
	p.history["bren_cask"]["born"] = d.world.year - p.old_age(d, "bren_cask") - 5.0
	var mc: Control = t._member_card(p.members[0])
	ok(_texts(mc).any(func(s): return s.begins_with("Age ") and s.contains("old: ")), "a member's card shows old age and its toll: %s" % str(_texts(mc)))
	mc.free()
	p.dismiss(d, "bren_cask")
	var lines: Array = t._records()
	ok(lines.any(func(l): return str(l).begins_with("Bren Cask, %d (old): paid off" % int(p.age(d, "bren_cask")))), "a past hire's age in the records: %s" % str(lines))
	d.world.visit("hearthmere")
	var oc: Control = t._offer_card("bren_cask")
	ok(_texts(oc).any(func(s): return s.contains("old: ")), "an old companion is offered as old")
	oc.free()
	# Many lives in one line: only the last few are listed, with a count of the rest.
	var rec: Dictionary = p.history["bren_cask"]
	for i in 9:
		_force_end(d, "bren_cask", "died" if i % 2 == 0 else "retired")
		rec["born"] = d.world.year - 30.0
		rec["rolled"] = d.world.year
		rec["status"] = "dismissed"
	ok(rec["past"].size() == int(GameParty.setting("past_kept")) and int(rec["line"]) == 9, "the record keeps the last %d of 9" % rec["past"].size())
	lines = t._records()
	ok(lines.any(func(l): return str(l) == "Before them, 6 more served the house in this line."), "older lives are counted: %s" % str(lines))
	ok(lines.filter(func(l): return str(l).contains(" in year ")).size() == int(GameParty.setting("past_shown")), "the last %d are listed" % int(GameParty.setting("past_shown")))
	ok(lines.any(func(l): return str(l).contains("retired to Brinehaven at")), "a retirement line: %s" % str(lines))
	t.free()


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out


func test_save_load() -> void:
	var d := _new(71)
	var p := d.party
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	_years(d, 7.25)
	p.dismiss(d, "maddy_thorn")
	_force_end(d, "bren_cask", "died")
	_years(d, 1.5)
	var text := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(text))
	ok(JSON.stringify(e.to_dict()) == text, "a save with ages round-trips exactly")
	for id in ["bren_cask", "maddy_thorn"]:
		ok(e.party.age(e, id) == p.age(d, id) and e.party.lifespan(e, id) == p.lifespan(d, id), "%s: same age and lifespan after load" % id)
	ok(typeof(e.party.history["bren_cask"]["line"]) == TYPE_INT and typeof(e.party.history["bren_cask"]["past"][0]["age"]) == TYPE_INT, "ints restored")
	ok(e.party.locked_reason(e, "bren_cask") == p.locked_reason(d, "bren_cask"), "the successor's wait survives")
	# Both copies age on identically.
	for x in [d, e]:
		for i in 120:
			_years(x, 1.0)
	ok(JSON.stringify(d.to_dict()) == JSON.stringify(e.to_dict()), "120 years later the loaded copy is identical")
	ok(p.history["maddy_thorn"]["status"] in ["dead", "retired"], "and Maddy's time came at home (%s)" % p.history["maddy_thorn"]["status"])


func test_old_saves() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "old_save_party_preaging.json"))
	ok(not raw.is_empty() and not raw["party"]["history"]["bren_cask"].has("born"), "a save from before ageing")
	var d := GameDynasty.from_dict(raw)
	var p := d.party
	ok(p.members.size() == 2, "its party loads")
	for id in ["bren_cask", "sister_oriel", "maddy_thorn", "grull_one_tusk"]:
		ok(p.history[id].has("born") and absf(p.age(d, id) - p.hire_age(d, id)) < 0.001, "%s gets an age from the data (%d)" % [id, int(p.age(d, id))])
	ok(not p.history["old_netta"].has("born") and int(p.history["old_netta"]["line"]) == 1, "a fallen line's kin is not yet met")
	var a := p.hire_age(d, "old_netta")
	ok(a >= 60.0 and a <= 90.0, "Young Wren will be met at a successor's age (%d)" % int(a))
	var again := GameDynasty.from_dict(raw)
	ok(JSON.stringify(again.to_dict()) == JSON.stringify(d.to_dict()), "old save loads the same way every time")
	var j := JSON.stringify(d.to_dict())
	ok(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j)).to_dict()) == j, "and round-trips once loaded")
	var t = Tavern.new()
	t.dynasty = d
	ok(t._records().size() >= 3, "records render: %s" % str(t._records()))
	ok(Tavern.summary_lines(d).size() == 2 and str(Tavern.summary_lines(d)[0]).begins_with("Bren Cask ("), "summary lines render")
	t.free()
	for i in 200:
		if d.state == "succession":
			d.choose_heir(0)
		elif d.state == "life":
			GameBot.step(d)
	ok(d.state == "life" or d.state == "succession", "the old save plays on (gen %d)" % d.gen)
	# Members with no record at all are given one.
	raw["party"] = {"members": [{"id": "hulda_stonebrow", "hp": 3}]}
	var thin := GameDynasty.from_dict(raw)
	ok(thin.party.history.has("hulda_stonebrow") and thin.party.history["hulda_stonebrow"]["status"] == "serving", "a bare member gets a record")
	ok(absf(thin.party.age(thin, "hulda_stonebrow") - thin.party.hire_age(thin, "hulda_stonebrow")) < 0.001, "and an age")


func test_bot() -> void:
	var d := _new(81)
	var p := d.party
	d.heir.gold = 5000
	d.heir.level = 5
	for i in 3:
		GameParty.bot_tick(d)
	ok(p.members.size() == 3, "the bot fills the party with three")
	var first: String = p.members[0]["id"]
	var rec: Dictionary = p.history[first]
	rec["born"] = d.world.year - p.lifespan(d, first) * 0.98
	ok(p.decline(d, first) >= float(GameParty.setting("bot_dismiss_decline")), "%s is frail (%.2f)" % [first, p.decline(d, first)])
	GameParty.bot_tick(d)
	ok(p.has_member(first), "with no one fresh at the table, the frail one stays")
	d.world.visit("brinehaven")
	GameParty.bot_tick(d)
	ok(not p.has_member(first) and p.history[first]["status"] == "dismissed", "the bot sends a frail companion home")
	ok(p.members.size() == 3, "and hires someone else (%s)" % str(p.members.map(func(m): return m["id"])))
	# Back home with a place free, it takes back a fit companion for free, never the frail one.
	d.world.visit("hearthmere")
	var fit := ""
	for m in p.members:
		if "hearthmere" in GameParty.def(m["id"])["where"]:
			fit = m["id"]
	p.dismiss(d, fit)
	GameParty.bot_tick(d)
	ok(p.has_member(fit) and not p.has_member(first), "rehires %s, not the frail %s" % [fit, first])
	# When a companion dies the bot hires a replacement.
	var other: String = p.members[0]["id"]
	_force_end(d, other, "died")
	ok(p.members.size() == 2, "one dies")
	d.world.visit("brinehaven")
	GameParty.bot_tick(d)
	ok(p.members.size() == 3, "the bot hires a replacement (%s)" % str(p.members.map(func(m): return m["id"])))
	# Away from a tavern a frail companion fights on; back in town the gaps are filled first.
	var w := _new(82)
	w.heir.gold = 5000
	w.heir.level = 5
	GameParty.bot_tick(w)
	var old_one: String = w.party.members[0]["id"]
	w.party.history[old_one]["born"] = w.world.year - w.party.lifespan(w, old_one) * 0.98
	w.world.visit("greenvale")
	GameParty.bot_tick(w)
	ok(w.party.has_member(old_one) and w.party.members.size() == 1, "no hiring or swapping in the wilds: a frail companion beats none")
	w.world.visit("hearthmere")
	GameParty.bot_tick(w)
	GameParty.bot_tick(w)
	ok(w.party.members.size() == 3 and w.party.has_member(old_one), "back in town the empty places are filled, the frail one kept while no one else sits there (%s)" % str(w.party.members.map(func(m): return m["id"])))
	GameParty.bot_tick(w)
	ok(w.party.members.size() == 3 and w.party.has_member(old_one), "and the party stays as it is")
	# Over long autopilot runs companions die and retire, and the house keeps hiring.
	var ends := 0
	var hires := 0
	for s in 3:
		var e := _new(900 + s)
		e.heir.gold = 400
		for i in 2500:
			if e.state == "succession":
				e.choose_heir(0)
			elif e.state == "life":
				GameBot.step(e)
		for id in e.party.history:
			ends += (e.party.history[id]["past"] as Array).filter(func(x): return x["end"] != "fell").size()
			hires += 1
		ok(e.journal.size() > 0, "seed %d plays %d generations" % [s, e.gen])
	ok(ends > 0 and hires > 2, "autopilot houses see companions die or retire and hire others (%d ends, %d roles)" % [ends, hires])


func test_determinism() -> void:
	var a := _run(4321)
	var b := _run(4321)
	ok(a == b, "same seed, same companions' lives")
	ok(a.contains("\"past\":[{"), "the run saw a companion's life end")


func _run(s: int) -> String:
	var d := _new(s)
	d.heir.gold = 400
	for i in 1500:
		if d.state == "succession":
			d.choose_heir(0)
		elif d.state == "life":
			GameBot.step(d)
	return JSON.stringify(d.to_dict())
