## The minimap (docs/PLAYER_INTERFACE.md, slice 3): the ground round a point of the open world, a tile a cell, as the kind of each
## tile (the same kinds the tile view and the world map colour: a biome, water, deep water, snow, ford, or the piece built there).
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
			row.append(GameRelief.kind(GameWorldGen.tile(d, x, z)) if built == "" else built)
		rows.append(row)
	return rows
