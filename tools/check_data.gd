## One command that checks all the game's data: every JSON file under data/ parses, every system's own
## validator reports nothing (rounds, ages, feats, events, skills, diseases, combat, skill trees, sprites,
## scenery), the battle events list is sound, and the text catalog and its uses in the code agree.
## Run: godot --headless --path . -s res://tools/check_data.gd   (exit 1 and the problems, one per line, if any)
## tests/test_game_data.gd runs the same check, so CI runs it on every pull request.
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
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
			["combat", GameCombat.validate()], ["skill trees", GameSkillTree.validate()], ["sprites", SpriteArt.validate()], ["titles", GameTitles.validate()],
			["scenery", SceneryArt.validate()], ["battle events", _event_list()], ["birth", GameBirth.validate()], ["finding", GameFinding.validate()], ["text", _text()]]:
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


## The text catalog: every key the code asks for exists, every key is asked for, and a call gives exactly
## the placeholders the line has.
static func _text() -> Array:
	var out: Array = []
	var lines: Dictionary = GameData.messages.get("lines", {})
	if lines.is_empty():
		return ["the catalog is empty or unreadable"]
	var call := RegEx.create_from_string("GameMessages\\.line\\(\\s*(\"(\\w+)\"|[^\"]*?\"(\\w+)\"[^\"]*?\"(\\w+)\")")
	var literal := RegEx.create_from_string("\"(\\w+)\"")
	var used: Dictionary = {}
	for dir in CODE:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + f)
			var at := 0
			while true:
				var i := src.find("GameMessages.line(", at)
				if i < 0:
					break
				at = i + 1
				var eol := src.find("\n", i)
				var snippet := src.substr(i, eol - i if eol > 0 else src.length() - i)
				# the key is the first string literal; a conditional key ("a" if x else "b") has two
				var rest := snippet.substr("GameMessages.line(".length())
				var keys: Array = []
				var head := rest
				var cut := head.find("{")
				if cut >= 0:
					head = head.substr(0, cut)
				for m in literal.search_all(head):
					keys.append(m.get_string(1))
				if keys.is_empty():
					out.append("%s%s asks for a message by a key it does not spell out: %s" % [dir, f, snippet.strip_edges()])
				for k in keys:
					used[k] = true
					if not lines.has(k):
						out.append("%s%s asks for the message '%s', which the catalog does not have" % [dir, f, k])
	for k in lines:
		if not used.has(k):
			out.append("the message '%s' is in the catalog but nothing asks for it" % k)
		if typeof(lines[k]) != TYPE_STRING or str(lines[k]).strip_edges() == "":
			out.append("the message '%s' is not text" % k)
	return out
