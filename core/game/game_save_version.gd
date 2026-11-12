## Save versions: the number a save file carries, and the chain of steps that brings a save from an older
## game up to this one before it is read, one step per version, each tested. A save from a newer game is
## turned away rather than read wrongly. Logic only (GameSaves calls it before GameDynasty.from_dict).
class_name GameSaveVersion
extends RefCounted

## The version this game writes.
##   1: the dynasty between fights (every save from before versions were checked says 1).
##   2: a fight in progress may be saved with it, under "battle" (see GameDynasty.to_save).
const CURRENT := 2


## The version a save says it has: 1 when it says nothing readable.
static func of(d: Dictionary) -> int:
	var v = d.get("version", 1)
	return int(v) if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else 1


## Whether this game can read the save: it is not from a newer one.
static func readable(d: Dictionary) -> bool:
	return of(d) <= CURRENT


## Upgrades `d` in place, step by step, to CURRENT. "" when it can be read, else why it cannot.
static func upgrade(d: Dictionary) -> String:
	var v := of(d)
	if v > CURRENT:
		return GameMessages.text("life", "replay_newer")
	while v < CURRENT:
		match v:
			1:
				_to_2(d)
		v += 1
		d["version"] = v
	return ""


## 1 to 2: version 2 only adds a fight in progress, which no version 1 save holds, so nothing else moves.
static func _to_2(d: Dictionary) -> void:
	d.erase("battle")
