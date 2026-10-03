## Events with skill checks and degrees of success. An event waiting for the player's choice
## is stored in GameDynasty.pending_event.
class_name GameEvents
extends RefCounted


## The heir spends time exploring the current place; may set d.pending_event.
static func explore(d: GameDynasty) -> Array:
	return d._finish_time("explore", ["%s explores %s but finds nothing of note." % [d.heir.name, d.world.here()["name"]]])


## Something may happen on arrival after travelling; may set d.pending_event.
static func on_arrive(_d: GameDynasty, _place_id: String) -> Array:
	return []


## Resolve the pending event with the chosen option.
static func resolve(_d: GameDynasty, _choice: int) -> Array:
	return []


static func bot_resolve(_d: GameDynasty) -> void:
	pass


static func bot_wants_explore(_d: GameDynasty) -> bool:
	return false
