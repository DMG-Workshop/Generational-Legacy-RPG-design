## Turn-based battle logic. No rendering: the UI reads `enemies`, `events` and `log`.
class_name GameBattle
extends RefCounted

var heir: GameHeir
var enemies: Array = []        # [{id,name,hp,max_hp,atk,def,agi,color,element,xp,gold,boss}]
var rng: RandomNumberGenerator
var damage_bonus: float = 0.0  # from legacy echoes
var slayer_bonus: Dictionary = {}  # creature id -> extra damage fraction
var weather: Dictionary = {}       # combat modifiers from the weather: dodge, crit, flee, mp_regen
var allies: Array = []             # companions fighting beside the heir (see GameParty)
var result: String = ""        # "", "victory", "defeat", "fled"
var defending: bool = false
var turn: int = 0
var log: Array = []
var events: Array = []         # UI hints from the most recent action


func _init(p_heir: GameHeir, p_enemies: Array, p_rng: RandomNumberGenerator) -> void:
	heir = p_heir
	enemies = p_enemies
	rng = p_rng


func living_enemies() -> Array:
	var out: Array = []
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			out.append(i)
	return out


func first_target() -> int:
	var l := living_enemies()
	return l[0] if l.size() > 0 else -1


func is_over() -> bool:
	return result != ""


func _begin_action() -> bool:
	events = []
	return result == ""


func _say(text: String) -> void:
	log.append(text)


func _calc_damage(power: float, mult: float, e: Dictionary, pierce: float, crit_bonus: float) -> Dictionary:
	var dmg: float = maxf(1.0, power * mult - float(e["def"]) * (1.0 - pierce) * 0.5)
	dmg *= rng.randf_range(0.9, 1.1)
	dmg *= 1.0 + damage_bonus + float(slayer_bonus.get(e["id"], 0.0))
	var crit := rng.randf() < heir.crit_chance() + crit_bonus + float(weather.get("crit", 0.0))
	if crit:
		dmg *= 1.75
	return {"amount": maxi(1, int(round(dmg))), "crit": crit}


func _hit_enemy(idx: int, power: float, mult: float, pierce: float, crit_bonus: float) -> int:
	var e: Dictionary = enemies[idx]
	var r := _calc_damage(power, mult, e, pierce, crit_bonus)
	var amount: int = r["amount"]
	e["hp"] = maxi(0, e["hp"] - amount)
	events.append({"type": "damage", "side": "enemy", "index": idx, "amount": amount, "crit": r["crit"]})
	_say("%s hits %s for %d%s." % [heir.name, e["name"], amount, " (CRIT!)" if r["crit"] else ""])
	if e["hp"] == 0:
		events.append({"type": "death", "side": "enemy", "index": idx})
		_say("%s is defeated." % e["name"])
	return amount


func attack(target: int) -> void:
	if not _begin_action():
		return
	target = _valid_target(target)
	_hit_enemy(target, heir.attack_power(), 1.0, 0.0, 0.0)
	_end_player_turn()


func skill_count() -> int:
	return (heir.cls()["skills"] as Array).size()


func skill_info(i: int) -> Dictionary:
	return heir.cls()["skills"][i]


## Skill costs grow with level, so max MP growth buys stronger casts rather than endless heals.
func skill_cost(i: int) -> int:
	var growth := float(GameData.bal("skill_cost_growth_per_level"))
	return int(round(float(skill_info(i)["mp"]) * (1.0 + growth * float(heir.level - 1))))


func can_use_skill(i: int) -> bool:
	return result == "" and heir.mp >= skill_cost(i)


func use_skill(i: int, target: int) -> void:
	if not _begin_action() or not can_use_skill(i):
		return
	var s := skill_info(i)
	heir.mp -= skill_cost(i)
	if s["type"] == "heal":
		var amt := int(round(float(heir.max_hp()) * float(s["pct_max_hp"]) * (1.0 + heir.trait_total("healing_power"))))
		_heal_player(amt, s["name"])
	else:
		target = _valid_target(target)
		var power: float
		match str(s.get("stat", "str")):
			"mag":
				power = heir.magic_power()
			"both":  # hybrid classes draw on body and spell alike
				power = (heir.attack_power() + heir.magic_power()) * 0.6
			_:
				power = heir.attack_power()
		var hits: int = int(s.get("hits", 1))
		var dealt := 0
		for h in hits:
			if enemies[target]["hp"] <= 0:
				target = first_target()
				if target < 0:
					break
			dealt += _hit_enemy(target, power, float(s["mult"]), float(s.get("pierce", 0.0)), float(s.get("crit_bonus", 0.0)))
		var drain := float(s.get("drain", 0.0))
		if drain > 0.0 and dealt > 0:
			_heal_player(int(round(float(dealt) * drain)), s["name"])
	_end_player_turn()


func defend() -> void:
	if not _begin_action():
		return
	defending = true
	heir.mp = mini(heir.max_mp(), heir.mp + int(ceil(float(heir.max_mp()) * 0.15)))
	events.append({"type": "defend"})
	_say("%s braces for impact." % heir.name)
	_end_player_turn()


func use_potion() -> void:
	if not _begin_action() or heir.potions <= 0:
		return
	heir.potions -= 1
	var amt := int(round(float(heir.max_hp()) * float(GameData.bal("potion_heal_pct")) * (1.0 + heir.trait_total("healing_power"))))
	_heal_player(amt, "Potion")
	_end_player_turn()


func flee() -> void:
	if not _begin_action():
		return
	var chance := clampf(0.45 + heir.trait_total("stealth") + heir.trait_total("intimidation") * 0.5 + heir.dodge_chance() * 0.3 + float(weather.get("flee", 0.0)), 0.1, 0.9)
	var boss := false
	for e in enemies:
		boss = boss or e.get("boss", false)
	if boss:
		chance *= 0.4
	if rng.randf() < chance:
		result = "fled"
		events.append({"type": "flee"})
		_say("%s escapes!" % heir.name)
		return
	_say("%s fails to escape!" % heir.name)
	_end_player_turn()


func _heal_player(amount: int, source: String) -> void:
	var before := heir.hp
	heir.hp = mini(heir.max_hp(), heir.hp + amount)
	events.append({"type": "heal", "side": "player", "amount": heir.hp - before})
	_say("%s restores %d HP (%s)." % [heir.name, heir.hp - before, source])


func _valid_target(t: int) -> int:
	if t >= 0 and t < enemies.size() and enemies[t]["hp"] > 0:
		return t
	return first_target()


func _end_player_turn() -> void:
	if living_enemies().is_empty():
		result = "victory"
		_say("Victory!")
		return
	for i in living_enemies():
		_enemy_act(i)
		if heir.hp <= 0:
			result = "defeat"
			_say("%s has fallen..." % heir.name)
			return
	defending = false
	turn += 1
	var regen := maxf(0.0, float(GameData.bal("mp_regen_per_turn_pct")) + float(weather.get("mp_regen", 0.0)))
	heir.mp = mini(heir.max_mp(), heir.mp + int(ceil(float(heir.max_mp()) * regen)))


func _enemy_act(i: int) -> void:
	var e: Dictionary = enemies[i]
	if rng.randf() < clampf(heir.dodge_chance() + float(weather.get("dodge", 0.0)), 0.0, 0.6):
		events.append({"type": "miss", "side": "player", "index": i})
		_say("%s attacks, but %s dodges." % [e["name"], heir.name])
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - heir.defense() * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(heir.trait_total("fire_resistance"), 0.0, 0.8)
	if defending:
		dmg *= 0.5
	var amount := maxi(1, int(round(dmg)))
	heir.hp = maxi(0, heir.hp - amount)
	events.append({"type": "damage", "side": "player", "index": i, "amount": amount, "crit": false})
	_say("%s hits %s for %d." % [e["name"], heir.name, amount])
