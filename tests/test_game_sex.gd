## Sex in the dynasty: the founder's start choice, the spouse always the opposite sex, children rolled
## both ways, and saves from before sexes existed load with a sex for everyone and their spouses opposite.
## Run: godot --headless --path . -s res://tests/test_game_sex.gd
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
	test_founder_choice()
	test_families_follow_the_rules()
	test_old_saves()
	print("sex tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_founder_choice() -> void:
	var f := GameDynasty.new_game(3, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human", GameSex.FEMALE)
	ok(f.heir.sex == GameSex.FEMALE, "the founder is the sex picked at the start")
	var m := GameDynasty.new_game(3, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human")
	ok(m.heir.sex == GameSex.MALE, "with no pick the founder is male")
	var bad := GameDynasty.new_game(3, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human", "robot")
	ok(GameSex.valid(bad.heir.sex), "an unknown sex is replaced by a valid one")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	ok(back.heir.sex == GameSex.FEMALE, "the sex survives a save")


## Plays dynasties through their generations and checks every spouse and child made along the way.
func test_families_follow_the_rules() -> void:
	var saw := {GameSex.MALE: 0, GameSex.FEMALE: 0}
	var spouses := 0
	var bad_spouse := 0
	var bad_child := 0
	for s in range(1, 13):
		var d := GameDynasty.new_game(s, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human", GameSex.FEMALE if s % 2 == 0 else GameSex.MALE)
		for g in 8:
			GameBot.live_life(d)
			if d.state == "succession":
				d.choose_heir(0)
			if d.state == "life":
				d.heir.age = maxf(d.heir.age, d.heir.family_min_age())   # old enough to found a family
				d.found_family()
			if d.heir.spouse != null:
				spouses += 1
				if d.heir.spouse.sex != GameSex.opposite(d.heir.sex):
					bad_spouse += 1
			for c in d.heir.children:
				if GameSex.valid(c.sex):
					saw[c.sex] += 1
				else:
					bad_child += 1
			for c in d.candidates:
				if not GameSex.valid(c.sex):
					bad_child += 1
	ok(spouses > 0, "the autopilot founded families to check (%d)" % spouses)
	ok(bad_spouse == 0, "every spouse is the opposite sex of their heir")
	ok(bad_child == 0, "every child and candidate has a sex")
	ok(saw[GameSex.MALE] > 0 and saw[GameSex.FEMALE] > 0, "children come out both ways (%d male, %d female)" % [saw[GameSex.MALE], saw[GameSex.FEMALE]])


## An old save has no "sex" anywhere: loading fills each person in, the same way every time.
func test_old_saves() -> void:
	var d := GameDynasty.new_game(9, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human", GameSex.FEMALE)
	for i in 3:
		GameBot.live_life(d)
		if d.state == "succession":
			d.choose_heir(0)
	if d.state == "life":
		d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
		d.found_family()
	var raw: Variant = JSON.parse_string(JSON.stringify(d.to_dict()))
	_strip(raw)
	var a := GameDynasty.from_dict(raw)
	var b := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	ok(GameSex.valid(a.heir.sex), "an old heir gets a sex on load")
	ok(a.heir.sex == b.heir.sex, "and the same one every time it loads")
	ok(a.heir.spouse == null or a.heir.spouse.sex == GameSex.opposite(a.heir.sex), "an old spouse is the opposite sex of the heir")
	for c in a.heir.children:
		ok(GameSex.valid(c.sex), "an old child gets a sex on load")


func _strip(v: Variant) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		v.erase("sex")
		for k in v:
			_strip(v[k])
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_strip(x)
