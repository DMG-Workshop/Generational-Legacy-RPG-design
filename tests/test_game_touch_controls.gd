## The fingers on the sandbox screen (ui/play/touch_controls.gd): a finger landing in the left part of the view becomes the
## stick, drawn where it landed, and pushes by how far it has moved (nothing inside the dead zone, a full push at the
## radius, never more); fingers elsewhere, or a second finger, are spares; two spares pinch the zoom within its limits; a
## released finger is forgotten and its index can be used again; and the data the stick needs is valid.
## Run: godot --headless --path . -s res://tests/test_game_touch_controls.gd
extends SceneTree

const TouchControls := preload("res://ui/play/touch_controls.gd")
const WorldInput := preload("res://ui/play/world_input.gd")

var fails := 0
var checks := 0
var area := Vector2(800, 600)


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
	test_stick()
	test_spares()
	test_pinch()
	print("touch controls tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	var share := WorldInput.setting("stick_zone_share")
	ok(share > 0.0 and share < 1.0, "the stick zone is part of the view, not none or all of it")
	ok(WorldInput.validate().is_empty(), "the input data is valid (%s)" % str(WorldInput.validate()))


func test_stick() -> void:
	var t := TouchControls.new()
	ok(not t.steering() and t.move() == Vector2.ZERO, "no finger, no push")
	t.touch(0, Vector2(100, 300), true, area)
	ok(t.steering() and t.origin == Vector2(100, 300), "a finger in the left part steers, from where it landed")
	ok(t.move() == Vector2.ZERO, "a finger that has not moved pushes nothing")
	var radius := WorldInput.setting("touch_stick_radius_px")
	t.drag(0, Vector2(100 + radius, 300))
	ok(t.move().x > 0.99 and absf(t.move().y) < 0.01, "a finger a radius to the right is a full push to the right")
	t.drag(0, Vector2(100 + radius * 0.5, 300))
	ok(t.move().x > 0.0 and t.move().x < 1.0, "half a radius is a push between none and full")
	t.drag(0, Vector2(100 + radius * 0.05, 300))
	ok(t.move() == Vector2.ZERO, "a finger inside the dead zone pushes nothing")
	t.drag(0, Vector2(100 + radius * 6.0, 300))
	ok(t.move().length() <= 1.0001, "a finger far beyond the radius is never more than a full push")
	ok(t.knob().distance_to(t.origin) <= radius + 0.001, "the knob stays within the stick's radius")
	t.drag(0, Vector2(100, 300 - radius))
	ok(t.move().y < -0.99, "a finger a radius up is a full push up")
	t.touch(0, Vector2(100, 300), false, area)
	ok(not t.steering() and t.move() == Vector2.ZERO, "lifting the finger stops the push")
	t.touch(0, Vector2(120, 320), true, area)
	ok(t.steering() and t.origin == Vector2(120, 320), "the same finger index can steer again")


func test_spares() -> void:
	var t := TouchControls.new()
	t.touch(3, Vector2(700, 300), true, area)
	ok(not t.steering() and t.fingers() == 1, "a first finger on the right is a spare, not the stick")
	t.touch(0, Vector2(100, 300), true, area)
	ok(t.steering() and t.fingers() == 2, "a finger on the left still steers with a spare down")
	t.touch(1, Vector2(150, 350), true, area)
	ok(t.stick == 0 and t.fingers() == 3, "a second finger on the left does not take the stick over")
	t.touch(0, Vector2(100, 300), false, area)
	ok(not t.steering() and t.fingers() == 2, "lifting the steering finger leaves the spares")
	t.touch(3, Vector2(700, 300), false, area)
	t.touch(1, Vector2(150, 350), false, area)
	ok(t.fingers() == 0, "every finger lifted leaves none")
	t.drag(9, Vector2(5, 5))
	ok(t.fingers() == 0, "a drag from an unknown finger changes nothing")


func test_pinch() -> void:
	var t := TouchControls.new()
	ok(t.pinch(1.0) == 1.0, "no fingers, no pinch")
	t.touch(1, Vector2(500, 300), true, area)
	ok(t.pinch(1.0) == 1.0, "one spare finger does not pinch")
	t.touch(2, Vector2(600, 300), true, area)
	ok(is_equal_approx(t.pinch(1.0), 1.0), "two fingers just down have not moved apart yet")
	t.drag(2, Vector2(700, 300))
	var wider := t.pinch(1.0)
	ok(wider > 1.0, "fingers moving apart zoom in")
	ok(is_equal_approx(wider, WorldInput.pinch_zoom(1.0, 100.0, 200.0)), "by the amount the data says")
	t.drag(2, Vector2(520, 300))
	ok(t.pinch(1.0) < 1.0, "fingers moving together zoom out")
	t.drag(2, Vector2(5000, 300))
	ok(t.pinch(1.0) <= WorldInput.setting("zoom_max") and t.pinch(1.0) >= WorldInput.setting("zoom_min"), "a pinch never goes past the zoom limits")
	t.touch(2, Vector2(520, 300), false, area)
	ok(t.pinch(1.0) == 1.0, "lifting one finger ends the pinch")
