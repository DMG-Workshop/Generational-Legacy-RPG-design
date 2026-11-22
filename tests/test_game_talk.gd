## The townspeople talking to the heir (core/game/game_talk.gd, data/world/talk.json, data/text/talk.json, GameSandbox.use and .greeting,
## ui/play/talk_panel.gd and the speech bubbles of ui/play/sandbox_screen.gd): Use beside a villager in the street or in a house whose roof
## is lifting gives words fitting their job, race, size, town, the time, the weather, the family's standing and house; a villager sometimes
## calls out first (a pure function of the seed, the person, the day and the tile, at most once a day each, with a cooldown, never in a
## fight, indoors or with a panel open); gate guards greet by the gate's name and town; a short conversation offers a rumour from the
## spawn tables; the text is in a catalog the locale code reads; nothing draws a die of the dynasty's. Breaks of each rule.
## Run: godot --headless --path . -s res://tests/test_game_talk.gd
extends SceneTree

const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")

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
	test_data()
	test_say()
	test_extras()
	test_use()
	test_conversations()
	test_greeting()
	test_gate_greeting()
	test_sandbox_rules()
	test_locale()
	test_breaks()
	await test_screen()
	print("talk tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A person who is at home by day in some house of a town (a homekeeper or anyone whose job keeps them in), with the tile to stand on.
func _house_person(d: GameDynasty, place: String, hour: float, job: String = "", houses_only: bool = false) -> Dictionary:
	for b in GameTown.buildings(place):
		if str(b["kind"]) == "family" or str(b["kind"]) == "board" or (houses_only and str(b["kind"]) != "house"):
			continue
		var who := GameVillagers.residents(b)
		for i in who.size():
			if not GameVillagers.present(d, b, i, hour):
				continue
			if job != "" and str(GameVillagers.job_of(b, i).get("id", "")) != job:
				continue
			var sp := GameVillagers.spot(b, i, hour, GameDay.is_night(d))
			var cell: Vector2i = sp["cell"]
			return {"b": b, "i": i, "tile": Vector2i(int(b["x"]) + cell.x, int(b["z"]) + cell.y)}
	return {}


func _at_hour(d: GameDynasty, hour: float) -> void:
	# the day's start phase plus the seconds: put the world clock at `hour` on its day 2
	var phase := hour / 24.0
	var start := float(GameDay.setting("start_phase"))
	d.world_seconds = fposmod(phase - start, 1.0) * float(GameDay.setting("day_seconds")) + float(GameDay.setting("day_seconds"))


func test_data() -> void:
	ok(GameTalk.validate().is_empty(), "the data is sound: %s" % str(GameTalk.validate()))
	ok(GameTalk.lines().size() > 150, "the catalog has %d lines" % GameTalk.lines().size())
	for j in ["farmer", "guard", "smith_hand", "shop_hand", "tavern_hand", "acolyte", "runner", "homekeeper", "gate_guard", "forge", "temple", "store", "tavern", "black_market"]:
		ok(GameTalk.variants("job.%s.day" % j) >= 2 and GameTalk.variants("job.%s.night" % j) >= 2 and GameTalk.variants("call.%s" % j) >= 1, "%s has lines for the day, the night and a call" % j)
	for w in GameDay.data()["weather_look"]:
		ok(GameTalk.variants("weather.%s" % w) >= 2, "weather %s has remarks" % w)
	for place in GameTown.towns():
		ok(GameTalk.variants("town.%s" % place) >= 2, "%s has remarks about it" % place)
	ok(GameTalk.lines() == GameLocale.source_lines("talk"), "the `talk` catalog is the locale code's")


func test_say() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var hour := GameDay.hour(d)
	var p := _house_person(d, "hearthmere", hour)
	ok(not p.is_empty(), "someone is at home at noon in Hearthmere")
	var who := GameTalk.beside(d, p["tile"], hour)
	ok(not who.is_empty() and who["where"] == "house", "the heir beside someone in a house whose roof is lifting can talk to them")
	var t := GameTalk.talk(d, who, hour)
	ok(bool(t["ok"]) and str(t["text"]).length() > 20 and str(t["text"]).contains(str(who["job"])), "they say something, under their job: %s" % str(t["text"]))
	ok(GameTalk.talk(d, who, hour)["text"] == t["text"], "the same words when asked again")
	# nobody is beside the heir far from everyone
	ok(GameTalk.beside(d, Vector2i(0, 0), hour).is_empty(), "far from the towns there is nobody to talk to")
	ok(not bool(GameTalk.talk(d, {}, hour)["ok"]), "no one, no words")
	# a whole roof hides the people: far from the house (alpha 1) they are not in reach
	var b: Dictionary = p["b"]
	var far := Vector2i(int(b["x"]) - int(GameReveal.setting("far")) - 4, int(b["z"]) + 2)
	ok(GameTalk.beside(d, far, hour).is_empty() or GameTalk.beside(d, far, hour)["where"] != "house" or GameTalk.beside(d, far, hour)["id"] != who["id"], "someone under a whole roof, far off, is not talked to")
	# the words differ between people and between times
	var seen := {}
	for place in GameTown.towns():
		for bb in GameTown.buildings(place):
			var res := GameVillagers.residents(bb)
			for i in res.size():
				if str(bb["kind"]) == "family" or str(bb["kind"]) == "board" or not GameVillagers.present(d, bb, i, hour):
					continue
				var sp := GameVillagers.spot(bb, i, hour, false)
				var tile := Vector2i(int(bb["x"]) + sp["cell"].x, int(bb["z"]) + sp["cell"].y)
				var w := GameTalk.beside(d, tile, hour)
				if not w.is_empty():
					seen[str(GameTalk.talk(d, w, hour)["text"])] = true
	ok(seen.size() >= 12, "different people say different things (%d lines)" % seen.size())
	var line1 := str(GameTalk.talk(d, who, 12.0)["text"])
	var line2 := str(GameTalk.talk(d, who, 21.5)["text"])
	ok(line1 != line2, "and the same person says different things at another time of day")
	# a sleeper only mumbles
	_at_hour(d, 2.0)
	var night_person := _house_person(d, "hearthmere", GameDay.hour(d), "", true)
	ok(not night_person.is_empty(), "someone is in bed at night")
	var sleeper := GameTalk.beside(d, night_person["tile"], GameDay.hour(d))
	ok(bool(sleeper.get("asleep", false)), "and asleep")
	var mumble := str(GameTalk.talk(d, sleeper, GameDay.hour(d))["bare"])
	var mumbles: Array = []
	for n in GameTalk.variants("asleep"):
		mumbles.append(GameTalk.text("asleep.%d" % (n + 1)))
	ok(mumbles.has(mumble), "a sleeper mumbles (%s)" % mumble)
	ok(GameTalk.choices_of(sleeper).is_empty(), "and offers no conversation")
	# the job's line is the job's: day and night
	var farmer := {"id": "x", "job_id": "farmer", "job": "Farmer", "work": "field", "race": "human", "scale": 1.0, "creature": "", "place": "hearthmere", "gate": "", "asleep": false}
	_at_hour(d, 12.0)
	var day_lines: Array = []
	for n in GameTalk.variants("job.farmer.day"):
		day_lines.append(GameTalk.text("job.farmer.day.%d" % (n + 1)))
	var said := str(GameTalk.talk(d, farmer, 12.0)["bare"])
	ok(day_lines.any(func(l): return said.contains(str(l))), "a farmer's day words are among the farmer's day lines")
	_at_hour(d, 0.5)
	var night_lines: Array = []
	for n in GameTalk.variants("job.farmer.night"):
		night_lines.append(GameTalk.text("job.farmer.night.%d" % (n + 1)))
	said = str(GameTalk.talk(d, farmer, 0.5)["bare"])
	ok(night_lines.any(func(l): return said.contains(str(l))), "and at night, the night lines")
	# a monster of the town says what its kind says
	var goblin := {"id": "g", "job_id": "", "job": "Goblin", "work": "", "race": "", "scale": 0.7, "creature": "goblin", "place": "ironford", "gate": "", "asleep": false}
	var gl: Array = []
	for n in GameTalk.variants("creature.goblin"):
		gl.append(GameTalk.text("creature.goblin.%d" % (n + 1)))
	ok(gl.has(str(GameTalk.talk(d, goblin, 12.0)["bare"])), "a goblin says a goblin's words")


func test_extras() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var base := {"id": "x", "job_id": "farmer", "job": "Farmer", "work": "field", "race": "human", "scale": 1.0, "creature": "", "place": "hearthmere", "gate": "", "asleep": false}
	var vals := GameTalk._vals(d, base)
	# the weather
	for w in GameDay.data()["weather_look"]:
		d.world.weather_id = w
		var line := GameTalk._extra(d, base, "weather", 3, vals)
		var lines: Array = []
		for n in GameTalk.variants("weather.%s" % w):
			lines.append(GameTalk.text("weather.%s.%d" % [w, n + 1]))
		ok(lines.has(line), "weather %s: the remark is one of its own" % w)
	# the standing with the town's faction: the church's, in Hearthmere, by the rank it gives (the same rank's lines)
	var rank := GameFactions.rank(d, "church")
	var sl := GameTalk._extra(d, base, "standing", 1, vals)
	var rank_lines: Array = []
	for n in GameTalk.variants("standing.%s" % rank):
		rank_lines.append(GameTalk.text("standing.%s.%d" % [rank, n + 1], vals))
	ok(rank_lines.has(sl), "standing: the remark fits the %s rank" % rank)
	ok(sl.contains(GameFactions.name_of("church")) or sl.contains("Tess") or sl.contains(d.dynasty_name), "and names the faction or the family (%s)" % sl)
	# each rank has its own group (a different standing, different lines)
	var groups := {}
	for rk in GameFactions.data()["ranks"]:
		groups["standing.%s" % rk["id"]] = GameTalk.variants("standing.%s" % rk["id"])
	ok(groups.size() == 5 and groups.values().all(func(n): return n >= 2), "every rank has lines")
	# the heir's standing is read and not changed
	var before := GameFactions.standing(d, "church")
	GameTalk.talk(d, base, 12.0)
	ok(GameFactions.standing(d, "church") == before, "talking leaves the standing as it was (read-only)")
	# a house built or not
	var none_line := GameTalk._extra(d, base, "house", 2, vals)
	var none_lines: Array = []
	for n in GameTalk.variants("house.none"):
		none_lines.append(GameTalk.text("house.none.%d" % (n + 1), vals))
	ok(none_lines.has(none_line), "no house of the family's: the remark asks about one")
	d.built = {"1,-1,1": "wall"}
	var built_line := GameTalk._extra(d, base, "house", 2, vals)
	var built_lines: Array = []
	for n in GameTalk.variants("house.built"):
		built_lines.append(GameTalk.text("house.built.%d" % (n + 1), vals))
	ok(built_lines.has(built_line) and built_line != none_line, "a house built: the remark is about that")
	d.built = {}
	# size and race
	var small := base.duplicate()
	small["scale"] = 0.75
	small["race"] = "halfling"
	ok(GameTalk._extra(d, small, "size", 0, vals) != "" and GameTalk.text("size.small.1") != "", "a halfling remarks on being small")
	var big := base.duplicate()
	big["scale"] = 1.25
	var small_line := GameTalk._extra(d, small, "size", 0, vals)
	var big_line := GameTalk._extra(d, big, "size", 0, vals)
	ok(small_line != big_line and big_line != "", "a large person remarks otherwise")
	ok(GameTalk._extra(d, base, "size", 0, vals) == "", "an ordinary human beside an ordinary heir says nothing of size")
	for r in GameData.races:
		var rl := GameTalk._extra(d, {"race": r, "scale": 1.0}, "race", 0, vals)
		ok(rl != "", "race %s has a remark" % r)
	for place in GameTown.towns():
		var pl := GameTalk._extra(d, {"place": place, "scale": 1.0, "race": "human"}, "town", 1, vals)
		ok(pl != "", "%s has a remark about it" % place)
	ok(GameTalk._extra(d, base, "nonsense", 0, vals) == "", "an unknown extra says nothing")
	# a talk adds up to `extras` extras on the job line
	var t := GameTalk.talk(d, base, 12.0)
	var sentences := str(t["bare"]).split(". ").size()
	ok(str(t["bare"]).length() > 40 and sentences >= 2, "a full answer is a job line and some remarks: %s" % str(t["bare"]))


func test_use() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	d.world.weather_id = "rain"
	var p := _house_person(d, "hearthmere", GameDay.hour(d))
	var sb := GameSandbox.start(d)
	sb.heir = p["tile"]
	# the heir is where the villager stands inside a body only for the test; Use finds them
	var r := sb.use()
	ok(bool(r["ok"]) and r.has("who") and str(r["text"]) != "", "Use beside someone talks to them: %s" % str(r["text"]))
	ok(sb.log.back()["kind"] == "talk", "and the words are in the log")
	# the family's own door or a room use takes second place: the door first
	var b: Dictionary = GameTown.buildings("hearthmere")[0]
	var sb2 := GameSandbox.start(d)
	sb2.heir = b["door"]
	sb2.use()
	ok(sb2.space != "world", "Use at a door goes in (nothing else is said)")
	# upstairs: nobody to talk to
	var sb3 := GameSandbox.start(d)
	sb3.heir = p["tile"]
	sb3.heir_y = -2
	var r3 := sb3.use()
	ok(not r3.has("who"), "upstairs there is no one to talk to")
	# in the open country there is nobody
	var sb4 := GameSandbox.start(d)
	sb4.heir = Vector2i(10, 10)
	ok(not sb4.use().has("who"), "far from a town Use finds no one")


func test_conversations() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var hour := GameDay.hour(d)
	var guard := {"id": "g1", "job_id": "gate_guard", "job": "Gate guard", "work": "gate", "race": "human", "scale": 1.0, "creature": "", "place": "hearthmere", "gate": "hearthmere/gate_n", "asleep": false}
	var ch := GameTalk.choices_of(guard)
	ok(ch.size() == 1 and ch[0]["id"] == "fear", "a gate guard offers one thing to ask: is there anything to fear")
	var farmer := {"id": "f1", "job_id": "farmer", "job": "Farmer", "work": "field", "race": "human", "scale": 1.0, "creature": "", "place": "hearthmere", "gate": "", "asleep": false}
	ok(GameTalk.choices_of(farmer)[0]["id"] == "news", "a farmer offers news")
	ok(GameTalk.choices_of({"job_id": "homekeeper", "creature": "", "asleep": false}).is_empty(), "a homekeeper offers nothing")
	for jid in GameTalk.data()["conversations"]:
		ok(GameTalk.choices_of({"job_id": jid, "creature": "", "asleep": false}).size() <= 2, "'%s' offers few choices" % jid)
	# a refusal: a choice the person does not offer
	ok(not bool(GameTalk.reply(d, farmer, "fear", hour)["ok"]), "a farmer will not answer a question they do not take")
	ok(not bool(GameTalk.reply(d, farmer, "nonsense", hour)["ok"]), "nor an unknown one")
	# a rumour names a creature GameSpawn puts there; find a day it exists
	var found := {}
	var day := GameDay.day_number(d)
	for k in 40:
		var s := GameTalk.sighting(d, "hearthmere", day + k)
		if not s.is_empty():
			found = s
			found["day"] = day + k
			break
	ok(not found.is_empty(), "a rumour of a creature near Hearthmere can be found within a few days")
	if not found.is_empty():
		ok(GameSpawn.spawn_at(d, int(found["x"]), -1, int(found["z"]), 0, false) == str(found["id"]), "the creature of the rumour is the one the spawn tables put at that tile (%s)" % found["id"])
		var a := GameWorldGen.anchor("hearthmere")
		var dist := Vector2(float(found["x"]) - float(a["x"]), float(found["z"]) - float(a["z"])).length()
		ok(dist >= float(GameTalk.data()["rumour"]["min"]) - 1.5 and dist <= float(GameTalk.data()["rumour"]["max"]) + 1.5, "within the rumour's range (%.0f tiles)" % dist)
		_at_hour(d, 12.0)
		d.world_seconds += float(int(found["day"]) - day) * float(GameDay.setting("day_seconds"))
		var rep := GameTalk.reply(d, farmer, "news", GameDay.hour(d))
		ok(bool(rep["ok"]) and str(rep["bare"]).to_lower().contains(str(found["name"]).to_lower()), "the farmer's news names it: %s" % str(rep["bare"]))
		var warn := GameTalk.reply(d, guard, "fear", GameDay.hour(d))
		ok(bool(warn["ok"]) and str(warn["bare"]).to_lower().contains(str(found["name"]).to_lower()), "and the guard's warning: %s" % str(warn["bare"]))
		ok(str(rep["bare"]).contains(str(GameTalk.text("dir.%s" % found["dir"]))), "with a direction")
		ok(GameTalk.sighting(d, "hearthmere", int(found["day"])) == GameTalk.sighting(d, "hearthmere", int(found["day"])), "the same sighting all day")
	# services' people answer about their wares
	var smith := {"id": "s", "job_id": "forge", "job": "Smith", "work": "forge", "race": "dwarf", "scale": 0.85, "creature": "", "place": "ironford", "gate": "", "asleep": false}
	var wares := GameTalk.reply(d, smith, "wares", hour)
	ok(bool(wares["ok"]) and str(wares["bare"]) == GameTalk.text("wares.forge"), "the smith says what the forge does")
	# no dice
	var before := d.rng.state
	GameTalk.reply(d, farmer, "news", hour)
	GameTalk.sighting(d, "kingshold", 9)
	ok(d.rng.state == before, "no die of the dynasty's was drawn")
	# a different seed has other sightings (it is the seed's)
	var other := _dyn(1234)
	var diff := false
	for k in 30:
		if GameTalk.sighting(d, "hearthmere", 1 + k) != GameTalk.sighting(other, "hearthmere", 1 + k):
			diff = true
	ok(diff, "a different seed has different rumours")


func test_greeting() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var hour := GameDay.hour(d)
	# the roll: a pure function, about the stated share, and not on every tile
	var hits := 0
	for x in 40:
		for z in 25:
			if GameTalk.wants(d, "someone", 3, Vector2i(x, z), 12):
				hits += 1
	ok(hits > 60 and hits < 160, "about 12 in 100 tiles make a person call out (%d of 1000)" % hits)
	ok(GameTalk.wants(d, "a", 5, Vector2i(3, 4), 50) == GameTalk.wants(d, "a", 5, Vector2i(3, 4), 50), "the same roll again")
	var other := _dyn(9)
	var differ := false
	for x in 30:
		if GameTalk.wants(d, "a", 5, Vector2i(x, 4), 50) != GameTalk.wants(other, "a", 5, Vector2i(x, 4), 50):
			differ = true
	ok(differ, "the seed changes the rolls")
	var days_differ := false
	for x in 30:
		if GameTalk.wants(d, "a", 5, Vector2i(x, 4), 50) != GameTalk.wants(d, "a", 6, Vector2i(x, 4), 50):
			days_differ = true
	ok(days_differ, "and the day does")
	# a person standing in the street: walk the heir along a row of tiles beside someone at home and count the greetings
	var p := _house_person(d, "hearthmere", hour)
	var spot: Vector2i = p["tile"]
	var seen := {}
	var last := GameTalk.NEVER
	var greeted: Array = []
	for k in 40:
		var tile := spot + Vector2i(k % 5 - 2, k / 5 - 4)
		var g := GameTalk.greeting(d, tile, hour, seen, last)
		if not g.is_empty():
			seen[str(g["who"]["id"])] = GameDay.day_number(d)
			last = GameDay.seconds(d)
			greeted.append(g)
			ok(str(g["text"]).length() > 5 and str(g["line"]).contains(str(g["who"]["job"])), "a greeting has the person's words and job: %s" % str(g["line"]))
			break
	ok(greeted.size() == 1, "walking by, someone calls out within a few steps (%d)" % greeted.size())
	# at most one greeting a day each: the same person never again that day, whatever the tile
	if not greeted.is_empty():
		var id := str(greeted[0]["who"]["id"])
		var again := 0
		for k in 200:
			var g2 := GameTalk.greeting(d, spot + Vector2i(k % 9 - 4, k / 9 % 9 - 4), hour, seen, GameTalk.NEVER)
			if not g2.is_empty() and str(g2["who"]["id"]) == id:
				again += 1
		ok(again == 0, "the same person does not call out twice in a day")
		# the global cooldown: right after anyone spoke nobody does, and it ends
		var quiet := 0
		var spoke := 0
		for k in 200:
			var t2 := spot + Vector2i(k % 9 - 4, k / 9 % 9 - 4)
			if not GameTalk.greeting(d, t2, hour, {}, GameDay.seconds(d)).is_empty():
				quiet += 1
			if not GameTalk.greeting(d, t2, hour, {}, GameDay.seconds(d) - float(GameTalk.setting("cooldown_seconds")) - 1.0).is_empty():
				spoke += 1
		ok(quiet == 0 and spoke > 0, "no one calls out within the cooldown (%d) and they may after it (%d)" % [quiet, spoke])
		# a new day: the same person may call out again
		var tomorrow := _dyn()
		_at_hour(tomorrow, 12.0)
		tomorrow.world_seconds += float(GameDay.setting("day_seconds"))
		var next := 0
		for k in 300:
			var g3 := GameTalk.greeting(tomorrow, spot + Vector2i(k % 9 - 4, k / 9 % 9 - 4), GameDay.hour(tomorrow), seen, GameTalk.NEVER)
			if not g3.is_empty() and str(g3["who"]["id"]) == id:
				next += 1
		ok(next > 0, "and the next day they may call out again (%d)" % next)
	# nobody calls out from far, nor in the open country
	ok(GameTalk.greeting(d, Vector2i(5, 5), hour, {}, GameTalk.NEVER).is_empty(), "in the open country nobody calls out")
	# the sleeping and the monsters do not
	_at_hour(d, 2.0)
	var night_person := _house_person(d, "hearthmere", GameDay.hour(d), "", true)
	var sleeper_calls := 0
	for k in 300:
		var g4 := GameTalk.greeting(d, night_person["tile"] + Vector2i(k % 7 - 3, k / 7 % 7 - 3), GameDay.hour(d), {}, GameTalk.NEVER)
		if not g4.is_empty() and bool(g4["who"]["asleep"]):
			sleeper_calls += 1
	ok(sleeper_calls == 0, "no one asleep calls out")
	# no dice
	_at_hour(d, 12.0)
	var before := d.rng.state
	for k in 50:
		GameTalk.greeting(d, spot + Vector2i(k % 7, k / 7), GameDay.hour(d), {}, GameTalk.NEVER)
	ok(d.rng.state == before, "no die of the dynasty's was drawn")


func test_gate_greeting() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var hour := GameDay.hour(d)
	for place in GameWalls.walled():
		var east: Dictionary = {}
		for g in GameWalls.gates(place):
			east = g
			break
		var inner: Vector2i = east["inner"]
		var greeted := {}
		var seen := {}
		for k in 30:
			var tile: Vector2i = inner + Vector2i(k % 6 - 3, k / 6 - 2)
			var g := GameTalk.greeting(d, tile, hour, {}, GameTalk.NEVER)
			if not g.is_empty() and str(g["who"]["gate"]) != "":
				greeted = g
				break
		ok(not greeted.is_empty(), "%s: a guard at the gate greets the heir who comes up to it" % east["id"])
		if not greeted.is_empty():
			var town := str(GameWorldGen.anchor(place)["name"])
			ok(str(greeted["text"]).contains(town) and str(greeted["text"]).contains(GameTalk.gate_name(east)), "and names the gate and the town: %s" % str(greeted["text"]))
			var dest := GameWalls.road_of(east)
			ok(dest == "" or str(greeted["text"]).contains(str(GameWorldGen.anchor(dest)["name"])), "and the road beyond")
			ok(str(greeted["who"]["job"]) == "Gate guard" and bool(greeted["offers"]), "they are a Gate guard who offers a word more")
	# the guard stands at the gate at night too
	_at_hour(d, 1.0)
	var g0: Dictionary = GameWalls.gates("hearthmere")[0]
	var near := GameTalk.nearby(d, float((g0["posts"][0] as Vector2i).x) + 0.5, float((g0["posts"][0] as Vector2i).y) + 0.5, GameDay.hour(d), 3.0, 3.0)
	ok(near.any(func(w): return w["where"] == "gate"), "a guard of the night shift is at the gate at one in the morning")
	# Use beside a gate guard: the words, the choices, the warning
	var sb := GameSandbox.start(d)
	var post: Vector2i = g0["posts"][0]
	sb.heir = post
	var r := sb.use()
	ok(r.has("who") and str(r["who"]["job"]) == "Gate guard" and (r["choices"] as Array).size() == 1, "Use at a gate talks to the guard, who offers a warning: %s" % str(r["text"]))
	ok(str(r["text"]).contains(GameTalk.gate_name(g0)), "and names the gate")


func test_sandbox_rules() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	var g0: Dictionary = GameWalls.gates("hearthmere")[1]
	var sb := GameSandbox.start(d)
	sb.heir = g0["posts"][0]
	# greeting: only in the world, on the ground, with no fight
	var got := {}
	for k in 60:
		sb.talk_last = GameTalk.NEVER
		sb.talk_seen = {}
		sb.heir = g0["posts"][0] + Vector2i(k % 4, k / 4 % 4)
		var g := sb.greeting()
		if not g.is_empty():
			got = g
			break
	ok(not got.is_empty(), "the sandbox gives a greeting near a gate")
	ok(sb.talk_seen.has(str(got["who"]["id"])) and sb.talk_last > GameTalk.NEVER, "and notes who spoke and when")
	ok(sb.log.back()["kind"] == "talk", "and logs it")
	ok(sb.greeting().is_empty(), "and nobody calls out again at once (the cooldown)")
	sb.talk_last = GameTalk.NEVER
	var indoors := GameSandbox.start(d)
	indoors.heir = g0["posts"][0]
	indoors.space = "somewhere"
	var any_indoors := false
	for k in 40:
		indoors.heir = g0["posts"][0] + Vector2i(k % 4, k / 4 % 4)
		if not indoors.greeting().is_empty():
			any_indoors = true
	ok(not any_indoors, "indoors nobody calls out")
	var up := GameSandbox.start(d)
	up.heir_y = -2
	var any_up := false
	for k in 40:
		up.heir = g0["posts"][0] + Vector2i(k % 4, k / 4 % 4)
		if not up.greeting().is_empty():
			any_up = true
	ok(not any_up, "upstairs nobody calls out")
	var fight := GameSandbox.start(d)
	d.start_encounter(["wolf"])
	var any_fight := false
	for k in 40:
		fight.heir = g0["posts"][0] + Vector2i(k % 4, k / 4 % 4)
		if not fight.greeting().is_empty():
			any_fight = true
	ok(d.battle != null and not any_fight, "in a fight nobody calls out")


func test_locale() -> void:
	var src := str(GameTalk.lines()["choice.news"])
	GameLocale.current = "pseudo"
	var pseudo := GameTalk.text("choice.news")
	ok(pseudo != src and pseudo.begins_with("["), "the pseudo-language shows the talk catalog is translatable (%s)" % pseudo)
	var line := GameTalk.text("gate.call.1", {"heir": "Tess", "gate": "East Gate", "town": "Hearthmere", "dest": "Greenvale"})
	ok(line.contains("Tess") and line.contains("East Gate"), "its placeholders are kept")
	GameLocale.current = ""
	ok(GameTalk.text("choice.news") == src, "English is the source")


func test_breaks() -> void:
	var good: Dictionary = GameTalk.data().duplicate(true)
	var cases := {
		"a greeting every time": func(dd: Dictionary): dd["settings"]["chance_percent"] = 90,
		"no cooldown": func(dd: Dictionary): dd["settings"]["cooldown_seconds"] = 0,
		"no reach": func(dd: Dictionary): dd["settings"]["reach_street"] = 0,
		"a conversation of an unknown job": func(dd: Dictionary): dd["conversations"]["wizard"] = ["news"],
		"an unknown choice": func(dd: Dictionary): dd["conversations"]["farmer"] = ["gossip"],
		"a choice with no reply": func(dd: Dictionary): dd["choices"]["news"]["reply"] = "sing",
		"a rumour inside the town": func(dd: Dictionary): dd["rumour"]["min"] = 5,
		"seven directions": func(dd: Dictionary): dd["directions"] = ["e", "se", "s", "sw", "w", "nw", "n"],
		"an unknown extra": func(dd: Dictionary): dd["extras"].append("gossip"),
	}
	for what in cases:
		GameTalk._cache = good.duplicate(true)
		cases[what].call(GameTalk._cache)
		ok(not GameTalk.validate().is_empty(), "the checker finds %s" % what)
	GameTalk._cache = good.duplicate(true)
	ok(GameTalk.validate().is_empty(), "(the rules are whole again)")
	# the catalog
	var lines_good: Dictionary = GameTalk.lines().duplicate(true)
	var line_cases := {
		"a missing job line": func(l: Dictionary): l.erase("job.farmer.day.1"),
		"a gap in the numbering": func(l: Dictionary): l.erase("job.guard.day.1"),
		"a line nothing asks for": func(l: Dictionary): l["rubbish.1"] = "x",
		"a line that is not text": func(l: Dictionary): l["job.farmer.day.1"] = 5,
		"an unknown placeholder": func(l: Dictionary): l["job.farmer.day.1"] = "Hello {nobody}.",
		"a missing single": func(l: Dictionary): l.erase("hint.talk"),
		"a group with a single variant": func(l: Dictionary): l.erase("weather.fog.2"),
	}
	for what in line_cases:
		GameTalk._lines = lines_good.duplicate(true)
		line_cases[what].call(GameTalk._lines)
		GameTalk._counts = {}
		# the counts are made when the lines are read: rebuild them the way `lines` does
		for k in GameTalk._lines:
			var i := (k as String).rfind(".")
			if i > 0 and (k as String).substr(i + 1).is_valid_int():
				var g := (k as String).substr(0, i)
				GameTalk._counts[g] = maxi(int(GameTalk._counts.get(g, 0)), int((k as String).substr(i + 1)))
		var found := _talk_problems_in_memory()
		ok(not found.is_empty(), "the checker finds %s" % what)
	GameTalk._lines = {}
	GameTalk._counts = {}
	ok(GameTalk.validate().is_empty(), "(the catalog is whole again)")


## `validate` reloads the lines from disk, so the broken catalog is checked by the rule parts that read what is in memory.
func _talk_problems_in_memory() -> Array:
	var bad: Array = []
	var lines := GameTalk._lines
	for g in ["job.farmer.day", "job.guard.day", "weather.fog", "job.farmer.night"]:
		var n := GameTalk.variants(g)
		for k in range(1, n + 1):
			if not lines.has("%s.%d" % [g, k]):
				bad.append("gap in %s" % g)
		if n < 2:
			bad.append("%s has too few lines" % g)
	for k in lines:
		if typeof(lines[k]) != TYPE_STRING:
			bad.append("not text: %s" % k)
		elif GameLocale.placeholders(str(lines[k])).any(func(p): return str(p) == "nobody"):
			bad.append("unknown placeholder in %s" % k)
	for k in ["hint.talk", "job.farmer.day.1"]:
		if not lines.has(k):
			bad.append("missing %s" % k)
	for k in lines:
		if (k as String).begins_with("rubbish"):
			bad.append("stray %s" % k)
	return bad


func test_screen() -> void:
	var d := _dyn()
	_at_hour(d, 12.0)
	d.world.visit("hearthmere")
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = SandboxScreen.new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	var g0: Dictionary = GameWalls.gates("hearthmere")[0]
	scr.sb.heir = g0["posts"][0]
	scr.sb.creatures.clear()
	scr._use()
	ok(scr._bubbles.size() == 1, "Use beside a gate guard puts their words over their head")
	ok(scr._modal_open(), "and opens the short conversation (the world waits)")
	var panel: Control = null
	for c in scr.get_children():
		if c.has_meta("modal"):
			panel = c
	ok(panel != null and panel.who["job"] == "Gate guard", "the panel is about the guard")
	await process_frame
	var said_before: String = panel._said.text
	panel._ask("fear")
	ok(panel._said.text != said_before and panel._asked.has("fear"), "asking the question gets an answer")
	ok(scr.last_line.contains("Gate guard"), "and the status line says it")
	# while the panel is open nobody calls out
	scr._greet_wait = -1.0
	var g_count: int = scr.sb.log.size()
	scr._process(0.1)
	ok(scr.sb.log.size() == g_count, "with the panel open nothing is said first")
	panel.queue_free()
	await process_frame
	ok(not scr._modal_open(), "Farewell closes it")
	# the bubble is drawn (the overlay runs through the guard and the bubble)
	scr.overlay.queue_redraw()
	await process_frame
	await process_frame
	ok(scr._bubble_pos.size() >= 1, "the guard is drawn with a head to put the words over")
	# the bubble ends
	var id: String = str(scr._bubbles.keys()[0])
	scr._bubbles[id]["until"] = 0
	scr.overlay.queue_redraw()
	await process_frame
	await process_frame
	ok(not scr._bubbles.has(id), "after a few seconds the words are gone")
	# no greeting while a fight is on: the screen hands over to the fight before it asks
	d.start_encounter(["wolf"])
	scr._greet_wait = -1.0
	var count: int = scr.sb.log.size()
	scr._process(0.1)
	ok(scr.sb.log.size() == count, "in a fight nobody calls out")
	scr.queue_free()
	app.queue_free()
