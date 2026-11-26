## The journal pane (docs/PLAYER_INTERFACE.md, slice 3): the last lines of what has happened in the open world (GameSandbox.log:
## talk, finds, arrivals, rests, hazards), newest at the bottom. The sandbox screen calls `refresh` a few times a second; the text
## is only set again when a line has been added. Rendering only.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const Toast := preload("res://ui/play/toast.gd")

var dynasty: GameDynasty
var sb: GameSandbox
var lines := 14
var _text: RichTextLabel
var _seen := -1
var _seen_news := -1


func _ready() -> void:
	lines = int(GameSandbox.data()["view"].get("journal_lines", 14))
	var v := Kit.overlay(self, "Journal")
	_text = Kit.rich()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.scroll_following = true
	v.add_child(_text)
	refresh()


func refresh() -> void:
	if sb == null or (sb.log.size() == _seen and Toast.history.size() == _seen_news):
		return
	_seen = sb.log.size()
	_seen_news = Toast.history.size()
	var out: Array = []
	var told := {}
	for e in sb.log.slice(maxi(0, sb.log.size() - lines)):
		told[str(e["text"])] = true
		out.append(Kit.quiet_bb(str(e["text"]), UiSkin.in_skin(self)) if str(e.get("kind", "")) in ["talk", "arrived"] else str(e["text"]))
	# the toasts that are not in the log (what the world said when something was tried, picked or failed), so none is lost once it fades
	var news: Array = Toast.history.filter(func(h): return not told.has(str(h["text"])))
	for h in news.slice(maxi(0, news.size() - lines / 2)):
		out.append(Kit.quiet_bb(str(h["text"]), UiSkin.in_skin(self)))
	_text.text = "\n".join(out)


## What the pane shows now, as plain text (for tests and readers).
func text() -> String:
	return _text.get_parsed_text() if _text != null else ""
