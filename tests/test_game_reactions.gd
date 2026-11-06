## Standing covers (roadmap item 22, the standing-reaction version): a member set to cover another steps in
## front of a foe's blow aimed at them while they are below settings.cover_below of their health, once a
## round, with no dice drawn. Setting, cycling and taking back a cover; the threshold; once a round; a
## fallen coverer; and that a cover which never fires leaves the fight exactly as it was.
## Run: godot --headless --path . -s res://tests/test_game_reactions.gd
extends SceneTree

const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	var chance_was = GameData.balance["companion_heir_target_chance"]
	GameData.balance["companion_heir_target_chance"] = 1.0   # every foe swings at the heir, so the covers can be counted
	test_data()
	test_set_and_cycle()
	test_cover_fires_below_threshold()
	test_not_above_threshold()
	test_fallen_coverer()
	test_unused_cover_changes_nothing()
	GameData.balance["companion_heir_target_chance"] = chance_was
	print("reactions tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- scaffolding (as in test_game_round)

func _dynasty(seed_val: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 30
	d.heir.potions = 0
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	return d


## A party round against three sturdy foes with a weak bite: nobody falls and nobody wins.
func _round(seed_val: int = 77) -> Array:
	var d := _dynasty(seed_val)
	var foes: Array = []
	for i in 3:
		foes.append(d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 4.0
	return [d, d.battle, d.battle_round()]


func _all_attack(r: GameRound) -> void:
	for by in r.members():
		r.queue(by, {"act": "attack", "target": "enemy:0"})


func _hurt_heir(b: GameBattle) -> void:
	b.heir.hp = maxi(1, int(float(b.unit_numbers(-1)["max_hp"]) * 0.2))


func _events(b: GameBattle, type: String) -> Array:
	return b.events.filter(func(e): return str(e.get("type", "")) == type)


# ---------------------------------------------------------------- tests

func test_data() -> void:
	ok(GameRound.validate().is_empty(), "the round settings, cover_below included, are sound: %s" % str(GameRound.validate()))
	var v := float(GameRound.setting("cover_below"))
	ok(v > 0.0 and v <= 1.0, "cover_below is a fraction of health")


func test_set_and_cycle() -> void:
	var t := _round()
	var r: GameRound = t[2]
	ok(r.set_cover(1, "heir") == "" and str(r.covers.get(1)) == "heir", "a companion can cover the heir")
	ok(r.set_cover(1, "ally:1") != "", "no one can cover themselves")
	ok(r.set_cover(1, "enemy:0") != "" and r.set_cover(1, "ally:9") != "", "only a party member still standing can be covered")
	ok(str(r.covers.get(1)) == "heir", "a refused choice leaves the cover as it was")
	var member := {}
	for m in r.view()["members"]:
		if int(m["by"]) == 1:
			member = m
	ok(str(member.get("cover", "")) == "heir", "the round's view shows whom a member covers")
	ok(r.set_cover(1, "") == "" and not r.covers.has(1), "an empty choice takes the cover back")
	# Cycling: none, then each other member in party order, then none again.
	var seen: Array = []
	for i in 5:
		var nxt := r.next_cover(1)
		r.set_cover(1, nxt)
		seen.append(nxt)
	ok(seen == ["heir", "ally:0", "ally:2", "", "heir"], "the Cover button cycles through the others, then none: %s" % str(seen))


func test_cover_fires_below_threshold() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	_hurt_heir(b)
	r.set_cover(1, "heir")
	_all_attack(r)
	r.resolve()
	var covers := _events(b, "cover")
	ok(covers.size() == 1, "a hurt heir is covered once in the round, not by every blow (%d)" % covers.size())
	if covers.size() == 1:
		ok(int(covers[0]["by"]) == 1 and int(covers[0]["for"]) == -1, "Bren steps in front of the heir")
	var on_bren := _events(b, "damage").filter(func(e): return str(e["side"]) == "ally" and int(e.get("ally", -1)) == 1)
	var missed_bren := _events(b, "miss").filter(func(e): return str(e["side"]) == "ally" and int(e.get("ally", -1)) == 1)
	ok(on_bren.size() + missed_bren.size() == 1, "the covered blow lands on (or misses) Bren, not the heir")
	ok(r.covers.get(1) == "heir", "the cover stands for the next round")


func test_not_above_threshold() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	r.set_cover(1, "heir")   # the heir is at full health
	_all_attack(r)
	r.resolve()
	ok(_events(b, "cover").is_empty(), "a healthy member is not covered")


func test_fallen_coverer() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	_hurt_heir(b)
	r.set_cover(1, "heir")
	b.allies[1].hp = 0   # Bren is down before the round plays
	r.begin_round()
	_all_attack(r)
	r.resolve()
	ok(_events(b, "cover").is_empty(), "a fallen member does not step in")


## A cover that never fires draws no dice: the fight is the same as one with no cover at all.
func test_unused_cover_changes_nothing() -> void:
	var a := _round(91)
	var c := _round(91)
	(c[2] as GameRound).set_cover(1, "heir")   # set, but the heir is healthy, so it never fires
	for t in [a, c]:
		_all_attack(t[2])
		(t[2] as GameRound).resolve()
	var la: GameBattle = a[1]
	var lc: GameBattle = c[1]
	ok(la.log == lc.log and la.heir.hp == lc.heir.hp, "an unused cover leaves the fight's log and health unchanged")
