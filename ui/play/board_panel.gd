## Notice board: side quests offered here, and the house's quest log.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes

var body: VBoxContainer
var confirm_abandon: String = ""   # quest id waiting for a second click on Abandon
var scrolls: Array = []            # the two column ScrollContainers, rebuilt with the board


func _ready() -> void:
	var v := Kit.overlay(self, "Notice Board  -  %s" % dynasty.world.here().get("name", ""))
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	_build([])


func _build(news: Array) -> void:
	var keep: Array = scrolls.map(func(sc): return sc.scroll_vertical)
	scrolls = []
	Kit.clear(body)
	var d := dynasty
	var qs := d.quests
	var town := d.world.location
	var max_active := int(GameData.bal("quest_max_active"))
	body.add_child(Kit.label("Obligations %d / %d    Notices completed: %s (%d different)" % [qs.active.size(), max_active, GameText.num(qs.total_done()), qs.done.size()], 15, Kit.DIM))
	if not news.is_empty():
		var n := Kit.label("\n".join(news), 14, Kit.GOOD)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(n)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)

	var posted := _column(cols, "Posted in %s" % GameQuests.place_name(town))
	var offers := qs.postings(d, town)
	if offers.is_empty():
		posted.add_child(_wrap("Nothing new on the board this generation. Notices go up as the years turn and the house's deeds become known.", 14, Kit.DIM))
	for q in offers:
		_offer_card(posted, q)

	var mine := _column(cols, "House obligations")
	if qs.active.is_empty():
		mine.add_child(_wrap("The house owes no one anything. Take down a notice to add it here; unfinished ones pass to the next heir.", 14, Kit.DIM))
	# Rewards claimable here first, then other finished ones, then the rest.
	var claim_here := func(e): return qs.is_complete(e) and GameQuests.def(e["id"])["giver"] == town
	for e in qs.active.filter(claim_here):
		_active_card(mine, e)
	for e in qs.active.filter(func(e): return qs.is_complete(e) and not claim_here.call(e)):
		_active_card(mine, e)
	for e in qs.active.filter(func(e): return not qs.is_complete(e)):
		_active_card(mine, e)
	if not qs.done.is_empty():
		mine.add_child(Kit.label("Completed", 16, Kit.ACCENT))
		var names: Array = qs.done.map(func(id): return GameQuests.def(id).get("name", id) + (" x%s" % GameText.num(qs.times_done(id)) if qs.times_done(id) > 1 else ""))
		mine.add_child(_wrap(", ".join(names), 13, Kit.DIM))
	_restore_scroll.call_deferred(keep)


## A rebuild must not jump the lists back to the top: the card the player just pressed stays put.
func _restore_scroll(keep: Array) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	for i in mini(keep.size(), scrolls.size()):
		scrolls[i].scroll_vertical = keep[i]


## A titled, scrolling column; returns the list to fill.
func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	col.add_child(Kit.label(title, 18, Kit.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	scrolls.append(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Card frame with the quest's name and kind; returns the inner box.
func _card(list: VBoxContainer, q: Dictionary) -> VBoxContainer:
	var p := Kit.panel()
	list.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var t := Kit.label(q["name"], 17, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if q.has("chain"):
		row.add_child(Kit.label("Story", 13, Color("#c58fe8")))
	elif q.get("repeatable", false):
		row.add_child(Kit.label("Bounty", 13, Kit.DIM))
	return v


func _offer_card(list: VBoxContainer, q: Dictionary) -> void:
	var d := dynasty
	var v := _card(list, q)
	v.add_child(Kit.label("Posted by %s" % q.get("poster", "the town"), 13, Kit.DIM))
	v.add_child(_wrap(q.get("text", ""), 14, Kit.TEXT))
	v.add_child(_wrap("Task: %s" % GameQuests.objective_text(q), 14, Kit.TEXT))
	v.add_child(_wrap("Reward: %s" % GameQuests.reward_text(d, q), 14, Kit.GOOD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var id: String = q["id"]
	var why := d.quests.accept_block(d, id)
	var b := Kit.button("Accept", func(): _act(d.quests.accept(d, id)), Vector2(110, 32))
	b.disabled = why != ""
	row.add_child(b)
	if why != "":
		var l := Kit.label(why, 13, Kit.BAD)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)


func _active_card(list: VBoxContainer, e: Dictionary) -> void:
	var d := dynasty
	var qs := d.quests
	var id: String = e["id"]
	var q := GameQuests.def(id)
	var v := _card(list, q)
	var complete := qs.is_complete(e)
	var goal := GameQuests.goal(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var task := _wrap(GameQuests.objective_text(q), 14, Kit.TEXT)
	row.add_child(task)
	if GameQuests.kind(q) == "kill":
		var pb := Kit.bar(Kit.GOOD if complete else Kit.ACCENT, goal, int(e["progress"]), Vector2(120, 14))
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		row.add_child(Kit.label("%d / %d" % [int(e["progress"]), goal], 14))
	var by := "Taken up by %s in generation %s, from the board in %s." % [e["by"], GameText.num(int(e["gen"])), GameQuests.place_name(q["giver"])]
	v.add_child(_wrap(by, 13, Kit.DIM))
	v.add_child(_wrap("Reward: %s" % GameQuests.reward_text(d, q), 14, Kit.GOOD))
	var here: bool = d.world.location == q["giver"]
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	if complete:
		var turn := Kit.button("Turn in", func(): _act(qs.turn_in(d, id)), Vector2(110, 32))
		turn.disabled = not here
		buttons.add_child(turn)
	if confirm_abandon == id:
		buttons.add_child(Kit.button("Really abandon", func(): _abandon(id), Vector2(150, 32)))
		buttons.add_child(Kit.button("Keep it", func(): confirm_abandon = ""; _build([]), Vector2(100, 32)))
	else:
		buttons.add_child(Kit.button("Abandon", func(): confirm_abandon = id; _build([]), Vector2(110, 32)))
	var state := ""
	if complete:
		state = "Done. Claim the reward here." if here else "Done. Report to the board in %s." % GameQuests.place_name(q["giver"])
	var s := Kit.label(state, 13, Kit.GOOD)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(s)


func _abandon(id: String) -> void:
	confirm_abandon = ""
	_act(dynasty.quests.abandon(dynasty, id))


func _act(msgs: Array) -> void:
	_build(msgs)
	if on_change.is_valid():
		on_change.call()


## Lines for the life screen's right-hand panel.
static func summary_lines(d: GameDynasty) -> Array:
	var out: Array = []
	for e in d.quests.active:
		var q := GameQuests.def(e["id"])
		var giver := GameQuests.place_name(q["giver"])
		if d.quests.is_complete(e):
			out.append("%s: done, report to %s" % [q["name"], giver])
			continue
		match GameQuests.kind(q):
			"kill":
				out.append("%s %d/%d (%s)" % [q["name"], int(e["progress"]), GameQuests.goal(q), giver])
			"visit":
				out.append("%s: go to %s (%s)" % [q["name"], GameQuests.place_name(q["objective"]["target"]), giver])
			_:
				out.append("%s: waiting (%s)" % [q["name"], giver])
	return out
