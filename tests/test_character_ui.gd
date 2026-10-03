## Tests for character UI components (Phase 5 - Character UI)
##
## Tests: skill trees, family tree browser, character sheet display

extends GutTest


var skill_tree: SkillTree
var family_tree: FamilyTreeBrowser
var heir: Heir
var lineage: Lineage
var npc_system: NPCSystem


func before_each() -> void:
	heir = Heir.new()
	heir.name = "Hero"
	heir.class_id = "warrior"
	heir.generation = 5
	heir.traits = ["warrior_steel", "noble_blood"]

	lineage = Lineage.new(42)
	npc_system = NPCSystem.new()

	skill_tree = SkillTree.new(heir)
	family_tree = FamilyTreeBrowser.new(lineage, heir, npc_system)


## Test: Skill tree initializes for warrior
func test_skill_tree_warrior_init() -> void:
	assert_not_null(skill_tree)
	assert_eq(skill_tree.heir.class_id, "warrior")
	assert_true(skill_tree.skills.size() > 0)


## Test: Warrior has slash skill
func test_warrior_has_slash() -> void:
	assert_true(skill_tree.skills.has("slash"))
	var slash = skill_tree.skills["slash"]
	assert_eq(slash.name, "Slash")
	assert_true(slash.learned)


## Test: Skill tree initializes for mage
func test_skill_tree_mage_init() -> void:
	var mage = Heir.new()
	mage.class_id = "mage"
	var mage_tree = SkillTree.new(mage)

	assert_true(mage_tree.skills.has("fireball"))


## Test: Learn skill from prerequisites
func test_learn_skill_with_prerequisites() -> void:
	# Whirlwind requires slash
	assert_false(skill_tree.skills["whirlwind"].learned)

	# Should fail without slash learned (though slash is learned by default)
	var result = skill_tree.learn_skill("whirlwind")

	assert_true(result)
	assert_true(skill_tree.skills["whirlwind"].learned)


## Test: Cannot learn skill without prerequisites
func test_cannot_learn_skill_without_prerequisites() -> void:
	# Last stand requires both whirlwind and shield_bash
	assert_false(skill_tree.skills["last_stand"].learned)

	# Try to learn without prerequisites
	var result = skill_tree.learn_skill("last_stand")

	assert_false(result)
	assert_false(skill_tree.skills["last_stand"].learned)


## Test: Upgrade skill level
func test_upgrade_skill() -> void:
	var slash = skill_tree.skills["slash"]
	var initial_level = slash.level

	var result = skill_tree.upgrade_skill("slash")

	assert_true(result)
	assert_eq(slash.level, initial_level + 1)


## Test: Cannot upgrade unlearned skill
func test_cannot_upgrade_unlearned_skill() -> void:
	var meteor = skill_tree.skills.get("meteor")
	if meteor:
		var result = skill_tree.upgrade_skill("meteor")
		assert_false(result)


## Test: Family tree browser initializes
func test_family_tree_browser_init() -> void:
	assert_not_null(family_tree)
	assert_eq(family_tree.current_heir, heir)


## Test: Get skill info
func test_get_skill_info() -> void:
	var info = skill_tree.get_skill_info("slash")

	assert_true(info.has("name"))
	assert_true(info.has("description"))
	assert_true(info.has("level"))
	assert_eq(info["name"], "Slash")
	assert_true(info["learned"])


## Test: Skill tree for different classes
func test_skill_trees_for_different_classes() -> void:
	var warrior = Heir.new()
	warrior.class_id = "warrior"
	var warrior_tree = SkillTree.new(warrior)

	var mage = Heir.new()
	mage.class_id = "mage"
	var mage_tree = SkillTree.new(mage)

	var rogue = Heir.new()
	rogue.class_id = "rogue"
	var rogue_tree = SkillTree.new(rogue)

	assert_true(warrior_tree.skills.has("slash"))
	assert_true(mage_tree.skills.has("fireball"))
	assert_true(rogue_tree.skills.has("backstab"))


## Test: Skill prerequisites are tracked
func test_skill_prerequisites() -> void:
	var whirlwind = skill_tree.skills["whirlwind"]

	assert_true("slash" in whirlwind.prerequisites)


## Test: Get ancestry line
func test_get_ancestry_line() -> void:
	var founder = lineage.create_founder("Founder", "warrior", "merchant")

	var line = family_tree.get_ancestry_line(founder.generation)

	assert_true(line.size() > 0)
	assert_eq(line[0].name, "Founder")


## Test: NPC ancestor in family tree
func test_npc_ancestor_in_family() -> void:
	var ancestor = Heir.new()
	ancestor.name = "Ancient One"
	ancestor.generation = 0

	var npc = npc_system.add_npc_ancestor(ancestor, 0)

	assert_not_null(npc)
	assert_eq(npc.heir.name, "Ancient One")
