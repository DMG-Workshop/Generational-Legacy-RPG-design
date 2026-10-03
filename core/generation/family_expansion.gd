## Family Expansion: Multiple heirs and inheritance system
##
## Manages multiple children per generation, inheritance choices,
## and family dynamics affecting heir capabilities

class_name FamilyExpansion


signal child_born(parent: Heir, child: Heir)
signal heir_chosen(chosen: Heir, siblings: Array[Heir])
signal family_reputation_changed(family_name: String, new_value: int)
signal sibling_conflict(heir: Heir, rival: Heir)


# Family reputation (shared across generation)
var family_reputation: Dictionary = {}  # family_name -> reputation_value

# Multiple children per heir
var children_per_heir: Dictionary = {}  # heir_id -> Array[Heir]

# Inheritance choices
var inheritance_history: Dictionary = {}  # heir_id -> chosen_child_id


func _init() -> void:
	family_reputation = {}
	children_per_heir = {}
	inheritance_history = {}


## Add a child to an heir
func add_child(parent: Heir, child: Heir) -> void:
	if not parent:
		return
	
	var parent_id = parent.to_string()
	if parent_id not in children_per_heir:
		children_per_heir[parent_id] = []
	
	children_per_heir[parent_id].append(child)
	child_born.emit(parent, child)


## Get all children of an heir
func get_children(heir: Heir) -> Array[Heir]:
	var heir_id = heir.to_string()
	if heir_id in children_per_heir:
		return children_per_heir[heir_id]
	return []


## Choose which child becomes the next heir (affects inheritance)
func choose_heir(heir: Heir, chosen_child: Heir) -> bool:
	var children = get_children(heir)
	if chosen_child not in children:
		return false
	
	var heir_id = heir.to_string()
	inheritance_history[heir_id] = chosen_child.to_string()
	
	# Apply inheritance bonuses/penalties
	_apply_inheritance_effects(heir, chosen_child, children)
	
	heir_chosen.emit(chosen_child, children)
	return true


## Internal: Apply effects of inheritance choice
func _apply_inheritance_effects(heir: Heir, chosen: Heir, siblings: Array[Heir]) -> void:
	# Chosen child receives stat bonuses
	for stat in chosen.stats:
		chosen.stats[stat] = int(chosen.stats[stat] * 1.15)
	
	# Siblings receive reduced inheritance
	for sibling in siblings:
		if sibling != chosen:
			# Stat reduction for non-chosen heirs
			for stat in sibling.stats:
				sibling.stats[stat] = int(sibling.stats[stat] * 0.90)
			
			# Sibling rivalry increases conflict potential
			sibling_conflict.emit(chosen, sibling)


## Calculate family reputation bonus
func get_family_reputation_bonus(heir: Heir) -> float:
	var family_name = heir.name.split()[0]  # Family name is first word
	var reputation = family_reputation.get(family_name, 0)
	
	# Every 100 reputation = +1% stat bonus (max +10%)
	var bonus = mini(reputation / 100.0 * 0.01, 0.10)
	return bonus


## Apply family reputation bonus to heir stats
func apply_family_reputation_to_heir(heir: Heir) -> void:
	var bonus = get_family_reputation_bonus(heir)
	if bonus > 0:
		for stat in heir.stats:
			heir.stats[stat] = int(heir.stats[stat] * (1.0 + bonus))


## Increase family reputation
func increase_family_reputation(heir: Heir, amount: int) -> void:
	var family_name = heir.name.split()[0]
	
	if family_name not in family_reputation:
		family_reputation[family_name] = 0
	
	family_reputation[family_name] += amount
	family_reputation_changed.emit(family_name, family_reputation[family_name])


## Decrease family reputation
func decrease_family_reputation(heir: Heir, amount: int) -> void:
	increase_family_reputation(heir, -amount)


## Get family reputation
func get_family_reputation(heir: Heir) -> int:
	var family_name = heir.name.split()[0]
	return family_reputation.get(family_name, 0)


## Create multiple children from parents
func produce_children(lineage: Lineage, father: Heir, mother: Heir, count: int = 2) -> Array[Heir]:
	var children: Array[Heir] = []
	
	for i in range(count):
		var child = lineage.produce_heir(
			mother,
			father,
			"%s %d" % [father.name, i + 1],
			father.class_id,
			father.job_id
		)
		
		add_child(father, child)
		add_child(mother, child)
		children.append(child)
	
	return children


## Calculate inheritance split (for wealth distribution)
func calculate_inheritance_split(heir: Heir, wealth: int) -> Dictionary:
	var children = get_children(heir)
	if children.is_empty():
		return {}
	
	var split: Dictionary = {}
	
	# Chosen heir gets 50%, others split remaining 50%
	var heir_id = heir.to_string()
	var chosen_id = inheritance_history.get(heir_id, "")
	
	var base_share = wealth / 2  # 50% to chosen heir
	var remaining_share = wealth / 2
	var per_sibling = remaining_share / (children.size() - 1) if children.size() > 1 else 0
	
	for child in children:
		var child_id = child.to_string()
		if child_id == chosen_id:
			split[child_id] = base_share
		else:
			split[child_id] = per_sibling
	
	return split


## Get family stats summary
func get_family_summary(heir: Heir) -> Dictionary:
	var children = get_children(heir)
	var family_rep = get_family_reputation(heir)
	
	return {
		"patriarch": heir.name,
		"spouse": heir.spouse.name if heir.spouse else "None",
		"child_count": children.size(),
		"children": [child.name for child in children],
		"family_reputation": family_rep,
		"family_bonus": "%.1f%%" % (get_family_reputation_bonus(heir) * 100.0)
	}


## Check if heir has children
func has_children(heir: Heir) -> bool:
	return get_children(heir).size() > 0


## Get child count
func get_child_count(heir: Heir) -> int:
	return get_children(heir).size()


## Resolve sibling rivalry (affects stat growth)
func resolve_sibling_conflict(winner: Heir, loser: Heir) -> void:
	# Winner gains reputation, loser loses reputation
	var family_name = winner.name.split()[0]
	increase_family_reputation(winner, 25)
	decrease_family_reputation(loser, 10)
