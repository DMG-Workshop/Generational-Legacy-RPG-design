## Remapping the open world's keys (roadmap item 39): a key can be given to an action in place of one it has (or added, up to
## max_keys), refused when it is unknown, reserved or another action's (naming that action), kept in settings.cfg and put into the
## engine's input map at once; reset gives back the data's keys; a damaged settings file is cleaned (unknown actions and keys,
## clashes with what an untouched action keeps, too many keys, none at all) so the controls never break; the Controls panel waits
## for a key, shows what was said, and the menu opens it.
## Run: godot --headless --path . -s res://tests/test_game_remap.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const ControlsPanel := preload("res://ui/play/controls_panel.gd")
const DIR := "user://test_remap/"

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _fresh() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	UiSettings.path = DIR + "settings.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	WorldInput.forget_overrides()
	WorldInput.install()


func _run() -> void:
	_fresh()
	test_data()
	test_remap()
	test_refusals()
	test_saved()
	test_clean()
	await test_panel()
	DirAccess.remove_absolute(UiSettings.path)
	WorldInput.forget_overrides()
	WorldInput.install()
	print("remap tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _key_events(action: String) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(OS.get_keycode_string((e as InputEventKey).keycode))
	return out


func test_data() -> void:
	ok(WorldInput.validate().is_empty(), "the shipped data passes: %s" % str(WorldInput.validate()))
	var s: Dictionary = WorldInput.data()["settings"]
	var keep: Variant = s["max_keys"]
	s["max_keys"] = 0
	ok(not WorldInput.validate().is_empty(), "no room for any key is caught")
	s["max_keys"] = keep
	var res: Variant = s["reserved_keys"]
	s["reserved_keys"] = ["NotAKey"]
	ok(not WorldInput.validate().is_empty(), "a reserved key the engine does not know is caught")
	s["reserved_keys"] = res
	var t: Variant = WorldInput.data()["text"]["clash"]
	WorldInput.data()["text"].erase("clash")
	ok(not WorldInput.validate().is_empty(), "missing text is caught")
	WorldInput.data()["text"]["clash"] = t
	ok(WorldInput.validate().is_empty(), "and mending the data clears it")


func test_remap() -> void:
	_fresh()
	var before := _key_events("world_dig")
	ok(WorldInput.keys_of("world_dig") == WorldInput.data()["actions"]["world_dig"]["keys"], "with nothing changed an action has the data's keys")
	var r := WorldInput.remap("world_dig", 0, "F5")
	ok(bool(r["ok"]) and str(r["text"]).contains("F5"), "a free key can be given to an action: %s" % r["text"])
	ok(WorldInput.keys_of("world_dig")[0] == "F5", "and it is the action's key now")
	ok(_key_events("world_dig").has("F5") and not _key_events("world_dig").has(before[0]), "and the engine's input map has it at once, and not the old one")
	ok(WorldInput.key_owner("F5") == "world_dig" and WorldInput.key_owner(before[0]) == "", "the old key is free again")
	# adding a key
	var n := (WorldInput.keys_of("world_dig") as Array).size()
	var add := WorldInput.remap("world_dig", n, "F6")
	ok(bool(add["ok"]) and (WorldInput.keys_of("world_dig") as Array).size() == n + 1, "the next slot adds a key")
	# the pad is untouched
	ok(not InputMap.action_get_events("world_dig").filter(func(e): return e is InputEventJoypadButton).is_empty() or (WorldInput.data()["actions"]["world_dig"].get("pad_buttons", []) as Array).is_empty(), "the gamepad's buttons stay")
	# reset
	var rs := WorldInput.reset("world_dig")
	ok(bool(rs["ok"]) and WorldInput.keys_of("world_dig") == WorldInput.data()["actions"]["world_dig"]["keys"] and _key_events("world_dig") == before, "reset gives the data's keys back, in the input map too")
	WorldInput.remap("world_dig", 0, "F5")
	WorldInput.remap("world_build", 0, "U")
	WorldInput.reset_all()
	ok(WorldInput.overrides().is_empty() and _key_events("world_dig") == before, "reset all clears every change")


func test_refusals() -> void:
	_fresh()
	var mine: String = WorldInput.keys_of("world_dig")[0]
	var other: String = WorldInput.data()["actions"]["world_build"]["keys"][0]
	var r := WorldInput.remap("world_dig", 0, other)
	ok(not r["ok"] and str(r["text"]).contains(other) and str(r["text"]).contains(str(WorldInput.data()["actions"]["world_build"]["name"]).to_lower()), "another action's key is refused, naming it: %s" % r["text"])
	ok(WorldInput.keys_of("world_dig")[0] == mine, "and nothing changed")
	ok(not WorldInput.remap("world_dig", 0, "Escape")["ok"] and str(WorldInput.remap("world_dig", 0, "Escape")["text"]).contains("kept to cancel"), "the reserved key is refused as reserved")
	ok(not WorldInput.remap("world_dig", 0, "NoSuchKey")["ok"], "a key the engine does not know is refused")
	ok(not WorldInput.remap("world_nothing", 0, "F5")["ok"], "an unknown action is refused")
	ok(not WorldInput.remap("world_dig", 9, "F5")["ok"], "a slot beyond the next free one is refused")
	var full := WorldInput.keys_of("world_dig").size()
	for k in ["F5", "F9", "F10", "F11"]:
		var slot := (WorldInput.keys_of("world_dig") as Array).size()
		WorldInput.remap("world_dig", slot, k)
	ok((WorldInput.keys_of("world_dig") as Array).size() <= int(WorldInput.setting("max_keys")), "an action holds no more than max_keys: %d" % (WorldInput.keys_of("world_dig") as Array).size())
	ok(full >= 1, "(it began with a key)")
	var back := WorldInput.remap("world_dig", 0, mine)
	ok(bool(back["ok"]), "giving an action back a key it had is fine")


func test_saved() -> void:
	_fresh()
	WorldInput.remap("world_dig", 0, "F5")
	ok(UiSettings.stored("keys", {}).get("world_dig", []) == ["F5"], "the change is in settings.cfg")
	WorldInput.forget_overrides()
	ok(WorldInput.keys_of("world_dig") == ["F5"], "and is read back the next time")
	WorldInput.install()
	ok(_key_events("world_dig").has("F5"), "and installed from the file")
	_fresh()
	ok(WorldInput.keys_of("world_dig") == WorldInput.data()["actions"]["world_dig"]["keys"], "with no file, the data's keys")


func test_clean() -> void:
	_fresh()
	var build_key: String = WorldInput.data()["actions"]["world_build"]["keys"][0]
	var raw := {
		"world_dig": ["F5", "NoSuchKey", "Escape", 7, "F5", "F6", "F7", "F8"],
		"world_nothing": ["Q"],
		"world_build": "not a list",
		"world_cancel": [],
		"world_interact": [build_key],
	}
	var c := WorldInput.clean_overrides(raw)
	ok(c.get("world_dig", []) == ["F5", "F6", "F7"], "dig keeps its good keys, in order, once each, up to max_keys: %s" % str(c.get("world_dig")))
	ok(not c.has("world_nothing") and not c.has("world_build") and not c.has("world_cancel"), "an unknown action, a non-list and an empty list are dropped")
	ok(not c.has("world_interact"), "a key an untouched action keeps by default is not up for grabs")
	ok(WorldInput.clean_overrides("junk").is_empty() and WorldInput.clean_overrides(null).is_empty() and WorldInput.clean_overrides([]).is_empty(), "something that is not a table is nothing")
	var clash := WorldInput.clean_overrides({"world_dig": ["F5"], "world_interact": ["F5"]})
	var first: String = WorldInput.actions()[mini(WorldInput.actions().find("world_dig"), WorldInput.actions().find("world_interact"))]
	ok(clash.size() == 1 and clash.has(first), "a key given to two actions stays with the first in the data's order (%s)" % first)
	# a settings file with that damage loads and plays
	var cf := ConfigFile.new()
	cf.set_value("ui", "keys", raw)
	cf.save(UiSettings.path)
	WorldInput.forget_overrides()
	WorldInput.install()
	ok(_key_events("world_dig").has("F5") and not _key_events("world_dig").has("Escape"), "the installed map has the good keys only")
	for action in WorldInput.actions():
		ok(not _key_events(action).is_empty() or (WorldInput.data()["actions"][action].get("keys", []) as Array).is_empty(), "%s still has a key" % action)


func test_panel() -> void:
	_fresh()
	var panel: Control = ControlsPanel.new()
	root.add_child(panel)
	await process_frame
	await process_frame
	var change: Button = panel.find_child("Change_world_dig", true, false)
	ok(change != null, "the panel has a Change button for each action")
	var reset: Button = panel.find_child("Reset_world_dig", true, false)
	ok(reset != null and reset.disabled, "and Reset is shut while an action has its own keys")
	change.pressed.emit()
	await process_frame
	ok(panel.waiting == "world_dig" and (panel.find_child("Change_world_dig", true, false) as Button).text.contains("Press"), "Change waits for a key and says so")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	panel._input(ev)
	await process_frame
	ok(WorldInput.keys_of("world_dig")[0] == "F5" and panel.waiting == "", "the next key is the action's key: %s" % panel.said.text)
	ok(not (panel.find_child("Reset_world_dig", true, false) as Button).disabled, "and Reset opens")
	# a clash says so and keeps waiting
	panel.find_child("Change_world_dig", true, false).pressed.emit()
	await process_frame
	var build_key: String = WorldInput.data()["actions"]["world_build"]["keys"][0]
	var clash := InputEventKey.new()
	clash.keycode = OS.find_keycode_from_string(build_key)
	clash.pressed = true
	panel._input(clash)
	await process_frame
	ok(panel.waiting == "world_dig" and panel.said.text.contains("already"), "a clash is told and the panel keeps waiting: %s" % panel.said.text)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	panel._input(esc)
	await process_frame
	ok(panel.waiting == "" and WorldInput.keys_of("world_dig")[0] == "F5", "Escape stops waiting and changes nothing")
	(panel.find_child("Reset_world_dig", true, false) as Button).pressed.emit()
	await process_frame
	ok(WorldInput.overrides().is_empty(), "Reset on a row gives its keys back")
	panel.queue_free()
	await process_frame
