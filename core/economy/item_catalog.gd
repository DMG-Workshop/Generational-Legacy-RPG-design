## Item Catalog: database of all predefined items
##
## Weapons, armor, consumables, materials

class_name ItemCatalog


## Predefined weapons
static var WEAPONS: Dictionary = {
	"iron_sword": {
		"name": "Iron Sword",
		"strength_bonus": 3,
		"value": Currency.new(0, 25, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
	"steel_sword": {
		"name": "Steel Sword",
		"strength_bonus": 5,
		"value": Currency.new(0, 50, 0, 0),
		"rarity": Item.Rarity.UNCOMMON
	},
	"enchanted_blade": {
		"name": "Enchanted Blade",
		"strength_bonus": 8,
		"value": Currency.new(0, 150, 0, 0),
		"rarity": Item.Rarity.RARE
	},
	"dragon_slayer": {
		"name": "Dragon Slayer",
		"strength_bonus": 12,
		"value": Currency.new(1, 0, 0, 0),
		"rarity": Item.Rarity.LEGENDARY
	},
	"wooden_bow": {
		"name": "Wooden Bow",
		"dexterity_bonus": 2,
		"value": Currency.new(0, 15, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
	"longbow": {
		"name": "Longbow",
		"dexterity_bonus": 4,
		"value": Currency.new(0, 40, 0, 0),
		"rarity": Item.Rarity.UNCOMMON
	},
}


## Predefined armor
static var ARMOR: Dictionary = {
	"leather_armor": {
		"name": "Leather Armor",
		"defense_bonus": 2,
		"value": Currency.new(0, 30, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
	"chain_mail": {
		"name": "Chain Mail",
		"defense_bonus": 4,
		"value": Currency.new(0, 75, 0, 0),
		"rarity": Item.Rarity.UNCOMMON
	},
	"plate_armor": {
		"name": "Plate Armor",
		"defense_bonus": 6,
		"value": Currency.new(0, 150, 0, 0),
		"rarity": Item.Rarity.RARE
	},
	"dragon_scale": {
		"name": "Dragon Scale Armor",
		"defense_bonus": 10,
		"value": Currency.new(2, 0, 0, 0),
		"rarity": Item.Rarity.LEGENDARY
	},
	"iron_helm": {
		"name": "Iron Helm",
		"defense_bonus": 1,
		"value": Currency.new(0, 20, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
}


## Predefined consumables
static var CONSUMABLES: Dictionary = {
	"health_potion": {
		"name": "Health Potion",
		"effect": Consumable.EffectType.HEAL,
		"amount": 25,
		"value": Currency.new(0, 5, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
	"greater_health_potion": {
		"name": "Greater Health Potion",
		"effect": Consumable.EffectType.HEAL,
		"amount": 50,
		"value": Currency.new(0, 15, 0, 0),
		"rarity": Item.Rarity.UNCOMMON
	},
	"mana_potion": {
		"name": "Mana Potion",
		"effect": Consumable.EffectType.MANA_RESTORE,
		"amount": 20,
		"value": Currency.new(0, 5, 0, 0),
		"rarity": Item.Rarity.COMMON
	},
	"antidote": {
		"name": "Antidote",
		"effect": Consumable.EffectType.CURE,
		"value": Currency.new(0, 10, 0, 0),
		"rarity": Item.Rarity.UNCOMMON,
		"cures": ["poison"]
	},
}


## Predefined crafting materials
static var MATERIALS: Dictionary = {
	"copper_ore": {
		"name": "Copper Ore",
		"type": "ore",
		"rarity": Item.Rarity.COMMON,
		"value": Currency.new(0, 2, 0, 0)
	},
	"iron_ore": {
		"name": "Iron Ore",
		"type": "ore",
		"rarity": Item.Rarity.UNCOMMON,
		"value": Currency.new(0, 5, 0, 0)
	},
	"mithril_ore": {
		"name": "Mithril Ore",
		"type": "ore",
		"rarity": Item.Rarity.RARE,
		"value": Currency.new(0, 25, 0, 0)
	},
	"pine_log": {
		"name": "Pine Log",
		"type": "wood",
		"rarity": Item.Rarity.COMMON,
		"value": Currency.new(0, 2, 0, 0)
	},
	"oak_log": {
		"name": "Oak Log",
		"type": "wood",
		"rarity": Item.Rarity.UNCOMMON,
		"value": Currency.new(0, 5, 0, 0)
	},
	"moonpetal_herb": {
		"name": "Moonpetal Herb",
		"type": "herb",
		"rarity": Item.Rarity.UNCOMMON,
		"value": Currency.new(0, 8, 0, 0)
	},
	"dragonroot": {
		"name": "Dragonroot",
		"type": "herb",
		"rarity": Item.Rarity.RARE,
		"value": Currency.new(0, 30, 0, 0)
	},
}


## Create weapon from catalog
static func create_weapon(weapon_id: String) -> Equipment:
	var data = WEAPONS.get(weapon_id)
	if not data:
		return null

	var weapon = Equipment.new(weapon_id, data["name"], Equipment.EquipmentSlot.MAIN_HAND, data["value"])
	weapon.rarity = data["rarity"]
	weapon.item_type = Item.ItemType.WEAPON

	if "strength_bonus" in data:
		weapon.add_stat_bonus("strength", data["strength_bonus"])
	if "dexterity_bonus" in data:
		weapon.add_stat_bonus("dexterity", data["dexterity_bonus"])

	return weapon


## Create armor from catalog
static func create_armor(armor_id: String) -> Equipment:
	var data = ARMOR.get(armor_id)
	if not data:
		return null

	var armor = Equipment.new(armor_id, data["name"], Equipment.EquipmentSlot.CHEST, data["value"])
	armor.rarity = data["rarity"]
	armor.item_type = Item.ItemType.ARMOR

	if "defense_bonus" in data:
		armor.add_stat_bonus("constitution", data["defense_bonus"])

	return armor


## Create consumable from catalog
static func create_consumable(consumable_id: String) -> Consumable:
	var data = CONSUMABLES.get(consumable_id)
	if not data:
		return null

	var consumable = Consumable.new(consumable_id, data["name"], data["effect"], data["value"])
	consumable.rarity = data["rarity"]

	if "amount" in data:
		consumable.effect_amount = data["amount"]
	if "cures" in data:
		consumable.cures = data["cures"]

	return consumable


## Create material from catalog
static func create_material(material_id: String) -> CraftingMaterial:
	var data = MATERIALS.get(material_id)
	if not data:
		return null

	var material = CraftingMaterial.new(material_id, data["name"], data["type"], data["value"])
	material.rarity = data["rarity"]

	return material


## Get all items of type
static func get_weapons() -> Array[String]:
	return WEAPONS.keys()


static func get_armor() -> Array[String]:
	return ARMOR.keys()


static func get_consumables() -> Array[String]:
	return CONSUMABLES.keys()


static func get_materials() -> Array[String]:
	return MATERIALS.keys()


## Get random item of type
static func get_random_weapon() -> Equipment:
	var weapons = get_weapons()
	return create_weapon(weapons[randi() % weapons.size()])


static func get_random_armor() -> Equipment:
	var armor_list = get_armor()
	return create_armor(armor_list[randi() % armor_list.size()])


static func get_random_consumable() -> Consumable:
	var consumables = get_consumables()
	return create_consumable(consumables[randi() % consumables.size()])


static func get_random_material() -> CraftingMaterial:
	var materials = get_materials()
	return create_material(materials[randi() % materials.size()])
