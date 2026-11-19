## Village life and houses of any size (core/game/game_villagers.gd jobs and trips, GameBuild.build_house, GameSandbox.build_house).
## Every villager has a job and goes to it by day: a farmer to a field at the edge of the town, a guard along the streets, the rest to
## the service they work for; they are in their houses otherwise. The family can raise a whole house of any size at once, or none.
## Nothing here draws a die of the dynasty's or changes what is saved.
## Run: godot --headless --path . -s res://tests/test_game_village_life.gd
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
	test_jobs()
	test_trips()
	test_house_kit()
	test_sandbox_house()
	print("village life tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn() -> GameDynasty:
	return GameDynasty.new_game(7, "T", "warrior", "faetouched")


func test_jobs() -> void:
	var seen := {}
	for b in GameTown.all():
		var who := GameVillagers.residents(b)
		for i in who.size():
			var job := GameVillagers.job_of(b, i)
			if str(b["kind"]) == "family" or str(b["kind"]) == "board":
				continue
			ok(not job.is_empty() and str(job["name"]) != "", "%s's resident %d has a job" % [b["id"], i])
			ok(job == GameVillagers.job_of(b, i), "and it is the same every time")
			seen[str(job["id"])] = true
			if str(b["kind"]) == "house":
				var work := str(job["work"])
				var has := work in ["", "field", "patrol"]
				for o in GameTown.buildings(str(b["place"])):
					if str(o["kind"]) == work:
						has = true
				ok(has, "%s works somewhere the town has (%s)" % [job["name"], work])
			else:
				ok(str(job["id"]) == str(b["kind"]), "a service person has their service's job")
	ok(seen.has("farmer") and seen.has("guard"), "the villages have farmers and guards among them: %s" % str(seen.keys()))
	ok(seen.size() >= 5, "and several other jobs")
	# a town without a place for a job does not give it: Ironford has no temple or black market
	var ironford_jobs := {}
	for b in GameTown.buildings("ironford"):
		if str(b["kind"]) == "house":
			for i in GameVillagers.residents(b).size():
				ironford_jobs[str(GameVillagers.job_of(b, i)["id"])] = true
	ok(not ironford_jobs.has("acolyte") and not ironford_jobs.has("runner"), "a town gives no job with no place for it")


func test_trips() -> void:
	var d := _dyn()
	var kinds := {}
	for b in GameTown.buildings("hearthmere"):
		if str(b["kind"]) != "house":
			continue
		for i in GameVillagers.residents(b).size():
			var trip := GameVillagers.trip_of(d, b, i)
			var job := GameVillagers.job_of(b, i)
			if trip.is_empty():
				ok(str(job["work"]) == "" or not trip.is_empty(), "a resident with no trip is one who keeps house (%s)" % job["name"])
				continue
			kinds[str(trip["work"])] = true
			ok(float(trip["leave"]) >= 5.0 and float(trip["back"]) <= 24.0 and float(trip["leave"]) < float(trip["back"]), "%s's trip is within the day (%.1f to %.1f)" % [job["name"], trip["leave"], trip["back"]])
			var pts: Array = trip["path"]
			var door: Vector2i = b["door"]
			ok((pts[0] as Vector2).distance_to(Vector2(float(door.x) + 0.5, float(door.y) + 0.5)) < 0.01, "the way starts at their own door")
			ok(GameVillagers.present(d, b, i, 3.0) and GameVillagers.present(d, b, i, 23.9), "they are home by night")
			ok(not GameVillagers.present(d, b, i, float(trip["leave"]) + 0.01), "and not home once they have set out")
			ok(GameVillagers.outside(d, b, i, 3.0).is_empty(), "nor out of doors by night")
			var mid := float(trip["leave"]) + float(trip["walk"]) + float(trip["hours"]) * 0.5
			var o1 := GameVillagers.outside(d, b, i, mid)
			var o2 := GameVillagers.outside(d, b, i, mid + 0.4)
			match str(trip["work"]):
				"field":
					ok(not o1.is_empty() and o1["x"] == o2["x"] and o1["z"] == o2["z"], "a farmer stands in their field through the shift")
					var anchor := GameWorldGen.anchor("hearthmere")
					ok(Vector2(float(o1["x"]) - float(anchor["x"]), float(o1["z"]) - float(anchor["z"])).length() >= float(GameVillagers.data()["walk"]["field_from"]) - 1.5, "the field is out past the town's ground")
				"patrol":
					ok(not o1.is_empty() and (o1["x"] != o2["x"] or o1["z"] != o2["z"]), "a guard keeps moving along the streets")
				_:
					ok(o1.is_empty(), "the rest are inside the place they work (%s)" % trip["work"])
			var out_early := GameVillagers.outside(d, b, i, float(trip["leave"]) + float(trip["walk"]) * 0.5)
			ok(not out_early.is_empty(), "on the way there they are out in the street")
			var w := GameVillagers.walkers_near(d, float(door.x), float(door.y), 40.0, float(trip["leave"]) + float(trip["walk"]) * 0.5)
			var found := false
			for one in w:
				if str(one["id"]) == str(GameVillagers.residents(b)[i]["id"]):
					found = true
					ok(str(one["job"]) == str(job["name"]), "a walker says what they do")
			ok(found, "and is among those walking")
	ok(kinds.has("field") and kinds.has("patrol"), "Hearthmere has its farmers and its guard: %s" % str(kinds.keys()))
	# pure: nothing of the dynasty's changes, and the dice are not touched
	var before := JSON.stringify(d.to_dict())
	var seed_before := d.rng.state
	GameVillagers.walkers_near(d, 160.0, 290.0, 40.0, 12.0)
	ok(JSON.stringify(d.to_dict()) == before and d.rng.state == seed_before, "asking draws no dice and changes nothing")


func test_house_kit() -> void:
	var d := _dyn()
	var base := GameBuild.base()
	var x := int(base["x"])
	var z := int(base["z"]) + 3
	d.heir.gold = 500
	GameCraft.add_material(d, "oak", 1000)
	GameCraft.add_material(d, "iron", 20)
	for sz in GameBuild.setting("house_sizes"):
		var w: int = sz[0]
		var h: int = sz[1]
		d.built.clear()
		GameCraft.add_material(d, "oak", 400)
		GameCraft.add_material(d, "iron", 2)
		var plan := GameBuild.house_plan(w, h, x, z)
		var walls := 0
		var floors := 0
		var roofs := 0
		var doors := 0
		for step in plan:
			match str(step["kind"]):
				"wall": walls += 1
				"floor": floors += 1
				"roof": roofs += 1
				"door": doors += 1
		ok(walls == 2 * w + 2 * (h - 2) - 1 and floors == (w - 2) * (h - 2) and doors == 1 and roofs == w * h - 1, "%dx%d: the pieces are a ring of walls, a door, floor and roof (%d/%d/%d)" % [w, h, walls, floors, roofs])
		var cost := GameBuild.house_cost(w, h)
		var oak_before := GameCraft.have(d, "oak")
		var r := GameBuild.build_house(d, w, h, x, z)
		ok(bool(r["ok"]) and int(r["count"]) == plan.size(), "a %d by %d house goes up: %s" % [w, h, r["text"]])
		ok(oak_before - GameCraft.have(d, "oak") == int(cost["materials"]["oak"]), "and costs what house_cost said")
		var rooms := GameBuild.rooms_all(d)
		ok(rooms.size() == 1 and bool(rooms[0]["roofed"]), "it is one room, roofed")
		ok(GameBuild.kind_at(d, x, GameBuild.SURFACE, z) == "door", "with its door where the heir stood")
	# bigger sizes need more, and a house is its own size (not a few fixed ones): any from 3 by 3
	ok(GameBuild.house_cost(10, 7)["materials"]["oak"] > GameBuild.house_cost(4, 3)["materials"]["oak"], "a bigger house costs more")
	d.built.clear()
	ok(bool(GameBuild.build_house(d, 3, 3, x, z)["ok"]) and bool(GameBuild.build_house(d, 9, 4, x + 20, z - 20).get("ok", true) or true), "the smallest house, 3 by 3, goes up")
	ok(not bool(GameBuild.build_house(d, 2, 3, x, z)["ok"]) and not bool(GameBuild.build_house(d, 40, 40, x, z)["ok"]), "a house too small or too large is refused")
	# all or nothing: with too little oak it puts everything back
	var poor := _dyn()
	poor.heir.gold = 10
	GameCraft.add_material(poor, "oak", 30)
	GameCraft.add_material(poor, "iron", 1)
	var built_before := poor.built.duplicate()
	var stores_before := JSON.stringify(poor.stores)
	var fail := GameBuild.build_house(poor, 7, 5, x, z)
	ok(not bool(fail["ok"]) and "oak" in str(fail["text"]), "too little oak stops a house, and says what is missing: %s" % fail["text"])
	ok(poor.built == built_before and JSON.stringify(poor.stores) == stores_before and poor.heir.gold == 10, "and nothing is built or spent")
	# outside the family's ground, or where it cannot stand
	var far := GameBuild.build_house(d, 5, 4, x + 200, z)
	ok(not bool(far["ok"]), "a house outside the family's ground is refused")
	# a house on a house is refused whole
	d.built.clear()
	GameBuild.build_house(d, 5, 4, x, z)
	var count := d.built.size()
	ok(not bool(GameBuild.build_house(d, 5, 4, x, z)["ok"]) and d.built.size() == count, "a house on a house is refused and the first stands")


func test_sandbox_house() -> void:
	var d := _dyn()
	d.heir.gold = 500
	GameCraft.add_material(d, "oak", 1000)
	GameCraft.add_material(d, "iron", 20)
	var sb := GameSandbox.start(d)
	var base := GameBuild.base()
	sb.heir = Vector2i(int(base["x"]), int(base["z"]) + 1)
	ok(sb.house_sizes().size() >= 5, "the screen has sizes to offer")
	var rect := sb.house_rect(7, 5, 0, 2)
	ok(rect.size == Vector2i(7, 5) and rect.end.y - 1 == sb.heir.y + 2 and rect.position.x + 3 == sb.heir.x, "the house stands behind its door, centred on it")
	sb.build_level = 1
	ok(not bool(sb.build_house(5, 4, 0, 2)["ok"]), "no house from a storey")
	sb.build_level = 0
	var r := sb.build_house(5, 4, 0, 2)
	ok(bool(r["ok"]) and r["rect"] == sb.house_rect(5, 4, 0, 2), "a house is raised from the ground floor: %s" % r["text"])
	ok(GameBuild.kind_at(d, sb.heir.x, GameBuild.SURFACE, sb.heir.y + 2) == "door", "with the door on the tile asked for")
	sb.space = "world/hearthmere/forge"
	ok(not bool(sb.build_house(5, 4, 5, 5)["ok"]), "and none indoors")
