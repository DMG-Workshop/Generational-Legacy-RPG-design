## Notice-board quests (GameQuests): content, rules, rewards, saves, the board and the autopilot.
## godot --headless --path . -s res://tests/test_game_quests.gd
extends SceneTree

const BoardPanel := preload("res://ui/play/board_panel.gd")
const LAST_GEN := 999

var failures := 0
var checks := 0


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	_test_data()
	_test_kill_windows()
	_test_chain_data()
	_test_kill_flow()
	_test_real_hunts()
	_test_gates()
	_test_visit_flow()
	_test_flag_flow()
	_test_rift_chain_played()
	_test_scaling()
	_test_save_load()
	_test_old_saves()
	_test_succession()
	_test_bot()
	_finish_with_ui.call_deferred()


## The board needs a live scene tree, so its checks run once the tree is up.
func _finish_with_ui() -> void:
	await process_frame
	_test_empty_data()
	_test_board_ui()
	print("%d checks, %d failures" % [checks, failures])
	print("ALL PASS" if failures == 0 else "TESTS FAILED")
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- helpers

func _fresh(gen: int = 1, level: int = 1, place: String = "hearthmere", seed_val: int = 4242) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tester", "warrior", GameData.traits_in(["bloodline"])[0], "human")
	d.gen = gen
	d.heir.gen = gen
	d.heir.level = level
	d.heir.lifespan = 100000.0
	d.world.visit(place)
	d.journal = []
	return d


func _q(id: String) -> Dictionary:
	return GameQuests.def(id)


func _flags_of(names: Array) -> Dictionary:
	var f := {}
	for n in names:
		f[n] = 1
	return f


## Places a family member can walk to from the start, given these story flags.
func _reachable(flags: Dictionary) -> Array:
	var w := GameWorld.new()
	var seen: Array = [GameData.world["start"]]
	var i := 0
	while i < seen.size():
		for link in w.roads(seen[i], flags):
			if link["to"] not in seen:
				seen.append(link["to"])
		i += 1
	return seen


func _creature(id: String) -> Dictionary:
	for c in GameData.creatures:
		if c["id"] == id:
			return c
	return {}


## Where creature `id` can be met at generation `g` (biome match or lair), limited to `places`.
func _spawn_places(id: String, g: int, places: Array) -> Array:
	var c := _creature(id)
	if c.is_empty() or g < int(c["min_gen"]) or g > int(c["max_gen"]):
		return []
	if c.get("boss", false):
		return [c["lair"]] if c.get("lair", "") in places else []
	var out: Array = []
	for p in places:
		var biomes: Array = GameWorld.place(p).get("biomes", [])
		if (c.get("biomes", []) as Array).any(func(b): return b in biomes):
			out.append(p)
	return out


func _journal_has(d: GameDynasty, part: String) -> bool:
	for line in d.journal:
		if str(line).find(part) >= 0:
			return true
	return false


## A real hunt here, won at once: the dynasty's own spawn rules pick the foes.
func _won_hunt(d: GameDynasty) -> Array:
	var b := d.start_hunt("hunt")
	var ids: Array = []
	for e in b.enemies:
		e["hp"] = 0
		ids.append(e["id"])
	b.result = "victory"
	d.finish_battle()
	d.heir.full_heal()
	return ids


func _travel_to(d: GameDynasty, target: String) -> void:
	var path := d.world.route_to(target, d.flags)
	for step in path:
		d.travel(step)
		d.heir.full_heal()


# ---------------------------------------------------------------- content

func _test_data() -> void:
	var qs: Array = GameData.quests
	_check(qs.size() >= 18 and qs.size() <= 24, "18-24 quests (%d)" % qs.size())
	var ids := {}
	var produced := {}
	for q in qs:
		for f in q.get("reward", {}).get("flags", []):
			produced[f] = q["id"]
	var per_town := {}
	var era := {"early": 0, "mid": 0, "late": 0}
	var uniques := 0
	var echoes := 0
	var repeatables := 0
	var place_ids: Array = GameData.world["locations"].map(func(l): return l["id"])
	for q in qs:
		var id: String = q.get("id", "")
		_check(id != "" and not ids.has(id), "unique id %s" % id)
		ids[id] = true
		for key in ["name", "giver", "text", "requires", "objective", "reward"]:
			_check(q.has(key), "%s has %s" % [id, key])
		_check(str(q["name"]).length() <= 32, "%s name fits a card" % id)
		_check(str(q["text"]).length() >= 40 and str(q["text"]).length() <= 260, "%s text is a short notice" % id)
		var giver := GameWorld.place(q["giver"])
		_check(giver.get("type", "") == "town" and "board" in giver.get("services", []), "%s giver %s is a town with a board" % [id, q["giver"]])
		per_town[q["giver"]] = int(per_town.get(q["giver"], 0)) + 1
		var req: Dictionary = q["requires"]
		for key in ["min_level", "min_gen", "flags", "not_flags"]:
			_check(req.has(key), "%s requires.%s" % [id, key])
		var lo := int(req.get("min_gen", 1))
		var hi := int(req.get("max_gen", LAST_GEN))
		_check(lo >= 1 and lo <= hi and lo <= LAST_GEN, "%s window %d-%d is sane" % [id, lo, hi])
		_check(int(req.get("min_level", 1)) >= 1 and int(req.get("min_level", 1)) <= 100, "%s min_level reachable" % id)
		if lo <= 60:
			era["early"] += 1
		elif lo < 300:
			era["mid"] += 1
		else:
			era["late"] += 1
		for f in req.get("flags", []):
			_check(produced.has(f), "%s needs flag %s that some quest sets" % [id, f])
			_check(produced.get(f, "") != id, "%s does not need its own flag" % id)
		for f in req.get("not_flags", []):
			_check(produced.has(f), "%s not_flag %s is a real flag" % [id, f])
		var o: Dictionary = q["objective"]
		match str(o.get("type", "")):
			"kill":
				var t: Array = GameQuests.targets(q)
				_check(not t.is_empty(), "%s has kill targets" % id)
				for c in t:
					_check(not _creature(c).is_empty(), "%s target %s exists" % [id, c])
				_check(int(o.get("count", 0)) >= 1 and int(o.get("count", 0)) <= 10, "%s count 1-10" % id)
				if o.has("place"):
					_check(o["place"] in place_ids, "%s place %s exists" % [id, o["place"]])
			"visit":
				_check(str(o.get("target", "")) in place_ids, "%s visit target exists" % id)
				_check(o.get("target", "") in _reachable(_flags_of(req.get("flags", []))), "%s visit target reachable" % id)
				_check(o.get("target", "") != q["giver"], "%s does not send you to its own town" % id)
			"flag":
				_check(produced.has(o.get("flag", "")), "%s waits on a flag some quest sets" % id)
			_:
				_check(false, "%s has a known objective type" % id)
		var r: Dictionary = q["reward"]
		_check(int(r.get("gold", 0)) > 0 and int(r.get("xp", 0)) > 0, "%s pays gold and xp" % id)
		for it in r.get("items", []):
			var item := GameItems.item_def(it)
			_check(not item.is_empty(), "%s reward item %s exists" % [id, it])
			if item.get("unique", false):
				uniques += 1
				_check(not q.get("repeatable", false), "%s: unique %s is not on a repeatable bounty" % [id, it])
		if r.has("echo"):
			echoes += 1
			var s := float(r["echo"].get("strength", 0.0))
			_check(s > 0.0 and s <= 0.15, "%s echo is small (%.2f)" % [id, s])
			_check(str(r["echo"].get("text", "")).find("{heir}") >= 0, "%s echo names the heir" % id)
		if q.get("repeatable", false):
			repeatables += 1
			_check(int(q.get("cooldown", 0)) >= 1, "%s bounty has a cooldown in generations" % id)
			_check(GameQuests.kind(q) == "kill", "%s bounty is a kill quest" % id)
			_check(req.has("max_gen") or not GameQuests.targets(q).is_empty(), "%s bounty ends" % id)
		for g in [1, 300, LAST_GEN]:
			var d := _fresh(g, 1)
			_check(GameQuests.objective_text(q) != "" and GameQuests.objective_text(q).find("{") < 0, "%s objective text" % id)
			_check(GameQuests.reward_text(d, q) != "", "%s reward text" % id)
	for town in ["hearthmere", "ironford", "kingshold", "brinehaven"]:
		_check(int(per_town.get(town, 0)) >= 4, "%s posts at least 4 quests" % town)
	_check(era["early"] >= 6 and era["mid"] >= 3 and era["late"] >= 3, "quests spread over eras %s" % str(era))
	_check(uniques >= 3, "some tier-4 uniques reward big quests (%d)" % uniques)
	_check(echoes >= 3, "some quests leave a glory echo")
	_check(repeatables >= 5, "repeatable bounties exist (%d)" % repeatables)


## Every generation a kill quest can be posted, a target lives in a reachable place.
func _test_kill_windows() -> void:
	for q in GameData.quests:
		if GameQuests.kind(q) != "kill":
			continue
		var req: Dictionary = q["requires"]
		var flags := _flags_of(req.get("flags", []))
		var places := _reachable(flags)
		if q["objective"].has("place"):
			places = [q["objective"]["place"]] if q["objective"]["place"] in places else []
		var lo := int(req.get("min_gen", 1))
		var hi := mini(int(req.get("max_gen", LAST_GEN)), LAST_GEN)
		var gaps: Array = []
		for g in range(lo, hi + 1):
			var found := false
			for t in GameQuests.targets(q):
				if not _spawn_places(t, g, places).is_empty():
					found = true
					break
			if not found:
				gaps.append(g)
		# A window may outlast its quarry only if the board stops posting it (bosses past their era).
		var posted_gaps: Array = []
		for g in gaps:
			var probe := _fresh(g)
			probe.flags = flags.duplicate()
			if GameQuests.achievable(probe, q):
				posted_gaps.append(g)
		_check(posted_gaps.is_empty(), "%s: a target spawns in a reachable place in every posted generation (gaps %s)" % [q["id"], str(posted_gaps.slice(0, 5))])
		_check(gaps.size() < (hi - lo + 1), "%s: posted for at least part of its window" % q["id"])


func _test_chain_data() -> void:
	var chain: Array = GameData.quests.filter(func(q): return q.get("chain", "") == "rift")
	_check(chain.size() >= 3 and chain.size() <= 5, "rift chain has 3-5 steps (%d)" % chain.size())
	var towns := {}
	var finals := 0
	for q in chain:
		towns[q["giver"]] = true
		if "rift_open" in q["reward"].get("flags", []):
			finals += 1
	_check(towns.size() >= 3, "rift chain crosses towns (%d)" % towns.size())
	_check(finals == 1, "exactly one chain step sets rift_open")
	# Walk the chain by flags: each step unlocks the next, and the last sets rift_open.
	var flags := {}
	var order: Array = []
	for i in chain.size():
		var next: Dictionary = {}
		for q in chain:
			if q["id"] in order:
				continue
			var req: Dictionary = q["requires"]
			if (req.get("flags", []) as Array).all(func(f): return flags.has(f)) and not (req.get("not_flags", []) as Array).any(func(f): return flags.has(f)):
				next = q
				break
		_check(not next.is_empty(), "rift chain step %d is reachable by flags" % (i + 1))
		if next.is_empty():
			return
		order.append(next["id"])
		for f in next["reward"].get("flags", []):
			flags[f] = 1
	_check(flags.has("rift_open"), "finishing the chain sets rift_open")
	var first := int(chain.filter(func(q): return q["id"] == order[0])[0]["requires"]["min_gen"])
	_check(first <= 100, "rift chain opens to a normal playthrough (first step gen %d)" % first)
	var w := GameWorld.new()
	_check(w.roads("highcrag", {}).all(func(r): return r["to"] != "the_rift"), "the Rift is sealed before rift_open")
	_check(w.roads("highcrag", {"rift_open": 1}).any(func(r): return r["to"] == "the_rift"), "rift_open unseals Highcrag -> The Rift")


# ---------------------------------------------------------------- rules

func _test_kill_flow() -> void:
	var d := _fresh(1, 1)
	var qs := d.quests
	var q := _q("hm_wolf_cull")
	_check(not q.is_empty(), "wolf cull exists")
	_check(qs.postings(d, "hearthmere").any(func(x): return x["id"] == "hm_wolf_cull"), "wolf cull posted at gen 1")
	_check(qs.postings(d, "ironford").all(func(x): return x["giver"] == "ironford"), "boards post only their own notices")
	_check(qs.accept_block(d, "hm_wolf_cull") == "", "wolf cull can be taken")
	qs.accept(d, "hm_wolf_cull")
	_check(qs.is_active("hm_wolf_cull"), "wolf cull active")
	_check(qs.postings(d, "hearthmere").all(func(x): return x["id"] != "hm_wolf_cull"), "taken notice leaves the board")
	_check(qs.accept(d, "hm_wolf_cull")[0].find("already") >= 0, "cannot take twice")
	qs.on_kill(d, "slime")
	_check(int(qs.entry("hm_wolf_cull")["progress"]) == 0, "slime does not count")
	for i in 7:
		qs.on_kill(d, "wolf")
	var goal := GameQuests.goal(q)
	_check(int(qs.entry("hm_wolf_cull")["progress"]) == goal, "progress stops at goal")
	_check(qs.is_complete(qs.entry("hm_wolf_cull")), "wolf cull complete")
	_check(_journal_has(d, "Report to the notice board in Hearthmere"), "journal says where to report")
	d.world.visit("greenvale")
	var away := qs.turn_in(d, "hm_wolf_cull")
	_check(qs.is_active("hm_wolf_cull") and away[0].find("Hearthmere") >= 0, "cannot turn in away from the giver")
	d.world.visit("hearthmere")
	var gold := d.heir.gold
	var expect_gold := GameQuests.reward_gold(d, q)
	var expect_xp := GameQuests.reward_xp(d, q)
	_check(expect_gold == int(round(60.0 * GameData.enemy_scale(1) * float(GameData.bal("quest_gold_mult")))), "gold reward formula")
	qs.turn_in(d, "hm_wolf_cull")
	_check(d.heir.gold == gold + expect_gold, "gold paid")
	_check(d.heir.level > 1, "xp paid (%d xp)" % expect_xp)
	_check(not qs.is_active("hm_wolf_cull") and qs.times_done("hm_wolf_cull") == 1 and "hm_wolf_cull" in qs.done, "recorded as done")
	_check(_journal_has(d, "Quest complete: Cull the Wolves"), "journal records the turn-in")
	var cd := int(q.get("cooldown", 1))
	for g in range(1, 1 + cd):
		d.gen = g
		_check(not qs.is_posted(d, q), "bounty on cooldown at gen %d" % g)
	d.gen = 1 + cd
	_check(qs.is_posted(d, q), "bounty back after %d generations" % cd)
	d.gen = int(q["requires"]["max_gen"]) + 1
	_check(not qs.is_posted(d, q), "bounty gone after its era")
	# A one-off quest never comes back.
	var d2 := _fresh(1, 20)
	d2.quests.accept(d2, "hm_grimfang")
	d2.quests.on_kill(d2, "grimfang")
	d2.quests.turn_in(d2, "hm_grimfang")
	_check(not d2.quests.is_posted(d2, _q("hm_grimfang")), "one-off quest not reposted")
	_check("elven_bow" in d2.heir.inventory, "item reward given through give_item")
	_check(d2.echo_total("glory", "quest_hm_grimfang") > 0.0, "glory echo left by a big quest")
	# A legend slain before the notice is taken is no longer posted.
	var d3 := _fresh(1, 20)
	d3.slain_bosses["grimfang"] = 1
	_check(not d3.quests.is_posted(d3, _q("hm_grimfang")), "dead legend's bounty not posted")


func _test_real_hunts() -> void:
	var d := _fresh(1, 3)
	d.quests.accept(d, "hm_wolf_cull")
	var wolves := 0
	var guard := 0
	while not d.quests.is_complete(d.quests.entry("hm_wolf_cull")) and guard < 200:
		guard += 1
		wolves += _won_hunt(d).count("wolf")
		_check(d.state == "life", "heir survives the test hunts")
		if d.state != "life":
			return
	_check(d.quests.is_complete(d.quests.entry("hm_wolf_cull")), "real hunts at Hearthmere finish the cull (%d hunts)" % guard)
	_check(wolves >= 5, "only wolves counted (%d wolves)" % wolves)
	# Every kill quest's target is actually spawned by the hunt rules at its era start.
	for q in GameData.quests:
		if GameQuests.kind(q) != "kill":
			continue
		var req: Dictionary = q["requires"]
		var flags := _flags_of(req.get("flags", []))
		var places := _reachable(flags)
		if q["objective"].has("place"):
			places = [q["objective"]["place"]]
		for g in [int(req["min_gen"]), mini(int(req.get("max_gen", LAST_GEN)), LAST_GEN)]:
			var hit := false
			for t in GameQuests.targets(q):
				var c := _creature(t)
				for p in _spawn_places(t, g, places):
					var h := _fresh(g, 50, p)
					h.flags = flags.duplicate()
					if c.get("boss", false):
						hit = hit or h.available_boss().get("id", "") == t
					else:
						for i in 40:
							if t in _won_hunt(h):
								hit = true
								break
							if h.state != "life":
								break
					if hit:
						break
				if hit:
					break
			var probe := _fresh(g)
			probe.flags = flags.duplicate()
			if GameQuests.achievable(probe, q):
				_check(hit, "%s: hunting at gen %d really meets a target" % [q["id"], g])


func _test_gates() -> void:
	var d := _fresh(1, 1)
	var qs := d.quests
	_check(qs.accept_block(d, "hm_mirefen_lantern") == "Needs level 2.", "level gate shown")
	qs.accept(d, "hm_mirefen_lantern")
	_check(not qs.is_active("hm_mirefen_lantern"), "level gate holds")
	d.world.visit("ironford")
	_check(qs.accept_block(d, "hm_wolf_cull").find("Hearthmere") >= 0, "taken only at the giver's board")
	d.world.visit("greenvale")
	_check(qs.postings(d, "greenvale").is_empty(), "no board, no notices")
	_check(qs.accept(d, "no_such_quest") == ["No such notice."], "unknown quest refused")
	_check(qs.turn_in(d, "no_such_quest").size() == 1 and qs.abandon(d, "no_such_quest").size() == 1, "unknown turn-in/abandon refused")
	# The active limit comes from balance.json.
	var max_active := int(GameData.bal("quest_max_active"))
	var d2 := _fresh(40, 99, "kingshold")
	var taken := 0
	for town in ["kingshold", "hearthmere", "ironford", "brinehaven"]:
		d2.world.visit(town)
		for q in d2.quests.postings(d2, town):
			if d2.quests.accept_block(d2, q["id"]) == "":
				d2.quests.accept(d2, q["id"])
				taken += 1
	_check(d2.quests.active.size() == max_active, "active limit %d holds (%d taken)" % [max_active, taken])
	var extra: Array = d2.quests.postings(d2, d2.world.location)
	if not extra.is_empty():
		_check(d2.quests.accept_block(d2, extra[0]["id"]).find("%d" % max_active) >= 0, "limit message names the limit")
	var first: String = d2.quests.active[0]["id"]
	d2.quests.abandon(d2, first)
	_check(d2.quests.active.size() == max_active - 1 and not d2.quests.is_active(first), "abandon frees a slot")
	_check(d2.quests.times_done(first) == 0, "abandoning is not completing")


func _test_visit_flow() -> void:
	var d := _fresh(1, 5)
	var qs := d.quests
	qs.accept(d, "hm_mirefen_lantern")
	_check(not qs.is_complete(qs.entry("hm_mirefen_lantern")), "lantern starts open")
	d.travel("mirefen")
	_check(qs.is_complete(qs.entry("hm_mirefen_lantern")), "arriving in Mirefen completes it")
	_check(qs.turn_in(d, "hm_mirefen_lantern")[0].find("Hearthmere") >= 0, "paid only at the giver")
	d.travel("hearthmere")
	qs.turn_in(d, "hm_mirefen_lantern")
	_check("prayer_beads" in d.heir.inventory, "lantern pays its item")
	# Taking a visit quest while standing at the target does not count until you arrive there.
	var d2 := _fresh(1, 20)
	d2.world.visit("ironford")
	d2.quests.accept(d2, "if_deepstone_survey")
	_check(not d2.quests.is_complete(d2.quests.entry("if_deepstone_survey")), "survey open at Ironford")
	d2.travel("deepstone_halls")
	_check(d2.quests.is_complete(d2.quests.entry("if_deepstone_survey")), "survey done on arrival")
	d2.travel("ironford")
	d2.quests.turn_in(d2, "if_deepstone_survey")
	_check(d2.flags.has("deepstone_surveyed"), "quest flag set through set_flag")


func _test_flag_flow() -> void:
	var lw := _q("hm_long_watch")
	var d := _fresh(int(lw["requires"]["min_gen"]), 10)
	_check(not d.quests.is_posted(d, lw), "long watch hidden before the seal is seen")
	d.set_flag("rift_seal_seen")
	_check(d.quests.is_posted(d, lw), "long watch posted once the seal is seen")
	d.quests.accept(d, "hm_long_watch")
	_check(not d.quests.is_complete(d.quests.entry("hm_long_watch")), "long watch open")
	d.set_flag("rift_open")
	_check(d.quests.is_complete(d.quests.entry("hm_long_watch")), "rift_open completes the long watch")
	d.quests.turn_in(d, "hm_long_watch")
	_check(d.quests.times_done("hm_long_watch") == 1, "long watch paid")


## The whole story chain played with real travel and real hunts at the chain's earliest generation.
func _test_rift_chain_played() -> void:
	var chain: Array = GameData.quests.filter(func(q): return q.get("chain", "") == "rift")
	var start := 999
	var top_level := 1
	for q in chain:
		start = mini(start, int(q["requires"]["min_gen"]))
		top_level = maxi(top_level, int(q["requires"]["min_level"]))
	var d := _fresh(start, top_level, "kingshold")
	d.heir.gold = 100000
	var qs := d.quests
	var order := ["rift_1_sealed_road", "rift_2_drowned_rite", "rift_3_warden_key", "rift_4_break_the_seal"]
	for id in order:
		var q := _q(id)
		if q.is_empty():
			_check(false, "chain step %s exists" % id)
			return
		_travel_to(d, q["giver"])
		_check(d.world.location == q["giver"], "%s: reached %s" % [id, q["giver"]])
		_check(qs.accept_block(d, id) == "", "%s can be taken at gen %d (%s)" % [id, d.gen, qs.accept_block(d, id)])
		qs.accept(d, id)
		var o: Dictionary = q["objective"]
		if GameQuests.kind(q) == "visit":
			_travel_to(d, o["target"])
		else:
			qs.on_kill(d, GameQuests.targets(q)[0])
			_check(int(qs.entry(id)["progress"]) == 0 or not o.has("place"), "%s: a kill away from %s does not count" % [id, o.get("place", "")])
			_travel_to(d, o.get("place", d.world.location))
			var guard := 0
			while not qs.is_complete(qs.entry(id)) and guard < 100 and d.state == "life":
				guard += 1
				_won_hunt(d)
			_check(qs.is_complete(qs.entry(id)), "%s: real hunts in %s finish it at gen %d (%d hunts)" % [id, o.get("place", "?"), d.gen, guard])
		_check(qs.is_complete(qs.entry(id)), "%s complete" % id)
		_travel_to(d, q["giver"])
		qs.turn_in(d, id)
		_check(qs.times_done(id) == 1, "%s paid" % id)
	_check(d.flags.has("rift_open"), "chain sets rift_open")
	_check("sunblade" in d.heir.inventory, "chain pays the Sunblade")
	_travel_to(d, "highcrag")
	var r := d.travel("the_rift")
	_check(d.world.location == "the_rift", "the heir walks into the Rift (%s)" % str(r))
	d.world.visit("brinehaven")
	var sound := _q("bh_rift_soundings")
	_check(d.quests.postings(d, "brinehaven").has(sound) == (d.gen >= int(sound["requires"]["min_gen"])), "soundings follow the chain")


func _test_scaling() -> void:
	var q := _q("hm_wolf_cull")
	var big := _q("rift_4_break_the_seal")
	var prev_g := 0
	for g in [1, 50, 300, 999]:
		var d := _fresh(g, 1)
		var gold := GameQuests.reward_gold(d, q)
		_check(gold > prev_g, "gold grows with generation (gen %d: %d)" % [g, gold])
		prev_g = gold
		_check(gold == int(round(60.0 * GameData.enemy_scale(g))), "gold = base x enemy_scale at gen %d" % g)
	for lv in [1, 45, 500, 5000, 99999]:
		var d := _fresh(300, lv)
		var xp := GameQuests.reward_xp(d, q)
		var xp_big := GameQuests.reward_xp(d, big)
		_check(xp == int(round(35.0 * GameData.xp_level_scale(lv))), "xp = base x xp_level_scale at level %d" % lv)
		_check(xp > 0 and xp_big > xp, "xp positive at level %d" % lv)
		var levels := float(xp) / float(d.heir.xp_to_next())
		if lv >= 45:
			_check(levels > 0.05 and levels < 3.0, "a bounty is worth a fraction of a level at %d (%.2f)" % [lv, levels])
		var h := GameHeir.new()
		h.level = lv
		var before := h.level
		h.gain_xp(xp)
		_check(h.level - before <= 6, "a bounty never jumps many levels at %d (+%d)" % [lv, h.level - before])


func _test_save_load() -> void:
	var d := _fresh(1, 20)
	var qs := d.quests
	qs.accept(d, "hm_wolf_cull")
	qs.accept(d, "hm_grimfang")
	for i in 3:
		qs.on_kill(d, "wolf")
	d.world.visit("hearthmere")
	var d0 := _fresh(1, 20)
	d0.quests.accept(d0, "hm_mirefen_lantern")
	d0.travel("mirefen")
	d0.travel("hearthmere")
	d0.quests.turn_in(d0, "hm_mirefen_lantern")
	d.quests.record = d0.quests.record.duplicate(true)
	d.quests.done = d0.quests.done.duplicate()
	d.set_flag("test_flag")
	var text := JSON.stringify(d.to_dict())
	var g := GameDynasty.from_dict(JSON.parse_string(text))
	var e := g.quests.entry("hm_wolf_cull")
	_check(not e.is_empty() and e["progress"] is int and int(e["progress"]) == 3, "progress survives as int")
	_check(e.get("gen") is int and e.get("by", "") == d.heir.name, "who and when survive")
	_check(g.quests.is_active("hm_grimfang"), "second quest survives")
	_check(g.quests.times_done("hm_mirefen_lantern") == 1 and g.quests.record["hm_mirefen_lantern"]["gen"] is int, "record survives with ints")
	_check("hm_mirefen_lantern" in g.quests.done, "done list survives")
	_check(g.flags.has("test_flag"), "flags survive")
	_check(JSON.stringify(g.to_dict()["quests"]) == JSON.stringify(d.to_dict()["quests"]), "quest state round-trips exactly")
	_check(not g.quests.is_posted(g, _q("hm_mirefen_lantern")), "loaded record still hides a one-off quest")
	for i in 2:
		g.quests.on_kill(g, "wolf")
	_check(g.quests.is_complete(g.quests.entry("hm_wolf_cull")), "loaded quest can be finished")
	var gold := g.heir.gold
	g.quests.turn_in(g, "hm_wolf_cull")
	_check(g.heir.gold > gold, "loaded quest pays")


func _test_old_saves() -> void:
	var d := _fresh(5, 10)
	var base: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var none := base.duplicate(true)
	none.erase("quests")
	var a := GameDynasty.from_dict(none)
	_check(a != null and a.quests.active.is_empty() and a.quests.done.is_empty(), "save without quests loads")
	_check(not a.quests.postings(a, "hearthmere").is_empty(), "board works after an old load")
	var skel := base.duplicate(true)
	skel["quests"] = {"active": [], "done": []}
	var b := GameDynasty.from_dict(skel)
	_check(b.quests.record.is_empty(), "skeleton quest format loads")
	var partial := base.duplicate(true)
	partial["quests"] = {"active": [{"id": "hm_wolf_cull", "progress": 2.0}, {"id": "removed_quest", "progress": 1}], "done": ["hm_mirefen_lantern"]}
	var c := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(partial)))
	_check(c.quests.active.size() == 1 and c.quests.entry("hm_wolf_cull")["progress"] is int, "old entries load, unknown quests dropped")
	_check(c.quests.times_done("hm_mirefen_lantern") == 1, "done without record counts once")
	_check(not c.quests.is_posted(c, _q("hm_mirefen_lantern")), "old done list still hides one-offs")
	_check(BoardPanel.summary_lines(c).size() == 1, "summary works on an old save")
	var empty := GameQuests.from_dict({})
	_check(empty.active.is_empty() and empty.total_done() == 0, "empty dict loads")


func _test_succession() -> void:
	var d := _fresh(1, 20)
	d.quests.accept(d, "hm_wolf_cull")
	d.quests.on_kill(d, "wolf")
	d.quests.on_kill(d, "wolf")
	d.quests.accept(d, "hm_grimfang")
	d.quests.on_kill(d, "grimfang")
	var name_before := d.heir.name
	d._die("old age")
	d.choose_heir(0)
	_check(d.heir.name != name_before or d.gen == 2, "a new heir takes over")
	_check(d.quests.is_active("hm_wolf_cull") and int(d.quests.entry("hm_wolf_cull")["progress"]) == 2, "unfinished quest and progress carry over")
	_check(d.quests.is_complete(d.quests.entry("hm_grimfang")), "finished quest waits for the next heir to claim")
	_check(_journal_has(d, "inherits the house's obligations"), "succession journal line")
	d.heir.lifespan = 100000.0
	var gold := d.heir.gold
	d.quests.turn_in(d, "hm_grimfang")
	_check(d.heir.gold > gold, "next heir can claim an inherited reward")
	# A bounty whose quarry dies out lapses at succession; a finished one never does.
	var q := _q("hm_wolf_cull")
	var wolf_end := int(_creature("wolf")["max_gen"])
	var d2 := _fresh(wolf_end, 5)
	d2.quests.active.append({"id": "hm_wolf_cull", "progress": 1, "gen": wolf_end, "by": "x"})
	d2.quests.active.append({"id": "if_goblin_ears", "progress": 1, "gen": wolf_end, "by": "x"})
	d2._die("old age")
	d2.choose_heir(0)
	_check(not d2.quests.is_active("hm_wolf_cull"), "wolf bounty lapses once wolves are gone (gen %d)" % d2.gen)
	_check(d2.quests.is_active("if_goblin_ears"), "goblin bounty still open while goblins roam")
	_check(_journal_has(d2, "rotted"), "lapsed notice journaled")
	var d3 := _fresh(wolf_end, 5)
	d3.quests.active.append({"id": "hm_wolf_cull", "progress": GameQuests.goal(q), "gen": wolf_end, "by": "x"})
	d3._die("old age")
	d3.choose_heir(0)
	_check(d3.quests.is_active("hm_wolf_cull"), "a finished bounty is kept for its reward")


func _test_empty_data() -> void:
	var saved: Array = GameData.quests
	GameData.quests = []
	var d := _fresh(1, 10)
	_check(d.quests.postings(d, "hearthmere").is_empty(), "no quests, no postings")
	_check(BoardPanel.summary_lines(d).is_empty(), "no quests, no summary")
	GameQuests.bot_tick(d)
	_check(d.quests.active.is_empty(), "bot copes with no quests")
	_check(GameQuests.def("hm_wolf_cull").is_empty(), "def on empty data")
	var p = BoardPanel.new()
	p.dynasty = d
	root.add_child(p)
	_check(p.body != null and p.body.get_child_count() > 0, "board builds with no quests")
	p.free()
	GameData.quests = saved


func _buttons(n: Node, text: String) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text == text:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c, text))
	return out


func _test_board_ui() -> void:
	var d := _fresh(30, 20)
	var changed := [0]
	var p = BoardPanel.new()
	p.dynasty = d
	p.on_change = func(): changed[0] += 1
	root.add_child(p)
	var accepts := _buttons(p, "Accept")
	_check(not accepts.is_empty(), "board shows Accept buttons")
	var enabled: Array = accepts.filter(func(b): return not b.disabled)
	if not enabled.is_empty():
		enabled[0].pressed.emit()
	_check(d.quests.active.size() == 1 and changed[0] == 1, "Accept takes the quest and refreshes the life screen")
	var id: String = d.quests.active[0]["id"]
	var q := _q(id)
	for i in GameQuests.goal(q):
		if GameQuests.kind(q) == "kill":
			d.quests.on_kill(d, GameQuests.targets(q)[0])
	if GameQuests.kind(q) == "visit":
		d.quests.on_arrive(d, q["objective"]["target"])
	p._build([])
	var turn := _buttons(p, "Turn in")
	_check(turn.size() == 1 and not turn[0].disabled, "finished quest shows Turn in")
	turn[0].pressed.emit()
	_check(d.quests.times_done(id) == 1 and d.quests.active.is_empty(), "Turn in pays from the board")
	_check(_buttons(p, "Turn in").is_empty(), "board rebuilt after turn-in")
	enabled = _buttons(p, "Accept").filter(func(b): return not b.disabled)
	enabled[0].pressed.emit()
	_buttons(p, "Abandon")[0].pressed.emit()
	_check(d.quests.active.size() == 1, "first Abandon click only asks")
	_buttons(p, "Keep it")[0].pressed.emit()
	_check(d.quests.active.size() == 1 and _buttons(p, "Really abandon").is_empty(), "Keep it cancels the abandon")
	_buttons(p, "Abandon")[0].pressed.emit()
	_buttons(p, "Really abandon")[0].pressed.emit()
	_check(d.quests.active.is_empty(), "second click abandons")
	p.free()
	# summary lines for each kind of objective
	var s := _fresh(400, 99, "hearthmere")
	s.set_flag("rift_seal_seen")
	s.quests.accept(s, "hm_long_watch")
	s.quests.active.append({"id": "hm_mirefen_lantern", "progress": 0, "gen": 400, "by": "x"})
	s.quests.active.append({"id": "hm_glade_wraiths", "progress": 1, "gen": 400, "by": "x"})
	s.quests.active.append({"id": "bh_wreckers", "progress": 5, "gen": 400, "by": "x"})
	var lines := BoardPanel.summary_lines(s)
	_check(lines.size() == 4, "one summary line per obligation")
	for l in lines:
		_check(str(l).length() <= 70, "summary line fits the side panel: %s" % l)
	_check(str(lines).find("1/4") >= 0 and str(lines).find("Mirefen") >= 0 and str(lines).find("report") >= 0, "summary shows progress, places and claims")


## Autopilot: takes doable notices, finishes and claims them, and is deterministic.
func _test_bot() -> void:
	var runs: Array = []
	for r in 2:
		var d := GameDynasty.new_game(777, "Bot", "warrior", GameData.traits_in(["bloodline"])[0], "human")
		for life in 4:
			GameBot.live_life(d)
			if d.state != "succession":
				break
			d.choose_heir(0)
		runs.append(d)
	var a: GameDynasty = runs[0]
	_check(a.quests.total_done() >= 2, "bot completes quests over 4 lives (%d)" % a.quests.total_done())
	_check(JSON.stringify(a.to_dict()) == JSON.stringify(runs[1].to_dict()), "same seed, same dynasty (quests add no randomness)")
	var d := _fresh(1, 1)
	d.quests.accept(d, "hm_wolf_cull")
	for i in 5:
		d.quests.on_kill(d, "wolf")
	GameQuests.bot_tick(d)
	_check(d.quests.times_done("hm_wolf_cull") == 1, "bot turns in a finished quest at its board")
	_check(d.quests.is_active("hm_wolf_cull") == false or d.quests.entry("hm_wolf_cull")["progress"] == 0, "bot may take the bounty again only fresh")
	# The bot never throws away a finished quest from another town to make room.
	var f := _fresh(40, 60, "kingshold")
	f.quests.active.append({"id": "if_goblin_ears", "progress": 6, "gen": 40, "by": "x"})
	f.quests.active.append({"id": "bh_wreckers", "progress": 5, "gen": 40, "by": "x"})
	f.quests.active.append({"id": "hm_wolf_cull", "progress": 5, "gen": 40, "by": "x"})
	f.quests.active.append({"id": "hm_causeway_trolls", "progress": 3, "gen": 40, "by": "x"})
	f.world.visit("hollow_barrow")
	f.world.visit("kingshold")
	GameQuests.bot_tick(f)
	for id in ["if_goblin_ears", "bh_wreckers", "hm_wolf_cull", "hm_causeway_trolls"]:
		_check(f.quests.is_active(id), "bot keeps finished %s" % id)
	# The bot never walks back to claim, so it only leaves town for the start town's notices.
	var v := _fresh(130, 60, "brinehaven")
	GameQuests.bot_tick(v)
	_check(not v.quests.is_active("bh_vaerthax"), "bot does not take a lair hunt it could never hand in")
	var g := _fresh(1, 20, "hearthmere")
	GameQuests.bot_tick(g)
	_check(g.quests.is_active("hm_grimfang"), "bot takes the start town's legend bounty")
	# A full log of finished notices from far towns gives way to work it can do here.
	var w := _fresh(40, 30, "ironford")
	w.slain_bosses["grimfang"] = 1
	w.slain_bosses["hollow_king"] = 1
	for id in ["bh_wreckers", "ks_barrow_dead", "hm_wolf_cull", "hm_causeway_trolls"]:
		w.quests.active.append({"id": id, "progress": GameQuests.goal(_q(id)), "gen": 40, "by": "x"})
	GameQuests.bot_tick(w)
	_check(w.quests.is_active("if_goblin_ears"), "bot makes room for a local bounty")
	_check(w.quests.is_active("hm_wolf_cull") and w.quests.is_active("hm_causeway_trolls"), "bot keeps finished start-town quests for the next heir")
	_check(w.quests.active.size() == int(GameData.bal("quest_max_active")), "log stays within the limit")
	# Over many lives the bot's log does not silt up with rewards it cannot claim.
	var s := GameDynasty.new_game(9295, "Bot", "warrior", GameData.traits_in(["bloodline"])[0], "human")
	s.gen = 295
	s.heir.gen = 295
	for life in 8:
		GameBot.live_life(s)
		if s.state != "succession":
			break
		s.choose_heir(0)
	var stuck: Array = s.quests.active.filter(func(e): return s.quests.is_complete(e) and GameQuests.def(e["id"])["giver"] != GameData.world["start"])
	_check(stuck.is_empty(), "no unclaimable finished quests left on the bot's log (%s)" % str(stuck))
