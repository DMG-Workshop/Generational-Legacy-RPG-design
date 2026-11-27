## What stands by the road and the camp, as the sandbox meets it: the signposts (GameRoads), the caravans (GameCaravans) and the heir's camp
## (GameCamp). `consider` offers them to GameSandbox.name_at (a click names them, the thing menu lists what can be done), `use` is what the
## Use action does beside one. Kept apart from GameSandbox so that file only calls in. Pure: nothing here draws a die.
class_name GameRoadside
extends RefCounted


## Offers the things of the roadside near a point to `consider` (the callable of name_at: kind, name, x, z, slack, id).
static func consider(sb: GameSandbox, fx: float, fz: float, reach: float, consider: Callable) -> void:
	var d := sb.d
	var near := Rect2i(floori(fx - reach - 2.0), floori(fz - reach - 2.0), ceili(reach * 2.0 + 4.0), ceili(reach * 2.0 + 4.0))
	for p in GameRoads.posts_in(d, near):
		consider.call("sign", GameRoads.name_of_post(p), float(p["x"]) + 0.5, float(p["z"]) + 0.5, 0.5, str(p["id"]))
	for st in GameCaravans.in_rect(d, near):
		consider.call("caravan", GameRoads.text("caravan_name"), float(st["x"]), float(st["z"]), 0.5, GameCaravans.PREFIX + str(int(st["index"])))
	if GameCamp.active(sb):
		consider.call("camp", GameCamp.text("name"), GameCamp.point(sb).x, GameCamp.point(sb).y, 0.5, "camp")


## Use on the ground floor of the open world: the camp fire (rest or cook), a caravan's wares (the screen opens the merchant panel), or a
## signpost read aloud. {} when none is near.
static func use(sb: GameSandbox) -> Dictionary:
	var camp := GameCamp.use(sb)
	if not camp.is_empty():
		return camp
	var d := sb.d
	var van := GameCaravans.use(d, sb.heir_point().x, sb.heir_point().y)
	if not van.is_empty():
		sb.log.append({"kind": "trade", "text": str(van["text"])})
		return van
	var post := GameRoads.post_near(d, sb.heir_point().x, sb.heir_point().y, GameRoads.setting("read_reach"))
	if not post.is_empty():
		var line := GameRoads.read(post)
		sb.log.append({"kind": "sign", "text": line})
		return {"ok": true, "text": line}
	return {}
