## One command that checks all the game's data: every JSON file under data/ parses, every system's own
## validator reports nothing (rounds, ages, feats, events, skills, diseases, combat, skill trees, sprites,
## scenery), the battle events list is sound, and the text catalog and its uses in the code agree.
## Run: godot --headless --path . -s res://tools/check_data.gd   (exit 1 and the problems, one per line, if any)
## tests/test_game_data.gd runs the same check, so CI runs it on every pull request.
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
const GraphicsSettings := preload("res://ui/play/graphics_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const Sound := preload("res://ui/play/sound.gd")
const CODE := ["res://core/game/"]


func _init() -> void:
	var found := problems()
	for p in found:
		print(p)
	print("%d data problem%s" % [found.size(), "" if found.size() == 1 else "s"])
	quit(1 if found.size() > 0 else 0)


## Every problem in the data, each starting with the part it belongs to.
static func problems() -> Array:
	GameData.load_all()
	var out: Array = []
	_parse(out)
	for pair in [["rounds", GameRound.validate()], ["ages", GameAges.validate()], ["feats", GameFeats.validate()],
			["events", GameEvents.validate()], ["skills", GameSkills.validate()], ["diseases", GameDisease.validate()],
			["combat", GameCombat.validate()], ["skill trees", GameSkillTree.validate()], ["sprites", SpriteArt.validate()], ["titles", GameTitles.validate()], ["achievements", GameAchievements.validate()], ["factions", GameFactions.validate()], ["heirlooms", GameHeirlooms.validate()], ["world events", GameWorldEvents.validate()], ["hard mode", GameHardMode.validate()],
			["scenery", SceneryArt.validate()], ["battle events", _event_list()], ["birth", GameBirth.validate()], ["finding", GameFinding.validate()], ["ranch", GameRanch.validate()], ["breeding rules", GameBreeding.validate()], ["realms", GameRealms.validate()], ["subclasses", GameSubclass.validate()], ["farm", GameFarm.validate()], ["raids", GameRaids.validate()], ["materials", GameMaterials.validate()], ["loot", GameLoot.validate()], ["carry", GameCarry.validate()], ["craft", GameCraft.validate()], ["mining", GameMine.validate()], ["worldgen", GameWorldGen.validate()], ["spawn", GameSpawn.validate()], ["behaviour", GameBehaviour.validate()], ["pathing", GamePath.validate()], ["graphics", GraphicsSettings.validate()], ["world input", WorldInput.validate()], ["locales", GameLocale.validate()], ["spaces", GameSpaces.validate()], ["error reports", GameReport.validate()], ["companions in the world", GameCompanions.validate()], ["building", GameBuild.validate()], ["day cycle", GameDay.validate()], ["sound", Sound.validate()], ["text", _text()]]:
		for p in pair[1]:
			out.append("%s: %s" % [pair[0], p])
	return out


## Every .json under data/ is read and parsed.
static func _parse(out: Array) -> void:
	var todo: Array = ["res://data/"]
	while not todo.is_empty():
		var dir: String = todo.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			todo.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".json"):
				continue
			var text := FileAccess.get_file_as_string(dir + f)
			if text == "" or JSON.parse_string(text) == null:
				out.append("json: %s%s does not parse" % [dir, f])


static func _event_list() -> Array:
	var out: Array = []
	var spec := GameEventSpec.spec()
	if spec.is_empty():
		return ["the list is empty or unreadable"]
	for t in spec:
		var s: Dictionary = spec[t]
		if str(s.get("about", "")) == "":
			out.append("'%s' says nothing about itself" % t)
		for group in ["fields", "optional"]:
			for k in s.get(group, {}):
				if str(s[group][k]) not in ["int", "number", "bool", "string", "ints"]:
					out.append("'%s'.%s has the unknown kind '%s'" % [t, k, s[group][k]])
		for k in s.get("optional", {}):
			if s.get("fields", {}).has(k):
				out.append("'%s'.%s is both required and optional" % [t, k])
	return out


## The text catalogs: every key the code asks for exists in its catalog (battle through GameMessages.line, life
## through GameMessages.text("life", key, vars)), every key is asked for, and every line is text.
## The text between an open bracket at `at` and its matching close, string literals kept whole.
static func _arguments(src: String, at: int) -> String:
	var depth := 0
	var quoted := false
	for j in range(at, src.length()):
		var ch := src[j]
		if ch == "\"":
			quoted = not quoted
		elif not quoted:
			if ch == "(":
				depth += 1
			elif ch == ")":
				if depth == 0:
					return src.substr(at, j - at)
				depth -= 1
	return src.substr(at, mini(200, src.length() - at))


static func _text() -> Array:
	var out: Array = []
	var catalogs := {"battle": GameData.messages.get("lines", {}), "life": GameData.life.get("lines", {})}
	for c in catalogs:
		if catalogs[c].is_empty():
			return ["the %s catalog is empty or unreadable" % c]
	var literal := RegEx.create_from_string("\"(\\w+)\"")
	var brackets := RegEx.create_from_string("\\[[^\\]]*\\]")
	var used := {"battle": {}, "life": {}}
	for dir in CODE:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			for call in ["GameMessages.line(", "GameMessages.text("]:
				var at := 0
				while true:
					var i := src.find(call, at)
					if i < 0:
						break
					at = i + 1
					var eol := src.find("\n", i)
					var snippet := src.substr(i, eol - i if eol > 0 else src.length() - i)
					# the key is the first string literal (a conditional key has two); for text() the catalog comes first.
					# The arguments end at the call's closing bracket, and the vars (a dictionary) are not part of them.
					var head := _arguments(src, i + call.length())
					var at_vars := head.find("{")
					if at_vars >= 0:
						head = head.substr(0, at_vars)
					# a key is never inside brackets (an index such as o["potions"] or an array)
					head = brackets.sub(head, "", true)
					var names: Array = []
					for m in literal.search_all(head):
						names.append(m.get_string(1))
					var catalog := "battle"
					if call == "GameMessages.text(":
						catalog = str(names.pop_front()) if not names.is_empty() else ""
					if names.is_empty() or not catalogs.has(catalog):
						out.append("%s%s asks for a message by a key it does not spell out, or in a catalog the game does not have: %s" % [dir, f, snippet.strip_edges()])
						continue
					for k in names:
						used[catalog][k] = true
						if not catalogs[catalog].has(k):
							out.append("%s%s asks for the message '%s', which the %s catalog does not have" % [dir, f, k, catalog])
	for c in catalogs:
		for k in catalogs[c]:
			if not used[c].has(k):
				out.append("the message '%s' is in the %s catalog but nothing asks for it" % [k, c])
			if typeof(catalogs[c][k]) != TYPE_STRING or str(catalogs[c][k]).strip_edges() == "":
				out.append("the message '%s' is not text" % k)
	return out
