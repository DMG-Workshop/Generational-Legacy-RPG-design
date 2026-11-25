## The minimap (docs/PLAYER_INTERFACE.md, slice 3): the ground round a point of the open world, a tile a cell, as the kind of each
## tile (the same kinds the tile view and the world map colour: a biome, water, deep water, snow, ford, or the piece built there), and
## over the ground a town's buildings (`building`), the walls and towers round it (`city_wall`) and the passage of a gate (`gate`).
## A pure function of the seed, the built pieces and the point: no dice, nothing saved. Rendering is ui/play/minimap_pane.gd.
class_name GameMiniMap
extends RefCounted


## The waygates the family knows within `radius` tiles of (cx, cz): [{id, x, z, mode}], for the pane to mark.
static func gates(d: GameDynasty, cx: int, cz: int, radius: int) -> Array:
	var out: Array = []
	for m in GameGates.markers(d):
		if absi(int(m["x"]) - cx) <= radius and absi(int(m["z"]) - cz) <= radius:
			out.append({"id": m["id"], "x": m["x"], "z": m["z"], "mode": m["mode"]})
	return out


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
