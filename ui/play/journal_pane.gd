## The journal pane (docs/PLAYER_INTERFACE.md, slice 3): the last lines of what has happened in the open world (GameSandbox.log:
## talk, finds, arrivals, rests, hazards), newest at the bottom. The sandbox screen calls `refresh` a few times a second; the text
## is only set again when a line has been added. Rendering only.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var sb: GameSandbox
var lines := 14
var _text: RichTextLabel
var _seen := -1


func _ready() -> void:
	lines = int(GameSandbox.data()["view"].get("journal_lines", 14))
	var v := Kit.overlay(self, "Journal")
	_text = Kit.rich()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.scroll_following = true
	v.add_child(_text)
	refresh()


func refresh() -> void:
	if sb == null or sb.log.size() == _seen:
		return
	_seen = sb.log.size()
	var out: Array = []
	for e in sb.log.slice(maxi(0, sb.log.size() - lines)):
		out.append(Kit.quiet_bb(str(e["text"])) if str(e.get("kind", "")) in ["talk", "arrived"] else str(e["text"]))
	_text.text = "\n".join(out)
