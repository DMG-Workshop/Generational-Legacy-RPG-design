## Unit tests for the layered combat system

extends GutTest


var battle: Battle


func before_each() -> void:
	battle = Battle.new()


## Test: Create combatants
func test_create_combatants() -> void:
	var warrior = Battle.Combatant.new()
	warrior.name = "Theron"
	warrior.class_id = "warrior"
	warrior.job_id = "guard"
	warrior.max_hp = 150
	warrior.hp = 150
	warrior.max_mp = 50
	warrior.mp = 50

	assert_eq(warrior.name, "Theron")
	assert_eq(warrior.class_id, "warrior")
	assert_true(warrior.is_alive)
	assert_eq(warrior.hp, 150)


## Test: Basic attack damage calculation
func test_attack_damage() -> void:
	var attacker = Battle.Combatant.new()
	attacker.name = "Attacker"
	attacker.class_id = "warrior"
	attacker.stats["strength"] = 15
	attacker.row = "front"

	var defender = Battle.Combatant.new()
	defender.name = "Defender"
	defender.stats["constitution"] = 10
	defender.row = "front"
	defender.hp = 100

	var damage = battle._calculate_damage(attacker, defender)
	assert_gt(damage, 0)
	assert_true(damage < 100)  # Reasonable damage value


## Test: Back row defense bonus
func test_back_row_reduces_damage() -> void:
	var attacker = Battle.Combatant.new()
	attacker.stats["strength"] = 15

	var front_defender = Battle.Combatant.new()
	front_defender.stats["constitution"] = 10
	front_defender.row = "front"

	var back_defender = Battle.Combatant.new()
	back_defender.stats["constitution"] = 10
	back_defender.row = "back"

	var front_damage = battle._calculate_damage(attacker, front_defender)
	var back_damage = battle._calculate_damage(attacker, back_defender)

	assert_gt(front_damage, back_damage)


## Test: Trait modifiers increase damage
func test_trait_modifiers_in_damage() -> void:
	var attacker = Battle.Combatant.new()
	attacker.stats["strength"] = 15
	attacker.traits = []

	var defender = Battle.Combatant.new()
	defender.stats["constitution"] = 10

	var base_damage = battle._calculate_damage(attacker, defender)

	# Add Warriors Steel trait
	attacker.traits.append("warriors_steel")
	var boosted_damage = battle._calculate_damage(attacker, defender)

	assert_gt(boosted_damage, base_damage)


## Test: Battle initialization
func test_start_battle() -> void:
	var party: Array[Battle.Combatant] = []
	var enemies: Array[Battle.Combatant] = []

	for i in range(3):
		var hero = Battle.Combatant.new()
		hero.name = "Hero%d" % i
		hero.hp = 100
		hero.faction = "party"
		party.append(hero)

	for i in range(2):
		var enemy = Battle.Combatant.new()
		enemy.name = "Enemy%d" % i
		enemy.hp = 50
		enemy.faction = "enemy"
		enemies.append(enemy)

	battle.start_battle(party, enemies)

	assert_eq(battle.state.party.size(), 3)
	assert_eq(battle.state.enemies.size(), 2)
	assert_false(battle.state.battle_over)


## Test: Turn order calculation
func test_turn_order_by_dexterity() -> void:
	var slow_char = Battle.Combatant.new()
	slow_char.name = "Slow"
	slow_char.stats["dexterity"] = 5

	var fast_char = Battle.Combatant.new()
	fast_char.name = "Fast"
	fast_char.stats["dexterity"] = 20

	var medium_char = Battle.Combatant.new()
	medium_char.name = "Medium"
	medium_char.stats["dexterity"] = 12

	var party = [slow_char, fast_char, medium_char]
	var enemies: Array[Battle.Combatant] = []

	battle.start_battle(party, enemies)

	# Fast char should be first
	assert_eq(battle.state.turn_order[0].name, "Fast")
	# Medium should be middle
	assert_eq(battle.state.turn_order[1].name, "Medium")
	# Slow should be last
	assert_eq(battle.state.turn_order[2].name, "Slow")


## Test: Execute attack action
func test_execute_attack_action() -> void:
	var attacker = Battle.Combatant.new()
	attacker.name = "Attacker"
	attacker.hp = 100
	attacker.is_alive = true

	var defender = Battle.Combatant.new()
	defender.name = "Defender"
	defender.hp = 100
	defender.is_alive = true

	var result = battle.execute_turn(attacker, "attack", defender)

	assert_eq(result["action"], "attack")
	assert_eq(result["actor"], attacker)
	assert_eq(result["target"], defender)
	assert_gt(result["damage"], 0)
	assert_lt(defender.hp, 100)  # Defender took damage


## Test: Dead combatant can't act
func test_dead_combatant_cannot_act() -> void:
	var dead_char = Battle.Combatant.new()
	dead_char.hp = 0
	dead_char.is_alive = false

	var target = Battle.Combatant.new()

	var result = battle.execute_turn(dead_char, "attack", target)

	assert_false(result["success"])


## Test: Stance changes defense
func test_stance_changes_buffs() -> void:
	var warrior = Battle.Combatant.new()
	warrior.class_id = "warrior"
	warrior.buffs = {}

	battle.execute_turn(warrior, "stance", "defensive")

	assert_true(warrior.buffs.has("defense"))
	assert_gt(warrior.buffs["defense"], 1.0)


## Test: Valid actions based on resources
func test_valid_actions_limited_by_mp() -> void:
	var mage = Battle.Combatant.new()
	mage.class_id = "mage"
	mage.mp = 0  # No mana

	var actions = battle.get_valid_actions(mage)

	# Should have attack and defend but not cast_spell
	assert_true("attack" in actions)
	assert_true("defend" in actions)
	assert_false("cast_spell" in actions)


## Test: Rage meter fills (Martial class mechanic)
func test_rage_meter_buildup() -> void:
	var warrior = Battle.Combatant.new()
	warrior.class_id = "berserker"
	warrior.rage_meter = 0.0

	battle._update_class_mechanics(warrior, "take_damage")

	assert_gt(warrior.rage_meter, 0.0)


## Test: Battle ends when all enemies die
func test_battle_ends_when_enemies_defeated() -> void:
	var hero = Battle.Combatant.new()
	hero.hp = 100
	hero.is_alive = true

	var enemy = Battle.Combatant.new()
	enemy.hp = 1
	enemy.is_alive = true

	var party = [hero]
	var enemies = [enemy]

	battle.start_battle(party, enemies)

	# Defeat the enemy
	battle.execute_turn(hero, "attack", enemy)

	assert_true(battle.state.battle_over)
	assert_true(battle.state.player_won)


## Test: Simulate full battle round
func test_simulate_full_round() -> void:
	var party = [Battle.Combatant.new(), Battle.Combatant.new()]
	for hero in party:
		hero.hp = 100
		hero.is_alive = true
		hero.faction = "party"

	var enemies = [Battle.Combatant.new()]
	for enemy in enemies:
		enemy.hp = 50
		enemy.is_alive = true
		enemy.faction = "enemy"

	battle.start_battle(party, enemies)
	var results = battle.simulate_round()

	assert_gt(results.size(), 0)
