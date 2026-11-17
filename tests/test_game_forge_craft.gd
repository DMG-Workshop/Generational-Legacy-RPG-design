## Crafting at the family's own forge (roadmap items 44 and 50): a built room with an anvil and a hearth is a forge that can make
## pieces anywhere (no town forge needed) for a share of the fee (`home_fee_mult`); the town forge's rules are the same as
## before; the sandbox's Use in such a room opens the workshop and changes nothing itself; the screen opens the workshop panel
## at the home forge, the world waits while it is open, and closing it gives the world back; and the data checks.
## Run: godot --headless --path . -s res://tests/test_game_forge_craft.gd
extends SceneTree

var fails := 0
var checks := 0
const S := -1


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_home_forge()
	test_use()
	await test_screen()
	await test_panel()
	print("forge craft tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A walled room with an anvil and a hearth in it; the heir has materials and gold.
func _forge() -> Dictionary:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 200)
	var b := GameBuild.base()
	var x := int(b["x"]) - 8
	var z := int(b["z"]) - 8
	for i in 6:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + 5), Vector2i(x, z + i), Vector2i(x + 5, z + i)]:
			if GameBuild.kind_at(d, pos.x, S, pos.y) == "":
				GameBuild.place(d, "wall", pos.x, S, pos.y)
	GameBuild.place(d, "anvil", x + 1, S, z + 1)
	GameBuild.place(d, "hearth", x + 2, S, z + 1)
	return {"d": d, "x": x, "z": z}


func _form_and_material(d: GameDynasty) -> Array:
	for f in GameLoot.data()["forms"]:
		var mats := GameCraft.materials_for(str(f["id"]))
		for m in mats:
			if GameCraft.have(d, str(m)) >= 20:
				return [str(f["id"]), str(m)]
	return ["", ""]


func test_data() -> void:
	ok(GameCraft.validate().is_empty() and GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameCraft.validate() + GameBuild.validate()))
	var s: Dictionary = GameCraft.data()["settings"]
	var keep: float = s["home_fee_mult"]
	s["home_fee_mult"] = 0.0
	ok(not GameCraft.validate().is_empty(), "a home fee of nothing is caught")
	s["home_fee_mult"] = 2.0
	ok(not GameCraft.validate().is_empty(), "a home fee above the town's is caught")
	s["home_fee_mult"] = keep
	ok(GameCraft.validate().is_empty(), "and putting it back clears it")
	var types: Array = GameBuild.data()["room_types"]
	var forge: Dictionary = {}
	for t in types:
		if t["id"] == "forge":
			forge = t
	ok(forge["use"]["kind"] == "craft" and not forge["use"].has("years"), "the forge's use is craft, which takes no years")
	var k: Dictionary = forge["use"].duplicate()
	forge["use"] = {"kind": "smelt", "hint": "x"}
	ok(not GameBuild.validate().is_empty(), "a use the game does not know is caught")
	forge["use"] = k
	ok(GameBuild.validate().is_empty(), "and putting it back clears it")


func test_home_forge() -> void:
	var h := _forge()
	var d: GameDynasty = h["d"]
	var fm := _form_and_material(d)
	ok(fm[0] != "", "there is a form and a material to make something with: %s" % str(fm))
	d.world.location = "whisperwood"   # wilds: no forge service here
	ok(not d.world.has_service("forge"), "(the heir is somewhere with no town forge)")
	var town := GameCraft.plan(d, fm[0], fm[1], [])
	ok(not town["ok"] and str(town["why"]).contains("no forge"), "at a place with no forge a piece cannot be made: %s" % town["why"])
	var home := GameCraft.plan(d, fm[0], fm[1], [], "home")
	ok(home["ok"], "but at the family's own forge it can: %s" % home["why"])
	d.world.location = "hearthmere"
	ok(d.world.has_service("forge"), "(Hearthmere has a forge)")
	var t2 := GameCraft.plan(d, fm[0], fm[1], [])
	var h2 := GameCraft.plan(d, fm[0], fm[1], [], "home")
	ok(t2["ok"] and h2["ok"], "both can make it there")
	ok(int(h2["fee"]) < int(t2["fee"]) and absi(int(h2["fee"]) * 2 - int(t2["fee"])) <= 1, "the family's forge charges half the town's fee: %d against %d" % [h2["fee"], t2["fee"]])
	ok(h2["id"] == t2["id"] and h2["units"] == t2["units"], "for the same piece from the same material")
	var gold := d.heir.gold
	var mat := GameCraft.have(d, fm[1])
	var made := int(d.stores.get("crafted", 0))
	var line := GameCraft.craft(d, fm[0], fm[1], [], "home")
	ok(line.contains("makes") and d.heir.inventory.has(h2["id"]), "making it puts it in the pack: %s" % line)
	ok(d.heir.gold == gold - int(h2["fee"]) and GameCraft.have(d, fm[1]) == mat - int(h2["units"]), "and spends the fee and the material")
	ok(int(d.stores.get("crafted", 0)) == made + 1, "and counts as a piece made")
	d.heir.gold = 0
	var broke := GameCraft.plan(d, fm[0], fm[1], [], "home")
	ok(not broke["ok"] and str(broke["why"]).contains("gold"), "with no gold the fee still has to be paid: %s" % broke["why"])
	d.heir.gold = 5000
	d.world.location = "whisperwood"
	var before := d.heir.inventory.size()
	ok(GameCraft.craft(d, fm[0], fm[1], []).contains("no forge") and d.heir.inventory.size() == before, "and the town path is the same as before: no forge, nothing made")


func test_use() -> void:
	var h := _forge()
	var d: GameDynasty = h["d"]
	var x: int = h["x"]
	var z: int = h["z"]
	var u := GameBuild.room_use(d, x + 3, z + 3)
	ok(u.get("kind", "") == "craft" and u["hint"] == "Use to work at the forge.", "the room is a forge that crafts: %s" % str(u))
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(x + 3, z + 3)
	ok(s.place_line().contains("forge") and s.place_line().contains("Use to work at the forge."), "the place line says what Use does: %s" % s.place_line())
	d.heir.hp = 1
	var age := d.heir.age
	var gold := d.heir.gold
	var r := s.use()
	ok(r["ok"] and r["open"] == "workshop" and r["forge"] == "home", "Use asks for the workshop at the home forge: %s" % str(r))
	ok(d.heir.hp == 1 and d.heir.age == age and d.heir.gold == gold, "and changes nothing itself (no rest, no time, no gold)")
	var h2 := _forge()
	GameBuild.place(h2["d"], "bed", h2["x"] + 3, S, h2["z"] + 3)
	ok(GameBuild.room_use(h2["d"], h2["x"] + 3, h2["z"] + 3).get("kind", "") == "craft", "a bed in a forge does not turn it into a bedroom: the forge comes first")


func test_screen() -> void:
	var h := _forge()
	var d: GameDynasty = h["d"]
	var x: int = h["x"]
	var z: int = h["z"]
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	scr.sb.heir = Vector2i(x + 3, z + 3)
	ok(not scr._modal_open(), "no workshop open to begin with")
	scr._use()
	await process_frame
	ok(scr._modal_open(), "Use in the forge opens the workshop over the map")
	var panel: Control = null
	for c in scr.get_children():
		if c.has_meta("modal"):
			panel = c
	ok(panel != null and panel.forge == "home", "and it is at the family's own forge")
	var tick: int = scr.sb.tick
	var at: Vector2i = scr.sb.heir
	for i in 60:
		await process_frame
	ok(scr.sb.tick == tick and scr.sb.heir == at, "while it is open the world waits (60 frames, no tick)")
	panel.queue_free()
	await process_frame
	await process_frame
	ok(not scr._modal_open(), "closing it gives the map back")
	for i in 60:
		await process_frame
	ok(scr.sb.tick > tick, "and the world goes on (60 frames, ticks again)")
	scr.queue_free()
	app.queue_free()


## The workshop panel itself: at a place with no town forge, the family's forge lets it make a piece and the town's does not.
func test_panel() -> void:
	var h := _forge()
	var d: GameDynasty = h["d"]
	d.world.location = "whisperwood"
	ok(not d.world.has_service("forge"), "(somewhere with no town forge)")
	var CraftPanel := load("res://ui/play/craft_panel.gd")
	var made := {}
	for forge in ["home", ""]:
		var panel: Control = CraftPanel.new()
		panel.dynasty = d
		panel.on_change = func(): pass
		panel.forge = forge
		root.add_child(panel)
		await process_frame
		var button: Button = panel.find_child("MakeButton", true, false)
		made[forge] = {"enabled": button != null and not button.disabled, "reason": panel.find_child("MakeReason", true, false) != null}
		if forge == "home" and button != null and not button.disabled:
			var pack := d.heir.inventory.size()
			var gold := d.heir.gold
			button.pressed.emit()
			made["pack"] = d.heir.inventory.size() - pack
			made["gold"] = gold - d.heir.gold
		panel.queue_free()
		await process_frame
	ok(made["home"]["enabled"], "the panel at the family's forge can make a piece with no town forge")
	ok(made.get("pack", 0) == 1 and made.get("gold", 0) > 0, "and pressing Make puts it in the pack and takes the fee")
	ok(not made[""]["enabled"] and made[""]["reason"], "while at a town forge's rules (none here) it cannot, and says why")
