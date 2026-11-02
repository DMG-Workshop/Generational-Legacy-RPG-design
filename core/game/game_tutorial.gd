## The first-heir tutorial: which tip to show next. No UI and no saved state of its own: each tip in
## data/ui/tutorial.json says when it applies ("when": all of these hold) and when it is done
## ("done": any of these holds), and the answers come from the dynasty itself, so an old save works
## and a hand-played game moves through the tips by playing. The first tip that applies and is not
## done is the one shown, so the order of the file is the order of teaching.
class_name GameTutorial
extends RefCounted

## The questions a tip may ask of the dynasty, by the names data/ui/tutorial.json uses.
const PREDICATES := ["hunted", "trained", "wounded", "can_found_family", "too_young_for_family",
	"family_founded", "can_retire", "first_generation"]


## The tip to show on `screen` ("life" or "succession"), or {} when there is none. Returns
## {id, text, highlight}: the text with its {name} and {min_age} filled in, and the start of
## the text of each action button to mark.
static func current(d: GameDynasty, screen: String = "life") -> Dictionary:
	GameData.load_all()
	for step in GameData.tutorial["steps"]:
		if str(step.get("screen", "life")) != screen:
			continue
		if not (step.get("when", []) as Array).all(func(p): return holds(d, str(p))):
			continue
		if (step.get("done", []) as Array).any(func(p): return holds(d, str(p))):
			continue
		return {"id": step["id"], "text": fill(str(step["text"]), d), "highlight": (step.get("highlight", []) as Array).duplicate()}
	return {}


## One question about the dynasty. An unknown name is false, and tests/test_game_tutorial.gd fails
## on a name in the data that is not in PREDICATES.
static func holds(d: GameDynasty, predicate: String) -> bool:
	var h := d.heir
	match predicate:
		"hunted":
			return d.total_hunts > 0 or h.battles_won > 0
		"trained":
			return h.training.values().any(func(v): return float(v) > 0.0)
		"wounded":
			return float(h.hp) < float(GameData.tutorial["wounded_below"]) * float(h.max_hp())
		"can_found_family":
			return d.can_found_family()
		"too_young_for_family":
			return not h.family_founded and h.age < h.family_min_age()
		"family_founded":
			return h.family_founded
		"can_retire":
			return d.can_retire()
		"first_generation":
			return d.gen <= 1
	return false


## {name} is the heir, {min_age} the age a family may be founded.
static func fill(text: String, d: GameDynasty) -> String:
	return text.replace("{name}", d.heir.name).replace("{min_age}", str(int(ceil(d.heir.family_min_age()))))
