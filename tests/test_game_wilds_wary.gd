## A trader wary of an uncleared fight (core/game/game_wilds_trade.gd `wary_of`, the `wary` range of a `merchant` block in data/world/wilds.json, GameWildsSites.use): a
## trader with a landmark that sends a fight close by will not open while it is uncleared, opens once the heir wins there, shuts again when the clearing renews,
## ignores a landmark out of range, a trader with no `wary` is never wary, no die of the dynasty's is drawn, and a break of the rule is caught.
## Run: godot --headless --path . -s res://tests/test_game_wilds_wary.gd
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
	test_wary()
	test_far()
	test_unwary()
	test_breaks()
	print("wilds wary tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


## A trader with a fight-sending landmark in its range, on some seed: [dynasty, trader, guard]; [] when none is found.
func _pair() -> Array:
	for seed_value in range(1, 40):
		var d := _dyn(seed_value)
		for area in ["greenvale", "whisperwood", "mirefen", "elderglade", "frostreach", "highcrag"]:
			var a := GameWorldGen.anchor(area)
			for r in range(0, 100, 6):
				for ang in 12:
					var x := int(a["x"]) + int(round(cos(float(ang) / 12.0 * TAU) * r))
					var z := int(a["z"]) + int(round(sin(float(ang) / 12.0 * TAU) * r))
					for lm in GameWildsSites.within(d, x, z, 12.0):
						if GameWildsTrade.is_trader(lm):
							var g := GameWildsTrade.wary_of(d, lm)
							if not g.is_empty():
								return [d, lm, g]
	return []


func test_data() -> void:
	ok(GameWildsTrade.validate().is_empty(), "the data is sound: %s" % str(GameWildsTrade.validate()))
	ok(not GameWilds.data()["text"]["wary"].is_empty(), "the wary line exists")
	ok(float(GameWilds.data()["landmarks"]["merchant"]["merchant"]["wary"]) > 0.0, "a merchant is wary by its data")


func test_wary() -> void:
	var p := _pair()
	ok(p.size() == 3, "a trader beside a fight-sending landmark exists on some seed")
	if p.size() != 3:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	var g: Dictionary = p[2]
	var st := d.rng.state
	var r := GameWildsSites.use(d, lm)
	ok(not bool(r["ok"]) and str(r.get("wary", "")) == str(g["id"]) and not r.has("open"), "an uncleared guard shuts the trader: %s" % str(r.get("text", "")))
	ok(str(r["text"]).contains(GameWildsSites.name_of(g).to_lower()), "and the line names it: %s" % r["text"])
	ok(d.rng.state == st, "no die of the dynasty's drawn")
	ok(not d.wilds.has("used"), "nothing is used up")
	# every uncleared guard near must be won before it opens
	var all_guards := GameWildsSites.within(d, float(lm["x"]) + 0.5, float(lm["z"]) + 0.5, float(GameWildsTrade.def_of(lm)["wary"])).filter(func(o): return str(o["id"]) != str(lm["id"]) and not GameWildsFights.block(o).is_empty())
	for o in all_guards:
		GameWildsFights.won(d, o)
	ok(GameWildsTrade.wary_of(d, lm).is_empty(), "won at each, the wagon is open")
	var r2 := GameWildsSites.use(d, lm)
	ok(bool(r2["ok"]) and str(r2.get("open", "")) == "merchant", "and Use opens the panel")
	# the clearing runs out
	d.gen += int(GameWilds.setting("renew_gens"))
	ok(not GameWildsTrade.wary_of(d, lm).is_empty(), "when the clearing renews the trader is wary again")
	# saved marks do not change with the tie: it is a function of the fights' marks
	var d2 := GameDynasty.from_dict(d.to_dict())
	ok(GameWildsTrade.wary_of(d2, lm) == GameWildsTrade.wary_of(d, lm), "the same after a save and load")


func test_far() -> void:
	var p := _pair()
	if p.size() != 3:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	var g: Dictionary = p[2]
	var dist := Vector2(float(lm["x"]) - float(g["x"]), float(lm["z"]) - float(g["z"])).length()
	ok(dist <= float(GameWildsTrade.def_of(lm)["wary"]) + 1.0, "the guard is within range: %.1f" % dist)
	GameWildsFights.won(d, g)
	# any other guard within range still holds the trader; if none remain it is open
	var others := GameWildsSites.within(d, float(lm["x"]) + 0.5, float(lm["z"]) + 0.5, float(GameWildsTrade.def_of(lm)["wary"])).filter(func(o): return str(o["id"]) != str(lm["id"]) and not GameWildsFights.block(o).is_empty() and not GameWildsFights.cleared(d, str(o["id"])))
	ok(GameWildsTrade.wary_of(d, lm).is_empty() == others.is_empty(), "only a guard within range makes it wary")


func test_unwary() -> void:
	var p := _pair()
	if p.size() != 3:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	ok(GameWildsTrade.wary_of(d, {}).is_empty(), "no landmark, not wary")
	var shrine := {"kind": "shrine", "id": "0:0", "x": 0, "z": 0}
	ok(GameWildsTrade.wary_of(d, shrine).is_empty(), "a landmark that is not a trader is never wary")
	var data: Dictionary = GameWilds.data()
	var md: Dictionary = data["landmarks"][str(lm["kind"])]["merchant"]
	var was: float = md["wary"]
	md["wary"] = 0.0
	ok(GameWildsTrade.wary_of(d, lm).is_empty(), "a trader with no wary range deals as it did")
	md["wary"] = was


func test_breaks() -> void:
	var data: Dictionary = GameWilds.data()
	var md: Dictionary = data["landmarks"]["merchant"]["merchant"]
	var was: float = md["wary"]
	md["wary"] = 99.0
	ok(not GameWildsTrade.validate().is_empty(), "a wary range of 99 is caught")
	md["wary"] = was
	var line: String = data["text"]["wary"]
	data["text"].erase("wary")
	ok(not GameWildsTrade.validate().is_empty(), "a missing wary line is caught")
	data["text"]["wary"] = line
	ok(GameWildsTrade.validate().is_empty(), "restored, sound again")
