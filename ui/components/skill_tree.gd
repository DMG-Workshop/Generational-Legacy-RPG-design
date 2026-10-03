## Skill tree visualization component
##
## Displays learnable skills in a tree structure with progression nodes

extends Control

class_name SkillTree


## Skill node in the tree
class SkillNode:
	var name: String
	var description: String
	var level: int = 0  # 0 = locked, 1-3 = unlocked levels
	var max_level: int = 3
	var prerequisites: Array[String] = []
	var position: Vector2
	var learned: bool = false


var heir: Heir
var skills: Dictionary = {}  # skill_name -> SkillNode
var selected_skill: String = ""


func _init(current_heir: Heir) -> void:
	heir = current_heir
	_initialize_skills()


func _initialize_skills() -> void:
	# Initialize skill tree based on heir's class and traits
	match heir.class_id:
		"warrior":
			_add_warrior_skills()
		"mage":
			_add_mage_skills()
		"rogue":
			_add_rogue_skills()
		_:
			_add_basic_skills()


func _add_warrior_skills() -> void:
	var slash = SkillNode.new()
	slash.name = "Slash"
	slash.description = "Basic sword attack"
	slash.position = Vector2(100, 100)
	slash.level = 1
	slash.learned = true
	skills["slash"] = slash

	var whirlwind = SkillNode.new()
	whirlwind.name = "Whirlwind"
	whirlwind.description = "Attack all enemies"
	whirlwind.position = Vector2(100, 200)
	whirlwind.prerequisites = ["slash"]
	skills["whirlwind"] = whirlwind

	var shield_bash = SkillNode.new()
	shield_bash.name = "Shield Bash"
	shield_bash.description = "Stun an enemy"
	shield_bash.position = Vector2(250, 200)
	shield_bash.prerequisites = ["slash"]
	skills["shield_bash"] = shield_bash

	var last_stand = SkillNode.new()
	last_stand.name = "Last Stand"
	last_stand.description = "Survive fatal damage once"
	last_stand.position = Vector2(175, 300)
	last_stand.prerequisites = ["whirlwind", "shield_bash"]
	skills["last_stand"] = last_stand


func _add_mage_skills() -> void:
	var fireball = SkillNode.new()
	fireball.name = "Fireball"
	fireball.description = "Fire spell attack"
	fireball.position = Vector2(100, 100)
	fireball.level = 1
	fireball.learned = true
	skills["fireball"] = fireball

	var inferno = SkillNode.new()
	inferno.name = "Inferno"
	inferno.description = "Massive fire damage"
	inferno.position = Vector2(100, 200)
	inferno.prerequisites = ["fireball"]
	skills["inferno"] = inferno

	var frost_nova = SkillNode.new()
	frost_nova.name = "Frost Nova"
	frost_nova.description = "Freeze enemies in place"
	frost_nova.position = Vector2(250, 100)
	skills["frost_nova"] = frost_nova

	var meteor = SkillNode.new()
	meteor.name = "Meteor"
	meteor.description = "Rain meteors from sky"
	meteor.position = Vector2(175, 250)
	meteor.prerequisites = ["inferno", "frost_nova"]
	skills["meteor"] = meteor


func _add_rogue_skills() -> void:
	var backstab = SkillNode.new()
	backstab.name = "Backstab"
	backstab.description = "High damage to single target"
	backstab.position = Vector2(100, 100)
	backstab.level = 1
	backstab.learned = true
	skills["backstab"] = backstab

	var shadow_clone = SkillNode.new()
	shadow_clone.name = "Shadow Clone"
	shadow_clone.description = "Create a decoy"
	shadow_clone.position = Vector2(100, 200)
	shadow_clone.prerequisites = ["backstab"]
	skills["shadow_clone"] = shadow_clone

	var poison_strike = SkillNode.new()
	poison_strike.name = "Poison Strike"
	poison_strike.description = "Damage over time"
	poison_strike.position = Vector2(250, 150)
	skills["poison_strike"] = poison_strike

	var deathmark = SkillNode.new()
	deathmark.name = "Deathmark"
	deathmark.description = "Execute weakened enemies"
	deathmark.position = Vector2(175, 300)
	deathmark.prerequisites = ["shadow_clone", "poison_strike"]
	skills["deathmark"] = deathmark


func _add_basic_skills() -> void:
	var attack = SkillNode.new()
	attack.name = "Attack"
	attack.description = "Basic attack"
	attack.position = Vector2(100, 100)
	attack.level = 1
	attack.learned = true
	skills["attack"] = attack

	var defend = SkillNode.new()
	defend.name = "Defend"
	defend.description = "Reduce damage taken"
	defend.position = Vector2(250, 100)
	skills["defend"] = defend


func _ready() -> void:
	# Draw skill tree
	draw.connect(_on_draw)
	custom_minimum_size = Vector2(400, 400)


func _on_draw() -> void:
	# Draw connections between skills
	for skill_name in skills:
		var skill = skills[skill_name]
		for prereq in skill.prerequisites:
			if skills.has(prereq):
				var prereq_skill = skills[prereq]
				draw_line(prereq_skill.position + Vector2(50, 50), skill.position + Vector2(50, 50), Color.GRAY, 2.0)

	# Draw skill nodes
	for skill_name in skills:
		var skill = skills[skill_name]
		var color = Color.DARK_GREEN if skill.learned else Color.DARK_RED

		if skill_name == selected_skill:
			color = Color.YELLOW

		# Draw node circle
		draw_circle(skill.position + Vector2(50, 50), 30, color)

		# Draw text
		var font = get_theme_font("font")
		if font:
			draw_string(font, skill.position + Vector2(10, 55), skill.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func get_skill_info(skill_name: String) -> Dictionary:
	if skills.has(skill_name):
		var skill = skills[skill_name]
		return {
			"name": skill.name,
			"description": skill.description,
			"level": skill.level,
			"max_level": skill.max_level,
			"learned": skill.learned,
			"prerequisites": skill.prerequisites
		}
	return {}


func learn_skill(skill_name: String) -> bool:
	if not skills.has(skill_name):
		return false

	var skill = skills[skill_name]

	# Check prerequisites
	for prereq in skill.prerequisites:
		if not skills[prereq].learned:
			return false

	skill.learned = true
	skill.level = 1
	queue_redraw()
	return true


func upgrade_skill(skill_name: String) -> bool:
	if not skills.has(skill_name):
		return false

	var skill = skills[skill_name]

	if not skill.learned or skill.level >= skill.max_level:
		return false

	skill.level += 1
	queue_redraw()
	return true
