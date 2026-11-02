## The sex of a dynasty's people: the founder picks it at the start; children are rolled at birth; a spouse
## is always the opposite sex (mates are opposite-sex only). A roll uses its own seeded dice, not the
## dynasty's main dice, so adding it changes no existing life: the same seed plays out exactly as before.
class_name GameSex
extends RefCounted

const MALE := "male"
const FEMALE := "female"
const SEXES := [MALE, FEMALE]


static func valid(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and SEXES.has(v)


static func opposite(sex: String) -> String:
	return FEMALE if sex == MALE else MALE


## A person's sex from the dynasty seed and their id alone, 50/50.
static func roll(seed_value: int, id: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, id, "sex"])
	return SEXES[r.randi() % SEXES.size()]
