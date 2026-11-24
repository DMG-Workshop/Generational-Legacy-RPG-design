## Throwaway art-direction mock-up (docs/ART_DIRECTION.md). NOT part of the game or its tests.
##
## Draws the open world twice with the real renderer, at the same place and zoom: "before" is the interface as it is,
## "after" hides it and draws the proposed look over the same world: chunky pixel panels on parchment with ink lines and gold
## studs (the rulebook look), inset item slots (the Minecraft inventory), crimson ribbon titles, segmented bars, a wooden
## header, a warm light and a vignette. Everything here is drawn from code, at one UI pixel of 2 screen pixels, so it shows
## what the look is, not what it would cost to do it everywhere. Run under a virtual display:
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/mockup.gd -- [out=/tmp/mockup]
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const ActionSlot := preload("res://ui/play/action_slot.gd")
const ItemIcon := preload("res://ui/play/item_icon.gd")
const MinimapPane := preload("res://ui/play/minimap_pane.gd")
const Art := preload("res://tools/mockup_art.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const TMP := "user://mockup_tmp/"

var app: Node
var d: GameDynasty
var out := "/tmp/mockup"


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(TMP)
	GameDynasty.save_path = TMP + "save.json"
	UiSettings.path = TMP + "settings.cfg"
	UiSettings.scale = 1.0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", true)
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	_game()
	var scr: Control = await _world()
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/before.png")
	# the same scene with the interface taken away and the proposed one drawn over it
	for c in scr.get_children():
		if c is HBoxContainer or c is VBoxContainer or c.has_meta("pane"):
			c.visible = false
	var ui := MockUi.new()
	ui.scr = scr
	ui.d = d
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.z_index = 50
	root.add_child(ui)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/after.png")
	print("drew before.png and after.png in ", out)
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP + f)
	quit(0)


## The house the screenshots use: a warrior of seed 77 with two companions.
func _game() -> void:
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	d = app.dynasty
	d.pending_event = {}
	d.heir.level = 18
	d.heir.gold = 1794
	d.world.visit("kingshold")
	d.world.weather_id = "clear"
	for id in ["bren_cask", "sister_oriel"]:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 18, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	d.found_family()
	d.journal.clear()
	d.heir.equipment["weapon"] = "steel_sword"
	d.heir.equipment["armor"] = "chainmail"


## The home town at twice the usual zoom (a tile is 32 screen pixels, so a pixel of the world is two of the screen's, as the interface's are).
func _world() -> Control:
	var spot := Vector2i(160, 296)
	d.world.visit("hearthmere")
	app.show_sandbox()
	await _frames(3)
	var scr: Control = app.current
	scr.set_process(false)
	d.world_seconds = 0.0
	d.clock_carry = 0.0
	scr.sb.heir = spot
	scr.sb.creatures.clear()
	scr.sb.companions = GameCompanions.agents_for(d, float(spot.x) + 0.5, float(spot.y) + 0.5)
	scr._warm_figures()
	scr.sb.creatures.append(GameBehaviour.new_agent(900, "wolf", float(spot.x) - 4.5, float(spot.y) + 1.5))
	scr.zoom = 2.0
	scr.cam = Vector2.ZERO
	scr._process(0.0)
	scr.queue_redraw()
	await _frames(2)
	scr.overlay.queue_redraw()
	await _frames(2)
	return scr


# ---------------------------------------------------------------- the proposed interface, drawn over the world

class MockUi extends Control:
	var scr: Control
	var d: GameDynasty
	var font: Font = ThemeDB.fallback_font
	var vignette: ImageTexture
	var map_tex: ImageTexture

	func _ready() -> void:
		vignette = Art.vignette_tex()
		var img := MinimapPane.make_image(d, scr.sb.heir.x, scr.sb.heir.y, 20)
		map_tex = ImageTexture.create_from_image(img)

	func _text(p: Vector2, t: String, size: int, c: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
		if outline.a > 0.0:
			font.draw_string_outline(get_canvas_item(), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, outline)
		font.draw_string(get_canvas_item(), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

	func _shadow(r: Rect2) -> void:
		draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.35))

	func _panel(r: Rect2) -> void:
		_shadow(r)
		draw_texture(Art.panel_tex(int(r.size.x), int(r.size.y)), r.position)

	func _ribbon(r: Rect2, t: String, size: int = 18) -> void:
		draw_texture(Art.ribbon_tex(int(r.size.x), int(r.size.y)), r.position)
		_text(r.position + Vector2(10, r.size.y * 0.5 + size * 0.3), t, size, Art.GOLD, Art.CRIMSON_DK)

	func _glyph(rows: Array, at: Vector2, scale: int, c: Color) -> void:
		var tex := Art.glyph_tex(rows)
		for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			draw_texture_rect(tex, Rect2(at + o, Vector2(8, 8) * scale), false, Art.INK)
		draw_texture_rect(tex, Rect2(at, Vector2(8, 8) * scale), false, c)

	func _draw() -> void:
		var h := d.heir
		# a warm light over the world, then the vignette
		draw_rect(Rect2(Vector2(0, 56), Vector2(1280, 664)), Color(1.0, 0.82, 0.5, 0.07))
		draw_texture_rect(vignette, Rect2(Vector2.ZERO, Vector2(1280, 720)), false)
		# the header: planks, the Menu and the map, the eight slots and the day
		draw_texture(Art.header_tex(1280, 56), Vector2.ZERO)
		var x := 10.0
		for pair in [["menu", false], ["map", false]]:
			draw_texture(Art.slot_tex(44, false), Vector2(x, 6))
			_glyph(_rows(str(pair[0])), Vector2(x + 6, 12), 4, Color("#e9dfc8"))
			x += 52.0
		x += 10.0
		var slots: Array = ActionSlot.data()["slots"]
		for n in slots.size():
			var def: Dictionary = slots[n]
			var lit := str(def["id"]) == "build"
			draw_texture(Art.slot_tex(44, lit), Vector2(x, 6))
			var col := Color(float(def["color"][0]), float(def["color"][1]), float(def["color"][2]))
			if str(def["id"]) == "cast":
				col = Color(col.r, col.g, col.b, 0.4)
			_glyph(_rows(str(def["glyph"])), Vector2(x + 6, 12), 4, col)
			_text(Vector2(x + 4, 18), str(n + 1), 11, Art.PARCH_HI, Art.INK)
			x += 48.0
		var tag := Rect2(Vector2(x + 14, 10), Vector2(1280.0 - x - 28.0, 36))
		draw_texture(Art.panel_tex(int(tag.size.x) / 2 * 2, 36), tag.position)
		_text(tag.position + Vector2(14, 25), "Day 1, 07:11  ·  clear  ·  You are in Hearthmere. Use to enter the forge.", 15, Art.INK)
		# the status pane
		var st := Rect2(Vector2(12, 68), Vector2(270, 236))
		_panel(st)
		_ribbon(Rect2(st.position + Vector2(10, 10), Vector2(st.size.x - 20, 30)), h.name, 19)
		_text(st.position + Vector2(18, 62), "Level %d  %s" % [h.level, str(GameData.classes.get(h.class_id, {}).get("name", h.class_id))], 15, Art.CRIMSON_DK)
		var rows := [
			[Art.HEART, Art.HP_C, float(h.hp) / float(h.max_hp()), "%d / %d" % [h.hp, h.max_hp()]],
			[Art.GEM, Art.MP_C, float(h.mp) / float(maxi(1, h.max_mp())), "%d / %d" % [h.mp, h.max_mp()]],
			[Art.POUCH, Art.CARRY_C, GameCarry.carried(h) / maxf(1.0, GameCarry.capacity(h)), GameCarry.summary(h)],
		]
		var y := 78.0
		for row in rows:
			_glyph(row[0], st.position + Vector2(16, y + 3), 2, (row[1] as Array)[1])
			draw_texture(Art.bar_tex(210, 22, row[2], row[1]), st.position + Vector2(40, y))
			_text(st.position + Vector2(48, y + 17), str(row[3]), 13, Color.WHITE, Art.INK)
			y += 36.0
		_glyph(Art.COIN, st.position + Vector2(16, y + 6), 2, Art.GOLD)
		_text(st.position + Vector2(40, y + 22), "%s gold" % GameText.num(h.gold), 16, Art.INK)
		# the nearby map in a wooden frame
		var mf := Rect2(Vector2(1070, 68), Vector2(198, 232))
		_shadow(mf)
		draw_rect(mf, Art.INK)
		draw_rect(mf.grow(-2), Art.WOOD)
		draw_rect(mf.grow(-4), Art.WOOD_HI)
		draw_rect(mf.grow(-6), Art.WOOD)
		_ribbon(Rect2(mf.position + Vector2(8, 8), Vector2(mf.size.x - 16, 26)), "Nearby", 16)
		var pic := Rect2(mf.position + Vector2(17, 42), Vector2(164, 164))
		draw_rect(pic.grow(3), Art.INK)
		draw_rect(pic.grow(1), Art.GOLD_DK)
		draw_texture_rect(map_tex, pic, false)
		draw_rect(Rect2(pic.position + Vector2(78, 78), Vector2(8, 8)), Art.GOLD)
		draw_rect(Rect2(pic.position + Vector2(78, 78), Vector2(8, 8)), Art.INK, false, 1.0)
		_text(mf.position + Vector2(18, 224), "Open ground.", 13, Art.PARCH_HI, Art.INK)
		# the journal
		var jr := Rect2(Vector2(12, 506), Vector2(460, 202))
		_panel(jr)
		_ribbon(Rect2(jr.position + Vector2(10, 10), Vector2(150, 30)), "Journal", 19)
		var lines := ["You walk into Hearthmere.", "Bren Cask takes the watch.", "A wolf prowls near the road.", "The forge is warm. Use to work."]
		for n in lines.size():
			_text(jr.position + Vector2(20, 66 + n * 26), "·  " + str(lines[n]), 15, Art.INK)
		# the character sheet
		var cs := Rect2(Vector2(1006, 316), Vector2(262, 322))
		_panel(cs)
		_ribbon(Rect2(cs.position + Vector2(10, 10), Vector2(cs.size.x - 20, 30)), "%s  ·  Warrior %d" % [h.name, h.level], 17)
		var fig: Texture2D = SpriteArt.figure(h)
		var por := Rect2(cs.position + Vector2(16, 52), Vector2(96, 168))
		draw_texture(Art.slot_tex(96, false), por.position)
		draw_rect(Rect2(por.position + Vector2(2, 2), Vector2(92, 164)), Color("#6a553d"))
		if fig != null:
			draw_texture_rect(fig, Rect2(por.position + Vector2(0, 8), Vector2(24, 40) * 4), false)
		var stats := [["STR", "str"], ["MAG", "mag"], ["AGI", "agi"], ["VIT", "vit"]]
		for n in stats.size():
			var sp := cs.position + Vector2(126, 52 + n * 42)
			draw_texture(Art.inset_tex(120, 36, false), sp)
			_text(sp + Vector2(10, 24), str(stats[n][0]), 14, Art.PARCH_HI, Art.INK)
			_text(sp + Vector2(76, 25), str(int(round(h.stat(str(stats[n][1]))))), 18, Color.WHITE, Art.INK)
		var gear := ["weapon", "armor", "trinket"]
		for n in gear.size():
			var gp := cs.position + Vector2(16 + n * 54, 236)
			draw_texture(Art.slot_tex(48, false), gp)
			var worn := GameItems.equipped(h, str(gear[n]))
			if worn != "":
				draw_texture_rect(ItemIcon.texture(worn), Rect2(gp + Vector2(6, 6), Vector2(36, 36)), false)
		draw_texture(Art.inset_tex(60, 48, false), cs.position + Vector2(186, 236))
		_text(cs.position + Vector2(200, 266), "Pack", 15, Art.PARCH_HI, Art.INK)
		_text(cs.position + Vector2(16, 306), "weapon · armor · trinket", 12, Art.CRIMSON_DK)

	func _rows(name: String) -> Array:
		return ActionSlot.icons()["glyphs"].get(name, [])
