## Fate system: random failures and their consequences
##
## Each heir is born with a Fate Value (1-30%) representing their lifetime
## chance of a major failure. This system rolls at milestones and applies
## consequences that ripple to the next generation.

extends Node

class_name FateSystem


## Milestone check types
enum Milestone {
	COMING_OF_AGE,
	FIRST_QUEST,
	FAMILY_FOUNDED,
	MIDLIFE,
	ELDER_YEARS
}

## Failure severity
enum Severity {
	MINOR,
	MODERATE,
	MAJOR,
	CRITICAL
}

## Heir archetypes resulting from failure
enum HeirArchetype {
	RESTORER,      # Reclaim what was lost
	REBEL,         # Do the opposite of parent
	INHERITOR,     # Succeed where parent failed
	SURVIVOR,      # Stay safe, trust no one
	REDEEMER,      # Heal parent's wounds or curse
	SUCCESSOR      # Keep what worked, fix what didn't
}


## Calculate per-milestone failure chance
## Fate Value (1-30%) is split across 5 milestones
static func get_milestone_chance(fate_value: float) -> float:
	return 1.0 - pow(1.0 - fate_value, 1.0 / 5.0)


## Roll a failure check at a milestone
static func roll_failure(fate_value: float, rng: RandomNumberGenerator) -> bool:
	var milestone_chance = get_milestone_chance(fate_value)
	return rng.randf() < milestone_chance


## Determine failure severity based on Fate Value
static func get_severity(fate_value: float, rng: RandomNumberGenerator) -> Severity:
	var roll = rng.randf() * 100.0

	# Lower Fate = mostly minor failures
	if fate_value <= 0.10:
		if roll < 90:
			return Severity.MINOR
		else:
			return Severity.MODERATE

	# Medium Fate = mix of minor and major
	elif fate_value <= 0.20:
		if roll < 50:
			return Severity.MINOR
		elif roll < 85:
			return Severity.MODERATE
		else:
			return Severity.MAJOR

	# High Fate = real chance of critical
	else:
		if roll < 30:
			return Severity.MINOR
		elif roll < 60:
			return Severity.MODERATE
		elif roll < 85:
			return Severity.MAJOR
		else:
			return Severity.CRITICAL


## Determine heir archetype after a failure
static func get_heir_archetype(
	severity: Severity,
	parent_job_id: String,
	rng: RandomNumberGenerator
) -> HeirArchetype:
	if severity == Severity.CRITICAL:
		# Critical failures strongly push toward Restorer or Redeemer
		return HeirArchetype.RESTORER if rng.randf() < 0.6 else HeirArchetype.REDEEMER
	elif severity == Severity.MAJOR:
		# Major failures push toward Rebel or Inheritor
		return HeirArchetype.REBEL if rng.randf() < 0.5 else HeirArchetype.INHERITOR
	else:
		# Minor failures can go any direction
		var archetypes = [
			HeirArchetype.RESTORER,
			HeirArchetype.REBEL,
			HeirArchetype.INHERITOR,
			HeirArchetype.SURVIVOR,
			HeirArchetype.REDEEMER,
			HeirArchetype.SUCCESSOR
		]
		return archetypes[rng.randi() % archetypes.size()]


## List of critical failure types
static var CRITICAL_FAILURE_TYPES = [
	"Magical Catastrophe",
	"Military Defeat",
	"Betrayal by Ally",
	"Curse Activation",
	"Loss of Power",
	"Family Tragedy",
	"Heresy",
	"Dragon Encounter"
]

## Get a random critical failure type
static func get_failure_type(rng: RandomNumberGenerator) -> String:
	return CRITICAL_FAILURE_TYPES[rng.randi() % CRITICAL_FAILURE_TYPES.size()]
