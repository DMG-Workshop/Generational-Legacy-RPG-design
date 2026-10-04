## Items, equipment and shops. Item effects use the same stat names as trait effects and are
## added into GameHeir.trait_total, so equipped gear works everywhere a trait does.
class_name GameItems
extends RefCounted

const SLOTS := ["weapon", "armor", "trinket"]


static func item_def(id: String) -> Dictionary:
	GameData.load_all()
	return GameData.items.get(id, {})


## Town errands the autopilot runs between actions (no time passes).
static func bot_tick(_d: GameDynasty) -> void:
	pass
