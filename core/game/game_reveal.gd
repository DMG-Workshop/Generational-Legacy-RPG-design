## Doll houses (core, no UI; `reveal` in data/world/sandbox.json): a house is seen from outside with its roof on, and the roof thins
## and goes as the heir comes close, so the rooms show, like the lid of a doll's house coming off. Pure functions of the heir's
## position and what is built: no dice, nothing saved. `near` and `far` are distances in tiles: at `far` or more the roof is whole,
## at `near` or less it is gone, between them it fades in `steps` steps (0 whole, `steps` gone). A town building reads `alpha`
## (a smooth 1 to 0) and the family's roofs read `roof_steps` (a whole roof lifts as one, however large the house).
class_name GameReveal
extends RefCounted


static func setting(key: String) -> Variant:
	return GameSandbox.data()["reveal"][key]


## How much of a roof is left at `dist` tiles: 1 whole, 0 gone.
static func alpha(dist: float) -> float:
	var near := float(setting("near"))
	var far := float(setting("far"))
	return clampf((dist - near) / (far - near), 0.0, 1.0)


## The step (0 whole to `steps` gone) for `dist`.
static func step_for(dist: float) -> int:
	var steps := int(setting("steps"))
	return clampi(steps - roundi(alpha(dist) * float(steps)), 0, steps)


## How far a point is from a building's body (tiles, w by h from x, z; 0 inside it).
static func distance_to(rect: Rect2i, px: float, pz: float) -> float:
	var dx := maxf(maxf(float(rect.position.x) - px, px - float(rect.position.x + rect.size.x)), 0.0)
	var dz := maxf(maxf(float(rect.position.y) - pz, pz - float(rect.position.y + rect.size.y)), 0.0)
	return sqrt(dx * dx + dz * dz)


## Whether a column has a roof over it, on any storey.
static func roofed(d: GameDynasty, x: int, z: int) -> bool:
	for y in range(GameBuild.SURFACE - 1, GameBuild.top_y() - 2, -1):
		if GameBuild.kind_at(d, x, y, z) == "roof":
			return true
	return false


## The roofs near a point that are not whole: `{"x,z": step}` for every roofed column of every house with a column within `far` of
## (px, pz); a house lifts as one (columns joined by their sides and corners). A house whole at `far` is not listed.
static func roof_steps(d: GameDynasty, px: float, pz: float) -> Dictionary:
	var out := {}
	if d.built.is_empty():
		return out
	var far := float(setting("far"))
	var cx := floori(px)
	var cz := floori(pz)
	var r := ceili(far) + 1
	var seen := {}
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			var k := "%d,%d" % [x, z]
			if seen.has(k) or not roofed(d, x, z):
				continue
			var cells: Array = []
			var best := INF
			var todo := [Vector2i(x, z)]
			seen[k] = true
			while not todo.is_empty() and cells.size() < int(setting("max_roof_cells")):
				var c: Vector2i = todo.pop_back()
				cells.append(c)
				best = minf(best, Vector2(float(c.x) + 0.5, float(c.y) + 0.5).distance_to(Vector2(px, pz)))
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var n := Vector2i(c.x + dx, c.y + dz)
						var nk := "%d,%d" % [n.x, n.y]
						if not seen.has(nk) and roofed(d, n.x, n.y):
							seen[nk] = true
							todo.append(n)
			var step := step_for(best)
			if step > 0:
				for c in cells:
					out["%d,%d" % [c.x, c.y]] = step
	return out


static func validate() -> Array:
	var bad: Array = []
	var s: Dictionary = GameSandbox.data().get("reveal", {})
	for k in ["near", "far", "steps", "max_roof_cells"]:
		if not s.has(k):
			bad.append("sandbox.json: reveal.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["near"]) < 0.0 or float(s["far"]) <= float(s["near"]):
		bad.append("sandbox.json: reveal needs far above near and near 0 or more")
	if int(s["steps"]) < 1 or int(s["steps"]) > 8 or int(s["max_roof_cells"]) < 1:
		bad.append("sandbox.json: reveal.steps is 1 to 8 and max_roof_cells at least 1")
	return bad
