## How crowded the open world is, and what a click does: the creatures the ground holds round the heir are a thin share of what its
## tiles roll (never more than `max_creatures`, none starting within `spawn_safe` of the heir, at most `spawn_burst` more at a refresh, the
## same few on the same ground every time), and the mouse's buttons no longer dig or build, so a click to walk leaves no hole.
## Run: godot --headless --path . -s res://tests/test_game_crowd.gd
extends SceneTree

const WorldInput := preload("res://ui/play/world_input.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

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
	UiSettings.path = "user://test_crowd.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	WorldInput.forget_overrides()
	test_data()
	test_crowd()
	test_clicks()
	DirAccess.remove_absolute(UiSettings.path)
	print("crowd tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(at: Vector2i) -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var sb := GameSandbox.start(d)
	sb.heir = at
	sb.creatures = []
	return sb


func test_data() -> void:
	ok(GameSandbox.validate().is_empty(), "the crowd settings check: %s" % str(GameSandbox.validate()))
	var saved: Variant = GameSandbox.data()["settings"].duplicate()
	GameSandbox.data()["settings"]["spawn_share"] = 0.0
	ok(not GameSandbox.validate().is_empty(), "a share of nothing is refused")
	GameSandbox.data()["settings"]["spawn_share"] = 0.1
	GameSandbox.data()["settings"]["spawn_safe"] = 99.0
	ok(not GameSandbox.validate().is_empty(), "a safe distance past the spawn radius is refused")
	GameSandbox.data()["settings"]["spawn_safe"] = 6
	GameSandbox.data()["settings"]["max_creatures"] = 0
	ok(not GameSandbox.validate().is_empty(), "no room for any creature is refused")
	for k in saved:
		GameSandbox.data()["settings"][k] = saved[k]
	ok(GameSandbox.validate().is_empty(), "and mending the data clears it")


func test_crowd() -> void:
	var maxn := int(GameSandbox.setting("max_creatures"))
	var burst := int(GameSandbox.setting("spawn_burst"))
	var safe := float(GameSandbox.setting("spawn_safe"))
	var worst := 0
	var seen_any := false
	for place in ["hearthmere", "greenvale", "whisperwood", "mirefen", "elderglade"]:
		var a := GameWorldGen.anchor(place)
		for off in [Vector2i(40, 0), Vector2i(0, 60), Vector2i(-70, 30), Vector2i(90, -40)]:
			var at := Vector2i(int(a["x"]) + off.x, int(a["z"]) + off.y)
			var sb := _sandbox(at)
			sb.refresh()
			ok(sb.creatures.size() <= burst, "a first refresh brings in at most %d creatures: %d at %s" % [burst, sb.creatures.size(), str(at)])
			for i in 12:
				var before := sb.creatures.size()
				sb.refresh()
				ok(sb.creatures.size() - before <= burst, "and each refresh after adds at most %d" % burst)
			worst = maxi(worst, sb.creatures.size())
			seen_any = seen_any or sb.creatures.size() > 0
			ok(sb.creatures.size() <= maxn, "never more than %d alive at once: %d" % [maxn, sb.creatures.size()])
			for c in sb.creatures:
				ok(Vector2(float(c["x"]) - float(at.x) - 0.5, float(c["z"]) - float(at.y) - 0.5).length() >= safe - 0.01, "none appears within %s of the heir" % safe)
	ok(seen_any, "the wilds still hold creatures")
	ok(worst <= maxn, "the most seen in any spot is %d" % worst)
	# the same ground holds the same creatures
	var home := GameWorldGen.anchor("whisperwood")
	var at2 := Vector2i(int(home["x"]) + 40, int(home["z"]))
	var one := _sandbox(at2)
	var two := _sandbox(at2)
	for i in 8:
		one.refresh()
		two.refresh()
	var sig_a := one.creatures.map(func(c): return "%s@%s,%s" % [c["id"], c["x"], c["z"]])
	var sig_b := two.creatures.map(func(c): return "%s@%s,%s" % [c["id"], c["x"], c["z"]])
	ok(sig_a == sig_b, "the same ground gives the same creatures")


func test_clicks() -> void:
	WorldInput.install()
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	for action in WorldInput.actions():
		ok(not InputMap.event_is_action(left, str(action)), "the left button is not %s" % str(action))
		ok(not InputMap.event_is_action(right, str(action)), "the right button is not %s" % str(action))
	ok(InputMap.has_action("world_dig") and InputMap.has_action("world_build"), "dig and build are still there for their keys")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	ok(InputMap.event_is_action(wheel, "world_zoom_in"), "the wheel still zooms")
