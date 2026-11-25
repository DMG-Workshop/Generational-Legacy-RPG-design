## The waygates' art (ui/play/gate_art.gd, data/art/gates.json; rendering only): an arch is 3 tiles by 4 (48 by 64 pixels), outlined in 1 pixel, with
## no stray pixel and a clear passage; dark, flickering and lit differ in their light (shimmer in the opening, lit runes), ruined ones are cracked and mossy
## and a gate's slot states show in its runes; each look is made once and kept; the glow layer asks for lit and flickering arches only; the picture follows the
## gate's state as the family mends it; painting draws no die; a realm's arrival ground paints in the realm's palette; breaking the data is caught.
## Run: godot --headless --path . -s res://tests/test_game_gate_art.gd
extends SceneTree

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_images()
	test_states()
	test_memo_and_follow()
	test_glow_and_marks()
	test_arrival_paint()
	test_data_breaks()
	print("gate art tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _count(img: Image, pred: Callable) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if pred.call(img.get_pixel(x, y)):
				n += 1
	return n


func _same(a: Image, b: Image) -> bool:
	return a.get_data() == b.get_data()


func test_images() -> void:
	ok(GateArt.validate().is_empty(), "the art passes its own check: %s" % str(GateArt.validate()))
	var whole := ["whole", "whole", "whole", "whole", "whole"]
	var runes := ["road", "door", "light", "bind", "return"]
	var img := GateArt.image("lit", whole, runes, false, 3)
	ok(img.get_width() == 48 and img.get_height() == 64, "an arch is 48 by 64 pixels, three tiles by four")
	var outline := Color.html(str(GateArt.data()["colors"]["outline"]))
	ok(_count(img, func(c): return c.is_equal_approx(outline)) > 150, "it has its outline")
	# the passage is open at the bottom middle: a walker's tile
	var blocked := 0
	for y in range(48, 60):
		for x in range(19, 29):
			if img.get_pixel(x, y).a >= 1.0:
				blocked += 1
	ok(blocked <= 12, "the passage at the bottom middle is open (%d solid pixels)" % blocked)
	# the legs stand on the bottom rows, the ring's top is above the middle
	var top := 64
	for y in 64:
		for x in 48:
			if img.get_pixel(x, y).a > 0.0:
				top = mini(top, y)
	ok(top >= 4 and top <= 12, "the ring rises to the top of the picture (row %d)" % top)
	# light from the top left: the left edge of a leg is lighter than its right edge
	var hi := Color.html(str(GateArt.data()["colors"]["stone_hi"]))
	var lo := Color.html(str(GateArt.data()["colors"]["stone_lo"]))
	var left_lit := 0
	var right_dark := 0
	for y in range(36, 56):
		if img.get_pixel(3, y).is_equal_approx(hi):
			left_lit += 1
		if img.get_pixel(11, y).is_equal_approx(lo):
			right_dark += 1
	ok(left_lit >= 12 and right_dark >= 8, "light falls from the top left: a leg is lit on its left, shaded on its right")


func test_states() -> void:
	var whole := ["whole", "whole", "whole", "whole", "whole"]
	var runes := ["road", "door", "light", "bind", "return"]
	var lit := GateArt.image("lit", whole, runes, false, 3)
	var flick := GateArt.image("flickering", ["whole", "worn", "whole", "worn", "whole"], runes, false, 3)
	var dark := GateArt.image("dark", whole, runes, false, 3)
	var shim := Color.html(str(GateArt.data()["colors"]["shimmer"]))
	var glass := func(c: Color): return c.a > 0.0 and c.a < 1.0
	var gl := _count(lit, glass)
	var gf := _count(flick, glass)
	var gd := _count(dark, glass)
	ok(gl > 300 and gf > 100 and gf < gl and gd == 0, "a lit arch has a full shimmer in its opening, a flickering one a thin one, a dark one none (%d, %d, %d)" % [gl, gf, gd])
	var rune_lit := Color.html(str(GateArt.data()["colors"]["rune_lit"]))
	var silver := Color.html(str(GateArt.data()["colors"]["silver"]))
	ok(_count(lit, func(c): return c.is_equal_approx(rune_lit)) > 20 and _count(lit, func(c): return c.is_equal_approx(silver)) == 0, "lit runes glow gold")
	ok(_count(dark, func(c): return c.is_equal_approx(silver)) > 20 and _count(dark, func(c): return c.is_equal_approx(rune_lit)) == 0, "a dark one shows its silver inlay plainly, unlit")
	# a ruined gate is cracked and mossy; a whole one little
	var ruin := GateArt.image("dark", ["stripped", "broken", "stripped", "broken", "stripped"], runes, true, 3)
	var moss := Color.html(str(GateArt.data()["colors"]["moss"]))
	var crack := Color.html(str(GateArt.data()["colors"]["stone_dk"]))
	ok(_count(ruin, func(c): return c.is_equal_approx(moss)) > _count(dark, func(c): return c.is_equal_approx(moss)) + 8, "a ruined gate is mossier")
	ok(_count(ruin, func(c): return c.is_equal_approx(crack)) > _count(dark, func(c): return c.is_equal_approx(crack)) + 15, "and more cracked (stripped runes are empty grooves)")
	ok(_count(ruin, func(c): return c.a > 0.0) < _count(dark, func(c): return c.a > 0.0), "and has a piece of its ring fallen")
	ok(not _same(ruin, dark) and not _same(lit, dark) and not _same(lit, flick), "every look is a picture of its own")
	# the slot states show in the runes
	var a := GateArt.image("dark", ["whole", "whole", "whole", "whole", "whole"], runes, false, 3)
	var b := GateArt.image("dark", ["whole", "worn", "whole", "whole", "whole"], runes, false, 3)
	var c := GateArt.image("dark", ["whole", "broken", "whole", "whole", "whole"], runes, false, 3)
	var e := GateArt.image("dark", ["whole", "stripped", "whole", "whole", "whole"], runes, false, 3)
	ok(not _same(a, b) and not _same(b, c) and not _same(c, e), "a whole, a worn, a broken and a stripped slot are drawn differently")
	# the same call is the same picture: nothing is random
	ok(_same(GateArt.image("lit", whole, runes, true, 9), GateArt.image("lit", whole, runes, true, 9)), "the same look paints the same pixels twice")
	ok(not _same(GateArt.image("dark", ruin_states(), runes, true, 1), GateArt.image("dark", ruin_states(), runes, true, 2)), "another gate's cracks fall elsewhere")
	for seed_variant in [1, 2, 3]:
		for st in [whole, ruin_states()]:
			var im := GateArt.image("dark", st, runes, true, seed_variant)
			var stray := 0
			for y in 64:
				for x in 48:
					if im.get_pixel(x, y).a > 0.0:
						var nb := 0
						for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var q: Vector2i = Vector2i(x, y) + o
							if q.x >= 0 and q.y >= 0 and q.x < 48 and q.y < 64 and im.get_pixel(q.x, q.y).a > 0.0:
								nb += 1
						if nb == 0:
							stray += 1
			ok(stray == 0, "no stray pixel (variant %d)" % seed_variant)
	# the picture of one rune
	var r1 := GateArt.rune_texture("road", "whole", true).get_image()
	var r2 := GateArt.rune_texture("road", "stripped", true).get_image()
	ok(r1.get_width() == 7 and r1.get_height() == 9 and not _same(r1, r2), "a rune's little picture is 7 by 9 and shows its state")
	ok(GateArt.rune_texture("road", "whole", true) == GateArt.rune_texture("road", "whole", true), "and is made once")
	ok(not _same(GateArt.rune_texture("road", "whole", true).get_image(), GateArt.rune_texture("deep", "whole", true).get_image()), "a rune has its own shape")


func ruin_states() -> Array:
	return ["stripped", "broken", "stripped", "broken", "stripped"]


func test_memo_and_follow() -> void:
	var d := GameDynasty.new_game(21, "Tess", "warrior", "faetouched", "human")
	var t1 := GateArt.texture_of(d, "hearthmere_arch")
	var t2 := GateArt.texture_of(d, "hearthmere_arch")
	ok(t1 == t2, "a gate's texture is made once and kept")
	var rng := d.rng.state
	GateArt.texture_of(d, "highcrag_arch")
	ok(d.rng.state == rng, "painting draws no die of the dynasty's")
	# the picture follows the state: mending a ruined gate changes it, then it is lit
	var hc := GateArt.texture_of(d, "highcrag_arch")
	var fixed := {}
	for i in GameGates.slot_count("highcrag_arch"):
		fixed["highcrag_arch:%d" % i] = 0
	d.gates["fixed"] = fixed
	var after := GateArt.texture_of(d, "highcrag_arch")
	ok(after != hc and GameGates.state(d, "highcrag_arch")["mode"] == "lit", "a gate mended is another picture, and lit")
	# years on it wears and is another picture again
	d.world.year = 120.0
	ok(GateArt.texture_of(d, "highcrag_arch") != after, "and wears in the picture as the years go")
	# the area it covers
	var r := GateArt.rect_of(d, "hearthmere_arch")
	var t := GameGates.tile_of(d, "hearthmere_arch")
	ok(r == Rect2i(t.x - 1, t.y - 3, 3, 4), "it covers three tiles by four, the passage tile at the bottom middle")
	var seen := GateArt.in_view(d, Rect2i(t.x - 5, t.y - 5, 10, 10))
	ok(seen.size() == 1 and str(seen[0]["id"]) == "hearthmere_arch", "the view finds the arch in it")
	ok(GateArt.in_view(d, Rect2i(0, 0, 4, 4)).is_empty(), "and none where there is none")


func test_glow_and_marks() -> void:
	var d := GameDynasty.new_game(21, "Tess", "warrior", "faetouched", "human")
	var t := GameGates.tile_of(d, "hearthmere_arch")
	var lit := GateArt.glow_sources(d, Rect2i(t.x - 5, t.y - 5, 10, 10))
	ok(lit.size() == 1 and float(lit[0]["spec"]["strength"]) > 0.5, "a lit arch is a source of glow at night")
	var dk := GameGates.tile_of(d, "highcrag_arch")
	ok(GateArt.glow_sources(d, Rect2i(dk.x - 5, dk.y - 5, 10, 10)).is_empty(), "a dark one is not")
	# a flickering one shines less
	var y := -1
	for yr in range(1, 200):
		if str(GameGates.state_in(d, "hearthmere_arch", yr)["mode"]) == "flickering":
			y = yr
			break
	if y > 0:
		d.world.year = float(y)
		var fl := GateArt.glow_sources(d, Rect2i(t.x - 5, t.y - 5, 10, 10))
		ok(fl.size() == 1 and float(fl[0]["spec"]["strength"]) < float(lit[0]["spec"]["strength"]), "a flickering arch glows less than a lit one")
	d.world.year = 0.0
	var sources := WorldLook.glow_sources(d, null, Rect2i(t.x - 5, t.y - 5, 10, 10))
	ok(sources.any(func(s): return float(s["spec"]["strength"]) == float(lit[0]["spec"]["strength"])), "the glow layer's sources include the arch")
	# the maps' colours differ by state
	ok(GateArt.icon_color("lit") != GateArt.icon_color("dark") and GateArt.icon_color("flickering") != GateArt.icon_color("lit"), "the maps mark a gate in the colour of its state")


func test_arrival_paint() -> void:
	var holder := Control.new()
	root.add_child(holder)
	for r in GameRealms.ids():
		if not GameRealms.gateable(str(r)):
			continue
		var cells := GameGates.arrival_cells(str(r))
		var lk := GameGates.look(str(r))
		ok(lk["floor"] != lk["wall"] and lk["glow"] != lk["sky"], "%s has a palette of its own" % r)
		# painting draws on a control without error (the draw calls need a draw context: use the control's draw signal)
		var painted := [false]
		holder.draw.connect(func():
			GateArt.paint_arrival(holder, str(r), cells, Vector2.ZERO, Vector2(640, 480), Vector2(0.5, -5.5), 24.0)
			painted[0] = true, CONNECT_ONE_SHOT)
		holder.queue_redraw()
		await process_frame
		await process_frame
		ok(painted[0], "%s: its ground is painted" % r)
	holder.queue_free()
	var hues := {}
	for r in GameRealms.ids():
		if GameRealms.gateable(str(r)):
			hues[str(snappedf(GameGates.look(str(r))["floor"].h, 0.05))] = true
	ok(hues.size() >= 5, "the seven realms look different (%d distinct floor hues)" % hues.size())


func test_data_breaks() -> void:
	var d: Dictionary = GateArt.data()
	var keep: String = d["colors"]["moss"]
	d["colors"]["moss"] = "nope"
	ok(not GateArt.validate().is_empty(), "a colour that is no colour is caught")
	d["colors"]["moss"] = keep
	var g: Array = d["glyphs"][0]
	var row: String = g[0]
	g[0] = "11"
	ok(not GateArt.validate().is_empty(), "a rune glyph row of the wrong width is caught")
	g[0] = row
	var alpha: float = d["shimmer_alpha"]["lit"]
	d["w"] = 4
	ok(not GateArt.validate().is_empty(), "a picture size that is not the art's is caught")
	d["w"] = 3
	d["shimmer_alpha"]["lit"] = alpha
	ok(GateArt.validate().is_empty(), "and mending it passes again")
