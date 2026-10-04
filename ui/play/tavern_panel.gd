## Tavern: companions for hire, and the party the house keeps.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes
var body: VBoxContainer
var note := ""
var confirm_id := ""


func _ready() -> void:
	var d := dynasty
	var t := GameParty.tavern(d.world.location)
	var title := "Tavern"
	if not t.is_empty():
		title = "%s, %s" % [t["name"], d.world.here()["name"]]
	body = Kit.overlay(self, title)
	_build()


func _build() -> void:
	var d := dynasty
	var p := d.party
	p.sync(d)
	while body.get_child_count() > 1:
		var c := body.get_child(body.get_child_count() - 1)
		body.remove_child(c)
		c.queue_free()
	var t := GameParty.tavern(d.world.location)
	var intro := Kit.label(str(t.get("text", "")), 14, Kit.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	body.add_child(Kit.label("Gold %d    Party %d / %d    Upkeep %d gold a year" % [d.heir.gold, p.members.size(), GameParty.max_size(), p.upkeep_total(d)], 15, Kit.ACCENT))
	if note != "":
		var n := Kit.label(note, 14, Kit.GOOD)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(n)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	var left := _column(cols, 1.35)
	var right := _column(cols, 1.0)

	left.add_child(Kit.label("Seeking work", 19, Kit.ACCENT))
	var here: Array = p.at_tavern(d, d.world.location) if d.world.has_service("tavern") else []
	var open_ids: Array = here.filter(func(id): return p.locked_reason(d, id) == "")
	var rumours: Array = here.filter(func(id): return p.locked_reason(d, id) != "")
	if open_ids.is_empty():
		left.add_child(_dim("No one here is looking for work from House %s just now." % d.dynasty_name))
	for id in open_ids:
		left.add_child(_offer_card(id))
	if not rumours.is_empty():
		left.add_child(Kit.label("Talk at the bar", 17, Kit.ACCENT))
		for id in rumours:
			left.add_child(_dim(_rumour(id)))

	right.add_child(Kit.label("Your party (%d / %d)" % [p.members.size(), GameParty.max_size()], 19, Kit.ACCENT))
	if p.members.is_empty():
		right.add_child(_dim("No one rides with %s. Hirelings fight at the heir's side, draw some of the blows and bind wounds, though foes take longer to bring down when they face a band." % d.heir.name))
	for m in p.members:
		right.add_child(_member_card(m))
	var past := _records()
	if not past.is_empty():
		right.add_child(Kit.label("House records", 17, Kit.ACCENT))
		for line in past:
			right.add_child(_dim(line))


func _rumour(id: String) -> String:
	var d := dynasty
	var p := d.party
	var r: Dictionary = p.history.get(id, {})
	if r.get("status", "") == "fallen":
		var back := int(r["gen"]) + int(GameData.bal("companion_kin_gens"))
		if d.gen < back:
			return "The barkeep keeps a cup turned down for %s. %s may take up the work from generation %d." % [(r["fallen"] as Array).back(), r["name"], back]
	var hint: String = GameParty.def(id).get("hint", "Someone at the back keeps their own counsel.")
	return "%s %s" % [hint, p.locked_reason(d, id)]


func _column(parent: Control, ratio: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = ratio
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


func _dim(text: String) -> Label:
	var l := Kit.label(text, 13, Kit.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _wrap(text: String, size: int, color: Color = Kit.TEXT) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _card_shell(id: String) -> Array:
	var c := GameParty.def(id)
	var card := Kit.panel(Kit.PANEL_LIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Color(GameData.classes[c["class"]]["color"])
	swatch.custom_minimum_size = Vector2(6, 0)
	row.add_child(swatch)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(150, 0)
	side.add_theme_constant_override("separation", 4)
	row.add_child(side)
	return [card, v, side]


## What the companion would bring at the heir's current level.
func _preview(u: GameHeir) -> String:
	var dmg := GameBattle.unit_skill_of(u, "damage")
	var stat: String = str(u.cls()["skills"][dmg].get("stat", "str")) if dmg >= 0 else "str"
	var power := "Attack %d" % int(u.attack_power())
	if stat == "mag":
		power = "Magic %d" % int(u.magic_power())
	elif stat == "both":
		power = "Attack %d  Magic %d" % [int(u.attack_power()), int(u.magic_power())]
	return "Lv%d   HP %d   MP %d   %s   Defense %d   Dodge %d%%" % [u.level, u.max_hp(), u.max_mp(), power, int(u.defense()), int(round(u.dodge_chance() * 100.0))]


func _skills(u: GameHeir) -> String:
	var parts: Array = []
	var skills: Array = u.cls()["skills"]
	for i in skills.size():
		var s: Dictionary = skills[i]
		var what: String
		if s["type"] == "heal":
			what = "heals %d%%" % int(round(float(s["pct_max_hp"]) * 100.0))
		else:
			what = "x%.1f" % float(s["mult"])
			if int(s.get("hits", 1)) > 1:
				what = "%d hits x%.1f" % [int(s["hits"]), float(s["mult"])]
		parts.append("%s (%s, %d MP)" % [s["name"], what, GameBattle.unit_skill_cost(u, i)])
	return "Skills: " + ", ".join(parts)


func _offer_card(id: String) -> Control:
	var d := dynasty
	var p := d.party
	var c := GameParty.def(id)
	var shell := _card_shell(id)
	var v: VBoxContainer = shell[1]
	var side: VBoxContainer = shell[2]
	var u := GameParty.build_unit(id, d.heir.level, d.gen, p.display_name(id))
	v.add_child(Kit.label("%s  -  %s %s" % [u.name, u.race()["name"], u.cls()["name"]], 17, Kit.ACCENT))
	var who: String = c.get("personality", "")
	if p.history.has(id) and not (p.history[id]["fallen"] as Array).is_empty():
		who = "Takes up the work of %s, who fell for your house. %s" % [" and ".join(p.history[id]["fallen"]), who]
	v.add_child(_wrap(who, 14))
	v.add_child(_wrap(_preview(u), 14))
	v.add_child(_wrap(_skills(u), 13, Kit.DIM))
	var fee := p.fee(d, id)
	side.add_child(Kit.label("Fee: %s" % ("waived" if fee == 0 else "%d gold" % fee), 14, Kit.GOOD if fee == 0 else Kit.TEXT))
	side.add_child(Kit.label("Upkeep: %d a year" % p.upkeep(d, id), 14))
	var block := p.hire_block(d, id)
	var btn := Kit.button("Hire", func(): _hire(id), Vector2(150, 34))
	btn.disabled = block != ""
	if block != "":
		btn.tooltip_text = block
	else:
		btn.tooltip_text = "%s served the house before and asks no fee." % u.name if fee == 0 else "Hire %s." % u.name
	side.add_child(btn)
	if block != "":
		var why := Kit.label(block, 12, Kit.BAD)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(150, 0)
		side.add_child(why)
	return shell[0]


func _member_card(m: Dictionary) -> Control:
	var d := dynasty
	var p := d.party
	var id: String = m["id"]
	var shell := _card_shell(id)
	var v: VBoxContainer = shell[1]
	var side: VBoxContainer = shell[2]
	side.custom_minimum_size = Vector2(120, 0)
	var u := p.unit(d, m)
	v.add_child(Kit.label(u.name, 17, Kit.ACCENT))
	v.add_child(Kit.label("%s %s  Lv%d" % [u.race()["name"], u.cls()["name"], u.level], 14, Kit.DIM))
	v.add_child(Kit.label("HP %d / %d" % [u.hp, u.max_hp()], 13))
	v.add_child(Kit.bar(Kit.GOOD, u.max_hp(), u.hp, Vector2(150, 8)))
	v.add_child(Kit.label("MP %d / %d" % [u.mp, u.max_mp()], 13))
	v.add_child(Kit.bar(Kit.MP_BLUE, maxf(1.0, u.max_mp()), u.mp, Vector2(150, 6)))
	var fought := int(m["battles"]) + int(p.history.get(id, {}).get("battles", 0))
	v.add_child(Kit.label("Upkeep %d a year   Battles %d" % [p.upkeep(d, id), fought], 13, Kit.DIM))
	var label := "Confirm" if confirm_id == id else "Dismiss"
	var btn := Kit.button(label, func(): _dismiss(id), Vector2(120, 34))
	btn.tooltip_text = "Pay off %s. They go home and will come back without a fee." % u.name
	side.add_child(btn)
	if confirm_id == id:
		var home: Array = GameParty.def(id).get("where", [])
		side.add_child(_wrap("Back to %s?" % GameWorld.place(home[0]).get("name", "home"), 12, Kit.DIM))
	return shell[0]


func _records() -> Array:
	var d := dynasty
	var p := d.party
	var out: Array = []
	for id in p.history:
		var r: Dictionary = p.history[id]
		var nb := int(r["battles"])
		var fought := "" if nb == 0 else (" (1 battle)" if nb == 1 else " (%d battles)" % nb)
		match r["status"]:
			"dismissed":
				out.append("%s: paid off in generation %d%s. Will return without a fee." % [r["name"], int(r["gen"]), fought])
			"left":
				out.append("%s: walked out unpaid in generation %d%s. Wants the full fee." % [r["name"], int(r["gen"]), fought])
			"fallen":
				var fallen: Array = r["fallen"]
				var back := int(r["gen"]) + int(GameData.bal("companion_kin_gens"))
				var kin: String = "%s may take up the work from generation %d." % [r["name"], back] if d.gen < back else "%s is ready to take up the work." % r["name"]
				out.append("%s: fell in generation %d%s. %s" % [fallen.back(), int(r["gen"]), fought, kin])
	return out


func _hire(id: String) -> void:
	confirm_id = ""
	note = dynasty.party.hire(dynasty, id)
	_changed()


func _dismiss(id: String) -> void:
	if confirm_id != id:
		confirm_id = id
		_build()
		return
	confirm_id = ""
	note = dynasty.party.dismiss(dynasty, id)
	_changed()


func _changed() -> void:
	if on_change.is_valid():
		on_change.call()
	_build()


## Lines for the life screen's right-hand panel.
static func summary_lines(d: GameDynasty) -> Array:
	var out: Array = []
	for m in d.party.members:
		var u := d.party.unit(d, m)
		# A no-break space keeps "HP" with its numbers when the line wraps.
		out.append("%s, %s %s Lv%d  HP\u00a0%d/%d" % [u.name, u.race()["name"], u.cls()["name"], u.level, u.hp, u.max_hp()])
	return out
