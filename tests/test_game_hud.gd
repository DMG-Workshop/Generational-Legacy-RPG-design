## The panes that stay up and the character panes (docs/PLAYER_INTERFACE.md, slices 3 and 4): the minimap's ground (GameMiniMap), item
## icons for every item (data/art/icons.json), the status, minimap and journal panes opening in their corners when the open world
## starts and staying closed once closed (until the Menu opens them), a double click on the heir opening the figure pane, wearing
## and taking off gear by drag and drop and double click, the pack as a grid, putting an item in a bag and taking it out, and a
## bag's own pane.
## Run: godot --headless --path . -s res://tests/test_game_hud.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const PaneKit := preload("res://ui/play/pane_kit.gd")
const ItemIcon := preload("res://ui/play/item_icon.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const StatusPane := preload("res://ui/play/status_pane.gd")
const MinimapPane := preload("res://ui/play/minimap_pane.gd")
const JournalPane := preload("res://ui/play/journal_pane.gd")
const FigurePane := preload("res://ui/play/figure_pane.gd")
const PackPane := preload("res://ui/play/pack_pane.gd")
const ItemSlot := preload("res://ui/play/item_slot.gd")

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
	UiSettings.path = "user://test_hud.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_hud_save.json"
	test_minimap()
	test_icons()
	await test_hud()
	await test_figure_and_pack()
	DirAccess.remove_absolute(UiSettings.path)
	print("hud tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_minimap() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	var sb := GameSandbox.start(d)
	var kinds := GameMiniMap.kinds(d, sb.heir.x, sb.heir.y, 5)
	ok(kinds.size() == 11 and (kinds[0] as Array).size() == 11, "the ground nearby is 11 by 11 for a radius of 5")
	ok(str(kinds[5][5]) == GameRelief.kind(GameWorldGen.tile(d, sb.heir.x, sb.heir.y)), "its middle is the heir's own tile")
	ok(GameMiniMap.kinds(d, sb.heir.x, sb.heir.y, 5) == kinds, "and the same every time")
	var out := GameMiniMap.kinds(d, -3, -3, 2)
	ok(str(out[0][0]) == GameRelief.kind(GameWorldGen.tile(d, -5, -5)), "beyond the world's edge it is whatever the world makes of it (sea)")
	d.built[GameBuild.key(sb.heir.x + 1, GameBuild.SURFACE, sb.heir.y)] = "wall"
	ok(str(GameMiniMap.kinds(d, sb.heir.x, sb.heir.y, 2)[2][3]) == "wall", "a piece the family built shows as that piece")
	var img := MinimapPane.make_image(d, sb.heir.x, sb.heir.y, 5)
	ok(img.get_width() == 11 and img.get_height() == 11, "and the picture is a pixel a tile")


func test_icons() -> void:
	ok(ItemIcon.validate().is_empty(), "the icon data is sound: %s" % str(ItemIcon.validate()))
	var bad := 0
	var seen := {}
	for id in GameData.items:
		var t := ItemIcon.texture(str(id))
		if t == null or t.get_width() != 12:
			bad += 1
		seen[ItemIcon.glyph_of(str(id))] = true
	ok(bad == 0, "every item has an icon")
	ok(seen.size() >= 8, "drawn with several different glyphs (%d)" % seen.size())
	ok(ItemIcon.glyph_of("iron_sword") == "sword" and ItemIcon.glyph_of("satchel#4") == "bag" and ItemIcon.glyph_of("satchel") == "bag", "a sword is a sword and a numbered bag a bag")
	ok(ItemIcon.color_of("iron_sword") != ItemIcon.color_of("leather_boots"), "iron and leather are not the same colour")
	ok(ItemIcon.texture("iron_sword") == ItemIcon.texture("iron_sword"), "an icon is made once")
	var broken: Array = ItemIcon.data()["glyphs"]["sword"].duplicate()
	ItemIcon.data()["glyphs"]["sword"] = ["short"]
	ok(not ItemIcon.validate().is_empty(), "a glyph with the wrong rows is found")
	ItemIcon.data()["glyphs"]["sword"] = broken
	ok(ItemIcon.validate().is_empty(), "and the data is whole again after")


func _app() -> Node:
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(4)
	return app


func _pane(map: Node, script: Script, key: String = "") -> Control:
	for c in map.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion() and (key == "" or str(c.get_meta("pane")) == key):
			return c
	return null


func _slots(node: Node, out: Array = []) -> Array:
	for c in node.get_children():
		if c is ItemSlot:
			out.append(c)
		_slots(c, out)
	return out


func _labels(node: Node, out: Array = []) -> Array:
	for c in node.get_children():
		if c is Label:
			out.append(str(c.text))
		_labels(c, out)
	return out


func test_hud() -> void:
	var app := await _app()
	var map: Node = app.current
	var status := _pane(map, StatusPane)
	var mini := _pane(map, MinimapPane)
	var journal := _pane(map, JournalPane)
	ok(status != null and mini != null and journal != null, "the status, minimap and journal panes open with the open world")
	ok(status != null and status.has_meta("pane_hud") and not status.has_meta("modal") and not map._modal_open(), "they stay up and the world does not wait for them")
	var room := UiSettings.room(map)
	ok(status != null and status.position.x < 100.0 and status.position.y < 120.0, "the status pane is in the top left: %s" % str(status.position))
	ok(mini != null and mini.position.x > room.x - mini.size.x - 40.0, "the minimap in the top right: %s" % str(mini.position))
	ok(journal != null and journal.position.y > room.y - journal.size.y - 40.0 and journal.position.x < 100.0, "the journal in the bottom left: %s" % str(journal.position))
	# they show the heir
	var d: GameDynasty = app.dynasty
	d.heir.hp = maxi(1, d.heir.hp - 3)
	status.refresh()
	var found := false
	for t in _labels(status):
		if ("%d of %d" % [d.heir.hp, d.heir.max_hp()]) in t:
			found = true
	ok(found, "the status pane shows the heir's health as it is now")
	map.sb.log.append({"kind": "talk", "text": "A test line of the journal."})
	journal.refresh()
	var journal_text := ""
	for c in journal.find_children("*", "RichTextLabel", true, false):
		journal_text += (c as RichTextLabel).text
	ok("A test line of the journal." in journal_text, "the journal shows what was logged")
	mini.refresh()
	ok(mini._image.texture != null, "the minimap has its ground drawn")
	# closing one keeps it closed, the Menu brings it back
	PaneKit.close(status)
	await _frames(2)
	ok(not PaneKit.wanted("status_pane"), "a pane that is closed is remembered as closed")
	map._toggle_hud(StatusPane)
	await _frames(2)
	ok(_pane(map, StatusPane) != null and PaneKit.wanted("status_pane"), "and the Menu opens it again")
	map._toggle_hud(StatusPane)
	await _frames(2)
	ok(_pane(map, StatusPane) == null and not PaneKit.wanted("status_pane"), "and closes it again")
	map._toggle_hud(StatusPane)
	await _frames(2)
	app.queue_free()
	await _frames(2)


func test_figure_and_pack() -> void:
	var app := await _app()
	var map: Node = app.current
	var d: GameDynasty = app.dynasty
	d.heir.equipment = {"weapon": "", "armor": "", "trinket": ""}
	d.heir.inventory = ["iron_sword"]
	# a double click on the heir opens the character
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var centre := Vector2(0, map.BAR) + area * 0.5
	map.sb.creatures = []
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = centre
	e.double_click = true
	map._gui_input(e)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = centre
	map._gui_input(up)
	await _frames(2)
	var fig := _pane(map, FigurePane)
	ok(fig != null, "a double click on the heir opens the figure pane")
	ok(fig != null and not fig.has_meta("modal"), "which does not stop the world")
	# wear by drop
	var weapon: ItemSlot = null
	for s in _slots(fig):
		if s.tag == "weapon":
			weapon = s
	ok(weapon != null and weapon.item == "", "the weapon square is empty")
	var data := {"item": "iron_sword", "from": "pack"}
	ok(weapon._can_drop_data(Vector2.ZERO, data), "a sword can be dropped on the weapon square")
	ok(not weapon._can_drop_data(Vector2.ZERO, {"item": "leather_armor", "from": "pack"}), "armour cannot")
	weapon._drop_data(Vector2.ZERO, data)
	await _frames(2)
	ok(d.heir.equipment["weapon"] == "iron_sword" and "iron_sword" not in d.heir.inventory, "dropping it wears it")
	for s in _slots(fig):
		if s.tag == "weapon":
			weapon = s
	ok(weapon.item == "iron_sword", "and the square shows it")
	weapon.on_double.call()
	await _frames(2)
	ok(d.heir.equipment["weapon"] == "" and "iron_sword" in d.heir.inventory, "a double click takes it off")
	# the pack
	map._open_pack("")
	await _frames(2)
	var pack := _pane(map, PackPane, "pack_pane")
	ok(pack != null, "the pack opens")
	var squares := _slots(pack)
	ok(squares.size() >= 24 and squares[0].item == "iron_sword", "as a grid of squares with the sword in the first (%d)" % squares.size())
	# a bag: put the sword in, take it out
	d.heir.inventory.append("satchel")
	pack.refresh()
	await _frames(2)
	var bag := ""
	for s in _slots(pack):
		if s.item != "" and GameBags.is_bag(s.item):
			bag = s.item
	ok(bag != "" and "#" in bag, "a bag in the pack shows as a numbered bag: %s" % bag)
	var bag_square: ItemSlot = null
	for s in _slots(pack):
		if s.item == bag:
			bag_square = s
	ok(bag_square._can_drop_data(Vector2.ZERO, {"item": "iron_sword", "from": "pack"}), "a thing can be dropped on a bag")
	ok(not bag_square._can_drop_data(Vector2.ZERO, {"item": bag, "from": "pack"}), "but a bag not on itself")
	bag_square._drop_data(Vector2.ZERO, {"item": "iron_sword", "from": "pack"})
	await _frames(2)
	ok(GameBags.contents(d.heir, bag) == ["iron_sword"] and "iron_sword" not in d.heir.inventory, "dropping it on the bag puts it in")
	for s in _slots(pack):   # (the grid was made again)
		if s.item == bag:
			bag_square = s
	bag_square.on_double.call()   # a double click opens the bag's own pane
	await _frames(2)
	var bag_pane := _pane(map, PackPane, "pack_pane:" + bag)
	ok(bag_pane != null and bag_pane.bag == bag, "a double click on a bag opens its own pane")
	var inner := _slots(bag_pane)
	ok(inner.size() == GameBags.slots(bag) and inner[0].item == "iron_sword", "with one square for each slot, the sword in the first")
	ok(bag_pane._can_drop_data(Vector2.ZERO, {"item": "healing_potion", "from": "pack"}) == (GameBags.where(d.heir, "healing_potion") != null), "a bag's pane takes only what the heir carries")
	# take it out by dropping it on the pack
	ok(pack._can_drop_data(Vector2.ZERO, {"item": "iron_sword", "from": "bag"}), "the pack takes a thing from a bag")
	pack._drop_data(Vector2.ZERO, {"item": "iron_sword", "from": "bag"})
	await _frames(2)
	ok("iron_sword" in d.heir.inventory and GameBags.contents(d.heir, bag).is_empty(), "and it comes out")
	# a bag that is left behind takes its pane with it
	GameCarry.drop(d, bag)
	await _frames(2)
	bag_pane.refresh()
	await _frames(2)
	ok(_pane(map, PackPane, "pack_pane:" + bag) == null, "a bag left behind takes its pane with it")
	# the Menu has the panes
	map._open_menu()
	await _frames(2)
	var menu: PopupMenu = null
	for c in map.get_children():
		if c is PopupMenu:
			menu = c
	var names: Array = []
	for i in menu.item_count:
		names.append(menu.get_item_text(i))
	ok("Character" in names and "Pack" in names and "Status" in names and "Nearby map" in names and "Journal" in names, "the Menu lists the character, the pack and the panes that stay up: %s" % str(names))
	app.queue_free()
	await _frames(2)
