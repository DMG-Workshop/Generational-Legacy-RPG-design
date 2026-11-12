## Hard-mode dynasty options (roadmap item 20): whole-line permadeath, iron-man saves and a generation cap. They
## are chosen once, at the founding (GameDynasty.new_game's last argument), and kept on the dynasty as `hard`:
## {permadeath: true, ironman: true, gen_cap: n}, a key only for an option that is on, the whole thing saved only
## when one is. None can be switched on for a house that already lives, and none can be switched off. Rules and
## text are in data/game/hard_mode.json. No dice; with nothing switched on every rule here answers as the game
## always did.
class_name GameHardMode
extends RefCounted

const PERMADEATH := "permadeath"
const IRONMAN := "ironman"
const GEN_CAP := "gen_cap"
const OPTIONS := [PERMADEATH, IRONMAN, GEN_CAP]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/game/hard_mode.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## The generation caps a founder may choose from, smallest first.
static func caps() -> Array:
	var out: Array = []
	for c in setting("gen_caps"):
		out.append(int(c))
	return out


# ---------------------------------------------------------------- what a dynasty was founded with

static func permadeath(d: GameDynasty) -> bool:
	return d.hard.get(PERMADEATH, false) == true


static func ironman(d: GameDynasty) -> bool:
	return d.hard.get(IRONMAN, false) == true


## The dynasty's own generation cap, or 0 when it has none.
static func gen_cap(d: GameDynasty) -> int:
	return int(d.hard.get(GEN_CAP, 0))


static func any(d: GameDynasty) -> bool:
	return not d.hard.is_empty()


## The generation whose heir is the last: the dynasty's cap when it has one, else the saga's own length.
static func last_gen(d: GameDynasty) -> int:
	var cap := gen_cap(d)
	return mini(cap, GameAges.max_generations()) if cap > 0 else GameAges.max_generations()


## True when a death of this cause ends the whole line (permadeath, and a cause on its list).
static func line_ends(d: GameDynasty, cause: String) -> bool:
	return permadeath(d) and cause in setting("permadeath_causes")


## The line a permadeath ending adds to the death's messages.
static func line_ends_text(d: GameDynasty) -> String:
	return text("line_ends", {"house": d.dynasty_name, "heir": d.heir.name})


# ---------------------------------------------------------------- the founding

## What a founder's choices come to, as the dynasty keeps them: {ok, text, hard}. `opts` may hold permadeath and
## ironman (true or false) and gen_cap (0 for none, or one of caps()); anything else is turned away.
static func choices(opts: Dictionary) -> Dictionary:
	var hard: Dictionary = {}
	for k in opts:
		if str(k) not in OPTIONS:
			return {"ok": false, "text": text("unknown_option", {"key": str(k)}), "hard": {}}
	for k in [PERMADEATH, IRONMAN]:
		if not opts.has(k):
			continue
		if typeof(opts[k]) != TYPE_BOOL:
			return {"ok": false, "text": text("bad_value", {"key": k}), "hard": {}}
		if opts[k]:
			hard[k] = true
	if opts.has(GEN_CAP):
		var c: Variant = opts[GEN_CAP]
		var whole: bool = typeof(c) == TYPE_INT or (typeof(c) == TYPE_FLOAT and is_finite(c) and c == floorf(c))
		if not whole or (int(c) != 0 and int(c) not in caps()):
			return {"ok": false, "text": text("bad_cap", {"caps": GameMessages.text("life", "list_comma").join(caps().map(func(n): return GameText.num(n)))}), "hard": {}}
		if int(c) != 0:
			hard[GEN_CAP] = int(c)
	return {"ok": true, "text": "", "hard": hard}


## True for a dynasty that has not yet lived: its founder, no hunt fought, no time passed.
static func is_fresh(d: GameDynasty) -> bool:
	return d.gen == 1 and d.state == "life" and d.history.is_empty() and d.total_hunts == 0 and d.world != null and d.world.year == 0.0


## Founds the dynasty with these options. Returns {ok, text}. Refused once options are set (they cannot be changed
## or switched off) and for a house that already lives (they cannot be switched on later).
static func found(d: GameDynasty, opts: Dictionary) -> Dictionary:
	if any(d):
		return {"ok": false, "text": text("already_set")}
	var c := choices(opts)
	if not c["ok"]:
		return {"ok": false, "text": c["text"]}
	if (c["hard"] as Dictionary).is_empty():
		return {"ok": true, "text": ""}
	if not is_fresh(d):
		return {"ok": false, "text": text("too_late")}
	d.hard = c["hard"]
	for line in lines(d):
		d._say(line)
	return {"ok": true, "text": ""}


# ---------------------------------------------------------------- what the screens say

## One line for each option the dynasty has on, none when it has none.
static func lines(d: GameDynasty) -> Array:
	return lines_of(d.hard)


static func lines_of(hard: Dictionary) -> Array:
	var out: Array = []
	for k in OPTIONS:
		if hard.has(k):
			out.append(str(data()["options"][k]["active"]).format({"cap": GameText.num(int(hard.get(GEN_CAP, 0)))}))
	return out


## A founder's choices in a few words, for the title's button: "off", or "permadeath, iron-man, 25 generations".
static func summary(opts: Dictionary) -> String:
	var c := choices(opts)
	var parts: Array = []
	for k in OPTIONS:
		if (c["hard"] as Dictionary).has(k):
			parts.append(text("short_" + k, {"cap": GameText.num(int(c["hard"].get(GEN_CAP, 0)))}))
	return text("off") if parts.is_empty() else GameMessages.text("life", "list_comma").join(parts)


static func option_name(key: String) -> String:
	return str(data()["options"][key]["name"])


static func option_about(key: String) -> String:
	return str(data()["options"][key]["about"])


# ---------------------------------------------------------------- saving

## The saved options made safe: only the known keys, only when on, of the right kind. A cap must be a whole
## number of at least 1 (it need not still be on the list: a house keeps the cap it was founded with).
static func load_state(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in [PERMADEATH, IRONMAN]:
		if typeof(v.get(k)) == TYPE_BOOL and v[k]:
			out[k] = true
	var c: Variant = v.get(GEN_CAP)
	if typeof(c) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(c)) and float(c) == floorf(float(c)) and float(c) >= 1.0 and float(c) <= float(GameAges.max_generations()):
		out[GEN_CAP] = int(c)
	return out


## True when a save, as parsed from its file, holds an iron-man house.
static func saved_ironman(saved: Variant) -> bool:
	return typeof(saved) == TYPE_DICTIONARY and load_state(saved.get("hard")).has(IRONMAN)


## After an iron-man house is saved, the save before it is not kept: there is nothing to go back to.
static func after_save(d: GameDynasty, path: String) -> void:
	if ironman(d) and FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "options", "text"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("hard_mode.json has no '%s'" % k)
	if not bad.is_empty():
		return bad
	var list: Variant = dat["settings"].get("gen_caps")
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		bad.append("hard mode: gen_caps must list at least one cap")
	else:
		var before := 0
		for c in list:
			if typeof(c) not in [TYPE_INT, TYPE_FLOAT] or float(c) != floorf(float(c)) or int(c) < 1:
				bad.append("hard mode: a generation cap must be a whole number of at least 1 (%s)" % str(c))
				continue
			if int(c) <= before:
				bad.append("hard mode: gen_caps must rise, each cap once (%d)" % int(c))
			if int(c) >= GameAges.max_generations():
				bad.append("hard mode: the cap %d is not below the saga's own length" % int(c))
			before = maxi(before, int(c))
	var causes: Variant = dat["settings"].get("permadeath_causes")
	if typeof(causes) != TYPE_ARRAY or (causes as Array).is_empty():
		bad.append("hard mode: permadeath_causes must name at least one cause of death")
	else:
		for c in causes:
			if str(c) == "old age":
				bad.append("hard mode: old age must pass the line on, it cannot end it")
			if typeof(c) != TYPE_STRING or str(c).strip_edges() == "":
				bad.append("hard mode: a permadeath cause has no name")
	for k in OPTIONS:
		var o: Variant = dat["options"].get(k)
		if typeof(o) != TYPE_DICTIONARY:
			bad.append("hard mode: the option '%s' is missing" % k)
			continue
		for part in ["name", "about", "active"]:
			if str(o.get(part, "")).strip_edges() == "":
				bad.append("hard mode: the option '%s' has no '%s'" % [k, part])
	for k in dat["options"]:
		if str(k) not in OPTIONS:
			bad.append("hard mode: '%s' is not an option the game has" % k)
	if typeof(dat["options"].get(GEN_CAP)) == TYPE_DICTIONARY and "{cap}" not in str(dat["options"][GEN_CAP].get("active", "")):
		bad.append("hard mode: the generation cap's 'active' line must say the {cap}")
	for k in ["button", "off", "panel_title", "panel_note", "on", "is_off", "no_cap", "cap_choice", "short_permadeath", "short_ironman",
			"short_gen_cap", "close", "stats_head", "slot_mark", "too_late", "already_set", "unknown_option", "bad_value", "bad_cap",
			"line_ends", "no_export", "no_import_over", "no_import"]:
		if str(dat["text"].get(k, "")).strip_edges() == "":
			bad.append("hard mode: the text '%s' is missing" % k)
	return bad
