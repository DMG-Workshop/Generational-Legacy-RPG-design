## An individual character in the bloodline
##
## Every heir is born, lives, and dies across 999 generations.
## They inherit traits, acquire skills, and shape the family's destiny.

extends Node

class_name Heir

## Basic info
var name: String = ""
var generation: int = 0
var birth_year: int = 0

## Family
var mother: Heir = null
var father: Heir = null
var spouse: Heir = null
var children: Array[Heir] = []

## Identity
var class_id: String = ""
var job_id: String = ""
var calling_id: String = ""

## Traits (array of trait IDs)
var traits: Array[String] = []

## Stats (will be computed from traits, class, and job)
var stats: Dictionary = {
	"strength": 10,
	"dexterity": 10,
	"constitution": 10,
	"intelligence": 10,
	"wisdom": 10,
	"charisma": 10,
	"max_hp": 100,
	"max_mp": 50,
}

## Reputation with factions
var faction_reputation: Dictionary = {}

## Wealth and possessions
var wealth: int = 0  # Legacy field for simple wealth tracking
var wallet: Wallet = Wallet.new()  # Main currency system
var gem_pouch: GemPouch = GemPouch.new()  # Gems collection
var equipment: Array[String] = []
var heirlooms: Array[String] = []
var inventory: Array = []  # Items carried

## Status
var is_alive: bool = true
var death_year: int = -1
var death_cause: String = ""

## Fate
var fate_value: float = 0.15  # 1% to 30%, will be rolled at birth
var fate_tier: String = "Uncertain"  # Charmed, Steady, Uncertain, Ill-Starred


## Roll Fate Value at birth
## Fate is the hidden probability of a major failure over this heir's lifetime
func roll_fate(
	base_roll: float = 0.15,
	trait_modifiers: float = 0.0,
	parent_failure: bool = false,
	era_difficulty: float = 0.0
) -> void:
	var final_fate = base_roll + trait_modifiers + era_difficulty
	if parent_failure:
		final_fate += 0.05

	fate_value = clamp(final_fate, 0.01, 0.30)

	# Determine the perception tier
	if fate_value <= 0.05:
		fate_tier = "Charmed"
	elif fate_value <= 0.12:
		fate_tier = "Steady"
	elif fate_value <= 0.20:
		fate_tier = "Uncertain"
	else:
		fate_tier = "Ill-Starred"


## Add a trait to this heir
func add_trait(trait_id: String) -> void:
	if trait_id not in traits:
		traits.append(trait_id)


## Check if this heir has a trait
func has_trait(trait_id: String) -> bool:
	return trait_id in traits


## Remove a trait from this heir
func remove_trait(trait_id: String) -> void:
	traits.erase(trait_id)


## Get a display string for this heir
func to_string() -> String:
	return "%s (Gen %d, %s)" % [name, generation, class_id]
