## Player-facing text kept in data (data/text/*.json), found by key, so a line can be reworded, translated or
## given a sound cue without touching rules. `line(key, vars)` fills each {placeholder} from `vars` in one pass.
## A missing key or placeholder is a bug: it is recorded in `problems` (the tests read it) and shown in the
## text as [key] or {name}, never silently blank. Logic only.
class_name GameMessages
extends RefCounted

static var problems: Array = []
static var _placeholder: RegEx


## The text for `key` with `vars` filled in.
static func line(key: String, vars: Dictionary = {}) -> String:
	GameData.load_all()
	var lines: Dictionary = GameData.messages.get("lines", {})
	if not lines.has(key):
		problems.append("no message '%s'" % key)
		return "[%s]" % key
	return fill(str(lines[key]), vars, key)


## Fills {placeholder}s of `template` from `vars`; `where` names the message for the problem list.
static func fill(template: String, vars: Dictionary, where: String = "") -> String:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{(\\w+)\\}")
	var out := ""
	var at := 0
	for m in _placeholder.search_all(template):
		out += template.substr(at, m.get_start() - at)
		var k := m.get_string(1)
		if vars.has(k):
			out += str(vars[k])
		else:
			problems.append("message '%s' was not given {%s}" % [where, k])
			out += m.get_string()
		at = m.get_end()
	return out + template.substr(at)


## The placeholders a template asks for.
static func placeholders(template: String) -> Array:
	var re := RegEx.create_from_string("\\{(\\w+)\\}")
	var out: Array = []
	for m in re.search_all(template):
		if m.get_string(1) not in out:
			out.append(m.get_string(1))
	return out
