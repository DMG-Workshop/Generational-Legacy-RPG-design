## How creatures are born and how the young of a pairing are born (data/creatures/breeding.json, the `born` and `young`
## of each creature, GameBirth). Every creature lays eggs, bears live young or is not born; a hybrid recipe says for
## itself how its young are born; a cross-breed of two creatures born differently follows the mixed-birth rule (the
## mother's way, by default), and the young are named for the parent whose way they follow. The rule is data: each of
## its four values is tried. Everything is a pure function of the data, so nothing in a life or a fight moves.
## Run: godot --headless --path . -s res://tests/test_game_birth.gd
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
	test_lookups()
	test_kinds()
	test_modes()
	test_rule_is_data()
	test_recipes()
	test_young()
	test_every_pair()
	test_validation()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Runs `body` with the breeding data changed as `edit` says, then puts it back.
func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameData.breeding.duplicate(true)
	edit.call(GameData.breeding)
	body.call()
	GameData.breeding = saved


func _set_rule(r: String) -> Callable:
	return func(b: Dictionary): b["settings"]["mixed_birth_rule"] = r


# ---------------------------------------------------------------- the data

func test_data() -> void:
	var found := GameBirth.validate()
	ok(found.is_empty(), "the birth data is sound" + ("" if found.is_empty() else ": " + str(found.slice(0, 4))))
	var count := {"egg": 0, "live": 0, "none": 0}
	for c in GameData.creatures:
		count[str(c["born"])] += 1
	ok(count["egg"] == 11 and count["live"] == 14 and count["none"] == 14, "39 creatures: 11 lay eggs (9 wild, the chicken and the goose), 14 bear live young (9 wild, sheep, cattle, pig, goat, horse) and 14 are not born (%s)" % str(count))
	for c in GameData.creatures:
		var id := str(c["id"])
		if c["born"] == "none":
			ok(not c.has("young") and not GameBirth.can_breed(id), "%s is not born, has no young and cannot be bred" % id)
		else:
			ok(str(c.get("young", "")) != "" and GameBirth.can_breed(id), "%s is born and its young have a name (%s)" % [id, c.get("young", "")])
	ok(str(GameData.breeding["settings"]["mixed_birth_rule"]) == "mother", "the rule in the data is the mother's way")
	ok(GameData.breeding["recipes"] is Array, "and there is a list of recipes (empty until the ranch brings its hybrids)")
	# the undead, the constructs, the fiends and the people-like foes are not ranched
	for id in ["skeleton", "wraith", "ghoul", "stone_golem", "fire_imp", "bandit", "goblin", "hollow_king", "the_unmade", "stonefather"]:
		ok(GameBirth.born(id) == "none", "%s is not born" % id)
	# the legends have young too, which is rare to find (a later rule): the wolf-alpha and the ember drake
	ok(GameBirth.born("grimfang") == "live" and GameBirth.born("vaerthax") == "egg", "Grimfang bears live young and Vaerthax lays eggs")
	# the rule matters in the game as built: there are egg-layers and live-bearers that live in one place
	var mixed_homes := 0
	for a in GameData.creatures:
		for b in GameData.creatures:
			if a["born"] == "egg" and b["born"] == "live" and not (a.get("biomes", []) as Array).filter(func(x): return x in b.get("biomes", [])).is_empty():
				mixed_homes += 1
	ok(mixed_homes > 0, "some creatures of the two ways share a home, so mixed pairings can happen (%d pairs)" % mixed_homes)


func test_lookups() -> void:
	ok(GameBirth.born("wolf") == "live" and GameBirth.born("drake") == "egg" and GameBirth.born("skeleton") == "none", "born reads the data")
	ok(GameBirth.young_name("wolf") == "pup" and GameBirth.young_name("drake") == "hatchling" and GameBirth.young_name("harpy") == "chick", "and so does the name of the young")
	ok(GameBirth.young_name("skeleton") == "", "a creature not born has no young to name")
	ok(GameBirth.born("no_such_creature") == "none" and GameBirth.young_name("no_such_creature") == "" and not GameBirth.can_breed("no_such_creature"), "an id that is no creature is not born")
	ok(GameBirth.rule() == "mother", "the rule is the mother's")
	_with(func(b): b["settings"]["mixed_birth_rule"] = "nonsense", func(): ok(GameBirth.rule() == "mother", "and an unknown rule falls back to the mother's"))


func test_kinds() -> void:
	ok(GameBirth.kind("wolf", "wolf") == "pure" and GameBirth.kind("drake", "drake") == "pure", "two of one species are pure")
	ok(GameBirth.kind("wolf", "frost_wolf") == "cross" and GameBirth.kind("wolf", "drake") == "cross", "two species with no recipe are a cross-breed")
	ok(GameBirth.kind("wolf", "skeleton") == "" and GameBirth.kind("skeleton", "wolf") == "" and GameBirth.kind("skeleton", "skeleton") == "", "anything with a creature that is not born cannot have young")
	_with(func(b): b["recipes"].append({"id": "ember_hound", "name": "Ember Hound", "parents": ["wolf", "drake"], "born": "egg", "young": "ember pup"}), func():
		ok(GameBirth.kind("wolf", "drake") == "hybrid" and GameBirth.kind("drake", "wolf") == "hybrid", "a pairing with a recipe is a hybrid, in either order")
		ok(GameBirth.kind("wolf", "frost_wolf") == "cross", "and the others are still cross-breeds"))


# ---------------------------------------------------------------- how they are born

func test_modes() -> void:
	ok(GameBirth.mode("wolf", "wolf") == "live" and GameBirth.mode("drake", "drake") == "egg", "two of a kind are born as their kind is")
	ok(GameBirth.mode("wolf", "frost_wolf") == "live" and GameBirth.mode("drake", "ash_wyrm") == "egg", "so are two kin of one way of being born")
	ok(GameBirth.mode("wolf", "skeleton") == "" and GameBirth.mode("skeleton", "drake") == "" and GameBirth.mode("goblin", "goblin") == "", "pairings that cannot have young give none")
	# the default: the mother's way
	ok(GameBirth.mode("wolf", "drake") == "live", "a wolf mother with a drake father bears live young")
	ok(GameBirth.mode("drake", "wolf") == "egg", "a drake mother with a wolf father lays eggs")
	ok(GameBirth.mode("harpy", "ogre") == "egg" and GameBirth.mode("ogre", "harpy") == "live", "likewise a harpy and an ogre, whichever is the mother")


func test_rule_is_data() -> void:
	var table := {
		"mother": [["wolf", "drake", "live"], ["drake", "wolf", "egg"]],
		"father": [["wolf", "drake", "egg"], ["drake", "wolf", "live"]],
		"egg": [["wolf", "drake", "egg"], ["drake", "wolf", "egg"]],
		"live": [["wolf", "drake", "live"], ["drake", "wolf", "live"]],
	}
	for r in table:
		_with(_set_rule(r), func():
			for row in table[r]:
				ok(GameBirth.mode(row[0], row[1]) == row[2], "rule '%s': a %s mother and a %s father give %s young" % [r, row[0], row[1], row[2]])
			# whatever the rule, creatures of one way of being born are not affected by it
			ok(GameBirth.mode("wolf", "frost_wolf") == "live" and GameBirth.mode("drake", "elder_dragon") == "egg", "rule '%s': kin of one way are born that way" % r)
			ok(GameBirth.mode("wolf", "skeleton") == "", "rule '%s': one that is not born still cannot breed" % r))


func test_recipes() -> void:
	var recipe := {"id": "ember_hound", "name": "Ember Hound", "parents": ["wolf", "drake"], "born": "egg", "young": "ember pup"}
	_with(func(b): b["recipes"].append(recipe), func():
		ok(GameBirth.recipe_for("wolf", "drake").get("id", "") == "ember_hound" and GameBirth.recipe_for("drake", "wolf").get("id", "") == "ember_hound", "a recipe is found in either order")
		ok(GameBirth.recipe_for("wolf", "harpy").is_empty(), "and only for its own pair")
		ok(GameBirth.mode("wolf", "drake") == "egg" and GameBirth.mode("drake", "wolf") == "egg", "a hybrid says for itself how it is born, whoever is the mother (the wolf mother no longer bears live young)")
		_with(_set_rule("live"), func(): ok(GameBirth.mode("wolf", "drake") == "egg", "and the rule for cross-breeds does not touch it"))
		ok(GameBirth.young_of("wolf", "drake") == "ember pup" and GameBirth.young_of("drake", "wolf") == "ember pup", "and its young have the recipe's name"))
	# a recipe wins even when both parents are born the same way
	_with(func(b): b["recipes"].append({"id": "cinder_wyrm", "name": "Cinder Wyrm", "parents": ["drake", "ash_wyrm"], "born": "live", "young": "wyrmling"}), func():
		ok(GameBirth.mode("drake", "ash_wyrm") == "live" and GameBirth.young_of("ash_wyrm", "drake") == "wyrmling", "a recipe may be born live though both parents lay eggs"))
	# a recipe with no usable birth falls back to the mother's
	_with(func(b): b["recipes"].append({"id": "odd", "name": "Odd", "parents": ["wolf", "drake"], "born": "none", "young": "x"}), func():
		ok(GameBirth.mode("wolf", "drake") == "live" and GameBirth.mode("drake", "wolf") == "egg", "a recipe whose birth is not egg or live falls back to the mother's way"))


func test_young() -> void:
	ok(GameBirth.young_of("wolf", "wolf") == "pup" and GameBirth.young_of("drake", "drake") == "hatchling", "the young of a pure pair are their kind's")
	ok(GameBirth.young_of("wolf", "drake") == "pup", "a wolf mother's live young are pups (named for the parent whose way they follow)")
	ok(GameBirth.young_of("drake", "wolf") == "hatchling", "a drake mother's eggs hatch hatchlings")
	ok(GameBirth.young_of("harpy", "drake") == "chick" and GameBirth.young_of("drake", "harpy") == "hatchling", "two egg-layers: the mother's young name")
	_with(_set_rule("egg"), func(): ok(GameBirth.young_of("wolf", "drake") == "hatchling", "when the rule makes an egg of a wolf's pairing, the young are named for the egg-layer"))
	_with(_set_rule("live"), func(): ok(GameBirth.young_of("drake", "wolf") == "pup", "and when it makes live young of a drake's, for the live-bearer"))
	ok(GameBirth.young_of("wolf", "skeleton") == "", "no young where there can be none")


# ---------------------------------------------------------------- every pairing

func test_every_pair() -> void:
	var ids: Array = GameData.creatures.map(func(c): return str(c["id"]))
	var bad := 0
	var cross := 0
	var counts := {"egg": 0, "live": 0, "": 0}
	for a in ids:
		for b in ids:
			var m := GameBirth.mode(str(a), str(b))
			counts[m] = int(counts.get(m, 0)) + 1
			var can := GameBirth.can_breed(str(a)) and GameBirth.can_breed(str(b))
			if (m == "") == can or m not in ["egg", "live", ""]:
				bad += 1
			if can and GameBirth.born(str(a)) != GameBirth.born(str(b)):
				cross += 1
				if m != GameBirth.born(str(a)):   # the default rule: the mother's way
					bad += 1
			if GameBirth.young_of(str(a), str(b)) == "" and m != "":
				bad += 1
	ok(bad == 0, "of all %d pairings, those that can have young give egg or live, the rest none, mixed ones follow the mother, and all have young to name (%d wrong)" % [ids.size() * ids.size(), bad])
	var layers := GameData.creatures.filter(func(c): return GameBirth.born(str(c["id"])) == "egg").size()
	var bearers := GameData.creatures.filter(func(c): return GameBirth.born(str(c["id"])) == "live").size()
	var breedable := layers + bearers
	ok(cross == 2 * layers * bearers, "there are %d mixed pairings (%d egg-layers x %d live-bearers, either way round)" % [cross, layers, bearers])
	ok(int(counts[""]) == ids.size() * ids.size() - breedable * breedable, "and %d pairings that cannot breed, the %d breedable creatures making %d" % [counts[""], breedable, breedable * breedable])


# ---------------------------------------------------------------- the validator

func test_validation() -> void:
	var saved_creatures: Array = GameData.creatures.duplicate(true)
	var c0: Dictionary = GameData.creatures[0]
	var old := str(c0["born"])
	c0["born"] = "sideways"
	ok(GameBirth.validate().any(func(p): return "born must be one of" in p), "an unknown way of being born is found")
	c0["born"] = "none"
	c0["young"] = "slimeling"
	ok(GameBirth.validate().any(func(p): return "not born has no young" in p), "young for a creature that is not born is found")
	c0["born"] = "egg"
	c0["young"] = ""
	ok(GameBirth.validate().any(func(p): return "needs the name of its young" in p), "a born creature with no name for its young is found")
	GameData.creatures = saved_creatures
	ok(old == "egg" and GameBirth.validate().is_empty(), "and putting it back, the data is sound again")
	_with(_set_rule("sometimes"), func(): ok(GameBirth.validate().any(func(p): return "mixed_birth_rule" in p), "an unknown rule is found"))
	var cases := {
		"two parents": [{"id": "r", "name": "R", "parents": ["wolf"], "born": "egg", "young": "x"}, "exactly two parents"],
		"parents that exist": [{"id": "r", "name": "R", "parents": ["wolf", "unicorn"], "born": "egg", "young": "x"}, "no creature called 'unicorn'"],
		"parents that can breed": [{"id": "r", "name": "R", "parents": ["wolf", "skeleton"], "born": "egg", "young": "x"}, "is not born and cannot be a parent"],
		"two species": [{"id": "r", "name": "R", "parents": ["wolf", "wolf"], "born": "egg", "young": "x"}, "two different species"],
		"a birth": [{"id": "r", "name": "R", "parents": ["wolf", "drake"], "born": "none", "young": "x"}, "born must be egg or live"],
		"a name for the young": [{"id": "r", "name": "R", "parents": ["wolf", "drake"], "born": "egg", "young": ""}, "needs the name of its young"],
		"an id and a name": [{"id": "", "name": "", "parents": ["wolf", "drake"], "born": "egg", "young": "x"}, "needs an id and a name"],
	}
	for name in cases:
		var recipe: Dictionary = cases[name][0]
		_with(func(b): b["recipes"].append(recipe), func(): ok(GameBirth.validate().any(func(p): return str(cases[name][1]) in p), "a recipe without %s is found" % name))
	var good := {"id": "a", "name": "A", "parents": ["wolf", "drake"], "born": "egg", "young": "x"}
	var dup := {"id": "b", "name": "B", "parents": ["drake", "wolf"], "born": "live", "young": "y"}
	_with(func(b): b["recipes"].append_array([good, dup]), func(): ok(GameBirth.validate().any(func(p): return "already a recipe" in p), "the same pairing twice, in either order, is found"))
	_with(func(b): b["recipes"].append(good), func(): ok(GameBirth.validate().is_empty(), "and a sound recipe is not flagged"))
