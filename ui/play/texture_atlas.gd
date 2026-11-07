## Packs small images into a few big texture pages, so a screen's sprites share textures instead of each having
## its own (fewer textures to keep and bind, which matters on a phone). An image added comes back as an
## AtlasTexture, a region of a page, that every control and node takes in place of a plain texture. Pages are
## square and fixed in size; images are placed left to right in rows ("shelves") with clear padding around them
## so a smoothly scaled sprite never picks up its neighbour's edge, and a new page is made when one is full. An
## image too big for a page gets a texture of its own. A page is uploaded when an add finishes, or once for a
## whole screen's worth between begin_batch() and end_batch(). Rendering only.
class_name TextureAtlas
extends RefCounted

var page_size: int
var padding: int
var pages: Array = []        # [{image, texture, shelves: [{y, h, x}], users: [AtlasTexture], dirty, used}]
var added := 0               # images added, the loners included
var loners := 0              # images too big for a page
var uploads := 0             # pages uploaded so far
var _batch := 0


func _init(p_page: int = 1024, p_padding: int = 2) -> void:
	page_size = maxi(16, p_page)
	padding = maxi(0, p_padding)


## Adds `img` and returns its texture: a region of a page, or a texture of its own when it cannot fit a page.
func add(img: Image) -> Texture2D:
	added += 1
	var w := img.get_width()
	var h := img.get_height()
	var cell_w := w + 2 * padding
	var cell_h := h + 2 * padding
	if cell_w > page_size or cell_h > page_size:
		loners += 1
		return ImageTexture.create_from_image(img)
	var spot := _place(cell_w, cell_h)
	var page: Dictionary = pages[spot.z]
	var at := Vector2i(spot.x + padding, spot.y + padding)
	(page["image"] as Image).blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(w, h)), at)
	page["dirty"] = true
	page["used"] = int(page["used"]) + cell_w * cell_h
	var t := AtlasTexture.new()
	t.atlas = page["texture"]
	t.region = Rect2(at, Vector2(w, h))
	t.filter_clip = true
	(page["users"] as Array).append(t)
	if _batch == 0:
		flush()
	return t


## The page, and the place on it, for a cell: x, y, page. Shelf packing: the first shelf tall enough with room
## left, else a new shelf under the last, else a new page.
func _place(cell_w: int, cell_h: int) -> Vector3i:
	for pi in pages.size():
		var shelves: Array = pages[pi]["shelves"]
		for s in shelves:
			if int(s["h"]) >= cell_h and int(s["x"]) + cell_w <= page_size:
				var x := int(s["x"])
				s["x"] = x + cell_w
				return Vector3i(x, int(s["y"]), pi)
		var top := 0
		if not shelves.is_empty():
			var last: Dictionary = shelves[shelves.size() - 1]
			top = int(last["y"]) + int(last["h"])
		if top + cell_h <= page_size:
			shelves.append({"y": top, "h": cell_h, "x": cell_w})
			return Vector3i(0, top, pi)
	var img := Image.create_empty(page_size, page_size, false, Image.FORMAT_RGBA8)
	pages.append({"image": img, "texture": ImageTexture.create_from_image(img), "shelves": [{"y": 0, "h": cell_h, "x": cell_w}], "users": [], "dirty": false, "used": 0})
	return Vector3i(0, 0, pages.size() - 1)


## Starts a batch: pages are not uploaded until the matching end_batch(). Batches nest.
func begin_batch() -> void:
	_batch += 1


func end_batch() -> void:
	_batch = maxi(0, _batch - 1)
	if _batch == 0:
		flush()


## Uploads every page that has changed since it was last uploaded. A changed page becomes a fresh texture and
## every region of it is pointed at that, so what is read back from a region (its image) is always current,
## whatever the renderer does with an update in place.
func flush() -> void:
	for p in pages:
		if p["dirty"]:
			var tex := ImageTexture.create_from_image(p["image"])
			p["texture"] = tex
			for u in p["users"]:
				(u as AtlasTexture).atlas = tex
			p["dirty"] = false
			uploads += 1


## {pages, images, loners, uploads, used (pixels placed, padding included), capacity (pixels in all pages)}.
func stats() -> Dictionary:
	var used := 0
	for p in pages:
		used += int(p["used"])
	return {"pages": pages.size(), "images": added, "loners": loners, "uploads": uploads, "used": used, "capacity": pages.size() * page_size * page_size}
