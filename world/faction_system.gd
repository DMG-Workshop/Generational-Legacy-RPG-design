## Faction System: Global faction definitions and standings
##
## Manages factions, their relationships, and world-wide standings

extends Node

class_name FactionSystem


signal faction_created(faction_id: String, name: String)
signal faction_reputation_changed(faction_id: String, reputation: int)
signal faction_war_declared(faction1: String, faction2: String)
signal faction_alliance_formed(faction1: String, faction2: String)
signal faction_truce_declared(faction1: String, faction2: String)


enum FactionAlignment { GOOD, EVIL, NEUTRAL }

var factions: Dictionary = {}
var faction_relations: Dictionary = {}


class Faction:
	var id: String
	var name: String
	var alignment: int
	var color: Color
	var description: String
	var player_reputation: int = 0
	var territory: Array = []
	var resources: Dictionary = {}
	var member_count: int = 0
	var created_at_tick: int = 0
	
	func _init(p_id: String, p_name: String, p_alignment: int, p_color: Color) -> void:
		id = p_id
		name = p_name
		alignment = p_alignment
		color = p_color


func _init() -> void:
	factions = {}
	faction_relations = {}
	_initialize_default_factions()


func _initialize_default_factions() -> void:
	create_faction("empire", "The Empire", FactionAlignment.GOOD, Color.BLUE, "A unified realm of order and law")
	create_faction("syndicate", "The Syndicate", FactionAlignment.EVIL, Color.RED, "A network of shadows and schemes")
	create_faction("ancients", "The Ancients", FactionAlignment.NEUTRAL, Color.PURPLE, "Mysterious keepers of forgotten knowledge")
	create_faction("wilderness", "Wilderness Tribes", FactionAlignment.NEUTRAL, Color.GREEN, "Free peoples of nature and primal forces")
	
	set_faction_relation("empire", "syndicate", -50)
	set_faction_relation("empire", "ancients", 10)
	set_faction_relation("empire", "wilderness", 0)
	set_faction_relation("syndicate", "ancients", -30)
	set_faction_relation("syndicate", "wilderness", 20)
	set_faction_relation("ancients", "wilderness", 15)


func create_faction(faction_id: String, name: String, alignment: int, color: Color, description: String = "") -> String:
	var faction = Faction.new(faction_id, name, alignment, color)
	faction.description = description
	factions[faction_id] = faction
	faction_created.emit(faction_id, name)
	return faction_id


func get_faction(faction_id: String) -> Faction:
	return factions.get(faction_id)


func add_faction_reputation(faction_id: String, amount: int) -> void:
	var faction = factions.get(faction_id)
	if faction:
		faction.player_reputation = clamp(faction.player_reputation + amount, -100, 100)
		faction_reputation_changed.emit(faction_id, faction.player_reputation)


func remove_faction_reputation(faction_id: String, amount: int) -> void:
	add_faction_reputation(faction_id, -amount)


func get_faction_reputation(faction_id: String) -> int:
	var faction = factions.get(faction_id)
	if faction:
		return faction.player_reputation
	return 0


func get_faction_tier(faction_id: String) -> String:
	var reputation = get_faction_reputation(faction_id)
	
	if reputation < -50:
		return "hostile"
	elif reputation < -25:
		return "unfriendly"
	elif reputation < 25:
		return "neutral"
	elif reputation < 50:
		return "friendly"
	else:
		return "allied"


func set_faction_relation(faction1_id: String, faction2_id: String, relation_value: int) -> void:
	var key = "%s_%s" % [faction1_id, faction2_id]
	faction_relations[key] = clamp(relation_value, -100, 100)


func get_faction_relation(faction1_id: String, faction2_id: String) -> int:
	var key = "%s_%s" % [faction1_id, faction2_id]
	if faction_relations.has(key):
		return faction_relations[key]
	
	key = "%s_%s" % [faction2_id, faction1_id]
	if faction_relations.has(key):
		return -faction_relations[key]
	
	return 0


func are_factions_at_war(faction1_id: String, faction2_id: String) -> bool:
	return get_faction_relation(faction1_id, faction2_id) < -50


func are_factions_allied(faction1_id: String, faction2_id: String) -> bool:
	return get_faction_relation(faction1_id, faction2_id) > 50


func declare_war(faction1_id: String, faction2_id: String) -> void:
	set_faction_relation(faction1_id, faction2_id, -75)
	set_faction_relation(faction2_id, faction1_id, -75)
	faction_war_declared.emit(faction1_id, faction2_id)


func form_alliance(faction1_id: String, faction2_id: String) -> void:
	set_faction_relation(faction1_id, faction2_id, 75)
	set_faction_relation(faction2_id, faction1_id, 75)
	faction_alliance_formed.emit(faction1_id, faction2_id)


func declare_truce(faction1_id: String, faction2_id: String) -> void:
	set_faction_relation(faction1_id, faction2_id, 0)
	set_faction_relation(faction2_id, faction1_id, 0)
	faction_truce_declared.emit(faction1_id, faction2_id)


func get_faction_info(faction_id: String) -> Dictionary:
	var faction = factions.get(faction_id)
	if not faction:
		return {}
	
	return {
		"id": faction.id,
		"name": faction.name,
		"alignment": FactionAlignment.keys()[faction.alignment],
		"color": faction.color,
		"description": faction.description,
		"player_reputation": faction.player_reputation,
		"tier": get_faction_tier(faction_id),
		"members": faction.member_count
	}


func get_all_factions() -> Array:
	return factions.values()


func get_faction_summary() -> Dictionary:
	var summary = {}
	for faction in factions.values():
		summary[faction.id] = {
			"name": faction.name,
			"reputation": faction.player_reputation,
			"tier": get_faction_tier(faction.id)
		}
	return summary


func add_faction_members(faction_id: String, count: int) -> void:
	var faction = factions.get(faction_id)
	if faction:
		faction.member_count += count


func add_faction_territory(faction_id: String, location: Vector2i) -> void:
	var faction = factions.get(faction_id)
	if faction and location not in faction.territory:
		faction.territory.append(location)


func get_controlling_faction(location: Vector2i) -> String:
	for faction in factions.values():
		if location in faction.territory:
			return faction.id
	return ""


func get_faction_resources(faction_id: String) -> Dictionary:
	var faction = factions.get(faction_id)
	if faction:
		return faction.resources.duplicate()
	return {}
