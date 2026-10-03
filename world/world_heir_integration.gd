## World-Heir Integration: Connect heir actions to world systems
##
## Manages heir exploration, settlement interaction, questing, and world state changes
## Applies rewards and consequences to heir progression

class_name WorldHeirIntegration


signal heir_moved(heir_name: String, from_pos: Vector2i, to_pos: Vector2i)
signal settlement_visited(heir_name: String, settlement_name: String)
signal quest_accepted(heir_name: String, quest_id: String)
signal world_action_completed(heir_name: String, action: String, rewards: Dictionary)


var world_system: WorldTileSystem
var settlement_system: SettlementSystem
var npc_system: NPCSystem

# Heir state tracking
var heir_positions: Dictionary = {}  # heir_name -> Vector2i
var heir_quests: Dictionary = {}  # heir_name -> [quest_ids]
var heir_recruited: Dictionary = {}  # heir_name -> [npc_names]


func _init(world: WorldTileSystem, settlements: SettlementSystem, npcs: NPCSystem) -> void:
	world_system = world
	settlement_system = settlements
	npc_system = npcs


## Initialize heir in world (spawn at settlement)
func initialize_heir_in_world(heir_name: String, settlement_name: String) -> Vector2i:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return Vector2i.ZERO

	var spawn_pos = settlement["position"]
	heir_positions[heir_name] = spawn_pos
	heir_quests[heir_name] = []
	heir_recruited[heir_name] = []

	return spawn_pos


## Move heir in world
func move_heir(heir_name: String, direction: Vector2i, distance: int = 1) -> Vector2i:
	if heir_name not in heir_positions:
		return Vector2i.ZERO

	var current_pos = heir_positions[heir_name]
	var new_pos = current_pos + (direction * distance)

	# Clamp to world bounds (let's say -1000 to 1000)
	new_pos = Vector2i(
		clampi(new_pos.x, -1000, 1000),
		clampi(new_pos.y, -1000, 1000)
	)

	heir_positions[heir_name] = new_pos
	heir_moved.emit(heir_name, current_pos, new_pos)

	return new_pos


## Get heir position
func get_heir_position(heir_name: String) -> Vector2i:
	return heir_positions.get(heir_name, Vector2i.ZERO)


## Visit settlement
func visit_settlement(heir_name: String, settlement_name: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	# Move heir to settlement
	heir_positions[heir_name] = settlement["position"]
	settlement_visited.emit(heir_name, settlement_name)

	# Get settlement summary
	return {
		"settlement": settlement_system.get_settlement_summary(settlement_name),
		"npcs": npc_system.get_settlement_npcs(settlement_name),
		"available_quests": 3,
		"building_effects": settlement_system.get_building_effects(settlement_name),
	}


## Accept quest from NPC
func accept_quest(heir_name: String, npc_name: String, heir_stats: Dictionary) -> Dictionary:
	if heir_name not in heir_quests:
		heir_quests[heir_name] = []

	var quest = npc_system.generate_quest(npc_name, heir_name, heir_stats)
	if not quest.is_empty():
		heir_quests[heir_name].append(quest["id"])
		quest_accepted.emit(heir_name, quest["id"])
		return quest

	return {}


## Complete quest (inherit from quest system, apply rewards)
func complete_quest(heir_name: String, quest_id: String, success: bool = true) -> Dictionary:
	if quest_id not in npc_system.quests:
		return {}

	var rewards = npc_system.complete_quest(quest_id, heir_name, success)

	if heir_name in heir_quests:
		heir_quests[heir_name].erase(quest_id)

	world_action_completed.emit(heir_name, "quest_completed", rewards)
	return rewards


## Train at settlement barracks
func train_at_barracks(heir_name: String, settlement_name: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	var barracks_level = settlement["buildings"].get(SettlementSystem.BuildingType.BARRACKS, 1)
	var stat_gain = 1 + (barracks_level * 0.5)

	var rewards = {
		"stat_bonus": int(stat_gain),
		"training_type": "strength",
		"settlement": settlement_name,
	}

	world_action_completed.emit(heir_name, "trained", rewards)
	return rewards


## Craft at settlement smithy
func craft_at_smithy(heir_name: String, settlement_name: String, equipment_type: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	var smithy_level = settlement["buildings"].get(SettlementSystem.BuildingType.SMITHY, 1)
	var craft_quality = 0.5 + (smithy_level * 0.1)  # 0.5 to 1.5
	var success_chance = clampi(0.4 + (smithy_level * 0.1), 0.4, 0.9)

	var success = randf() < success_chance

	var rewards = {
		"success": success,
		"equipment_type": equipment_type,
		"quality": craft_quality,
		"settlement": settlement_name,
	}

	if success:
		world_action_completed.emit(heir_name, "crafted", rewards)

	return rewards


## Get blessings at shrine
func seek_blessing_at_shrine(heir_name: String, settlement_name: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	var shrine_level = settlement["buildings"].get(SettlementSystem.BuildingType.SHRINE, 1)
	var blessing_chance = 0.3 + (shrine_level * 0.1)

	if randf() < blessing_chance:
		var stat_types = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
		var blessed_stat = stat_types.pick_random()
		var blessing_amount = 1 + (shrine_level - 1) * 0.5

		var rewards = {
			"blessed": true,
			"stat": blessed_stat,
			"amount": int(blessing_amount),
			"settlement": settlement_name,
		}

		world_action_completed.emit(heir_name, "blessed", rewards)
		return rewards

	return {
		"blessed": false,
		"settlement": settlement_name,
	}


## Recruit NPC at tavern
func recruit_at_tavern(heir_name: String, settlement_name: String, npc_name: String, payment: int) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	var tavern_level = settlement["buildings"].get(SettlementSystem.BuildingType.TAVERN, 1)
	var recruit_cost = 50 - (tavern_level * 5)  # Discounts with tavern level

	if payment < recruit_cost:
		return {"success": false, "reason": "insufficient_payment"}

	if npc_system.recruit_npc(npc_name, heir_name, payment):
		if heir_name not in heir_recruited:
			heir_recruited[heir_name] = []
		heir_recruited[heir_name].append(npc_name)

		var rewards = {
			"npc_recruited": npc_name,
			"cost": recruit_cost,
			"actual_payment": payment,
			"settlement": settlement_name,
		}

		world_action_completed.emit(heir_name, "recruited", rewards)
		return rewards

	return {"success": false, "reason": "recruitment_failed"}


## Upgrade building in settlement (requires resources)
func upgrade_settlement_building(heir_name: String, settlement_name: String, building_type: int) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_name)
	if settlement.is_empty():
		return {}

	var current_level = settlement["buildings"].get(building_type, 1)
	if current_level >= 5:
		return {"success": false, "reason": "max_level_reached"}

	if settlement_system.upgrade_building(settlement_name, building_type):
		var rewards = {
			"success": true,
			"building": SettlementSystem.BuildingType.keys()[building_type],
			"new_level": settlement["buildings"][building_type],
			"settlement": settlement_name,
		}

		world_action_completed.emit(heir_name, "building_upgraded", rewards)
		return rewards

	return {"success": false, "reason": "insufficient_resources"}


## Get heir world summary
func get_heir_world_summary(heir_name: String) -> Dictionary:
	var position = heir_positions.get(heir_name, Vector2i.ZERO)
	var nearest_settlement = settlement_system.get_nearest_settlement(position)

	return {
		"position": position,
		"nearest_settlement": nearest_settlement,
		"active_quests": heir_quests.get(heir_name, []).size(),
		"recruited_npcs": heir_recruited.get(heir_name, []).size(),
		"visited_settlements": [],  # Track separately if needed
	}
