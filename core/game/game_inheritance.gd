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
		var def := GameData.trait_def(id)
		var muts: Array = def.get("mutations", [])
		var chance := float(def.get("mutation_chance", GameData.bal("mutation_chance")))
		if muts.size() > 0 and rng.randf() < chance:
			var target := _weighted_pick(muts, rng)
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

	if rng.randf() < float(GameData.bal("spontaneous_divine_chance")):
		var gods := GameData.traits_in(["divine"])
		if not gods.is_empty():
			var g: String = gods[rng.randi() % gods.size()]
			if g not in expressed:
				expressed.append(g)
				events.append("The heavens mark this child at birth: %s!" % GameData.trait_name(g))

	_resolve_conflicts(expressed, dormant, events)
	_cap_traits(expressed, dormant)
	dormant = dormant.filter(func(d): return d not in expressed)
	return {"traits": expressed, "dormant": dormant, "events": events}


## Picks a mutation target; traits with a low "mutation_weight" (the harmful ones) come up less often.
static func _weighted_pick(ids: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in ids:
		total += float(GameData.trait_def(id).get("mutation_weight", 1.0))
	var roll := rng.randf() * total
	for id in ids:
		roll -= float(GameData.trait_def(id).get("mutation_weight", 1.0))
		if roll < 0.0:
			return id
	return ids[ids.size() - 1]


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
		# Divine traits are never pushed into dormancy by the cap.
		var i := expressed.size() - 1
		while i > 0 and GameData.trait_def(expressed[i]).get("category", "") == "divine":
			i -= 1
		var id = expressed[i]
		expressed.remove_at(i)
		if id not in dormant:
			dormant.append(id)
