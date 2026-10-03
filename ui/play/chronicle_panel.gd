## Overlay showing the dynasty's lineage, echoes, heirlooms and journal.
extends PanelContainer

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 60
	offset_right = -60
	offset_top = 40
	offset_bottom = -40
	add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 10, Kit.ACCENT))
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Kit.label("Chronicle of House %s" % dynasty.dynasty_name, 24, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Kit.button("Close", func(): queue_free(), Vector2(100, 36)))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	var lin := Kit.rich()
	lin.name = "Lineage"
	lin.text = _lineage_text()
	tabs.add_child(lin)
	var ech := Kit.rich()
	ech.name = "Echoes & Heirlooms"
	ech.text = _echo_text()
	tabs.add_child(ech)
	var jr := Kit.rich()
	jr.name = "Journal"
	jr.text = "\n".join(dynasty.journal.slice(maxi(0, dynasty.journal.size() - 120)))
	tabs.add_child(jr)


func _lineage_text() -> String:
	var lines: Array = []
	if dynasty.history.is_empty():
		lines.append("[color=#8d88a0]No ancestors have died yet.[/color]")
	for r in dynasty.history:
		var cname: String = GameData.classes[r["class_id"]]["name"]
		var line := "[b]Gen %d[/b]  %s  (%s, level %d)  died aged %d: %s" % [r["gen"], r["name"], cname, r["level"], r["age"], r["cause"]]
		if not (r["parents"] as Array).is_empty():
			line += "\n      child of %s" % " & ".join(r["parents"])
		if (r["traits"] as Array).size() > 0:
			line += "\n      traits: %s" % ", ".join(r["traits"])
		if r["archetype"] != "":
			line += "\n      shaped by fate as a %s" % GameFate.ARCHETYPES[r["archetype"]]["name"]
		lines.append(line)
	if dynasty.heir != null and dynasty.state == "life":
		lines.append("[color=#e0b341][b]Gen %d  %s  (living)[/b][/color]" % [dynasty.gen, dynasty.heir.full_name()])
	return "\n\n".join(lines)


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
		lines.append(" - %s (taken from %s, generation %d)" % [h["name"], h["boss"], h["gen"]])
	return "\n".join(lines)
