## Spouse System: Marriage and partner progression
##
## Handles spouse acquisition, marriage mechanics, compatibility,
## and spouse stat/skill progression alongside heir

class_name SpouseSystem


signal spouse_acquired(heir: Heir, spouse: Heir)
signal marriage_occurred(heir: Heir, spouse: Heir)
signal spouse_leveled_up(spouse: Heir, skill: String)
signal divorce_initiated(heir: Heir, spouse: Heir)


# Spouse compatibility factors
var compatibility_modifiers: Dictionary = {
	"class_match": 0.10,      # +10% if same class
	"job_match": 0.15,        # +15% if same job
	"trait_alignment": 0.20,  # +20% if 2+ shared traits
	"reputation_diff": -0.10, # -10% per 50 point reputation diff
	"age_difference": -0.05   # -5% per 10 year age gap
}

# Available spouse pool (would be generated or loaded)
var spouse_pool: Array[Heir] = []


func _init() -> void:
	_initialize_spouse_pool()


## Initialize default spouse pool (placeholder)
func _initialize_spouse_pool() -> void:
	# In full implementation, would load from NPC catalog
	# For now, create procedural spouses
	for i in range(10):
		var spouse = Heir.new()
		spouse.name = "Companion %d" % (i + 1)
		spouse.class_id = ["warrior", "mage", "rogue"][i % 3]
		spouse.job_id = ["fighter", "wizard", "thief"][i % 3]
		spouse.generation = -1  # Mark as NPC
		spouse.traits = []
		spouse_pool.append(spouse)


## Calculate marriage compatibility between heir and potential spouse
func calculate_compatibility(heir: Heir, spouse: Heir) -> float:
	var base_compatibility = 0.5  # 50% base chance
	
	# Class matching bonus
	if heir.class_id == spouse.class_id:
		base_compatibility += compatibility_modifiers["class_match"]
	
	# Job matching bonus
	if heir.job_id == spouse.job_id:
		base_compatibility += compatibility_modifiers["job_match"]
	
	# Trait alignment bonus
	var shared_traits = 0
	for trait in heir.traits:
		if trait in spouse.traits:
			shared_traits += 1
	if shared_traits >= 2:
		base_compatibility += compatibility_modifiers["trait_alignment"]
	
	# Reputation difference penalty
	var heir_rep = heir.faction_reputation.get("party", 0)
	var spouse_rep = spouse.faction_reputation.get("party", 0)
	var rep_diff = abs(heir_rep - spouse_rep)
	if rep_diff > 50:
		base_compatibility += compatibility_modifiers["reputation_diff"]
	
	return clamp(base_compatibility, 0.0, 1.0)


## Propose marriage to a specific spouse
func propose_marriage(heir: Heir, spouse: Heir) -> bool:
	if not heir or not spouse or heir.spouse:
		return false
	
	var compatibility = calculate_compatibility(heir, spouse)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Success if compatibility roll passes
	if rng.randf() < compatibility:
		_marry(heir, spouse)
		return true
	
	return false


## Get available spouse options with compatibility scores
func get_spouse_options(heir: Heir, count: int = 5) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	
	for spouse in spouse_pool:
		if spouse.spouse == null:  # Only available spouses
			var compat = calculate_compatibility(heir, spouse)
			options.append({
				"spouse": spouse,
				"compatibility": compat,
				"name": spouse.name,
				"class": spouse.class_id,
				"job": spouse.job_id
			})
	
	# Sort by compatibility (highest first)
	options.sort_custom(func(a, b): return a["compatibility"] > b["compatibility"])
	
	# Return top count options
	return options.slice(0, mini(count, options.size()))


## Internal: Marry two characters
func _marry(heir: Heir, spouse: Heir) -> void:
	heir.spouse = spouse
	spouse.spouse = heir
	
	marriage_occurred.emit(heir, spouse)
	
	# Apply marriage bonuses
	_apply_marriage_bonuses(heir, spouse)


## Internal: Apply stat bonuses from marriage
func _apply_marriage_bonuses(heir: Heir, spouse: Heir) -> void:
	# Charisma bonus from marriage
	heir.stats["charisma"] = int(heir.stats["charisma"] * 1.10)
	spouse.stats["charisma"] = int(spouse.stats["charisma"] * 1.10)
	
	# Shared trait inheritance (spouse can pass traits to children)
	for trait in spouse.traits:
		if trait not in heir.traits:
			# Spouse's traits have 30% chance to be inherited by children
			pass


## Apply battle rewards to spouse as well
func apply_spouse_rewards(heir: Heir, rewards: Dictionary) -> void:
	if not heir or not heir.spouse:
		return
	
	var spouse = heir.spouse
	
	# Spouse gains 60% of heir's XP rewards
	var spouse_xp_multiplier = 0.6
	var spouse_crafting_xp = {}
	
	var crafting_xp = rewards.get("crafting_xp", {})
	for skill in crafting_xp:
		spouse_crafting_xp[skill] = int(crafting_xp[skill] * spouse_xp_multiplier)
	
	if spouse_crafting_xp.size() > 0:
		_apply_spouse_skill_progression(spouse, spouse_crafting_xp)


## Internal: Apply skill progression to spouse
func _apply_spouse_skill_progression(spouse: Heir, crafting_xp: Dictionary) -> void:
	for skill_name in crafting_xp:
		var xp_gained = crafting_xp[skill_name]
		
		if skill_name not in spouse.crafting_skills:
			var skill = CraftingSkill.new()
			skill.skill_type = skill_name
			skill.xp = 0
			skill.level = 1
			spouse.crafting_skills[skill_name] = skill
		
		var skill = spouse.crafting_skills[skill_name]
		var old_level = skill.level
		
		skill.xp += xp_gained
		
		while skill.xp >= 100:
			skill.xp -= 100
			skill.level += 1
			if skill.level > old_level:
				spouse_leveled_up.emit(spouse, skill_name)


## Initiate divorce (reduces family reputation)
func initiate_divorce(heir: Heir) -> bool:
	if not heir or not heir.spouse:
		return false
	
	var spouse = heir.spouse
	heir.spouse = null
	spouse.spouse = null
	
	# Reputation penalty
	heir.faction_reputation["party"] = heir.faction_reputation.get("party", 0) - 50
	
	divorce_initiated.emit(heir, spouse)
	return true


## Get spouse stats summary
func get_spouse_summary(heir: Heir) -> Dictionary:
	if not heir or not heir.spouse:
		return {}
	
	var spouse = heir.spouse
	return {
		"name": spouse.name,
		"class": spouse.class_id,
		"job": spouse.job_id,
		"stats": spouse.stats.duplicate(),
		"skills": spouse.crafting_skills.keys(),
		"traits": spouse.traits.duplicate()
	}


## Check if characters can marry (both available)
func can_marry(heir: Heir, spouse: Heir) -> bool:
	return heir and spouse and heir.spouse == null and spouse.spouse == null
