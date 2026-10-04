## One member of the dynasty: stats, traits, family. Pure data + derived stats.
class_name GameHeir
extends RefCounted

const STATS := ["str", "mag", "agi", "vit"]

var id: int = 0
var name: String = ""
var surname: String = ""
var class_id: String = "warrior"
var race_id: String = "human"
var gen: int = 1
var age: float = 16.0
var hazard_age: float = 16.0   # age up to which old-age death has already been rolled
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
var equipment: Dictionary = {"weapon": "", "armor": "", "trinket": ""}   # slot -> item id
var inventory: Array = []    # item ids carried but not worn


func full_name() -> String:
	return "%s %s" % [name, surname]


func cls() -> Dictionary:
	return GameData.classes[class_id]


func race() -> Dictionary:
	return GameData.races[race_id]


func racial_traits() -> Array:
	return race().get("traits", [])


## Expressed traits plus the innate traits of the heir's race.
func all_traits() -> Array:
	return traits + racial_traits()


func adult_age() -> float:
	return float(race()["start_age"])


func family_min_age() -> float:
	return adult_age() + float(GameData.bal("family_after_years"))


func midlife_age() -> float:
	return lifespan * float(GameData.bal("midlife_fraction"))


## Sum of an effect stat across expressed traits, racial traits and equipped gear.
func trait_total(stat: String) -> float:
	var total := 0.0
	for id in all_traits():
		for e in GameData.trait_def(id).get("effects", []):
			if e["stat"] == stat:
				total += float(e["value"])
	for slot in equipment:
		if equipment[slot] != "":
			for e in GameItems.item_def(equipment[slot]).get("effects", []):
				if e["stat"] == stat:
					total += float(e["value"])
	return total


func fate_modifier_total() -> float:
	var total := 0.0
	for id in all_traits():
		total += float(GameData.trait_def(id).get("fate_modifier", 0.0))
	return total


## Expected lifespan (the median age of death). Without divine traits it is the "natural" span.
func compute_lifespan(include_divine: bool = true) -> float:
	var span: float = float(race()["lifespan"])
	var mod := 1.0
	var aging := 1.0
	for id in all_traits():
		if not include_divine and GameData.trait_def(id).get("category", "") == "divine":
			continue
		for e in GameData.trait_def(id).get("effects", []):
			if e["stat"] == "lifespan_modifier":
				mod = max(mod, float(e["value"]))
			elif e["stat"] == "aging_rate":
				aging = min(aging, float(e["value"]))
	span = span * mod / aging
	span += float(archetype_bonus.get("lifespan", 0.0))
	return clampf(span, float(GameData.bal("min_lifespan")), float(GameData.bal("max_lifespan")))


## Class base/growth plus the race's additive adjustments.
func base_of(s: String) -> float:
	return float(cls()["base"][s]) + float(race().get("base", {}).get(s, 0.0))


func growth_of(s: String) -> float:
	return float(cls()["growth"][s]) + float(race().get("growth", {}).get(s, 0.0))


func stat(s: String) -> float:
	var v: float = maxf(1.0, base_of(s) + growth_of(s) * float(level - 1))
	v = (v + training[s]) * GameData.heir_scale(gen)
	v *= 1.0 + float(archetype_bonus.get("all_stats", 0.0))
	v *= 1.0 + float(archetype_bonus.get(s, 0.0))
	return v


func max_hp() -> int:
	var v: float = base_of("hp") + growth_of("hp") * float(level - 1) + stat("vit") * 2.0
	v *= GameData.heir_scale(gen)
	v *= 1.0 + trait_total("max_hp") + float(archetype_bonus.get("hp", 0.0)) + heirloom_bonus
	return maxi(10, int(round(v)))


func max_mp() -> int:
	var v: float = base_of("mp") + growth_of("mp") * float(level - 1) + stat("mag") * 0.5
	v *= 1.0 + trait_total("max_mp")
	return maxi(0, int(round(v)))


func attack_power() -> float:
	return (stat("str") * 1.6) * (1.0 + trait_total("melee_damage") + trait_total("strength") + heirloom_bonus)


func magic_power() -> float:
	var bonus := trait_total("element_power") + trait_total("divine_magic_power") + trait_total("dark_magic_power")
	return (stat("mag") * 1.6) * (1.0 + bonus + heirloom_bonus)


func defense() -> float:
	return stat("vit") * 0.8 * maxf(0.0, 1.0 + trait_total("defense"))


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
	var cap := int(GameData.bal("level_cap"))
	if level >= cap:
		xp = 0
		return 0
	var mult := maxf(0.1, 1.0 + float(archetype_bonus.get("xp", 0.0)) + trait_total("xp_gain"))
	xp += int(round(float(amount) * mult))
	var gained := 0
	while level < cap and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		hp = mini(max_hp(), hp + int(float(max_hp()) * 0.25))
		mp = mini(max_mp(), mp + int(float(max_mp()) * 0.25))
	if level >= cap:
		xp = 0
	return gained


## Chance of dying of old age while ageing from `from_age` to `to_age`. The lifespan is the
## median age of death, not a limit: the risk is slight in middle age and climbs steeply past it.
func old_age_death_chance(from_age: float, to_age: float) -> float:
	var k := float(GameData.bal("old_age_steepness"))
	var hazard := log(2.0) * (exp(k * (to_age / lifespan - 1.0)) - exp(k * (from_age / lifespan - 1.0)))
	return 1.0 - exp(-hazard)


func refresh_derived() -> void:
	lifespan = compute_lifespan()
	hp = clampi(hp, 1, max_hp())
	mp = clampi(mp, 0, max_mp())


func to_dict() -> Dictionary:
	var kids: Array = []
	for c in children:
		kids.append(c.to_dict())
	return {
		"id": id, "name": name, "surname": surname, "class_id": class_id, "race_id": race_id, "gen": gen,
		"age": age, "hazard_age": hazard_age, "lifespan": lifespan, "level": level, "xp": xp, "hp": hp, "mp": mp,
		"gold": gold, "potions": potions, "traits": traits, "dormant": dormant,
		"fate_value": fate_value, "milestones_done": milestones_done, "archetype": archetype,
		"archetype_bonus": archetype_bonus, "training": training, "family_founded": family_founded,
		"extra_life_used": extra_life_used, "battles_won": battles_won, "kills": kills,
		"parent_names": parent_names, "heirloom_bonus": heirloom_bonus, "children": kids,
		"equipment": equipment, "inventory": inventory,
		"spouse": spouse.to_dict() if spouse != null else null,
	}


static func from_dict(d: Dictionary) -> GameHeir:
	var h := GameHeir.new()
	h.id = int(d["id"]); h.name = d["name"]; h.surname = d["surname"]; h.class_id = d["class_id"]
	h.race_id = d.get("race_id", "human")
	h.gen = int(d["gen"]); h.age = float(d["age"]); h.lifespan = float(d["lifespan"])
	h.hazard_age = float(d.get("hazard_age", h.age))
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
	h.equipment = d.get("equipment", {"weapon": "", "armor": "", "trinket": ""})
	h.inventory = Array(d.get("inventory", []))
	h.lifespan = h.compute_lifespan()
	# A save from an older, steeper XP curve can hold more XP than the next level now costs.
	while h.level < int(GameData.bal("level_cap")) and h.xp >= h.xp_to_next():
		h.xp -= h.xp_to_next()
		h.level += 1
	for c in d["children"]:
		h.children.append(GameHeir.from_dict(c))
	if d["spouse"] != null:
		h.spouse = GameHeir.from_dict(d["spouse"])
	return h
