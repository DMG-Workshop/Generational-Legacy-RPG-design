## The dynasty statistics: heirs lived, causes of death, the greatest heir, gold per kept heir (GameStats),
## the counts holding once heirs are folded into the Ages, a save round trip, and the chronicle's Statistics tab.
## godot --headless --path . -s res://tests/test_game_stats.gd
extends SceneTree

const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _new(s: int) -> GameDynasty:
	var d := GameDynasty.new_game(s, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## Ends the heir's life and takes the successor, the way a real succession does.
func _succeed(d: GameDynasty) -> void:
	d._die("old age")
	d.choose_heir(0)


func _run() -> void:
	# A new dynasty: the founder is living, nothing has died yet.
	var d := _new(61)
	var s := GameStats.summary(d)
	ok(s["generations"] == 1 and s["heirs"] == 1, "a new dynasty has one heir in generation 1")
	ok((s["causes"] as Array).is_empty() and s["legends"] == 0, "no deaths or legends yet")
	ok((s["best"] as Dictionary).is_empty(), "no best heir before anyone has died")
	ok(s["ages_reached"] == [1], "a new house has reached Age 1")
	ok(s["gold"].size() == 1 and s["gold"][0]["gen"] == 1, "the living founder is the only gold entry")

	# Two successions by old age: three heirs in all, two deaths counted.
	_succeed(d)
	_succeed(d)
	s = GameStats.summary(d)
	ok(s["generations"] == 3 and s["heirs"] == 3, "two deaths and the living heir make three heirs")
	ok(s["causes"] == [["old age", 2]], "both deaths are counted as old age")
	ok(not (s["best"] as Dictionary).is_empty(), "a best heir is named once someone has died")
	ok(s["gold"].size() == 3 and s["gold"][-1]["gen"] == 3, "every kept heir has a gold entry, the living one last")

	# Old heirs fold into the Ages: they still count, and the founder stays.
	var keep = GameAges.settings()["history_full_keep"]
	GameAges.settings()["history_full_keep"] = 2
	var f := _new(62)
	for i in 6:
		_succeed(f)
	GameAges.settings()["history_full_keep"] = keep
	s = GameStats.summary(f)
	ok(f.ages.folded_heirs() > 0, "heirs past history_full_keep are folded")
	ok(s["heirs"] == 7 and s["generations"] == 7, "folded heirs still count: seven heirs by generation seven")
	ok(s["causes"] == [["old age", 6]], "folded deaths still count by cause")
	ok(s["gold"].size() < 7, "gold is kept only for the heirs in full")
	ok((s["ages_reached"] as Array).has(s["age"]) and (s["ages_reached"] as Array).size() >= 1, "the Ages reached include the current Age, folded or not")
	var reached: Array = GameStats.summary(f)["ages_reached"]
	ok(reached == reached.duplicate(), "Ages reached is a list of distinct Ages")
	var fp := _panel_for(f)
	await process_frame
	await process_frame
	var tab := _tab_text(fp, "Statistics")
	fp.queue_free()
	ok(tab.find("Ages reached") >= 0, "the Statistics tab names the Ages reached")

	# Gold over time: each Age has an average of the gold its heirs had at death, and it survives folding.
	var ga: Array = GameStats.summary(f)["gold_by_age"]
	ok(ga.size() >= 1 and int(ga[0]["known"]) > 0, "each Age that has deaths has a known gold figure")
	var kept_known := 0
	for row in f.ages.age_rows(f):
		kept_known += int(row.get("gold_known", 0))
	ok(kept_known == 6, "all six deaths have their gold counted, folded or not")
	# An Age saved before gold was kept reads as not recorded, not as zero.
	var old_row := {"age": 9, "from": 1, "to": 1, "heirs": 1, "greatest": {}, "legends": [], "causes": {}}
	f.ages.summaries.append(old_row)
	var nine := {}
	for a in GameStats.summary(f)["gold_by_age"]:
		if int(a["age"]) == 9:
			nine = a
	ok(not nine.is_empty() and int(nine["known"]) == 0 and int(nine["average"]) == -1, "an Age with no gold figure reads as not recorded, not zero")
	f.ages.summaries.pop_back()

	# A save round trip gives the same statistics.
	var r := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	ok(JSON.stringify(GameStats.summary(r)) == JSON.stringify(GameStats.summary(f)), "the statistics are the same after a save and load")

	# The chronicle has the Statistics tab with the heir count in it.
	var panel: Control = ChroniclePanel.new()
	panel.dynasty = _new(63)
	root.add_child(panel)
	await process_frame
	await process_frame
	var text := _tab_text(panel, "Statistics")
	ok(text != "", "the chronicle has a Statistics tab")
	ok(text.find("Heirs") >= 0, "and the tab shows the heirs lived")
	panel.queue_free()

	print("stats tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _panel_for(d: GameDynasty) -> Control:
	var p: Control = ChroniclePanel.new()
	p.dynasty = d
	root.add_child(p)
	return p


func _tab_text(panel: Node, tab: String) -> String:
	for c in _all(panel):
		if c is RichTextLabel and c.name == tab:
			return (c as RichTextLabel).text
	return ""


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out
