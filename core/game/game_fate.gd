## Fate Value, milestone failure checks, severity and heir archetypes.
class_name GameFate
extends RefCounted

const SEVERITIES := ["minor", "moderate", "major", "critical"]

## Archetypes a failure can create in the next heir: the bonus each gives (names and lines in the catalog).
const ARCHETYPES := {
	"restorer": {"bonus": {"vit": 0.1}, "gold": 60},
	"rebel": {"bonus": {"agi": 0.1, "str": 0.05}},
	"inheritor": {"bonus": {"xp": 0.25}},
	"survivor": {"bonus": {"hp": 0.15, "vit": 0.05}},
	"redeemer": {"bonus": {"mag": 0.1}, "purge_curse": true},
	"successor": {"bonus": {"all_stats": 0.05}},
}

## The milestones an heir can pass (their names are in the catalog: milestone_label).
const MILESTONE_IDS := ["coming_of_age", "first_quest", "family_founded", "midlife", "elder_years"]

## Fate Values and echo strengths are kept on a 0.0001 grid. Saved JSON prints the nearest short
## decimal, which can parse to a neighbouring double, so loading must snap again (see from_dict).
const STEP := 0.0001


static func roll_fate_value(rng: RandomNumberGenerator, modifier: float) -> float:
	var v := rng.randf_range(float(GameData.bal("fate_min")), float(GameData.bal("fate_max"))) + modifier
	return snappedf(clampf(v, float(GameData.bal("fate_min")), float(GameData.bal("fate_max"))), STEP)


## Fate Value is a lifetime failure chance spread over 5 milestones.
static func milestone_chance(fate_value: float) -> float:
	return 1.0 - pow(1.0 - fate_value, 1.0 / 5.0)


static func roll_failure(fate_value: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < milestone_chance(fate_value)


## The name of an archetype, as the family's chronicle shows it.
static func archetype_name(id: String) -> String:
	match id:
		"restorer":
			return GameMessages.text("life", "archetype_restorer")
		"rebel":
			return GameMessages.text("life", "archetype_rebel")
		"inheritor":
			return GameMessages.text("life", "archetype_inheritor")
		"survivor":
			return GameMessages.text("life", "archetype_survivor")
		"redeemer":
			return GameMessages.text("life", "archetype_redeemer")
		"successor":
			return GameMessages.text("life", "archetype_successor")
	return id


## What an archetype does, in a line.
static func archetype_desc(id: String) -> String:
	match id:
		"restorer":
			return GameMessages.text("life", "archetype_restorer_desc")
		"rebel":
			return GameMessages.text("life", "archetype_rebel_desc")
		"inheritor":
			return GameMessages.text("life", "archetype_inheritor_desc")
		"survivor":
			return GameMessages.text("life", "archetype_survivor_desc")
		"redeemer":
			return GameMessages.text("life", "archetype_redeemer_desc")
		"successor":
			return GameMessages.text("life", "archetype_successor_desc")
	return ""


## The name of a milestone, as the heir's journal shows it.
static func milestone_label(id: String) -> String:
	match id:
		"coming_of_age":
			return GameMessages.text("life", "milestone_coming_of_age")
		"first_quest":
			return GameMessages.text("life", "milestone_first_quest")
		"family_founded":
			return GameMessages.text("life", "milestone_family_founded")
		"midlife":
			return GameMessages.text("life", "milestone_midlife")
		"elder_years":
			return GameMessages.text("life", "milestone_elder_years")
	return id


static func roll_severity(fate_value: float, rng: RandomNumberGenerator) -> String:
	var r := rng.randf() * 100.0
	if fate_value <= 0.10:
		return "minor" if r < 85 else ("moderate" if r < 98 else "major")
	elif fate_value <= 0.20:
		return "minor" if r < 45 else ("moderate" if r < 80 else ("major" if r < 96 else "critical"))
	return "minor" if r < 20 else ("moderate" if r < 50 else ("major" if r < 80 else "critical"))


static func roll_archetype(rng: RandomNumberGenerator) -> String:
	var keys: Array = ARCHETYPES.keys()
	return keys[rng.randi() % keys.size()]
