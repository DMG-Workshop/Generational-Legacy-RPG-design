## Turn-based battle logic. No rendering: the UI reads `enemies`, `allies`, `events` and `log`.
## Event "by" is the acting ally's index (-1 for the heir); side "ally" events carry "ally".
class_name GameBattle
extends RefCounted

var heir: GameHeir
var enemies: Array = []        # [{id,name,hp,max_hp,atk,def,agi,color,element,xp,gold,boss}]
var rng: RandomNumberGenerator
var damage_bonus: float = 0.0  # from legacy echoes
var slayer_bonus: Dictionary = {}  # creature id -> extra damage fraction
var weather: Dictionary = {}       # combat modifiers from the weather: dodge, crit, flee, mp_regen
var allies: Array = []             # Array[GameHeir]: companions fighting beside the heir (see GameParty)
var foe_hp_mult: float = 1.0       # extra toughness foes have for the companions still standing
var result: String = ""        # "", "victory", "defeat", "fled"
var defending: bool = false
var turn: int = 0
var focus: int = -1            # the enemy the heir last struck; allies press the same target
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


## Companions join before the first blow. Foes facing a band take more bringing down, so allies
## make a fight safer more than shorter. Their blows are not scaled: a party must never turn a
## fair fight into one where the heir falls before they can act.
func add_allies(units: Array) -> void:
	allies = units
	_scale_foes_to_party()


## Foes are tougher by companion_foe_hp for each companion still standing. When one falls, the
## foes lose that share at once (keeping the fraction of HP they had), so a party that is knocked
## out never leaves the heir facing a tougher foe than they would have met alone. Legends are
## never scaled: hirelings barely scratch one, and a band is how a house brings one down.
func _scale_foes_to_party() -> float:
	var mult := 1.0 + float(GameData.bal("companion_foe_hp")) * float(conscious_allies().size())
	var f := mult / foe_hp_mult
	foe_hp_mult = mult
	for e in enemies:
		if e["hp"] > 0 and f != 1.0 and not e.get("boss", false):
			e["max_hp"] = maxi(1, int(round(float(e["max_hp"]) * f)))
			e["hp"] = maxi(1, int(round(float(e["hp"]) * f)))
	return f


## Indices of allies still standing; an ally at 0 HP is out for the rest of the battle.
func conscious_allies() -> Array:
	var out: Array = []
	for i in allies.size():
		if allies[i].hp > 0:
			out.append(i)
	return out


func is_over() -> bool:
	return result != ""


func _begin_action() -> bool:
	events = []
	return result == ""


func _say(text: String) -> void:
	log.append(text)


func _unit(by: int) -> GameHeir:
	return heir if by < 0 else allies[by]


func _calc_damage(power: float, mult: float, e: Dictionary, pierce: float, crit_bonus: float, by: int = -1) -> Dictionary:
	var dmg: float = maxf(1.0, power * mult - float(e["def"]) * (1.0 - pierce) * 0.5)
	dmg *= rng.randf_range(0.9, 1.1)
	if by < 0:  # legacy echoes are the family's, not the hirelings'
		dmg *= 1.0 + damage_bonus + float(slayer_bonus.get(e["id"], 0.0))
	var crit := rng.randf() < _unit(by).crit_chance() + crit_bonus + float(weather.get("crit", 0.0))
	if crit:
		dmg *= 1.75
	return {"amount": maxi(1, int(round(dmg))), "crit": crit}


func _hit_enemy(idx: int, power: float, mult: float, pierce: float, crit_bonus: float, by: int = -1) -> int:
	var e: Dictionary = enemies[idx]
	var r := _calc_damage(power, mult, e, pierce, crit_bonus, by)
	var amount: int = r["amount"]
	var hp_before: int = e["hp"]
	e["hp"] = maxi(0, e["hp"] - amount)
	events.append({"type": "damage", "side": "enemy", "index": idx, "amount": amount, "crit": r["crit"], "by": by})
	_say("%s hits %s for %d%s." % [_unit(by).name, e["name"], amount, " (CRIT!)" if r["crit"] else ""])
	if e["hp"] == 0:
		events.append({"type": "death", "side": "enemy", "index": idx})
		_say("%s is defeated." % e["name"])
	return hp_before - int(e["hp"])


func attack(target: int) -> void:
	if not _begin_action():
		return
	target = _valid_target(target)
	focus = target
	_hit_enemy(target, heir.attack_power(), 1.0, 0.0, 0.0)
	_end_player_turn()


func skill_count() -> int:
	return (heir.cls()["skills"] as Array).size()


func skill_info(i: int) -> Dictionary:
	return heir.cls()["skills"][i]


## Skill costs grow with level, so max MP growth buys stronger casts rather than endless heals.
func skill_cost(i: int) -> int:
	return unit_skill_cost(heir, i)


static func unit_skill_cost(u: GameHeir, i: int) -> int:
	var growth := float(GameData.bal("skill_cost_growth_per_level"))
	return int(round(float(u.cls()["skills"][i]["mp"]) * (1.0 + growth * float(u.level - 1))))


## First skill of a kind ("damage" or "heal") in a unit's class, or -1.
static func unit_skill_of(u: GameHeir, kind: String) -> int:
	var skills: Array = u.cls()["skills"]
	for i in skills.size():
		if skills[i]["type"] == kind:
			return i
	return -1


static func skill_power(u: GameHeir, s: Dictionary) -> float:
	match str(s.get("stat", "str")):
		"mag":
			return u.magic_power()
		"both":  # hybrid classes draw on body and spell alike
			return (u.attack_power() + u.magic_power()) * 0.6
	return u.attack_power()


static func heal_amount(caster: GameHeir, patient: GameHeir, s: Dictionary) -> int:
	return int(round(float(patient.max_hp()) * float(s["pct_max_hp"]) * (1.0 + caster.trait_total("healing_power"))))


func can_use_skill(i: int) -> bool:
	return result == "" and heir.mp >= skill_cost(i)


func use_skill(i: int, target: int) -> void:
	if not _begin_action() or not can_use_skill(i):
		return
	var s := skill_info(i)
	heir.mp -= skill_cost(i)
	if s["type"] == "heal":
		_heal_player(heal_amount(heir, heir, s), s["name"])
	else:
		target = _valid_target(target)
		focus = target
		_strike(-1, s, target)
	_end_player_turn()


## A damage skill: several hits roll over to the next foe, drain heals the user.
func _strike(by: int, s: Dictionary, target: int) -> void:
	var u := _unit(by)
	var power := skill_power(u, s)
	var hits: int = int(s.get("hits", 1))
	var dealt := 0
	for h in hits:
		if enemies[target]["hp"] <= 0:
			target = first_target()
			if target < 0:
				break
		dealt += _hit_enemy(target, power, float(s["mult"]), float(s.get("pierce", 0.0)), float(s.get("crit_bonus", 0.0)), by)
	var drain := float(s.get("drain", 0.0))
	if drain > 0.0 and dealt > 0:
		if by < 0:
			_heal_player(int(round(float(dealt) * drain)), s["name"])
		else:
			_heal_ally(by, int(round(float(dealt) * drain)), s["name"])


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
		_say("%s escapes!" % heir.name if allies.is_empty() else "%s and the party escape!" % heir.name)
		return
	_say("%s fails to escape!" % heir.name)
	_end_player_turn()


func _heal_player(amount: int, source: String, by: int = -1) -> void:
	var before := heir.hp
	heir.hp = mini(heir.max_hp(), heir.hp + amount)
	events.append({"type": "heal", "side": "player", "amount": heir.hp - before, "by": by})
	if by < 0:
		_say("%s restores %d HP (%s)." % [heir.name, heir.hp - before, source])
	else:
		_say("%s tends %s: +%d HP (%s)." % [allies[by].name, heir.name, heir.hp - before, source])


func _heal_ally(ai: int, amount: int, source: String) -> void:
	var a: GameHeir = allies[ai]
	var before := a.hp
	a.hp = mini(a.max_hp(), a.hp + amount)
	events.append({"type": "heal", "side": "ally", "ally": ai, "amount": a.hp - before, "by": ai})
	_say("%s restores %d HP (%s)." % [a.name, a.hp - before, source])


func _valid_target(t: int) -> int:
	if t >= 0 and t < enemies.size() and enemies[t]["hp"] > 0:
		return t
	return first_target()


func _end_player_turn() -> void:
	if living_enemies().is_empty():
		result = "victory"
		_say("Victory!")
		return
	for ai in conscious_allies():
		_ally_act(ai)
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
	for ai in conscious_allies():
		var a: GameHeir = allies[ai]
		a.mp = mini(a.max_mp(), a.mp + int(ceil(float(a.max_mp()) * regen)))


## A companion's turn: mend the heir when they are badly hurt, otherwise fight.
func _ally_act(ai: int) -> void:
	var a: GameHeir = allies[ai]
	var skills: Array = a.cls()["skills"]
	var heal := unit_skill_of(a, "heal")
	var hurt := float(heir.hp) < float(heir.max_hp()) * float(GameData.bal("companion_heal_below"))
	if hurt and heal >= 0 and a.mp >= unit_skill_cost(a, heal):
		a.mp -= unit_skill_cost(a, heal)
		_heal_player(heal_amount(a, heir, skills[heal]), skills[heal]["name"], ai)
		return
	var target := _valid_target(focus)
	var strike := unit_skill_of(a, "damage")
	if strike >= 0 and a.mp >= unit_skill_cost(a, strike):
		a.mp -= unit_skill_cost(a, strike)
		_strike(ai, skills[strike], target)
	else:
		_hit_enemy(target, a.attack_power(), 1.0, 0.0, 0.0, ai)


## Who an enemy goes for: the heir, or (less often) a companion still standing. -1 = the heir.
func _enemy_target() -> int:
	var up := conscious_allies()
	if up.is_empty() or rng.randf() < float(GameData.bal("companion_heir_target_chance")):
		return -1
	return up[rng.randi() % up.size()]


func _enemy_act(i: int) -> void:
	var e: Dictionary = enemies[i]
	var who := _enemy_target()
	if who >= 0:
		_enemy_hit_ally(i, who)
		return
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


func _enemy_hit_ally(i: int, ai: int) -> void:
	var e: Dictionary = enemies[i]
	var a: GameHeir = allies[ai]
	if rng.randf() < clampf(a.dodge_chance() + float(weather.get("dodge", 0.0)), 0.0, 0.6):
		events.append({"type": "miss", "side": "ally", "index": i, "ally": ai})
		_say("%s attacks, but %s dodges." % [e["name"], a.name])
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - a.defense() * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(a.trait_total("fire_resistance"), 0.0, 0.8)
	var amount := maxi(1, int(round(dmg)))
	a.hp = maxi(0, a.hp - amount)
	events.append({"type": "damage", "side": "ally", "index": i, "ally": ai, "amount": amount, "crit": false})
	_say("%s hits %s for %d." % [e["name"], a.name, amount])
	if a.hp == 0:
		events.append({"type": "ko", "side": "ally", "ally": ai, "foe_scale": _scale_foes_to_party()})
		_say("%s is knocked senseless and out of the fight." % a.name)
