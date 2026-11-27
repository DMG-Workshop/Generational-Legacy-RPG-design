## What the battle screen shows for the open world's variety and a legend's stage (ui/play/boss_card.gd, BattleView): a legend's title
## card as the fight opens (not for a hunt, not for a fight reloaded mid-way), the legend fought in its lair, the telegraph and
## guard words floated from the events, a foe that joins the fight getting its figure (and taps) as its event plays, a phase,
## an elite named in colour, the legend's fall and the heirloom shown at the head of the result, and nothing of it for a hunt.
## Run: godot --headless --path . -s res://tests/test_game_boss_card.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const DIR := "user://test_boss_card/"

var checks := 0
var fails := 0
var app: Node
var d: GameDynasty
var bv: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	var only: PackedStringArray = []   # -- only=a,b runs just those tests
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	for name in ["legend", "hunt", "join", "victory"]:
		if only.is_empty() or name in only:
			await call("test_" + name)
	print("boss card tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _start(kind: String, foe_ids: Array, variety: bool = true) -> void:
	TouchHint.finger = false
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	d = app.dynasty
	d.pending_event = {}
	d.heir.level = 40
	d.heir.full_heal()
	d.world.visit("kingshold")
	if kind == "legend":
		var c := GameCombat.creature_def(str(foe_ids[0]))
		var foe := d._make_enemy(c, 1.0, 1.0, 25)
		if variety:
			GameVariety.dress_boss(d, foe)
		d._begin_battle([foe], "legend")
		d.battle.variety = variety
	else:
		d.start_encounter(foe_ids, "", 1.0, [20, 20], [[1, 1], [2, 2]])
		if not variety:
			d.battle.variety = false
	d.auto_battle = false
	app.show_state()
	await _frames(5)
	bv = app.current


func _cards(n: Node, out: Array = []) -> Array:
	if n is ColorRect and (n as ColorRect).z_index == 8 and n.get_child_count() > 0 and n.get_child(0) is VBoxContainer:
		out.append(n)
	for c in n.get_children():
		_cards(c, out)
	return out


func _idle() -> void:
	for k in 200:
		if not bv.busy:
			break
		await create_timer(0.1).timeout
	await _frames(3)


func _labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func test_legend() -> void:
	await _start("legend", ["hollow_king"])
	var cards := _cards(bv.arena)
	ok(cards.size() == 1, "a legend's fight opens with its title card")
	var words := _labels(cards[0]) if not cards.is_empty() else []
	ok("Hollow King" in words and "Sovereign of the Barrow" in words, "with its name and epithet: %s" % str(words))
	ok(bv.scenery != null, "and its lair behind it")
	var lair := SceneryArtProbe.lair_texture(d, bv.b)
	ok(lair != null and bv.scenery.texture.atlas == lair, "the lair's scenery, not the town's")
	await create_timer(3.0).timeout
	ok(_cards(bv.arena).is_empty(), "the card goes by itself")
	# a fight reloaded mid-way shows no card
	var again := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_save())))
	ok(again.battle != null and again.battle.resumed, "the fight reloads")


func test_hunt() -> void:
	await _start("hunt", ["wolf", "wolf"], false)
	ok(_cards(bv.arena).is_empty(), "a hunt has no title card")
	await _start("legend", ["grimfang"], false)
	ok(_cards(bv.arena).size() == 1, "a hunt-board legend has the card (it only shows, it changes nothing)")
	ok(not bv.b.variety, "and no phases")


## A foe that calls for help: its figure and its taps appear when the event plays.
func test_join() -> void:
	await _start("hunt", ["wolf"])
	var b: GameBattle = bv.b
	var e: Dictionary = b.enemies[0]
	e["hp"] = 100000
	e["max_hp"] = 100000
	d.heir.hp = 100000
	b.enemies = [b.enemies[0]]
	e.erase("v")
	GameVariety.add_pattern(d, e, "call", GameVariety.keyed(1, "t", 0))
	e["hp"] = 30000
	ok(bv.enemy_nodes.size() == 1, "one figure to begin with")
	var seen_wind := false
	var seen_join := false
	for k in 6:
		await bv._do(func(): b.attack(0))
		await _idle()
		seen_wind = seen_wind or b.log.any(func(l): return str(l).contains("is calling for help"))
		seen_join = seen_join or b.enemies.size() > 1
		if b.enemies.size() > 1:
			break
	ok(seen_wind and seen_join, "the call is announced and answered in the log")
	ok(bv.enemy_nodes.size() == b.enemies.size(), "and the newcomer has its figure on the field (%d, %d)" % [bv.enemy_nodes.size(), b.enemies.size()])
	var second: Dictionary = bv.enemy_nodes[bv.enemy_nodes.size() - 1]
	ok(second["root"].is_inside_tree() and second["body"].mouse_filter == Control.MOUSE_FILTER_STOP, "and can be tapped")
	ok(float(second["hp"].max_value) == float(b.enemies[1]["max_hp"]), "with its own health bar")
	# an elite foe's name is drawn in the accent colour
	await _start("hunt", ["wolf", "wolf"])
	GameVariety._give(d, bv.b.enemies[0], "armoured")
	app.show_state()
	await _frames(5)
	bv = app.current
	var lbl: Label = null
	for en in bv.enemy_nodes:
		for c in en["root"].get_children():
			if c is Label and (c as Label).text.begins_with("Armoured"):
				lbl = c
	ok(lbl != null and lbl.get_theme_color("font_color") == Kit.ACCENT, "an elite's name is in the accent colour")


func test_victory() -> void:
	await _start("legend", ["hollow_king"])
	var b: GameBattle = bv.b
	b.enemies[0]["hp"] = 1
	d.heir.hp = 100000
	await create_timer(3.0).timeout
	for k in 8:
		if bv.result_shown:
			break
		await bv._do(func(): b.attack(0))
		await _idle()
	ok(bv.result_shown and b.result == "victory", "the legend falls")
	await _frames(4)
	var words := _labels(bv.result_overlay)
	ok("Hollow King has fallen!" in words, "the result opens with its fall: %s" % str(words.slice(0, 6)))
	ok(words.any(func(w): return str(w).begins_with("Heirloom claimed: Crown of the Hollow King")), "and the heirloom claimed, large")


class SceneryArtProbe:
	static func lair_texture(dyn: GameDynasty, b: GameBattle) -> Texture2D:
		var SA := load("res://ui/play/scenery_art.gd")
		return SA.texture(GameVariety.arena_place(b), dyn.world.weather_id, str(dyn.world.season().get("id", "")))
