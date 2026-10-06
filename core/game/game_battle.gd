## Turn-based battle logic. No rendering: the UI reads `enemies`, `allies`, `statuses`, `events`
## and `log`. Event "by" is the acting ally's index (-1 for the heir); side "ally" events carry
## "ally". Units are named by refs: "heir", "ally:<i>", "enemy:<i>". Every foe has a place on the
## field in paces ("x", "y"; see GameCombat.place_enemies); areas are measured on it.
class_name GameBattle
extends RefCounted

var heir: GameHeir
var enemies: Array = []        # [{id,name,level,hp,max_hp,atk,def,agi,color,element,xp,gold,boss,row,x,y}]
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
var statuses: Dictionary = {}  # ref -> [{id, turns, amount, stacks, source, beat}]
var immune: Dictionary = {}    # ref -> the unit's own turns left of immunity to control effects
var heir_skip: bool = false    # a status cost the heir this turn; any action just lets it pass
var casts: int = 0             # numbers each ability use; the events it causes share the number
var uses: Dictionary = {}      # "<ref>/<ability name>" -> times used this battle
var _nums: Dictionary = {}     # unit index -> unit_numbers, worked out once a battle


func _init(p_heir: GameHeir, p_enemies: Array, p_rng: RandomNumberGenerator) -> void:
	heir = p_heir
	enemies = p_enemies
	rng = p_rng
	GameCombat.place_enemies(enemies)


func living_enemies() -> Array:
	var out: Array = []
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			out.append(i)
	return out


func first_target() -> int:
	var l := living_enemies()
	return l[0] if l.size() > 0 else -1


## Companions join before the first blow, knowing the spells of their class and level. Foes facing
## a band take more bringing down, so allies make a fight safer more than shorter. Their blows are
## not scaled: a party must never turn a fair fight into one where the heir falls before they act.
func add_allies(units: Array) -> void:
	allies = units
	for a in allies:
		a.learn_spells()
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


## Every action starts here. A heir who lost the turn to a status just lets it pass.
func _begin_action() -> bool:
	events = []
	if result != "":
		return false
	if heir_skip:
		heir_skip = false
		_end_player_turn()
		return false
	return true


func _say(text: String) -> void:
	log.append(text)


func _unit(by: int) -> GameHeir:
	return heir if by < 0 else allies[by]


func unit(by: int) -> GameHeir:
	return _unit(by)


# ---------------------------------------------------------------- refs and places

static func ref_of(by: int) -> String:
	return "heir" if by < 0 else "ally:%d" % by


static func enemy_ref(i: int) -> String:
	return "enemy:%d" % i


func _side(ref: String) -> String:
	return ref.get_slice(":", 0)


func _index(ref: String) -> int:
	return int(ref.get_slice(":", 1))


func ref_name(ref: String) -> String:
	match _side(ref):
		"heir":
			return heir.name
		"ally":
			return allies[_index(ref)].name
		"enemy":
			return str(enemies[_index(ref)]["name"])
	return "?"


func ref_hp(ref: String) -> int:
	match _side(ref):
		"heir":
			return heir.hp
		"ally":
			return allies[_index(ref)].hp
		"enemy":
			return int(enemies[_index(ref)]["hp"])
	return 0


func ref_max_hp(ref: String) -> int:
	match _side(ref):
		"heir":
			return heir.max_hp()
		"ally":
			return allies[_index(ref)].max_hp()
		"enemy":
			return int(enemies[_index(ref)]["max_hp"])
	return 1


func ref_level(ref: String) -> int:
	match _side(ref):
		"heir":
			return heir.level
		"ally":
			return allies[_index(ref)].level
		"enemy":
			return int(enemies[_index(ref)].get("level", 1))
	return 0


func _ref_boss(ref: String) -> bool:
	return _side(ref) == "enemy" and bool(enemies[_index(ref)].get("boss", false))


func _ref_alive(ref: String) -> bool:
	match _side(ref):
		"heir", "ally", "enemy":
			return ref_hp(ref) > 0
	return false


## What "power"-based statuses from this unit scale with.
func _ref_power(ref: String) -> float:
	match _side(ref):
		"heir", "ally":
			var nums := unit_numbers(-1 if ref == "heir" else _index(ref))
			return maxf(float(nums["str"]), float(nums["mag"]))
		"enemy":
			return float(enemies[_index(ref)]["atk"])
	return 0.0


## The heir and every companion still standing.
func party_refs() -> Array:
	var out: Array = ["heir"]
	for ai in conscious_allies():
		out.append(ref_of(ai))
	return out


func unit_point(by: int) -> Vector2:
	return GameCombat.heir_point() if by < 0 else GameCombat.ally_point(by)


func enemy_point(i: int) -> Vector2:
	var e: Dictionary = enemies[i]
	return Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))


## Foes an ability would strike, aimed at `target`, with each one's damage factor: [[i, f], ...].
func aoe_hits(ab: Dictionary, caster: int, target: int) -> Array:
	if not GameCombat.aims_at_foe(ab):
		return []
	target = _valid_target(target)
	if target < 0:
		return []
	var points := {}
	for i in living_enemies():
		points[i] = enemy_point(i)
	return GameCombat.footprint(ab, unit_point(caster), target, points)


## Indices of the living foes an ability used by `caster` (-1 heir, else ally index) on
## `target_index` would hit. The UI previews this; the bot weighs it.
func aoe_targets(ability: Dictionary, caster: int, target_index: int) -> Array:
	return aoe_hits(ability, caster, target_index).map(func(h): return h[0])


# ---------------------------------------------------------------- statuses

func status_list(ref: String) -> Array:
	return statuses.get(ref, [])


func status_of(ref: String, id: String) -> Dictionary:
	for inst in status_list(ref):
		if inst["id"] == id:
			return inst
	return {}


func has_status(ref: String, id: String) -> bool:
	return not status_of(ref, id).is_empty()


## Sum of one modifier (dodge, crit, damage_dealt, damage_taken, extra_action) over a unit's statuses.
func status_mod(ref: String, key: String) -> float:
	var t := 0.0
	for inst in status_list(ref):
		var mods: Dictionary = GameCombat.status_def(inst["id"]).get("mods", {})
		if mods.has(key):
			t += float(mods[key]) * float(inst["amount"]) * float(inst["stacks"])
	return t


func _dealt_mult(ref: String) -> float:
	return maxf(0.1, 1.0 + status_mod(ref, "damage_dealt"))


func _taken_mult(ref: String) -> float:
	return maxf(0.1, 1.0 + status_mod(ref, "damage_taken"))


## True while a status will cost the unit its next turn for certain (stun, freeze, sleep).
func is_held(ref: String) -> bool:
	for inst in status_list(ref):
		if GameCombat.status_def(inst["id"]).get("skip", "") == "always":
			return true
	return false


## Chance a status entry from an ability ({id, chance, ...}) takes hold: foes well above the
## caster's level shrug off harm, legends resist control, and a unit just freed from control
## cannot be locked down again at once. Help for the party always lands.
func status_chance(target_ref: String, entry: Dictionary, source: String) -> float:
	var id := str(entry["id"])
	var def := GameCombat.status_def(id)
	var chance := float(entry.get("chance", 1.0))
	if def.is_empty() or not _ref_alive(target_ref):
		return 0.0
	if not def.get("harmful", false):
		return clampf(chance, 0.0, 1.0)
	var control := bool(def.get("control", false))
	if control and int(immune.get(target_ref, 0)) > 0:
		return 0.0
	var src_lv := float(maxi(1, ref_level(source))) if source != "" else float(maxi(1, ref_level(target_ref)))
	var ratio := float(maxi(1, ref_level(target_ref))) / src_lv
	chance *= clampf(1.0 - float(GameCombat.setting("level_resist")) * (ratio - 1.0), float(GameCombat.setting("resist_floor")), float(GameCombat.setting("resist_ceiling")))
	if control and _ref_boss(target_ref):
		chance *= float(GameCombat.setting("boss_control_chance"))
	return clampf(chance, 0.0, 1.0)


## Rolls an ability's status entry against a unit; true if it took hold.
func try_status(target_ref: String, entry: Dictionary, source: String, power: float = -1.0) -> bool:
	var def := GameCombat.status_def(str(entry["id"]))
	if def.is_empty() or not _ref_alive(target_ref):
		return false
	var chance := status_chance(target_ref, entry, source)
	if chance < 1.0 and rng.randf() >= chance:
		events.append({"type": "status", "ref": target_ref, "id": entry["id"], "applied": false})
		return false
	var turns := int(entry.get("turns", def.get("default_turns", 1)))
	return apply_status(target_ref, str(entry["id"]), float(entry.get("potency", def.get("default_potency", 1.0))), turns, source, power)


## Puts a status on a unit, no roll (see try_status for chances). `potency` means what the status's
## "basis" says: a fraction of `power` (or the source's own power), a fraction of the target's max
## HP, or a flat value. Reapplying follows the status's "stack" rule. Returns false if it could not.
func apply_status(target_ref: String, status_id: String, potency: float, turns: int, source: String = "", power: float = -1.0) -> bool:
	var def := GameCombat.status_def(status_id)
	if def.is_empty() or not _ref_alive(target_ref):
		return false
	var control := bool(def.get("control", false))
	if control and int(immune.get(target_ref, 0)) > 0:
		return false
	turns = clampi(turns, 1, int(GameCombat.setting("status_turns_max")))
	if control and _ref_boss(target_ref):
		turns = mini(turns, int(GameCombat.setting("boss_control_max_turns")))
	var amount := potency
	match str(def.get("basis", "flat")):
		"power":
			amount = potency * (power if power >= 0.0 else _ref_power(source))
		"max_hp":
			amount = potency * float(ref_max_hp(target_ref))
			if _ref_boss(target_ref) and def.get("harmful", false):
				amount *= float(GameCombat.setting("boss_max_hp_tick_mult"))
	var list: Array = statuses.get(target_ref, [])
	var cur := status_of(target_ref, status_id)
	if cur.is_empty():
		list.append({"id": status_id, "turns": turns, "amount": amount, "stacks": 1, "source": source, "beat": 0})
	else:
		match str(def.get("stack", "refresh")):
			"stack":
				cur["stacks"] = mini(int(cur["stacks"]) + 1, int(def.get("max_stacks", 1)))
				cur["amount"] = maxf(float(cur["amount"]), amount)
				cur["turns"] = maxi(int(cur["turns"]), turns)
			"extend":
				cur["turns"] = mini(int(cur["turns"]) + turns, int(GameCombat.setting("status_turns_max")))
				cur["amount"] = maxf(float(cur["amount"]), amount)
			_:
				cur["turns"] = maxi(int(cur["turns"]), turns)
				cur["amount"] = maxf(float(cur["amount"]), amount)
	statuses[target_ref] = list
	events.append({"type": "status", "ref": target_ref, "id": status_id, "applied": true, "turns": turns})
	_say(_status_text(def, "apply", target_ref))
	return true


func _status_text(def: Dictionary, key: String, ref: String, n: int = 0) -> String:
	var t: String = def.get("text", {}).get(key, "")
	if t == "":
		t = "{t}: %s." % def.get("name", "?")
	return t.replace("{t}", ref_name(ref)).replace("{n}", str(n))


func remove_status(ref: String, id: String, why: String = "end") -> void:
	var inst := status_of(ref, id)
	if inst.is_empty():
		return
	(statuses[ref] as Array).erase(inst)
	if (statuses[ref] as Array).is_empty():
		statuses.erase(ref)
	var def := GameCombat.status_def(id)
	if def.get("control", false):
		immune[ref] = maxi(int(immune.get(ref, 0)), int(GameCombat.setting("control_immunity_turns")))
	events.append({"type": "status", "ref": ref, "id": id, "applied": false, "removed": why})
	if _ref_alive(ref):
		_say(_status_text(def, why, ref))


## Clears every harmful status from a unit; returns how many.
func cleanse(ref: String) -> int:
	var n := 0
	for inst in status_list(ref).duplicate():
		if GameCombat.status_def(inst["id"]).get("harmful", false):
			remove_status(ref, inst["id"], "end")
			n += 1
	return n


## Start of a unit's own turn: control immunity wears down, damage and healing over time land,
## then durations count down. Returns false when the unit cannot act (fallen, or a status costs it
## the turn).
func _start_turn(ref: String) -> bool:
	if int(immune.get(ref, 0)) > 0:
		immune[ref] = int(immune[ref]) - 1
	var list: Array = status_list(ref)
	if list.is_empty():
		return _ref_alive(ref)
	var skip := ""
	for inst in list.duplicate():
		var def := GameCombat.status_def(inst["id"])
		var n := maxi(1, int(round(float(inst["amount"]) * float(inst["stacks"]))))
		match str(def.get("tick", "")):
			"damage":
				_say(_status_text(def, "tick", ref, n))
				_tick_damage(ref, n, inst["id"])
				if not _ref_alive(ref):
					return false
			"heal":
				_tick_heal(ref, n, inst["id"])
		if skip == "":
			match str(def.get("skip", "")):
				"always":
					skip = inst["id"]
				"chance":
					if rng.randf() < float(inst["amount"]):
						skip = inst["id"]
				"alternate":
					inst["beat"] = int(inst["beat"]) + 1
					if int(inst["beat"]) % 2 == 0:
						skip = inst["id"]
	if skip != "":
		events.append({"type": "skip", "ref": ref, "id": skip})
		_say(_status_text(GameCombat.status_def(skip), "skip", ref))
	for inst in list.duplicate():
		inst["turns"] = int(inst["turns"]) - 1
		if int(inst["turns"]) <= 0:
			remove_status(ref, inst["id"], "end")
	return skip == ""


func _tick_damage(ref: String, n: int, id: String) -> void:
	var absorbed := _absorb(ref, n)
	var lost := n - absorbed
	events.append({"type": "tick", "ref": ref, "id": id, "amount": lost, "absorbed": absorbed})
	_lose_hp(ref, lost)


func _tick_heal(ref: String, n: int, id: String) -> void:
	var before := ref_hp(ref)
	match _side(ref):
		"heir":
			heir.hp = mini(heir.max_hp(), heir.hp + n)
		"ally":
			var a: GameHeir = allies[_index(ref)]
			a.hp = mini(a.max_hp(), a.hp + n)
		"enemy":
			var e: Dictionary = enemies[_index(ref)]
			e["hp"] = mini(int(e["max_hp"]), int(e["hp"]) + n)
	var gained := ref_hp(ref) - before
	if gained > 0:
		events.append({"type": "tick", "ref": ref, "id": id, "amount": gained, "heal": true})
		_say(_status_text(GameCombat.status_def(id), "tick", ref, gained))


## A shield soaks up damage before HP does; returns the amount it absorbed.
func _absorb(ref: String, n: int) -> int:
	var total := 0
	for inst in status_list(ref).duplicate():
		if n - total <= 0:
			break
		var def := GameCombat.status_def(inst["id"])
		if not def.get("absorb", false):
			continue
		var take := mini(n - total, int(floor(float(inst["amount"]))))
		inst["amount"] = float(inst["amount"]) - float(take)
		total += take
		if take > 0:
			_say(_status_text(def, "absorb", ref, take))
		if float(inst["amount"]) < 1.0:
			remove_status(ref, inst["id"], "end")
	return total


## HP loss already announced by its own event; handles a foe's death and a companion's knock-out.
func _lose_hp(ref: String, n: int) -> void:
	match _side(ref):
		"heir":
			heir.hp = maxi(0, heir.hp - n)
		"enemy":
			var i := _index(ref)
			var e: Dictionary = enemies[i]
			var was: int = e["hp"]
			e["hp"] = maxi(0, int(e["hp"]) - n)
			if was > 0 and e["hp"] == 0:
				events.append({"type": "death", "side": "enemy", "index": i})
				_say("%s is defeated." % e["name"])
				statuses.erase(ref)
		"ally":
			var ai := _index(ref)
			var a: GameHeir = allies[ai]
			var was := a.hp
			a.hp = maxi(0, a.hp - n)
			if was > 0 and a.hp == 0:
				statuses.erase(ref)
				events.append({"type": "ko", "side": "ally", "ally": ai, "foe_scale": _scale_foes_to_party()})
				_say("%s is knocked senseless and out of the fight." % a.name)


## Extra damage fraction the next blow on a frozen unit gets (see _break_ice).
func _shatter(ref: String) -> float:
	for inst in status_list(ref):
		var bonus := float(GameCombat.status_def(inst["id"]).get("shatter", 0.0))
		if bonus > 0.0:
			return bonus
	return 0.0


## After a blow lands: the ice breaks and a sleeper wakes.
func _after_blow(ref: String) -> void:
	for inst in status_list(ref).duplicate():
		var def := GameCombat.status_def(inst["id"])
		if float(def.get("shatter", 0.0)) > 0.0:
			remove_status(ref, inst["id"], "shatter")
		elif def.get("wake_on_hit", false):
			remove_status(ref, inst["id"], "wake")


## Haste: after acting, a chance to act again. No roll is made without it.
func _extra_action(ref: String) -> bool:
	var p := status_mod(ref, "extra_action")
	if p <= 0.0 or not _ref_alive(ref) or rng.randf() >= p:
		return false
	_say(_status_text(GameCombat.status_def("haste"), "extra", ref))
	return true


# ---------------------------------------------------------------- dealing damage

func _calc_damage(power: float, mult: float, idx: int, pierce: float, crit_bonus: float, by: int = -1, element: String = "") -> Dictionary:
	var e: Dictionary = enemies[idx]
	var dmg: float = maxf(1.0, power * mult - float(e["def"]) * (1.0 - pierce) * 0.5)
	dmg *= rng.randf_range(0.9, 1.1)
	if by < 0:  # legacy echoes are the family's, not the hirelings'
		dmg *= 1.0 + damage_bonus + float(slayer_bonus.get(e["id"], 0.0))
	dmg *= GameCombat.element_mult(element, str(e.get("element", "")))
	dmg *= _dealt_mult(ref_of(by)) * _taken_mult(enemy_ref(idx))
	var crit := rng.randf() < float(unit_numbers(by)["crit"]) + crit_bonus + float(weather.get("crit", 0.0)) + status_mod(ref_of(by), "crit")
	if crit:
		dmg *= 1.75
	return {"amount": maxi(1, int(round(dmg))), "crit": crit}


func _hit_enemy(idx: int, power: float, mult: float, pierce: float, crit_bonus: float, by: int = -1, element: String = "", cast: int = 0) -> int:
	var e: Dictionary = enemies[idx]
	var ref := enemy_ref(idx)
	var r := _calc_damage(power, mult, idx, pierce, crit_bonus, by, element)
	var amount: int = r["amount"]
	var shatter := _shatter(ref)
	if shatter > 0.0:
		amount = int(round(float(amount) * (1.0 + shatter)))
	var absorbed := _absorb(ref, amount)
	var hp_before: int = e["hp"]
	events.append({"type": "damage", "side": "enemy", "index": idx, "amount": amount - absorbed, "crit": r["crit"], "by": by,
		"cast": cast, "element": element, "shatter": shatter > 0.0, "absorbed": absorbed})
	_say("%s hits %s for %d%s." % [_unit(by).name, e["name"], amount - absorbed, " (CRIT!)" if r["crit"] else ""])
	_lose_hp(ref, amount - absorbed)
	if e["hp"] > 0:
		_after_blow(ref)
	return hp_before - int(e["hp"])


func attack(target: int) -> void:
	if not _begin_action():
		return
	target = _valid_target(target)
	focus = target
	_hit_enemy(target, float(unit_numbers(-1)["str"]), 1.0, 0.0, 0.0)
	_heir_haste()
	_end_player_turn()


func skill_count() -> int:
	return (heir.cls()["skills"] as Array).size()


func skill_info(i: int) -> Dictionary:
	return heir.cls()["skills"][i]


## Skill costs grow with level, so max MP growth buys stronger casts rather than endless heals.
func skill_cost(i: int) -> int:
	return unit_skill_cost(heir, i)


static func unit_skill_cost(u: GameHeir, i: int) -> int:
	return GameCombat.ability_cost(u.cls()["skills"][i], u.level)


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
	if result == "" and not heir_skip and not can_use_skill(i):
		return
	use_ability(skill_info(i), target, skill_cost(i))


# ---------------------------------------------------------------- spells

func unit_spells(by: int) -> Array:
	return _unit(by).spells


func known_spells() -> Array:
	return heir.spells


func spell_cost(id: String) -> int:
	return GameCombat.ability_cost(GameCombat.spell(id), heir.level)


func can_cast(id: String) -> bool:
	return result == "" and id in heir.spells and heir.mp >= spell_cost(id)


func cast_spell(id: String, target: int) -> void:
	if id not in heir.spells:
		return
	if result == "" and not heir_skip and not can_cast(id):
		return
	use_ability(GameCombat.spell(id), target, spell_cost(id))


## The heir's turn with any ability (a class skill, a spell, or anything shaped like one): pay
## `mp_cost`, resolve it, let allies and foes act. Another resource or scaling is the caller's.
func use_ability(ab: Dictionary, target: int, mp_cost: int = 0, power: float = -1.0) -> void:
	if not _begin_action() or heir.mp < mp_cost:
		return
	heir.mp -= mp_cost
	resolve_ability(-1, ab, target, power)
	_heir_haste()
	_end_player_turn()


## The one pipeline every ability runs through. Areas strike each foe inside with its own roll;
## several hits on a single foe roll over to the next when it falls; then statuses, drain, healing,
## cleansing and mana. Costs are the caller's; `power` < 0 means the ability's own stat decides.
func resolve_ability(by: int, ab: Dictionary, target: int, power: float = -1.0) -> void:
	var u := _unit(by)
	if power < 0.0:
		var nums := unit_numbers(by)
		power = float(nums.get(str(ab.get("stat", "str")), nums["str"]))
	casts += 1
	var name := str(ab.get("name", "?"))
	var aoe := GameCombat.is_aoe(ab)
	var hits: Array = []
	if GameCombat.aims_at_foe(ab):
		target = _valid_target(target)
		if target < 0:
			return
		if by < 0 and float(ab.get("mult", 0.0)) > 0.0:
			focus = target
		hits = aoe_hits(ab, by, target)
	events.append({"type": "cast", "by": by, "name": name, "cast": casts, "aoe": aoe, "element": str(ab.get("element", "")),
		"targets": hits.map(func(h): return h[0])})
	if ab.has("group") or aoe:
		_say("%s %s %s." % [u.name, "casts" if ab.has("group") else "uses", name])
	var src := ref_of(by)
	var key := "%s/%s" % [src, name]
	uses[key] = int(uses.get(key, 0)) + 1
	var dealt := 0
	var mult := float(ab.get("mult", 0.0))
	if mult > 0.0 and not hits.is_empty():
		var el := str(ab.get("element", ""))
		var pierce := float(ab.get("pierce", 0.0))
		var cb := float(ab.get("crit_bonus", 0.0))
		var n := int(ab.get("hits", 1))
		if not aoe and n > 1:
			var t := target
			for h in n:
				if enemies[t]["hp"] <= 0:
					t = first_target()
					if t < 0:
						break
				dealt += _hit_enemy(t, power, mult, pierce, cb, by, el, casts)
		else:
			for h in hits:
				if enemies[h[0]]["hp"] > 0:
					dealt += _hit_enemy(h[0], power, mult * float(h[1]), pierce, cb, by, el, casts)
	for st in ab.get("statuses", []):
		match str(st.get("on", "target")):
			"party":
				for r in party_refs():
					try_status(r, st, src, power)
			"self":
				try_status(src, st, src, power)
			_:
				var shrugged: Array = []
				for h in hits:
					if enemies[h[0]]["hp"] > 0 and not try_status(enemy_ref(h[0]), st, src, power):
						shrugged.append(enemies[h[0]]["name"])
				if not shrugged.is_empty():
					var what := str(GameCombat.status_def(str(st["id"])).get("name", st["id"]))
					_say("%s resist%s %s." % [shrugged[0] if shrugged.size() == 1 else "%d foes" % shrugged.size(), "s" if shrugged.size() == 1 else "", what])
	var drain := float(ab.get("drain", 0.0))
	if drain > 0.0 and dealt > 0:
		if by < 0:
			_heal_player(int(round(float(dealt) * drain)), name)
		else:
			_heal_ally(by, int(round(float(dealt) * drain)), name)
	if ab.has("pct_max_hp"):
		if ab.get("party", false):
			for r in party_refs():
				if r == "heir":
					_heal_player(heal_amount(u, heir, ab), name, by)
				else:
					var ai := _index(r)
					_heal_ally(ai, heal_amount(u, allies[ai], ab), name, by)
		else:   # a class heal mends its user, or a companion tends the heir
			_heal_player(heal_amount(u, heir, ab), name, by)
	if ab.get("cleanse", false):
		for r in party_refs():
			cleanse(r)
	if ab.get("mana", false):
		var before := u.mp
		u.mp = mini(u.max_mp(), u.mp + int(ceil(float(u.max_mp()) * float(GameCombat.setting("mana_tap_pct")))))
		events.append({"type": "mana", "by": by, "amount": u.mp - before})
		_say("%s draws in %d MP." % [u.name, u.mp - before])


## Haste on the heir: a free follow-up blow on the same foe.
func _heir_haste() -> void:
	if result != "" or living_enemies().is_empty() or not _extra_action("heir"):
		return
	var t := _valid_target(focus)
	_hit_enemy(t, float(unit_numbers(-1)["str"]), 1.0, 0.0, 0.0)


# ---------------------------------------------------------------- other heir actions

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


## Lets the turn pass; a heir who lost the turn to a status does the same with any action.
func pass_turn() -> void:
	if not _begin_action():
		return
	_say("%s holds back." % heir.name)
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


func _heal_ally(ai: int, amount: int, source: String, by: int = -2) -> void:
	var a: GameHeir = allies[ai]
	var before := a.hp
	a.hp = mini(a.max_hp(), a.hp + amount)
	events.append({"type": "heal", "side": "ally", "ally": ai, "amount": a.hp - before, "by": ai if by == -2 else by})
	_say("%s restores %d HP (%s)." % [a.name, a.hp - before, source])


func _valid_target(t: int) -> int:
	if t >= 0 and t < enemies.size() and enemies[t]["hp"] > 0:
		return t
	return first_target()


func _won() -> bool:
	if living_enemies().is_empty():
		result = "victory"
		_say("Victory!")
		return true
	return false


func _end_player_turn() -> void:
	if _won():
		return
	for ai in conscious_allies():
		if allies[ai].hp <= 0:
			continue
		_ally_turn(ai)
		if _won():
			return
	for i in living_enemies():
		if enemies[i]["hp"] <= 0:
			continue
		_enemy_turn(i)
		if heir.hp <= 0:
			result = "defeat"
			_say("%s has fallen..." % heir.name)
			return
		if _won():
			return
	defending = false
	turn += 1
	var regen := maxf(0.0, float(GameData.bal("mp_regen_per_turn_pct")) + float(weather.get("mp_regen", 0.0)))
	heir.mp = mini(heir.max_mp(), heir.mp + int(ceil(float(heir.max_mp()) * regen)))
	for ai in conscious_allies():
		var a: GameHeir = allies[ai]
		a.mp = mini(a.max_mp(), a.mp + int(ceil(float(a.max_mp()) * regen)))
	_start_heir_turn()


## The heir's statuses tick as the next turn begins, so the player sees where they stand.
func _start_heir_turn() -> void:
	heir_skip = false
	if _start_turn("heir"):
		return
	if heir.hp <= 0:
		result = "defeat"
		_say("%s has fallen..." % heir.name)
	else:
		heir_skip = true


func _ally_turn(ai: int) -> void:
	var ref := ref_of(ai)
	if not _start_turn(ref):
		return
	_ally_act(ai)
	if result == "" and not living_enemies().is_empty() and _extra_action(ref):
		_ally_act(ai)


## A companion's turn, chosen by GameTactics: mend the heir when they are badly hurt, cleanse,
## hold the most dangerous foe, or strike where it does the most.
func _ally_act(ai: int) -> void:
	var a: GameHeir = allies[ai]
	var plan := GameTactics.choose(self, ai)
	match str(plan.get("act", "attack")):
		"ability":
			a.mp -= int(plan["cost"])
			resolve_ability(ai, plan["ab"], int(plan["target"]))
		_:
			_hit_enemy(_valid_target(int(plan.get("target", focus))), float(unit_numbers(ai)["str"]), 1.0, 0.0, 0.0, ai)


## Who an enemy goes for: the heir, or (less often) a companion still standing. -1 = the heir.
func _enemy_target() -> int:
	var up := conscious_allies()
	if up.is_empty() or rng.randf() < float(GameData.bal("companion_heir_target_chance")):
		return -1
	return up[rng.randi() % up.size()]


func _enemy_turn(i: int) -> void:
	var ref := enemy_ref(i)
	if not _start_turn(ref):
		return
	_enemy_act(i)
	if result == "" and heir.hp > 0 and _extra_action(ref):
		_enemy_act(i)


func _enemy_act(i: int) -> void:
	var e: Dictionary = enemies[i]
	var who := _enemy_target()
	if who >= 0:
		_enemy_hit_ally(i, who)
		return
	var me := unit_numbers(-1)
	if rng.randf() < clampf(float(me["dodge"]) + float(weather.get("dodge", 0.0)) + status_mod("heir", "dodge"), 0.0, 0.6):
		events.append({"type": "miss", "side": "player", "index": i})
		_say("%s attacks, but %s dodges." % [e["name"], heir.name])
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - float(me["def"]) * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(heir.trait_total("fire_resistance"), 0.0, 0.8)
	if defending:
		dmg *= 0.5
	dmg *= _dealt_mult(enemy_ref(i)) * _taken_mult("heir") * (1.0 + _shatter("heir"))
	var amount := maxi(1, int(round(dmg)))
	var absorbed := _absorb("heir", amount)
	events.append({"type": "damage", "side": "player", "index": i, "amount": amount - absorbed, "crit": false, "absorbed": absorbed})
	_say("%s hits %s for %d%s." % [e["name"], heir.name, amount - absorbed, " (%d absorbed)" % absorbed if absorbed > 0 else ""])
	_lose_hp("heir", amount - absorbed)
	if heir.hp > 0:
		_after_blow("heir")
		_inflict(i, "heir")


func _enemy_hit_ally(i: int, ai: int) -> void:
	var e: Dictionary = enemies[i]
	var a: GameHeir = allies[ai]
	var ref := ref_of(ai)
	var nums := unit_numbers(ai)
	if rng.randf() < clampf(float(nums["dodge"]) + float(weather.get("dodge", 0.0)) + status_mod(ref, "dodge"), 0.0, 0.6):
		events.append({"type": "miss", "side": "ally", "index": i, "ally": ai})
		_say("%s attacks, but %s dodges." % [e["name"], a.name])
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - float(nums["def"]) * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(a.trait_total("fire_resistance"), 0.0, 0.8)
	dmg *= _dealt_mult(enemy_ref(i)) * _taken_mult(ref) * (1.0 + _shatter(ref))
	var amount := maxi(1, int(round(dmg)))
	var absorbed := _absorb(ref, amount)
	events.append({"type": "damage", "side": "ally", "index": i, "ally": ai, "amount": amount - absorbed, "crit": false, "absorbed": absorbed})
	_say("%s hits %s for %d%s." % [e["name"], a.name, amount - absorbed, " (%d absorbed)" % absorbed if absorbed > 0 else ""])
	_lose_hp(ref, amount - absorbed)
	if a.hp > 0:
		_after_blow(ref)
		_inflict(i, ref)


## A creature's own statuses (a fire imp's burn...) on a unit it just struck.
func _inflict(i: int, target_ref: String) -> void:
	for entry in GameCombat.creature_def(str(enemies[i]["id"])).get("inflicts", []):
		try_status(target_ref, entry, enemy_ref(i), float(enemies[i]["atk"]))


# ---------------------------------------------------------------- estimates (for tactics and the UI)

## A unit's fighting numbers, which hold for the whole battle (worked out again only if its level
## changes): power by stat, crit and dodge chance, defense, max HP. Working them out walks every
## trait and item, so blows and tactics read them from here.
func unit_numbers(by: int) -> Dictionary:
	var u := _unit(by)
	var c: Dictionary = _nums.get(by, {})
	if c.is_empty() or int(c["level"]) != u.level or c["unit"] != u:
		var atk := u.attack_power()
		var mag := u.magic_power()
		c = {"unit": u, "level": u.level, "str": atk, "mag": mag, "both": (atk + mag) * 0.6, "crit": u.crit_chance(),
			"dodge": u.dodge_chance(), "def": u.defense(), "max_hp": u.max_hp()}
		_nums[by] = c
	return c


## Expected damage of an ability (or a plain attack when `ab` is empty) used by `by` on `target`,
## foe by foe and before overkill: [[enemy index, damage], ...]. `hits` (a footprint) and `nums`
## (unit_numbers) may be passed in when already known.
func expected_hits(by: int, ab: Dictionary, target: int, hits: Array = [], nums: Dictionary = {}) -> Array:
	var mult := 1.0 if ab.is_empty() else float(ab.get("mult", 0.0))
	if mult <= 0.0:
		return []
	if nums.is_empty():
		nums = unit_numbers(by)
	var power: float = nums["str"] if ab.is_empty() else nums.get(str(ab.get("stat", "str")), nums["str"])
	if hits.is_empty():
		hits = [[_valid_target(target), 1.0]] if ab.is_empty() else aoe_hits(ab, by, target)
	var pierce := float(ab.get("pierce", 0.0))
	var calm := statuses.is_empty()   # most of the time nobody carries a status: skip the lookups
	var crit := clampf(float(nums["crit"]) + float(ab.get("crit_bonus", 0.0)) + float(weather.get("crit", 0.0)) + (0.0 if calm else status_mod(ref_of(by), "crit")), 0.0, 1.0)
	var n := 1 if GameCombat.is_aoe(ab) else int(ab.get("hits", 1))
	var el := str(ab.get("element", ""))
	var base := (1.0 + crit * 0.75) * float(n) * (1.0 if calm else _dealt_mult(ref_of(by)))
	var out: Array = []
	for h in hits:
		var i: int = h[0]
		if i < 0:
			continue
		var e: Dictionary = enemies[i]
		var dmg := maxf(1.0, power * mult * float(h[1]) - float(e["def"]) * (1.0 - pierce) * 0.5) * base
		if by < 0:
			dmg *= 1.0 + damage_bonus + float(slayer_bonus.get(e["id"], 0.0))
		if el != "":
			dmg *= GameCombat.element_mult(el, str(e.get("element", "")))
		if not calm:
			var ref := enemy_ref(i)
			dmg *= _taken_mult(ref) * (1.0 + _shatter(ref))
		out.append([i, dmg])
	return out


## Expected damage of an ability on `target`; each foe counts up to its remaining HP.
func estimate(by: int, ab: Dictionary, target: int, nums: Dictionary = {}) -> float:
	var total := 0.0
	for h in expected_hits(by, ab, target, [], nums):
		total += minf(float(h[1]), float(enemies[h[0]]["hp"]))
	return total


## Expected damage a foe deals the heir on its next turn (0 while it is held fast).
func foe_threat(i: int) -> float:
	var e: Dictionary = enemies[i]
	var me := unit_numbers(-1)
	if e["hp"] <= 0:
		return 0.0
	if statuses.is_empty():
		return maxf(1.0, float(e["atk"]) - float(me["def"]) * 0.6) * (1.0 - clampf(float(me["dodge"]), 0.0, 0.6))
	var ref := enemy_ref(i)
	if is_held(ref):
		return 0.0
	var dmg := maxf(1.0, float(e["atk"]) - float(me["def"]) * 0.6) * _dealt_mult(ref) * _taken_mult("heir")
	for inst in status_list(ref):
		match str(GameCombat.status_def(inst["id"]).get("skip", "")):
			"chance":
				dmg *= 1.0 - clampf(float(inst["amount"]), 0.0, 1.0)
			"alternate":
				dmg *= 0.5
	return dmg * (1.0 - clampf(float(me["dodge"]) + status_mod("heir", "dodge"), 0.0, 0.6))
