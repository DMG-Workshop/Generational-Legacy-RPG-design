## Battle figures' poses (ui/play/figure_pose.gd): every figure drawn from a sprite stands in a pose holder
## that breathes, out of step with its neighbours, and plays the battle's events as moves: the attacker's hop
## and the target's flinch on a blow, a step back on a miss, a cast in its colour, a guard, a companion
## falling when knocked out, the hero falling when beaten, and a slain foe toppling. A figure still drawn as
## a block takes the events without a pose. Reduced motion stops the breathing and the moves but still shows
## a fall, at once, and none of it draws the dynasty's dice.
## Run: godot --headless --path . -s res://tests/test_game_poses.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]
const DIR := "user://test_poses/"

var fails := 0
var checks := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", false)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	var bv := await _fight(d)
	var dice := d.rng.state
	test_poses(bv)
	await test_breathing(bv)
	await test_moves(bv)
	await test_falls(bv)
	ok(d.rng.state == dice, "no pose or move draws the dynasty's dice")
	UiSettings.set_access("reduced_motion", true)
	bv = await _fight(d)
	await test_reduced_motion(bv)
	UiSettings.set_access("reduced_motion", false)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("poses tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## A fight with the trio against a wolf, a slime, a goblin and a creature without art, shown on the screen.
func _fight(d: GameDynasty) -> Control:
	var foes: Array = []
	for id in ["wolf", "slime", "goblin"]:
		foes.append(d._make_enemy(GameCombat.creature_def(id), 1.0, 1.0, 10))
	var unknown: Dictionary = GameCombat.creature_def("goblin").duplicate(true)
	unknown["id"] = "no_such_beast"
	foes.append(d._make_enemy(unknown, 1.0, 1.0, 10))
	d._begin_battle(foes, "hunt")
	d.auto_battle = false
	app.show_state()
	await _frames(5)
	return app.current


func _poses(bv: Control) -> Array:
	var out: Array = [bv.hero_pose]
	for a in bv.ally_nodes:
		out.append(a["pose"])
	for e in bv.enemy_nodes:
		out.append(e["pose"])
	return out


# ---------------------------------------------------------------- standing

func test_poses(bv: Control) -> void:
	ok(bv.hero_pose != null and bv.hero_pose.sprite.texture != null, "the hero stands in a pose holder")
	var allies: int = bv.ally_nodes.filter(func(a): return a["pose"] != null).size()
	ok(allies == bv.ally_nodes.size() and allies == 3, "and so does each companion")
	ok(bv.enemy_nodes[0]["pose"] != null and bv.enemy_nodes[2]["pose"] != null, "and each foe with art")
	ok(bv.enemy_nodes[3]["pose"] == null, "a creature still drawn as a block has none")
	ok(bv.hero_pose.facing > 0.0 and bv.enemy_nodes[0]["pose"].facing < 0.0, "the party faces right and the foes face left")
	ok(bv.hero_pose.size == bv.hero_node.get_child(0).size and bv.hero_pose.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the holder fills the body and leaves its taps to it")


func test_breathing(bv: Control) -> void:
	var standing: Array = _poses(bv).filter(func(p): return p != null)
	ok(standing.all(func(p): return p.breathing()), "every standing figure breathes")
	var beats := {}
	for p in standing:
		beats[p.beat] = true
	ok(beats.size() >= 3, "out of step with each other: %d beats among %d figures" % [beats.size(), standing.size()])
	var seen := {}
	var sprite: TextureRect = bv.hero_pose.sprite
	for i in 24:
		seen[sprite.position.y] = true
		await _wait(0.08)
	ok(seen.size() == 2, "a breath is a bob between two places: %s" % str(seen.keys()))
	ok(is_equal_approx(absf(seen.keys()[0] - seen.keys()[1]) if seen.size() == 2 else 0.0, bv.hero_pose.px), "one pixel of the art apart")


# ---------------------------------------------------------------- moves

func _play(bv: Control, ev: Dictionary) -> void:
	bv._play_one(ev)


func test_moves(bv: Control) -> void:
	var hero: Control = bv.hero_pose
	var wolf: Control = bv.enemy_nodes[0]["pose"]
	_play(bv, {"type": "damage", "side": "enemy", "index": 0, "by": -1, "amount": 1, "crit": false})
	ok(hero.last == "attack" and wolf.last == "hurt", "a blow: the hero attacks and the wolf flinches")
	await _frames(2)
	ok(hero.position.x > 0.0 and wolf.position.x > 0.0, "the hero hops toward the foes and the wolf is knocked back, away from them: %s %s" % [str(hero.position), str(wolf.position)])
	var steps: Vector2 = wolf.position / wolf.px
	ok(is_equal_approx(steps.x, roundf(steps.x)) and is_equal_approx(steps.y, roundf(steps.y)), "a move jumps in whole art pixels, never between them: %s" % str(steps))
	await _wait(0.5)
	ok(hero.position == Vector2.ZERO and wolf.position == Vector2.ZERO, "both settle back where they stood")
	var bren: Control = bv.ally_nodes[1]["pose"]
	var slime: Control = bv.enemy_nodes[1]["pose"]
	_play(bv, {"type": "damage", "side": "ally", "index": 1, "ally": 1, "amount": 1, "crit": false})
	ok(slime.last == "attack" and bren.last == "hurt", "a foe's blow: the slime attacks and the companion flinches")
	await _frames(2)
	ok(slime.position.x < 0.0 and bren.position.x < 0.0, "the slime hops toward the party, the companion is knocked back")
	_play(bv, {"type": "damage", "side": "heir", "index": 2, "amount": 1, "crit": false})
	ok(hero.last == "hurt" and bv.enemy_nodes[2]["pose"].last == "attack", "a blow on the hero")
	_play(bv, {"type": "miss", "side": "heir", "index": 0})
	ok(hero.last == "dodge", "a miss on the hero is a step back")
	_play(bv, {"type": "miss", "side": "enemy", "index": 2, "by": 0})
	ok(bv.enemy_nodes[2]["pose"].last == "dodge" and bv.ally_nodes[0]["pose"].last == "attack", "and a foe's dodge too")
	_play(bv, {"type": "cast", "by": -1, "name": "Fireball", "element": "fire", "targets": []})
	ok(hero.last == "cast", "a cast")
	await _frames(1)
	ok(hero.sprite.modulate != Color.WHITE, "lit in the spell's colour")
	await _wait(0.5)
	ok(hero.sprite.modulate.is_equal_approx(Color.WHITE), "which fades")
	_play(bv, {"type": "defend", "by": 2})
	ok(bv.ally_nodes[2]["pose"].last == "guard", "a guard")
	_play(bv, {"type": "damage", "side": "enemy", "index": 3, "by": -1, "amount": 1, "crit": false})
	ok(hero.last == "attack", "a blow on a creature drawn as a block plays without a pose")
	await _wait(0.6)


# ---------------------------------------------------------------- falls

func test_falls(bv: Control) -> void:
	var tarsk: Control = bv.ally_nodes[2]["pose"]
	_play(bv, {"type": "ko", "ally": 2, "foe_scale": 1.0})
	ok(tarsk.lying and not tarsk.breathing(), "a companion knocked out falls and stops breathing")
	await _wait(0.4)
	ok(is_equal_approx(tarsk.rotation, -PI * 0.5), "lying with the head toward their back: %f" % tarsk.rotation)
	tarsk.play("attack")
	ok(tarsk.last == "fall" and tarsk.position == Vector2.ZERO, "a fallen figure plays no more moves")
	var goblin: Control = bv.enemy_nodes[2]["pose"]
	_play(bv, {"type": "death", "index": 2})
	await _wait(0.4)
	ok(goblin.lying and is_equal_approx(goblin.rotation, PI * 0.5), "a slain foe topples the other way: %f" % goblin.rotation)
	bv._step_heir_hp(-bv.hero_hp.max_value)
	await _wait(0.4)
	ok(bv.hero_pose.lying and is_equal_approx(bv.hero_pose.rotation, -PI * 0.5), "the hero falls when beaten")


# ---------------------------------------------------------------- reduced motion

func test_reduced_motion(bv: Control) -> void:
	var standing: Array = _poses(bv).filter(func(p): return p != null)
	ok(standing.all(func(p): return not p.breathing()), "with reduced motion nobody breathes")
	var hero: Control = bv.hero_pose
	_play(bv, {"type": "damage", "side": "enemy", "index": 0, "by": -1, "amount": 1, "crit": false})
	await _frames(2)
	ok(hero.last == "attack" and hero.position == Vector2.ZERO and bv.enemy_nodes[0]["pose"].position == Vector2.ZERO, "and the moves stay still")
	_play(bv, {"type": "ko", "ally": 0, "foe_scale": 1.0})
	ok(is_equal_approx(bv.ally_nodes[0]["pose"].rotation, -PI * 0.5), "but a fall shows at once")
