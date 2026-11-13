## The accessibility options (roadmap item 14): the three yes-or-no settings stored in settings.cfg, a
## damaged value reading as off, the colour and contrast variants, reduced motion's time, and the menu's
## Accessibility row.
## godot --headless --path . -s res://tests/test_game_access.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const FigurePose := preload("res://ui/play/figure_pose.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
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

	# The accessible colours reach the places they are drawn, not only the helpers.
	var quiet_off := Kit.quiet_bb("x")
	UiSettings.set_access("colour_blind", false)
	UiSettings.set_access("high_contrast", false)
	ok(quiet_off.find(Kit.DIM.to_html(false)) >= 0, "quiet text is the standard grey with the options off")
	ok(Kit.good_fill(Color("#25452c")) == Color("#25452c") and Kit.good_muted() == Color("#6a8f6a"), "fills and muted text keep the standard colours with the options off")
	UiSettings.set_access("high_contrast", true)
	ok(Kit.quiet_bb("x").find(Kit.DIM_HC.to_html(false)) >= 0, "high contrast reaches quiet text built as BBCode")
	UiSettings.set_access("high_contrast", false)
	UiSettings.set_access("colour_blind", true)
	ok(Kit.good_fill(Color("#25452c")) != Color("#25452c") and Kit.bad_fill(Color("#33202a")) != Color("#33202a"), "good and bad fills change with colour-blind colours")
	ok(Kit.good_muted() != Color("#6a8f6a"), "the muted good text changes with colour-blind colours")

	# The life screen's journal: victories and deaths take the palette's colours.
	var life: Control = LifeScreen.new()
	var win: String = life._colorize("Victory over the wolves")
	var dies: String = life._colorize("Tess dies of old age")
	ok(win.find(Kit.GOOD_CB.to_html(false)) >= 0 and win.find("6fcf6f") < 0, "a victory line is blue with colour-blind colours, not green")
	ok(dies.find(Kit.BAD_CB.to_html(false)) >= 0 and dies.find("e0605a") < 0, "a death line is orange with colour-blind colours, not red")
	UiSettings.set_access("colour_blind", false)
	ok(life._colorize("Victory over the wolves").find("6fcf6f") >= 0, "and the standard green and red with the options off")
	life.free()

	# The chronicle's quiet text follows high contrast on its Statistics tab.
	var cd := GameDynasty.new_game(64, "Tess", "warrior", "faetouched", "human")
	cd.pending_event = {}
	var panel: Control = ChroniclePanel.new()
	panel.dynasty = cd
	root.add_child(panel)
	await _frames(2)
	ok(_tab_text(panel, "Statistics").find("8d88a0") >= 0, "the Statistics tab uses the standard quiet grey with the options off")
	UiSettings.set_access("high_contrast", true)
	panel.queue_free()
	await _frames(2)
	panel = ChroniclePanel.new()
	panel.dynasty = cd
	root.add_child(panel)
	await _frames(2)
	ok(_tab_text(panel, "Statistics").find("8d88a0") < 0 and _tab_text(panel, "Statistics").find(Kit.DIM_HC.to_html(false)) >= 0, "high contrast brightens the Statistics tab's quiet text")
	panel.queue_free()
	UiSettings.set_access("high_contrast", false)
	UiSettings.set_access("colour_blind", false)

	# Reduced motion: a figure's move does not move it at all; without it, the move does.
	var tex := ImageTexture.create_from_image(Image.create(96, 160, false, Image.FORMAT_RGBA8))
	var pose: Control = FigurePose.new()
	root.add_child(pose)
	pose.setup(tex, Vector2(120, 200), 1.0, 0.0)
	# The move is sampled while it runs (it is back at its place by the end either way).
	UiSettings.set_access("reduced_motion", true)
	pose.play("attack")
	var moved_reduced := false
	for i in 15:
		await process_frame
		moved_reduced = moved_reduced or pose.position != Vector2.ZERO
	ok(not moved_reduced and pose.last == "attack", "reduced motion: a fight move is recorded but the figure never leaves its place")
	await _frames(40)
	UiSettings.set_access("reduced_motion", false)
	pose.play("attack")
	var moved_full := false
	for i in 15:
		await process_frame
		moved_full = moved_full or pose.position != Vector2.ZERO
	ok(moved_full, "without reduced motion the same move moves the figure")
	await _frames(40)
	pose.queue_free()

	DirAccess.remove_absolute(UiSettings.path)
	print("access tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _tab_text(panel: Node, tab: String) -> String:
	for c in _all(panel):
		if c is RichTextLabel and c.name == tab:
			return (c as RichTextLabel).text
	return ""


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _has_label(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_label(c, text):
			return true
	return false
