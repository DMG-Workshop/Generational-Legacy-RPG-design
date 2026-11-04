## The accessibility options (roadmap item 14): the three yes-or-no settings stored in settings.cfg, a
## damaged value reading as off, the colour and contrast variants, reduced motion's time, and the menu's
## Accessibility row.
## godot --headless --path . -s res://tests/test_game_access.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const DIR := "user://test_access/"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	UiSettings.path = DIR + "settings.cfg"
	DirAccess.remove_absolute(UiSettings.path)

	# Off by default: no file, and the standard colours.
	ok(not UiSettings.colour_blind() and not UiSettings.high_contrast() and not UiSettings.reduced_motion(), "all three options are off with no file")
	ok(Kit.good() == Kit.GOOD and Kit.bad() == Kit.BAD and Kit.dim() == Kit.DIM, "the standard colours show when the options are off")
	ok(UiSettings.motion_time(0.4) == 0.4, "motion keeps its time when reduced motion is off")

	# Stored and read back; an unknown key is refused.
	ok(UiSettings.set_access("colour_blind", true), "a known option can be stored")
	ok(UiSettings.colour_blind(), "the stored choice is read back")
	ok(not UiSettings.set_access("moat", true), "an unknown option is refused")
	ok(not UiSettings.access_on("moat"), "and nothing is stored for it")

	# Colour-blind: blue for good, orange for bad, and the two stay apart.
	ok(Kit.good() == Kit.GOOD_CB and Kit.bad() == Kit.BAD_CB, "colour-blind colours replace green and red")
	ok(Kit.good().b > Kit.good().r and Kit.bad().r > Kit.bad().b, "good leans blue and bad leans orange, not green and red")
	ok(Kit.good() != Kit.bad(), "good and bad stay different colours")

	# High contrast: quiet text is brighter.
	UiSettings.set_access("high_contrast", true)
	ok(Kit.dim() == Kit.DIM_HC and _luma(Kit.DIM_HC) > _luma(Kit.DIM), "high contrast brightens quiet text")

	# Reduced motion: animations take no time.
	UiSettings.set_access("reduced_motion", true)
	ok(UiSettings.motion_time(0.4) == 0.0, "reduced motion gives animations no time")
	UiSettings.set_access("reduced_motion", false)
	ok(UiSettings.motion_time(0.4) == 0.4, "turning reduced motion off restores the time")

	# A damaged value reads as off, without a crash.
	var cf := ConfigFile.new()
	cf.set_value("ui", "colour_blind", "yes")
	cf.set_value("ui", "high_contrast", 1)
	cf.save(UiSettings.path)
	ok(not UiSettings.colour_blind() and not UiSettings.high_contrast(), "a damaged value (text, number) reads as off")

	# The menu lists the three options, and choosing one stores it.
	DirAccess.remove_absolute(UiSettings.path)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var app := GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 71, "human", GameSex.MALE)
	app.show_state()
	await _frames(3)
	app.open_menu()
	await _frames(3)
	ok(_has_label(app.current, "Accessibility"), "the menu has an Accessibility heading")
	ok(_has_label(app.current, "Colour-blind colours") and _has_label(app.current, "High contrast") and _has_label(app.current, "Reduced motion"), "the menu lists all three options")
	app.set_access("reduced_motion", true)
	ok(UiSettings.reduced_motion(), "the app stores the reduced motion choice")
	await _frames(2)

	DirAccess.remove_absolute(UiSettings.path)
	print("access tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _has_label(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_label(c, text):
			return true
	return false
