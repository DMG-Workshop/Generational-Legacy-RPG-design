## Multi-Generation Recipe: crafting items that span generations
##
## Requires multiple heirs to contribute progress over time
## RARE RARE RARE - legendary items that take a lineage to create

class_name MultiGenRecipe


## Recipe ID
var recipe_id: String = ""

## Final output item (the legendary item)
var legendary_item_id: String = ""

## Total progress needed (100)
var total_progress: int = 100

## Current progress (accumulated across generations)
var current_progress: int = 0

## How many generations have contributed
var generations_contributed: int = 0

## List of heirs who worked on this
var contributors: Array[String] = []

## The year work started
var start_year: int = 0

## Current year of work
var current_year: int = 0

## Stages of completion with milestones
var milestones: Dictionary = {
	25: "Foundation Laid",
	50: "Structure Complete",
	75: "Refinement Begun",
	100: "Legendary Item Complete"
}

## Description of the legendary item
var lore: String = ""

## Rarity tier
var rarity: int = Item.Rarity.LEGENDARY


func _init(
	p_id: String = "",
	p_output: String = "",
	p_total: int = 100
) -> void:
	recipe_id = p_id
	legendary_item_id = p_output
	total_progress = p_total


## Add progress to recipe
func add_progress(
	amount: int,
	heir_name: String,
	year: int
) -> Dictionary:  # Returns {progress_before, progress_after, milestone_reached, is_complete}
	var progress_before = current_progress
	var milestone_reached = ""

	current_progress = min(current_progress + amount, total_progress)
	current_year = year

	if heir_name not in contributors:
		contributors.append(heir_name)
		generations_contributed += 1

	# Check milestones
	for threshold in milestones:
		if progress_before < threshold and current_progress >= threshold:
			milestone_reached = milestones[threshold]

	var is_complete = current_progress >= total_progress

	return {
		"progress_before": progress_before,
		"progress_after": current_progress,
		"milestone_reached": milestone_reached,
		"is_complete": is_complete
	}


## Get progress percentage
func get_progress_percent() -> int:
	return int((float(current_progress) / total_progress) * 100)


## Get progress bar
func get_progress_bar() -> String:
	var filled = int((float(current_progress) / total_progress) * 20)
	var empty = 20 - filled
	return "[%s%s] %d%%" % ["█".repeat(filled), "░".repeat(empty), get_progress_percent()]


## Get current milestone
func get_current_milestone() -> String:
	var current_stage = "Conception"
	for threshold in milestones.keys():
		if current_progress >= threshold:
			current_stage = milestones[threshold]
	return current_stage


## Get contributors list
func get_contributors_string() -> String:
	return ", ".join(contributors)


## Check if complete
func is_complete() -> bool:
	return current_progress >= total_progress


## To string representation
func to_string() -> String:
	return "%s: %s (%d%% - %d heirs)" % [
		recipe_id,
		get_current_milestone(),
		get_progress_percent(),
		generations_contributed
	]


## Detailed description
func get_detailed_string() -> String:
	var str = "%s\n" % to_string()
	str += "Progress: %s\n" % get_progress_bar()
	str += "Generations Contributed: %d\n" % generations_contributed
	if not contributors.is_empty():
		str += "Contributors: %s\n" % get_contributors_string()
	if not lore.is_empty():
		str += "\nLore:\n%s\n" % lore
	return str
