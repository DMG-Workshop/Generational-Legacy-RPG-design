## THROWAWAY rendering trial (roadmap item 36). Not part of the game: it is run on the target phone to find out how
## an isometric pixel-art world drawn by Godot's 3D renderer performs, before any art is made for it. See
## docs/RENDER_TRIAL.md for what it measures, how to run it and how to read the numbers.
##
## The scene is a field of blocks of different heights (so height, digging and building are real), an orthographic
## camera at the isometric angle that pans on a fixed path, lights, and many Sprite3D figures walking about, drawn
## from the game's own sprites (SpriteArt). Two ways of putting it on the screen are compared:
##   native  the 3D world is drawn at the screen's full resolution
##   lowres  the 3D world is drawn into a small SubViewport (the screen's size divided by `scale_px`) and that
##           picture is scaled up with nearest-neighbour filtering, so every rendered pixel is a crisp square
## Everything that can cost frame time can be changed while it runs: the technique, the pixel scale, the number of
## lights, the sun's shadow, the number of figures, the camera pitch and whether the camera snaps to the pixel grid.
## "Sweep" runs a fixed list of settings for a while each and writes one line of numbers for each.
extends Control

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const FrameStats := preload("res://trial/frame_stats.gd")

const GRID := 24                       # blocks along each side of the field
const VIEW_SIZE := 14.0                # world units from the top of the screen to the bottom (orthographic)
const SCALES := [1, 2, 3, 4]           # screen pixels per rendered pixel for the low-resolution technique
const LIGHTS := [0, 2, 4, 8]
const SPRITES := [10, 50, 100, 200]
const PITCHES := [35.264, 30.0]        # true isometric, and the 2:1 pixel-art angle
const SOAK_SECONDS := 600.0
const SWEEP_SECONDS := 15.0
const WARMUP_SECONDS := 2.0
const OVER_LIMIT_MS := 20.0            # a frame slower than this is a stutter on a 60 Hz screen
## Settings tried by the sweep: technique, lights, sprites, sun shadow, pixel scale.
const SWEEP := [
	["native", 0, 50, false, 3], ["native", 4, 50, false, 3], ["native", 8, 50, false, 3], ["native", 4, 50, true, 3], ["native", 4, 200, false, 3],
	["lowres", 0, 50, false, 3], ["lowres", 4, 50, false, 3], ["lowres", 8, 50, false, 3], ["lowres", 4, 50, true, 3], ["lowres", 4, 200, false, 3],
	["lowres", 4, 50, false, 2], ["lowres", 4, 50, false, 4],
]
const HEADER := "time,elapsed_s,technique,scale,render_px,lights,sun_shadow,sprites,pitch,snap,avg_ms,p95_ms,p99_ms,worst_ms,over_20ms,fps,draw_calls,objects,primitives,vram_mb,device,renderer"

var technique := "lowres"
var scale_px := 3
var light_count := 4
var shadows := false
var sprite_count := 50
var pitch_index := 0
var snap := true
var sweep_seconds := SWEEP_SECONDS
var log_dir := "user://"

var world: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var field: MultiMeshInstance3D
var torches: Array = []
var walkers: Array = []            # [{node, cx, cz, radius, speed, phase}]
var viewport3d: SubViewport
var shown: TextureRect
var stats := FrameStats.new(300)
var label: Label
var buttons: Dictionary = {}
var results: Array = []            # lines of the last sweep, for the screen
var elapsed := 0.0
var mode := "free"                 # free | sweep | soak
var mode_time := 0.0
var sweep_index := 0
var _since_label := 0.0
var _since_log := 0.0
var _textures: Array = []
var _render_px := Vector2i.ZERO


func _ready() -> void:
	GameData.load_all()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_world()
	viewport3d = SubViewport.new()
	viewport3d.own_world_3d = true
	viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport3d.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport3d)
	shown = TextureRect.new()
	shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shown)
	_make_overlay()
	_apply()
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()   # tools/trial_adb.sh starts the soak with "--soak"
	if "--sweep" in args:
		start_sweep()
	elif "--soak" in args:
		start_soak()


# ---------------------------------------------------------------- the world

func _make_world() -> void:
	world = Node3D.new()
	world.name = "World"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14121c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a8fb0")
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_SIZE
	camera.near = 0.1
	camera.far = 120.0
	world.add_child(camera)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.0
	sun.directional_shadow_max_distance = 40.0
	world.add_child(sun)
	_make_field()
	_make_walkers()


func ground_height(x: float, z: float) -> int:
	return clampi(1 + int(floor(2.2 + 1.8 * sin(x * 0.55) * cos(z * 0.45))), 1, 4)


## Each block's top and sides come from a small atlas of hand-drawn-looking surfaces: four surfaces (grass, earth,
## stone, snow) by eight variants, so no two neighbouring blocks match. A block's variant and tint come from its own
## position through an integer mix (never Godot's global dice), so the same field is drawn every run.
const ATLAS_COLS := 8
const ATLAS_ROWS := 4
const CELL := 16


static func _mix(a: int, b: int) -> int:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


static func _unit(h: int) -> float:
	return float(h & 0xffff) / 65535.0


## One variant of one surface, drawn pixel by pixel in greys (the block's colour is multiplied in by the shader), so
## the surface reads as stone, earth, grass or snow whatever the tint.
func _draw_cell(img: Image, col: int, row: int) -> void:
	var ox := col * CELL
	var oy := row * CELL
	var seed_v := _mix(col + 1, row * 31 + 7)
	var base := 0.80 + 0.10 * _unit(_mix(seed_v, 3))
	for y in CELL:
		for x in CELL:
			var h := _mix(seed_v + x * 97, y * 131 + 11)
			var v := base + (_unit(h) - 0.5) * 0.10   # fine grain, different in every variant
			img.set_pixel(ox + x, oy + y, Color(v, v, v, 1.0))
	match row:
		0:   # grass: darker tufts and a few light blades, sparse
			for i in 14:
				var tx := int(floor(_unit(_mix(seed_v, 40 + i) ) * (CELL - 1)))
				var ty := int(floor(_unit(_mix(seed_v, 80 + i) ) * (CELL - 1)))
				img.set_pixel(ox + tx, oy + ty, Color(base - 0.22, base - 0.22, base - 0.22))
				if ty > 0:
					img.set_pixel(ox + tx, oy + ty - 1, Color(base + 0.08, base + 0.08, base + 0.08))
		1:   # earth: flecks of pebble and a darker patch in some variants
			for i in 9:
				var tx := int(floor(_unit(_mix(seed_v, 120 + i)) * (CELL - 1)))
				var ty := int(floor(_unit(_mix(seed_v, 160 + i)) * (CELL - 1)))
				var c := base + (0.12 if i % 3 == 0 else -0.18)
				img.set_pixel(ox + tx, oy + ty, Color(c, c, c))
			if seed_v % 3 == 0:
				for y in range(5, 10):
					for x in range(4, 9):
						var c2 := base - 0.12
						img.set_pixel(ox + x, oy + y, Color(c2, c2, c2))
		2:   # stone: a crack or two, and paler chips
			var cx := 2 + int(_unit(_mix(seed_v, 200)) * 10)
			for k in 6:
				var y0 := (k * 3 + int(_unit(_mix(seed_v, 210 + k)) * 3)) % CELL
				img.set_pixel(ox + clampi(cx + k % 3, 0, CELL - 1), oy + y0, Color(base - 0.3, base - 0.3, base - 0.3))
			for i in 6:
				var tx2 := int(floor(_unit(_mix(seed_v, 260 + i)) * (CELL - 1)))
				var ty2 := int(floor(_unit(_mix(seed_v, 300 + i)) * (CELL - 1)))
				img.set_pixel(ox + tx2, oy + ty2, Color(base + 0.14, base + 0.14, base + 0.14))
		3:   # snow: a few bright glints and soft shadow hollows
			for i in 5:
				var tx3 := int(floor(_unit(_mix(seed_v, 340 + i)) * (CELL - 1)))
				var ty3 := int(floor(_unit(_mix(seed_v, 380 + i)) * (CELL - 1)))
				img.set_pixel(ox + tx3, oy + ty3, Color(1.0, 1.0, 1.0))
			for i in 3:
				var tx4 := int(floor(_unit(_mix(seed_v, 420 + i)) * (CELL - 1)))
				var ty4 := int(floor(_unit(_mix(seed_v, 460 + i)) * (CELL - 1)))
				img.set_pixel(ox + tx4, oy + ty4, Color(base - 0.10, base - 0.10, base - 0.10))


func _make_atlas() -> ImageTexture:
	var img := Image.create(ATLAS_COLS * CELL, ATLAS_ROWS * CELL, false, Image.FORMAT_RGBA8)
	for row in ATLAS_ROWS:
		for col in ATLAS_COLS:
			_draw_cell(img, col, row)
	return ImageTexture.create_from_image(img)


const BLOCK_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(8.0, 4.0);
varying vec2 cell_at;
varying vec4 tint;
void vertex() {
	cell_at = INSTANCE_CUSTOM.xy;
	tint = COLOR;
}
void fragment() {
	vec2 cell = floor(cell_at * cells + vec2(0.5));
	vec2 uv = (cell + fract(UV)) / cells;
	vec3 grey = texture(atlas, uv).rgb;
	ALBEDO = grey * tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


func _make_field() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var shader := Shader.new()
	shader.code = BLOCK_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("atlas", _make_atlas())
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = GRID * GRID
	var tops := [Color("#6abf4b"), Color("#a8794a"), Color("#8c8c9a"), Color("#e6e6f0")]   # grass, earth, stone, snow
	for gz in GRID:
		for gx in GRID:
			var i := gz * GRID + gx
			var h := ground_height(gx - GRID / 2.0, gz - GRID / 2.0)
			var t := Transform3D(Basis().scaled(Vector3(1.0, float(h), 1.0)), Vector3(gx - GRID / 2.0, float(h) * 0.5 - 0.5, gz - GRID / 2.0))
			mm.set_instance_transform(i, t)
			var r := _mix(gx * 7919 + 13, gz * 104729 + 29)
			var variant := r % ATLAS_COLS
			var jitter := 1.0 + (_unit(_mix(r, 5)) - 0.5) * 0.14   # each block's own brightness, a few per cent either way
			var warm := (_unit(_mix(r, 9)) - 0.5) * 0.06             # and a slight warm or cool drift
			var c: Color = (tops[h - 1] as Color) * jitter
			c = Color(c.r * (1.0 + warm), c.g, c.b * (1.0 - warm), 1.0)
			mm.set_instance_color(i, c)
			mm.set_instance_custom_data(i, Color(float(variant) / float(ATLAS_COLS) + 0.5 / ATLAS_COLS, float(h - 1) / float(ATLAS_ROWS) + 0.5 / ATLAS_ROWS, 0.0, 0.0))
	field = MultiMeshInstance3D.new()
	field.multimesh = mm
	world.add_child(field)


func _make_walkers() -> void:
	_textures.clear()
	var colors := [Color("#cc3333"), Color("#3366cc"), Color("#33aa66"), Color("#ccaa33")]
	var n := 0
	for cls in GameData.classes:
		var tex := SpriteArt.hero("human", str(cls), colors[n % colors.size()])
		if tex != null:
			_textures.append([tex, 1.8])
		n += 1
	for c in GameData.creatures:
		var tex := SpriteArt.creature(str(c["id"]))
		if tex != null:
			_textures.append([tex, 3.2 if bool(c.get("boss", false)) else 1.5])
	var rng := RandomNumberGenerator.new()   # the trial's own dice: nothing here is the game's
	rng.seed = 36
	for i in SPRITES[SPRITES.size() - 1]:
		var pick: Array = _textures[rng.randi() % _textures.size()]
		var tex: Texture2D = pick[0]
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = float(pick[1]) / float(tex.get_height())
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.double_sided = true
		s.offset = Vector2(0.0, tex.get_height() * 0.5)   # standing on its position
		world.add_child(s)
		walkers.append({"node": s, "cx": rng.randf_range(-7.0, 7.0), "cz": rng.randf_range(-7.0, 7.0), "radius": rng.randf_range(1.0, 5.0),
			"speed": rng.randf_range(0.15, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0), "phase": rng.randf() * TAU})
	for i in LIGHTS[LIGHTS.size() - 1]:
		var l := OmniLight3D.new()
		var a := TAU * float(i) / float(LIGHTS[LIGHTS.size() - 1])
		l.position = Vector3(cos(a) * 6.0, 4.2, sin(a) * 6.0)
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 2.2
		l.omni_range = 6.0
		world.add_child(l)
		torches.append(l)


# ---------------------------------------------------------------- the settings

## Puts the world where the technique draws it and applies every setting.
func _apply() -> void:
	var parent: Node = viewport3d if technique == "lowres" else self
	if world.get_parent() != parent:
		if world.get_parent() != null:
			world.get_parent().remove_child(world)
		parent.add_child(world)
		parent.move_child(world, 0)
	var window := _window_px()
	if technique == "lowres":
		_render_px = Vector2i(maxi(1, window.x / scale_px), maxi(1, window.y / scale_px))
		viewport3d.size = _render_px
		viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		shown.texture = viewport3d.get_texture()
		shown.visible = true
	else:
		_render_px = window
		viewport3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
		shown.visible = false
	camera.current = true
	camera.rotation_degrees = Vector3(-float(PITCHES[pitch_index]), 45.0, 0.0)
	sun.shadow_enabled = shadows
	for i in torches.size():
		(torches[i] as OmniLight3D).visible = i < light_count
	for i in walkers.size():
		(walkers[i]["node"] as Sprite3D).visible = i < sprite_count
	stats.reset()
	_update_buttons()


## The window's size in real pixels (the viewport's own size where there is no window, as when run headless).
func _window_px() -> Vector2i:
	var w := DisplayServer.window_get_size()
	if w.x <= 0 or w.y <= 0:
		w = Vector2i(get_viewport_rect().size)
	return Vector2i(maxi(2, w.x), maxi(2, w.y))


func _cycle(values: Array, current: Variant) -> Variant:
	return values[(values.find(current) + 1) % values.size()]


func _update_buttons() -> void:
	if buttons.is_empty():
		return
	(buttons["technique"] as Button).text = "Technique: " + technique
	(buttons["scale"] as Button).text = "Pixel scale: %d" % scale_px
	(buttons["lights"] as Button).text = "Lights: %d" % light_count
	(buttons["shadows"] as Button).text = "Sun shadow: " + ("on" if shadows else "off")
	(buttons["sprites"] as Button).text = "Figures: %d" % sprite_count
	(buttons["pitch"] as Button).text = "Pitch: %.1f" % float(PITCHES[pitch_index])
	(buttons["snap"] as Button).text = "Snap camera: " + ("on" if snap else "off")
	(buttons["sweep"] as Button).text = "Sweep (%d s)" % int(SWEEP.size() * sweep_seconds)
	(buttons["soak"] as Button).text = "Soak %d min" % int(SOAK_SECONDS / 60.0)


# ---------------------------------------------------------------- the screen

func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-212, 8)
	box.custom_minimum_size = Vector2(204, 0)
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)
	var defs := [["technique", func(): technique = "native" if technique == "lowres" else "lowres"],
		["scale", func(): scale_px = _cycle(SCALES, scale_px)],
		["lights", func(): light_count = _cycle(LIGHTS, light_count)],
		["shadows", func(): shadows = not shadows],
		["sprites", func(): sprite_count = _cycle(SPRITES, sprite_count)],
		["pitch", func(): pitch_index = (pitch_index + 1) % PITCHES.size()],
		["snap", func(): snap = not snap],
		["sweep", func(): start_sweep()],
		["soak", func(): start_soak()],
		["quit", func(): get_tree().quit()]]
	for d in defs:
		var b := Button.new()
		b.text = str(d[0])
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 16)
		var act: Callable = d[1]
		b.pressed.connect(func():
			if mode != "free" and d[0] not in ["quit", "sweep", "soak"]:
				return   # a run in progress keeps its settings
			act.call()
			if d[0] not in ["quit", "sweep", "soak"]:
				_apply())
		box.add_child(b)
		buttons[d[0]] = b
	buttons["quit"].text = "Quit"
	_update_buttons()


func _process(delta: float) -> void:
	elapsed += delta
	if stats.count() > 0 or delta > 0.0:
		stats.add(delta * 1000.0)
	_move(delta)
	_since_label += delta
	if _since_label >= 0.25:
		_since_label = 0.0
		label.text = _report()
	match mode:
		"sweep":
			_run_sweep(delta)
		"soak":
			_run_soak(delta)


## The camera on its path and every figure on its own, snapped to the pixel grid when asked.
func _move(_delta: float) -> void:
	var focus := Vector3(sin(elapsed * 0.15) * 4.0, 1.5, cos(elapsed * 0.11) * 4.0)
	var basis := Basis.from_euler(Vector3(-deg_to_rad(float(PITCHES[pitch_index])), deg_to_rad(45.0), 0.0))
	var pos := focus + basis.z * 40.0
	if snap:
		var texel := VIEW_SIZE / float(maxi(1, _render_px.y))
		var local := basis.inverse() * pos
		local.x = roundf(local.x / texel) * texel
		local.y = roundf(local.y / texel) * texel
		pos = basis * local
	camera.position = pos
	for i in mini(sprite_count, walkers.size()):
		var w: Dictionary = walkers[i]
		var a := float(w["phase"]) + elapsed * float(w["speed"])
		var x := float(w["cx"]) + cos(a) * float(w["radius"])
		var z := float(w["cz"]) + sin(a) * float(w["radius"])
		var top := float(ground_height(roundf(x), roundf(z))) - 0.5
		(w["node"] as Sprite3D).position = Vector3(x, top, z)


func _report() -> String:
	var lines: Array = []
	lines.append("%s  %s  scale %d  3D drawn at %dx%d" % [technique, "(crisp pixels)" if technique == "lowres" else "(full resolution)", scale_px, _render_px.x, _render_px.y])
	lines.append("lights %d  sun shadow %s  figures %d  pitch %.1f  snap %s" % [light_count, "on" if shadows else "off", sprite_count, float(PITCHES[pitch_index]), "on" if snap else "off"])
	lines.append("frame %.1f ms avg  %.1f p95  %.1f p99  %.1f worst  (%.0f fps)" % [stats.avg(), stats.percentile(95.0), stats.percentile(99.0), stats.worst(), stats.fps()])
	lines.append("over %d ms: %.1f%% of the last %d frames" % [int(OVER_LIMIT_MS), 100.0 * stats.over(OVER_LIMIT_MS), stats.count()])
	lines.append("draw calls %d  objects %d  vram %.0f MB" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	match mode:
		"sweep":
			lines.append("SWEEP %d of %d: %.0f s left in this setting" % [sweep_index + 1, SWEEP.size(), maxf(0.0, sweep_seconds - mode_time)])
		"soak":
			lines.append("SOAK: %.0f of %.0f s (a line is logged every 30 s)" % [mode_time, SOAK_SECONDS])
	lines.append("%s  %s" % [RenderingServer.get_video_adapter_name(), OS.get_name()])
	for r in results:
		lines.append(str(r))
	return "\n".join(lines)


# ---------------------------------------------------------------- sweep and soak

func start_sweep() -> void:
	results.clear()
	mode = "sweep"
	sweep_index = 0
	mode_time = 0.0
	_write_header(log_dir + "trial_sweep.csv")
	_apply_sweep(0)


func _apply_sweep(i: int) -> void:
	var s: Array = SWEEP[i]
	technique = str(s[0])
	light_count = int(s[1])
	sprite_count = int(s[2])
	shadows = bool(s[3])
	scale_px = int(s[4])
	_apply()
	mode_time = 0.0
	_warmed = false


var _warmed := false


func _run_sweep(delta: float) -> void:
	mode_time += delta
	if not _warmed and mode_time >= WARMUP_SECONDS:
		_warmed = true
		stats.reset()
	if mode_time >= sweep_seconds:
		var row := _row()
		_append(log_dir + "trial_sweep.csv", row)
		print("TRIAL_RESULT ", row)
		results.append("%s s%d L%d F%d %s: %.1f avg  %.1f p95  %.1f p99 ms" % [technique, scale_px, light_count, sprite_count, "shadow" if shadows else "-", stats.avg(), stats.percentile(95.0), stats.percentile(99.0)])
		sweep_index += 1
		if sweep_index >= SWEEP.size():
			mode = "free"
			_update_buttons()
			print("TRIAL_DONE sweep")
		else:
			_apply_sweep(sweep_index)


func start_soak() -> void:
	mode = "soak"
	mode_time = 0.0
	_since_log = 0.0
	_write_header(log_dir + "trial_soak.csv")
	stats.reset()


func _run_soak(delta: float) -> void:
	mode_time += delta
	_since_log += delta
	if _since_log >= 30.0:
		_since_log = 0.0
		var row := _row()
		_append(log_dir + "trial_soak.csv", row)
		print("TRIAL_SOAK ", row)
	if mode_time >= SOAK_SECONDS:
		mode = "free"
		print("TRIAL_DONE soak")


# ---------------------------------------------------------------- the numbers

func _row() -> String:
	return ",".join([str(int(Time.get_unix_time_from_system())), "%.0f" % elapsed, technique, str(scale_px), "%dx%d" % [_render_px.x, _render_px.y],
		str(light_count), "1" if shadows else "0", str(sprite_count), "%.1f" % float(PITCHES[pitch_index]), "1" if snap else "0",
		"%.2f" % stats.avg(), "%.2f" % stats.percentile(95.0), "%.2f" % stats.percentile(99.0), "%.2f" % stats.worst(),
		"%.4f" % stats.over(OVER_LIMIT_MS), "%.1f" % stats.fps(),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))), str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))), "%.0f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		RenderingServer.get_video_adapter_name().replace(",", " "), RenderingServer.get_current_rendering_driver_name()])


func _write_header(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_line(HEADER)
		f.close()


func _append(path: String, row: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(row)
	f.close()
