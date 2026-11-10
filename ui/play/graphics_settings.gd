## Graphics settings (roadmap item 37): a quality preset (pixel scale, effects, frame cap) and a battery saver that
## lies over it, from data/ui/graphics.json. The choice is kept in settings.cfg beside the text size, never in the
## save. `apply` hands the frame cap and the low-processor mode to the engine and the weather particles to the
## scenery painter; `pixel_scale` waits for the 3D renderer. Rendering side only: nothing here touches a dynasty.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
const PATH := "res://data/ui/graphics.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func ids() -> Array:
	return (data()["order"] as Array).duplicate()


static func default_id() -> String:
	return str(data()["default_mobile" if UiSettings.is_mobile() else "default_desktop"])


## The preset in use: the stored one if it is one the game knows, else the default for this kind of device.
static func preset() -> String:
	var v: Variant = UiSettings.stored("graphics", "")
	return str(v) if typeof(v) == TYPE_STRING and data()["presets"].has(str(v)) else default_id()


static func set_preset(id: String) -> bool:
	if not data()["presets"].has(id):
		return false
	return UiSettings.store("graphics", id)


static func battery_saver() -> bool:
	return str(UiSettings.stored("battery_saver", "off")) == "on"


static func set_battery_saver(on: bool) -> bool:
	return UiSettings.store("battery_saver", "on" if on else "off")


static func preset_def(id: String) -> Dictionary:
	return data()["presets"].get(id, data()["presets"][default_id()])


## What is in force now: {preset, pixel_scale, effects, fps_cap, low_processor}, the battery saver laid over the preset.
static func current() -> Dictionary:
	var p := preset_def(preset())
	var out := {"preset": preset(), "pixel_scale": int(p["pixel_scale"]), "effects": str(p["effects"]), "fps_cap": int(p["fps_cap"]), "low_processor": false}
	if battery_saver():
		var b: Dictionary = data()["battery_saver"]
		var cap := int(b["fps_cap"])
		out["fps_cap"] = cap if int(out["fps_cap"]) == 0 else mini(cap, int(out["fps_cap"]))
		out["effects"] = _lower(str(out["effects"]), str(b["effects"]))
		out["low_processor"] = bool(b["low_processor"])
	return out


static func _lower(a: String, b: String) -> String:
	var levels: Array = data()["levels"]
	return a if levels.find(a) <= levels.find(b) else b


## Whether a named effect is drawn now (`effect_levels` says the level it needs; an unknown effect is not drawn).
static func effect_on(effect: String) -> bool:
	var need := str(data()["effect_levels"].get(effect, ""))
	var levels: Array = data()["levels"]
	if need == "" or not levels.has(need):
		return false
	return levels.find(str(current()["effects"])) >= levels.find(need)


## Hands what is in force to the engine and the painters.
static func apply() -> void:
	var c := current()
	Engine.max_fps = int(c["fps_cap"])
	OS.low_processor_usage_mode = bool(c["low_processor"])
	var particles := effect_on("weather_particles")
	if SceneryArt.particles_on != particles:
		SceneryArt.particles_on = particles
		SceneryArt.forget_painted()   # scenes painted under the old setting are painted again


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["order", "default_desktop", "default_mobile", "levels", "presets", "battery_saver", "effect_levels"]:
		if not dat.has(k):
			bad.append("graphics.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var levels: Array = dat["levels"]
	if levels.size() < 2 or str(levels[0]) != "off":
		bad.append("graphics.json: levels must start at 'off' and have at least one more")
	for id in dat["order"]:
		if not dat["presets"].has(id):
			bad.append("graphics.json: order names '%s', which is not a preset" % id)
	for id in dat["presets"]:
		var p: Dictionary = dat["presets"][id]
		if not (dat["order"] as Array).has(id):
			bad.append("graphics.json: preset '%s' is not in order, so the menu would not offer it" % id)
		for k in ["name", "pixel_scale", "effects", "fps_cap", "about"]:
			if not p.has(k):
				bad.append("graphics.json: preset '%s' has no %s" % [id, k])
		if not bad.is_empty():
			return bad
		if int(p["pixel_scale"]) < 1 or int(p["pixel_scale"]) > 8:
			bad.append("graphics.json: preset '%s' pixel_scale must be 1 to 8" % id)
		if not levels.has(str(p["effects"])):
			bad.append("graphics.json: preset '%s' effects '%s' is not a level" % [id, p["effects"]])
		if int(p["fps_cap"]) != 0 and int(p["fps_cap"]) < 15:
			bad.append("graphics.json: preset '%s' fps_cap must be 0 (uncapped) or at least 15" % id)
	for k in ["default_desktop", "default_mobile"]:
		if not dat["presets"].has(str(dat[k])):
			bad.append("graphics.json: %s '%s' is not a preset" % [k, dat[k]])
	var b: Dictionary = dat["battery_saver"]
	for k in ["fps_cap", "effects", "low_processor", "about"]:
		if not b.has(k):
			bad.append("graphics.json: battery_saver has no %s" % k)
	if b.has("fps_cap") and int(b["fps_cap"]) < 15:
		bad.append("graphics.json: the battery saver needs a frame cap of at least 15 (0 would save nothing)")
	if b.has("effects") and not levels.has(str(b["effects"])):
		bad.append("graphics.json: battery_saver effects '%s' is not a level" % b["effects"])
	for e in dat["effect_levels"]:
		if not levels.has(str(dat["effect_levels"][e])) or str(dat["effect_levels"][e]) == "off":
			bad.append("graphics.json: effect '%s' needs a level other than off" % e)
	return bad
