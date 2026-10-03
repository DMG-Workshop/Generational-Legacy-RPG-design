## Dialogue System: Dialogue trees, conversations, and NPC dialogue
##
## Manages dialogue nodes, conditions, choices, and conversation state

extends Node

class_name DialogueSystem


signal dialogue_started(npc_id: String, dialogue_id: String)
signal dialogue_choice_made(npc_id: String, choice_index: int)
signal dialogue_ended(npc_id: String)
signal dialogue_outcome_triggered(outcome_type: String, data: Dictionary)


var dialogue_trees: Dictionary = {}
var active_conversations: Dictionary = {}


class DialogueNode:
	var id: String
	var text: String
	var speaker: String
	var choices: Array = []
	var conditions: Dictionary = {}
	var outcomes: Array = []
	
	func _init(p_id: String, p_text: String, p_speaker: String = "npc") -> void:
		id = p_id
		text = p_text
		speaker = p_speaker


class DialogueChoice:
	var text: String
	var next_node_id: String
	var condition: String = ""
	var outcome: Dictionary = {}
	
	func _init(p_text: String, p_next_id: String) -> void:
		text = p_text
		next_node_id = p_next_id


class Conversation:
	var npc_id: String
	var dialogue_id: String
	var current_node_id: String
	var history: Array = []
	var variables: Dictionary = {}
	
	func _init(p_npc_id: String, p_dialogue_id: String, p_start_node: String) -> void:
		npc_id = p_npc_id
		dialogue_id = p_dialogue_id
		current_node_id = p_start_node


func _init() -> void:
	dialogue_trees = {}
	active_conversations = {}


func create_dialogue_tree(dialogue_id: String) -> void:
	if not dialogue_trees.has(dialogue_id):
		dialogue_trees[dialogue_id] = {}


func add_dialogue_node(dialogue_id: String, node_id: String, text: String, speaker: String = "npc") -> void:
	if not dialogue_trees.has(dialogue_id):
		create_dialogue_tree(dialogue_id)
	
	var node = DialogueNode.new(node_id, text, speaker)
	dialogue_trees[dialogue_id][node_id] = node


func add_dialogue_choice(dialogue_id: String, from_node_id: String, choice_text: String, to_node_id: String) -> void:
	if not dialogue_trees.has(dialogue_id):
		return
	
	var node = dialogue_trees[dialogue_id].get(from_node_id)
	if node:
		var choice = DialogueChoice.new(choice_text, to_node_id)
		node.choices.append(choice)


func start_dialogue(npc_id: String, dialogue_id: String, start_node: String = "start") -> bool:
	if not dialogue_trees.has(dialogue_id):
		return false
	
	var conversation = Conversation.new(npc_id, dialogue_id, start_node)
	active_conversations[npc_id] = conversation
	dialogue_started.emit(npc_id, dialogue_id)
	return true


func get_current_dialogue_text(npc_id: String) -> String:
	var conversation = active_conversations.get(npc_id)
	if not conversation:
		return ""
	
	var tree = dialogue_trees.get(conversation.dialogue_id)
	if not tree:
		return ""
	
	var node = tree.get(conversation.current_node_id)
	if node:
		return node.text
	
	return ""


func get_current_dialogue_choices(npc_id: String) -> Array:
	var conversation = active_conversations.get(npc_id)
	if not conversation:
		return []
	
	var tree = dialogue_trees.get(conversation.dialogue_id)
	if not tree:
		return []
	
	var node = tree.get(conversation.current_node_id)
	if node:
		var choice_texts = []
		for choice in node.choices:
			choice_texts.append(choice.text)
		return choice_texts
	
	return []


func make_dialogue_choice(npc_id: String, choice_index: int) -> bool:
	var conversation = active_conversations.get(npc_id)
	if not conversation:
		return false
	
	var tree = dialogue_trees.get(conversation.dialogue_id)
	if not tree:
		return false
	
	var node = tree.get(conversation.current_node_id)
	if not node or choice_index >= node.choices.size():
		return false
	
	var choice = node.choices[choice_index]
	conversation.current_node_id = choice.next_node_id
	conversation.history.append({"node": node.id, "choice": choice_index})
	dialogue_choice_made.emit(npc_id, choice_index)
	
	if choice.outcome.size() > 0:
		_apply_dialogue_outcome(npc_id, choice.outcome)
	
	if conversation.current_node_id == "end":
		end_dialogue(npc_id)
	
	return true


func end_dialogue(npc_id: String) -> void:
	active_conversations.erase(npc_id)
	dialogue_ended.emit(npc_id)


func is_in_dialogue(npc_id: String) -> bool:
	return active_conversations.has(npc_id)


func _apply_dialogue_outcome(npc_id: String, outcome: Dictionary) -> void:
	if outcome.has("gift"):
		dialogue_outcome_triggered.emit("gift", {"npc_id": npc_id, "item": outcome["gift"]})
	
	if outcome.has("reputation_change"):
		dialogue_outcome_triggered.emit("reputation", {"npc_id": npc_id, "delta": outcome["reputation_change"]})
	
	if outcome.has("gold"):
		dialogue_outcome_triggered.emit("gold", {"npc_id": npc_id, "amount": outcome["gold"]})
	
	if outcome.has("quest_flag"):
		dialogue_outcome_triggered.emit("quest", {"quest": outcome["quest_flag"], "active": true})


func create_generic_greeting_tree() -> void:
	create_dialogue_tree("greeting")
	add_dialogue_node("greeting", "start", "Greetings, traveler! What brings you to our humble settlement?", "npc")
	add_dialogue_choice("greeting", "start", "Just passing through.", "end")
	add_dialogue_choice("greeting", "start", "I'm looking for work.", "work_question")
	
	add_dialogue_node("greeting", "work_question", "Ah, seeking employment? We could use strong hands around here.", "npc")
	add_dialogue_choice("greeting", "work_question", "I'm interested.", "end")
	add_dialogue_choice("greeting", "work_question", "Never mind.", "end")


func create_merchant_tree() -> void:
	create_dialogue_tree("merchant")
	add_dialogue_node("merchant", "start", "Welcome! Looking to buy or sell today?", "npc")
	add_dialogue_choice("merchant", "start", "Browse your wares.", "end")
	add_dialogue_choice("merchant", "start", "I have items to sell.", "end")


func create_inn_tree() -> void:
	create_dialogue_tree("innkeeper")
	add_dialogue_node("innkeeper", "start", "Welcome to my inn! A room for the night?", "npc")
	add_dialogue_choice("innkeeper", "start", "Yes, I'll take a room.", "end")
	add_dialogue_choice("innkeeper", "start", "Maybe later.", "end")


func get_dialogue_tree(dialogue_id: String) -> Dictionary:
	return dialogue_trees.get(dialogue_id, {})


func get_conversation_history(npc_id: String) -> Array:
	var conversation = active_conversations.get(npc_id)
	if conversation:
		return conversation.history.duplicate()
	return []
