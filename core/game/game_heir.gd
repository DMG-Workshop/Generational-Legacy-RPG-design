## One member of the dynasty: stats, traits, family. Pure data + derived stats.
class_name GameHeir
extends RefCounted

const STATS := ["str", "mag", "agi", "vit"]

var id: int = 0
var name: String = ""
var surname: String = ""
var class_id: String = "warrior"
var gen: int = 1
var age: float = 16.0
var lifespan: float = 62.0
var level: int = 1
var xp: int = 0
var hp: int = 1
var mp: int = 0
var gold: int = 0
var potions: int = 0
var traits: Array = []       # expressed trait ids
var dormant: Array = []      # carried but not expressed
var fate_value: float = 0.1
var milestones_done: Array = []
var archetype: String = ""
var archetype_bonus: Dictionary = {}
var training: Dictionary = {"str": 0.0, "mag": 0.0, "agi": 0.0, "vit": 0.0}
var family_founded: bool = false
var extra_life_used: bool = false
var battles_won: int = 0
var kills: Dictionary = {}
var parent_names: Array = []
var children: Array = []     # Array[GameHeir], born to this heir
var spouse: GameHeir = null
var heirloom_bonus: float = 0.0


func full_name() -> String:
	return "%s %s" % [name, surname]


func cls() -> Dictionary:
	return GameData.classes[class_id]


## Sum of an effect stat across expressed traits.
func trait_total(stat: String) -> float:
	var total := 0.0
	for id in traits:
		for e in GameData.trait_def(id).get("effects", []):
			if e["stat"] == stat:
				total += float(e["value"])
	return total


func fate_modifier_total() -> float:
	var total := 0.0
	for id in traits:
		total += float(GameData.trait_def(id).get("fate_modifier", 0.0))
	return total


func compute_lifespan() -> float:
	var span: float = float(GameData.bal("base_lifespan"))
	var mod := 1.0
	var aging := 1.0
	for id in traits:
		for e in GameData.trait_def(id).get("effects", []):
			if e["stat"] == "lifespan_modifier":
				mod = max(mod, float(e["value"]))
			elif e["stat"] == "aging_rate":
				aging = min(aging, float(e["value"]))
	span = span * mod / aging
	span += float(archetype_bonus.get("lifespan", 0.0))
	return clampf(span, float(GameData.bal("min_lifespan")), float(GameData.bal("max_lifespan")))


func stat(s: String) -> float:
	var c := cls()
	var v: float = float(c["base"][s]) + float(c["growth"][s]) * float(level - 1)
	v = (v + training[s]) * GameData.heir_scale(gen)
	v *= 1.0 + float(archetype_bonus.get("all_stats", 0.0))
	v *= 1.0 + float(archetype_bonus.get(s, 0.0))
	return v


func max_hp() -> int:
	var c := cls()
	var v: float = float(c["base"]["hp"]) + float(c["growth"]["hp"]) * float(level - 1) + stat("vit") * 2.0
	v *= GameData.heir_scale(gen)
	v *= 1.0 + trait_total("max_hp") + float(archetype_bonus.get("hp", 0.0)) + heirloom_bonus
	return maxi(10, int(round(v)))


func max_mp() -> int:
	var c := cls()
	var v: float = float(c["base"]["mp"]) + float(c["growth"]["mp"]) * float(level - 1) + stat("mag") * 0.5
	return maxi(0, int(round(v)))


func attack_power() -> float:
	return (stat("str") * 1.6) * (1.0 + trait_total("melee_damage") + trait_total("strength") + heirloom_bonus)


func magic_power() -> float:
	var bonus := trait_total("element_power") + trait_total("divine_magic_power") + trait_total("dark_magic_power")
	return (stat("mag") * 1.6) * (1.0 + bonus + heirloom_bonus)


func defense() -> float:
	return stat("vit") * 0.8


func dodge_chance() -> float:
	return clampf(stat("agi") / (stat("agi") + 60.0) * 0.5 + trait_total("reflexes"), 0.0, 0.6)


func crit_chance() -> float:
	return clampf(0.05 + trait_total("luck") + stat("agi") / (stat("agi") + 100.0) * 0.2, 0.0, 0.6)


func xp_to_next() -> int:
	return int(float(GameData.bal("xp_base")) * pow(float(level), float(GameData.bal("xp_exponent"))))


func full_heal() -> void:
	hp = max_hp()
	mp = max_mp()


## Returns the number of levels gained.
func gain_xp(amount: int) -> int:
	xp += int(round(float(amount) * (1.0 + float(archetype_bonus.get("xp", 0.0)))))
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		hp = mini(max_hp(), hp + int(float(max_hp()) * 0.25))
		mp = mini(max_mp(), mp + int(float(max_mp()) * 0.25))
	return gained


func refresh_derived() -> void:
	lifespan = compute_lifespan()
	hp = clampi(hp, 1, max_hp())
	mp = clampi(mp, 0, max_mp())


func to_dict() -> Dictionary:
	var kids: Array = []
	for c in children:
		kids.append(c.to_dict())
	return {
		"id": id, "name": name, "surname": surname, "class_id": class_id, "gen": gen,
		"age": age, "lifespan": lifespan, "level": level, "xp": xp, "hp": hp, "mp": mp,
		"gold": gold, "potions": potions, "traits": traits, "dormant": dormant,
		"fate_value": fate_value, "milestones_done": milestones_done, "archetype": archetype,
		"archetype_bonus": archetype_bonus, "training": training, "family_founded": family_founded,
		"extra_life_used": extra_life_used, "battles_won": battles_won, "kills": kills,
		"parent_names": parent_names, "heirloom_bonus": heirloom_bonus, "children": kids,
		"spouse": spouse.to_dict() if spouse != null else null,
	}


static func from_dict(d: Dictionary) -> GameHeir:
	var h := GameHeir.new()
	h.id = int(d["id"]); h.name = d["name"]; h.surname = d["surname"]; h.class_id = d["class_id"]
	h.gen = int(d["gen"]); h.age = float(d["age"]); h.lifespan = float(d["lifespan"])
	h.level = int(d["level"]); h.xp = int(d["xp"]); h.hp = int(d["hp"]); h.mp = int(d["mp"])
	h.gold = int(d["gold"]); h.potions = int(d["potions"])
	h.traits = Array(d["traits"]); h.dormant = Array(d["dormant"])
	h.fate_value = float(d["fate_value"]); h.milestones_done = Array(d["milestones_done"])
	h.archetype = d["archetype"]; h.archetype_bonus = d["archetype_bonus"]
	h.training = d["training"]; h.family_founded = d["family_founded"]
	h.extra_life_used = d["extra_life_used"]; h.battles_won = int(d["battles_won"])
	h.kills = {}
	for k in d["kills"]:
		h.kills[k] = int(d["kills"][k])
	h.parent_names = Array(d["parent_names"])
	h.heirloom_bonus = float(d["heirloom_bonus"])
	h.lifespan = h.compute_lifespan()
	for c in d["children"]:
		h.children.append(GameHeir.from_dict(c))
	if d["spouse"] != null:
		h.spouse = GameHeir.from_dict(d["spouse"])
	return h
