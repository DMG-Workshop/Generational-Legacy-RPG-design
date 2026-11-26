## The options: Sound, Graphics, Access, Controls, Text size, Touch, Autopilot, General and (in a game) Save, one tab each. Opened by the
## life screen's Menu button, the pause screen's and the main menu's Options, or Android's back button when nothing else is open.
## Every page is built once and one is shown, so the screen is never taller than one tab. Back (Escape, the pad's B) closes it.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const GraphicsSettings := preload("res://ui/play/graphics_settings.gd")
const Sound := preload("res://ui/play/sound.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")
const Cooldown := preload("res://ui/play/autopilot_cooldown.gd")

const PAGE_ORDER := ["text", "touch", "general", "access", "graphics", "sound", "controls", "autopilot", "save"]

static var last_tab := ""   # the tab the player was on, for the next time the options open

var app: Node
var note: Label
var pages := {}        # tab id -> the page of that tab (all built once; one shows)
var tab_row: HFlowContainer
var tab := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("back_close", func(): queue_free())
	z_index = 20   # above a fight's lists and result, which draw raised
	SkinScreen.apply(self, false)   # parchment and wooden buttons over the dimmed screen it was opened on
	var mode: String = app.menu_mode()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	p.set_meta("kit_panel", true)
	p.custom_minimum_size = Vector2(minf(560.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label(str(MenuKit.data()["options"]["title"]), 22, Kit.ACCENT)
	var rb := SkinScreen.ribbon(t)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rb)
	top.add_child(Kit.button("Back", func(): queue_free(), Vector2(100, 34)))
	tab_row = HFlowContainer.new()
	tab_row.add_theme_constant_override("h_separation", 6)
	tab_row.add_theme_constant_override("v_separation", 6)
	v.add_child(tab_row)
	var listed: Array = MenuKit.rows("options").map(func(r): return str(r["id"]))
	for id in PAGE_ORDER:   # the pages sit in the order the options were always built in (the tabs show in the data's order)
		if id not in listed or (id == "save" and mode != "game"):
			continue   # nothing to save on the title or mid-fight
		var pg := VBoxContainer.new()
		pg.add_theme_constant_override("separation", 8)
		pg.visible = false
		pg.name = "Page_" + id
		pages[id] = pg
		v.add_child(pg)

	# Built in the order the options were always listed, each into its tab's page.
	var pg_text: VBoxContainer = pages["text"]
	pg_text.add_child(Kit.label("Text size", 17, Kit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pg_text.add_child(row)
	for s in UiSettings.scales():
		var sc: float = s
		_choice(row, "%d%%" % int(round(sc * 100.0)), is_equal_approx(sc, UiSettings.get_scale()), func(): app.set_ui_scale(sc))
	pg_text.add_child(_why("Everything on screen grows together. Phones and tablets start at %d%%." % int(round(float(UiSettings.setting("default_scale_mobile")) * 100.0))))

	var pg_touch: VBoxContainer = pages["touch"]
	pg_touch.add_child(Kit.label("Touch layout", 17, Kit.ACCENT))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	pg_touch.add_child(trow)
	for tl in UiSettings.touch_layouts():
		var mode_id: String = tl
		_choice(trow, mode_id.capitalize(), mode_id == UiSettings.get_touch_layout(), func(): app.set_touch_layout(mode_id))
	pg_touch.add_child(_why("Fingertip-sized buttons and tap / hold in the help. Auto: on phones and tablets only."))
	if UiSettings.touch() or UiSettings.touch_screen():
		pg_touch.add_child(_why("Hold a finger on anything for its details; a quick tap acts."))

	var pg_gen: VBoxContainer = pages["general"]
	pg_gen.add_child(Kit.label("Tutorial tips", 17, Kit.ACCENT))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	pg_gen.add_child(prow)
	_choice(prow, "On", UiSettings.tutorial_on(), func(): app.set_tutorial(true))
	_choice(prow, "Off", not UiSettings.tutorial_on(), func(): app.set_tutorial(false))
	pg_gen.add_child(_why("Short tips about what to do next, for a new house's first heir."))

	var pg_access: VBoxContainer = pages["access"]
	pg_access.add_child(Kit.label("Accessibility", 17, Kit.ACCENT))
	var options := [
		["colour_blind", "Colour-blind colours", "Good and bad news in blue and orange, not green and red."],
		["high_contrast", "High contrast", "Quiet text in a brighter grey."],
		["reduced_motion", "Reduced motion", "No sliding or lunging in fights; numbers fade where they are."],
		["plain_font", "Plain font", "Titles, buttons and bars in the usual font, not the pixel font."],
		["sound_captions", "Captions for sounds", "A short line on screen for each sound that matters, even with sound off."],
	]
	for opt in options:
		var key: String = opt[0]
		var on := UiSettings.access_on(key)
		var krow := HBoxContainer.new()
		krow.add_theme_constant_override("separation", 8)
		pg_access.add_child(krow)
		var name_l := Kit.label(opt[1], 15, Kit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.tooltip_text = opt[2]
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		krow.add_child(name_l)
		_choice(krow, "On", on, func(): app.set_access(key, true))
		_choice(krow, "Off", not on, func(): app.set_access(key, false))
		pg_access.add_child(_why(opt[2]))
	if GameLocale.offered().size() > 1:   # nothing to choose until there is a second language
		pg_gen.add_child(Kit.label("Language", 17, Kit.ACCENT))
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 8)
		pg_gen.add_child(lrow)
		for lid in GameLocale.offered():
			var locale_id: String = lid
			_choice(lrow, GameLocale.name_of(locale_id), locale_id == GameLocale.locale(), func(): app.set_locale(locale_id))

	var pg_gfx: VBoxContainer = pages["graphics"]
	pg_gfx.add_child(Kit.label("Graphics", 17, Kit.ACCENT))
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	pg_gfx.add_child(grow)
	for gid in GraphicsSettings.ids():
		var preset_id: String = gid
		_choice(grow, str(GraphicsSettings.preset_def(preset_id)["name"]), preset_id == GraphicsSettings.preset(), func(): app.set_graphics(preset_id))
	pg_gfx.add_child(_why(str(GraphicsSettings.preset_def(GraphicsSettings.preset())["about"])))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	pg_gfx.add_child(brow)
	var blabel := Kit.label("Battery saver", 15, Kit.TEXT)
	blabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(blabel)
	_choice(brow, "On", GraphicsSettings.battery_saver(), func(): app.set_battery_saver(true))
	_choice(brow, "Off", not GraphicsSettings.battery_saver(), func(): app.set_battery_saver(false))
	pg_gfx.add_child(_why(str(GraphicsSettings.data()["battery_saver"]["about"])))

	var pg_sound: VBoxContainer = pages["sound"]
	var stext: Dictionary = Sound.data()["text"]
	for pair in [["sound", "effects"], ["music", "music"], ["ambience", "ambience"]]:
		var kind: String = pair[0]
		pg_sound.add_child(Kit.label(str(stext[pair[1]]), 17, Kit.ACCENT))
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		pg_sound.add_child(srow)
		_choice(srow, str(stext["off"]), Sound.choice(kind) == "off", func(): app.set_sound(kind, "off"))
		for lid in Sound.level_ids():
			var level_id: String = lid
			_choice(srow, str(Sound.data()["levels"][level_id]["name"]), Sound.choice(kind) == level_id, func(): app.set_sound(kind, level_id))
	pg_sound.add_child(_why(str(stext["about"])))

	pg_gen.add_child(Kit.label("Start in", 17, Kit.ACCENT))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	pg_gen.add_child(wrow)
	_choice(wrow, "Open world", UiSettings.open_world_first(), func(): app.set_open_world_first(true))
	_choice(wrow, "Life screen", not UiSettings.open_world_first(), func(): app.set_open_world_first(false))
	pg_gen.add_child(_why("What New game and Continue open first: the 2D map, or the life screen with its buttons. Walk the world and Back go between them."))
	pg_gen.add_child(Kit.label("Problems", 17, Kit.ACCENT))
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 8)
	pg_gen.add_child(erow)
	var elabel := Kit.label("Error log", 15, Kit.TEXT)
	elabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(elabel)
	_choice(erow, "On", UiSettings.error_log_on(), func(): app.set_error_log(true))
	_choice(erow, "Off", not UiSettings.error_log_on(), func(): app.set_error_log(false))
	pg_gen.add_child(_why("Remembers the game's last errors, for a report. Kept in memory only; nothing is sent."))
	var pg_controls: VBoxContainer = pages["controls"]
	pg_controls.add_child(Kit.label("Controls", 17, Kit.ACCENT))
	pg_controls.add_child(Kit.button("Controls: change the world's keys", func(): app.open_controls(), Vector2(0, 40)))
	pg_controls.add_child(_why("The gamepad's buttons are fixed: A accepts, B goes back, Start opens the pause screen."))
	pg_gen.add_child(Kit.button("Report a problem", func(): app.open_report(), Vector2(0, 40)))

	var pg_auto: VBoxContainer = pages["autopilot"]
	pg_auto.add_child(Kit.label("Autopilot cooldowns", 17, Kit.ACCENT))
	var atext: Dictionary = MenuKit.data()["options"]["autopilot"]
	for id in Cooldown.ids():
		var arow := HBoxContainer.new()
		pg_auto.add_child(arow)
		var al := Kit.label(str(atext[id]), 15, Kit.TEXT)
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(al)
		var left := Cooldown.remaining(id)
		var state := Kit.label(str(atext["ready"]) if left <= 0.0 else str(atext["left"]) % _clock(left), 15, Kit.good() if left <= 0.0 else Kit.dim())
		arow.add_child(state)
	pg_auto.add_child(_why(str(atext["about"])))

	note = Kit.label("", 14, Kit.good())
	if mode == "game":
		var pg_save: VBoxContainer = pages["save"]
		pg_save.add_child(Kit.button("Save", func():
			app.autosave()
			note.text = "Saved.", Vector2(0, 40)))
		var no_export := GameHardMode.text("no_export") if GameHardMode.ironman(app.dynasty) else ""
		var copy := Kit.button("Copy backup", func():
			app.autosave()
			var text := GameSaves.export_text(app.slot)
			if text.is_empty():
				note.text = "Nothing could be copied."
			else:
				Clipboard.set_text(text)
				note.text = "Backup of slot %d copied. Paste it into a note to keep it." % app.slot, Vector2(0, 40))
		copy.disabled = no_export != ""
		pg_save.add_child(copy)
		var export := Kit.button("Export to file", func():
			app.autosave()
			var slot: int = app.slot
			FilePicker.save("Save the house to a file", GameSaves.file_name(slot), func(path: String):
				if path == "":
					note.text = "Nothing was saved."
					return
				var r := GameSaves.export_file(slot, path)
				note.text = "Saved to %s." % path if r["ok"] else r["error"] + " Copy backup works too."), Vector2(0, 40))
		export.disabled = no_export != ""
		pg_save.add_child(export)
		if no_export != "":   # an iron-man house: the reason the two buttons are shut
			pg_save.add_child(_why(no_export))
		pg_save.add_child(Kit.button("Title screen", func(): app.show_title(), Vector2(0, 40)))
	elif mode == "battle":
		pages["general"].add_child(_why("The fight is saved as you go: closing the game now reopens it where you left off."))
	v.add_child(note)
	_select(last_tab if pages.has(last_tab) else str(MenuKit.rows("options")[0]["id"]), false)


func _why(text: String) -> Label:
	var l := Kit.label(text, 14, Kit.dim())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60] if s >= 3600 else "%d:%02d" % [s / 60, s % 60]


## Shows one tab's page and marks its button.
func _select(id: String, by_player: bool = true) -> void:
	if not pages.has(id):
		return
	tab = id
	last_tab = id
	for k in pages:
		(pages[k] as Control).visible = k == id
	Kit.clear(tab_row)
	for r in MenuKit.rows("options"):
		var rid := str(r["id"])
		if not pages.has(rid):
			continue
		var b := Kit.button(str(r["label"]), func(): _select(rid), Vector2(0, 36))
		b.name = "Tab_" + rid
		b.toggle_mode = false
		b.set_meta("tab_id", rid)
		if rid == id:
			if UiSkin.screen_active(b):
				b.set_meta("skin_on", true)
			else:
				b.add_theme_stylebox_override("normal", Kit.style(Color("#3d3860"), 6, Kit.ACCENT))
				b.add_theme_color_override("font_color", Kit.ACCENT)
		tab_row.add_child(b)
	if by_player and app != null and app.pad != null and app.pad.on:
		for b in tab_row.get_children():
			if b.get_meta("tab_id") == id:
				(b as Control).grab_focus.call_deferred()   # the focus stays on the tab just chosen


## One of a row of settings buttons, the one in use marked.
func _choice(row: HBoxContainer, text: String, on: bool, cb: Callable) -> void:
	var b := Kit.button(text, cb, Vector2(100, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on and UiSkin.screen_active(b):
		b.set_meta("skin_on", true)   # the crimson plank
	elif on:
		b.add_theme_stylebox_override("normal", Kit.style(Color("#3d3860"), 6, Kit.ACCENT))
		b.add_theme_color_override("font_color", Kit.ACCENT)
	row.add_child(b)
