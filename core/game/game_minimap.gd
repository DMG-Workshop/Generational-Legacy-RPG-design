## The minimap (docs/PLAYER_INTERFACE.md, slice 3): the ground round a point of the open world, a tile a cell, as the kind of each
## tile (the same kinds the tile view and the world map colour: a biome, water, deep water, snow, ford, or the piece built there), and
## over the ground a town's buildings (`building`), the walls and towers round it (`city_wall`) and the passage of a gate (`gate`).
## A pure function of the seed, the built pieces and the point: no dice, nothing saved. Rendering is ui/play/minimap_pane.gd.
class_name GameMiniMap
extends RefCounted


## Rows (z, north first) of columns (x) of kinds, `radius` tiles each way from (cx, cz): (2 * radius + 1) squared in all.
static func kinds(d: GameDynasty, cx: int, cz: int, radius: int) -> Array:
	var rows: Array = []
	for z in range(cz - radius, cz + radius + 1):
		var row: Array = []
		for x in range(cx - radius, cx + radius + 1):
			var built := GameBuild.kind_at(d, x, GameBuild.SURFACE, z)
			row.append(built if built != "" else _standing(x, z, GameRelief.kind(GameWorldGen.tile(d, x, z))))
		rows.append(row)
	return rows


## Where the map pin is from a tile, for the minimap (`radius` tiles each way is its picture; the sandbox's `minimap_radius` when -1): {} for no pin,
## else {inside (the pin is within the picture), angle (radians, 0 east, turning toward south as the screen does: the way an arrow points),
## distance (whole tiles), dir (the compass point), place (its name), offset (the pin's tile less `from_tile`)}. No dice, nothing saved.
static func pin_bearing(d: GameDynasty, from_tile: Vector2i, radius: int = -1) -> Dictionary:
	if d.map_pin.is_empty():
		return {}
	var r := int(GameSandbox.data()["view"].get("minimap_radius", 20)) if radius < 0 else radius
	var at := GameTravel.pin_tile(d)
	var off := at - from_tile
	return {"inside": maxi(absi(off.x), absi(off.y)) <= r, "angle": atan2(float(off.y), float(off.x)), "distance": GameTravel.tiles(from_tile, at),
		"dir": GameTravel.compass(from_tile, at), "place": GameTravel.pin_name(d), "offset": off}


## What stands on a tile of the open world that is not the family's: a town's building, a wall or tower of its wall, or a gate's
## passage; the ground's own kind where there is none.
static func _standing(x: int, z: int, ground: String) -> String:
	if GameTown.blocks(x, z):
		return "building"
	var w := GameWalls.kind_at(x, z)
	if w == "gate":
		return "gate"
	if w != "":
		return "city_wall"
	return ground
