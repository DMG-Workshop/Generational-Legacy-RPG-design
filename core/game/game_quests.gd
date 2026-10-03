## Side quests offered on town notice boards, driven by the dynasty's story flags.
## Unfinished quests are family obligations: they carry over to the next heir.
class_name GameQuests
extends RefCounted

var active: Array = []   # [{"id": quest id, "progress": int}]
var done: Array = []     # quest ids the family has completed


func on_kill(_d: GameDynasty, _creature_id: String) -> void:
	pass


func on_arrive(_d: GameDynasty, _place_id: String) -> void:
	pass


func on_flag(_d: GameDynasty, _flag: String) -> void:
	pass


## Town errands the autopilot runs between actions (no time passes).
static func bot_tick(_d: GameDynasty) -> void:
	pass


func to_dict() -> Dictionary:
	return {"active": active, "done": done}


static func from_dict(v: Dictionary) -> GameQuests:
	var q := GameQuests.new()
	q.active = Array(v.get("active", []))
	q.done = Array(v.get("done", []))
	return q
