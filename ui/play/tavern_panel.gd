## Tavern: companions for hire, and the party the house keeps.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const OLD := Color("#e8a05a")

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
	body.add_child(Kit.label("Gold %s    Party %d / %d    Upkeep %s gold a year" % [GameText.num(d.heir.gold), p.members.size(), GameParty.max_size(), GameText.num(p.upkeep_total(d))], 15, Kit.ACCENT))
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
			return "The barkeep keeps a cup turned down for %s. %s may take up the work from generation %s." % [(r["fallen"] as Array).back(), r["name"], GameText.num(back)]
	if r.get("status", "") in ["dead", "retired"] and not (r.get("past", []) as Array).is_empty():
		var e: Dictionary = (r["past"] as Array).back()
		var gone := "The barkeep keeps a cup turned down for %s, who died of old age at %d." % [e["name"], int(e["age"])]
		if e["end"] == "retired":
			gone = "%s has retired to %s, and the regulars still ask after them." % [e["name"], p._place_name(id)]
		return "%s %s" % [gone, p.locked_reason(d, id)]
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
	var power := "Attack %s" % GameText.num(int(u.attack_power()))
	if stat == "mag":
		power = "Magic %s" % GameText.num(int(u.magic_power()))
	elif stat == "both":
		power = "Attack %s  Magic %s" % [GameText.num(int(u.attack_power())), GameText.num(int(u.magic_power()))]
	return "Lv%s   HP %s   MP %s   %s   Defense %s   Dodge %d%%" % [GameText.num(u.level), GameText.num(u.max_hp()), GameText.num(u.max_mp()), power, GameText.num(int(u.defense())), int(round(u.dodge_chance() * 100.0))]


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
		parts.append("%s (%s, %s MP)" % [s["name"], what, GameText.num(GameBattle.unit_skill_cost(u, i))])
	return "Skills: " + ", ".join(parts)


## Who held this role before the one now at the table, if anyone.
func _heritage(id: String) -> String:
	var r: Dictionary = dynasty.party.history.get(id, {})
	var past: Array = r.get("past", [])
	var fallen: Array = r.get("fallen", [])
	if not past.is_empty():
		var e: Dictionary = past.back()
		if e["end"] == "died":
			return "Takes up the work of %s, who died of old age at %d." % [e["name"], int(e["age"])]
		if e["end"] == "retired":
			return "Takes up the work of %s, who retired at %d." % [e["name"], int(e["age"])]
		return "Takes up the work of %s, who fell for your house." % e["name"]
	if not fallen.is_empty():
		return "Takes up the work of %s, who fell for your house." % " and ".join(fallen)
	return ""


func _offer_card(id: String) -> Control:
	var d := dynasty
	var p := d.party
	var c := GameParty.def(id)
	var shell := _card_shell(id)
	var v: VBoxContainer = shell[1]
	var side: VBoxContainer = shell[2]
	var u := p.offer_unit(d, id)
	v.add_child(Kit.label("%s  -  %s %s" % [u.name, u.race()["name"], u.cls()["name"]], 17, Kit.ACCENT))
	var who: String = c.get("personality", "")
	var before := _heritage(id)
	if before != "":
		who = "%s %s" % [before, who]
	v.add_child(_wrap(who, 14))
	v.add_child(_wrap(p.age_text(d, id), 14, OLD if p.is_old(d, id) else Kit.DIM))
	v.add_child(_wrap(_preview(u), 14))
	v.add_child(_wrap(_skills(u), 13, Kit.DIM))
	var fee := p.fee(d, id)
	side.add_child(Kit.label("Fee: %s" % ("waived" if fee == 0 else "%s gold" % GameText.num(fee)), 14, Kit.GOOD if fee == 0 else Kit.TEXT))
	side.add_child(Kit.label("Upkeep: %s a year" % GameText.num(p.upkeep(d, id)), 14))
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
	v.add_child(Kit.label("%s %s  Lv%s" % [u.race()["name"], u.cls()["name"], GameText.num(u.level)], 14, Kit.DIM))
	v.add_child(_wrap(p.age_text(d, id), 13, OLD if p.is_old(d, id) else Kit.DIM))
	# Health and mana side by side keep a full party of three on screen.
	var gauges := HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 12)
	v.add_child(gauges)
	gauges.add_child(_gauge("HP %s / %s" % [GameText.num(u.hp), GameText.num(u.max_hp())], Kit.GOOD, u.max_hp(), u.hp))
	gauges.add_child(_gauge("MP %s / %s" % [GameText.num(u.mp), GameText.num(u.max_mp())], Kit.MP_BLUE, maxf(1.0, u.max_mp()), u.mp))
	var label := "Confirm" if confirm_id == id else "Dismiss"
	var btn := Kit.button(label, func(): _dismiss(id), Vector2(120, 34))
	btn.tooltip_text = "Pay off %s. They go home and will come back without a fee." % u.name
	side.add_child(btn)
	if confirm_id == id:
		var home: Array = GameParty.def(id).get("where", [])
		side.add_child(_wrap("Back to %s?" % GameWorld.place(home[0]).get("name", "home"), 12, Kit.DIM))
	else:
		var fought := int(m["battles"]) + int(p.history.get(id, {}).get("battles", 0))
		side.add_child(Kit.label("Upkeep %s a year" % GameText.num(p.upkeep(d, id)), 12, Kit.DIM))
		side.add_child(Kit.label("Battles %d" % fought, 12, Kit.DIM))
	return shell[0]


func _gauge(text: String, color: Color, max_value: float, value: float) -> VBoxContainer:
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("separation", 2)
	g.add_child(Kit.label(text, 13))
	g.add_child(Kit.bar(color, max_value, value, Vector2(0, 8)))
	return g


func _records() -> Array:
	var d := dynasty
	var p := d.party
	var out: Array = []
	var shown := int(GameParty.setting("past_shown"))
	for id in p.history:
		var r: Dictionary = p.history[id]
		var nb := int(r["battles"])
		var fought := "" if nb == 0 else (" (1 battle)" if nb == 1 else " (%d battles)" % nb)
		var past: Array = r.get("past", [])
		var earlier := int(r.get("line", 0)) - mini(past.size(), shown)
		if earlier > 0 and not past.is_empty():
			out.append("Before them, %d more served the house in this line." % earlier)
		for e in past.slice(maxi(0, past.size() - shown)):
			out.append(_past_line(id, e))
		var who := "%s, %d of ~%d%s" % [r["name"], int(p.age(d, id)), int(round(p.lifespan(d, id))), " (old)" if p.is_old(d, id) else ""]
		match r["status"]:
			"dismissed":
				out.append("%s: paid off in generation %s%s. Will return without a fee." % [who, GameText.num(int(r["gen"])), fought])
			"left":
				out.append("%s: walked out unpaid in generation %s%s. Wants the full fee." % [who, GameText.num(int(r["gen"])), fought])
			"fallen":
				var fallen: Array = r["fallen"]
				var back := int(r["gen"]) + int(GameData.bal("companion_kin_gens"))
				var kin: String = "%s may take up the work from generation %s." % [r["name"], GameText.num(back)] if d.gen < back else "%s is ready to take up the work." % r["name"]
				if past.is_empty():
					out.append("%s: fell in generation %s%s. %s" % [fallen.back(), GameText.num(int(r["gen"])), fought, kin])
				else:
					out.append(kin)
			"dead", "retired":
				if GameParty.def(id).has("successor"):
					var lock := p.locked_reason(d, id)
					out.append(lock if lock != "" else "%s is ready to take up the work." % r["name"])
	return out


func _past_line(id: String, e: Dictionary) -> String:
	var nb := int(e.get("battles", 0))
	var fought := "" if nb == 0 else (" (1 battle)" if nb == 1 else " (%d battles)" % nb)
	match e["end"]:
		"fell":
			return "%s fell in battle at %d, in year %s%s." % [e["name"], int(e["age"]), GameText.num(int(e["year"])), fought]
		"retired":
			return "%s retired to %s at %d, in year %s%s." % [e["name"], dynasty.party._place_name(id), int(e["age"]), GameText.num(int(e["year"])), fought]
	var where := "in the house's service" if bool(e.get("served", true)) else "after leaving the house's service"
	return "%s died of old age at %d in year %s, %s%s." % [e["name"], int(e["age"]), GameText.num(int(e["year"])), where, fought]


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
		var years := str(int(d.party.age(d, m["id"])))
		if d.party.is_old(d, m["id"]):
			years += ", " + d.party.old_text(d, m["id"])
		# A no-break space keeps "HP" with its numbers when the line wraps.
		out.append("%s (%s), %s %s Lv%s  HP\u00a0%s/%s" % [u.name, years, u.race()["name"], u.cls()["name"], GameText.num(u.level), GameText.num(u.hp), GameText.num(u.max_hp())])
	return out
