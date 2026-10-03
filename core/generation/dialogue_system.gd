## Dialogue System: manages dialogue trees and conversations
##
## Supports branching dialogue with choices and outcomes

extends Node

class_name DialogueSystem


## Dialogue node in conversation tree
class DialogueNode:
	var id: String
	var speaker: String
	var text: String
	var choices: Array[DialogueChoice] = []
	var outcome: Dictionary = {}  # Quest rewards, reputation changes, etc.


## Dialogue choice (player response option)
class DialogueChoice:
	var text: String
	var next_node: String
	var conditions: Array[String] = []  # Requirements to show this choice
	var outcome: Dictionary = {}  # Immediate effects of choosing this


## All dialogue trees by key
var dialogues: Dictionary = {}


func _init() -> void:
	_initialize_dialogues()


func _initialize_dialogues() -> void:
	# Quest dialogue trees
	_add_beast_slayer_quest()
	_add_artifact_recovery_quest()
	_add_village_escort_quest()

	# NPC dialogue trees
	_add_merchant_dialogue()
	_add_innkeeper_dialogue()


## Quest: Slay the Beast
func _add_beast_slayer_quest() -> void:
	var start = DialogueNode.new()
	start.id = "beast_start"
	start.speaker = "Village Elder"
	start.text = "A terrible beast has been terrorizing our livestock. We desperately need help. Will you hunt it down?"

	var accept_choice = DialogueChoice.new()
	accept_choice.text = "I will slay this beast for you!"
	accept_choice.next_node = "beast_accept"
	accept_choice.outcome = {"quest_accepted": true}
	start.choices.append(accept_choice)

	var refuse_choice = DialogueChoice.new()
	refuse_choice.text = "This doesn't concern me."
	refuse_choice.next_node = "beast_refuse"
	refuse_choice.outcome = {"quest_accepted": false, "reputation_loss": 10}
	start.choices.append(refuse_choice)

	var quest_node = DialogueNode.new()
	quest_node.id = "beast_accept"
	quest_node.speaker = "Village Elder"
	quest_node.text = "Excellent! The beast lurks in the caves to the east. It's massive and dangerous. Here's a map and some supplies."
	quest_node.outcome = {
		"quest_type": "hunt",
		"target": "Feral Beast",
		"location": "Eastern Caves",
		"reward_gold": 150,
		"reward_reputation": 30,
		"difficulty": 2
	}

	var refuse_node = DialogueNode.new()
	refuse_node.id = "beast_refuse"
	refuse_node.speaker = "Village Elder"
	refuse_node.text = "Very well. Perhaps another will help us... if they have more courage than you."

	dialogues["beast_slayer"] = {
		"start": start,
		"accept": quest_node,
		"refuse": refuse_node
	}


## Quest: Recover Stolen Artifact
func _add_artifact_recovery_quest() -> void:
	var start = DialogueNode.new()
	start.id = "artifact_start"
	start.speaker = "Mage Scholar"
	start.text = "A powerful magical artifact was stolen from the tower! Without it, we cannot conduct important research. Will you recover it?"

	var investigate = DialogueChoice.new()
	investigate.text = "I'll track down the thieves."
	investigate.next_node = "artifact_investigate"
	investigate.outcome = {"quest_accepted": true}
	start.choices.append(investigate)

	var details = DialogueChoice.new()
	details.text = "Tell me more details first."
	details.next_node = "artifact_details"
	start.choices.append(details)

	var quest_node = DialogueNode.new()
	quest_node.id = "artifact_investigate"
	quest_node.speaker = "Mage Scholar"
	quest_node.text = "The thieves were spotted heading toward the underground catacombs. The artifact glows with arcane energy - you'll recognize it."
	quest_node.outcome = {
		"quest_type": "retrieve",
		"target": "Stolen Runestone",
		"location": "Catacombs",
		"reward_gold": 200,
		"reward_reputation": 40,
		"difficulty": 3,
		"reward_trait": "mageblood"
	}

	var details_node = DialogueNode.new()
	details_node.id = "artifact_details"
	details_node.speaker = "Mage Scholar"
	details_node.text = "The thieves were mercenaries - likely hired by someone jealous of our progress. The artifact is an ancient Runestone. It's priceless to our order."

	var details_accept = DialogueChoice.new()
	details_accept.text = "I'll recover it for you."
	details_accept.next_node = "artifact_investigate"
	details_node.choices.append(details_accept)

	dialogues["artifact_recovery"] = {
		"start": start,
		"investigate": quest_node,
		"details": details_node
	}


## Quest: Escort Merchant Caravan
func _add_village_escort_quest() -> void:
	var start = DialogueNode.new()
	start.id = "escort_start"
	start.speaker = "Merchant Captain"
	start.text = "Our caravan needs protection for the journey to the capital. Bandits have been active on the road. Can you protect us?"

	var agree = DialogueChoice.new()
	agree.text = "I'll keep your caravan safe."
	agree.next_node = "escort_agree"
	agree.outcome = {"quest_accepted": true}
	start.choices.append(agree)

	var negotiate = DialogueChoice.new()
	negotiate.text = "What's your offer?"
	negotiate.next_node = "escort_negotiate"
	start.choices.append(negotiate)

	var quest_node = DialogueNode.new()
	quest_node.id = "escort_agree"
	quest_node.speaker = "Merchant Captain"
	quest_node.text = "Excellent! We leave at dawn. The journey takes 3 days. Just keep the bandits at bay."
	quest_node.outcome = {
		"quest_type": "escort",
		"target": "Merchant Caravan",
		"location": "Road to Capital",
		"reward_gold": 120,
		"reward_reputation": 25,
		"difficulty": 1,
		"duration": 3
	}

	var negotiate_node = DialogueNode.new()
	negotiate_node.id = "escort_negotiate"
	negotiate_node.speaker = "Merchant Captain"
	negotiate_node.text = "We can pay you 150 gold, plus a share of the profits. That's generous for a 3-day journey."

	var negotiate_accept = DialogueChoice.new()
	negotiate_accept.text = "Deal! I'll protect you."
	negotiate_accept.next_node = "escort_agree"
	negotiate_node.choices.append(negotiate_accept)

	dialogues["merchant_escort"] = {
		"start": start,
		"agree": quest_node,
		"negotiate": negotiate_node
	}


## NPC: Innkeeper dialogue
func _add_innkeeper_dialogue() -> void:
	var greeting = DialogueNode.new()
	greeting.id = "inn_greeting"
	greeting.speaker = "Innkeeper"
	greeting.text = "Welcome! What can I get you?"

	var rest = DialogueChoice.new()
	rest.text = "I need a room for the night."
	rest.next_node = "inn_rest"
	rest.outcome = {"action": "rest", "cost": 10}
	greeting.choices.append(rest)

	var drink = DialogueChoice.new()
	drink.text = "Pour me an ale."
	drink.next_node = "inn_drink"
	drink.outcome = {"action": "drink", "cost": 5}
	greeting.choices.append(drink)

	var gossip = DialogueChoice.new()
	gossip.text = "Any news or rumors?"
	gossip.next_node = "inn_gossip"
	greeting.choices.append(gossip)

	dialogues["innkeeper"] = {"greeting": greeting}


## NPC: Merchant dialogue
func _add_merchant_dialogue() -> void:
	var greeting = DialogueNode.new()
	greeting.id = "merchant_greeting"
	greeting.speaker = "Merchant"
	greeting.text = "Looking for quality goods? I have the best selection in town."

	var buy = DialogueChoice.new()
	buy.text = "Show me your wares."
	buy.next_node = "merchant_shop"
	buy.outcome = {"action": "open_shop"}
	greeting.choices.append(buy)

	var quest = DialogueChoice.new()
	quest.text = "Do you need anything delivered?"
	quest.next_node = "merchant_quest"
	greeting.choices.append(quest)

	dialogues["merchant"] = {"greeting": greeting}


## Get a dialogue tree by key
func get_dialogue(key: String) -> DialogueNode:
	if dialogues.has(key):
		var tree = dialogues[key]
		if tree.has("start"):
			return tree["start"]
	return null


## Get next dialogue node
func get_next_node(tree_key: String, node_id: String) -> DialogueNode:
	if dialogues.has(tree_key):
		var tree = dialogues[tree_key]
		if tree.has(node_id):
			return tree[node_id]
	return null


## Get dialogue choices for a node
func get_choices(node: DialogueNode) -> Array[DialogueChoice]:
	return node.choices


## Apply dialogue outcome
func apply_outcome(outcome: Dictionary, heir: Heir) -> Dictionary:
	var result = {
		"gold_gained": 0,
		"reputation_gained": 0,
		"quest_started": false,
		"items_gained": []
	}

	if outcome.has("reward_gold"):
		result["gold_gained"] = outcome["reward_gold"]

	if outcome.has("reward_reputation"):
		result["reputation_gained"] = outcome["reward_reputation"]

	if outcome.has("quest_accepted") and outcome["quest_accepted"]:
		result["quest_started"] = true

	return result
