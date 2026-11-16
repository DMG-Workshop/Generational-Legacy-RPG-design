## The fingers on the sandbox screen (roadmap item 39): which finger steers and where it landed, and the pinch of two other
## fingers. Pure bookkeeping with no nodes, so it is tested headless; the screen feeds it its touch and drag events and asks
## it for the push of the stick and the zoom. A finger that lands in the left part of the view (`stick_zone_share` of it)
## when none is steering becomes the stick, drawn where it landed; any other finger is a spare, and exactly two spares
## pinch. The arithmetic is WorldInput's (`touch_stick`, `pinch_zoom`).
extends RefCounted

const WorldInput := preload("res://ui/play/world_input.gd")

var stick := -1                  # the steering finger's index, -1 for none
var origin := Vector2.ZERO       # where it landed
var now := Vector2.ZERO          # where it is
var _spare := {}                 # index -> position, the fingers that are not steering
var _span := 0.0                 # the distance between the two spare fingers at the last pinch step


## A finger went down (`pressed`) or up at `pos`, in a view `area` big.
func touch(index: int, pos: Vector2, pressed: bool, area: Vector2) -> void:
	if pressed:
		if stick < 0 and pos.x < area.x * WorldInput.setting("stick_zone_share"):
			stick = index
			origin = pos
			now = pos
		else:
			_spare[index] = pos
			_reset_span()
	elif index == stick:
		stick = -1
	else:
		_spare.erase(index)
		_reset_span()


## A finger moved to `pos`.
func drag(index: int, pos: Vector2) -> void:
	if index == stick:
		now = pos
	elif _spare.has(index):
		_spare[index] = pos


func steering() -> bool:
	return stick >= 0


## The push of the steering finger, from nothing to a full push (length 1); nothing when no finger steers.
func move() -> Vector2:
	return WorldInput.touch_stick(origin, now) if stick >= 0 else Vector2.ZERO


## Where to draw the stick's knob: the finger, held within the stick's radius of where it landed.
func knob() -> Vector2:
	return origin + (now - origin).limit_length(WorldInput.setting("touch_stick_radius_px"))


## The zoom after two spare fingers moved apart or together since the last call; unchanged with any other number of them.
func pinch(zoom: float) -> float:
	if _spare.size() != 2:
		return zoom
	var span := _span_now()
	var out := WorldInput.pinch_zoom(zoom, _span, span)
	_span = span
	return out


func fingers() -> int:
	return _spare.size() + (1 if stick >= 0 else 0)


func _span_now() -> float:
	var keys := _spare.keys()
	return (_spare[keys[0]] as Vector2).distance_to(_spare[keys[1]])


func _reset_span() -> void:
	_span = _span_now() if _spare.size() == 2 else 0.0
