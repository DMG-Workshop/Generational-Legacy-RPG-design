## The family tree: one entry per generation from the dynasty's own records (GameFamilyTree), older
## heirs counted once folded into the Ages, damaged names shown as fewer names, and the chronicle's
## Family Tree tab showing it. Logic is checked directly; the tab is checked by opening the panel.
## godot --headless --path . -s res://tests/test_game_family_tree.gd
extends SceneTree

const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const DIR := "user://test_family_tree/"

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


func _reload(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


## Ends the heir's life and takes the successor, the way a real succession does.
func _succeed(d: GameDynasty) -> void:
	d._die("old age")
	d.choose_heir(0)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	# A new dynasty: one generation, the living founder, nobody else yet.
	var d := _new(51)
	var t := GameFamilyTree.tree(d)
	ok(t["folded"] == 0, "a new dynasty has nothing folded")
	ok(t["generations"].size() == 1, "a new dynasty has one generation")
	var g1: Dictionary = t["generations"][0]
	ok(g1["gen"] == 1 and g1["heirs"].size() == 1, "generation 1 holds the living founder")
	var founder: Dictionary = g1["heirs"][0]
	ok(founder["living"] and founder["name"] == d.heir.full_name(), "the founder is living and named")
	ok(founder["parents"].is_empty() and founder["spouse"] == "" and founder["children"].is_empty(), "no parents, spouse or children yet")

	# The founder dies, the child succeeds: the founder is kept with their cause of death.
	var founder_name := d.heir.full_name()
	_succeed(d)
	t = GameFamilyTree.tree(d)
	var gens: Array = t["generations"]
	ok(gens.size() == 2 and gens[0]["gen"] == 1 and gens[1]["gen"] == 2, "a death adds the next generation")
	var dead: Dictionary = gens[0]["heirs"][0]
	ok(not dead["living"] and dead["cause"] == "old age" and dead["name"] == founder_name, "the dead founder keeps their death")
	var heir2: Dictionary = gens[1]["heirs"][0]
	ok(heir2["living"] and heir2["parents"] == d.heir.parent_names, "the living heir lists the parents on their own record")

	# Marriage shows up on the living heir, and the founder's child is named under them.
	var kid_name: String = d.heir.full_name()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	d.found_family(0)
	var spouse_name: String = d.heir.spouse.name
	t = GameFamilyTree.tree(d)
	heir2 = t["generations"][-1]["heirs"][0]
	ok(heir2["spouse"] == spouse_name, "the living heir shows their spouse")
	var children_now: Array = heir2["children"]
	ok(children_now.size() == d.heir.children.size(), "children are listed for the living heir")

	# Legacy echoes appear under the generation that earned them.
	d._add_echo("glory", "life", "Tess lived a celebrated life", 0.1)
	t = GameFamilyTree.tree(d)
	var living_echoes: Array = t["generations"][-1]["heirs"][0]["echoes"]
	ok(living_echoes.has("Tess lived a celebrated life"), "an echo from this generation is shown on its heir")
	ok(not (t["generations"][0]["heirs"][0]["echoes"] as Array).has("Tess lived a celebrated life"), "and not on an earlier generation")

	# Old heirs fold into the Ages: they are counted, not named, and the founder stays.
	var keep = GameAges.settings()["history_full_keep"]
	GameAges.settings()["history_full_keep"] = 2
	var f := _new(52)
	for i in 6:
		_succeed(f)
	GameAges.settings()["history_full_keep"] = keep
	t = GameFamilyTree.tree(f)
	ok(t["folded"] > 0, "heirs past history_full_keep are folded and counted")
	var named := 0
	for entry in t["generations"]:
		named += (entry["heirs"] as Array).size()
	ok(named + t["folded"] == 7, "every heir is either named or counted (%d + %d = 7)" % [named, t["folded"]])
	ok(t["generations"][0]["gen"] == 1, "the founder's generation is still shown")

	# A save survives: the tree reads the same after a round trip, and an old save shows the living heir.
	var r := _reload(d)
	ok(JSON.stringify(GameFamilyTree.tree(r)) == JSON.stringify(GameFamilyTree.tree(d)), "the tree is the same after a save and load")
	var bare := _new(53)
	bare.history = []
	bare.echoes = []
	ok(GameFamilyTree.tree(bare)["generations"].size() == 1, "an old save with no history still shows the living heir")

	# Damaged names in a save are dropped, not crashed on.
	var names := GameFamilyTree._names(["Ann", 4, null, "Bo"])
	ok(names == ["Ann", "Bo"], "only text names survive a damaged save")
	ok(GameFamilyTree._names("nonsense").is_empty(), "a damaged name list is empty")

	# Once the saga has ended there is no living heir to show.
	var e := _new(54)
	e.state = "ended"
	var any_living := false
	for entry in GameFamilyTree.tree(e)["generations"]:
		for h in entry["heirs"]:
			any_living = any_living or h["living"]
	ok(not any_living, "an ended saga shows no living heir")

	# The chronicle has the tab, and it names the founder.
	var panel: Control = ChroniclePanel.new()
	panel.dynasty = _new(55)
	root.add_child(panel)
	await process_frame
	await process_frame
	var tab_text := _tab_text(panel, "Family Tree")
	ok(tab_text != "", "the chronicle has a Family Tree tab")
	ok(tab_text.find(panel.dynasty.heir.full_name()) >= 0, "and the tab names the living heir")
	ok(tab_text.find("Generation 1") >= 0, "the tab heads each generation")
	panel.queue_free()

	# A house with two generations and an echo: the tab draws the deaths, the marriage, the echo and the count of folded heirs.
	var fd := _new(56)
	_succeed(fd)
	var keep2 = GameAges.settings()["history_full_keep"]
	GameAges.settings()["history_full_keep"] = 1
	for i in 3:
		_succeed(fd)
	GameAges.settings()["history_full_keep"] = keep2
	fd.echoes.append({"kind": "glory", "key": "celebrated", "text": "Tess lived a celebrated life", "strength": 0.5, "gen": 1})
	var fp: Control = ChroniclePanel.new()
	fp.dynasty = fd
	root.add_child(fp)
	await process_frame
	await process_frame
	var ft := _tab_text(fp, "Family Tree")
	ok(ft.find("Generation 4") >= 0 and ft.find("died old age") >= 0 and ft.find("Generation 2") < 0, "the tab shows the kept generations and how their heirs died, and not the folded ones")
	ok(ft.find("legacy: Tess lived a celebrated life") >= 0, "the tab shows the echo of the generation it came from")
	ok(ft.find("2 earlier heirs are told in the Ages tab") >= 0 and fd.ages.folded_heirs() == 2, "folded heirs are counted in the tab, not named")
	fp.queue_free()

	_wipe()
	print("family tree tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


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


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
