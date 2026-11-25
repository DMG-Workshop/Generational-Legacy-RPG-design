## The light of the open world, drawn over the map (data/art/light.json; GroundArt makes the textures). The colour of the light from
## GameDay.look (a warm sun by day, a cool tint as it fails), the soft shadow under a town building, the glow of hearths, forges, camp
## fires and lit windows at night, the rain and snow of the weather, a fog's grey, and a soft vignette at the screen's edge. A
## rendering helper: it reads the dynasty and draws, it changes nothing, and nothing in it is random (a flake or a flicker is a hash
## of its number and the time). Everything that moves is still with reduced motion, and the weather is not drawn at all.
class_name WorldLook
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")


## A Control that draws with a function (`painter(control)`), for a layer of its own over the map: additive when it holds glow.
class Layer extends Control:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## A full-size layer that draws with `painter`, mouse-proof, optionally blending additively.
static func make_layer(painter: Callable, additive: bool) -> Control:
	var l := Layer.new()
	l.painter = painter
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = m
	return l


static func data() -> Dictionary:
	return GroundArt.light_data()


## The time the moving things take: 0 (everything still) with reduced motion.
static func clock() -> float:
	return 0.0 if UiSettings.reduced_motion() else float(Time.get_ticks_msec()) / 1000.0


static func _rgb(a: Array, alpha: float = 1.0) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]), alpha)


# ---------------------------------------------------------------- the colour of the light

## The colour laid over the map in `rect`: the day's tint as the light fails, then the warm sun of a bright day.
static func paint_grade(c: Control, rect: Rect2, look: Dictionary) -> void:
	var g: Dictionary = data()["grade"]
	var tint: Array = look["tint"]
	var night := (1.0 - float(look["light"])) * float(g["night_alpha"])
	if night > 0.0:
		c.draw_rect(rect, Color(float(tint[0]), float(tint[1]), float(tint[2]), night))
	var warm := float(look["light"]) * float(g["sun_alpha"])
	if warm > 0.0:
		c.draw_rect(rect, _rgb(g["sun_color"], warm))


## The fog's grey over `rect` (none in clear weather).
static func paint_fog(c: Control, rect: Rect2, look: Dictionary) -> void:
	var w: Dictionary = data()["weather"]
	var a := float(look["fog"]) * float(w["fog_alpha"])
	if a > 0.0:
		c.draw_rect(rect, _rgb(w["fog_color"], a))


## The vignette over `rect`: darker at the edge, and a little more at night.
static func paint_vignette(c: Control, rect: Rect2, look: Dictionary) -> void:
	var v: Dictionary = data()["vignette"]
	var a := float(v["strength"]) * (1.0 + float(v["night_boost"]) * (1.0 - float(look["sun"])))
	c.draw_texture_rect(GroundArt.vignette_texture(), rect, false, Color(1, 1, 1, clampf(a, 0.0, 1.0)))


# ---------------------------------------------------------------- shadows

## The soft shadow of a building: its footprint `box` moved to the south-east (the sun is in the north-west) and grown a little in
## each of `layers` fading boxes. Drawn before the building, which covers all but its south and east sides.
static func paint_building_shadow(c: Control, box: Rect2, cell: float) -> void:
	var s: Dictionary = data()["shadow"]
	var b: Dictionary = s["building"]
	var layers := int(b["layers"])
	var col := _rgb(s["color"], float(b["alpha"]) / float(layers))
	for i in layers:
		var grow := float(b["grow"]) * cell * float(layers - i) / float(layers)
		var r := Rect2(box.position + Vector2(float(b["dx"]), float(b["dy"])) * cell, box.size).grow(grow)
		c.draw_rect(r, col)


# ---------------------------------------------------------------- glow

## How strongly the night's lights shine, 0 (by day) to 1 (the dark of night).
static func night_glow(look: Dictionary) -> float:
	var from := float(data()["glow"]["from_sun"])
	return clampf((from - float(look["sun"])) / from, 0.0, 1.0)


## What shines in the tiles `view`, as [{pos: Vector2 (tiles), spec: Dictionary}]: the family's hearths and anvils, camp fires and
## the like standing in the chunks the tile view keeps (`tile_view.glows`), and the lit windows of the town's buildings.
static func glow_sources(d: GameDynasty, tile_view: TileView, view: Rect2i) -> Array:
	var gl: Dictionary = data()["glow"]
	var out: Array = []
	for k in d.built:
		var cell: Variant = GameBuild.parse(str(k))
		if cell == null or (cell as Vector3i).y != GameBuild.SURFACE:
			continue
		var spec: Variant = gl["tiles"].get(str(d.built[k]), null)
		if spec != null and view.has_point(Vector2i((cell as Vector3i).x, (cell as Vector3i).z)):
			out.append({"pos": Vector2(float((cell as Vector3i).x) + 0.5, float((cell as Vector3i).z) + 0.5), "spec": spec})
	if tile_view != null:
		for chunk in tile_view.glows:
			for cell in tile_view.glows[chunk]:
				if view.has_point(cell):
					out.append({"pos": Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5), "spec": gl["glyphs"][tile_view.glows[chunk][cell]]})
	for b in GameTown.in_rect(view):
		var spec: Dictionary = gl["buildings"].get(str(b["kind"]), gl["buildings"]["default"])
		out.append({"pos": Vector2(float(b["x"]) + float(spec["at"][0]) * float(b["w"]), float(b["z"]) + float(spec["at"][1]) * float(b["h"])), "spec": spec})
	return out


## The strength of a source at a time: its own, flickering a little (a hash of where it is sets its phase).
static func glow_strength(spec: Dictionary, pos: Vector2, t: float) -> float:
	var gl: Dictionary = data()["glow"]
	var phase := float(GroundArt.mix(int(pos.x * 2.0), int(pos.y * 2.0)) % 628) / 100.0
	return float(spec["strength"]) * (1.0 + float(gl["flicker"]) * sin(t * float(gl["flicker_hz"]) * TAU + phase))


## Draws the glow of the sources over the map: `tile_to_px` turns a position in tiles into one on the layer. Meant for an additive layer.
static func paint_glow(c: Control, sources: Array, look: Dictionary, cell: float, origin: Vector2, area: Vector2, centre: Vector2) -> void:
	var night := night_glow(look)
	if night <= 0.0:
		return
	var t := clock()
	var tex := GroundArt.glow_texture()
	for src in sources:
		var spec: Dictionary = src["spec"]
		var p: Vector2 = origin + (src["pos"] - centre) * cell + area * 0.5
		var r := float(spec["radius"]) * cell
		var k := glow_strength(spec, src["pos"], t) * night
		var col := _rgb(spec["color"])
		c.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r * k, col.g * k, col.b * k, 1.0))


# ---------------------------------------------------------------- smoke

## Puff i of `n` in a smoke pot's cloud of `radius` tiles at time t: {pos (tiles from the cloud's middle), r (tiles), alpha}. Spread over
## the disc by a hash of the puff's number, drifting slowly round with the time; a hash and the time are all there is to it, so it is
## still with reduced motion (t is 0 then) and no die is thrown.
static func smoke_puff(i: int, _n: int, radius: float, t: float) -> Dictionary:
	var u1 := _unit(i, 11)
	var u2 := _unit(i, 12)
	var u3 := _unit(i, 13)
	var ang := u1 * TAU + t * 0.04 * (0.5 + u3)
	var dist := sqrt(u2) * radius * 0.92
	var wobble := Vector2(sin(t * 0.35 + u3 * TAU), cos(t * 0.28 + u1 * TAU)) * radius * 0.04
	return {"pos": Vector2.from_angle(ang) * dist + wobble, "r": radius * (0.2 + 0.16 * u3), "alpha": 0.3 + 0.2 * u2}


## Draws the cloud over the map: `cloud` is its middle in tiles, `fade` (0 to 1) thins it as the last of its time runs out.
static func paint_smoke(c: Control, cloud: Vector2, radius: float, puffs: int, origin: Vector2, area: Vector2, view_centre: Vector2, cell: float, fade: float) -> void:
	var strength := clampf(fade * 5.0, 0.0, 1.0)
	var t := clock()
	var tex := GroundArt.glow_texture()
	var rect := Rect2(origin, area)
	for i in puffs:
		var pf := smoke_puff(i, puffs, radius, t)
		var p: Vector2 = origin + (cloud + Vector2(pf["pos"]) - view_centre) * cell + area * 0.5
		var r := float(pf["r"]) * cell
		if not rect.grow(r).has_point(p):
			continue
		c.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.78, 0.78, 0.8, float(pf["alpha"]) * strength))
	var mid := origin + (cloud - view_centre) * cell + area * 0.5
	c.draw_arc(mid, radius * cell, 0.0, TAU, 64, Color(0.8, 0.8, 0.84, 0.4 * strength), maxf(1.0, cell * 0.06))


# ---------------------------------------------------------------- weather

## The share of a hash, 0 up to (not including) 1.
static func _unit(a: int, b: int) -> float:
	return float(GroundArt.mix(a, b, 77) & 0xffff) / 65536.0


## How many particles of a kind a view of `size` draws in a weather: the data's count for a 1280 by 720 view, by its area and the
## weather's intensity.
static func particle_count(precip: String, weather: String, size: Vector2) -> int:
	var w: Dictionary = data()["weather"]
	if not w.has(precip):
		return 0
	var scale := clampf(size.x * size.y / (1280.0 * 720.0), 0.4, 2.5)
	return int(round(float(w[precip]["count"]) * scale * float(w["intensity"].get(weather, 1.0))))


## Where particle i of a kind is at time t, in a view of `size`: from the top (rain falls and leans, snow drifts) and back to the top when
## it leaves the bottom. For rain, also the tail it streaks back to.
static func particle(precip: String, i: int, t: float, size: Vector2) -> Vector2:
	var w: Dictionary = data()["weather"][precip]
	var u1 := _unit(i, 1)
	var u2 := _unit(i, 2)
	var u3 := _unit(i, 3)
	if precip == "rain":
		var fy := fposmod(u2 + float(w["fall"]) * t * (0.85 + 0.3 * u3), 1.0)
		var drift := float(w["slant"]) * fy * size.y
		return Vector2(fposmod(u1 * size.x + drift, size.x), fy * size.y)
	var sy := fposmod(u2 + float(w["fall"]) * t * (0.6 + 0.8 * u3), 1.0)
	return Vector2(fposmod(u1 * size.x + sin(t * 0.7 + u3 * TAU) * float(w["sway_px"]), size.x), sy * size.y)


## Whether the weather has anything to draw: rain or snow, and not with reduced motion.
static func weather_shows(look: Dictionary) -> bool:
	return not UiSettings.reduced_motion() and data()["weather"].has(str(look["precip"]))


## Draws the rain or snow over `rect` (nothing with reduced motion or when the sky is dry).
static func paint_weather(c: Control, rect: Rect2, look: Dictionary) -> void:
	if not weather_shows(look):
		return
	var precip := str(look["precip"])
	var w: Dictionary = data()["weather"][precip]
	var col := _rgb(w["color"], float(w["color"][3]))
	var t := clock()
	var n := particle_count(precip, str(look["weather"]), rect.size)
	for i in n:
		var p := rect.position + particle(precip, i, t, rect.size)
		if precip == "rain":
			var len_px := float(w["length_px"])
			c.draw_line(p, p - Vector2(float(w["slant"]) * len_px, len_px), col, float(w["width_px"]))
		else:
			var sz := float(w["size_px"]) * (0.6 + 0.8 * _unit(i, 3))
			c.draw_rect(Rect2(p, Vector2(sz, sz)), col)
