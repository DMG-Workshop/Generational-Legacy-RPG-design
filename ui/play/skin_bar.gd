## A segmented bar of the interface skin (ui/play/ui_skin.gd): drawn over a ProgressBar that keeps the value and the range, with the
## bar's picture at the left and its words over the fill. Rendering only.
extends Control

const UiSkin := preload("res://ui/play/ui_skin.gd")

var pb: ProgressBar
var kind := "hp"
var text := ""
var thin := false   # a plate's slim bar (battle): no picture, no words; frame, track and a segmented fill drawn to the pixel

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw_thin() -> void:
	var c: Array = UiSkin.triple(kind if kind in UiSkin.TRIPLES else str(UiSkin.data()["bars"][kind]["colors"]))
	var frac := 0.0 if pb.max_value <= 0.0 else clampf(float(pb.value) / float(pb.max_value), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), UiSkin.pal("ink"))
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), UiSkin.pal("track"))
	var inner := size - Vector2(2, 2)
	var fw := floorf(inner.x * frac)
	if frac > 0.0:
		fw = maxf(fw, 1.0)
	if fw <= 0.0 or inner.y < 1.0:
		return
	draw_rect(Rect2(Vector2.ONE, Vector2(fw, inner.y)), c[1])
	if inner.y >= 3.0:
		draw_rect(Rect2(Vector2.ONE, Vector2(fw, 1)), c[0])
		draw_rect(Rect2(Vector2(1, size.y - 2.0), Vector2(fw, 1)), c[2])
	var every := float(int(UiSkin.piece("bar")["segment_every"]) * UiSkin.pixel())
	var x := every
	while x < fw + 1.0:
		draw_rect(Rect2(Vector2(x, 1), Vector2(1, inner.y)), c[2])
		x += every


func _draw() -> void:
	if thin:
		_draw_thin()
		return
	var spec: Dictionary = UiSkin.data()["bars"][kind]
	var S: int = UiSkin.pixel()
	var sc: int = int(UiSkin.piece("bar")["icon_scale"])
	var icon: Texture2D = UiSkin.icon_tex(str(spec["icon"]))
	var iw := 8 * sc * S
	var colors: Array = UiSkin.triple(str(spec["colors"]))
	var ink: Color = UiSkin.pal("ink")
	for o in [Vector2(S, 0), Vector2(-S, 0), Vector2(0, S), Vector2(0, -S)]:
		draw_texture_rect(icon, Rect2(Vector2(0, (size.y - iw) * 0.5) + o, Vector2(iw, iw)), false, ink)
	draw_texture_rect(icon, Rect2(Vector2(0, (size.y - iw) * 0.5), Vector2(iw, iw)), false, colors[1])
	var x := float(iw + 2 * S)
	var frac := 0.0 if pb.max_value <= 0.0 else clampf(float(pb.value) / float(pb.max_value), 0.0, 1.0)
	draw_texture(UiSkin.bar_tex(int(size.x - x), int(size.y), frac, str(spec["colors"])), Vector2(x, 0))
	var pf: Array = UiSkin.pick("bar", int(UiSkin.piece("bar")["text_size"]), get_theme_default_font())
	var font: Font = pf[0]
	var fs: int = pf[1]
	var at := Vector2(x + 4 * S, (size.y + float(fs) * 0.7) * 0.5)
	var ol := int(UiSkin.font_role("bar").get("outline", 3)) if UiSkin.font_for("bar") == font else 3
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, ink)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiSkin.pal("bar_text"))
