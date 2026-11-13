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
var biomes: Array = []             # the ground the battle is fought on (environmental feats need it)
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
var struck: Dictionary = {}    # refs that have landed a blow this battle (First Strike)
var feat_ready: Dictionary = {}   # ref -> {feat id -> the round from which that unit may use it again, "*" -> after any feat}
var fields: Array = []         # ground an ability fouled: [{name, x, y, radius, from, until, statuses, source, power, color, end}]
var _nums: Dictionary = {}     # unit index -> unit_numbers, worked out once a battle
var _gear: Dictionary = {}     # unit index -> {feat id -> why its weapon or this ground rules it out}
var coating: Dictionary = {}   # {item, hits}: a toxin on the heir's blade (see GamePlague)
var exposures: Array = []      # [{disease, chance, source}]: what the heir risked, rolled once the battle is settled
var _blade: bool = false       # the heir's blows now come from the blade, so a coating rides on them
var round_on: bool = false     # a GameRound is running: the heir's action no longer plays the rest of the round itself
var round_acted: bool = false  # the heir's slot was used (acted or passed) while round_on
var round_marks: bool = false  # tell round, act and foes markers in `events` (only inside GameRound.resolve)
var round_cmds: Dictionary = {}   # ally index -> plan the player chose for this round; absent = the class's own choice
var round_covers: Dictionary = {} # covered ref -> member who steps in (GameRound.set_cover); set only for end_round
var round_asks: Dictionary = {}   # by -> true: members the player may be asked to step in (GameRound.ask_reactions)
var reaction: Dictionary = {}     # a blow waiting on the player's answer: {"foe": i, "for": by, "by": [who may step in]}
var _covered: Dictionary = {}     # members who have stepped in this round
var _asked_for: Dictionary = {}   # members the player has been asked about this round
var _foe_queue: Array = []        # foes still to act this round, in order
var _foe_step: int = 0            # where the foe at the head of _foe_queue is in its turn (see _foe_turn_steps)
var braced: Dictionary = {}    # ref -> true: a companion braced this round (see GameRound, settings.brace_taken)
var resumed: bool = false      # not saved: this fight was loaded from a save made in the middle of it


func _init(p_heir: GameHeir, p_enemies: Array, p_rng: RandomNumberGenerator) -> void:
	heir = p_heir
	enemies = p_enemies
	rng = p_rng
	GameCombat.place_enemies(enemies)


## A fight in progress as plain values, for a save made in the middle of it (GameDynasty.to_save). The heir and
## the dice are the dynasty's and saved with it; each companion is kept as who they are and their health and
## mana, and rebuilt from the party on load. The worked-out numbers (_nums, _gear) are worked out again.
func to_dict() -> Dictionary:
	return {
		"enemies": enemies, "damage_bonus": damage_bonus, "slayer_bonus": slayer_bonus, "weather": weather,
		"biomes": biomes, "allies": allies.map(func(a): return {"id": str(a.get_meta("companion", "")), "hp": a.hp, "mp": a.mp}),
		"foe_hp_mult": foe_hp_mult, "result": result, "defending": defending, "turn": turn, "focus": focus,
		"log": log, "events": events, "statuses": statuses, "immune": immune, "heir_skip": heir_skip, "casts": casts,
		"uses": uses, "struck": struck, "feat_ready": feat_ready, "fields": fields, "coating": coating,
		"exposures": exposures, "blade": _blade, "round_on": round_on, "round_acted": round_acted,
		"round_marks": round_marks, "round_cmds": round_cmds, "round_covers": round_covers, "round_asks": round_asks,
		"reaction": reaction, "covered": _covered, "asked_for": _asked_for, "foe_queue": _foe_queue,
		"foe_step": _foe_step, "braced": braced,
	}


## The fight a to_dict() saved, given back its heir, its dice and its companions (rebuilt from the party in
## the saved order, as add_allies made them, without scaling the foes again: their saved health already is).
## Null when a value is missing or of the wrong kind, or the companions do not match: the fight is not loaded.
static func restore(v: Dictionary, p_heir: GameHeir, p_rng: RandomNumberGenerator, p_allies: Array) -> GameBattle:
	var kinds := {
		"enemies": TYPE_ARRAY, "damage_bonus": TYPE_FLOAT, "slayer_bonus": TYPE_DICTIONARY, "weather": TYPE_DICTIONARY,
		"biomes": TYPE_ARRAY, "allies": TYPE_ARRAY, "foe_hp_mult": TYPE_FLOAT, "result": TYPE_STRING, "defending": TYPE_BOOL,
		"turn": TYPE_INT, "focus": TYPE_INT, "log": TYPE_ARRAY, "events": TYPE_ARRAY, "statuses": TYPE_DICTIONARY,
		"immune": TYPE_DICTIONARY, "heir_skip": TYPE_BOOL, "casts": TYPE_INT, "uses": TYPE_DICTIONARY,
		"struck": TYPE_DICTIONARY, "feat_ready": TYPE_DICTIONARY, "fields": TYPE_ARRAY, "coating": TYPE_DICTIONARY,
		"exposures": TYPE_ARRAY, "blade": TYPE_BOOL, "round_on": TYPE_BOOL, "round_acted": TYPE_BOOL,
		"round_marks": TYPE_BOOL, "round_cmds": TYPE_DICTIONARY, "round_covers": TYPE_DICTIONARY,
		"round_asks": TYPE_DICTIONARY, "reaction": TYPE_DICTIONARY, "covered": TYPE_DICTIONARY,
		"asked_for": TYPE_DICTIONARY, "foe_queue": TYPE_ARRAY, "foe_step": TYPE_INT, "braced": TYPE_DICTIONARY,
	}
	for k in kinds:
		if typeof(v.get(k)) != kinds[k]:
			return null
	var saved: Array = v["allies"]
	if saved.size() != p_allies.size():
		return null
	var b := GameBattle.new(p_heir, [], p_rng)   # no placing: the foes keep the places they had
	b.enemies = v["enemies"]
	b.biomes = v["biomes"]
	b.allies = p_allies
	for i in p_allies.size():
		var a: GameHeir = p_allies[i]
		var s = saved[i]
		if typeof(s) != TYPE_DICTIONARY or str(s.get("id", "")) != str(a.get_meta("companion", "")):
			return null
		a.learn_spells()
		GameFeats.ready_companion(a, b.biomes, 1 + p_allies.size())
		a.hp = int(s.get("hp", a.hp))
		a.mp = int(s.get("mp", a.mp))
	b.damage_bonus = v["damage_bonus"]
	b.slayer_bonus = v["slayer_bonus"]
	b.weather = v["weather"]
	b.foe_hp_mult = v["foe_hp_mult"]
	b.result = v["result"]
	b.defending = v["defending"]
	b.turn = v["turn"]
	b.focus = v["focus"]
	b.log = v["log"]
	b.events = v["events"]
	b.statuses = v["statuses"]
	b.immune = v["immune"]
	b.heir_skip = v["heir_skip"]
	b.casts = v["casts"]
	b.uses = v["uses"]
	b.struck = v["struck"]
	b.feat_ready = v["feat_ready"]
	b.fields = v["fields"]
	b.coating = v["coating"]
	b.exposures = v["exposures"]
	b._blade = v["blade"]
	b.round_on = v["round_on"]
	b.round_acted = v["round_acted"]
	b.round_marks = v["round_marks"]
	b.round_cmds = v["round_cmds"]
	b.round_covers = v["round_covers"]
	b.round_asks = v["round_asks"]
	b.reaction = v["reaction"]
	b._covered = v["covered"]
	b._asked_for = v["asked_for"]
	b._foe_queue = v["foe_queue"]
	b._foe_step = v["foe_step"]
	b.braced = v["braced"]
	b.resumed = true
	return b


func living_enemies() -> Array:
	var out: Array = []
	for i in enemies.size():
		if enemies[i]["hp"] > 0:
			out.append(i)
	return out


func first_target() -> int:
	var l := living_enemies()
	return l[0] if l.size() > 0 else -1


## Companions join before the first blow, knowing the spells of their class and level and carrying
## the feats one of them would ready on this ground (see GameFeats.ready_companion). Foes facing
## a band take more bringing down, so allies make a fight safer more than shorter. Their blows are
## not scaled: a party must never turn a fair fight into one where the heir falls before they act.
func add_allies(units: Array) -> void:
	allies = units
	for a in allies:
		a.learn_spells()
		GameFeats.ready_companion(a, biomes, 1 + allies.size())
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
	if not round_on:
		events = []   # a queued round keeps one list for the whole round
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


## Where a unit's areas are measured from: its place, stepped up to the party's front line.
func cast_point(by: int) -> Vector2:
	return GameCombat.cast_point(unit_point(by))


func enemy_point(i: int) -> Vector2:
	var e: Dictionary = enemies[i]
	return Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))


## Foes an ability would strike, aimed at `target`, with each one's damage factor: [[i, f], ...].
## Empty when a cone or line aimed that way reaches no one.
func aoe_hits(ab: Dictionary, caster: int, target: int) -> Array:
	if not GameCombat.aims_at_foe(ab):
		return []
	target = _valid_target(target)
	if target < 0:
		return []
	var points := {}
	for i in living_enemies():
		points[i] = enemy_point(i)
	return GameCombat.footprint(ab, cast_point(caster), target, points)


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
	var m := maxf(0.1, 1.0 + status_mod(ref, "damage_dealt"))
	return m * _rule_dealt(ref) if _side(ref) != "enemy" else m


## What a keystone does to the damage a party member deals: Glass Cannon always, Wrath by the share
## of HP already lost.
func _rule_dealt(ref: String) -> float:
	var by := -1 if ref == "heir" else _index(ref)
	var nums := unit_numbers(by)
	var m := float(nums["dealt"])
	if float(nums["wrath"]) > 0.0:
		var u := _unit(by)
		m *= 1.0 + float(nums["wrath"]) * clampf(1.0 - float(u.hp) / float(maxi(1, int(nums["max_hp"]))), 0.0, 1.0)
	return m


## A party member's guards stacked together (a stance, a ward feat, a party blessing) never take
## off more than half of a blow: settings.party_taken_floor.
func _taken_mult(ref: String) -> float:
	var low := 0.1 if _side(ref) == "enemy" else float(GameCombat.setting("party_taken_floor"))
	return maxf(low, 1.0 + status_mod(ref, "damage_taken"))


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
	if _side(target_ref) != "enemy":
		chance *= 1.0 - float(unit_numbers(-1 if target_ref == "heir" else _index(target_ref))["resist"])
	return clampf(chance, 0.0, 1.0)


## Rolls an ability's status entry against a unit; true if it took hold.
func try_status(target_ref: String, entry: Dictionary, source: String, power: float = -1.0) -> bool:
	var def := GameCombat.status_def(str(entry["id"]))
	if def.is_empty() or not _ref_alive(target_ref):
		return false
	var chance := status_chance(target_ref, entry, source)
	if chance < 1.0 and rng.randf() >= chance:
		if _tells_resist(entry):
			events.append({"type": "status", "ref": target_ref, "id": entry["id"], "applied": false})
		return false
	var turns := int(entry.get("turns", def.get("default_turns", 1)))
	return apply_status(target_ref, str(entry["id"]), float(entry.get("potency", def.get("default_potency", 1.0))), turns, source, power)


## A side effect that seldom lands (a 35% burn) fails quietly; a spell cast for its effect does not.
static func _tells_resist(entry: Dictionary) -> bool:
	return float(entry.get("chance", 1.0)) >= float(GameCombat.setting("tell_resist_from"))


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
				n = _tick_resisted(ref, n, str(def.get("element", "")))
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


## Elements bite on ticks as on blows: a fire imp shrugs off half a burn, and the heir's and a
## companion's fire resistance cools one.
func _tick_resisted(ref: String, n: int, element: String) -> int:
	if element == "":
		return n
	var f := 1.0
	match _side(ref):
		"enemy":
			f = GameCombat.element_mult(element, str(enemies[_index(ref)].get("element", "")))
		"heir", "ally":
			var u: GameHeir = heir if ref == "heir" else allies[_index(ref)]
			f = 1.0 - clampf(u.trait_total(element + "_resistance"), 0.0, 0.8)
	return maxi(1, int(round(float(n) * f)))


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


## What a unit's wards can still soak.
func _ward(ref: String) -> int:
	var t := 0
	for inst in status_list(ref):
		if GameCombat.status_def(inst["id"]).get("absorb", false):
			t += int(floor(float(inst["amount"])))
	return t


## "Grimfang hits Tess for 50 (18 absorbed)." - told before a spent ward fades.
func _say_blow(who: String, whom: String, lost: int, absorbed: int, crit: bool) -> void:
	var tail := " (CRIT!)" if crit else ""
	if absorbed <= 0:
		_say(GameMessages.line("hit", {"who": who, "whom": whom, "n": lost, "tail": tail}))
	elif lost > 0:
		_say(GameMessages.line("hit_ward", {"who": who, "whom": whom, "n": lost, "absorbed": absorbed, "tail": tail}))
	else:
		_say(GameMessages.line("hit_ward_all", {"who": who, "whom": whom, "absorbed": absorbed}))


## A shield soaks up damage before HP does; returns the amount it absorbed. A blow tells the
## absorbed share in its own line (`tell` false); a tick leaves it to the ward.
func _absorb(ref: String, n: int, tell: bool = true) -> int:
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
		if take > 0 and tell:
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
				_say(GameMessages.line("foe_defeated", {"name": e["name"]}))
				statuses.erase(ref)
				var moved := GameCombat.close_ranks(enemies)
				if not moved.is_empty():
					events.append({"type": "advance", "indices": moved})
					_say(GameMessages.line("foe_steps_up", {"name": enemies[moved[0]]["name"]}) if moved.size() == 1 else GameMessages.line("back_rank_steps_up"))
		"ally":
			var ai := _index(ref)
			var a: GameHeir = allies[ai]
			var was := a.hp
			a.hp = maxi(0, a.hp - n)
			if was > 0 and a.hp == 0:
				statuses.erase(ref)
				events.append({"type": "ko", "side": "ally", "ally": ai, "foe_scale": _scale_foes_to_party()})
				_say(GameMessages.line("ally_knocked_out", {"name": a.name}))


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
	var nums := unit_numbers(by)
	var opening := float(nums["first_strike"]) > 0.0 and not struck.has(ref_of(by))   # First Strike: the battle's first blow
	struck[ref_of(by)] = true
	var roll := rng.randf()
	var crit := opening or roll < float(nums["crit"]) + crit_bonus + float(weather.get("crit", 0.0)) + status_mod(ref_of(by), "crit")
	if crit:
		dmg *= float(nums["crit_mult"]) + (float(nums["first_strike"]) if opening else 0.0)
	_spend_blow_statuses(ref_of(by))
	return {"amount": maxi(1, int(round(dmg))), "crit": crit}


## Dragon's Breath (a keystone rule): as the fight opens the heir exhales fire over every foe, which
## ignores armour and never fells one (it leaves the last of its life to the first blow).
func open_with_breath() -> void:
	var nums := unit_numbers(-1)
	if float(nums["breath"]) <= 0.0 or result != "":
		return
	var power := maxf(float(nums["str"]), float(nums["mag"])) * float(nums["breath"])
	events = []
	casts += 1
	var hit: Array = []
	for i in living_enemies():
		var e: Dictionary = enemies[i]
		var amount := mini(int(e["hp"]) - 1, int(round(power * GameCombat.element_mult("fire", str(e.get("element", "")))))) 
		if amount > 0:
			_lose_hp(enemy_ref(i), amount)
			hit.append(i)
	events.append({"type": "cast", "by": -1, "name": GameMessages.text("life", "ability_dragons_breath"), "cast": casts, "aoe": true, "element": "fire", "targets": hit})
	_say(GameMessages.line("dragons_breath", {"name": heir.name}))


## A status with "spent_on": "blow" (hidden) rides on the next blow the unit lands and ends there.
func _spend_blow_statuses(ref: String) -> void:
	if not statuses.has(ref):
		return
	for inst in status_list(ref).duplicate():
		if GameCombat.status_def(inst["id"]).get("spent_on", "") == "blow":
			remove_status(ref, inst["id"], "spent")


## A foe's chance to slip a blow: nimble kinds more often, a slowed one less, a held one never.
func foe_dodge(i: int) -> float:
	var ref := enemy_ref(i)
	if is_held(ref):
		return 0.0
	var chance := float(enemies[i].get("agi", 0)) * float(GameCombat.setting("foe_dodge_per_agi")) + status_mod(ref, "dodge")
	return clampf(chance, 0.0, float(GameCombat.setting("foe_dodge_max")))


## One blow on a foe, with its own dodge, crit and damage roll. Returns the HP it took, or -1
## when the foe dodged.
func _hit_enemy(idx: int, power: float, mult: float, pierce: float, crit_bonus: float, by: int = -1, element: String = "", cast: int = 0) -> int:
	var e: Dictionary = enemies[idx]
	var ref := enemy_ref(idx)
	var dodge := foe_dodge(idx)
	if dodge > 0.0 and rng.randf() < dodge:
		events.append({"type": "miss", "side": "enemy", "index": idx, "by": by, "cast": cast})
		_say(GameMessages.line("foe_dodged", {"foe": e["name"], "name": _unit(by).name}))
		return -1
	var r := _calc_damage(power, mult, idx, pierce, crit_bonus, by, element)
	var amount: int = r["amount"]
	var shatter := _shatter(ref)
	if shatter > 0.0:
		amount = int(round(float(amount) * (1.0 + shatter)))
	var absorbed := mini(amount, _ward(ref))
	var hp_before: int = e["hp"]
	events.append({"type": "damage", "side": "enemy", "index": idx, "amount": amount - absorbed, "crit": r["crit"], "by": by,
		"cast": cast, "element": element, "shatter": shatter > 0.0, "absorbed": absorbed})
	_say_blow(_unit(by).name, e["name"], amount - absorbed, absorbed, r["crit"])
	_absorb(ref, amount, false)
	_lose_hp(ref, amount - absorbed)
	if e["hp"] > 0:
		_after_blow(ref)
	if by < 0 and _blade and not coating.is_empty():
		_envenom(idx)
	return hp_before - int(e["hp"])


func attack(target: int) -> void:
	if not _begin_action():
		return
	target = _valid_target(target)
	focus = target
	_blade = true
	_hit_enemy(target, float(unit_numbers(-1)["str"]), 1.0, 0.0, 0.0)
	_heir_haste()
	_end_player_turn()


func skill_count() -> int:
	return (heir.cls()["skills"] as Array).size()


## The heir's class skill as the skill tree has shaped it.
func skill_info(i: int) -> Dictionary:
	return GameSkillTree.skill(heir, i)


## Skill costs grow with level, so max MP growth buys stronger casts rather than endless heals.
func skill_cost(i: int) -> int:
	return unit_skill_cost(heir, i)


static func unit_skill_cost(u: GameHeir, i: int) -> int:
	return GameCombat.ability_cost(GameSkillTree.skill(u, i), u.level)


## First skill of a kind ("damage" or "heal") in a unit's class, or -1.
static func unit_skill_of(u: GameHeir, kind: String) -> int:
	var skills: Array = GameSkillTree.skills(u)
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
	return result == "" and skill_unlocked(i) and not skill_used_up(i) and can_pay(-1, skill_cost(i))


## Whether the heir's level has opened class skill `i` (see GameSkills).
func skill_unlocked(i: int) -> bool:
	return GameSkills.unlocked(heir, i)


## A once-a-battle skill the unit has already used in this fight.
func unit_skill_used_up(by: int, i: int) -> bool:
	var s := GameSkillTree.skill(_unit(by), i)
	return GameSkills.is_once(s) and int(uses.get("%s/%s" % [ref_of(by), s.get("name", "")], 0)) > 0


func skill_used_up(i: int) -> bool:
	return unit_skill_used_up(-1, i)


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
	return GameCombat.ability_cost(unit_spell(-1, id), heir.level)


## A spell as the unit's skill tree has shaped it.
func unit_spell(by: int, id: String) -> Dictionary:
	return GameSkillTree.spell(_unit(by), id)


func unit_feat(by: int, id: String) -> Dictionary:
	return GameSkillTree.feat(_unit(by), id)


func can_cast(id: String) -> bool:
	return result == "" and id in heir.spells and can_pay(-1, spell_cost(id))


## Blood Magic turns a skill's or spell's MP cost into HP (see GameSkillTree.blood_cost).
func pays_in_hp(by: int) -> bool:
	return bool(unit_numbers(by)["blood"])


func blood_cost(by: int, mp_cost: int) -> int:
	var nums := unit_numbers(by)
	return GameSkillTree.blood_cost(_unit(by), mp_cost, int(nums["max_hp"]), int(nums["max_mp"]))


## Whether the unit can pay an ability's cost: MP, or under Blood Magic HP that leaves it standing.
func can_pay(by: int, mp_cost: int) -> bool:
	if pays_in_hp(by):
		return mp_cost <= 0 or _unit(by).hp > blood_cost(by, mp_cost)
	return _unit(by).mp >= mp_cost


## "6 MP", or "14 HP" under Blood Magic, for the buttons.
func pay_text(by: int, mp_cost: int) -> String:
	return GameMessages.text("life", "hp_cost_amount", {"amount": GameText.num(blood_cost(by, mp_cost))}) if pays_in_hp(by) and mp_cost > 0 else GameMessages.text("life", "mp_cost_amount", {"amount": GameText.num(mp_cost)})


## Takes the cost; returns false (nothing paid) when the unit cannot.
func _pay(by: int, mp_cost: int) -> bool:
	if not can_pay(by, mp_cost):
		return false
	var u := _unit(by)
	if not pays_in_hp(by):
		u.mp -= mp_cost
		return true
	var hp := blood_cost(by, mp_cost) if mp_cost > 0 else 0
	if hp > 0:
		u.hp -= hp
		events.append({"type": "hp_cost", "by": by, "amount": hp})
		_say(GameMessages.line("blood_magic_cost", {"name": u.name, "n": hp}))
	return true


func cast_spell(id: String, target: int) -> void:
	if id not in heir.spells:
		return
	if result == "" and not heir_skip and not can_cast(id):
		return
	use_ability(unit_spell(-1, id), target, spell_cost(id))


# ---------------------------------------------------------------- feats

## The feats a unit has readied, in slot order.
func unit_feats(by: int) -> Array:
	return _unit(by).equipped_feats


func feat_in_slot(slot: int) -> String:
	var list: Array = heir.equipped_feats
	return str(list[slot]) if slot >= 0 and slot < list.size() else ""


## Turns a unit must wait before using a feat again; 0 when it is ready. After any feat the user
## catches breath before the next (recovery_turns in feats.json), whatever their cooldowns.
func feat_wait(by: int, id: String) -> int:
	var r: Dictionary = feat_ready.get(ref_of(by), {})
	if r.is_empty():
		return 0
	return maxi(0, maxi(int(r.get(id, 0)), int(r.get("*", 0))) - turn)


## Why a unit cannot use a feat now ("" if it can): not readied, cooling down or catching breath,
## the wrong weapon or ground, or too hurt to pay its HP.
func feat_block(by: int, id: String) -> String:
	var u := _unit(by)
	if id not in u.equipped_feats:
		return GameMessages.text("life", "not_readied_battle")
	var wait := feat_wait(by, id)
	if wait > 0:
		var own := maxi(0, int(feat_ready.get(ref_of(by), {}).get(id, 0)) - turn)
		return "%s in %d turn%s." % ["Ready" if own >= wait else "Catching breath: ready", wait, "" if wait == 1 else "s"]
	var gear: Dictionary = _gear.get(by, {})   # the weapon in hand and the ground hold for the battle
	if not gear.has(id):
		gear[id] = GameFeats.gear_block(u, id, biomes)
		_gear[by] = gear
	if str(gear[id]) != "":
		return gear[id]
	return GameFeats.hurt_block(u, id, int(unit_numbers(by)["max_hp"]))


func can_use_feat(slot: int) -> bool:
	var id := feat_in_slot(slot)
	return result == "" and id != "" and feat_block(-1, id) == ""


## The heir's turn with the feat readied in `slot`. It costs no MP: its cooldown starts and a few
## take HP. Like an area spell, a feat aimed where it reaches no foe is not used.
func use_feat(slot: int, target: int) -> void:
	var id := feat_in_slot(slot)
	if id == "" or (result == "" and not heir_skip and feat_block(-1, id) != ""):
		return
	if not _begin_action():
		return
	var ab := unit_feat(-1, id)
	if GameCombat.aims_at_foe(ab) and aoe_hits(ab, -1, target).is_empty():
		return
	_spend_feat(-1, id)
	resolve_ability(-1, ab, target)
	_heir_haste()
	_end_player_turn()


## What a feat's use costs its user: its cooldown and the user's breath start, and any HP it takes
## is paid (it never takes the last).
func _spend_feat(by: int, id: String) -> void:
	var r: Dictionary = feat_ready.get(ref_of(by), {})
	r[id] = turn + int(unit_feat(by, id).get("cooldown", 0)) + 1
	r["*"] = turn + int(GameFeats.setting("recovery_turns")) + 1
	feat_ready[ref_of(by)] = r
	var u := _unit(by)
	var cost := mini(GameFeats.hp_cost(u, id, int(unit_numbers(by)["max_hp"])), u.hp - 1)
	if cost <= 0:
		return
	u.hp -= cost
	events.append({"type": "hp_cost", "by": by, "amount": cost})
	_say(GameMessages.line("feat_hp_cost", {"feat": GameFeats.feat_name(id), "name": u.name, "n": cost}))


## Execute and its like strike harder at a foe already badly hurt; a bane ({"undead": 1.5}) at a
## foe of that tag (see data/creatures).
func _foe_mult(ab: Dictionary, i: int) -> float:
	var m := 1.0
	var e: Dictionary = enemies[i]
	if ab.has("vs_wounded"):
		var w: Dictionary = ab["vs_wounded"]
		if float(e["hp"]) < float(e["max_hp"]) * float(w["below"]):
			m = float(w["mult"])
	if ab.has("bane"):
		var tags: Array = e.get("tags", [])
		for tag in ab["bane"]:
			if tag in tags:
				m *= float(ab["bane"][tag])
	return m


## Ground an area leaves fouled (caltrops, a mire): from the next round, for the turns its "field"
## gives, every foe that starts its turn inside takes the ability's statuses on foes again.
func _lay_field(by: int, ab: Dictionary, target: int, power: float) -> void:
	var f: Dictionary = ab["field"]
	var at := cast_point(by) if GameCombat.around_self(ab) else enemy_point(target)
	var name := str(ab.get("name", "?"))
	var radius := float(ab.get("target", {}).get("radius", 3.0))
	fields.append({"name": name, "x": at.x, "y": at.y, "radius": radius, "from": turn + 1, "until": turn + int(f.get("turns", 1)),
		"statuses": ab.get("statuses", []).filter(func(st): return str(st.get("on", "target")) == "target"),
		"source": ref_of(by), "power": power, "color": str(f.get("color", "#c8a060")), "end": str(f.get("text", {}).get("end", ""))})
	events.append({"type": "field", "name": name, "x": at.x, "y": at.y, "radius": radius})
	var lay := str(f.get("text", {}).get("lay", ""))
	if lay != "":
		_say(lay)


## Rounds a field still holds, counting the one under way.
func field_turns_left(f: Dictionary) -> int:
	return int(f["until"]) - maxi(turn, int(f["from"])) + 1


func _tread(i: int) -> void:
	var p := enemy_point(i)
	for f in fields:
		if turn >= int(f["from"]) and p.distance_to(Vector2(float(f["x"]), float(f["y"]))) <= float(f["radius"]) + 0.0001:
			for st in f["statuses"]:
				try_status(enemy_ref(i), st, str(f["source"]), float(f["power"]))


## A round ends: fields whose last round it was are gone.
func _wear_fields() -> void:
	for f in fields.duplicate():
		if int(f["until"]) <= turn:
			fields.erase(f)
			events.append({"type": "field_end", "name": f["name"]})
			if str(f["end"]) != "":
				_say(str(f["end"]))


## The party member every foe goes for while a taunt holds (-1 the heir, else the ally), or -2.
func _taunting() -> int:
	var found := -2
	for r in statuses:
		if r == "heir" or str(r).begins_with("ally"):
			for inst in statuses[r]:
				if GameCombat.status_def(inst["id"]).get("draws", false):
					if r == "heir":
						return -1
					found = _index(r) if found == -2 else mini(found, _index(r))
	return found


## The heir's turn with any ability (a class skill, a spell, or anything shaped like one): pay
## `mp_cost`, resolve it, let allies and foes act. Another resource or scaling is the caller's.
## An area aimed where it reaches no foe is not used: nothing is paid and the turn is not spent.
func use_ability(ab: Dictionary, target: int, mp_cost: int = 0, power: float = -1.0) -> void:
	if not _begin_action() or not can_pay(-1, mp_cost):
		return
	if GameCombat.aims_at_foe(ab) and aoe_hits(ab, -1, target).is_empty():
		return
	_pay(-1, mp_cost)
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
	if by < 0:
		_blade = str(ab.get("stat", "str")) != "mag"
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
	if ab.has("group") or aoe or ab.has("feat"):
		_say(GameMessages.line("casts", {"name": u.name, "ability": name}) if ab.has("group") else GameMessages.line("uses", {"name": u.name, "ability": name}))
	var src := ref_of(by)
	var key := "%s/%s" % [src, name]
	uses[key] = int(uses.get(key, 0)) + 1
	var dealt := 0
	var missed := {}   # foes that dodged every blow: what rides on the blow misses them too
	var mult := float(ab.get("mult", 0.0))
	if mult > 0.0 and not hits.is_empty():
		var el := str(ab.get("element", ""))
		var pierce := float(ab.get("pierce", 0.0))
		var cb := float(ab.get("crit_bonus", 0.0))
		var n := int(ab.get("hits", 1))
		if not aoe and n > 1:
			var t := target
			var landed := {}
			for h in n:
				if enemies[t]["hp"] <= 0:
					t = first_target()
					if t < 0:
						break
				var took := _hit_enemy(t, power, mult * _foe_mult(ab, t), pierce, cb, by, el, casts)
				if took >= 0:
					dealt += took
					landed[t] = true
				else:
					missed[t] = true
			for t2 in landed:
				missed.erase(t2)
		else:
			for h in hits:
				if enemies[h[0]]["hp"] > 0:
					var took := _hit_enemy(h[0], power, mult * float(h[1]) * _foe_mult(ab, h[0]), pierce, cb, by, el, casts)
					if took < 0:
						missed[h[0]] = true
					else:
						dealt += took
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
					if missed.has(h[0]):
						continue
					if enemies[h[0]]["hp"] > 0 and not try_status(enemy_ref(h[0]), st, src, power):
						shrugged.append(enemies[h[0]]["name"])
				if not shrugged.is_empty() and _tells_resist(st):
					var what := str(GameCombat.status_def(str(st["id"])).get("name", st["id"]))
					_say(GameMessages.line("foe_resists", {"name": shrugged[0], "what": what}) if shrugged.size() == 1 else GameMessages.line("foes_resist", {"n": shrugged.size(), "what": what}))
	if ab.has("field") and not hits.is_empty():
		_lay_field(by, ab, target, power)
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
		elif target >= 0 and target < allies.size() and allies[target].hp > 0:   # a single heal aimed at a companion
			_heal_ally(target, heal_amount(u, allies[target], ab), name, by)
		else:   # a class heal mends its user, or a companion tends the heir
			_heal_player(heal_amount(u, heir, ab), name, by)
	if ab.get("cleanse", false):
		for r in party_refs():
			cleanse(r)
	if ab.get("mana", false):
		var before := u.mp
		u.mp = mini(u.max_mp(), u.mp + int(ceil(float(u.max_mp()) * float(GameCombat.setting("mana_tap_pct")))))
		events.append({"type": "mana", "by": by, "amount": u.mp - before})
		_say(GameMessages.line("mana_drawn", {"name": u.name, "n": u.mp - before}))


## Haste on the heir: a free follow-up blow on the same foe.
func _heir_haste() -> void:
	if result != "" or living_enemies().is_empty() or not _extra_action("heir"):
		return
	var t := _valid_target(focus)
	_blade = true
	_hit_enemy(t, float(unit_numbers(-1)["str"]), 1.0, 0.0, 0.0)


# ---------------------------------------------------------------- toxins and vials

## The heir may coat the blade with a toxin from the pack while no coating is on it.
func can_coat(item: String) -> bool:
	return result == "" and not heir_skip and coating.is_empty() and item in heir.inventory and GameItems.kind_of(item) == "toxin"


## Works a toxin into the blade; it takes no turn. The heir's next blade blows (plain blows and
## skills that are not pure magic) carry its statuses. The handling may make the heir sick.
func coat_blade(item: String) -> void:
	if not can_coat(item):
		return
	events = []
	heir.inventory.erase(item)
	coating = {"item": item, "hits": int(GamePlague.setting("coat_hits"))}
	events.append({"type": "coat", "item": item})
	_say(GamePlague.text("coat", {"h": heir.name, "item": GameItems.item_name(item)}))
	var bf: Dictionary = GameItems.item_def(item)["toxin"].get("backfire", {})
	if not bf.is_empty():
		exposures.append({"disease": str(bf["disease"]), "chance": float(bf["chance"]), "source": "toxin"})


## A landed blade blow: the coating's statuses roll on the foe, and one of its hits is spent.
func _envenom(idx: int) -> void:
	var item := str(coating["item"])
	if enemies[idx]["hp"] > 0:
		for st in GamePlague.coat_statuses(item):
			try_status(enemy_ref(idx), st, "heir")
	coating["hits"] = int(coating["hits"]) - 1
	if int(coating["hits"]) <= 0:
		coating = {}
		events.append({"type": "coat_end", "item": item})
		_say(GamePlague.text("coat_spent", {"h": heir.name, "item": GameItems.item_name(item)}))


func can_throw(item: String) -> bool:
	return result == "" and item in heir.inventory and GameItems.kind_of(item) == "vial"


## Throws a plague vial: a burst that sickens and weakens every foe inside (GamePlague.vial_ability).
## Thrown where it reaches no foe, it is not thrown. The thrower risks the splash.
func throw_vial(item: String, target: int) -> void:
	if result == "" and not heir_skip and not can_throw(item):
		return
	if not _begin_action():
		return
	var ab := GamePlague.vial_ability(item)
	if aoe_hits(ab, -1, target).is_empty():
		return
	heir.inventory.erase(item)
	var v: Dictionary = GameItems.item_def(item)["vial"]
	exposures.append({"disease": str(v["disease"]), "chance": float(v.get("splash", 0.0)), "source": "vial"})
	resolve_ability(-1, ab, target)
	_heir_haste()
	_end_player_turn()


# ---------------------------------------------------------------- other heir actions

func defend() -> void:
	if not _begin_action():
		return
	defending = true
	heir.mp = mini(heir.max_mp(), heir.mp + int(ceil(float(heir.max_mp()) * float(GameRound.setting("defend_mp_pct")))))
	events.append({"type": "defend"})
	_say(GameMessages.line("brace", {"name": heir.name}))
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
	_say(GameMessages.line("hold_back", {"name": heir.name}))
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
		_say(GameMessages.line("escape_alone" if allies.is_empty() else "escape_party", {"name": heir.name}))
		return
	_say(GameMessages.line("escape_failed", {"name": heir.name}))
	_end_player_turn()


func _heal_player(amount: int, source: String, by: int = -1) -> void:
	var before := heir.hp
	heir.hp = mini(heir.max_hp(), heir.hp + amount)
	events.append({"type": "heal", "side": "player", "amount": heir.hp - before, "by": by})
	if by < 0:
		_say(GameMessages.line("restores", {"name": heir.name, "n": heir.hp - before, "source": source}))
	else:
		_say(GameMessages.line("tends", {"healer": allies[by].name, "name": heir.name, "n": heir.hp - before, "source": source}))


func _heal_ally(ai: int, amount: int, source: String, by: int = -2) -> void:
	var a: GameHeir = allies[ai]
	var before := a.hp
	a.hp = mini(a.max_hp(), a.hp + amount)
	events.append({"type": "heal", "side": "ally", "ally": ai, "amount": a.hp - before, "by": ai if by == -2 else by})
	_say(GameMessages.line("restores", {"name": a.name, "n": a.hp - before, "source": source}))


func _valid_target(t: int) -> int:
	if t >= 0 and t < enemies.size() and enemies[t]["hp"] > 0:
		return t
	return first_target()


## GameRound's way in: from here until end_round() the heir's actions only do their own part, and
## the events of the whole round collect in one list (with round, act and foes markers).
func begin_round() -> void:
	events = []
	round_on = true
	round_acted = false
	round_marks = true


## Plays the rest of the round after the heir's slot: companions (with the plans the player chose,
## by ally index; the others decide for themselves), then the foes, regeneration and the heir's
## status tick. The one exit from round mode; nothing else may leave round_on set.
func end_round(ally_plans: Dictionary) -> void:
	round_on = false
	_covered = {}
	_asked_for = {}
	reaction = {}
	if result == "":   # a successful flee already ended the fight
		round_cmds = ally_plans
		_end_player_turn()
	if reaction.is_empty():   # else answer_reaction() plays the rest of the round
		_close_round()


## The round is over: the plans, covers and asks it was given are dropped.
func _close_round() -> void:
	round_cmds = {}
	round_covers = {}
	round_asks = {}
	round_marks = false


## The player's answer to `reaction`: `by` (one of reaction.by) steps in front of the blow, or -2 lets it
## land. The waiting blow is struck, then the foes and the round go on, and may stop to ask again.
func answer_reaction(by: int) -> void:
	if reaction.is_empty():
		return
	var i := int(reaction["foe"])
	var who := int(reaction["for"])
	var choices: Array = reaction["by"]
	reaction = {}
	_asked_for[who] = true
	if by in choices:
		_covered[by] = true
		events.append({"type": "cover", "by": by, "for": who, "index": i})
		_say(GameMessages.line("steps_in_front", {"by": unit(by).name, "who": unit(who).name}))
		who = by
	_enemy_strike(i, who)
	_foe_step = 2 if _foe_step == 1 else 4   # the action that waited is done
	if _foe_phase():
		_round_tail()
	if reaction.is_empty():
		_close_round()


func _won() -> bool:
	if living_enemies().is_empty():
		result = "victory"
		_say(GameMessages.line("victory"))
		return true
	return false


func _end_player_turn() -> void:
	if round_on:
		round_acted = true   # the party and foe phase waits for end_round()
		return
	if _won():
		return
	for ai in conscious_allies():
		if allies[ai].hp <= 0:
			continue
		_ally_turn(ai)
		if _won():
			return
	if round_marks:
		events.append({"type": "foes"})
	_foe_queue = living_enemies()
	_foe_step = 0
	if _foe_phase():
		_round_tail()


## The foes still to act this round (_foe_queue), each turn in steps so one blow can wait on the player's
## answer (answer_reaction). True when every foe has acted and the round goes on; false when it stopped to
## ask, or the fight ended.
func _foe_phase() -> bool:
	while not _foe_queue.is_empty():
		var i := int(_foe_queue[0])
		if _foe_step == 0 and enemies[i]["hp"] <= 0:
			_foe_queue.pop_front()
			continue
		if not _foe_turn_steps(i):
			return false
		_foe_queue.pop_front()
		_foe_step = 0
		if heir.hp <= 0:
			result = "defeat"
			_say(GameMessages.line("fallen", {"name": heir.name}))
			return false
		if _won():
			return false
	return true


## After the foes: guards and fields wear off, the turn ends, mana returns and the heir's turn begins.
func _round_tail() -> void:
	defending = false
	braced.clear()
	if not fields.is_empty():
		_wear_fields()
	turn += 1
	var regen := maxf(0.0, float(GameData.bal("mp_regen_per_turn_pct")) + float(weather.get("mp_regen", 0.0)))
	for by in [-1] + conscious_allies():
		var nums := unit_numbers(by)
		var u := _unit(by)
		u.mp = mini(int(nums["max_mp"]), u.mp + int(ceil(float(nums["max_mp"]) * (regen + float(nums["mp_regen"])))))
	_start_heir_turn()


## The heir's statuses tick as the next turn begins, so the player sees where they stand.
func _start_heir_turn() -> void:
	heir_skip = false
	if _start_turn("heir"):
		return
	if heir.hp <= 0:
		result = "defeat"
		_say(GameMessages.line("fallen", {"name": heir.name}))
	else:
		heir_skip = true


func _ally_turn(ai: int) -> void:
	var ref := ref_of(ai)
	if not _start_turn(ref):
		return
	if round_marks:
		events.append({"type": "act", "by": ai, "manual": round_cmds.has(ai)})
	var covering := round_cmds.has(ai) and bool(round_cmds[ai].get("cover", false))   # the party flees: no bonus action either
	_ally_act(ai)
	if not covering and result == "" and not living_enemies().is_empty() and _extra_action(ref):
		_ally_act(ai)


## A companion's turn: the plan the player chose for it this round (see GameRound), else decided by
## GameTactics: mend the heir when they are badly hurt, cleanse, hold the most dangerous foe, or
## strike where it does the most. A haste bonus action is always the class's own choice.
func _ally_act(ai: int) -> void:
	var plan := {}
	if round_cmds.has(ai):
		plan = GameRound.plan_for(self, ai, round_cmds[ai])
		round_cmds.erase(ai)
		if plan.is_empty():   # no longer possible at its turn: the class decides
			_say(GameMessages.line("improvises", {"name": allies[ai].name}))
			if round_marks:
				events.append({"type": "act", "by": ai, "manual": false, "fallback": true})
	if plan.is_empty():
		plan = GameTactics.choose(self, ai)
	_ally_do(ai, plan)


func _ally_do(ai: int, plan: Dictionary) -> void:
	var a: GameHeir = allies[ai]
	match str(plan.get("act", "attack")):
		"ability":
			_pay(ai, int(plan.get("mp", plan["cost"])))
			if str(plan.get("feat", "")) != "":
				_spend_feat(ai, str(plan["feat"]))
			resolve_ability(ai, plan["ab"], int(plan["target"]))
		"defend":
			braced[ref_of(ai)] = true
			var mp_pct := float(GameRound.setting("defend_mp_pct"))
			a.mp = mini(a.max_mp(), a.mp + int(ceil(float(a.max_mp()) * mp_pct)))
			events.append({"type": "defend", "by": ai})
			_say(GameMessages.line("brace", {"name": a.name}))
		"potion":
			if heir.potions > 0:   # the house's stock, shared; the plan was checked just before
				heir.potions -= 1
				var amt := int(round(float(a.max_hp()) * float(GameData.bal("potion_heal_pct")) * (1.0 + a.trait_total("healing_power"))))
				_heal_ally(ai, amt, "Potion")
		"pass":
			_say(str(plan.get("text", GameMessages.line("hold_back", {"name": a.name}))))
		_:
			_hit_enemy(_valid_target(int(plan.get("target", focus))), float(unit_numbers(ai)["str"]), 1.0, 0.0, 0.0, ai)


## Who an enemy goes for: whoever is taunting, else the heir or (less often) a companion still
## standing. -1 = the heir.
func _enemy_target() -> int:
	var drawn := _taunting()
	if drawn > -2:
		return drawn
	var up := conscious_allies()
	if up.is_empty() or rng.randf() < float(GameData.bal("companion_heir_target_chance")):
		return -1
	return up[rng.randi() % up.size()]


## One whole foe turn (fields, statuses, the action and any bonus action), as the foes' phase plays it.
func _enemy_turn(i: int) -> void:
	_foe_step = 0
	_foe_turn_steps(i)
	_foe_step = 0


## One foe's turn in steps, so it can stop and pick up again: 0 the turn begins (fields, statuses), 1 the
## action, 2 whether a bonus action comes, 3 the bonus action, 4 done. False when a blow stopped to wait
## on the player's answer; answer_reaction() strikes it and moves _foe_step on.
func _foe_turn_steps(i: int) -> bool:
	var ref := enemy_ref(i)
	if _foe_step == 0:
		if not fields.is_empty():
			_tread(i)
		_foe_step = 1 if _start_turn(ref) else 4
	if _foe_step == 1:
		if not _enemy_act(i):
			return false
		_foe_step = 2
	if _foe_step == 2:
		_foe_step = 3 if result == "" and heir.hp > 0 and _extra_action(ref) else 4
	if _foe_step == 3:
		if not _enemy_act(i):
			return false
		_foe_step = 4
	return true


## A foe's action: it picks whom to strike, and a standing cover may step in. When the player can be
## asked to cover that member (round_asks), the blow waits in `reaction` and this returns false; else
## it strikes and returns true. Asking draws no dice, so a fight with nobody to ask plays as before.
func _enemy_act(i: int) -> bool:
	var who := _cover_for(i, _enemy_target())
	var can := _askable_for(who)
	if not can.is_empty():
		reaction = {"foe": i, "for": who, "by": can}
		return false
	_enemy_strike(i, who)
	return true


func _enemy_strike(i: int, who: int) -> void:
	if who >= 0:
		_enemy_hit_ally(i, who)
	else:
		_enemy_hit_heir(i)


func _enemy_hit_heir(i: int) -> void:
	var e: Dictionary = enemies[i]
	var me := unit_numbers(-1)
	if not bool(me["no_dodge"]) and rng.randf() < clampf(float(me["dodge"]) + float(weather.get("dodge", 0.0)) + status_mod("heir", "dodge"), 0.0, 0.6):
		events.append({"type": "miss", "side": "player", "index": i})
		_say(GameMessages.line("foe_missed", {"foe": e["name"], "name": heir.name}))
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - float(me["def"]) * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(heir.trait_total("fire_resistance"), 0.0, 0.8)
	if defending:
		dmg *= 0.5
	dmg *= _dealt_mult(enemy_ref(i)) * _taken_mult("heir") * (1.0 + _shatter("heir")) * float(me["taken"])
	var amount := maxi(1, int(round(dmg)))
	var absorbed := mini(amount, _ward("heir"))
	absorbed += _mind_over_matter(-1, amount - absorbed)
	events.append({"type": "damage", "side": "player", "index": i, "amount": amount - absorbed, "crit": false, "absorbed": absorbed})
	_say_blow(e["name"], heir.name, amount - absorbed, absorbed, false)
	_absorb("heir", amount, false)
	_lose_hp("heir", amount - absorbed)
	if heir.hp > 0:
		_after_blow("heir")
		_inflict(i, "heir")


## A standing cover (GameRound.set_cover): when a foe swings at a member below cover_below of their
## health, the member covering them takes the blow instead, once a round. It draws no dice, so a fight
## with no cover set plays exactly as before.
func _cover_for(i: int, who: int) -> int:
	if round_covers.is_empty():
		return who
	var ref := ref_of(who)
	if not round_covers.has(ref):
		return who
	var by: int = int(round_covers[ref])
	if by == who or _covered.has(by) or unit(by).hp <= 0 or (by >= 0 and by not in conscious_allies()):
		return who
	if not _below_cover(who):
		return who
	_covered[by] = true
	events.append({"type": "cover", "by": by, "for": who, "index": i})
	_say(GameMessages.line("steps_in_front", {"by": unit(by).name, "who": unit(who).name}))
	return by


## Whether a member is hurt enough to be covered: below cover_below of their health.
func _below_cover(who: int) -> bool:
	return float(unit(who).hp) / maxf(1.0, float(unit_numbers(who)["max_hp"])) < float(GameRound.setting("cover_below"))


## Members the player may be asked to step in front of a blow aimed at `who`: on manual control this round
## (round_asks), standing, not `who`, and not yet stepped in. Only while `who` is below cover_below and has
## not been asked about this round. [] when there is nothing to ask.
func _askable_for(who: int) -> Array:
	var out: Array = []
	if round_asks.is_empty() or _asked_for.has(who) or not _below_cover(who):
		return out
	for by in round_asks:
		var m := int(by)
		if m == who or _covered.has(m) or unit(m).hp <= 0 or (m >= 0 and m not in conscious_allies()):
			continue
		out.append(m)
	return out


func _enemy_hit_ally(i: int, ai: int) -> void:
	var e: Dictionary = enemies[i]
	var a: GameHeir = allies[ai]
	var ref := ref_of(ai)
	var nums := unit_numbers(ai)
	if not bool(nums["no_dodge"]) and rng.randf() < clampf(float(nums["dodge"]) + float(weather.get("dodge", 0.0)) + status_mod(ref, "dodge"), 0.0, 0.6):
		events.append({"type": "miss", "side": "ally", "index": i, "ally": ai})
		_say(GameMessages.line("foe_missed", {"foe": e["name"], "name": a.name}))
		return
	var dmg: float = maxf(1.0, float(e["atk"]) * rng.randf_range(0.85, 1.15) - float(nums["def"]) * 0.6)
	if e["element"] == "fire":
		dmg *= 1.0 - clampf(a.trait_total("fire_resistance"), 0.0, 0.8)
	dmg *= _dealt_mult(enemy_ref(i)) * _taken_mult(ref) * (1.0 + _shatter(ref)) * float(nums["taken"])
	if braced.has(ref):
		dmg *= float(GameRound.setting("brace_taken"))
	var amount := maxi(1, int(round(dmg)))
	var absorbed := mini(amount, _ward(ref))
	absorbed += _mind_over_matter(ai, amount - absorbed)
	events.append({"type": "damage", "side": "ally", "index": i, "ally": ai, "amount": amount - absorbed, "crit": false, "absorbed": absorbed})
	_say_blow(e["name"], a.name, amount - absorbed, absorbed, false)
	_absorb(ref, amount, false)
	_lose_hp(ref, amount - absorbed)
	if a.hp > 0:
		_after_blow(ref)
		_inflict(i, ref)


## Mind over Matter: part of a blow the wards left is paid from the unit's mana, each MP covering
## hp_per_mp HP. Returns the HP taken that way (it counts as absorbed, so _absorb leaves it to the
## wards first).
func _mind_over_matter(by: int, n: int) -> int:
	var nums := unit_numbers(by)
	var share := float(nums["mom"])
	if share <= 0.0 or n <= 0:
		return 0
	var u := _unit(by)
	var per := maxf(1.0, float(nums["mom_per_mp"]))
	var want := int(round(float(n) * share))
	var mp := mini(u.mp, int(ceil(float(want) / per)))
	var take := mini(want, int(floor(float(mp) * per)))
	if mp > 0 and take > 0:
		u.mp -= mp
		events.append({"type": "mana", "by": by, "amount": -mp})
		_say(GameMessages.line("mana_blow", {"name": u.name, "n": take}))
		return take
	return 0


## A creature's own statuses (a fire imp's burn...) on a unit it just struck.
func _inflict(i: int, target_ref: String) -> void:
	for entry in GameCombat.creature_def(str(enemies[i]["id"])).get("inflicts", []):
		try_status(target_ref, entry, enemy_ref(i), float(enemies[i]["atk"]))


# ---------------------------------------------------------------- estimates (for tactics and the UI)

## A unit's fighting numbers, which hold for the whole battle (worked out again only if its level
## changes): power by stat (each readied feat's under "feat:<id>"), crit and dodge chance, defense,
## max HP. Working them out walks every trait and item, so blows and tactics read them from here.
func unit_numbers(by: int) -> Dictionary:
	var u := _unit(by)
	var c: Dictionary = _nums.get(by, {})
	if c.is_empty() or int(c["level"]) != u.level or c["unit"] != u:
		var atk := u.attack_power()
		var mag := u.magic_power()
		var glass := GameSkillTree.rule(u, "glass")
		var no_dodge := GameSkillTree.has_rule(u, "no_dodge")
		c = {"unit": u, "level": u.level, "str": atk, "mag": mag, "both": (atk + mag) * 0.6, "crit": u.crit_chance(),
			"dodge": 0.0 if no_dodge else u.dodge_chance(), "def": u.defense(), "max_hp": u.max_hp(), "max_mp": u.max_mp(),
			"no_dodge": no_dodge, "blood": GameSkillTree.has_rule(u, "blood_magic"),
			"crit_mult": float(GameSkillTree.rule(u, "crit_mult").get("mult", 1.75)) + u.trait_total("crit_damage"),
			"wrath": float(GameSkillTree.rule(u, "wrath").get("max", 0.0)),
			"first_strike": float(GameSkillTree.rule(u, "first_strike").get("bonus", 0.0)),
			"breath": float(GameSkillTree.rule(u, "dragon_breath").get("mult", 0.0)), "dealt": 1.0 + float(glass.get("dealt", 0.0)),
			"taken": 1.0 + float(glass.get("taken", 0.0)), "mom": float(GameSkillTree.rule(u, "mind_over_matter").get("share", 0.0)),
			"mom_per_mp": float(GameSkillTree.rule(u, "mind_over_matter").get("hp_per_mp", 1.0)),
			"mp_regen": u.trait_total("mp_regen"),
			"resist": clampf(u.trait_total("resist"), 0.0, 0.9)}
		if not u.equipped_feats.is_empty():
			var fn := GameFeats.numbers(u)
			for id in u.equipped_feats:
				c["feat:" + str(id)] = GameFeats.power_with(fn, str(id))
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
	var base := (1.0 + crit * (float(nums["crit_mult"]) - 1.0)) * float(n) * (_rule_dealt(ref_of(by)) if calm else _dealt_mult(ref_of(by)))
	var out: Array = []
	for h in hits:
		var i: int = h[0]
		if i < 0:
			continue
		var e: Dictionary = enemies[i]
		var dmg := maxf(1.0, power * mult * float(h[1]) * _foe_mult(ab, i) - float(e["def"]) * (1.0 - pierce) * 0.5) * base * (1.0 - foe_dodge(i))
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
		return maxf(1.0, float(e["atk"]) - float(me["def"]) * 0.6) * float(me["taken"]) * (1.0 - clampf(float(me["dodge"]), 0.0, 0.6))
	var ref := enemy_ref(i)
	if is_held(ref):
		return 0.0
	var dmg := maxf(1.0, float(e["atk"]) - float(me["def"]) * 0.6) * _dealt_mult(ref) * _taken_mult("heir") * float(me["taken"])
	for inst in status_list(ref):
		match str(GameCombat.status_def(inst["id"]).get("skip", "")):
			"chance":
				dmg *= 1.0 - clampf(float(inst["amount"]), 0.0, 1.0)
			"alternate":
				dmg *= 0.5
	return dmg * (1.0 - (0.0 if bool(me["no_dodge"]) else clampf(float(me["dodge"]) + status_mod("heir", "dodge"), 0.0, 0.6)))
