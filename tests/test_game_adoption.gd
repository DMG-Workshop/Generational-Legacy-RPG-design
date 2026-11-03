## Adoption: with no children, companions of the house are offered as heirs (up to adoption_max, the rest
## cousins); the one chosen leaves the company with status "adopted" and keeps their race and class; a
## house with no companion gets exactly the cousins it always had; the adoptee survives a save.
## Run: godot --headless --path . -s res://tests/test_game_adoption.gd
extends SceneTree

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	GameData.balance["adoption_max"] = 2   # adoption ships off (balance.json); these tests turn it on
	test_no_companions_gets_cousins()
	test_companions_are_offered()
	test_choosing_an_adoptee_leaves_the_company()
	test_adoptee_survives_a_save()
	test_old_saves_have_no_adoptee()
	print("adoption tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A house with `n` companions in the party, the heir without children, ready to die into succession.
func _house(seed_value: int, n: int) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human")
	var ids := ["bren_cask", "maddy_thorn", "sister_oriel"]
	for i in n:
		var id: String = ids[i]
		var def_c := GameParty.def(id)
		d.party.members.append({"id": id, "name": def_c["name"], "hp": 10, "mp": 0, "level": 3, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": [], "tree": {}})
		d.party.history[id] = {"name": def_c["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": []}
	d.heir.children.clear()
	return d


func _succeed(d: GameDynasty) -> void:
	d._die("old age")


func test_no_companions_gets_cousins() -> void:
	var d := _house(41, 0)
	_succeed(d)
	ok(d.state == "succession" and d.candidates.size() == 2, "with no companions, two candidates")
	var all_cousins := true
	for c in d.candidates:
		all_cousins = all_cousins and c.companion_id == "" and str(c.parent_names[0]).begins_with("(distant cousin")
	ok(all_cousins, "and they are the cousins the house always had")


func test_companions_are_offered() -> void:
	var one := _house(42, 1)
	_succeed(one)
	ok(one.candidates.size() == 2, "one companion: two candidates still")
	ok(one.candidates[0].companion_id == "bren_cask", "the companion is the first candidate")
	ok(str(one.candidates[1].parent_names[0]).begins_with("(distant cousin"), "and a cousin fills the other place")
	var two := _house(43, 3)
	_succeed(two)
	var adopted := 0
	for c in two.candidates:
		if c.companion_id != "":
			adopted += 1
	ok(adopted == int(GameData.bal("adoption_max")), "at most adoption_max companions are offered (%d)" % adopted)
	var c: GameHeir = one.candidates[0]
	ok(c.race_id == GameParty.def("bren_cask")["race"] and c.class_id == GameParty.def("bren_cask")["class"], "the adoptee keeps the companion's race and class")
	ok(c.surname == one.dynasty_name, "and takes the dynasty name")


func test_choosing_an_adoptee_leaves_the_company() -> void:
	var d := _house(44, 2)
	_succeed(d)
	var pick := -1
	for i in d.candidates.size():
		if d.candidates[i].companion_id != "":
			pick = i
			break
	var who: String = d.candidates[pick].companion_id
	d.choose_heir(pick)
	ok(d.heir.companion_id == "", "the new heir is no longer marked as adopted")
	ok(not d.party.has_member(who), "the adoptee leaves the company")
	ok(d.party.history[who]["status"] == "adopted", "with status adopted in the record")
	ok(d.party.members.size() == 1, "the other companion stays with the family")


func test_adoptee_survives_a_save() -> void:
	var d := _house(45, 1)
	_succeed(d)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.candidates.size() == d.candidates.size() and back.candidates[0].companion_id == "bren_cask", "the adoptee's companion id is saved with the candidates")


func test_old_saves_have_no_adoptee() -> void:
	var d := _house(46, 0)
	var raw: Variant = JSON.parse_string(JSON.stringify(d.to_dict()))
	raw["heir"].erase("companion_id")
	var back := GameDynasty.from_dict(raw)
	ok(back.heir.companion_id == "", "an old heir loads with no companion id")
