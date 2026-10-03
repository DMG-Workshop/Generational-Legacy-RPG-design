## Family tree browser: navigate and view ancestry
##
## Displays lineage, shows ancestor details, and allows browsing back through generations

extends Control

class_name FamilyTreeBrowser


var lineage: Lineage
var current_heir: Heir
var selected_ancestor: Heir = null
var npc_system: NPCSystem


func _init(p_lineage: Lineage, p_heir: Heir, p_npc_system: NPCSystem) -> void:
	lineage = p_lineage
	current_heir = p_heir
	npc_system = p_npc_system


func _ready() -> void:
	# Setup UI
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "Family Tree: %s Bloodline" % current_heir.name
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Generation navigation
	var nav_hbox = HBoxContainer.new()
	vbox.add_child(nav_hbox)

	var gen_label = Label.new()
	gen_label.text = "Generation: "
	nav_hbox.add_child(gen_label)

	var gen_spin = SpinBox.new()
	gen_spin.min_value = 0
	gen_spin.max_value = lineage.generation_count
	gen_spin.value = current_heir.generation
	gen_spin.value_changed.connect(_on_generation_changed)
	nav_hbox.add_child(gen_spin)

	# Ancestor list
	var list_label = Label.new()
	list_label.text = "Ancestors at Generation %d" % current_heir.generation
	vbox.add_child(list_label)

	var ancestor_list = ItemList.new()
	ancestor_list.custom_minimum_size = Vector2(0, 300)
	ancestor_list.item_selected.connect(_on_ancestor_selected)
	vbox.add_child(ancestor_list)

	# Populate with ancestors at current generation
	_populate_ancestors(ancestor_list, current_heir.generation)

	# Ancestor detail panel
	var detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_panel.add_child(detail_vbox)

	var detail_title = Label.new()
	detail_title.text = "Ancestor Details"
	detail_title.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(detail_title)

	var detail_text = TextEdit.new()
	detail_text.editable = false
	detail_text.custom_minimum_size = Vector2(0, 150)
	detail_vbox.add_child(detail_text)


func _populate_ancestors(list: ItemList, generation: int) -> void:
	list.clear()

	# Get all heirs from this generation
	for gen in range(generation + 1):
		var heir = lineage.get_heir(gen)
		if heir and heir.generation == generation:
			var item_text = "%s (Gen %d, Age %d)" % [heir.name, heir.generation, heir.death_year if heir.death_year > 0 else 0]
			list.add_item(item_text)


func _on_generation_changed(value: float) -> void:
	var generation = int(value)
	print("Browsing generation %d" % generation)
	# Refresh ancestor list
	# TODO: Update UI


func _on_ancestor_selected(index: int) -> void:
	# Get selected ancestor
	var heir = lineage.get_heir(index)
	if heir:
		selected_ancestor = heir
		_show_ancestor_details(heir)


func _show_ancestor_details(ancestor: Heir) -> void:
	var details = ""
	details += "Name: %s\n" % ancestor.name
	details += "Generation: %d\n" % ancestor.generation
	details += "Class: %s\n" % ancestor.class_id
	details += "Job: %s\n" % ancestor.job_id
	details += "Traits: %s\n" % ", ".join(ancestor.traits)
	details += "Status: %s\n" % ("Living" if ancestor.is_alive else "Deceased")

	if ancestor.death_year > 0:
		details += "Death Year: %d\n" % ancestor.death_year
		details += "Death Cause: %s\n" % ancestor.death_cause

	# Show legacy information
	var npc = npc_system.get_ancestor_by_generation(ancestor.generation)
	if npc:
		details += "\nLegacy: NPC Ancestor\n"
		details += "Wisdom: %d\n" % npc.wisdom
		details += "Personality: %s\n" % npc.personality
		details += "Is Legendary: %s" % ("Yes" if npc.is_legendary else "No")

	print(details)


func get_ancestry_line(current_generation: int) -> Array[Heir]:
	## Get direct lineage from founder to current
	var line: Array[Heir] = []

	for gen in range(current_generation + 1):
		var heir = lineage.get_heir(gen)
		if heir:
			line.append(heir)

	return line


func get_siblings(heir: Heir) -> Array[Heir]:
	## Get all siblings of an heir
	var siblings: Array[Heir] = []

	# TODO: Implement sibling detection

	return siblings


func get_descendants(ancestor: Heir) -> Array[Heir]:
	## Get all descendants of an ancestor
	var descendants: Array[Heir] = []

	# TODO: Implement descendant search

	return descendants
