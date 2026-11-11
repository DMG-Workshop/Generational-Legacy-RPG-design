## Graphics settings (roadmap item 37): the data and ways to break it; the default preset by device; choosing a preset
## and keeping it; a damaged settings file; the battery saver laid over each preset; what reaches the engine (frame
## cap, low-processor mode); weather particles drawn or not, with the rest of the painted scene unchanged; the menu's
## Graphics rows; and that none of it is in the save.
## Run: godot --headless --path . -s res://tests/test_game_graphics.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const GraphicsSettings := preload("res://ui/play/graphics_settings.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const DIR := "user://test_graphics/"

var checks := 0
var fails := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_wipe()
	GameData.load_all()
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	test_data()
	test_presets()
	test_battery_saver()
	test_engine()
	test_particles()
	await test_menu()
	_wipe()
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	SceneryArt.particles_on = true
	print("graphics tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func test_data() -> void:
	ok(GraphicsSettings.validate().is_empty(), "the data is sound: %s" % str(GraphicsSettings.validate()))
	var saved: Dictionary = GraphicsSettings.data().duplicate(true)
	GraphicsSettings.data()["presets"]["high"]["effects"] = "sparkly"
	ok(not GraphicsSettings.validate().is_empty(), "an effects level that does not exist is found")
	GraphicsSettings._cache = saved.duplicate(true)
	GraphicsSettings.data()["default_mobile"] = "ultra"
	ok(not GraphicsSettings.validate().is_empty(), "a default that is not a preset is found")
	GraphicsSettings._cache = saved.duplicate(true)
	GraphicsSettings.data()["order"].erase("medium")
	ok(not GraphicsSettings.validate().is_empty(), "a preset the menu would not offer is found")
	GraphicsSettings._cache = saved.duplicate(true)
	GraphicsSettings.data()["battery_saver"]["fps_cap"] = 0
	ok(not GraphicsSettings.validate().is_empty(), "a battery saver that caps nothing is found")
	GraphicsSettings._cache = saved.duplicate(true)
	GraphicsSettings.data()["presets"]["low"]["fps_cap"] = 5
	ok(not GraphicsSettings.validate().is_empty(), "a frame cap too low to play at is found")
	GraphicsSettings._cache = saved.duplicate(true)
	GraphicsSettings.data()["effect_levels"]["weather_particles"] = "off"
	ok(not GraphicsSettings.validate().is_empty(), "an effect that would always be drawn is found")
	GraphicsSettings._cache = {}
	ok(GraphicsSettings.validate().is_empty(), "(and the data is whole again after)")


func test_presets() -> void:
	ok(GraphicsSettings.ids() == ["low", "medium", "high"], "three presets, lowest first")
	ok(GraphicsSettings.preset() == "high", "a computer starts on High")
	UiSettings.force_mobile = 1
	ok(GraphicsSettings.preset() == "medium", "a phone starts on Medium")
	UiSettings.force_mobile = 0
	ok(GraphicsSettings.set_preset("low") and GraphicsSettings.preset() == "low", "a preset is chosen")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(str(cf.get_value("ui", "graphics", "")) == "low", "and kept in the settings file")
	ok(not GraphicsSettings.set_preset("ultra") and GraphicsSettings.preset() == "low", "an unknown preset is refused")
	for junk in ["ultra", 5, ["low"], "", true]:
		UiSettings.store("graphics", junk)
		ok(GraphicsSettings.preset() == "high", "a damaged choice in the file (%s) falls back to the default" % str(junk))
	var low := GraphicsSettings.preset_def("low")
	var high := GraphicsSettings.preset_def("high")
	ok(int(low["pixel_scale"]) > int(high["pixel_scale"]) and int(low["fps_cap"]) == 30 and int(high["fps_cap"]) == 0, "Low draws fewer pixels at 30 frames; High is sharpest and uncapped")
	GraphicsSettings.set_preset("medium")
	var c := GraphicsSettings.current()
	ok(c["preset"] == "medium" and c["pixel_scale"] == 3 and c["effects"] == "some" and c["fps_cap"] == 60 and c["low_processor"] == false, "what is in force is the preset's own: %s" % str(c))


func test_battery_saver() -> void:
	ok(not GraphicsSettings.battery_saver(), "the battery saver is off to begin with")
	GraphicsSettings.set_battery_saver(true)
	ok(GraphicsSettings.battery_saver(), "and can be switched on")
	for id in GraphicsSettings.ids():
		GraphicsSettings.set_preset(id)
		var c := GraphicsSettings.current()
		ok(c["fps_cap"] == 30 and c["effects"] == "off" and c["low_processor"] == true and c["pixel_scale"] == int(GraphicsSettings.preset_def(id)["pixel_scale"]), "over %s it caps the frames at 30, drops the effects and keeps the preset's pixel scale" % id)
	var saved: Dictionary = GraphicsSettings.data().duplicate(true)
	GraphicsSettings.data()["presets"]["low"]["fps_cap"] = 20
	GraphicsSettings.set_preset("low")
	ok(GraphicsSettings.current()["fps_cap"] == 20, "a preset already under the saver's cap keeps its own")
	GraphicsSettings._cache = {}
	GraphicsSettings.set_battery_saver(false)
	GraphicsSettings.set_preset("high")
	ok(GraphicsSettings.current()["fps_cap"] == 0 and GraphicsSettings.current()["effects"] == "all", "off again, the preset is as it was")
	UiSettings.store("battery_saver", 7)
	ok(not GraphicsSettings.battery_saver(), "a damaged value reads as off")
	UiSettings.store("battery_saver", "off")


func test_engine() -> void:
	GraphicsSettings.set_preset("low")
	GraphicsSettings.apply()
	ok(Engine.max_fps == 30 and not OS.low_processor_usage_mode, "Low reaches the engine as a 30 frame cap")
	GraphicsSettings.set_preset("high")
	GraphicsSettings.apply()
	ok(Engine.max_fps == 0, "High lifts the cap")
	GraphicsSettings.set_battery_saver(true)
	GraphicsSettings.apply()
	ok(Engine.max_fps == 30 and OS.low_processor_usage_mode, "the battery saver caps it and turns on the engine's low-processor mode")
	GraphicsSettings.set_battery_saver(false)
	GraphicsSettings.apply()
	ok(Engine.max_fps == 0 and not OS.low_processor_usage_mode, "and off again restores both")


func _differ(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func test_particles() -> void:
	ok(GraphicsSettings.effect_on("weather_particles"), "High draws the weather's particles")
	ok(not GraphicsSettings.effect_on("no_such_effect"), "an effect nobody listed is not drawn")
	GraphicsSettings.set_preset("medium")
	ok(GraphicsSettings.effect_on("weather_particles"), "so does Medium")
	GraphicsSettings.set_preset("low")
	ok(not GraphicsSettings.effect_on("weather_particles"), "Low does not")
	GraphicsSettings.set_preset("high")
	GraphicsSettings.apply()
	ok(SceneryArt.particles_on, "(the painter is told)")
	# a place and weather whose scene has particles
	var place := ""
	var weather := ""
	for l in GameData.world["locations"]:
		for w in ["snow", "rain", "storm"]:
			SceneryArt.particles_on = true
			var with := SceneryArt.paint(str(l["id"]), w, "winter")
			SceneryArt.particles_on = false
			var without := SceneryArt.paint(str(l["id"]), w, "winter")
			if with != null and without != null and _differ(with, without) > 0 and place == "":
				place = str(l["id"])
				weather = w
		if place != "":
			break
	SceneryArt.particles_on = true
	ok(place != "", "(a fight's scene with weather in the air: %s in %s)" % [place, weather])
	var on_img := SceneryArt.paint(place, weather, "winter")
	SceneryArt.particles_on = false
	var off_img := SceneryArt.paint(place, weather, "winter")
	var changed := _differ(on_img, off_img)
	ok(changed > 0 and changed < on_img.get_width() * on_img.get_height() / 4, "with the particles off only the particles go: %d of %d pixels differ" % [changed, on_img.get_width() * on_img.get_height()])
	SceneryArt.particles_on = true
	ok(_differ(SceneryArt.paint(place, weather, "winter"), on_img) == 0, "and on again the scene is exactly as it was")
	var tex := SceneryArt.texture(place, weather, "winter")
	GraphicsSettings.set_preset("low")
	GraphicsSettings.apply()
	ok(not SceneryArt.particles_on and SceneryArt.texture(place, weather, "winter") != tex, "changing the preset repaints a scene already painted")
	GraphicsSettings.set_preset("high")
	GraphicsSettings.apply()


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	if n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _btn(text: String, n: Node) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _btn(text, c)
		if b != null:
			return b
	return null


func _row_button(n: Node, row_label: String, which: String) -> Button:
	if n is HBoxContainer:
		var named := false
		for c in n.get_children():
			if c is Label and (c as Label).text == row_label:
				named = true
		if named:
			for c in n.get_children():
				if c is Button and (c as Button).text == which:
					return c
	for c in n.get_children():
		var b := _row_button(c, row_label, which)
		if b != null:
			return b
	return null


func _menu() -> Control:
	for c in app.current.get_children():
		if c is MenuPanel and not c.is_queued_for_deletion():
			return c
	return null


func test_menu() -> void:
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	var m: Control = app.open_menu()
	await _frames(3)
	var texts := _texts(m)
	ok(texts.has("Graphics") and texts.has("Low") and texts.has("Medium") and texts.has("High") and texts.has("Battery saver"), "the menu has a Graphics section with the presets and the battery saver")
	ok(_btn("High", m).has_theme_color_override("font_color") and texts.has(str(GraphicsSettings.preset_def("high")["about"])), "High is marked, with what it does under it")
	_btn("Low", m).pressed.emit()
	await _frames(4)
	ok(GraphicsSettings.preset() == "low" and Engine.max_fps == 30, "choosing Low stores it and applies it at once")
	m = _menu()
	ok(m != null and _btn("Low", m).has_theme_color_override("font_color") and _texts(m).has(str(GraphicsSettings.preset_def("low")["about"])), "the menu comes back with Low marked and described")
	_row_button(m, "Battery saver", "On").pressed.emit()
	await _frames(4)
	ok(GraphicsSettings.battery_saver() and OS.low_processor_usage_mode, "the battery saver's On switches it on")
	_row_button(_menu(), "Battery saver", "Off").pressed.emit()
	await _frames(4)
	_btn("High", _menu()).pressed.emit()
	await _frames(4)
	ok(not GraphicsSettings.battery_saver() and GraphicsSettings.preset() == "high" and Engine.max_fps == 0, "and back to High with the saver off")
	app.new_game("Tess", "warrior", "faetouched", 41)
	await _frames(3)
	var save := JSON.stringify(app.dynasty.to_save())
	ok(not save.contains("graphics") and not save.contains("battery"), "none of it is in the save")
	var fresh := GameApp.new()
	GraphicsSettings.set_preset("low")
	Engine.max_fps = 0
	root.add_child(fresh)
	await _frames(3)
	ok(Engine.max_fps == 30, "a game that starts applies the stored preset")
	fresh.queue_free()
	GraphicsSettings.set_preset("high")
	GraphicsSettings.apply()
