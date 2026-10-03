## Trait inheritance, dormancy, mutation chains and conflicts. Static + RNG-driven (deterministic).
class_name GameInheritance
extends RefCounted


static func random_name(rng: RandomNumberGenerator) -> String:
	var given: Array = GameData.names["given"]
	return given[rng.randi() % given.size()]


## Roll a child's traits from the given parents. Returns {"traits": [], "dormant": [], "events": []}.
static func inherit(parents: Array, rng: RandomNumberGenerator, penalty: float = 1.0) -> Dictionary:
	var events: Array = []
	var expressed: Array = []
	var dormant: Array = []
	for p in parents:
		var carried: Array = []
		for id in p.traits:
			carried.append([id, true])
		for id in p.dormant:
			carried.append([id, false])
		for entry in carried:
			var id: String = entry[0]
			var parent_expressed: bool = entry[1]
			var def := GameData.trait_def(id)
			if rng.randf() >= float(def["inherit_chance"]) * penalty:
				continue
			var shows: bool
			if parent_expressed:
				shows = rng.randf() >= float(def.get("dormant_chance", 0.0))
			else:
				shows = rng.randf() < float(GameData.bal("dormant_express_chance"))
				if shows:
					events.append("%s skipped a generation and resurfaced." % def["name"])
			if shows:
				if id not in expressed:
					expressed.append(id)
			elif id not in dormant:
				dormant.append(id)

	# Mutation chains: a mutated trait may itself mutate in later generations.
	var mutated: Array = []
	for id in expressed:
		var muts: Array = GameData.trait_def(id).get("mutations", [])
		if muts.size() > 0 and rng.randf() < float(GameData.bal("mutation_chance")):
			var target: String = muts[rng.randi() % muts.size()]
			events.append("%s mutated into %s!" % [GameData.trait_name(id), GameData.trait_name(target)])
			mutated.append([id, target])
	for m in mutated:
		expressed.erase(m[0])
		if m[1] not in expressed:
			expressed.append(m[1])

	if rng.randf() < float(GameData.bal("spontaneous_blessing_chance")):
		var pool := GameData.traits_in(["blessing"])
		var b: String = pool[rng.randi() % pool.size()]
		if b not in expressed:
			expressed.append(b)
			events.append("A spontaneous blessing appeared: %s." % GameData.trait_name(b))

	_resolve_conflicts(expressed, dormant, events)
	_cap_traits(expressed, dormant)
	dormant = dormant.filter(func(d): return d not in expressed)
	return {"traits": expressed, "dormant": dormant, "events": events}


static func _resolve_conflicts(expressed: Array, dormant: Array, events: Array) -> void:
	var i := 0
	while i < expressed.size():
		var id: String = expressed[i]
		var conflicts: Array = GameData.trait_def(id).get("conflicts", [])
		var removed := false
		for j in range(i):
			if expressed[j] in conflicts or id in GameData.trait_def(expressed[j]).get("conflicts", []):
				events.append("%s conflicts with %s and went dormant." % [GameData.trait_name(id), GameData.trait_name(expressed[j])])
				expressed.remove_at(i)
				if id not in dormant:
					dormant.append(id)
				removed = true
				break
		if not removed:
			i += 1


static func _cap_traits(expressed: Array, dormant: Array) -> void:
	var cap: int = int(GameData.bal("max_expressed_traits"))
	while expressed.size() > cap:
		var id = expressed.pop_back()
		if id not in dormant:
			dormant.append(id)
