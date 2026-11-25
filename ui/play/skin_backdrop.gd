## The night-sky backdrop of a full-screen text screen (ui/play/ui_skin.gd, data/ui/skin.json "screens"): bands of colour, a tile of stars
## and a strip of hills along the bottom, all kept textures drawn at whole multiples of the pixel with no smoothing. Still: nothing
## moves, so reduced motion has nothing to turn off. Rendering only.
extends Control

const UiSkin := preload("res://ui/play/ui_skin.gd")


func _init() -> void:
	name = "SkinBackdrop"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("skin_done", true)
	set_meta("skin_screen_done", true)


func _draw() -> void:
	draw_texture_rect(UiSkin.sky_tex(), Rect2(Vector2.ZERO, size), false)
	draw_texture_rect(UiSkin.stars_tex(), Rect2(Vector2.ZERO, size), true)
	var hills := UiSkin.hills_tex()
	var hh := float(hills.get_height())
	draw_texture_rect(hills, Rect2(0.0, size.y - hh, size.x, hh), true)
