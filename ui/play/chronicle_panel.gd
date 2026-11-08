## Overlay showing the dynasty's lineage, its Ages, echoes, heirlooms and journal. Modal: its
## backdrop keeps clicks off the screen behind it.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var dynasty: GameDynasty
var on_change: Callable   # called after a title is put on or taken off (the screen behind redraws)
var _titles_box: VBoxContainer


func _ready() -> void:
	var v := Kit.overlay(self, "Chronicle of House %s" % dynasty.dynasty_name)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UiSettings.touch():   # the tabs a fingertip tall, as the buttons are
		for st in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
			var sb: StyleBox = tabs.get_theme_stylebox(st).duplicate()
			var line := tabs.get_theme_font("font").get_height(tabs.get_theme_font_size("font_size"))
			var pad := maxf(0.0, (UiSettings.tap_h(0.0) - line) * 0.5)
			sb.content_margin_top = pad
			sb.content_margin_bottom = pad
			tabs.add_theme_stylebox_override(st, sb)
	v.add_child(tabs)

	var lin := Kit.rich()
	lin.name = "Lineage"
	lin.text = _lineage_text()
	tabs.add_child(lin)
	var tree := Kit.rich()
	tree.name = "Family Tree"
	tree.text = _tree_text()
	tabs.add_child(tree)


	tabs.add_child(_titles_tab())
	tabs.add_child(_creatures_tab())
	var stats := Kit.rich()
	stats.name = "Statistics"
	stats.text = _stats_text()
	tabs.add_child(stats)
	var ages := Kit.rich()
	ages.name = "Ages"
	ages.text = _ages_text()
	tabs.add_child(ages)
	var ech := Kit.rich()
	ech.name = "Echoes & Heirlooms"
	ech.text = _echo_text()
	tabs.add_child(ech)
	var jr := Kit.rich()
	jr.name = "Journal"
	jr.text = "\n".join(dynasty.journal.slice(maxi(0, dynasty.journal.size() - GameDynasty.JOURNAL_SAVED)))
	tabs.add_child(jr)


func _n(v: Variant) -> String:
	return GameText.num(int(v))


## The founder, a line for the heirs folded into the Ages, then the latest heirs in full.
func _lineage_text() -> String:
	var lines: Array = []
	if dynasty.history.is_empty():
		lines.append("[color=#8d88a0]No ancestors have died yet.[/color]")
	for i in dynasty.history.size():
		lines.append(_record(dynasty.history[i]))
		var a := dynasty.ages
		if i == 0 and not a.summaries.is_empty():
			var span := {"from": _n(a.summaries[0]["from"]), "to": _n(a.summaries.back()["to"]), "heirs": _n(a.folded_heirs())}
			lines.append("[color=#8d88a0][i]%s[/i][/color]" % GameAges.text("folded", span))
	if dynasty.heir != null and dynasty.state == "life":
		lines.append("[color=#e0b341][b]Gen %s  %s  (living)[/b][/color]" % [_n(dynasty.gen), dynasty.heir.full_name()])
	return "\n\n".join(lines)


func _record(r: Dictionary) -> String:
	var cname: String = "%s %s" % [GameData.races[r.get("race_id", "human")]["name"], GameData.classes[r["class_id"]]["name"]]
	var line := "[b]Gen %s[/b]  %s  (%s, level %s)  died aged %d: %s" % [_n(r["gen"]), r["name"], cname, _n(r["level"]), r["age"], r["cause"]]
	if not (r["parents"] as Array).is_empty():
		line += "\n      child of %s" % " & ".join(r["parents"])
	if (r["traits"] as Array).size() > 0:
		line += "\n      traits: %s" % ", ".join(r["traits"])
	if r["archetype"] != "":
		line += "\n      shaped by fate as a %s" % GameFate.ARCHETYPES[r["archetype"]]["name"]
	var won := GameTitles.clean_ids(r.get("titles", []))
	if not won.is_empty():
		line += "\n      titles: %s" % ", ".join(won.map(func(id): return str(GameTitles.def(id)["name"])))
	return line


## The tree, generation by generation: each heir with their parents, spouse, children, death, traits
## and the legacy echoes from their generation. Heirs folded into the Ages are counted, not named.
func _tree_text() -> String:
	var t := GameFamilyTree.tree(dynasty)
	var blocks: Array = []
	if int(t["folded"]) > 0:
		blocks.append("[color=#8d88a0][i]%s earlier heirs are told in the Ages tab.[/i][/color]" % _n(t["folded"]))
	for entry in t["generations"]:
		var lines: Array = ["[b]Generation %s[/b]" % _n(entry["gen"])]
		for h in entry["heirs"]:
			lines.append(_tree_heir(h))
		blocks.append("\n".join(lines))
	if blocks.is_empty():
		blocks.append("[color=#8d88a0]No family yet.[/color]")
	return "\n\n".join(blocks)


func _tree_heir(h: Dictionary) -> String:
	var cname := "%s %s" % [GameData.races[h["race_id"]]["name"], GameData.classes[h["class_id"]]["name"]]
	var fate := "living, level %s" % _n(h["level"]) if h["living"] else "died %s, level %s" % [h["cause"], _n(h["level"])]
	var head := "%s  (%s, %s)" % [h["name"], cname, fate]
	if h["living"]:
		head = "[color=#e0b341]%s[/color]" % head
	var out := "  " + head
	if not (h["parents"] as Array).is_empty():
		out += "\n      child of %s" % " & ".join(h["parents"])
	if str(h["spouse"]) != "":
		out += "\n      married to %s" % h["spouse"]
	if not (h["children"] as Array).is_empty():
		out += "\n      children: %s" % ", ".join(h["children"])
	if not (h["traits"] as Array).is_empty():
		out += "\n      traits: %s" % ", ".join(h["traits"])
	for e in h["echoes"]:
		out += "\n      legacy: %s" % e
	return out


## The dynasty's numbers (GameStats): heirs, causes of death, legends, the greatest heir and gold.
func _stats_text() -> String:
	var st := GameStats.summary(dynasty)
	var lines: Array = []
	lines.append("[b]Heirs[/b]  %s lived through %s generation%s, now in Age %s" % [_n(st["heirs"]), _n(st["generations"]), "" if int(st["generations"]) == 1 else "s", _n(st["age"])])
	lines.append("")
	lines.append("[b]Deaths by cause[/b]")
	if (st["causes"] as Array).is_empty():
		lines.append("[color=#8d88a0]None yet.[/color]")
	for c in st["causes"]:
		lines.append(" - %s %s" % [_n(c[1]), c[0]])
	lines.append("")
	lines.append("[b]Legends slain[/b]  %s (%s kind%s)" % [_n(st["legends"]), _n(st["legend_kinds"]), "" if int(st["legend_kinds"]) == 1 else "s"])
	lines.append("")
	var best: Dictionary = st["best"]
	if best.is_empty():
		lines.append("[b]Greatest heir[/b]  [color=#8d88a0]none yet[/color]")
	else:
		lines.append("[b]Greatest heir[/b]  %s, %s %s, level %s (generation %s)" % [best["name"], GameData.races[best["race_id"]]["name"], GameData.classes[best["class_id"]]["name"], _n(best["level"]), _n(best["gen"])])
	lines.append("")
	lines.append("[b]Average gold at death, by Age[/b]")
	for a in st["gold_by_age"]:
		if int(a["known"]) == 0:
			lines.append(" - Age %s: not recorded" % _n(a["age"]))
		else:
			lines.append(" - Age %s: %s gold, from %s heir%s" % [_n(a["age"]), _n(a["average"]), _n(a["known"]), "" if int(a["known"]) == 1 else "s"])
	lines.append("")
	lines.append("[b]Gold of the heirs kept in full[/b]")
	for g in st["gold"]:
		lines.append(" - generation %s: %s gold" % [_n(g["gen"]), _n(g["gold"])])
	lines.append("[color=#8d88a0]Heirs folded into the Ages keep their deaths and counts, but not their gold.[/color]")
	return "\n".join(lines)


## One entry per Age lived through: its heirs, the greatest of them, the legends slain, the dead.
func _ages_text() -> String:
	var d := dynasty
	var lines: Array = []
	var rows := d.ages.age_rows(d)
	for row in rows:
		var g: Dictionary = row["greatest"]
		var entry := "[b]Age %s[/b]  generations %s-%s  -  %s heir%s" % [_n(row["age"]), _n(row["from"]), _n(row["to"]), _n(row["heirs"]), "" if int(row["heirs"]) == 1 else "s"]
		entry += "\n      Greatest: %s, %s %s, level %s (generation %s)" % [g["name"], GameData.races[g["race_id"]]["name"], GameData.classes[g["class_id"]]["name"], _n(g["level"]), _n(g["gen"])]
		var legends: Array = (row["legends"] as Array).map(func(l): return "%s (%s, generation %s)" % [d._creature_name(l["id"]), l["by"], _n(l["gen"])])
		entry += "\n      Legends slain: %s" % (", ".join(legends) if not legends.is_empty() else "none")
		entry += "\n      Deaths: %s" % _causes(row["causes"])
		lines.append(entry)
	if d.state == "life" and (rows.is_empty() or int(rows.back()["age"]) < d.age_number()):
		lines.append("[color=#e0b341][b]Age %s[/b]  begun in generation %s[/color]" % [_n(d.age_number()), _n(d.gen - d.era_gen() + 1)])
	if lines.is_empty():
		lines.append("[color=#8d88a0]No Age has been told yet.[/color]")
	lines.append("[color=#8d88a0]An Age lasts %s generations. Legends rise again when a new one begins.[/color]" % _n(GameAges.age_length()))
	return "\n\n".join(lines)


## "1,034 of old age, 50 slain in battle", most common first.
func _causes(causes: Dictionary) -> String:
	var keys := causes.keys()
	keys.sort_custom(func(a, b): return int(causes[a]) > int(causes[b]) or (int(causes[a]) == int(causes[b]) and str(a) < str(b)))
	return ", ".join(keys.map(func(k): return "%s %s%s" % [_n(causes[k]), "of " if k == "old age" else "", k]))


func _echo_text() -> String:
	var lines: Array = ["[b]Legacy Echoes[/b] (fade 15% each generation, compound when repeated)"]
	if dynasty.echoes.is_empty():
		lines.append("[color=#8d88a0]None yet. Slay legends, live well, or fail spectacularly.[/color]")
	for e in dynasty.echoes:
		lines.append(" - " + dynasty.describe_echo(e))
	lines.append("")
	lines.append("[b]Heirlooms[/b] (+%d%% power to all heirs)" % int(round(dynasty.heirloom_bonus() * 100.0)))
	if dynasty.heirlooms.is_empty():
		lines.append("[color=#8d88a0]None. Slay a Legend to claim one.[/color]")
	for h in dynasty.heirlooms:
		lines.append(" - %s (taken from %s, generation %s)" % [h["name"], h["boss"], _n(h["gen"])])
	return "\n".join(lines)


## The Titles tab: the heir's and the house's earned titles, each with a button to wear it, and below them the titles
## not yet earned, with how each is earned.
func _titles_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Titles"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_titles_box = VBoxContainer.new()
	_titles_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titles_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_titles_box)
	_fill_titles()
	return scroll


func _fill_titles() -> void:
	Kit.clear(_titles_box)
	var alive := dynasty.state == "life"
	var worn := GameTitles.worn(dynasty) if dynasty.heir != null else ""
	var head := Kit.label("Wearing: %s" % (GameTitles.display_name(dynasty) if worn != "" else "no title") if dynasty.heir != null else "", 16, Kit.ACCENT)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titles_box.add_child(head)
	var note := Kit.label("A title is earned, never bought. The heir wears one at a time after their name. A personal title ends with its heir (it stays in the lineage); a house title stays with the house.", 14, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titles_box.add_child(note)
	if worn != "" and alive:
		_titles_box.add_child(Kit.button("Take off the title", func(): _wear(""), Vector2(0, 0)))
	var mine: Array = GameTitles.earned(dynasty) if dynasty.heir != null else []
	_titles_box.add_child(Kit.label("Earned (%d)" % mine.size(), 18, Kit.ACCENT))
	if mine.is_empty():
		_titles_box.add_child(Kit.label("None yet.", 14, Kit.dim()))
	for id in mine:
		_title_row(GameTitles.def(id), true, id == worn, alive)
	var later: Array = GameTitles.defs().filter(func(t): return str(t["id"]) not in mine)
	_titles_box.add_child(Kit.label("Not yet earned (%d)" % later.size(), 18, Kit.dim()))
	for t in later:
		_title_row(t, false, false, false)


func _title_row(t: Dictionary, got: bool, on: bool, can_wear: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titles_box.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var kind := "house" if str(t.get("kind", "personal")) == "house" else "personal"
	var title := Kit.label("%s  (%s)" % [str(t["name"]), kind], 16, Kit.ACCENT if got else Kit.dim())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var about := str(t["about"])
	var perk := GameTitles.perk_text(t)
	if perk != "":
		about += "  Worn: %s." % perk
	var line := Kit.label(about, 14, Kit.TEXT if got else Kit.dim())
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(line)
	if got:
		var b := Kit.button("Worn" if on else "Wear", func(): _wear(str(t["id"])), Vector2(96, 0))
		b.disabled = on or not can_wear
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)


## The Creatures tab: the eggs and young the family keeps (see GameRoster). Read only for now.
func _creatures_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Creatures"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	box.add_child(Kit.label(GameFinding.text("kept", {"n": dynasty.roster.size(), "cap": GameRoster.cap()}), 18, Kit.ACCENT))
	var note := Kit.label(GameFinding.text("note", {}), 14, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	if dynasty.roster.is_empty():
		var none := Kit.label(GameFinding.text("empty", {}), 15, Kit.TEXT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
	for e in dynasty.roster:
		var d := GameRoster.describe(e)
		var t := Kit.label("%s  (%s)" % [d["name"], d["stage"]], 16, Kit.ACCENT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(t)
		var l := Kit.label(d["line"], 14, Kit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	return scroll


## Puts a title on (or, with "", takes it off), tells the screen behind, and draws the tab again.
func _wear(id: String) -> void:
	if id == "":
		GameTitles.unwear(dynasty)
	elif not GameTitles.wear(dynasty, id):
		return
	if on_change.is_valid():
		on_change.call()
	_fill_titles()
