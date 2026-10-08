## Overlay showing the dynasty's lineage, its Ages, echoes, heirlooms and journal. Modal: its
## backdrop keeps clicks off the screen behind it.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty


func _ready() -> void:
	var v := Kit.overlay(self, "Chronicle of House %s" % dynasty.dynasty_name)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	var lin := Kit.rich()
	lin.name = "Lineage"
	lin.text = _lineage_text()
	tabs.add_child(lin)
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
	return line


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
