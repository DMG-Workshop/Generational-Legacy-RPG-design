## Companions hired for a fee who travel and fight beside the heir.
class_name GameParty
extends RefCounted

var members: Array = []


## Upkeep and loyalty as years pass; append messages to `msgs`.
func on_years(_d: GameDynasty, _years: float, _msgs: Array) -> void:
	pass


## The family's companions stay on with the new heir (or leave); append messages to `msgs`.
func on_succession(_d: GameDynasty, _msgs: Array) -> void:
	pass


## Allies for a new battle (see GameBattle.allies).
func battle_allies(_d: GameDynasty) -> Array:
	return []


## Town errands the autopilot runs between actions (no time passes).
static func bot_tick(_d: GameDynasty) -> void:
	pass


func to_dict() -> Dictionary:
	return {"members": members}


static func from_dict(v: Dictionary) -> GameParty:
	var p := GameParty.new()
	p.members = Array(v.get("members", []))
	return p
