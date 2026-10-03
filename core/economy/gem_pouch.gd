## Gem Pouch: container for gems with inventory management
##
## Tracks gems, calculates total value, supports trading

extends Resource

class_name GemPouch


var gems: Array[Gem] = []


func _init() -> void:
	gems = []


## Add a gem
func add_gem(gem: Gem) -> void:
	gems.append(gem)


## Remove a gem by index
func remove_gem(index: int) -> bool:
	if index < 0 or index >= gems.size():
		return false

	gems.remove_at(index)
	return true


## Get total value of all gems as Currency
func get_total_value() -> Currency:
	var total_gp = 0
	for gem in gems:
		total_gp += gem.get_value_gp()

	return Currency.new(0, total_gp, 0, 0)


## Get total value in gold pieces
func get_total_value_gp() -> int:
	var total = 0
	for gem in gems:
		total += gem.get_value_gp()
	return total


## Get gem count
func get_count() -> int:
	return gems.size()


## Get count by type
func get_count_by_type(gem_type: String) -> int:
	var count = 0
	for gem in gems:
		if gem.gem_type.to_lower() == gem_type.to_lower():
			count += 1
	return count


## Get gems of specific type
func get_gems_by_type(gem_type: String) -> Array[Gem]:
	var result: Array[Gem] = []
	for gem in gems:
		if gem.gem_type.to_lower() == gem_type.to_lower():
			result.append(gem)
	return result


## Get gems by rarity
func get_gems_by_rarity(rarity: int) -> Array[Gem]:
	var result: Array[Gem] = []
	for gem in gems:
		if gem.rarity == rarity:
			result.append(gem)
	return result


## Get gems by condition
func get_gems_by_condition(condition: int) -> Array[Gem]:
	var result: Array[Gem] = []
	for gem in gems:
		if gem.condition == condition:
			result.append(gem)
	return result


## Get most valuable gems
func get_top_gems(count: int = 5) -> Array[Gem]:
	var sorted_gems = gems.duplicate()
	sorted_gems.sort_custom(func(a, b): return a.get_value_gp() > b.get_value_gp())

	return sorted_gems.slice(0, mini(count, sorted_gems.size()))


## Get average gem value
func get_average_value_gp() -> int:
	if gems.is_empty():
		return 0
	return get_total_value_gp() / gems.size()


## Find gem by type and take it
func take_gem_of_type(gem_type: String) -> Gem:
	for i in range(gems.size()):
		if gems[i].gem_type.to_lower() == gem_type.to_lower():
			var gem = gems[i]
			gems.remove_at(i)
			return gem

	return null


## Clear all gems
func clear() -> void:
	gems.clear()


## Get gems suitable for sale (worth at least 10 gp)
func get_sellable_gems() -> Array[Gem]:
	var result: Array[Gem] = []
	for gem in gems:
		if gem.get_value_gp() >= 10:
			result.append(gem)
	return result


## Get valuable gems (worth at least 100 gp)
func get_valuable_gems() -> Array[Gem]:
	var result: Array[Gem] = []
	for gem in gems:
		if gem.is_valuable():
			result.append(gem)
	return result


## Get gem statistics
func get_stats() -> Dictionary:
	var stats = {
		"total_gems": gems.size(),
		"total_value_gp": get_total_value_gp(),
		"average_value_gp": get_average_value_gp(),
		"valuable_count": get_valuable_gems().size(),
		"by_type": {},
		"by_rarity": {},
		"by_condition": {}
	}

	# Count by type
	for gem in gems:
		if not stats["by_type"].has(gem.gem_type):
			stats["by_type"][gem.gem_type] = 0
		stats["by_type"][gem.gem_type] += 1

	# Count by rarity
	for rarity in range(Gem.Rarity.LEGENDARY + 1):
		stats["by_rarity"][Gem.new("", 0, rarity).get_rarity_name()] = get_gems_by_rarity(rarity).size()

	# Count by condition
	for condition in range(Gem.Condition.DAMAGED + 1):
		stats["by_condition"][Gem.new("", condition).get_condition_name()] = get_gems_by_condition(condition).size()

	return stats


## Get display string
func to_string() -> String:
	if gems.is_empty():
		return "Empty"

	return "%d gems worth %dgp" % [gems.size(), get_total_value_gp()]


## List all gems
func list_gems() -> Array[String]:
	var result: Array[String] = []
	for gem in gems:
		result.append(gem.to_string())
	return result
