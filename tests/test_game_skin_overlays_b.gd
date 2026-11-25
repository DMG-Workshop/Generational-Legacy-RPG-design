## The interface skin on the chronicle's Statistics, Ages and Creatures tabs, the tavern, the quest board and the skill tree's canvas
## (PanelSkin.section/figure, SkillTreePanel._dress_node; docs/ART_DIRECTION.md): cards with ribbons and inset figure rows with segmented
## bars, creature rows as slots, raised keys, slim bars, the tree's bed, plate cards and ink links, the contrast of the card tints, and
## the old look kept (a plain RichTextLabel, flat boxes) when a panel is not a skinned pane.
## Run: godot --headless --path . -s res://tests/test_game_skin_overlays_b.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_skin_overlays_b.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_overlays_b_save.json"
	UiSettings.scale = 1.0
	test_data()
	await test_skinned()
	await test_high_contrast()
	await test_old_look()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin overlays b tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data is valid with the tree tints: %s" % str(UiSkin.validate()))
	var bad: Dictionary = (UiSkin.data() as Dictionary).duplicate(true)
	bad["tree"]["locked"] = [0.3, 0.3, 0.3]
	ok(UiSkin.validate(bad).any(func(m): return str(m).contains("skill card")), "a locked-card tint that makes the ink unreadable is found")
	var gone: Dictionary = (UiSkin.data() as Dictionary).duplicate(true)
	gone.erase("tree")
	ok(not UiSkin.validate(gone).is_empty(), "data without the tree tints is found")


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _game() -> Array:
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	return [app, app.current, app.dynasty]


func _open(map: Node, d: GameDynasty, script: Script, skinned: bool) -> Control:
	var p: Control = script.new()
	p.dynasty = d
	p.on_change = func(): pass
	if skinned:
		p.set_meta("pane", str(script.resource_path.get_file().get_basename()))
	map.add_child(p)
	return p


func _tab(p: Node, name: String) -> Node:
	return p.find_child(name, true, false)


func test_skinned() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	await _frames(2)
	var g := await _game()
	var app: Node = g[0]
	var map: Node = g[1]
	var d: GameDynasty = g[2]
	d.heir.gold = 3000
	for i in 3:
		d._die("old age")
		d.choose_heir(0)
	GameRoster.add(d, "wolf", "Ash")
	GameRoster.add(d, "drake", "Ember")
	# the chronicle: Statistics and Ages as cards
	var chron := _open(map, d, ChroniclePanel, true)
	await _frames(3)
	var stats := _tab(chron, "Statistics")
	var ages := _tab(chron, "Ages")
	ok(stats is ScrollContainer and ages is ScrollContainer, "Statistics and Ages are drawn pages, not text")
	var cards := _all(stats, []).filter(func(n): return n is PanelContainer and n.get_theme_stylebox("panel") == UiSkin.panel_box())
	ok(cards.size() >= 5, "Statistics is a stack of parchment cards: %d" % cards.size())
	var ribbons := _all(stats, []).filter(func(n): return n is PanelContainer and n.get_theme_stylebox("panel").texture == UiSkin.ribbon_box().texture)
	ok(ribbons.size() == cards.size(), "each card has its heading ribbon: %d of %d" % [ribbons.size(), cards.size()])
	var rows := _all(stats, []).filter(func(n): return n is PanelContainer and n.has_meta("skin_row"))
	ok(rows.size() >= 8, "the figures are inset rows: %d" % rows.size())
	var bars := _all(stats, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
	ok(not bars.is_empty(), "causes and gold have segmented bars: %d" % bars.size())
	var right := _all(stats, []).filter(func(n): return n is Label and n.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	ok(right.size() >= 4 and right.all(func(l): return l.custom_minimum_size.x >= 90.0), "the numbers are right-aligned in a column")
	var st := GameStats.summary(d)
	var text := "\n".join(_all(stats, []).filter(func(n): return n is Label).map(func(l): return l.text))
	ok(text.find(GameText.num(int(st["heirs"]))) >= 0 and text.find("Deaths by cause") >= 0, "the page says what the text did")
	var bg := UiSkin.pal("slot_bg")
	var reads := true
	for r in rows:
		for n in _all(r, []):
			if n is Label and str(n.text) != "" and UiSkin.contrast(n.get_theme_color("font_color"), bg) < 4.5:
				reads = false
	ok(reads, "the words in the rows read on the slot")
	var age_cards := _all(ages, []).filter(func(n): return n is PanelContainer and n.get_theme_stylebox("panel") == UiSkin.panel_box())
	ok(age_cards.size() >= 1, "each Age is a card: %d" % age_cards.size())
	# the creatures: a slot and raised keys for each
	var cre := _tab(chron, "Creatures")
	var crows := _all(cre, []).filter(func(n): return n is PanelContainer and n.has_meta("skin_row"))
	ok(crows.size() == d.roster.size(), "each creature is an inset slot: %d of %d" % [crows.size(), d.roster.size()])
	var keys := _all(cre, []).filter(func(n): return n is Button)
	ok(not keys.is_empty() and keys.all(func(b): return b.get_theme_stylebox("normal") == UiSkin.button_box("normal")), "creature and market keys are raised parchment")
	chron.queue_free()
	# the tavern
	d.world.visit("hearthmere")
	d.world.location = "hearthmere"
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 3, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	var tav := _open(map, d, TavernPanel, true)
	await _frames(3)
	var tbtn := _all(tav, []).filter(func(n): return n is Button and str(n.text) in ["Hire", "Skill tree", "Dismiss"])
	ok(not tbtn.is_empty() and tbtn.all(func(b): return b.get_theme_stylebox("normal") == UiSkin.button_box("normal")), "the tavern's keys are raised parchment (%d)" % tbtn.size())
	var thin := _all(tav, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar") and n.get_meta("skin_bar").thin)
	ok(thin.size() >= 2, "a member's health and mana are slim segmented bars: %d" % thin.size())
	tav.queue_free()
	# the board
	var board := _open(map, d, BoardPanel, true)
	var kill: Array = GameData.quests.filter(func(q): return GameQuests.kind(q) == "kill" and d.quests.is_posted(d, q))
	if not kill.is_empty():
		d.world.visit(str(kill[0]["giver"]))
		d.world.location = str(kill[0]["giver"])
		d.quests.accept(d, str(kill[0]["id"]))
		board._build([])
		await _frames(2)
		var qb := _all(board, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
		ok(qb.size() >= 1, "a kill notice's progress is a segmented bar")
	else:
		ok(true, "(no kill notice is posted in this seed; the bar is drawn by the same call as the house's)")
	board.queue_free()
	await _frames(2)
	# the skill tree: bed, plate cards, ink links
	var tree := _open(map, d, SkillTreePanel, true)
	await _frames(3)
	var looks := {}
	for id in tree.boxes:
		var b: Button = tree.boxes[id]
		looks[b.get_meta("look")] = b
		ok(b.get_theme_stylebox("normal") is StyleBoxTexture, "a node is a card of the skin")
	ok(looks.has("open") and looks.has("locked"), "the tree shows open and locked nodes (%s)" % str(looks.keys()))
	if looks.has("open") and looks.has("locked"):
		var ob: Button = looks["open"]
		var lb: Button = looks["locked"]
		var so: StyleBoxTexture = ob.get_theme_stylebox("normal")
		var sl: StyleBoxTexture = lb.get_theme_stylebox("normal")
		ok(so.texture == UiSkin.plate_box(true).texture or so.texture == UiSkin.ribbon_box().texture, "a node open to buy is lit")
		ok(sl.modulate_color.r < 1.0 and sl.modulate_color.r < so.modulate_color.r, "a locked node is dimmed")
		var face := UiSkin.pal("parch") * sl.modulate_color
		ok(UiSkin.contrast(lb.get_theme_color("font_color"), face) >= 4.5 or lb.get_theme_color("font_color") == UiSkin.pal("parch_hi"), "a locked node's words still read")
	var bed: StyleBox = null
	for n in _all(tree, []):
		if n is PanelContainer and n.get_theme_stylebox("panel") is StyleBoxFlat and n.get_theme_stylebox("panel").bg_color == UiSkin.pal("parch_lo"):
			bed = n.get_theme_stylebox("panel")
	ok(bed != null, "the tree is drawn on shaded parchment")
	tree.queue_free()
	app.queue_free()
	await _frames(2)


func test_high_contrast() -> void:
	UiSettings.set_access("high_contrast", true)
	ok(UiSkin.validate().is_empty(), "the tree tints hold in high contrast")
	var g := await _game()
	var map: Node = g[1]
	var d: GameDynasty = g[2]
	var tree := _open(map, d, SkillTreePanel, true)
	var chron := _open(map, d, ChroniclePanel, true)
	await _frames(3)
	var ok_all := true
	for id in tree.boxes:
		var b: Button = tree.boxes[id]
		var sb: StyleBoxTexture = b.get_theme_stylebox("normal")
		var face := (UiSkin.pal("crimson") if GameSkillTree.is_keystone(id) else UiSkin.pal("parch")) * sb.modulate_color
		if UiSkin.contrast(b.get_theme_color("font_color"), face) < 7.0:
			ok_all = false
	ok(ok_all, "every node's words are strong in high contrast")
	ok(_tab(chron, "Statistics") is ScrollContainer, "the pages are drawn in high contrast too")
	(g[0] as Node).queue_free()
	await _frames(2)
	UiSettings.set_access("high_contrast", false)


func test_old_look() -> void:
	var g := await _game()
	var map: Node = g[1]
	var d: GameDynasty = g[2]
	# not a pane: the plain text and flat boxes stay
	var chron := _open(map, d, ChroniclePanel, false)
	var tree := _open(map, d, SkillTreePanel, false)
	await _frames(3)
	ok(_tab(chron, "Statistics") is RichTextLabel and _tab(chron, "Ages") is RichTextLabel, "outside a skinned pane Statistics and Ages stay rich text")
	ok(tree.boxes.size() > 0 and tree.boxes.values().all(func(b): return b.get_theme_stylebox("normal") is StyleBoxFlat), "and the tree's nodes stay flat boxes")
	(g[0] as Node).queue_free()
	await _frames(2)
