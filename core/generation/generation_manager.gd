## Generation Manager: orchestrates the flow of one heir's life
##
## A single heir:
## 1. Is born with inherited traits and stats
## 2. Grows through life events (quests, battles, romances)
## 3. Ages and eventually dies
## 4. Passes the bloodline to a chosen child
## 5. Becomes an NPC ancestor

extends Node

class_name GenerationManager


## Life phases
enum LifePhase {
	CHILDHOOD,      # Age 0-12: bonding with parents, learning
	ADOLESCENCE,    # Age 13-17: first quest, finding identity
	ADULTHOOD,      # Age 18-50: main story, building legacy
	ELDERHOOD,      # Age 51-65: mentoring next generation
	DEATH           # Age 65+: end of life
}


## Current heir
var current_heir: Heir = null

## Lineage system (to manage family tree)
var lineage: Lineage = null

## World manager (to access realms and properties)
var world: WorldManager = null

## NPC system (to track old heirs as NPCs)
var npc_system: NPCSystem = null

## Reputation system (faction standing)
var reputation_system: ReputationSystem = null

## Estate manager (family properties)
var estate_manager: EstateManager = null

## Event system (generates life events)
var event_system: EventSystem = null

## Current age (in years)
var current_age: int = 0

## Current life phase
var current_phase: LifePhase = LifePhase.CHILDHOOD

## Life events (quests, battles, romances completed)
var life_events: Array[String] = []

## Wealth and possessions
var current_wealth: int = 0

## Relationships (spouse, children, mentor)
var spouse: Heir = null
var children: Array[Heir] = []
var mentor: Heir = null  # Old parent or legendary companion


func _init(p_lineage: Lineage, p_world: WorldManager) -> void:
	lineage = p_lineage
	world = p_world
	npc_system = NPCSystem.new()
	reputation_system = ReputationSystem.new()
	estate_manager = EstateManager.new()
	event_system = EventSystem.new()


## Start a new generation with an heir
func begin_generation(heir: Heir) -> void:
	current_heir = heir
	current_age = 0
	current_phase = LifePhase.CHILDHOOD
	life_events = []
	current_wealth = 100  # Starting wealth
	children = []
	spouse = null

	# Find mentor (previous heir as NPC)
	if heir.father != null and heir.father.is_alive == false:
		mentor = heir.father


## Advance one year of life
func advance_year() -> Dictionary:
	var event = {
		"year": current_age,
		"phase": current_phase,
		"event_type": "age_advance"
	}

	current_age += 1

	# Update life phase based on age
	_update_life_phase()

	# Generate a random event using the event system
	var generated_event = event_system.generate_event(
		current_heir,
		current_age,
		current_phase,
		reputation_system.factions
	)

	if generated_event.get("type") != "none":
		event.merge(generated_event)

	# Check for random life events
	_check_random_events()

	# Age-based effects
	if current_age >= 65:
		# Natural death
		current_heir.is_alive = false
		current_heir.death_year = current_age
		current_heir.death_cause = "Old age"
		event["event_type"] = "death"

	return event


## Update life phase based on age
func _update_life_phase() -> void:
	if current_age < 13:
		current_phase = LifePhase.CHILDHOOD
	elif current_age < 18:
		current_phase = LifePhase.ADOLESCENCE
	elif current_age < 51:
		current_phase = LifePhase.ADULTHOOD
	elif current_age < 66:
		current_phase = LifePhase.ELDERHOOD
	else:
		current_phase = LifePhase.DEATH


## Check for random life events (marriage, children, tragedy)
func _check_random_events() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = current_heir.generation * 12345 + current_age

	# Adulthood: chance of marriage
	if current_phase == LifePhase.ADULTHOOD and spouse == null:
		if rng.randf() < 0.05:  # 5% chance per year
			_trigger_marriage()

	# After marriage: chance of children
	if spouse != null and current_phase == LifePhase.ADULTHOOD:
		if rng.randf() < 0.10:  # 10% chance per year
			_trigger_birth()

	# Elderhood: mentoring skills
	if current_phase == LifePhase.ELDERHOOD and rng.randf() < 0.02:
		life_events.append("mentored_heir")


## Trigger marriage event
func _trigger_marriage() -> void:
	# TODO: Generate spouse from world
	spouse = Heir.new()
	spouse.name = "Spouse of " + current_heir.name
	spouse.generation = current_heir.generation
	life_events.append("marriage")


## Trigger birth event
func _trigger_birth() -> void:
	var child = Heir.new()
	child.name = "Child of " + current_heir.name
	child.generation = current_heir.generation + 1
	child.mother = current_heir
	child.father = spouse
	child.traits = []
	child.birth_year = current_age

	# Inherit traits from both parents
	lineage._inherit_traits(child, current_heir, spouse)

	children.append(child)
	life_events.append("child_born")


## Transition to next heir (end of life)
func transition_to_heir(chosen_child: Heir) -> Dictionary:
	if chosen_child not in children:
		return {"success": false, "reason": "Child not in bloodline"}

	# Age out current heir
	if current_heir.is_alive:
		current_heir.is_alive = false
		current_heir.death_year = current_age
		current_heir.death_cause = "Retired from active play"

	# Make old heir an NPC
	npc_system.add_npc_ancestor(current_heir, current_heir.generation)

	# Add old heir's tomb to Hollow Below
	var tomb = estate_manager.create_property(
		"hollow",
		Vector3i(current_heir.generation, 0, 100),
		"tomb"
	)
	tomb["ancestor"] = current_heir

	# Begin new heir's generation
	begin_generation(chosen_child)

	return {
		"success": true,
		"old_heir": current_heir,
		"new_heir": chosen_child,
		"generations_passed": current_heir.generation
	}


## Get life summary for display
func get_life_summary() -> Dictionary:
	return {
		"heir": current_heir.name,
		"generation": current_heir.generation,
		"age": current_age,
		"phase": LifePhase.keys()[current_phase],
		"traits": current_heir.traits,
		"wealth": current_wealth,
		"children": children.size(),
		"spouse": spouse.name if spouse else "None",
		"events": life_events.size(),
		"is_alive": current_heir.is_alive,
	}


## Gain wealth from quest or business
func gain_wealth(amount: int) -> void:
	current_wealth += amount


## Gain reputation with faction
func gain_reputation(faction: String, amount: int) -> void:
	reputation_system.add_reputation(current_heir.generation, faction, amount)


## Execute a quest (outcome affects inheritance)
func execute_quest(quest_id: String) -> Dictionary:
	var outcome = {
		"quest": quest_id,
		"success": randf() > 0.3,  # 70% success rate
		"reward_wealth": 50,
		"reward_reputation": "general",
		"event": quest_id
	}

	if outcome["success"]:
		gain_wealth(outcome["reward_wealth"])
		gain_reputation("general", 20)
		life_events.append("quest_" + quest_id + "_success")
	else:
		life_events.append("quest_" + quest_id + "_failure")

	return outcome


## Mentor the next heir (improves their starting stats)
func mentor_child(child: Heir) -> void:
	# Boost child's stats based on parent's skills
	for i in range(child.stats.size()):
		var stat_key = child.stats.keys()[i]
		child.stats[stat_key] += 2  # +2 to all stats from mentoring

	child.traits.append("mentored")  # Special trait marking this


## Get all available heirs (children)
func get_heir_options() -> Array[Heir]:
	return children.filter(func(c): return c.is_alive or c.birth_year > 0)
