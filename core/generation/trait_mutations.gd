## Trait Mutations: Dormant traits, mutations, and inheritance chains
##
## Manages trait expression, dormancy, mutations, and how traits
## compound and evolve across generations

class_name TraitMutations


signal trait_activated(heir: Heir, trait_id: String)
signal trait_mutated(heir: Heir, original_trait: String, new_trait: String)
signal dormant_trait_awakened(heir: Heir, trait_id: String)


var trait_catalog: Dictionary = {}
var dormant_traits: Dictionary = {}  # heir_id -> Array[String]
var mutation_chains: Dictionary = {}  # trait_id -> Array[mutation_ids]


func _init() -> void:
	trait_catalog = TraitLoader.load_all_traits()
	_initialize_mutation_chains()


## Initialize trait mutation chains
func _initialize_mutation_chains() -> void:
	# Build mutation chains from trait definitions
	for trait_id in trait_catalog:
		var trait_def = trait_catalog[trait_id]
		var mutations = trait_def.get("mutations", [])
		if mutations.size() > 0:
			mutation_chains[trait_id] = mutations


## Add dormant trait to heir
func add_dormant_trait(heir: Heir, trait_id: String) -> void:
	if not heir:
		return
	
	var heir_id = heir.to_string()
	if heir_id not in dormant_traits:
		dormant_traits[heir_id] = []
	
	if trait_id not in dormant_traits[heir_id]:
		dormant_traits[heir_id].append(trait_id)


## Get dormant traits for heir
func get_dormant_traits(heir: Heir) -> Array[String]:
	var heir_id = heir.to_string()
	if heir_id in dormant_traits:
		return dormant_traits[heir_id]
	return []


## Check for dormant trait activation based on stat threshold
func check_dormant_activation(heir: Heir) -> void:
	var dormant = get_dormant_traits(heir)
	
	for trait_id in dormant:
		if not trait_catalog.has(trait_id):
			continue
		
		var trait_def = trait_catalog[trait_id]
		var activation_stat = trait_def.get("activation_stat", "")
		var activation_threshold = trait_def.get("activation_threshold", 15)
		
		# Check if heir's stat exceeds threshold
		if activation_stat in heir.stats:
			if heir.stats[activation_stat] >= activation_threshold:
				activate_dormant_trait(heir, trait_id)


## Activate a dormant trait
func activate_dormant_trait(heir: Heir, trait_id: String) -> void:
	if not heir:
		return
	
	var heir_id = heir.to_string()
	if heir_id not in dormant_traits or trait_id not in dormant_traits[heir_id]:
		return
	
	# Move from dormant to active
	dormant_traits[heir_id].erase(trait_id)
	heir.add_trait(trait_id)
	
	trait_activated.emit(heir, trait_id)
	
	# Check for mutation chain
	_trigger_mutation_chain(heir, trait_id)


## Internal: Trigger mutation chain when trait activates
func _trigger_mutation_chain(heir: Heir, trait_id: String) -> void:
	if trait_id not in mutation_chains:
		return
	
	var mutations = mutation_chains[trait_id]
	if mutations.is_empty():
		return
	
	# 30% chance per activation to mutate to next in chain
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if rng.randf() < 0.30:
		var mutated_trait = mutations[rng.randi() % mutations.size()]
		_mutate_trait(heir, trait_id, mutated_trait)


## Mutate a trait into a different one
func _mutate_trait(heir: Heir, original_trait: String, new_trait: String) -> void:
	if not heir:
		return
	
	# Remove original, add mutated
	heir.remove_trait(original_trait)
	heir.add_trait(new_trait)
	
	trait_mutated.emit(heir, original_trait, new_trait)


## Inherit dormant traits from parent
func inherit_dormant_traits(heir: Heir, parent: Heir) -> void:
	if not heir or not parent:
		return
	
	var parent_dormant = get_dormant_traits(parent)
	
	for trait_id in parent_dormant:
		# 50% chance to inherit dormant trait
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		
		if rng.randf() < 0.50:
			add_dormant_trait(heir, trait_id)


## Get trait expression level (how strong the trait is)
func get_trait_expression_level(heir: Heir, trait_id: String) -> float:
	if trait_id not in heir.traits:
		return 0.0
	
	# Base expression is 1.0
	var expression = 1.0
	
	# Bonus for matching stat
	if trait_catalog.has(trait_id):
		var trait_def = trait_catalog[trait_id]
		var stat_bonus = trait_def.get("stat_bonus", "")
		
		if stat_bonus in heir.stats:
			# +0.1 expression per 5 points in bonus stat
			var bonus_amount = heir.stats[stat_bonus] / 5.0
			expression += mini(bonus_amount * 0.1, 0.5)
	
	return expression


## Check for trait conflicts (traits that shouldn't coexist)
func get_conflicting_traits(heir: Heir) -> Array[Array]:
	var conflicts: Array[Array] = []
	
	# Define trait conflicts
	var conflict_pairs = [
		["blessing_courage", "curse_cowardice"],
		["blessing_strength", "curse_weakness"],
		["blessing_health", "curse_plague"]
	]
	
	for pair in conflict_pairs:
		var trait1_active = pair[0] in heir.traits
		var trait2_active = pair[1] in heir.traits
		
		if trait1_active and trait2_active:
			conflicts.append(pair)
	
	return conflicts


## Resolve trait conflicts (one cancels the other)
func resolve_trait_conflict(heir: Heir, conflict_pair: Array) -> void:
	if not heir or conflict_pair.size() != 2:
		return
	
	var trait1 = conflict_pair[0]
	var trait2 = conflict_pair[1]
	
	# Blessing beats curse (blessing stays, curse removed)
	if trait1.begins_with("blessing") and trait2.begins_with("curse"):
		heir.remove_trait(trait2)
	elif trait2.begins_with("blessing") and trait1.begins_with("curse"):
		heir.remove_trait(trait1)


## Get trait bonus to specific stat
func get_trait_stat_bonus(heir: Heir, stat_name: String) -> int:
	var total_bonus = 0
	
	for trait_id in heir.traits:
		if not trait_catalog.has(trait_id):
			continue
		
		var trait_def = trait_catalog[trait_id]
		var stat_bonuses = trait_def.get("stat_bonuses", {})
		
		if stat_name in stat_bonuses:
			var bonus = stat_bonuses[stat_name]
			var expression = get_trait_expression_level(heir, trait_id)
			total_bonus += int(bonus * expression)
	
	return total_bonus


## Trigger random mutation event (rare)
func trigger_random_mutation(heir: Heir, rng: RandomNumberGenerator) -> void:
	if heir.traits.is_empty():
		return
	
	# 5% chance per check
	if rng.randf() > 0.05:
		return
	
	var random_trait = heir.traits[rng.randi() % heir.traits.size()]
	
	if random_trait not in mutation_chains:
		return
	
	var mutations = mutation_chains[random_trait]
	var mutated = mutations[rng.randi() % mutations.size()]
	
	_mutate_trait(heir, random_trait, mutated)


## Get trait family (related traits)
func get_trait_family(trait_id: String) -> Array[String]:
	var family = [trait_id]
	
	# Add mutations
	if trait_id in mutation_chains:
		family.append_array(mutation_chains[trait_id])
	
	# Add to other families if found
	for other_trait in mutation_chains:
		if trait_id in mutation_chains[other_trait]:
			family.append(other_trait)
	
	return family
