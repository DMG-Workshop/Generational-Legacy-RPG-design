## The entrance of a dungeon on the open world, painted as pixel art (rendering only; data/world/dungeon_themes.json says what each
## theme's entrance looks like, GameDungeonArt where it stands). Each is 5 tiles wide and 3 tall (80 by 48 pixels) with the door tile
## at the bottom middle: a cave mouth with skull posts, a barrow mound with a stone door, a volcano gate, drowned temple steps, a
## dwarf gate, a tear in the ground. Made once from its rows and kept; nothing is random.
class_name DungeonEntranceArt
extends RefCounted

static var _cache: Dictionary = {}


## The image of a dungeon's entrance (empty for a place with no theme).
static func image(place: String) -> Image:
	var t := GameDungeonArt.theme(place)
	if t.is_empty():
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var e: Dictionary = t["entrance"]
	var rows: Array = e["rows"]
	var w := int(e["w"]) * 16
	var h := int(e["h"]) * 16
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var pal: Dictionary = {}
	for ch in e["palette"]:
		pal[ch] = Color.html(str(e["palette"][ch]))
	for y in h:
		var row := str(rows[y])
		for x in w:
			var ch := row.substr(x, 1)
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return img


static func texture(place: String) -> Texture2D:
	if not _cache.has(place):
		_cache[place] = ImageTexture.create_from_image(image(place))
	return _cache[place]


static func validate() -> Array:
	var bad: Array = []
	for place in GameDungeonArt.data()["dungeons"]:
		var img := image(str(place))
		var e: Dictionary = GameDungeonArt.theme(str(place))["entrance"]
		if img.get_width() != int(e["w"]) * 16 or img.get_height() != int(e["h"]) * 16:
			bad.append("%s: the entrance is not its tiles' size" % place)
			continue
		var solid := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					solid += 1
		if solid < img.get_width() * img.get_height() / 3:
			bad.append("%s: the entrance is mostly clear" % place)
		# the door tile (bottom middle) must have something drawn: the way in
		var mid := (int(e["w"]) - 1) / 2 * 16
		var door_px := 0
		for y in range(img.get_height() - 16, img.get_height()):
			for x in range(mid, mid + 16):
				if img.get_pixel(x, y).a > 0.0:
					door_px += 1
		if door_px < 100:
			bad.append("%s: nothing is drawn at the door tile" % place)
	return bad
