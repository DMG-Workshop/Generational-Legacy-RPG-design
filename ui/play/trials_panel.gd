## The trials of the realms (see GameTrials): each row says what a trial is, who runs it, what it would give and where the heir stands
## in it; the buttons do the next step of its way in, begin it, let its hours pass, finish it or face its master. A step that cannot
## be done says why, as text. Nothing here computes a result: GameTrials does it all.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable
var _body: VBoxContainer
var _line := ""            # what the last action told
var _ask_leave := false    # leaving a trial loses its progress, so it asks twice


func _ready() -> void:
	var v := Kit.overlay(self, "Trials of %s" % dynasty.heir.name)
	set_meta("modal", true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_build()


func _build() -> void:
	Kit.clear(_body)
	_body.add_child(_wrapped("A trial is a test set by its master. Each has a way in (a short errand or an offering), then takes hours of the world's clock, and passing it gives a lasting gain. One at a time.", 15, Kit.dim()))
	if _line != "":
		_body.add_child(_wrapped(_line, 15, Kit.ACCENT))
	var list := GameTrials.listing(dynasty)
	if list.is_empty():
		_body.add_child(_wrapped("No trial stands in a realm that is open to the family yet.", 16, Kit.dim()))
	for t in list:
		_body.add_child(_row(t))
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(0, 48)))


func _row(t: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var head := "%s  (%s, level %d, %d hours)" % [str(t["name"]), str(t["focus_name"]), int(t["level"]), int(t["length"])]
	box.add_child(_wrapped(head, 17, Kit.good() if str(t["status"]) == "passed" else Kit.ACCENT))
	var about := "Run by %s. Gives: %s." % [str(t["master"]), str(t["gain"])]
	if int(t["chance"]) >= 0:
		about += " Chance of passing: %d%%." % int(t["chance"])
	else:
		about += " Won by beating the master in a fight."
	box.add_child(_wrapped(about, 14, Kit.dim()))
	match str(t["status"]):
		"passed":
			box.add_child(_wrapped("Passed.", 14, Kit.good()))
		"active":
			_active(box, t)
		"way":
			box.add_child(_wrapped("The way in, step %d of %d: %s" % [int(t["steps_done"]) + 1, int(t["steps_total"]), str(t["step_text"])], 14, Kit.TEXT))
			var b := Kit.button("Do this step", func(): _act(func(): return GameTrials.do_step(dynasty, str(t["id"]))), Vector2(200, 44))
			b.name = "TrialStep"
			b.disabled = str(t["step_why"]) != ""
			box.add_child(b)
			if str(t["step_why"]) != "":
				box.add_child(_wrapped(str(t["step_why"]), 14, Kit.dim()))
		"ready", "shut":
			box.add_child(_wrapped("The way in is done.", 14, Kit.good()))
			var b2 := Kit.button("Begin (%d hours)" % int(t["length"]), func(): _act(func(): return GameTrials.start(dynasty, str(t["id"]))), Vector2(200, 44))
			b2.name = "TrialBegin"
			b2.disabled = str(t["status"]) == "shut"
			box.add_child(b2)
			if str(t["why"]) != "":
				box.add_child(_wrapped(str(t["why"]), 14, Kit.dim()))
	var rule := HSeparator.new()
	box.add_child(rule)
	return box


## The trial under way: its stage, the hours, and what can be done now.
func _active(box: VBoxContainer, t: Dictionary) -> void:
	var left := GameTrials.remaining(dynasty)
	box.add_child(_wrapped(GameTrials.stage_line(dynasty), 15, Kit.TEXT))
	box.add_child(_wrapped("%d of %d hours spent; %d to go." % [int(floor(GameTrials.spent(dynasty))), int(t["length"]), int(ceil(left))], 14, Kit.dim()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if left > 0.0:
		var w := Kit.button("Let the hours pass", func(): _act(func(): return "\n".join(GameTrials.wait_out(dynasty))), Vector2(200, 44))
		w.name = "TrialWait"
		row.add_child(w)
	elif bool(t["fight"]):
		var f := Kit.button("Face %s" % str(t["master"]), func(): _fight(), Vector2(200, 44))
		f.name = "TrialFight"
		row.add_child(f)
	else:
		var fin := Kit.button("Finish the trial", func(): _act(func(): return "\n".join(GameTrials.finish(dynasty))), Vector2(200, 44))
		fin.name = "TrialFinish"
		row.add_child(fin)
	var lv := Kit.button("Leave: the progress is lost" if not _ask_leave else "Really leave?", func(): _leave(), Vector2(200, 44))
	lv.name = "TrialLeave"
	row.add_child(lv)


func _leave() -> void:
	if not _ask_leave:
		_ask_leave = true
		_build()
		return
	_ask_leave = false
	_act(func(): return GameTrials.leave(dynasty))


## Runs one action of the trials, says what it told, lets the screen behind it know and draws the rows again.
func _act(action: Callable) -> void:
	_line = str(action.call())
	_ask_leave = false
	_changed()


func _fight() -> void:
	var b := GameTrials.begin_master(dynasty)
	_line = "" if b != null else "The master is not ready."
	_changed()


func _changed() -> void:
	if on_change.is_valid():
		on_change.call()
	if dynasty.battle != null or dynasty.state != "life" or not is_inside_tree():
		return   # a fight (or the end of the line) takes the screen over; this panel goes with it
	_build()


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
