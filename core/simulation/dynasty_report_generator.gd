## Dynasty Report Generator: Generate comprehensive dynasty legacy reports
##
## Creates detailed reports of dynasty progression, achievements, and legacy

extends Node

class_name DynastyReportGenerator


signal report_generated(report_type: String)


var report_sections: Dictionary = {}


class DynastyReport:
	var title: String
	var generation_span: int
	var final_prestige: int
	var final_tier: String
	var total_milestones: int
	var total_prophecies: int
	var total_events: int
	var total_combats: int
	var legendary_bosses_defeated: int
	var average_prestige_per_gen: float
	var prestige_growth_trajectory: Array
	var achievements_summary: Dictionary
	var world_impact_summary: String

	func _init() -> void:
		title = "Dynasty Report"
		generation_span = 0
		final_prestige = 0
		final_tier = "BRONZE"
		total_milestones = 0
		total_prophecies = 0
		total_events = 0
		total_combats = 0
		legendary_bosses_defeated = 0
		average_prestige_per_gen = 0.0
		prestige_growth_trajectory = []
		achievements_summary = {}
		world_impact_summary = ""


func _init() -> void:
	pass


func generate_dynasty_report(simulation_stats: Dictionary, generation_records: Array, milestone_timeline: Array) -> DynastyReport:
	var report = DynastyReport.new()

	report.title = "Dynasty of Ages - 999 Generation Legacy"
	report.generation_span = simulation_stats.get("total_generations_simulated", 0)
	report.final_prestige = simulation_stats.get("final_prestige", 0)
	report.total_milestones = simulation_stats.get("total_milestones_reached", 0)
	report.total_prophecies = simulation_stats.get("total_prophecies_fulfilled", 0)
	report.total_events = simulation_stats.get("total_events_created", 0)
	report.total_combats = simulation_stats.get("total_combat_victories", 0)
	report.legendary_bosses_defeated = simulation_stats.get("total_legendary_bosses_defeated", 0)
	report.average_prestige_per_gen = simulation_stats.get("average_prestige_per_generation", 0.0)

	# Determine final tier
	var tier_names = ["BRONZE", "SILVER", "GOLD", "PLATINUM", "DIAMOND", "ETERNAL"]
	if report.final_prestige < 1000:
		report.final_tier = tier_names[0]
	elif report.final_prestige < 5000:
		report.final_tier = tier_names[1]
	elif report.final_prestige < 15000:
		report.final_tier = tier_names[2]
	elif report.final_prestige < 35000:
		report.final_tier = tier_names[3]
	elif report.final_prestige < 75000:
		report.final_tier = tier_names[4]
	else:
		report.final_tier = tier_names[5]

	# Build prestige trajectory
	for record in generation_records:
		if record.get("generation", 0) % 50 == 0:  # Sample every 50 generations
			report.prestige_growth_trajectory.append({
				"generation": record.get("generation", 0),
				"prestige": record.get("prestige_at_end", 0)
			})

	# Build achievements summary
	report.achievements_summary = {
		"milestones_reached": report.total_milestones,
		"prophecies_fulfilled": report.total_prophecies,
		"legendary_encounters": report.legendary_bosses_defeated,
		"combat_victories": report.total_combats,
		"world_events": report.total_events
	}

	# Generate world impact summary
	report.world_impact_summary = _generate_world_impact(report)

	report_generated.emit("dynasty_report")
	return report


func generate_prestige_timeline(generation_records: Array) -> Array:
	var timeline = []

	for record in generation_records:
		if record.get("generation", 0) % 100 == 0:  # Every 100 generations
			timeline.append({
				"generation": record.get("generation", 0),
				"prestige": record.get("prestige_at_end", 0),
				"milestones_triggered": record.get("milestones_triggered", []).size(),
				"realm_reached": record.get("realm_reached", "starter_lands"),
				"combat_victories": record.get("combat_victories", 0)
			})

	return timeline


func generate_achievement_history(generation_records: Array) -> Dictionary:
	var history = {
		"milestone_generations": [],
		"prophecy_milestones": 0,
		"event_milestones": 0,
		"combat_milestones": 0,
		"legendary_defeats": []
	}

	var prophecy_count = 0
	var event_count = 0
	var combat_count = 0

	for record in generation_records:
		# Track milestone generations
		if record.get("milestones_triggered", []).size() > 0:
			history["milestone_generations"].append(record.get("generation", 0))

		# Accumulate counts
		prophecy_count += record.get("prophecies_fulfilled", 0)
		event_count += record.get("events_created", 0)
		combat_count += record.get("combat_victories", 0)

		# Track legendary defeats
		if record.get("legendary_bosses_defeated", []).size() > 0:
			for boss in record.get("legendary_bosses_defeated", []):
				history["legendary_defeats"].append({
					"generation": record.get("generation", 0),
					"boss": boss
				})

	history["prophecy_milestones"] = prophecy_count
	history["event_milestones"] = event_count
	history["combat_milestones"] = combat_count

	return history


func generate_validation_report(validation_results: Dictionary) -> Dictionary:
	var report = {
		"total_systems_validated": 0,
		"systems_passed": 0,
		"systems_failed": 0,
		"validation_details": {}
	}

	for system_name in validation_results.keys():
		report["total_systems_validated"] += 1
		var result = validation_results[system_name]

		if result:
			report["systems_passed"] += 1
		else:
			report["systems_failed"] += 1

		report["validation_details"][system_name] = result

	return report


func format_report_as_text(report: DynastyReport) -> String:
	var text = ""

	text += "═══════════════════════════════════════════════════\n"
	text += "  %s\n" % report.title
	text += "═══════════════════════════════════════════════════\n\n"

	text += "DYNASTY STATISTICS\n"
	text += "───────────────────────────────────────────────────\n"
	text += "Generations Spanned: %d\n" % report.generation_span
	text += "Final Prestige Level: %d (%s Tier)\n" % [report.final_prestige, report.final_tier]
	text += "Average Prestige per Generation: %.2f\n\n" % report.average_prestige_per_gen

	text += "MAJOR ACHIEVEMENTS\n"
	text += "───────────────────────────────────────────────────\n"
	text += "Milestones Reached: %d\n" % report.total_milestones
	text += "Prophecies Fulfilled: %d\n" % report.total_prophecies
	text += "Legendary Bosses Defeated: %d\n" % report.legendary_bosses_defeated
	text += "Combat Victories: %d\n" % report.total_combats
	text += "World Events Shaped: %d\n\n" % report.total_events

	text += "WORLD IMPACT\n"
	text += "───────────────────────────────────────────────────\n"
	text += report.world_impact_summary + "\n"

	text += "═══════════════════════════════════════════════════\n"

	return text


func export_report_data(report: DynastyReport) -> Dictionary:
	return {
		"title": report.title,
		"generation_span": report.generation_span,
		"final_prestige": report.final_prestige,
		"final_tier": report.final_tier,
		"total_milestones": report.total_milestones,
		"total_prophecies": report.total_prophecies,
		"total_events": report.total_events,
		"total_combats": report.total_combats,
		"legendary_bosses_defeated": report.legendary_bosses_defeated,
		"average_prestige_per_gen": report.average_prestige_per_gen,
		"achievements_summary": report.achievements_summary,
		"prestige_trajectory": report.prestige_growth_trajectory
	}


func _generate_world_impact(report: DynastyReport) -> String:
	var impact = ""

	match report.final_tier:
		"BRONZE":
			impact = "The dynasty's legacy is modest, limited to the starter lands. Few know their name."
		"SILVER":
			impact = "The dynasty has begun to establish itself. Their influence is felt in neighboring regions."
		"GOLD":
			impact = "A prominent dynasty known across many realms. Their deeds are recorded in local histories."
		"PLATINUM":
			impact = "A legendary dynasty whose influence shapes entire regions. Bards sing songs of their achievements."
		"DIAMOND":
			impact = "A transcendent dynasty that has reshaped the very fabric of their world. Their name is eternal."
		"ETERNAL":
			impact = "The ultimate dynasty. Their 999 generations span the ages. They have conquered realms, fulfilled prophecies, and defeated legendary foes. They are the architects of destiny itself."

	if report.total_prophecies > 0:
		impact += " %d prophecies were fulfilled through their actions." % report.total_prophecies

	if report.legendary_bosses_defeated > 0:
		impact += " They defeated %d legendary bosses." % report.legendary_bosses_defeated

	if report.total_milestones >= 5:
		impact += " Every generation milestone was reached."
	elif report.total_milestones > 0:
		impact += " %d major generational milestones were achieved." % report.total_milestones

	return impact
