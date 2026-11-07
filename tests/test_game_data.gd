## The data check (tools/check_data.gd) and the text catalog (data/text/battle.json, GameMessages). The one
## command that checks every JSON file and every system's validator reports nothing, and it does find a
## broken catalog; the fight's log lines are the catalog's, word for word as they were when written in code
## (each line is spelled out here, including ones a fight seldom reaches); no log line is written in the battle
## code any more; and fights played through give lines with no missing key and no unfilled placeholder.
## Run: godot --headless --path . -s res://tests/test_game_data.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const Check := preload("res://tools/check_data.gd")

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
	test_check()
	test_lines()
	test_code()
	test_fights()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_check() -> void:
	var found := Check.problems()
	ok(found.is_empty(), "the data check finds nothing" + ("" if found.is_empty() else ": " + str(found.slice(0, 5))))
	var saved: Dictionary = GameData.messages.duplicate(true)
	# a message the code asks for goes missing
	GameData.messages["lines"].erase("victory")
	ok(Check.problems().any(func(p): return "'victory'" in p and "catalog does not have" in p), "a missing message is found")
	GameData.messages = saved.duplicate(true)
	# a message nothing asks for
	GameData.messages["lines"]["orphan"] = "Nobody says this."
	ok(Check.problems().any(func(p): return "'orphan'" in p and "nothing asks for it" in p), "an unused message is found")
	GameData.messages = saved.duplicate(true)
	GameData.messages["lines"]["victory"] = "  "
	ok(Check.problems().any(func(p): return "'victory'" in p and "not text" in p), "an empty message is found")
	GameData.messages = saved


# ---------------------------------------------------------------- the lines

func test_lines() -> void:
	GameMessages.problems.clear()
	var cases := [
		["hit", {"who": "Grimfang", "whom": "Tess", "n": 50, "tail": ""}, "Grimfang hits Tess for 50."],
		["hit", {"who": "Tess", "whom": "Grimfang", "n": 90, "tail": " (CRIT!)"}, "Tess hits Grimfang for 90 (CRIT!)."],
		["hit_ward", {"who": "A", "whom": "B", "n": 32, "absorbed": 18, "tail": ""}, "A hits B for 32 (18 absorbed)."],
		["hit_ward_all", {"who": "A", "whom": "B", "absorbed": 7}, "A hits B, and the ward absorbs all 7."],
		["foe_defeated", {"name": "Wolf"}, "Wolf is defeated."],
		["foe_steps_up", {"name": "Wolf"}, "Wolf steps up to the front."],
		["back_rank_steps_up", {}, "The back rank steps up to the front."],
		["ally_knocked_out", {"name": "Bren"}, "Bren is knocked senseless and out of the fight."],
		["dragons_breath", {"name": "Tess"}, "Tess breathes fire over the foes."],
		["foe_dodged", {"foe": "Wolf", "name": "Tess"}, "Wolf dodges Tess's attack."],
		["blood_magic_cost", {"name": "Tess", "n": 12}, "Blood Magic costs Tess 12 HP."],
		["feat_hp_cost", {"feat": "Reckless Swing", "name": "Tess", "n": 9}, "Reckless Swing costs Tess 9 HP."],
		["casts", {"name": "Tess", "ability": "Fireball"}, "Tess casts Fireball."],
		["uses", {"name": "Tess", "ability": "Cleave"}, "Tess uses Cleave."],
		["foe_resists", {"name": "Wolf", "what": "Poison"}, "Wolf resists Poison."],
		["foes_resist", {"n": 3, "what": "Poison"}, "3 foes resist Poison."],
		["mana_drawn", {"name": "Tess", "n": 14}, "Tess draws in 14 MP."],
		["brace", {"name": "Tess"}, "Tess braces for impact."],
		["hold_back", {"name": "Tess"}, "Tess holds back."],
		["escape_alone", {"name": "Tess"}, "Tess escapes!"],
		["escape_party", {"name": "Tess"}, "Tess and the party escape!"],
		["escape_failed", {"name": "Tess"}, "Tess fails to escape!"],
		["restores", {"name": "Tess", "n": 30, "source": "Potion"}, "Tess restores 30 HP (Potion)."],
		["tends", {"healer": "Oriel", "name": "Tess", "n": 22, "source": "Mend"}, "Oriel tends Tess: +22 HP (Mend)."],
		["steps_in_front", {"by": "Bren", "who": "Tess"}, "Bren steps in front of Tess."],
		["victory", {}, "Victory!"],
		["fallen", {"name": "Tess"}, "Tess has fallen..."],
		["improvises", {"name": "Bren"}, "Bren improvises."],
		["foe_missed", {"foe": "Wolf", "name": "Tess"}, "Wolf attacks, but Tess dodges."],
		["mana_blow", {"name": "Tess", "n": 5}, "Tess's mana takes 5 of the blow."],
	]
	var keys: Array = GameData.messages["lines"].keys()
	for c in cases:
		ok(GameMessages.line(c[0], c[1]) == c[2], "'%s' reads \"%s\"" % [c[0], c[2]])
		keys.erase(c[0])
	ok(keys.is_empty(), "every message in the catalog is spelled out here" + ("" if keys.is_empty() else ": " + str(keys)))
	ok(GameMessages.problems.is_empty(), "and none of them lacked a placeholder")
	# a missing key or placeholder is shown and recorded, never blank
	ok(GameMessages.line("no_such_line") == "[no_such_line]" and GameMessages.problems.size() == 1, "a missing key shows as [key] and is recorded")
	ok(GameMessages.line("brace", {}) == "{name} braces for impact." and GameMessages.problems.size() == 2, "a missing placeholder shows as {name} and is recorded")
	ok(GameMessages.fill("{a}{a} {b}", {"a": "x", "b": 3}) == "xx 3", "placeholders fill in one pass, repeats and numbers included")
	ok(GameMessages.fill("{a}", {"a": "{b}", "b": "no"}) == "{b}", "text that looks like a placeholder is not filled twice")
	ok(GameMessages.placeholders("{who} hits {whom} for {n}{tail}. {who}") == ["who", "whom", "n", "tail"], "the placeholders of a line are listed once each")
	GameMessages.problems.clear()


# ---------------------------------------------------------------- the code

func test_code() -> void:
	var src := FileAccess.get_file_as_string("res://core/game/game_battle.gd")
	var literal := RegEx.create_from_string("_say\\(\\s*\"")
	ok(literal.search(src) == null, "no log line is written in the battle code: every _say takes a message")


# ---------------------------------------------------------------- fights

func test_fights() -> void:
	GameMessages.problems.clear()
	var lines := 0
	var odd: Array = []
	for c in [[3, "warrior", 0, "hunt"], [4, "mage", 2, "hunt"], [8, "cleric", 3, "hunt_hard"], [11, "rogue", 3, "legend"], [14, "paladin", 1, "legend"]]:
		var d := Scen.make(c[0], c[1], c[2], c[3])
		var b := d.battle
		var guard := 0
		while not b.is_over() and guard < Scen.GUARD:
			guard += 1
			GameTactics.auto_turn(b)
		for l in b.log:
			lines += 1
			if "{" in l or "[" in l and "]" in l and l.begins_with("["):
				odd.append(l)
	ok(lines > 100, "fights gave lines to read (%d)" % lines)
	ok(odd.is_empty(), "no line has an unfilled placeholder or a missing key" + ("" if odd.is_empty() else ": " + str(odd.slice(0, 3))))
	ok(GameMessages.problems.is_empty(), "and no message went wrong" + ("" if GameMessages.problems.is_empty() else ": " + str(GameMessages.problems.slice(0, 3))))
