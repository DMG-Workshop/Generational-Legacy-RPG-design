## A short conversation with a villager of the open world: what they said, and the few things the heir may ask (GameTalk.choices_of;
## the answers are GameTalk.reply). The screen only draws; the words and the rumours come from GameTalk. The world waits while it is open.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var who: Dictionary = {}
var first := ""                 # what they said when the heir used them
var on_say: Callable = Callable()   # called with each line, for the map's status line
var body: VBoxContainer
var _said: Label
var _asked := {}


func _ready() -> void:
	body = Kit.overlay(self, str(who.get("job", "")))
	_said = Kit.label(first, 17)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_said)
	_rebuild()


func _rebuild() -> void:
	for c in body.get_children():
		if c.has_meta("choice"):
			body.remove_child(c)
			c.queue_free()
	for c in GameTalk.choices_of(who):
		var id := str(c["id"])
		if _asked.has(id):
			continue
		var b := Kit.button(str(c["label"]), func(): _ask(id), Vector2(0, 44))
		b.set_meta("choice", true)
		body.add_child(b)
	var bye := Kit.button(GameTalk.text("choice.bye"), func(): queue_free(), Vector2(0, 44))
	bye.set_meta("choice", true)
	body.add_child(bye)


func _ask(id: String) -> void:
	_asked[id] = true
	var r := GameTalk.reply(dynasty, who, id, GameDay.hour(dynasty))
	if r["ok"]:
		_said.text = str(r["bare"])
		if on_say.is_valid():
			on_say.call(str(r["text"]))
	_rebuild()
