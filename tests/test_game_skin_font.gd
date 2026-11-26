## The skin's pixel font (UiSkin font_for / font_size_for / dress_font, the "font" block of data/ui/skin.json, assets/fonts): the font and
## its licence load; sizes snap to whole multiples of the font's pixel and a text with no crisp size near it keeps the engine's font;
## body text never wears it; the Plain font option puts everything back; the high-contrast face; the validator finds each kind of
## break; ribbons, buttons and headings on the real screens wear it, and the log and paragraphs do not.
## Run: godot --headless --path . -s res://tests/test_game_skin_font.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_skin_font.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_font_save.json"
	UiSettings.scale = 1.0
	test_font_and_licence()
	test_sizes()
	test_roles_and_plain()
	test_dress_font()
	test_high_contrast()
	test_breaks()
	await test_screens()
	await test_plain_option()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin font tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _broken(edit: Callable) -> Array:
	var d: Dictionary = UiSkin.data().duplicate(true)
	edit.call(d)
	return UiSkin.validate(d)


func _set_scale(s: float) -> void:
	UiSettings.scale = s


func test_font_and_licence() -> void:
	UiSettings.scale = 1.0
	ok(UiSkin.validate().is_empty(), "the skin data, font block included, is valid: %s" % str(UiSkin.validate()))
	var f := UiSkin.font_file("regular")
	var b := UiSkin.font_file("bold")
	ok(f is FontFile and b is FontFile, "the regular and the bold font load")
	ok(f != null and f.has_char("A".unicode_at(0)) and f.has_char("z".unicode_at(0)) and f.has_char("9".unicode_at(0)), "they have letters and digits")
	var accents := ""
	for ch in ["é", "è", "ü", "ñ", "ö", "å", "ç", "ï", "ø", "ß"]:
		if f != null and not f.has_char(ch.unicode_at(0)):
			accents += ch
	ok(accents == "", "the Latin-1 letters the text uses are there (missing: %s)" % accents)
	ok(f != null and (f as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_NONE and (f as FontFile).hinting == TextServer.HINTING_NONE, "its pixels are not smoothed or hinted")
	var lic: String = str(UiSkin.font_block().get("licence", ""))
	ok(FileAccess.file_exists(lic) and FileAccess.get_file_as_string(lic).contains("SIL OPEN FONT LICENSE"), "the licence text is shipped with the font (%s)" % lic)
	ok(FileAccess.file_exists("res://assets/fonts/README.md") and FileAccess.get_file_as_string("res://assets/fonts/README.md").contains("Silkscreen"), "and a README names the font and where it came from")
	ok(UiSkin.font_file("nothing") == null, "an unknown face is no font")


func test_sizes() -> void:
	ok(UiSkin.font_crisp(16, 1.0) and UiSkin.font_crisp(8, 1.0) and UiSkin.font_crisp(24, 1.0), "at 100% sizes 8, 16 and 24 are whole multiples of the font's 8 pixels")
	ok(not UiSkin.font_crisp(20, 1.0) and not UiSkin.font_crisp(13, 1.0), "20 and 13 are not")
	ok(UiSkin.font_crisp(32, 1.25) and not UiSkin.font_crisp(16, 1.25) and not UiSkin.font_crisp(24, 1.25), "at 125% only 32 is (and 16 would blur)")
	ok(UiSkin.font_crisp(16, 1.5) and UiSkin.font_crisp(32, 1.5) and not UiSkin.font_crisp(8, 1.5) and not UiSkin.font_crisp(24, 1.5), "at 150% 16 and 32 are, 8 and 24 are not")
	ok(not UiSkin.font_crisp(0, 1.0), "size 0 is not")
	# every size the font hands out is crisp, near the want and big enough, at every text size
	var good := true
	for sc in UiSettings.scales():
		for want in range(6, 60):
			for role in ["title", "bar", "plate", "badge", "button", "tab", "heading"]:
				var s := UiSkin.font_size_for(role, want, sc)
				if s == 0:
					continue
				var spec := UiSkin.font_role(role)
				var fb := UiSkin.font_block()
				if not UiSkin.font_crisp(s, sc) or float(s) < float(want) * float(fb["min_ratio"]) - 1.0 or float(s) > float(want) * float(fb["max_ratio"]) + 1.0 or float(s) * sc < float(spec["min_px"]):
					good = false
					print("   bad size %d for %s want %d at %.2f" % [s, role, want, sc])
	ok(good, "every size handed out is crisp, within the ratios of the want and not below the role's least")
	ok(UiSkin.font_size_for("button", 16, 1.0) == 16, "a 16 button is 16")
	ok(UiSkin.font_size_for("button", 14, 1.0) == 16 and UiSkin.font_size_for("button", 13, 1.0) == 16, "14 and 13 snap to 16")
	ok(UiSkin.font_size_for("title", 20, 1.0) == 24, "a tie goes to the larger size for a title (20 is 24)")
	ok(UiSkin.font_size_for("button", 20, 1.0) == 16, "and to the smaller one for the rest (a button's 20 is 16)")
	ok(UiSkin.font_size_for("button", 16, 1.25) == 0 and UiSkin.font_size_for("title", 20, 1.25) == 0, "at 125% the usual sizes have no crisp one near, so the engine's font stays")
	ok(UiSkin.font_size_for("title", 30, 1.25) == 32, "but a big title there is 32")
	ok(UiSkin.font_size_for("button", 16, 1.5) == 16 and UiSkin.font_size_for("button", 14, 1.5) == 16, "at 150% 16 is crisp (24 screen pixels, three to a font pixel)")
	ok(UiSkin.font_size_for("badge", 11, 1.0) == 8 or UiSkin.font_size_for("badge", 11, 1.0) == 16, "a badge's 11 snaps to a whole size")
	ok(UiSkin.font_size_for("button", 0, 1.0) == 0, "a text that asks for no size gets none")
	# the pixel at the player's scale: the skin's art and the font step together
	for sc in UiSettings.scales():
		UiSettings.scale = sc
		var px := UiSkin.pixel()
		ok(absf(float(px) * sc - roundf(float(px) * sc)) < 0.001, "the skin pixel is whole screen pixels at %d%%" % int(sc * 100.0))
		var s16 := UiSkin.font_size_for("heading", 8 * px, sc)
		ok(s16 == 0 or UiSkin.font_crisp(s16, sc), "and a size of 8 skin pixels is crisp or left to the engine at %d%%" % int(sc * 100.0))
	UiSettings.scale = 1.0


func test_roles_and_plain() -> void:
	UiSettings.scale = 1.0
	for role in ["title", "bar", "plate", "badge", "button", "tab", "heading"]:
		ok(UiSkin.font_for(role) != null, "%s wears the pixel font" % role)
	ok(UiSkin.font_for("body") == null and UiSkin.font_size_for("body", 16, 1.0) == 0, "body text keeps the engine's font")
	ok(UiSkin.font_for("nonsense") == null, "an unknown role keeps it too")
	var pk: Array = UiSkin.pick("bar", 13, ThemeDB.fallback_font)
	ok(pk[0] == UiSkin.font_for("bar") and pk[1] == 16, "hand-drawn text asks for its font and size together")
	UiSettings.set_access("plain_font", true)
	ok(UiSettings.plain_font() and not UiSkin.font_on(), "the Plain font option turns the pixel font off")
	ok(UiSkin.font_for("title") == null and UiSkin.font_size_for("button", 16, 1.0) == 0, "every role is then the engine's")
	var pp: Array = UiSkin.pick("bar", 13, ThemeDB.fallback_font)
	ok(pp[0] == ThemeDB.fallback_font and pp[1] == 13, "and hand-drawn text takes the fallback at the size it asked")
	UiSettings.set_access("plain_font", false)
	ok(not UiSettings.plain_font() and UiSkin.font_on(), "off again, it is back")
	ok(UiSettings.ACCESS_KEYS.has("plain_font"), "plain_font is one of the accessibility keys")
	var cf := ConfigFile.new()
	cf.set_value("ui", "plain_font", "yes")
	cf.save(UiSettings.path)
	ok(not UiSettings.plain_font(), "a damaged value reads as off")
	DirAccess.remove_absolute(UiSettings.path)
	ok(not UiSettings.plain_font(), "and there is no option without a file")


func test_dress_font() -> void:
	UiSettings.scale = 1.0
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	ok(UiSkin.dress_font(l, "button"), "a label asking for 14 is dressed")
	ok(l.get_theme_font_size("font_size") == 16 and l.get_theme_font("font") == UiSkin.font_for("button") and l.has_meta("skin_pixel_font"), "in the pixel font at 16")
	_set_scale(1.25)
	ok(not UiSkin.dress_font(l, "button", 14), "at 125% the same text is not")
	ok(l.get_theme_font("font") != UiSkin.font_for("button") and not l.has_meta("skin_pixel_font"), "and gets the engine's font back")
	ok(l.get_theme_font_size("font_size") == 14, "and the size it had comes back")
	UiSkin.dress_font(l, "button", 14)
	l.add_theme_font_size_override("font_size", 15)   # the caller sets another size later
	_set_scale(1.25)
	UiSkin.dress_font(l, "button", 15)
	ok(l.get_theme_font_size("font_size") == 15, "a size the caller set since is left alone")
	UiSettings.scale = 1.0
	var b := Button.new()
	b.text = "Go"
	ok(UiSkin.dress_font(b, "button") and b.get_theme_font_size("font_size") > 0, "a button is dressed (its own size is the default)")
	UiSettings.set_access("plain_font", true)
	var b2 := Button.new()
	ok(not UiSkin.dress_font(b2, "button") and not b2.has_meta("skin_pixel_font"), "under Plain font nothing is dressed")
	UiSettings.set_access("plain_font", false)
	# too narrow: back to the engine's font, at the size the caller wanted
	var nb := Button.new()
	nb.text = "A long enough label that cannot fit"
	nb.add_theme_font_size_override("font_size", 16)
	root.add_child(nb)
	nb.custom_minimum_size = Vector2(60, 30)
	nb.clip_text = true
	UiSkin.dress_font(nb, "button")
	nb.size = Vector2(60, 30)
	UiSkin._refit(nb)
	ok(not nb.has_meta("skin_pixel_font") and nb.get_theme_font_size("font_size") == 16, "a button whose room is too narrow for the words goes back to the engine's font at its own size")
	nb.size = Vector2(900, 30)
	UiSkin.dress_font(nb, "button")
	ok(not nb.has_meta("skin_pixel_font"), "and stays so while its text is the same")
	nb.text = "OK"
	UiSkin.dress_font(nb, "button")
	ok(nb.has_meta("skin_pixel_font"), "a new text gets another try")
	nb.queue_free()
	# headings: large single lines only
	var h := Label.new()
	h.add_theme_font_size_override("font_size", 20)
	UiSkin.dress_heading(h)
	ok(h.has_meta("skin_pixel_font"), "a large one-line label is a heading")
	var para := Label.new()
	para.add_theme_font_size_override("font_size", 20)
	para.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiSkin.dress_heading(para)
	ok(not para.has_meta("skin_pixel_font"), "a wrapping paragraph is not")
	var small := Label.new()
	small.add_theme_font_size_override("font_size", 14)
	UiSkin.dress_heading(small)
	ok(not small.has_meta("skin_pixel_font"), "nor is small text")
	# a kit button off the skin (a phone, a compact window) is not touched
	UiSettings.force_touch = 1
	var host := Control.new()
	host.set_meta("pane", true)
	root.add_child(host)
	var pb := PanelSkin.button(host, "Build", func(): pass)
	ok(not pb.has_meta("skin_pixel_font"), "a button of a pane that is not skinned keeps the engine's font")
	UiSettings.force_touch = -1
	host.queue_free()


func test_high_contrast() -> void:
	UiSettings.scale = 1.0
	ok(UiSkin.font_face("bar") == "regular" and UiSkin.font_face("title") == "bold", "each role has its face")
	UiSettings.set_access("high_contrast", true)
	ok(UiSkin.font_face("bar") == "bold" and UiSkin.font_face("button") == "bold", "in high contrast every role takes the heavier face")
	ok(UiSkin.font_for("bar") == UiSkin.font_file("bold"), "and the font handed out is it")
	ok(UiSkin.variant() == "high_contrast" and UiSkin.validate().is_empty(), "the data still validates, the font's contrast figures held in both palettes")
	var d: Dictionary = UiSkin.data()
	for pair in d["font"]["contrast"]:
		var fg := Color(str(d["variants"]["high_contrast"][pair["fg"]]))
		var bg := Color(str(d["variants"]["high_contrast"][pair["bg"]]))
		ok(UiSkin.contrast(fg, bg) >= float(pair["min_hc"]), "%s on %s (%s) holds %.1f to 1 in high contrast" % [pair["fg"], pair["bg"], pair["why"], float(pair["min_hc"])])
	UiSettings.set_access("high_contrast", false)
	ok(UiSkin.font_face("bar") == "regular", "off again, the faces are the data's")


func test_breaks() -> void:
	ok(_broken(func(d): d.erase("font")).size() > 0, "a missing font block is found")
	ok(_broken(func(d): d["font"] = 3).size() > 0, "a font block that is not an object is found")
	ok(_broken(func(d): d["font"]["enabled"] = "yes").size() > 0, "an enabled that is not true or false is found")
	ok(_broken(func(d): d["font"]["regular"] = "res://assets/fonts/nothing.ttf").size() > 0, "a font file that is not there is found")
	ok(_broken(func(d): d["font"]["bold"] = "").size() > 0, "a bold font with no path is found")
	ok(_broken(func(d): d["font"]["regular"] = "res://assets/fonts/README.md").size() > 0, "a font that is not a .ttf or .otf is found")
	ok(_broken(func(d): d["font"]["licence"] = "res://assets/fonts/nothing.txt").size() > 0, "a missing licence text is found")
	ok(_broken(func(d): d["font"]["native"] = 0).size() > 0, "a font pixel of none is found")
	ok(_broken(func(d): d["font"]["native"] = 7.5).size() > 0, "a font pixel that is not whole is found")
	ok(_broken(func(d): d["font"]["min_ratio"] = 1.5).size() > 0, "a smallest ratio above 1 is found")
	ok(_broken(func(d): d["font"]["max_ratio"] = 0.5).size() > 0, "a largest ratio below 1 is found")
	ok(_broken(func(d): d["font"]["heading_min"] = 0).size() > 0, "a heading size of none is found")
	ok(_broken(func(d): d["font"]["high_contrast_face"] = "italic").size() > 0, "a high-contrast face that is no face is found")
	ok(_broken(func(d): d["font"]["roles"].erase("button")).size() > 0, "a missing role is found")
	ok(_broken(func(d): d["font"]["roles"]["title"]["face"] = "light").size() > 0, "a role with an unknown face is found")
	ok(_broken(func(d): d["font"]["roles"]["bar"]["min_px"] = 0).size() > 0, "a role with no least size is found")
	ok(_broken(func(d): d["font"]["roles"]["tab"]["use"] = "yes").size() > 0, "a role's use that is not true or false is found")
	ok(_broken(func(d): d["font"]["roles"]["body"]["use"] = true).size() > 0, "long text in the pixel font is refused")
	ok(_broken(func(d): d["font"]["contrast"] = []).size() > 0, "a font with no contrast figures is found")
	ok(_broken(func(d): d["font"]["contrast"].append({"fg": "ink", "bg": "ink", "min": 7.0, "min_hc": 10.0})).size() > 0, "text of one colour on itself is found")
	ok(_broken(func(d): d["font"]["contrast"].append({"fg": "nothing", "bg": "ink", "min": 1.0, "min_hc": 1.0})).size() > 0, "a pair naming no colour is found")
	ok(_broken(func(d): d["font"]["contrast"].append({"fg": "gold_hi"})).size() > 0, "a pair with no figures is found")
	ok(_broken(func(d): d["variants"]["high_contrast"]["gold_hi"] = "#7a5a10").size() > 0, "a high-contrast ribbon title that is too dim is found")
	ok(_broken(func(d): d["variants"]["standard"]["wood_text"] = "#6b4a2b").size() > 0, "a plank's words too dim in the standard palette are found")
	var msg := str(_broken(func(d): d["font"]["roles"]["body"]["use"] = true))
	ok(msg.contains("body"), "and the message names the role")


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _pixel_nodes(n: Node) -> Array:
	return _all(n, []).filter(func(c): return c is Control and (c as Control).has_meta("skin_pixel_font"))


func _start() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false


func test_screens() -> void:
	UiSettings.force_touch = -1
	await _start()
	app.show_title()
	await _frames(4)
	var t: Control = app.current
	var ribbon_label: Label = null
	for n in _all(t, []):
		if n is PanelContainer and n.has_meta("skin_ribbon"):
			ribbon_label = n.get_child(0)
	ok(ribbon_label != null and ribbon_label.has_meta("skin_pixel_font") and ribbon_label.get_theme_font("font") == UiSkin.font_for("title"), "the title screen's ribbon is in the pixel font")
	ok(ribbon_label != null and UiSkin.font_crisp(ribbon_label.get_theme_font_size("font_size")), "at a crisp size (%d)" % (ribbon_label.get_theme_font_size("font_size") if ribbon_label != null else 0))
	t._show_page("new")   # the founding form and the slots: the widest rows of the title
	await _frames(3)
	var btns := _all(t, []).filter(func(n): return n is Button and (n as Button).text != "" and (n as Button).is_visible_in_tree())
	ok(btns.any(func(b): return b.has_meta("skin_pixel_font")), "some of its planks are in the pixel font")
	for b in btns:
		if b.has_meta("skin_pixel_font"):
			var w: float = (b as Button).get_theme_font("font").get_string_size((b as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1, (b as Button).get_theme_font_size("font_size")).x
			if w > (b as Button).size.x - (b as Button).get_theme_stylebox("normal").get_minimum_size().x + 0.5:
				ok(false, "pixel text of '%s' wider than its button" % (b as Button).text)
	app.new_game("Tess", "warrior", "faetouched", 7)
	app.show_state()
	await _frames(4)
	var life: Control = app.current
	ok(_pixel_nodes(life).size() >= 10, "the life screen has pixel text on its ribbon, headings and buttons (%d)" % _pixel_nodes(life).size())
	var bars := _all(life, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
	ok(bars.size() >= 2, "it has skinned bars")
	var long_text := _all(life, []).filter(func(n): return (n is RichTextLabel) or (n is Label and (n as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and (n as Label).text.length() > 30))
	for n in long_text:
		if n.has_meta("skin_pixel_font"):
			print("   long text in the pixel font: ", n.get_class(), " '", n.get("text"), "' ", n.get_path())
	ok(long_text.size() > 0 and long_text.all(func(n): return not n.has_meta("skin_pixel_font")), "paragraphs, the log and the tips keep the engine's font (%d of them)" % long_text.size())
	var rich := _all(life, []).filter(func(n): return n is RichTextLabel)
	ok(rich.all(func(r): return not r.has_theme_font_override("normal_font")), "no rich text carries the pixel font")
	var life_pixel := _pixel_nodes(life).size()
	# the text size changes what is crisp: at 125% the usual sizes fall back
	app.set_ui_scale(1.25)
	await _frames(4)
	var at125 := _pixel_nodes(app.current).filter(func(n): return UiSkin.font_crisp(n.get_theme_font_size("font_size"), 1.25))
	ok(at125.size() == _pixel_nodes(app.current).size(), "at 125%% whatever is in the pixel font is at a crisp size (%d)" % at125.size())
	ok(_pixel_nodes(app.current).size() < life_pixel, "and most of it has gone back to the engine's font")
	app.set_ui_scale(1.5)
	await _frames(4)
	var at150 := _pixel_nodes(app.current)
	ok(at150.size() > 0 and at150.all(func(n): return UiSkin.font_crisp(n.get_theme_font_size("font_size"), 1.5)), "at 150%% it is back, at crisp sizes (%d)" % at150.size())
	app.set_ui_scale(1.0)
	await _frames(3)
	# phone layout: the screens are skinned there too, and the skin keeps to the same rules
	UiSettings.force_touch = 1
	app.show_state()
	await _frames(4)
	var ph := _pixel_nodes(app.current)
	ok(ph.all(func(n): return UiSkin.font_crisp(n.get_theme_font_size("font_size"))), "on the touch layout pixel text is crisp too (%d)" % ph.size())
	UiSettings.force_touch = -1


func test_plain_option() -> void:
	UiSettings.scale = 1.0
	app.show_state()
	await _frames(4)
	var before := _pixel_nodes(app.current).size()
	ok(before > 0, "there is pixel text to switch off (%d)" % before)
	var access_menu: Control = app.open_menu()
	await _frames(3)
	access_menu._select("access")   # Plain font is on the Access tab
	await _frames(2)
	var plain_btn: Button = null
	var seen_label := false
	for n in _all(app.current, []):
		if n is Label and (n as Label).text == "Plain font":
			seen_label = true
	ok(seen_label, "the menu's Accessibility row lists Plain font")
	app.set_access("plain_font", true)
	ok(UiSettings.plain_font(), "choosing it is stored")
	await _frames(4)
	ok(_pixel_nodes(app.current).is_empty(), "every text on the menu is back in the engine's font")
	app.show_state()
	await _frames(4)
	var f: Font = UiSkin.font_file("regular")
	var b: Font = UiSkin.font_file("bold")
	var leaks := _all(app.current, []).filter(func(n): return n is Control and n.has_theme_font_override("font") and (n.get_theme_font("font") == f or n.get_theme_font("font") == b))
	ok(_pixel_nodes(app.current).is_empty() and leaks.is_empty(), "so is the life screen, with no control left on the pixel font (%d)" % leaks.size())
	app.set_access("plain_font", false)
	await _frames(2)
	app.show_state()
	await _frames(4)
	ok(_pixel_nodes(app.current).size() > 0, "turned off again the pixel font is back")
	ok(plain_btn == null, "(done)")
