## The death summary: what the screen shown when an heir dies (ui/play/death_panel.gd) tells, worked out from what the dynasty
## already keeps (`last_death`, the house, the heirlooms, the echoes, the candidates). It is read-only: it changes no rule of death or
## succession and draws no die. The text and its few numbers are in data/ui/death.json.
## Run: godot --headless --path . -s res://tests/test_game_death_panel.gd
class_name GameDeath
extends RefCounted

const PATH := "res://data/ui/death.json"
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## Whether there is a death to tell: the dynasty has one on record and is between heirs (or at the saga's end).
static func has_death(d: GameDynasty) -> bool:
	return d != null and not d.last_death.is_empty() and d.state in ["succession", "ended"]


## The summary: {title, who, how, killer, sections: [{head, lines: [text]}], carry_on (the button's text), heirs (the candidates' names), ends}.
static func summary(d: GameDynasty) -> Dictionary:
	var rec: Dictionary = d.last_death
	var name := str(rec.get("name", ""))
	var first := name.split(" ")[0] if name != "" else ""
	var cause := str(rec.get("cause", ""))
	var race: String = str((GameData.races.get(str(rec.get("race_id", "human")), {}) as Dictionary).get("name", rec.get("race_id", "")))
	var cls: String = str((GameData.classes.get(str(rec.get("class_id", "")), {}) as Dictionary).get("name", rec.get("class_id", "")))
	var out := {
		"title": text("passed", {"name": first}),
		"who": text("who", {"gen": GameText.num(int(rec.get("gen", 1))), "race": race, "cls": cls, "level": GameText.num(int(rec.get("level", 1)))}),
		"how": GameMessages.text("life", "dies_old_age", {"name": first, "age": int(rec.get("age", 0))}) if cause == "old age" else GameMessages.text("life", "dies_cause", {"name": first, "cause": d._cause_text(cause), "age": int(rec.get("age", 0))}),   # the very line the journal has
		"killer": killer_line(d, cause),
		"heirs": d.candidates.map(func(c): return str(c.name)),
		"ends": d.state == "ended",
	}
	out["sections"] = [
		{"head": text("life"), "lines": _life(rec)},
		{"head": text("leaves", {"name": first}), "lines": _leaves(d, rec)},
		{"head": text("carries"), "lines": _carries(d, rec)},
	]
	out["carry_on"] = carry_text(out["heirs"])
	return out


## "What killed me": the foe that struck the heir down and its band and level when the fight is still known (the dynasty keeps them
## for the session, not in the save), else what the record has.
static func killer_line(d: GameDynasty, cause: String) -> String:
	if cause == "old age":
		return text("killer_old")
	if cause != "slain in battle":
		return text("killer_cause", {"cause": cause})
	var info: Dictionary = d.killer_info
	var foe := ""
	if not info.is_empty():
		foe = str(info.get("name", ""))
	if foe == "" and d.killer_id != "":
		foe = d._creature_name(d.killer_id)
	if foe == "":
		return text("killer_slain_unknown")
	var band := ""
	if not info.is_empty():
		var con := str(info.get("con", ""))
		var lv := int(info.get("level", 0))
		if con != "" and lv > 0:
			band = text("killer_band", {"band": GameLevels.band_name(con), "level": GameText.num(lv)})
		elif con != "":
			band = text("killer_band_only", {"band": GameLevels.band_name(con)})
		elif lv > 0:
			band = text("killer_level_only", {"level": GameText.num(lv)})
	return text("killer", {"foe": foe, "band": band})


static func _life(rec: Dictionary) -> Array:
	var slain := 0
	var kills: Variant = rec.get("kills", {})
	if typeof(kills) == TYPE_DICTIONARY:
		for k in kills:
			slain += int(kills[k])
	var won := GameText.num(int(rec.get("battles_won", 0)))
	return [text("life_kills_one" if slain == 1 else "life_kills", {"n": GameText.num(slain), "won": won}), text("life_gold", {"gold": GameText.num(int(rec.get("gold", 0)))})]


static func _leaves(d: GameDynasty, rec: Dictionary) -> Array:
	var comma := GameMessages.text("life", "list_comma")
	var out: Array = []
	var held: Array = d.heirlooms.map(func(h): return str(h.get("name", "")))
	var cap := int(data()["settings"]["max_heirlooms"])
	if held.is_empty():
		out.append(text("leaves_no_heirlooms"))
	else:
		out.append(text("leaves_heirlooms", {"list": comma.join(held.slice(0, cap)) + ("" if held.size() <= cap else " +%d" % (held.size() - cap))}))
	var parts: Array = []
	for t in GameHouse.TRACKS:
		if GameHouse.level(d, t) > 0:
			parts.append(text("house_part", {"track": GameHouse.track_name(t), "level": GameHouse.level(d, t)}))
	out.append(text("leaves_house", {"list": comma.join(parts)}) if not parts.is_empty() else text("leaves_no_house"))
	var titles: Array = []
	for id in rec.get("titles", []):
		titles.append(str(GameTitles.def(str(id)).get("name", id)))
	for id in d.house_titles:
		var nm := str(GameTitles.def(str(id)).get("name", id))
		if nm not in titles:
			titles.append(nm)
	out.append(text("leaves_titles", {"list": comma.join(titles)}) if not titles.is_empty() else text("leaves_no_titles"))
	var echoes: Array = d.echoes.duplicate()
	echoes.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]))
	var shown: Array = echoes.slice(0, int(data()["settings"]["max_echoes"])).map(func(e): return d.describe_echo(e))
	out.append(text("leaves_echoes", {"list": comma.join(shown)}) if not shown.is_empty() else text("leaves_no_echoes"))
	return out


static func _carries(d: GameDynasty, rec: Dictionary) -> Array:
	var out: Array = []
	var frac := float(GameData.bal("gold_inherit_fraction"))
	out.append(text("carries_gold", {"gold": GameText.num(int(float(rec.get("gold", 0)) * frac)), "pct": int(round(frac * 100.0))}))
	var potions := d.heir.potions if d.heir != null else 0
	if potions > 0:
		out.append(text("carries_potion") if potions == 1 else text("carries_potions", {"n": potions}))
	var packed := d.heir.inventory.size() if d.heir != null else 0
	out.append(text("carries_gear", {"n": packed}) if packed > 0 else text("carries_gear_none"))
	if not d.echoes.is_empty():
		out.append(text("carries_echoes", {"pct": 15}))
	if d.pending_archetype != "":
		out.append(text("fate", {"name": GameFate.archetype_name(d.pending_archetype)}))
	return out


## The button that goes on to the succession: one heir by name, or the heirs by name (or the plain choice when there are many).
static func carry_text(heirs: Array) -> String:
	if heirs.is_empty():
		return text("carry_choose")
	if heirs.size() == 1:
		return text("carry_one", {"heir": heirs[0]})
	if heirs.size() <= 3:
		return text("carry_many", {"heirs": " / ".join(heirs)})
	return text("carry_choose")


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	if not dat.has("text") or not dat.has("settings"):
		return ["death.json: settings and text are required"]
	for k in ["max_echoes", "max_heirlooms"]:
		if int(dat["settings"].get(k, 0)) < 1:
			bad.append("death.json: settings.%s must be at least 1" % k)
	for k in ["passed", "who", "killer", "killer_old", "killer_cause", "killer_slain_unknown", "life", "life_kills", "life_kills_one", "life_gold", "leaves", "leaves_heirlooms", "leaves_no_heirlooms", "leaves_house", "leaves_no_house", "leaves_titles", "leaves_no_titles", "leaves_echoes", "leaves_no_echoes", "carries", "carries_gold", "carries_gear", "carries_gear_none", "carry_one", "carry_many", "carry_choose"]:
		if not dat["text"].has(k):
			bad.append("death.json: text.%s is missing" % k)
	return bad
