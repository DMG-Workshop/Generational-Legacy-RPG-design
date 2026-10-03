## Legendary Name Generator: procedural names and lore for legendary items
##
## Combines thematic components to create unique legendary item identities

class_name LegendaryNameGenerator


static var ADJECTIVES: Array[String] = [
	"Eternal", "Void", "Starborn", "Crimson", "Whispered",
	"Dawn", "Shadowbane", "Lightbringer", "Dragonborn", "Soulforged",
	"Ascendant", "Twilight", "Radiant", "Obsidian", "Celestial"
]

static var NOUNS: Array[String] = [
	"Blade", "Crown", "Scepter", "Fang", "Torrent",
	"Wrath", "Nexus", "Echo", "Vigil", "Covenant",
	"Oath", "Curse", "Blessing", "Whisper", "Storm"
]

static var LOCATIONS: Array[String] = [
	"of the First Age", "of Ancestors' Halls", "of Lost Kingdoms",
	"of the Fallen Stars", "of Dragon Fire", "of the Void",
	"of Dawn's Light", "of Eternal Vigil", "of the Bloodline",
	"of Ancient Pacts", "of the Shattered Moon", "of Eternity"
]

static var LORE_THEMES: Dictionary = {
	"FIRE": {
		"verb": "forged",
		"location": "the forge fires",
		"imagery": "blazing"
	},
	"ICE": {
		"verb": "tempered",
		"location": "frozen wastes",
		"imagery": "crystalline"
	},
	"BLOOD": {
		"verb": "cursed",
		"location": "ancient bloodfields",
		"imagery": "crimson"
	},
	"LIGHT": {
		"verb": "blessed",
		"location": "celestial heights",
		"imagery": "radiant"
	},
	"VOID": {
		"verb": "born",
		"location": "the abyss",
		"imagery": "shadowed"
	}
}


static func generate_name(seed_value: int, item_type: String = "") -> String:
	if seed_value > 0:
		seed(seed_value)

	var pattern = randi() % 3

	match pattern:
		0:
			return "%s %s" % [
				ADJECTIVES[randi() % ADJECTIVES.size()],
				NOUNS[randi() % NOUNS.size()]
			]
		1:
			return "%s %s %s" % [
				ADJECTIVES[randi() % ADJECTIVES.size()],
				NOUNS[randi() % NOUNS.size()],
				LOCATIONS[randi() % LOCATIONS.size()]
			]
		_:
			return "%s of %s %s" % [
				NOUNS[randi() % NOUNS.size()],
				ADJECTIVES[randi() % ADJECTIVES.size()],
				LOCATIONS[randi() % LOCATIONS.size()]
			]


static func generate_lore(
	seed_value: int,
	defeated_enemy: String = "",
	enchantments: Array = [],
	heir_generation: int = 1
) -> String:
	if seed_value > 0:
		seed(seed_value)

	var theme_key = "LIGHT"
	if not enchantments.is_empty() and enchantments[0] is Dictionary:
		if "flavor_tags" in enchantments[0]:
			var tags = enchantments[0]["flavor_tags"]
			if not tags.is_empty():
				theme_key = tags[0]

	var theme = LORE_THEMES.get(theme_key, LORE_THEMES["LIGHT"])
	var sentences: Array[String] = []

	if not defeated_enemy.is_empty():
		sentences.append("Forged in victory over %s, this legendary weapon carries echoes of triumph." % defeated_enemy)
	else:
		sentences.append("This artifact was %s through generations of ritual and sacrifice." % theme["verb"])

	sentences.append("Its power grew with each heir, drawing strength from the bloodline's legacy.")

	var power_desc = "grants dominion over %s" % theme["imagery"]
	sentences.append("Wielded by the heir of generation %d, it %s." % [heir_generation, power_desc])

	return " ".join(sentences)


static func generate_full_description(
	seed_value: int,
	item_type: String,
	theme: String
) -> Dictionary:
	if seed_value > 0:
		seed(seed_value)

	var name = generate_name(seed_value, item_type)
	var lore = generate_lore(seed_value, "", [], 1)

	var flavor_map = {
		"FIRE": "Burns with ancestral flames, forever seeking new challenges.",
		"ICE": "Gleams with ancient frost, preserving the memory of fallen ages.",
		"BLOOD": "Thrums with generational power, bound to the bloodline.",
		"LIGHT": "Radiates with celestial blessing, guiding the worthy.",
		"VOID": "Whispers with void-touched authority, beyond mortal reckoning."
	}

	var flavor = flavor_map.get(theme, flavor_map["LIGHT"])

	return {
		"name": name,
		"lore": lore,
		"flavor_text": flavor
	}


static func get_random_location(seed_value: int) -> String:
	if seed_value > 0:
		seed(seed_value)
	return LOCATIONS[randi() % LOCATIONS.size()]


static func get_random_adjective(seed_value: int) -> String:
	if seed_value > 0:
		seed(seed_value)
	return ADJECTIVES[randi() % ADJECTIVES.size()]


static func get_random_noun(seed_value: int) -> String:
	if seed_value > 0:
		seed(seed_value)
	return NOUNS[randi() % NOUNS.size()]
