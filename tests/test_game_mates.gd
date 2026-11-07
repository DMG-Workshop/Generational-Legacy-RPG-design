## Mates: the candidates are opposite-sex, looking at them changes no dice, the one chosen becomes the spouse,
## and without a choice (the autopilot's way) the old random spouse still comes, as before.
## Run: godot --headless --path . -s res://tests/test_game_mates.gd
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
	test_candidates()
	test_choice_becomes_spouse()
	test_old_path_unchanged()
	print("mate tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _adult(seed_value: int, sex: String = GameSex.MALE) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human", sex)
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	return d


func test_candidates() -> void:
	var d := _adult(4, GameSex.FEMALE)
	var mates := d.mate_candidates()
	ok(mates.size() == int(GameData.bal("mate_candidate_count")), "the heir is offered the configured number of mates")
	var all_opposite := true
	for m in mates:
		all_opposite = all_opposite and m.sex == GameSex.MALE
	ok(all_opposite, "every candidate is the opposite sex of a female heir")
	var before := JSON.stringify(d.to_dict())
	d.mate_candidates()
	ok(JSON.stringify(d.to_dict()) == before, "looking at the candidates changes nothing in the dynasty")
	var again := d.mate_candidates()
	ok(again[0].name == mates[0].name and again[2].traits == mates[2].traits, "the same candidates every time they are asked for")


func test_choice_becomes_spouse() -> void:
	var d := _adult(5)
	var pick := 1
	var want: GameHeir = d.mate_candidates()[pick]
	d.found_family(pick)
	ok(d.heir.spouse != null and d.heir.spouse.name == want.name and d.heir.spouse.surname == want.surname, "the chosen mate is the spouse")
	ok(d.heir.spouse.id > 0, "and gets a real id once chosen")
	ok(d.heir.spouse.sex == GameSex.opposite(d.heir.sex), "and is the opposite sex")
	ok(not d.heir.children.is_empty(), "children are born of the marriage")
	for c in d.heir.children:
		ok(c.parent_names == [d.heir.name, want.name], "each child names the chosen mate as a parent")


func test_old_path_unchanged() -> void:
	var a := _adult(7)
	var b := _adult(7)
	a.found_family()
	b.found_family(-1)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "no choice gives the random spouse, as before")
