## What an heirloom does besides give power (roadmap follow-up to item 18): each of the five legends' heirlooms gives its own small
## effect (`effects` in heirlooms.json) that grows with each level it is reworked: more gold or XP from hunts, better shop prices,
## fewer raids on the house. Only the first `heirloom_max` count; with none the numbers are exactly what they were; no dice; the
## heirloom panel names the effect; the data is checked.
## Run: godot --headless --path . -s res://tests/test_game_heirloom_effects.gd
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
	test_effect()
	test_hunt()
	test_prices_and_raids()
	await test_panel()
	print("heirloom effect tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _loom(name: String, level: int = 0) -> Dictionary:
	var h := {"name": name, "boss": "x", "gen": 1}
	if level > 0:
		h["level"] = level
	return h


func test_data() -> void:
	ok(GameHeirlooms.validate().is_empty(), "the shipped data passes: %s" % str(GameHeirlooms.validate()))
	var fx: Dictionary = GameHeirlooms.data()["effects"]
	var keep: Variant = fx["Grimfang's Fang"]
	fx["Grimfang's Fang"] = {"hunt_gold": 0.5}
	ok(not GameHeirlooms.validate().is_empty(), "an effect of 50% is caught")
	fx["Grimfang's Fang"] = {"fame": 0.04}
	ok(not GameHeirlooms.validate().is_empty(), "an effect nothing reads is caught")
	fx.erase("Grimfang's Fang")
	ok(not GameHeirlooms.validate().is_empty(), "a legend's heirloom with no effects entry is caught")
	fx["Grimfang's Fang"] = keep
	fx["Nobody's Ring"] = {"hunt_gold": 0.01}
	ok(not GameHeirlooms.validate().is_empty(), "an effect for an heirloom no legend leaves is caught")
	fx.erase("Nobody's Ring")
	ok(GameHeirlooms.validate().is_empty(), "and mending the data clears it")


func test_effect() -> void:
	var fang := _loom("Grimfang's Fang")
	ok(absf(GameHeirlooms.effect_of(fang, "hunt_gold") - 0.04) < 0.0001 and GameHeirlooms.effect_of(fang, "persuasion") == 0.0, "as taken, an heirloom gives its base effect and nothing else")
	var top := _loom("Grimfang's Fang", GameHeirlooms.max_level())
	var want := 0.04 * (1.0 + float(GameHeirlooms.max_level()) * float(GameHeirlooms.setting("effect_per_level")))
	ok(absf(GameHeirlooms.effect_of(top, "hunt_gold") - want) < 0.0001, "reworked to the top it gives more: %.3f" % GameHeirlooms.effect_of(top, "hunt_gold"))
	ok(GameHeirlooms.effect_of(_loom("Unknown Thing"), "hunt_gold") == 0.0 and GameHeirlooms.effect_of("junk", "hunt_gold") == 0.0, "an unknown heirloom and a damaged entry give nothing")
	var d := _fresh()
	ok(GameHeirlooms.effect(d, "hunt_gold") == 0.0, "a house with none adds exactly 0")
	d.heirlooms = [_loom("Grimfang's Fang"), _loom("Shard of the Unmade")]
	ok(absf(GameHeirlooms.effect(d, "hunt_gold") - 0.06) < 0.0001, "two heirlooms add: %.3f" % GameHeirlooms.effect(d, "hunt_gold"))
	var many := _fresh()
	var cap := int(GameData.bal("heirloom_max"))
	for i in cap + 3:
		many.heirlooms.append(_loom("Grimfang's Fang"))
	ok(absf(GameHeirlooms.effect(many, "hunt_gold") - float(cap) * 0.04) < 0.0001, "only the first heirloom_max (%d) of %d count: %.3f" % [cap, many.heirlooms.size(), GameHeirlooms.effect(many, "hunt_gold")])
	var txt := GameHeirlooms.effect_text(fang)
	ok(txt == "Also: +4% gold from hunts." and GameHeirlooms.effect_text(_loom("Unknown Thing")) == "", "the text says what it gives: %s" % txt)


## One win in a fight, as the dynasty's finish_battle pays it: the gold and XP from the same fight with and without the heirloom.
func _won(d: GameDynasty) -> Dictionary:
	var b := d.start_hunt("hunt")
	var xp0 := d.heir.xp
	var gold0 := d.heir.gold
	b.result = "victory"
	for e in b.enemies:
		e["hp"] = 0
	d.finish_battle()
	return {"gold": d.heir.gold - gold0, "xp": d.heir.xp - xp0}


func test_hunt() -> void:
	var plain := _fresh()
	var rich := _fresh()
	rich.heirlooms = [_loom("Grimfang's Fang", GameHeirlooms.max_level()), _loom("Vaerthax's Scale", GameHeirlooms.max_level())]
	var a := _won(plain)
	var b := _won(rich)
	ok(a["gold"] > 0 and b["gold"] > a["gold"], "the Fang pays more from a hunt: %d against %d" % [b["gold"], a["gold"]])
	ok(b["xp"] >= a["xp"], "and the Scale does not pay less XP: %d against %d" % [b["xp"], a["xp"]])
	var xp_only := _fresh()
	xp_only.heirlooms = [_loom("Vaerthax's Scale", GameHeirlooms.max_level())]
	var c := _won(xp_only)
	ok(c["xp"] > a["xp"] or a["xp"] == 0, "the Scale alone adds XP: %d against %d" % [c["xp"], a["xp"]])
	ok(c["gold"] == a["gold"], "and no gold")


func test_prices_and_raids() -> void:
	var d := _fresh()
	var base := GameItems.persuasion(d)
	d.heirlooms = [_loom("Crown of the Hollow King", GameHeirlooms.max_level())]
	ok(GameItems.persuasion(d) > base, "the Crown lowers shop prices (persuasion %.3f)" % GameItems.persuasion(d))
	var p := _fresh()
	p.heir.gold = 5000
	var h := _fresh()
	h.heir.gold = 5000
	h.heirlooms = [_loom("Heart of Stone", GameHeirlooms.max_level())]
	ok(GameRaids.chance(h) < GameRaids.chance(p) and GameRaids.chance(p) > 0.0, "the Heart keeps raiders off: %.4f against %.4f" % [GameRaids.chance(h), GameRaids.chance(p)])
	var rng := h.rng.state
	GameRaids.chance(h)
	GameItems.persuasion(h)
	ok(h.rng.state == rng, "no dice are drawn")


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func test_panel() -> void:
	var d := _fresh()
	d.heirlooms = [_loom("Grimfang's Fang")]
	var panel: Control = load("res://ui/play/heirloom_panel.gd").new()
	panel.dynasty = d
	panel.on_change = func(): pass
	root.add_child(panel)
	await process_frame
	await process_frame
	var found := false
	for l in panel.find_children("*", "Label", true, false):
		if (l as Label).text.contains("gold from hunts"):
			found = true
	ok(found, "the heirloom panel names what it gives")
	panel.queue_free()
	await process_frame
