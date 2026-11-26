## The first-heir tutorial: which tip to show next. No UI and no saved state of its own: each tip in
## data/ui/tutorial.json says when it applies ("when": all of these hold) and when it is done
## ("done": any of these holds), and the answers come from the dynasty itself, so an old save works
## and a hand-played game moves through the tips by playing. The first tip that applies and is not
## done is the one shown, so the order of the file is the order of teaching.
## The open world's tips (screen "sandbox": moving, digging, gathering, building, companions, night) work the same
## way. What cannot be read from the dynasty (whether the heir has moved yet: where they stand is not saved) the
## screen tells in `ctx`, a dictionary of yes-or-no facts by the names in CONTEXT; a fact not given is false.
class_name GameTutorial
extends RefCounted

## The questions a tip may ask of the dynasty, by the names data/ui/tutorial.json uses.
const PREDICATES := ["hunted", "trained", "wounded", "can_found_family", "too_young_for_family",
	"family_founded", "can_retire", "first_generation",
	"moved", "dug", "can_build", "built", "has_room", "has_companion", "gave_order", "night",
	"guided", "has_dead", "hurt", "errand_taken", "errand_ready", "errand_paid",
	"at_marker", "routed", "store_seen"]
## The questions only the screen can answer, passed in `ctx`: the guided start's "walked to the marker", "clicked to walk" and
## "has been in the store" (where the heir has been is not saved; a later fact of the dynasty ends a step too, so a game
## picked up again moves on).
const CONTEXT := ["moved", "at_marker", "routed", "store_seen"]
const SCREENS := ["life", "succession", "sandbox", "battle"]


## The tip to show on `screen` ("life" or "succession"), or {} when there is none. Returns
## {id, text, highlight}: the text with its {name} and {min_age} filled in, and the start of
## the text of each action button to mark. `ctx` holds the facts in CONTEXT (see above).
static func current(d: GameDynasty, screen: String = "life", ctx: Dictionary = {}) -> Dictionary:
	GameData.load_all()
	for step in GameData.tutorial["steps"]:
		if str(step.get("screen", "life")) != screen:
			continue
		if not (step.get("when", []) as Array).all(func(p): return holds(d, str(p), ctx)):
			continue
		if (step.get("done", []) as Array).any(func(p): return holds(d, str(p), ctx)):
			continue
		return {"id": step["id"], "text": fill(GameLocale.text("tutorial", str(step["id"]), str(step["text"])), d), "highlight": (step.get("highlight", []) as Array).duplicate(), "goal": str(step.get("goal", ""))}
	return {}


## One question about the dynasty. An unknown name is false, and tests/test_game_tutorial.gd fails
## on a name in the data that is not in PREDICATES.
static func holds(d: GameDynasty, predicate: String, ctx: Dictionary = {}) -> bool:
	var h := d.heir
	if CONTEXT.has(predicate):
		return typeof(ctx.get(predicate)) == TYPE_BOOL and bool(ctx[predicate])
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
		"dug":
			return GameMine.dug_count(d, GameWorldGen.MINE_SITE) > 0
		"can_build":   # the stores and purse can pay for a wall
			return GameBuild._cost_problem(d, GameBuild.pieces()["wall"]) == ""
		"built":
			return not d.built.is_empty()
		"has_room":
			return not GameBuild.rooms(d).is_empty()
		"has_companion":
			return not d.party.members.is_empty()
		"gave_order":
			return d.party.members.any(func(m): return GameCompanions.order_of(d, str(m["id"])) != GameCompanions.FOLLOW)
		"night":
			return GameDay.is_night(d)
		"guided":   # the guided start was begun for this house (GameGoal.begin)
			return GameGoal.guided(d)
		"has_dead":   # the bodies of the last victory, not yet searched or left
			return not d.loot.is_empty()
		"hurt":
			return float(h.hp) < float(GameData.tutorial.get("hurt_below", 0.75)) * float(h.max_hp())
		"errand_taken":   # the first job (data/world/goals.json) is on the house's list or done
			return d.quests.is_active(GameGoal.first_quest()) or d.quests.times_done(GameGoal.first_quest()) > 0
		"errand_ready":
			var e := d.quests.entry(GameGoal.first_quest())
			return not e.is_empty() and d.quests.is_complete(e)
		"errand_paid":
			return d.quests.times_done(GameGoal.first_quest()) > 0
	return false


## {name} is the heir, {min_age} the age a family may be founded, {home} the town the family builds round and {claim}
## how many tiles from it the family's ground reaches (GameBuild).
static func fill(text: String, d: GameDynasty) -> String:
	var out := text.replace("{name}", d.heir.name).replace("{min_age}", str(int(ceil(d.heir.family_min_age()))))
	if "{home}" in out or "{claim}" in out:
		out = out.replace("{home}", str(GameBuild.base().get("name", ""))).replace("{claim}", str(int(GameBuild.claim_radius(d))))
	return out
