## The first-heir tutorial's logic (GameTutorial, data/ui/tutorial.json): the data is sound, every
## question the tips ask is answered, the tips come in the order the file teaches them from a game's own
## state, and nothing about the tutorial is saved with the dynasty.
## Run: godot --headless --path . -s res://tests/test_game_tutorial.gd
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
	test_data()
	test_questions()
	test_order()
	test_succession()
	test_nothing_saved()
	print("tutorial tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_val: int = 11) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_data() -> void:
	var steps: Array = GameData.tutorial["steps"]
	ok(steps.size() >= 5, "the tutorial has its steps (%d)" % steps.size())
	var seen := {}
	for s in steps:
		var id := str(s["id"])
		ok(not seen.has(id), "step ids are unique: %s" % id)
		seen[id] = true
		# It is a first-heir tutorial: a later generation, or a house played long, is taught nothing.
		ok((s.get("when", []) as Array).has("first_generation"), "%s only applies in the first generation" % id)
		ok(str(s.get("screen", "life")) in ["life", "succession"], "%s is for a known screen" % id)
		ok(str(s["text"]).length() > 20 and str(s["text"]).length() <= 125, "%s has a short tip, about two lines on a phone (%d characters)" % [id, str(s["text"]).length()])
		for key in ["when", "done"]:
			for p in s.get(key, []):
				ok(GameTutorial.PREDICATES.has(str(p)), "%s: '%s' in %s is a question the tutorial can answer" % [id, str(p), key])
		for word in s.get("highlight", []):
			ok(str(word) != "", "%s: highlight words are not empty" % id)
	ok(float(GameData.tutorial["wounded_below"]) > 0.0 and float(GameData.tutorial["wounded_below"]) < 1.0, "wounded_below is a fraction")
	# Every placeholder in the data is one fill() knows.
	var d := _dyn()
	for s in steps:
		var filled := GameTutorial.fill(str(s["text"]), d)
		ok(not ("{" in filled or "}" in filled), "%s leaves no placeholder unfilled: %s" % [s["id"], filled])
	ok(GameTutorial.fill("{name}", d) == "Tess", "{name} is the heir")
	ok(GameTutorial.fill("{min_age}", d) == str(int(ceil(d.heir.family_min_age()))), "{min_age} is the age a family may be founded")


## Each question is true in some state: a misspelled arm of the match would leave one always false.
func test_questions() -> void:
	var d := _dyn()
	ok(not GameTutorial.holds(d, "hunted"), "a new house has not hunted")
	d.total_hunts = 1
	ok(GameTutorial.holds(d, "hunted"), "a won hunt counts")
	d = _dyn()
	d.heir.battles_won = 2
	ok(GameTutorial.holds(d, "hunted"), "so do the heir's wins")
	d = _dyn()
	ok(not GameTutorial.holds(d, "trained"), "untrained at first")
	d.heir.training["vit"] = 1.5
	ok(GameTutorial.holds(d, "trained"), "any trained stat counts")
	d = _dyn()
	ok(not GameTutorial.holds(d, "wounded"), "full health is not wounded")
	d.heir.hp = int(float(d.heir.max_hp()) * float(GameData.tutorial["wounded_below"])) - 1
	ok(GameTutorial.holds(d, "wounded"), "under the line is wounded")
	d.heir.hp = int(ceil(float(d.heir.max_hp()) * float(GameData.tutorial["wounded_below"]))) + 1
	ok(not GameTutorial.holds(d, "wounded"), "over the line is not")
	d = _dyn()
	ok(GameTutorial.holds(d, "too_young_for_family") and not GameTutorial.holds(d, "can_found_family"), "a young founder cannot yet found a family")
	d.heir.age = d.heir.family_min_age()
	ok(GameTutorial.holds(d, "can_found_family") and not GameTutorial.holds(d, "too_young_for_family"), "at the age, they can")
	ok(not GameTutorial.holds(d, "family_founded") and not GameTutorial.holds(d, "can_retire") or d.heir.age >= d.heir.midlife_age(), "no family yet")
	d.found_family()
	ok(GameTutorial.holds(d, "family_founded") and GameTutorial.holds(d, "can_retire"), "founded, and then retirement is open")
	ok(not GameTutorial.holds(d, "can_found_family") and not GameTutorial.holds(d, "too_young_for_family"), "a founded family is neither")
	ok(GameTutorial.holds(d, "first_generation"), "generation 1 is the first")
	d.gen = 2
	ok(not GameTutorial.holds(d, "first_generation"), "generation 2 is not")
	ok(not GameTutorial.holds(d, "no_such_question"), "an unknown question is false")


## From a fresh house to the first succession, the tips come in the order the file teaches them.
func test_order() -> void:
	var d := _dyn()
	var tip := GameTutorial.current(d)
	ok(tip.get("id") == "hunt", "first, hunt: %s" % str(tip.get("id")))
	ok("Tess" in str(tip.get("text")) and tip.get("highlight") == ["Hunt"], "it names the heir and marks Hunt")
	d.total_hunts = 1
	ok(GameTutorial.current(d).get("id") == "train", "after a hunt, train")
	d.heir.hp = 1
	var hurt := GameTutorial.current(d)
	ok(hurt.get("id") == "rest" and "Rest" in hurt["highlight"] and "Potion" in hurt["highlight"], "a hurt heir is told to rest first")
	d.heir.full_heal()
	d.heir.training["str"] = 1.5
	var wait := GameTutorial.current(d)
	ok(wait.get("id") == "family_wait" and str(int(ceil(d.heir.family_min_age()))) in str(wait["text"]), "too young: told the age (%s)" % str(wait.get("text")))
	ok(wait["highlight"].is_empty(), "nothing to mark while waiting")
	d.heir.age = d.heir.family_min_age()
	ok(GameTutorial.current(d).get("id") == "family" and GameTutorial.current(d)["highlight"] == ["Found family"], "old enough: found a family")
	d.found_family()
	var retire := GameTutorial.current(d)
	ok(retire.get("id") == "retire" and retire["highlight"] == ["Retire"], "a founded house may retire: %s" % str(retire.get("id")))
	d.gen = 2
	ok(GameTutorial.current(d).is_empty(), "past the first generation there is nothing left to teach")
	ok(GameTutorial.current(_dyn(), "no_such_screen").is_empty(), "a screen without tips has none")


func test_succession() -> void:
	var d := _dyn()
	ok(GameTutorial.current(d, "succession").get("id") == "succession" and GameTutorial.current(d).get("id") == "hunt", "the succession tip belongs to its own screen")
	d._die("old age")
	var tip := GameTutorial.current(d, "succession")
	ok(tip.get("id") == "succession" and "Pick the child" in str(tip["text"]), "it tells them to pick the child: %s" % str(tip.get("text")))
	ok(not (str(d.last_death["name"]) in str(tip["text"])), "and does not repeat the screen's title about who has died")
	ok(d.state == "succession" and not d.candidates.is_empty(), "a cousin or child stands ready")
	d.choose_heir(0)
	ok(GameTutorial.current(d, "succession").is_empty() and GameTutorial.current(d).is_empty(), "the first succession done, the tutorial is over")


## The tutorial is worked out from the game, so a save carries nothing of it and an old one loads as before.
func test_nothing_saved() -> void:
	var d := _dyn()
	GameTutorial.current(d)
	ok(not JSON.stringify(d.to_dict()).to_lower().contains("tutorial"), "no tutorial state in the save")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var back := GameDynasty.from_dict(raw)
	ok(GameTutorial.current(back).get("id") == "hunt", "a loaded game gives the same first tip")
	var old := GameDynasty.new_game(12, "Old", "warrior", "faetouched", "human")
	old.gen = 7
	old.total_hunts = 400
	ok(GameTutorial.current(old).is_empty(), "a long-played house is taught nothing")
