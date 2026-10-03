## The between-battles hub: stats, family, journal and the action menu.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const MapPanel := preload("res://ui/play/map_panel.gd")

var app: Node
var d: GameDynasty
var left: VBoxContainer
var right: VBoxContainer
var journal: RichTextLabel
var actions: GridContainer
var header: Label
var where: Label


func _ready() -> void:
	d = app.dynasty
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	header = Kit.label("", 22, Kit.ACCENT)
	root.add_child(header)
	where = Kit.label("", 15, Kit.DIM)
	root.add_child(where)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	var lp := Kit.panel()
	lp.custom_minimum_size = Vector2(300, 0)
	cols.add_child(lp)
	left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	lp.add_child(left)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	var jp := Kit.panel(Color("#1a1828"))
	jp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(jp)
	journal = Kit.rich()
	jp.add_child(journal)
	actions = GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	mid.add_child(actions)

	var rp := Kit.panel()
	rp.custom_minimum_size = Vector2(300, 0)
	cols.add_child(rp)
	right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	rp.add_child(right)
	_refresh()


func _refresh() -> void:
	var h := d.heir
	header.text = "House %s  -  Generation %d  -  %s the %s %s" % [d.dynasty_name, d.gen, h.name, h.race()["name"], h.cls()["name"]]
	var place := d.world.here()
	where.text = "%s (%s)  -  %s  -  %s: %s" % [place["name"], place["type"], d.world.date_text(), d.world.weather()["name"], d.world.weather().get("text", "")]
	_build_left()
	_build_right()
	_build_actions()
	journal.text = "\n".join(d.journal.slice(maxi(0, d.journal.size() - 60)).map(_colorize))


func _colorize(line: String) -> String:
	if line.begins_with("Victory") or line.begins_with("Level up") or line.begins_with("Milestone") or line.begins_with("Heirloom") or line.begins_with("Legend"):
		return "[color=#6fcf6f]%s[/color]" % line
	if "dies" in line or "slain" in line or "DISASTER" in line or "failure" in line or "Fate (" in line:
		return "[color=#e0605a]%s[/color]" % line
	if line.begins_with("Generation") or "dynasty begins" in line:
		return "[color=#e0b341][b]%s[/b][/color]" % line
	return line


func _build_left() -> void:
	Kit.clear(left)
	var h := d.heir
	left.add_child(Kit.label(h.full_name(), 22, Kit.ACCENT))
	var arch := ""
	if h.archetype != "":
		arch = "  -  %s" % GameFate.ARCHETYPES[h.archetype]["name"]
	left.add_child(Kit.label("Level %d %s %s%s" % [h.level, h.race()["name"], h.cls()["name"], arch], 15, Kit.DIM))
	left.add_child(Kit.label("Age %d / ~%d%s" % [int(h.age), int(h.lifespan), "  (living on borrowed time)" if h.age > h.lifespan else ""], 15))
	left.add_child(Kit.label("Fate Value: %d%%" % int(round(h.fate_value * 100.0)), 15, Kit.BAD if h.fate_value > 0.2 else Kit.TEXT))
	left.add_child(Kit.label("HP %d / %d" % [h.hp, h.max_hp()], 14))
	left.add_child(Kit.bar(Kit.GOOD, h.max_hp(), h.hp))
	left.add_child(Kit.label("MP %d / %d" % [h.mp, h.max_mp()], 14))
	left.add_child(Kit.bar(Kit.MP_BLUE, maxf(1.0, h.max_mp()), h.mp))
	left.add_child(Kit.label("XP %d / %d" % [h.xp, h.xp_to_next()], 14))
	left.add_child(Kit.bar(Kit.ACCENT, h.xp_to_next(), h.xp, Vector2(200, 10)))
	left.add_child(Kit.label("STR %d   MAG %d   AGI %d   VIT %d" % [int(h.stat("str")), int(h.stat("mag")), int(h.stat("agi")), int(h.stat("vit"))], 15))
	left.add_child(Kit.label("Gold %d    Potions %d" % [h.gold, h.potions], 16, Kit.ACCENT))
	left.add_child(HSeparator.new())
	left.add_child(Kit.label("Traits (hover for details)", 15, Kit.DIM))
	for id in h.all_traits():
		var l := Kit.label(GameData.trait_name(id), 15, Kit.trait_color(id))
		l.tooltip_text = Kit.trait_tooltip(id)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		left.add_child(l)
	if h.all_traits().is_empty():
		left.add_child(Kit.label("none", 14, Kit.DIM))
	if not h.dormant.is_empty():
		left.add_child(Kit.label("Carried dormant (may pass on):", 14, Kit.DIM))
		for id in h.dormant:
			var l := Kit.label("  " + GameData.trait_name(id), 14, Kit.DIM)
			l.tooltip_text = Kit.trait_tooltip(id)
			l.mouse_filter = Control.MOUSE_FILTER_STOP
			left.add_child(l)


func _build_right() -> void:
	Kit.clear(right)
	var h := d.heir
	right.add_child(Kit.label("Family", 20, Kit.ACCENT))
	if h.spouse != null:
		right.add_child(Kit.label("Spouse: %s (%s %s)" % [h.spouse.name, h.spouse.race()["name"], h.spouse.cls()["name"]], 15))
		for c in h.children:
			var traits_txt: String = ", ".join(c.traits.map(func(t): return GameData.trait_name(t)))
			var l := Kit.label("%s (%s %s)  Fate %d%%\n   %s" % [c.name, c.race()["name"], c.cls()["name"], int(round(c.fate_value * 100.0)), traits_txt if traits_txt != "" else "no expressed traits"], 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(270, 0)
			right.add_child(l)
	else:
		var single := Kit.label("Unmarried. Without children, distant cousins inherit with weaker blood.", 14, Kit.DIM)
		single.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		single.custom_minimum_size = Vector2(270, 0)
		right.add_child(single)
	right.add_child(HSeparator.new())
	right.add_child(Kit.label("Legacy", 20, Kit.ACCENT))
	right.add_child(Kit.label("Heirlooms: %d  (+%d%% power)" % [d.heirlooms.size(), int(round(d.heirloom_bonus() * 100.0))], 14))
	right.add_child(Kit.label("Ancestors: %d" % d.history.size(), 14))
	if d.echoes.is_empty():
		right.add_child(Kit.label("No legacy echoes yet.", 14, Kit.DIM))
	for e in d.echoes:
		var l := Kit.label(d.describe_echo(e), 13, Kit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(270, 0)
		right.add_child(l)


func _build_actions() -> void:
	Kit.clear(actions)
	var h := d.heir
	var boss := d.available_boss()
	_act("Hunt (safe)", func(): _hunt("hunt"))
	_act("Hunt (hard, 2x loot)", func(): _hunt("hunt_hard"))
	var legend := _act("Legend: %s" % boss["name"] if not boss.is_empty() else "No legend here", func(): _legend())
	legend.disabled = boss.is_empty()
	if not boss.is_empty():
		legend.tooltip_text = "Level %d. Slaying a legend grants a permanent heirloom and a legacy echo." % int(boss["min_level"])
	else:
		var rumors: Array = d.stirring_legends().map(func(c): return "%s (level %d) lairs in %s" % [c["name"], int(c.get("min_level", 1)), GameWorld.place(c.get("lair", "")).get("name", "somewhere")])
		legend.tooltip_text = "Legends are fought in their lairs.\n" + ("\n".join(rumors) if not rumors.is_empty() else "None stir in this generation.")
	_act("Travel / Map", func(): _map())
	for s in ["str", "mag", "agi", "vit"]:
		var st: String = s
		_act("Train %s" % st.to_upper(), func(): _do(func(): return d.train(st)))
	_act("Work for gold", func(): _do(func(): return d.work()))
	_act("Rest (heal fully)", func(): _do(func(): return d.rest()))
	var buy := _act("Buy potion (%dg)" % d.potion_price(), _say_buy)
	buy.disabled = h.gold < d.potion_price()
	var fam := _act("Found family", func(): _do(func(): return d.found_family()))
	fam.disabled = not d.can_found_family()
	fam.tooltip_text = "Requires age %d+ and no family yet. Children inherit traits from both parents." % int(h.family_min_age())
	var ret := _act("Retire / pass the torch", func(): _do(func(): return d.retire()))
	ret.disabled = not d.can_retire()
	_act("Autopilot: this life", func(): _autopilot(1))
	_act("Autopilot: 10 gens", func(): _autopilot(10))
	_act("Chronicle", func(): _chronicle())
	_act("Save", func(): d.save_to_disk(); d._say("Game saved."); _refresh())
	_act("Main menu", func(): app.show_title())


func _act(text: String, cb: Callable) -> Button:
	var b := Kit.button(text, cb, Vector2(150, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.tooltip_text = text
	actions.add_child(b)
	return b


func _say_buy() -> void:
	d._say(d.buy_potion())
	app.autosave()
	_refresh()


func _do(fn: Callable) -> void:
	fn.call()
	app.autosave()
	if d.state != "life":
		app.show_state()
	else:
		_refresh()


func _hunt(kind: String) -> void:
	d.start_hunt(kind)
	app.show_state()


func _legend() -> void:
	if d.start_legend() != null:
		app.show_state()


func _autopilot(generations: int) -> void:
	for i in generations:
		GameBot.live_life(d)
		if i < generations - 1:
			GameBot.choose_best(d)
	app.autosave()
	app.show_state()


func _map() -> void:
	var m := MapPanel.new()
	m.dynasty = d
	m.on_travel = func(to: String): _do(func(): return d.travel(to))
	add_child(m)


func _chronicle() -> void:
	var c := Chronicle.new()
	c.dynasty = d
	add_child(c)
