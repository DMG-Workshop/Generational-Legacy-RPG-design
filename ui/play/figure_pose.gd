## A battle figure's poses. The sprite sits in this holder, which moves it without touching the body under it
## that takes the taps and the flashes. Standing, the figure breathes: a two-frame bob of one art pixel, each
## figure on a beat of its own. The battle's events play as short moves, all in whole pixels of the art so
## the figure stays crisp: attack (a hop toward the other side), cast (a hop with a flash of the spell's
## colour), hurt (knocked back with a shake), dodge (a step back), guard (a crouch), and fall (a companion
## knocked out, the hero down, a slain foe: the figure lies down, its head toward its back). With reduced
## motion there is no breathing and no move, but a fall still shows, at once. Rendering only: nothing here
## touches the game's state or its dice.
extends Control

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

## The moves, as steps of [x toward the other side, y down] in art pixels and the seconds the figure holds
## there, ending where it stands. A step is a jump, not a glide, like the frames of a sprite.
const MOVES := {
	"attack": [[2, -1, 0.07], [0, 0, 0.13]],
	"cast": [[0, -2, 0.08], [0, 0, 0.16]],
	"hurt": [[-2, 0, 0.05], [-1, 0, 0.05], [-2, 0, 0.05], [0, 0, 0.1]],
	"dodge": [[-3, 0, 0.08], [-3, 0, 0.1], [0, 0, 0.14]],
	"guard": [[0, 1, 0.06], [0, 1, 0.3], [0, 0, 0.08]],
}

var sprite: TextureRect
var facing := 1.0       # 1: faces right, as the party does; -1: faces left, as the foes do
var px := 1.0           # one pixel of the art, in this holder's units
var beat := 0.0         # seconds in each half of a breath
var last := ""          # the last move played (or "fall"), for the tests and the views that follow
var lying := false      # fallen: no more breathing or moves
var _home := Vector2.ZERO
var _breath: Tween = null
var _move: Tween = null


## Fills `box` with `tex` standing in it as SpriteArt.fit places it, turned the way it `faces`. `beat` sets
## how long each half of its breath lasts, so figures side by side breathe out of step.
func setup(tex: Texture2D, box: Vector2, faces: float, beat: float) -> void:
	size = box
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	facing = signf(faces) if faces != 0.0 else 1.0
	sprite = SpriteArt.sprite_node(tex, box)
	add_child(sprite)
	_home = sprite.position
	px = sprite.size.x / maxf(1.0, float(tex.get_width()) / float(SpriteArt.UPSCALE))
	pivot_offset = Vector2(sprite.position.x + sprite.size.x * 0.5, sprite.position.y + sprite.size.y)   # the feet
	breathe(beat)


## Starts the idle bob, a half-beat up and a half-beat down; none with reduced motion or once fallen.
func breathe(p_beat: float) -> void:
	if _breath != null:
		_breath.kill()
		_breath = null
	sprite.position = _home
	beat = p_beat
	if lying or beat <= 0.0 or UiSettings.reduced_motion():
		return
	_breath = create_tween().set_loops()
	_breath.tween_interval(beat)
	_breath.tween_callback(func(): sprite.position.y = _home.y - px)
	_breath.tween_interval(beat)
	_breath.tween_callback(func(): sprite.position.y = _home.y)


func breathing() -> bool:
	return _breath != null and _breath.is_valid() and _breath.is_running()


## Plays a move from MOVES ("cast" takes the spell's colour as a flash). Nothing moves once fallen, and with
## reduced motion only `last` changes.
func play(move: String, tint: Color = Color(0, 0, 0, 0)) -> void:
	if lying or not MOVES.has(move):
		return
	last = move
	if UiSettings.reduced_motion():
		return
	if _move != null:
		_move.kill()
	position = Vector2.ZERO
	_move = create_tween()
	for step in MOVES[move]:
		var to := Vector2(float(step[0]) * facing * px, float(step[1]) * px)
		_move.tween_callback(func(): position = to)
		_move.tween_interval(float(step[2]))
	if tint.a > 0.0:
		sprite.modulate = Color.WHITE.lerp(tint, 0.6) * 1.6
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.3)


## Lies down, the head toward the back, turning about the feet; at once with reduced motion or `now`.
func fall(now: bool = false) -> void:
	if lying:
		return
	lying = true
	last = "fall"
	if _breath != null:
		_breath.kill()
		_breath = null
	if _move != null:
		_move.kill()
	position = Vector2.ZERO
	sprite.position = _home
	var down := -facing * PI * 0.5
	if now or UiSettings.reduced_motion():
		rotation = down
		return
	_move = create_tween()
	_move.tween_property(self, "rotation", down, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
