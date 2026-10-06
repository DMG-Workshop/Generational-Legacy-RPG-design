## Fate Value, milestone failure checks, severity and heir archetypes.
class_name GameFate
extends RefCounted

const SEVERITIES := ["minor", "moderate", "major", "critical"]

## Archetypes a failure can create in the next heir.
const ARCHETYPES := {
	"restorer": {"name": "Restorer", "desc": "Wants back what was lost: +gold, +VIT.", "bonus": {"vit": 0.1}, "gold": 60},
	"rebel": {"name": "Rebel", "desc": "Does the opposite of their parent: +AGI, +STR.", "bonus": {"agi": 0.1, "str": 0.05}},
	"inheritor": {"name": "Inheritor", "desc": "Learns fast from past failure: +25% XP.", "bonus": {"xp": 0.25}},
	"survivor": {"name": "Survivor", "desc": "Trusts no one, stays alive: +15% HP, +DEF.", "bonus": {"hp": 0.15, "vit": 0.05}},
	"redeemer": {"name": "Redeemer", "desc": "Heals old wounds: sheds one curse, +MAG.", "bonus": {"mag": 0.1}, "purge_curse": true},
	"successor": {"name": "Successor", "desc": "Keeps what worked: +5% all stats.", "bonus": {"all_stats": 0.05}},
}

const MILESTONE_LABELS := {
	"coming_of_age": "Coming of Age", "first_quest": "First Quest", "family_founded": "Family Founded",
	"midlife": "Midlife", "elder_years": "Elder Years",
}


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
