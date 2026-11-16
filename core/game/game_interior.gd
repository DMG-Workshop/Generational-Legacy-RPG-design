## The floor of an interior as walkable cells (roadmap item 41, the sandbox's interiors). GameSpaces says what an interior's
## rooms are (rectangles on its own floor, with doors between them, origin at the door the heir comes in by); this turns that
## into cells the sandbox can walk: every tile of a room is `floor`, each door between rooms is a `door`, the tile the heir
## enters on is the `exit` (standing on it and using it leads back out), and every tile that touches the floor and is not
## floor is a `wall`. Anything else is nothing at all (not a cell). Pure and deterministic: built from the layouts alone,
## nothing saved, no dice. A person (GamePeople) stands on a floor cell, which is then `person`: solid, drawn, and talked to. The kinds are the names the tile view has a colour for.
class_name GameInterior
extends RefCounted

const WALKABLE := ["floor", "door", "exit"]
## The eight ways round a tile, for finding the walls.
const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


## The tile the heir comes in on and goes out by: the origin of the interior's own floor.
static func entry() -> Vector2i:
	return Vector2i.ZERO


## The cells of an interior: {"x,z": kind}. {} for a space that is not an interior or has no rooms.
static func cells(space_id: String) -> Dictionary:
	var out := {}
	var rooms := GameSpaces.rooms(space_id)
	if rooms.is_empty():
		return out
	for r in rooms:
		var rect: Array = r["rect"]
		for dz in int(rect[3]):
			for dx in int(rect[2]):
				out[key(int(rect[0]) + dx, int(rect[1]) + dz)] = "floor"
	for door in GameSpaces._layout(space_id).get("doors", []):
		out[key(int(door["at"][0]), int(door["at"][1]))] = "door"
	var e := entry()
	if out.has(key(e.x, e.y)):
		out[key(e.x, e.y)] = "exit"
	for person in GamePeople.in_space(space_id):
		var c := GamePeople.cell_of(person)
		if out.get(key(c.x, c.y), "") == "floor":
			out[key(c.x, c.y)] = "person"
	var walls := {}
	for k in out:
		var p := _parse(k)
		for a in AROUND:
			var n: Vector2i = p + a
			if not out.has(key(n.x, n.y)):
				walls[key(n.x, n.y)] = "wall"
	for k in walls:
		out[k] = "wall"
	return out


static func _parse(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## Whether a cell can be stood on.
static func passable(grid: Dictionary, x: int, z: int) -> bool:
	return str(grid.get(key(x, z), "")) in WALKABLE


## The room a cell is in ("" for a door, a wall or nowhere): GameSpaces' rooms.
static func room_at(space_id: String, x: int, z: int) -> String:
	return GameSpaces.room_at(space_id, x, z)


## Every walkable cell reachable from the entry, stepping the four ways: the floor the heir can really get across.
static func reachable(grid: Dictionary) -> Dictionary:
	var seen := {}
	var e := entry()
	if not passable(grid, e.x, e.y):
		return seen
	var stack: Array = [e]
	seen[key(e.x, e.y)] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if passable(grid, n.x, n.y) and not seen.has(key(n.x, n.y)):
				seen[key(n.x, n.y)] = true
				stack.append(n)
	return seen
