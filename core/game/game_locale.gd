## Localisation (roadmap item 40): which language the game's text is shown in, and the text for a line in it. The
## text itself is in data and is read through `GameLocale.text(catalog, key, source)`: the source line when the game is
## in its own language (so nothing changes for a game that never switches), the translation's line when the chosen
## locale has one that uses the same {placeholders}, the source line when it does not, and for the pseudo-language a
## line made on the fly (accented, padded, bracketed) to show up text that will not fit or was never made
## translatable. Catalogs are the text in data today: `battle` (data/text/battle.json), `life` (the rest of the game's text,
## data/text/life.json) and `tutorial` (the tips, by step id). No UI; the chosen locale is a setting of the screen side (settings.cfg), handed in with `set_locale`.
class_name GameLocale
extends RefCounted

const PATH := "res://data/text/locales.json"
const DIR := "res://data/text/locales/"

static var current := ""          # "" until asked: the source language
static var _cache: Dictionary = {}
static var _translations: Dictionary = {}   # locale -> {catalog -> {key -> text}}
static var _placeholder: RegEx


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func source() -> String:
	return str(data()["source"])


static func ids() -> Array:
	return data()["locales"].keys()


## The locales the menu offers: those not hidden.
static func offered() -> Array:
	return ids().filter(func(id): return not bool(data()["locales"][id].get("hidden", false)))


static func name_of(id: String) -> String:
	return str(data()["locales"].get(id, {}).get("name", id))


static func locale() -> String:
	return current if current != "" and data()["locales"].has(current) else source()


## Chooses the language. An unknown one is refused and the game stays as it was.
static func set_locale(id: String) -> bool:
	if not data()["locales"].has(id):
		return false
	current = id
	return true


static func is_pseudo(id: String) -> bool:
	return bool(data()["locales"].get(id, {}).get("pseudo", false))


# ---------------------------------------------------------------- the text

## The source lines of a catalog, by key.
static func source_lines(catalog: String) -> Dictionary:
	GameData.load_all()
	match catalog:
		"battle":
			return GameData.messages.get("lines", {})
		"life":
			return GameData.life.get("lines", {})
		"tutorial":
			var out := {}
			for step in GameData.tutorial.get("steps", []):
				out[str(step["id"])] = str(step["text"])
			return out
	return {}


## A locale's own lines for a catalog ({} when it has no file for it).
static func lines_of(id: String, catalog: String) -> Dictionary:
	if not _translations.has(id):
		_translations[id] = {}
	if not _translations[id].has(catalog):
		var path := DIR + id + "/" + catalog + ".json"
		var found := {}
		if FileAccess.file_exists(path):
			var raw: Variant = GameData.load_json(path)
			if typeof(raw) == TYPE_DICTIONARY and typeof(raw.get("lines")) == TYPE_DICTIONARY:
				found = raw["lines"]
		_translations[id][catalog] = found
	return _translations[id][catalog]


## The placeholders a line asks for, sorted.
static func placeholders(line: String) -> Array:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{(\\w+)\\}")
	var out: Array = []
	for m in _placeholder.search_all(line):
		if m.get_string(1) not in out:
			out.append(m.get_string(1))
	out.sort()
	return out


## The line to show for `key` of `catalog`, whose source text is `source_text`.
static func text(catalog: String, key: String, source_text: String) -> String:
	var id := locale()
	if id == source():
		return source_text
	if is_pseudo(id):
		return pseudo(source_text)
	var line: Variant = lines_of(id, catalog).get(key, null)
	if typeof(line) == TYPE_STRING and placeholders(str(line)) == placeholders(source_text):
		return str(line)
	return source_text


## The pseudo-language's version of a line: accents on every letter, padding, brackets; {placeholders} untouched.
static func pseudo(line: String) -> String:
	var p: Dictionary = data()["pseudo"]
	var map: Dictionary = p["map"]
	var out := ""
	var letters := 0
	var inside := false
	for i in line.length():
		var ch := line[i]
		if ch == "{":
			inside = true
		if inside:
			out += ch
		else:
			out += str(map.get(ch, ch))
			letters += 1
		if ch == "}":
			inside = false
	var pad := int(ceil(float(letters) * float(p["expand"])))
	return str(p["open"]) + out + str(p["pad"]).repeat(pad) + str(p["close"])


# ---------------------------------------------------------------- checking a translation

## What is wrong with a locale's files: lines for keys the game does not have, lines whose placeholders differ from the
## source's, and (as `missing`) source lines it has not translated. Returns {problems: [..], missing: [..]}.
static func check(id: String) -> Dictionary:
	var problems: Array = []
	var missing: Array = []
	for catalog in data()["catalogs"]:
		var src := source_lines(str(catalog))
		var mine := lines_of(id, str(catalog))
		for key in mine:
			if not src.has(key):
				problems.append("%s/%s.json: '%s' is not a line the game has" % [id, catalog, key])
			elif typeof(mine[key]) != TYPE_STRING:
				problems.append("%s/%s.json: '%s' is not text" % [id, catalog, key])
			elif placeholders(str(mine[key])) != placeholders(str(src[key])):
				problems.append("%s/%s.json: '%s' uses %s where the source uses %s" % [id, catalog, key, str(placeholders(str(mine[key]))), str(placeholders(str(src[key])))])
		for key in src:
			if not mine.has(key):
				missing.append("%s/%s" % [catalog, key])
	return {"problems": problems, "missing": missing}


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["source", "locales", "pseudo", "catalogs", "sample_chars"]:
		if not dat.has(k):
			bad.append("locales.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if not dat["locales"].has(str(dat["source"])):
		bad.append("locales.json: the source '%s' is not one of the locales" % dat["source"])
	var p: Dictionary = dat["pseudo"]
	for k in ["expand", "open", "close", "pad", "map"]:
		if not p.has(k):
			bad.append("locales.json: pseudo.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(p["expand"]) < 0.1 or float(p["expand"]) > 1.0:
		bad.append("locales.json: pseudo.expand should be 0.1 to 1 (translations run about a third longer than English)")
	if str(p["pad"]).length() != 1 or str(p["open"]) == "" or str(p["close"]) == "":
		bad.append("locales.json: pseudo needs one pad character and an open and close bracket")
	for ch in p["map"]:
		if str(ch).length() != 1 or str(p["map"][ch]).length() != 1:
			bad.append("locales.json: pseudo.map '%s' must map one character to one character" % ch)
		if str(ch) == "{" or str(ch) == "}":
			bad.append("locales.json: pseudo.map must leave the braces alone")
	for catalog in dat["catalogs"]:
		if source_lines(str(catalog)).is_empty():
			bad.append("locales.json: catalog '%s' has no source lines" % catalog)
	var pseudos := 0
	for id in dat["locales"]:
		var l: Dictionary = dat["locales"][id]
		if str(l.get("name", "")) == "":
			bad.append("locales.json: locale '%s' has no name" % id)
		if bool(l.get("pseudo", false)):
			pseudos += 1
			if not bool(l.get("hidden", false)):
				bad.append("locales.json: the pseudo-language '%s' must be hidden from the menu" % id)
			continue
		if id == str(dat["source"]):
			continue
		var c := check(str(id))
		bad.append_array(c["problems"])
		for m in c["missing"]:
			bad.append("locales.json: locale '%s' has no line for %s" % [id, m])
	if pseudos != 1:
		bad.append("locales.json: there should be exactly one pseudo-language")
	return bad
