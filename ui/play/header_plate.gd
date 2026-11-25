## The header's plate on a desktop window with a mouse: the heir's name and the gold they carry, light on an ink badge with a coin
## (docs/ART_DIRECTION.md). Rendering only: the screen tells it what to show. It sits at the end of the bar, over the wooden header.
extends Control

const UiSkin := preload("res://ui/play/ui_skin.gd")

var who := ""
var gold := 0


func show_for(p_who: String, p_gold: int) -> void:
	if p_who == who and p_gold == gold and custom_minimum_size.x > 0.0:
		return
	who = p_who
	gold = p_gold
	custom_minimum_size = Vector2(_width(), 0)
	queue_redraw()


func _font_size() -> int:
	return int(UiSkin.hud("plate_text"))


func _width() -> float:
	var px := float(UiSkin.pixel())
	var f := ThemeDB.fallback_font
	var fs := _font_size()
	return px * 6.0 + px * 8.0 + px * 2.0 + f.get_string_size(str(gold), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + px * 5.0 + f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _draw() -> void:
	var px := float(UiSkin.pixel())
	var f := ThemeDB.fallback_font
	var fs := _font_size()
	var h := f.get_height(fs) + px * 4.0
	var box := Rect2(Vector2(0, roundf((size.y - h) * 0.5)), Vector2(size.x, h))
	draw_style_box(UiSkin.badge_box(false), box)
	var x := box.position.x + px * 3.0
	draw_texture_rect(UiSkin.icon_tex("coin"), Rect2(Vector2(x, box.position.y + (h - px * 8.0) * 0.5), Vector2.ONE * px * 8.0), false, UiSkin.pal("gold"))
	x += px * 10.0
	var base := box.position.y + px * 2.0 + f.get_ascent(fs)
	var gtxt := str(gold)
	draw_string(f, Vector2(x, base), gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiSkin.pal("gold_hi"))
	x += f.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + px * 5.0
	draw_string(f, Vector2(x, base), who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiSkin.pal("parch_hi"))
