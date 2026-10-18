## The autopilot's choice of hunt: balance.json "bot_hard_hunt" (every key there and that each is
## read), GameBot.wants_hard_hunt for a ready heir and for each way of not being ready (wounded,
## out of potions, too green, no run of wins, too little gear, a deadly place, off the cadence,
## turned off), GameBot.step taking a Hard hunt only when the rule holds, the player's
## auto-battle untouched, and determinism (same seed, same journal) with Hard hunts in the story.
## Run: godot --headless --path . -s res://tests/test_game_bot.gd
extends SceneTree

const KEYS := ["every", "min_level", "min_hp_frac", "min_potions", "min_gear", "min_streak", "clean_hp_frac", "max_danger"]
const RULE_KEYS := ["every", "min_level", "min_hp_frac", "min_potions", "min_gear", "min_streak", "max_danger"]

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_settings()
	test_rule()
	test_step()
	test_auto_battle()
	test_lives()
	test_determinism()
	print("bot tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _rule() -> Dictionary:
	return GameData.bal("bot_hard_hunt")


## A heir who meets every part of the rule, standing in the home town.
func _ready_dyn(seed_val: int = 61, cls: String = "warrior") -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	var r := _rule()
	var h := d.heir
	h.level = int(r["min_level"]) + 5
	h.spells = []
	h.learn_spells()
	GameSkillTree.start(h)
	h.equipment = {"weapon": "iron_sword", "armor": "leather_armor", "trinket": ""}
	h.potions = int(r["min_potions"])
	h.clean_streak = int(r["min_streak"])
	# On the cadence, and clear of the bot's training turns ((wins + level) % 5 == 4) even one win on.
	h.battles_won = int(r["every"]) * 7
	while (h.battles_won + h.level) % 5 in [3, 4]:
		h.battles_won += int(r["every"])
	h.full_heal()
	d.world.location = GameData.world["start"]
	return d


func _with(key: String, value: Variant, f: Callable) -> Variant:
	var r := _rule()
	var old: Variant = r[key]
	r[key] = value
	var out: Variant = f.call()
	r[key] = old
	return out


# ---------------------------------------------------------------- settings

func test_settings() -> void:
	var r := _rule()
	ok(KEYS.all(func(k): return r.has(k)), "balance.json bot_hard_hunt has every key: %s" % str(r.keys()))
	ok(r.size() == KEYS.size(), "and no key this suite does not know about")
	ok(int(r["every"]) >= 1 and float(r["min_hp_frac"]) > 0.55 and int(r["min_potions"]) >= 1 and int(r["min_level"]) > 1,
		"the shipped rule hard-hunts sometimes, never wounded (the bot rests below 55%%), never potionless, never as a fresh founder")
	# Each key is read: pushing it just past the ready heir turns the Hard hunt off.
	var d := _ready_dyn()
	var h := d.heir
	ok(GameBot.wants_hard_hunt(d), "the ready heir wants a Hard hunt")
	var past := {
		"every": 0, "min_level": h.level + 1, "min_hp_frac": 1.01, "min_potions": h.potions + 1,
		"min_gear": 3, "min_streak": h.clean_streak + 1,
		"max_danger": float(d.world.here().get("danger", 1.0)) - 0.01,
	}
	for k in RULE_KEYS:
		ok(not _with(k, past[k], func(): return GameBot.wants_hard_hunt(d)), "the rule reads %s" % k)
	ok(_with("every", 1, func(): h.battles_won += 1; var w := GameBot.wants_hard_hunt(d); h.battles_won -= 1; return w),
		"every 1 hard-hunts whenever the heir is ready")
	ok(GameBot.wants_hard_hunt(d), "the rule is restored after the probes")


# ---------------------------------------------------------------- the rule

func test_rule() -> void:
	var r := _rule()
	var cases := {
		"wounded (90% HP)": func(d: GameDynasty): d.heir.hp = int(float(d.heir.max_hp()) * 0.9),
		"badly wounded (60% HP)": func(d: GameDynasty): d.heir.hp = int(float(d.heir.max_hp()) * 0.6),
		"out of potions": func(d: GameDynasty): d.heir.potions = 0,
		"one potion short": func(d: GameDynasty): d.heir.potions = int(r["min_potions"]) - 1,
		"a fresh founder (level 1)": func(d: GameDynasty): d.heir.level = 1,
		"just below the level": func(d: GameDynasty): d.heir.level = int(r["min_level"]) - 1,
		"no run of wins": func(d: GameDynasty): d.heir.clean_streak = 0,
		"one win short of the run": func(d: GameDynasty): d.heir.clean_streak = int(r["min_streak"]) - 1,
		"no gear": func(d: GameDynasty): d.heir.equipment = {"weapon": "", "armor": "", "trinket": ""},
		"too little gear": func(d: GameDynasty): d.heir.equipment = {"weapon": "iron_sword", "armor": "", "trinket": ""},
		"off the cadence": func(d: GameDynasty): d.heir.battles_won += 1,
		"a deadly place": func(d: GameDynasty): d.world.location = _deadliest(),
	}
	for what in cases:
		var d := _ready_dyn()
		(cases[what] as Callable).call(d)
		ok(not GameBot.wants_hard_hunt(d), "no Hard hunt when %s" % what)
	for cls in GameData.starting_ids(GameData.classes):
		var d := _ready_dyn(62, cls)
		ok(GameBot.wants_hard_hunt(d), "%s: a ready heir wants a Hard hunt" % cls)
	# A fresh founder fails the rule whatever else is true.
	var f := GameDynasty.new_game(63, "", "warrior", "faetouched", "human")
	ok(not GameBot.wants_hard_hunt(f), "a fresh founder never wants a Hard hunt")
	# Cheap: no RNG and next to no time.
	var d := _ready_dyn()
	var state: Variant = d.rng.state
	var t0 := Time.get_ticks_usec()
	for i in 10000:
		GameBot.wants_hard_hunt(d)
	var took := Time.get_ticks_usec() - t0
	ok(d.rng.state == state, "the rule draws nothing from the dynasty's RNG")
	ok(took < 1000000, "10,000 decisions take next to no time (%d us, under 100 us each)" % took)


func _deadliest() -> String:
	var best := ""
	var worst := -1.0
	for loc in GameData.world["locations"]:
		if float(loc.get("danger", 1.0)) > worst:
			worst = float(loc.get("danger", 1.0))
			best = loc["id"]
	ok(worst > float(_rule()["max_danger"]), "some place is deadlier than the rule allows (%s %.2f)" % [best, worst])
	return best


# ---------------------------------------------------------------- GameBot.step

## Runs one step on a fresh copy of the ready heir after `prep`, and returns the kind of battle it
## began ("" when it did something else). Steps that do something else are tried on other seeds.
func _step_kind(prep: Callable, seeds: Array) -> Array:
	var kinds: Array = []
	for s in seeds:
		var d := _ready_dyn(s)
		d.heir.family_founded = true   # not off to found a family
		d.heir.gold = 0                # buys nothing, so the potions stay as set
		for c in GameData.creatures:   # no legend to travel to: the step is about the hunt
			if c.get("boss", false):
				d.slain_bosses[c["id"]] = d.gen
		prep.call(d)
		d.battle_kind = ""
		GameBot.step(d)
		kinds.append(d.battle_kind)
	return kinds


func test_step() -> void:
	var seeds := range(100, 140)
	var ready := _step_kind(func(_d): pass, seeds)
	ok(ready.has("hunt_hard") and not ready.has("hunt"), "a ready heir's hunts are Hard hunts: %s" % str(_tally(ready)))
	var cases := {
		"wounded": func(d: GameDynasty): d.heir.hp = int(float(d.heir.max_hp()) * 0.8),
		"out of potions": func(d: GameDynasty): d.heir.potions = 0,
		"below the strength rule": func(d: GameDynasty): d.heir.clean_streak = 0,
		"a fresh founder's level": func(d: GameDynasty): d.heir.level = 1,
		"off the cadence": func(d: GameDynasty): d.heir.battles_won += 1,
	}
	for what in cases:
		var kinds := _step_kind(cases[what], seeds)
		ok(kinds.has("hunt") and not kinds.has("hunt_hard"), "GameBot.step never hard-hunts %s: %s" % [what, str(_tally(kinds))])
	# A win adds to the run, a defeat or a flight ends it, and a save keeps it.
	var d := _ready_dyn()
	d.heir.clean_streak = 3
	var b := d.start_hunt("hunt")
	b.result = "victory"
	for e in b.enemies:
		e["hp"] = 0
	d.finish_battle()
	ok(d.heir.clean_streak == 4, "a clean victory adds to the run of wins (%d)" % d.heir.clean_streak)
	# A costly win (below clean_hp_frac at the end) ends the run; the setting is read.
	for frac in [0.5, 0.9]:
		d.heir.clean_streak = 4
		d.heir.hp = int(float(d.heir.max_hp()) * 0.7)
		var bw := d.start_hunt("hunt")
		bw.result = "victory"
		for e in bw.enemies:
			e["hp"] = 0
		_with("clean_hp_frac", frac, func(): d.finish_battle(); return null)
		var want := 5 if frac < 0.7 else 0
		ok(d.heir.clean_streak == want, "a win at 70%% HP with clean_hp_frac %.1f leaves a run of %d (%d)" % [frac, want, d.heir.clean_streak])
	d.heir.full_heal()
	d.heir.clean_streak = 4
	var copy := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(copy.heir.clean_streak == 4, "a save keeps the run of wins")
	var old := d.heir.to_dict()
	old.erase("clean_streak")
	ok(GameHeir.from_dict(old).clean_streak == 0, "an old save without it starts with no run")
	b = d.start_hunt("hunt")
	b.result = "fled"
	d.finish_battle()
	ok(d.heir.clean_streak == 0, "a flight ends the run")
	d.heir.clean_streak = 5
	d.heir.extra_life_used = true
	b = d.start_hunt("hunt")
	b.result = "defeat"
	d.finish_battle()
	ok(d.heir.clean_streak == 0, "a defeat ends the run")


func _tally(kinds: Array) -> Dictionary:
	var t := {}
	for k in kinds:
		t[k] = int(t.get(k, 0)) + 1
	return t


# ---------------------------------------------------------------- auto-battle

func test_auto_battle() -> void:
	# The player's auto-battle fights whatever hunt the player started, and the rule never runs.
	for kind in ["hunt", "hunt_hard"]:
		var d := _ready_dyn(71)
		d.auto_battle = true
		d.heir.clean_streak = 0   # the bot rule would say plain
		d.start_hunt(kind)
		ok(d.battle_kind == kind and GameTactics.auto_from_start(d), "auto-battle takes on the player's %s as started" % kind)


# ---------------------------------------------------------------- whole lives

func test_lives() -> void:
	var hard := 0
	var plain := 0
	var bad := 0
	var r := _rule()
	for s in 3:
		var d := GameDynasty.new_game(500 + s, "", ["warrior", "mage", "rogue"][s], "faetouched", "human")
		for i in 3000:
			if d.state == "succession":
				d.choose_heir(0)
				continue
			if d.state != "life":
				break
			var h := d.heir
			var before := [h.level, h.clean_streak, h.battles_won, d.gen]
			d.battle_kind = ""
			GameBot.step(d)
			if d.battle_kind == "hunt":
				plain += 1
			elif d.battle_kind == "hunt_hard":
				hard += 1
				if before[0] < int(r["min_level"]) or before[1] < int(r["min_streak"]) or before[2] % int(r["every"]) != 0:
					bad += 1
	ok(hard > 0 and plain > hard, "over whole lives the bot hard-hunts sometimes, mostly hunts plain (%d hard, %d plain)" % [hard, plain])
	ok(bad == 0, "every Hard hunt was taken by a seasoned heir on the cadence (%d were not)" % bad)


# ---------------------------------------------------------------- determinism

func test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var d := GameDynasty.new_game(4247, "", "paladin", "faetouched", "human")
		var hard := 0
		for i in 3000:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				d.battle_kind = ""
				GameBot.step(d)
				if d.battle_kind == "hunt_hard":
					hard += 1
		runs.append([d.journal.duplicate(), JSON.stringify(d.to_dict()), hard])
	ok(runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1], "the same seed tells the same story")
	ok(int(runs[0][2]) > 0 and runs[0][2] == runs[1][2], "with the same Hard hunts in it (%d)" % runs[0][2])
