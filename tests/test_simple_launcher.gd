## Simple Test Launcher - Load and run Phase 16 trait tests
##
## This validates that systems load correctly in Godot

extends Node

func _ready() -> void:
	print("\n" + "═" * 80)
	print("GENERATIONAL LEGACY RPG - System Test Launcher")
	print("═" * 80 + "\n")

	print("Testing Phase 16: Traits & Lineage...")
	await run_phase_16_test()

	print("\nAll systems loaded successfully!")
	print("✓ You can now open individual test files in the Godot editor")
	print("✓ Or create a full launcher scene")
	print("\n" + "═" * 80 + "\n")

	get_tree().quit()


func run_phase_16_test() -> void:
	print("\n▶ Loading TraitDefinition system...")
	var trait_def = TraitDefinition.new()
	print("✓ TraitDefinition loaded")

	var iron_blood = trait_def.get_trait("iron_blood")
	if iron_blood:
		print("  ✓ Iron Blood trait: %s" % iron_blood.name)
		print("    - Stat bonus: %s" % iron_blood.stat_modifiers)

	print("\n▶ Loading TraitInheritance system...")
	var trait_inherit = TraitInheritance.new()
	print("✓ TraitInheritance loaded")

	print("\n▶ Loading BloodlineSystem...")
	var bloodline = BloodlineSystem.new()
	print("✓ BloodlineSystem loaded")

	print("\n✓ Phase 16 systems verified")

	await get_tree().create_timer(0.5).timeout
