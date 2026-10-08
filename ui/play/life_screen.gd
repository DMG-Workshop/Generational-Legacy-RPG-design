## The between-battles hub: stats, family, journal and the action menu.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const MapPanel := preload("res://ui/play/map_panel.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
const EventPanel := preload("res://ui/play/event_panel.gd")

const COLUMN_W := 300
const COLUMN_TEXT_W := 256   # leaves room for the scroll bar

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
	header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(header)
	where = Kit.label("", 15, Kit.DIM)
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	where.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(where)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	left = _column(cols)

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
	actions.columns = 4
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	mid.add_child(actions)

	right = _column(cols)
	_refresh()
	if d.has_pending_event():
		_open.call_deferred(EventPanel)


## A fixed-width side panel that scrolls when a long life fills it.
func _column(cols: HBoxContainer) -> VBoxContainer:
	var p := Kit.panel()
	p.custom_minimum_size = Vector2(COLUMN_W, 0)
	cols.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	sc.add_child(v)
	return v


func _refresh() -> void:
	var h := d.heir
	header.text = "House %s  -  Generation %s  -  Age %s  -  %s the %s %s" % [d.dynasty_name, GameText.num(d.gen), GameText.num(d.age_number()), h.name, h.race()["name"], h.cls()["name"]]
	var place := d.world.here()
	where.text = "%s (%s)  -  %s  -  %s: %s" % [place["name"], place["type"], d.world.date_text(), d.world.weather()["name"], d.world.weather().get("text", "")]
	header.tooltip_text = header.text
	where.tooltip_text = where.text
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
	left.add_child(Kit.label("Level %s %s %s%s" % [GameText.num(h.level), h.race()["name"], h.cls()["name"], arch], 15, Kit.DIM))
	left.add_child(Kit.label("Age %d / ~%d%s" % [int(h.age), int(h.lifespan), "  (living on borrowed time)" if h.age > h.lifespan else ""], 15))
	left.add_child(Kit.label("Fate Value: %d%%" % int(round(h.fate_value * 100.0)), 15, Kit.BAD if h.fate_value > 0.2 else Kit.TEXT))
	left.add_child(Kit.label("HP %s / %s" % [GameText.num(h.hp), GameText.num(h.max_hp())], 14))
	left.add_child(Kit.bar(Kit.GOOD, h.max_hp(), h.hp))
	left.add_child(Kit.label("MP %s / %s" % [GameText.num(h.mp), GameText.num(h.max_mp())], 14))
	left.add_child(Kit.bar(Kit.MP_BLUE, maxf(1.0, h.max_mp()), h.mp))
	left.add_child(Kit.label("XP %s / %s" % [GameText.num(h.xp), GameText.num(h.xp_to_next())], 14))
	left.add_child(Kit.bar(Kit.ACCENT, h.xp_to_next(), h.xp, Vector2(200, 10)))
	left.add_child(Kit.label("STR\u00a0%s   MAG\u00a0%s   AGI\u00a0%s   VIT\u00a0%s" % [GameText.num(int(h.stat("str"))), GameText.num(int(h.stat("mag"))), GameText.num(int(h.stat("agi"))), GameText.num(int(h.stat("vit")))], 15))
	left.add_child(Kit.label("Gold %s    Potions %d" % [GameText.num(h.gold), h.potions], 16, Kit.ACCENT))
	_afflictions(h)
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
	_fit_column(left)


## Sicknesses: the stage, what it takes away and how long until it worsens.
func _afflictions(h: GameHeir) -> void:
	if h.diseases.is_empty():
		return
	left.add_child(HSeparator.new())
	left.add_child(Kit.label("Afflictions (cures at temples)", 15, Kit.BAD))
	for e in h.diseases:
		var info := GameDisease.describe_entry(e)
		var l := Kit.label("%s: %s (%d/%d)" % [info["name"], info["stage_name"], info["stage"], info["stages"]], 15, Kit.BAD)
		l.tooltip_text = "%s\n%s" % [info["name"], info["description"]]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		left.add_child(l)
		left.add_child(Kit.label("  %s\n  %s" % [info["effects"], info["outlook"]], 13, Kit.DIM))


## Every line in a side column wraps at the column's width: six-figure stats at level 5000,
## long names and long class titles must never push the other columns off-screen.
func _fit_column(col: VBoxContainer) -> void:
	for c in col.get_children():
		if c is Label:
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.custom_minimum_size.x = COLUMN_TEXT_W


func _build_right() -> void:
	Kit.clear(right)
	var h := d.heir
	right.add_child(Kit.label("Family", 20, Kit.ACCENT))
	if h.spouse != null:
		right.add_child(Kit.label("Spouse: %s (%s %s)%s" % [h.spouse.name, h.spouse.race()["name"], h.spouse.cls()["name"], _sick(h.spouse)], 15))
		for c in h.children:
			var traits_txt: String = ", ".join(c.traits.map(func(t): return GameData.trait_name(t)))
			right.add_child(Kit.label("%s (%s %s)  Fate %d%%\n   %s%s" % [c.name, c.race()["name"], c.cls()["name"], int(round(c.fate_value * 100.0)), traits_txt if traits_txt != "" else "no expressed traits", _sick(c)], 14))
	else:
		right.add_child(Kit.label("Unmarried. Without children, distant cousins inherit with weaker blood.", 14, Kit.DIM))
	_section("Gear", ShopPanel.summary_lines(d))
	_section("Companions", TavernPanel.summary_lines(d))
	_section("Quests", BoardPanel.summary_lines(d))
	right.add_child(HSeparator.new())
	right.add_child(Kit.label("Legacy", 20, Kit.ACCENT))
	right.add_child(Kit.label("Heirlooms: %d  (+%d%% power)" % [d.heirlooms.size(), int(round(d.heirloom_bonus() * 100.0))], 14))
	right.add_child(Kit.label("Ancestors: %s" % GameText.num(d.ancestor_count()), 14))
	if d.echoes.is_empty():
		right.add_child(Kit.label("No legacy echoes yet.", 14, Kit.DIM))
	for e in d.echoes:
		right.add_child(Kit.label(d.describe_echo(e), 13, Kit.DIM))
	_fit_column(right)


func _sick(m: GameHeir) -> String:
	return "" if m.diseases.is_empty() else "\n   sick: %s" % GameDisease.status_text(m)


func _section(title: String, lines: Array) -> void:
	if lines.is_empty():
		return
	right.add_child(HSeparator.new())
	right.add_child(Kit.label(title, 20, Kit.ACCENT))
	for line in lines:
		right.add_child(Kit.label(str(line), 13, Kit.TEXT))


func _build_actions() -> void:
	Kit.clear(actions)
	var h := d.heir
	var boss := d.available_boss()
	_act("Hunt", func(): _hunt("hunt"))
	var hard := _act("Hard hunt", func(): _hunt("hunt_hard"))
	hard.tooltip_text = "Tougher monsters and more Elites, for double XP and gold."
	var legend := _act("Fight %s" % boss.get("short", boss["name"]) if not boss.is_empty() else "No legend here", func(): _legend())
	legend.disabled = boss.is_empty()
	if not boss.is_empty():
		legend.tooltip_text = "%s, level %d. Slaying a legend grants a permanent heirloom and a legacy echo." % [boss["name"], int(boss["min_level"])]
	else:
		var rumors: Array = d.stirring_legends().map(func(c): return "%s (level %d) lairs in %s" % [c["name"], int(c.get("min_level", 1)), GameWorld.place(c.get("lair", "")).get("name", "somewhere")])
		legend.tooltip_text = "Legends are fought in their lairs.\n" + ("\n".join(rumors) if not rumors.is_empty() else "None stir in this generation.")
	_act("Travel / Map", func(): _map())
	_act("Explore", func(): _do(func(): return d.explore()))
	var w := d.world
	if w.has_service("forge") or w.has_service("store") or w.has_service("temple"):
		_act("Shops", func(): _open(ShopPanel))
	if w.has_service("tavern"):
		_act("Tavern", func(): _open(TavernPanel))
	if w.has_service("board"):
		_act("Notice board", func(): _open(BoardPanel))
	var gear := _act("Gear", func(): _gear())
	gear.tooltip_text = "What %s wears and carries. Swap gear anywhere; selling needs a town shop." % h.name
	for s in ["str", "mag", "agi", "vit"]:
		var st: String = s
		_act("Train %s" % st.to_upper(), func(): _do(func(): return d.train(st)))
	_act("Work", func(): _do(func(): return d.work()))
	_act("Rest", func(): _do(func(): return d.rest()))
	var buy := _act("Potion (%sg)" % GameText.num(d.potion_price()), _say_buy)
	buy.tooltip_text = "Buy a healing potion for %s gold." % GameText.num(d.potion_price())
	buy.disabled = h.gold < d.potion_price()
	var fam := _act("Found family", func(): _do(func(): return d.found_family()))
	fam.disabled = not d.can_found_family()
	fam.tooltip_text = "Requires age %d+ and no family yet. Children inherit traits from both parents." % int(h.family_min_age())
	var ret := _act("Retire", func(): _do(func(): return d.retire()))
	ret.disabled = not d.can_retire()
	_act("Auto: this life", func(): _autopilot(1))
	_act("Auto: 10 gens", func(): _autopilot(10))
	_act("Chronicle", func(): _chronicle())
	_act("Save", func(): d.save_to_disk(); d._say("Game saved."); _refresh())
	_act("Menu", func(): app.show_title())


func _act(text: String, cb: Callable) -> Button:
	var b := Kit.button(text, cb, Vector2(150, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	if text.length() > 15:
		b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = text
	actions.add_child(b)
	return b


func _say_buy() -> void:
	d._say(d.buy_potion())
	app.autosave()
	_refresh()


func _do(fn: Callable) -> void:
	fn.call()
	_changed()


## After anything changes the dynasty: save, then show whatever needs the player next.
func _changed() -> void:
	app.autosave()
	if d.state != "life" or d.battle != null:
		app.show_state()
		return
	_refresh()
	if d.has_pending_event() and not _has_open(EventPanel):
		_open(EventPanel)


func _open(panel_script: Script) -> void:
	var p: Control = panel_script.new()
	p.dynasty = d
	p.on_change = _changed
	add_child(p)


## The shop panel's Gear tab on its own, so gear can be changed in the wilds too.
func _gear() -> void:
	var p: Control = ShopPanel.new()
	p.gear_only = true
	p.dynasty = d
	p.on_change = _changed
	add_child(p)


func _has_open(panel_script: Script) -> bool:
	for c in get_children():
		if c.get_script() == panel_script:
			return true
	return false


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
	m.on_change = _changed
	add_child(m)


func _chronicle() -> void:
	var c := Chronicle.new()
	c.dynasty = d
	add_child(c)
