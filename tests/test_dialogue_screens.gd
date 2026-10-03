## Tests for dialogue and quest screens (Phase 5 - Dialogue & Events)
##
## Tests: dialogue tree display, choice selection, quest details, quest acceptance

extends GutTest


var dialogue_system: DialogueSystem
var heir: Heir
var dialogue_screen: DialogueTreeScreen
var quest_screen: QuestDetailScreen


func before_each() -> void:
	dialogue_system = DialogueSystem.new()
	heir = Heir.new()
	heir.name = "Hero"
	heir.class_id = "warrior"
	heir.generation = 5


## Test: Dialogue system initializes
func test_dialogue_system_init() -> void:
	assert_not_null(dialogue_system)
	assert_true(dialogue_system.dialogues.size() > 0)


## Test: Get beast slayer quest dialogue
func test_get_beast_slayer_quest() -> void:
	var start_node = dialogue_system.get_dialogue("beast_slayer")
	assert_not_null(start_node)
	assert_eq(start_node.id, "beast_start")
	assert_eq(start_node.speaker, "Village Elder")


## Test: Beast slayer quest has two choices
func test_beast_slayer_has_choices() -> void:
	var start_node = dialogue_system.get_dialogue("beast_slayer")
	var choices = dialogue_system.get_choices(start_node)
	assert_eq(choices.size(), 2)


## Test: Get next dialogue node
func test_get_next_dialogue_node() -> void:
	var accept_node = dialogue_system.get_next_node("beast_slayer", "beast_accept")
	assert_not_null(accept_node)
	assert_eq(accept_node.id, "beast_accept")


## Test: Apply dialogue outcome
func test_apply_dialogue_outcome() -> void:
	var outcome = {"reward_gold": 100, "reward_reputation": 25}
	var result = dialogue_system.apply_outcome(outcome, heir)

	assert_eq(result["gold_gained"], 100)
	assert_eq(result["reputation_gained"], 25)


## Test: Quest acceptance outcome
func test_quest_acceptance_outcome() -> void:
	var outcome = {"quest_accepted": true, "reward_gold": 150}
	var result = dialogue_system.apply_outcome(outcome, heir)

	assert_true(result["quest_started"])
	assert_eq(result["gold_gained"], 150)


## Test: Artifact recovery quest
func test_artifact_recovery_quest() -> void:
	var start_node = dialogue_system.get_dialogue("artifact_recovery")
	assert_not_null(start_node)
	assert_eq(start_node.id, "artifact_start")


## Test: Artifact quest has details option
func test_artifact_quest_details_option() -> void:
	var start_node = dialogue_system.get_dialogue("artifact_recovery")
	var choices = dialogue_system.get_choices(start_node)
	var has_details = false
	for choice in choices:
		if "details" in choice.text.to_lower():
			has_details = true
	assert_true(has_details)


## Test: Merchant escort quest
func test_merchant_escort_quest() -> void:
	var start_node = dialogue_system.get_dialogue("merchant_escort")
	assert_not_null(start_node)
	assert_eq(start_node.id, "escort_start")


## Test: Innkeeper dialogue
func test_innkeeper_dialogue() -> void:
	var greeting = dialogue_system.get_dialogue("innkeeper")
	assert_not_null(greeting)
	assert_eq(greeting.id, "inn_greeting")
	assert_eq(greeting.speaker, "Innkeeper")


## Test: Merchant dialogue
func test_merchant_dialogue() -> void:
	var greeting = dialogue_system.get_dialogue("merchant")
	assert_not_null(greeting)
	assert_eq(greeting.id, "merchant_greeting")


## Test: Dialogue outcome with trait reward
func test_dialogue_outcome_with_trait() -> void:
	var outcome = {
		"quest_type": "retrieve",
		"reward_trait": "mageblood",
		"reward_reputation": 40
	}
	var result = dialogue_system.apply_outcome(outcome, heir)
	assert_eq(result["reputation_gained"], 40)


## Test: Quest detail screen initialization
func test_quest_detail_screen_init() -> void:
	var quest_data = {
		"quest_type": "hunt",
		"target": "Feral Beast",
		"location": "Eastern Caves",
		"reward_gold": 150,
		"reward_reputation": 30,
		"difficulty": 2
	}
	quest_screen = QuestDetailScreen.new(quest_data, heir)
	assert_not_null(quest_screen)


## Test: Quest detail screen stores quest data
func test_quest_detail_screen_quest_data() -> void:
	var quest_data = {
		"quest_type": "retrieve",
		"target": "Stolen Runestone",
		"location": "Catacombs",
		"reward_gold": 200,
		"difficulty": 3
	}
	quest_screen = QuestDetailScreen.new(quest_data, heir)
	assert_eq(quest_screen.quest_data, quest_data)


## Test: Dialogue tree screen initialization
func test_dialogue_tree_screen_init() -> void:
	dialogue_screen = DialogueTreeScreen.new(dialogue_system, "beast_slayer", heir)
	assert_not_null(dialogue_screen)
	assert_eq(dialogue_screen.current_tree_key, "beast_slayer")


## Test: Dialogue tree screen starts with correct node
func test_dialogue_tree_screen_starting_node() -> void:
	dialogue_screen = DialogueTreeScreen.new(dialogue_system, "merchant_escort", heir)
	assert_not_null(dialogue_screen.current_node)
	assert_eq(dialogue_screen.current_node.id, "escort_start")


## Test: Consequence notification screen initialization
func test_consequence_notification_init() -> void:
	var consequences = {
		"gold_gained": 100,
		"reputation_gained": 25,
		"quest_started": true,
		"items_gained": []
	}
	var notification = ConsequenceNotificationScreen.new(consequences, heir)
	assert_not_null(notification)


## Test: Consequence notification stores consequences
func test_consequence_notification_stores_data() -> void:
	var consequences = {
		"gold_gained": 150,
		"reputation_gained": 30,
		"quest_started": false
	}
	var notification = ConsequenceNotificationScreen.new(consequences, heir)
	assert_eq(notification.consequences, consequences)


## Test: Consequence notification with items
func test_consequence_notification_with_items() -> void:
	var consequences = {
		"gold_gained": 0,
		"reputation_gained": 0,
		"quest_started": false,
		"items_gained": ["Health Potion", "Ancient Map"]
	}
	var notification = ConsequenceNotificationScreen.new(consequences, heir)
	assert_eq(notification.consequences["items_gained"].size(), 2)
