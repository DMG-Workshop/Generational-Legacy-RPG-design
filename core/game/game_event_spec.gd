## The fixed list of typed events a fight emits (data/game/battle_events.json): their fields and kinds. A view
## (the text battle screen now, the isometric world later) draws from this list alone. Logic only; the test
## checks every event the core emits against it, and every `type` the source can emit is on it.
class_name GameEventSpec
extends RefCounted

const PATH := "res://data/game/battle_events.json"

static var _spec: Dictionary = {}


static func spec() -> Dictionary:
	if _spec.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		_spec = parsed.get("events", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	return _spec


## The types on the list.
static func types() -> Array:
	return spec().keys()


static func _kind_ok(kind: String, v: Variant) -> bool:
	match kind:
		"int":
			return typeof(v) == TYPE_INT
		"number":
			return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
		"bool":
			return typeof(v) == TYPE_BOOL
		"string":
			return typeof(v) == TYPE_STRING
		"ints":
			if typeof(v) != TYPE_ARRAY:
				return false
			for x in v:
				if typeof(x) != TYPE_INT:
					return false
			return true
	return false


## What is wrong with `ev` against the list: [] when it is a listed type with every field present, no field
## unlisted and each of the right kind.
static func problems(ev: Variant) -> Array:
	var out: Array = []
	if typeof(ev) != TYPE_DICTIONARY or not ev.has("type"):
		return ["not an event with a type"]
	var t := str(ev["type"])
	var s: Dictionary = spec().get(t, {})
	if s.is_empty():
		return ["unlisted type '%s'" % t]
	var must: Dictionary = s.get("fields", {})
	var may: Dictionary = s.get("optional", {})
	for k in must:
		if not ev.has(k):
			out.append("%s: missing '%s'" % [t, k])
		elif not _kind_ok(str(must[k]), ev[k]):
			out.append("%s: '%s' is not %s" % [t, k, must[k]])
	for k in ev:
		if k == "type" or must.has(k):
			continue
		if not may.has(k):
			out.append("%s: unlisted field '%s'" % [t, k])
		elif not _kind_ok(str(may[k]), ev[k]):
			out.append("%s: '%s' is not %s" % [t, k, may[k]])
	return out
