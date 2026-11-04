## The family tree, read from the dynasty's own records: one entry per generation, each heir with
## who they were the child of, who they married, the children they had, how they died, their traits
## and the legacy echoes that came from their generation. Only what the dynasty keeps is shown: the
## founder and the latest heirs in full (GameDynasty.history), and older heirs as a count, since
## GameAges folds them into summaries. Logic only; the chronicle draws it (ui/play/chronicle_panel.gd).
class_name GameFamilyTree
extends RefCounted


## {folded: int, generations: [{gen: int, heirs: [node]}]}, oldest generation first. A node:
## {name, race_id, class_id, level, living, cause, parents, spouse, children, traits, echoes}.
## parents, children and traits are names; cause is "" for the living heir.
static func tree(d: GameDynasty) -> Dictionary:
	var by_gen := {}
	for rec in d.history:
		var g := int(rec.get("gen", 1))
		if not by_gen.has(g):
			by_gen[g] = []
		by_gen[g].append(_dead(d, rec))
	if d.heir != null and d.state == "life":
		var g := d.heir.gen
		if not by_gen.has(g):
			by_gen[g] = []
		by_gen[g].append(_living(d))
	var gens := by_gen.keys()
	gens.sort()
	var out: Array = []
	for g in gens:
		out.append({"gen": g, "heirs": by_gen[g]})
	return {"folded": d.ages.folded_heirs(), "generations": out}


static func _dead(d: GameDynasty, rec: Dictionary) -> Dictionary:
	return {
		"name": str(rec.get("name", "")),
		"race_id": str(rec.get("race_id", "human")),
		"class_id": str(rec.get("class_id", "warrior")),
		"level": int(rec.get("level", 1)),
		"living": false,
		"cause": str(rec.get("cause", "")),
		"parents": _names(rec.get("parents", [])),
		"spouse": str(rec.get("spouse", "")),
		"children": _names(rec.get("children", [])),
		"traits": _names(rec.get("traits", [])),
		"echoes": _echoes(d, int(rec.get("gen", 1))),
	}


static func _living(d: GameDynasty) -> Dictionary:
	var h := d.heir
	var traits: Array = []
	for t in h.traits:
		traits.append(GameData.trait_name(t))
	var children: Array = []
	for c in h.children:
		children.append(c.name)
	return {
		"name": h.full_name(),
		"race_id": h.race_id,
		"class_id": h.class_id,
		"level": h.level,
		"living": true,
		"cause": "",
		"parents": _names(h.parent_names),
		"spouse": h.spouse.name if h.spouse != null else "",
		"children": children,
		"traits": traits,
		"echoes": _echoes(d, h.gen),
	}


static func _echoes(d: GameDynasty, g: int) -> Array:
	var out: Array = []
	for e in d.echoes:
		if int(e.get("gen", -1)) == g:
			out.append(str(e.get("text", "")))
	return out


## Saved names, checked: only strings survive, so a damaged save shows fewer names, never a crash.
static func _names(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_STRING:
			out.append(v)
	return out
