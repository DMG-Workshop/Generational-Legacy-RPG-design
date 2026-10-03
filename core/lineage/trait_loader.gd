## Loads trait definitions from JSON files
##
## Reads all trait JSONs and builds the trait catalog indexed by ID

extends Node

class_name TraitLoader


## Load all traits from /data/traits/*.json
static func load_all_traits() -> Dictionary:
	var catalog: Dictionary = {}
	var traits_dir = "res://data/traits/"

	# Load each category of traits
	var categories = ["bloodline", "acquired", "curses", "blessings"]

	for category in categories:
		var file_path = traits_dir + category + ".json"
		var traits = _load_trait_file(file_path)

		for trait in traits:
			catalog[trait["id"]] = trait

	return catalog


## Load a single trait JSON file
static func _load_trait_file(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to load trait file: " + path)
		return []

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("JSON parse error in " + path + ": " + json.get_error_message())
		return []

	var data = json.data
	if data.has("traits"):
		return data["traits"]

	return []


## Get a trait by ID
static func get_trait(catalog: Dictionary, trait_id: String) -> Dictionary:
	return catalog.get(trait_id, {})


## Get all mutations for a trait
static func get_mutations(catalog: Dictionary, trait_id: String) -> Array:
	var trait = get_trait(catalog, trait_id)
	return trait.get("mutations", [])


## Check if two traits conflict
static func traits_conflict(catalog: Dictionary, trait_a: String, trait_b: String) -> bool:
	var trait = get_trait(catalog, trait_a)
	var conflicts = trait.get("conflicts", [])
	return trait_b in conflicts
