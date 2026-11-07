## The rendering trial (trial/, roadmap item 36): a throwaway scene run on the target phone to measure an isometric
## pixel-art world drawn by Godot's 3D renderer. What can be held without a phone: the frame-time statistics are right,
## the scene builds and every combination of its settings applies, the two techniques put the world where they should,
## a sweep and a soak write their lines of numbers, the trial is its own app (a main scene and an export preset of
## its own, and left out of the game's builds), and the adb script that records battery and temperature does its job
## against a stand-in for adb. The numbers themselves (frame times, battery, heat, APK size) need the phone:
## docs/RENDER_TRIAL.md.
## Run: godot --headless --path . -s res://tests/test_game_trial.gd
extends SceneTree

const FrameStats := preload("res://trial/frame_stats.gd")
const Trial := preload("res://trial/iso_trial.gd")
const DIR := "user://test_trial/"

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
	_wipe(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	test_stats()
	test_project()
	await test_scene()
	await test_sweep_and_soak()
	test_adb_script()
	_wipe(DIR)
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Removes every file and folder under `dir` (a run leaves nothing behind for the next).
func _wipe(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_wipe(dir + sub + "/")
		DirAccess.remove_absolute(dir + sub)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# ---------------------------------------------------------------- the statistics

func test_stats() -> void:
	var s := FrameStats.new(100)
	ok(s.count() == 0 and s.avg() == 0.0 and s.percentile(95.0) == 0.0 and s.worst() == 0.0 and s.fps() == 0.0 and s.over(10.0) == 0.0, "an empty window is all zeros")
	for i in range(1, 101):
		s.add(float(i))
	ok(s.count() == 100 and is_equal_approx(s.avg(), 50.5), "100 frames of 1 to 100 ms average 50.5")
	ok(s.percentile(95.0) == 95.0 and s.percentile(99.0) == 99.0 and s.percentile(50.0) == 50.0 and s.percentile(100.0) == 100.0 and s.percentile(0.0) == 1.0, "the percentiles are the frame that fraction were no slower than")
	ok(s.worst() == 100.0, "the worst is the slowest")
	ok(is_equal_approx(s.over(90.0), 0.10), "ten of them are slower than 90 ms")
	ok(is_equal_approx(s.fps(), 1000.0 / 50.5), "frames per second follow the average")
	s.add(500.0)
	ok(s.count() == 100 and s.worst() == 500.0 and s.percentile(0.0) == 2.0, "the window slides: the oldest frame goes when a new one comes")
	s.reset()
	ok(s.count() == 0, "reset empties it")
	var w := FrameStats.new(0)
	w.add(5.0)
	w.add(7.0)
	ok(w.count() == 1 and w.avg() == 7.0, "a window is at least one frame")
	var steady := FrameStats.new(300)
	for i in 300:
		steady.add(16.7)
	steady.add(120.0)
	ok(steady.percentile(99.0) < 17.0 and steady.worst() == 120.0, "one stutter in 300 frames shows in the worst and not in the 99th percentile")


# ---------------------------------------------------------------- the trial as its own app

func test_project() -> void:
	var project := ConfigFile.new()
	ok(project.load("res://project.godot") == OK, "project.godot loads")
	var feature_main := str(project.get_value("application", "run/main_scene.trial", ""))
	var game_main := str(project.get_value("application", "run/main_scene", ""))
	ok(feature_main == "res://trial/iso_trial.tscn" and FileAccess.file_exists(feature_main), "with the trial feature the app opens the trial scene")
	ok(game_main == "res://ui/main.tscn", "and without it, the game")
	var presets := ConfigFile.new()
	ok(presets.load("res://export_presets.cfg") == OK, "the export presets load")
	var by_name := {}
	for sec in presets.get_sections():
		if sec.ends_with(".options"):
			continue
		by_name[str(presets.get_value(sec, "name", ""))] = sec
	ok(by_name.has("Android Trial") and by_name.has("Android"), "there is a preset for the trial beside the game's Android one")
	if not (by_name.has("Android Trial") and by_name.has("Android")):
		return
	var trial: String = by_name["Android Trial"]
	var game: String = by_name["Android"]
	ok(str(presets.get_value(trial, "custom_features")) == "trial" and str(presets.get_value(game, "custom_features")) == "", "the trial preset sets the trial feature, the game's does not")
	var t_pkg := str(presets.get_value(trial + ".options", "package/unique_name"))
	var g_pkg := str(presets.get_value(game + ".options", "package/unique_name"))
	ok(t_pkg != g_pkg and t_pkg.begins_with(g_pkg), "the trial is its own app that installs beside the game (%s)" % t_pkg)
	ok(str(presets.get_value(trial + ".options", "package/name")) != str(presets.get_value(game + ".options", "package/name")), "with a name of its own")
	for name in ["Android", "iOS", "Windows Desktop"]:
		ok(by_name.has(name) and "trial/*" in str(presets.get_value(by_name[name], "exclude_filter")), "the %s build leaves the trial out" % name)
	ok("trial/*" not in str(presets.get_value(trial, "exclude_filter")), "and the trial build keeps it")
	ok(str(presets.get_value(trial + ".options", "architectures/arm64-v8a")) == "true", "the trial is built for 64-bit phones like the game")


# ---------------------------------------------------------------- the scene

func _make() -> Control:
	var t: Control = load("res://trial/iso_trial.tscn").instantiate()
	t.log_dir = DIR
	root.add_child(t)
	return t


func test_scene() -> void:
	var t := _make()
	await _frames(4)
	ok(t.field.multimesh.instance_count == Trial.GRID * Trial.GRID, "the field has a block for every square (%d)" % t.field.multimesh.instance_count)
	var heights := {}
	for gz in Trial.GRID:
		for gx in Trial.GRID:
			heights[t.ground_height(gx - Trial.GRID / 2.0, gz - Trial.GRID / 2.0)] = true
	ok(heights.size() >= 3, "and the ground has height, not a flat plane (%d heights)" % heights.size())
	ok(t.walkers.size() == Trial.SPRITES[Trial.SPRITES.size() - 1] and t.torches.size() == Trial.LIGHTS[Trial.LIGHTS.size() - 1], "there are figures and torches enough for the biggest setting")
	ok(t.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "the camera is orthographic")
	ok(is_equal_approx(t.camera.rotation_degrees.y, 45.0) and is_equal_approx(t.camera.rotation_degrees.x, -35.264), "at the isometric angle")
	ok(t.stats.count() > 0, "frame times are being recorded")
	var report: String = t._report()
	ok("frame" in report and "draw calls" in report and "lowres" in report, "the screen reports the technique, frame times and draw calls")
	# the technique puts the world in its own viewport, or in the screen's
	ok(t.world.get_parent() == t.viewport3d and t.shown.visible, "low-resolution draws the world in a small viewport shown scaled up")
	var win: Vector2i = t._window_px()
	ok(win.x > 1 and t.viewport3d.size == Vector2i(maxi(1, win.x / t.scale_px), maxi(1, win.y / t.scale_px)), "which is the window divided by the pixel scale (%s of %s)" % [t.viewport3d.size, win])
	t.technique = "native"
	t._apply()
	ok(t.world.get_parent() == t and not t.shown.visible and t.viewport3d.render_target_update_mode == SubViewport.UPDATE_DISABLED, "native draws it in the screen's own viewport and stops the small one")
	t.technique = "lowres"
	t._apply()
	ok(t.world.get_parent() == t.viewport3d, "and back again")
	# every combination applies, and what it asks for shows
	var applied := 0
	for tech in ["native", "lowres"]:
		for sc in Trial.SCALES:
			for lights in Trial.LIGHTS:
				for sprites in Trial.SPRITES:
					for pi in Trial.PITCHES.size():
						t.technique = tech
						t.scale_px = sc
						t.light_count = lights
						t.sprite_count = sprites
						t.pitch_index = pi
						t.shadows = (lights + sprites) % 2 == 0
						t._apply()
						applied += 1
						var lit: int = t.torches.filter(func(l): return l.visible).size()
						var seen: int = t.walkers.filter(func(w): return w["node"].visible).size()
						if lit != lights or seen != sprites or t.sun.shadow_enabled != t.shadows or not is_equal_approx(t.camera.rotation_degrees.x, -float(Trial.PITCHES[pi])):
							ok(false, "the setting %s %d %d %d %d was not applied" % [tech, sc, lights, sprites, pi])
	ok(applied == 2 * 4 * 4 * 4 * 2, "every combination of settings was applied (%d)" % applied)
	await _frames(3)
	# the camera snaps to whole rendered pixels when asked
	t.technique = "lowres"
	t.scale_px = 3
	t.pitch_index = 0
	t.snap = true
	t._apply()
	for step in 5:
		t.elapsed += 0.37
		t._move(0.0)
		var basis := Basis.from_euler(Vector3(-deg_to_rad(float(Trial.PITCHES[0])), deg_to_rad(45.0), 0.0))
		var local: Vector3 = basis.inverse() * (t.camera.position as Vector3)
		var texel: float = Trial.VIEW_SIZE / float(t._render_px.y)
		var off_x := absf(local.x / texel - roundf(local.x / texel))
		var off_y := absf(local.y / texel - roundf(local.y / texel))
		ok(off_x < 0.001 and off_y < 0.001, "snapped, the camera sits on a whole rendered pixel (step %d)" % step)
	t.snap = false
	t.elapsed += 0.123
	t._move(0.0)
	var free_basis := Basis.from_euler(Vector3(-deg_to_rad(float(Trial.PITCHES[0])), deg_to_rad(45.0), 0.0))
	var free_local: Vector3 = free_basis.inverse() * (t.camera.position as Vector3)
	var free_texel: float = Trial.VIEW_SIZE / float(t._render_px.y)
	ok(absf(free_local.x / free_texel - roundf(free_local.x / free_texel)) > 0.001 or absf(free_local.y / free_texel - roundf(free_local.y / free_texel)) > 0.001, "and unsnapped, it does not (so the switch shows the difference)")
	# the figures stand on the ground they walk over
	var standing := 0
	for i in 20:
		var w: Dictionary = t.walkers[i]
		var p: Vector3 = (w["node"] as Sprite3D).position
		if is_equal_approx(p.y, float(t.ground_height(roundf(p.x), roundf(p.z))) - 0.5):
			standing += 1
	ok(standing == 20, "the figures stand on the top of the blocks they walk over (%d of 20)" % standing)
	t.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- sweep and soak

func test_sweep_and_soak() -> void:
	var t := _make()
	await _frames(2)
	t.sweep_seconds = 0.3
	t.start_sweep()
	ok(t.mode == "sweep" and t.technique == str(Trial.SWEEP[0][0]), "a sweep starts on its first setting")
	var guard := 0
	while t.mode == "sweep" and guard < 400:
		guard += 1
		t._process(0.2)
	ok(t.mode == "free", "and ends after every setting (%d steps)" % guard)
	var csv := FileAccess.get_file_as_string(DIR + "trial_sweep.csv").split("\n", false)
	ok(csv.size() == 1 + Trial.SWEEP.size() and csv[0] == Trial.HEADER, "it writes a header and a line for each of the %d settings" % Trial.SWEEP.size())
	var columns := Trial.HEADER.split(",").size()
	var shaped := true
	var order_ok := true
	for i in range(1, csv.size()):
		var cols := csv[i].split(",")
		shaped = shaped and cols.size() == columns
		order_ok = order_ok and cols[2] == str(Trial.SWEEP[i - 1][0]) and int(cols[5]) == int(Trial.SWEEP[i - 1][1]) and int(cols[7]) == int(Trial.SWEEP[i - 1][2])
	ok(shaped, "every line has the header's %d columns" % columns)
	ok(order_ok, "in the order of the sweep's list")
	ok(t.results.size() == Trial.SWEEP.size() and "avg" in str(t.results[0]), "the screen keeps a line for each too")
	# a soak logs a line every 30 seconds
	t.start_soak()
	ok(t.mode == "soak", "a soak starts")
	t._process(31.0)
	var soak := FileAccess.get_file_as_string(DIR + "trial_soak.csv").split("\n", false)
	ok(soak.size() == 2 and soak[0] == Trial.HEADER, "and logs a line after 30 seconds")
	t._process(Trial.SOAK_SECONDS)
	ok(t.mode == "free", "and ends after its ten minutes")
	# the settings are held during a run
	t.start_sweep()
	var before: String = t.technique
	(t.buttons["technique"] as Button).pressed.emit()
	ok(t.technique == before, "pressing a setting during a run does not change it")
	t.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the adb script

func test_adb_script() -> void:
	var script := ProjectSettings.globalize_path("res://tools/trial_adb.sh")
	var fake := ProjectSettings.globalize_path("res://tests/fixtures/fake_adb.sh")
	var out_dir := ProjectSettings.globalize_path(DIR + "adb_out")
	var state := ProjectSettings.globalize_path(DIR + "adb_state")
	var log := ProjectSettings.globalize_path(DIR + "adb.log")
	var apk := ProjectSettings.globalize_path(DIR + "fake.apk")
	var f := FileAccess.open(DIR + "fake.apk", FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
	f.close()
	var output: Array = []
	var cmd := "ADB='%s' INTERVAL=1 FAKE_STATE='%s' FAKE_LOG='%s' bash '%s' '%s' 3 '%s'" % [fake, state, log, script, apk, out_dir]
	var code := OS.execute("bash", ["-c", cmd], output, true)
	ok(code == 0, "the script runs against a phone that answers (exit %d)" % code)
	var battery := FileAccess.get_file_as_string(out_dir + "/battery.csv").split("\n", false)
	ok(battery.size() == 5 and battery[0] == "elapsed_s,level_percent,temp_c,status", "it samples the battery at the start and every second for three (%d lines)" % battery.size())
	if battery.size() == 5:
		ok(battery[1] == "0,80,31.0,3" and battery[4] == "3,77,32.5,3", "reading level, temperature in degrees and status: %s ... %s" % [battery[1], battery[4]])
	var summary := FileAccess.get_file_as_string(out_dir + "/summary.txt")
	ok("Device: Pixel Test (Android 14, tensor)" in summary, "the summary names the device")
	ok("APK: 10 bytes" in summary, "and the APK's size")
	ok("Battery: 80% to 77% in 3 s" in summary and "Temperature: 31.0 C at the start, 32.5 C at the end, 32.5 C at most" in summary, "and the battery and temperature over the run")
	ok("Frame-time lines from the app: 2" in summary, "and how many frame-time lines the app logged")
	var kept := FileAccess.get_file_as_string(out_dir + "/trial_log.txt")
	ok(kept.count("TRIAL_") == 3 and not "unrelated" in kept, "only the trial's own log lines are kept")
	var commands := FileAccess.get_file_as_string(log)
	ok("install -r" in commands and "am start -n com.dmgworkshop.generationallegacy.trial/com.godot.game.GodotApp" in commands and "--soak" in commands, "it installed the trial and started it on its soak")
	ok("logcat -c" in commands, "after clearing the phone's log")
	# no phone, no APK
	var none: Array = []
	var no_phone := OS.execute("bash", ["-c", "ADB=/bin/false bash '%s' '%s' 1 '%s' 2>&1" % [script, apk, out_dir + "2"]], none, true)
	ok(no_phone != 0 and "No phone found" in "".join(none), "with no phone connected it says so and stops")
	var no_apk := OS.execute("bash", ["-c", "bash '%s' 2>&1" % script], none, true)
	ok(no_apk != 0, "and with no APK given it stops")
