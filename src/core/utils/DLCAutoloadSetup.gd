class_name DLCAutoloadSetup
extends RefCounted

## DLCAutoloadSetup
##
## Utility script to verify and help configure DLC system autoloads.
## Can be used to check if all required autoloads are properly registered.
##
## Usage:
##   var setup := DLCAutoloadSetup.new()
##   setup.verify_autoloads() # Returns true if all OK
##   setup.print_autoload_config() # Prints config for project.godot

## Required autoloads for DLC system
const REQUIRED_AUTOLOADS := {
	"ExpansionManager": "res://src/core/managers/ExpansionManager.gd",
	"PsionicSystem": "res://src/core/systems/PsionicSystem.gd",
	"DifficultyScalingSystem": "res://src/core/systems/DifficultyScalingSystem.gd",
	"EliteEnemySystem": "res://src/core/systems/EliteEnemySystem.gd",
	"StealthMissionSystem": "res://src/core/systems/StealthMissionSystem.gd",
	"SalvageJobSystem": "res://src/core/systems/SalvageJobSystem.gd"
}

## Verify all required autoloads are registered
func verify_autoloads() -> bool:
	var all_present := true
	var missing_autoloads := []

	for autoload_name in REQUIRED_AUTOLOADS.keys():
		if not _is_autoload_registered(autoload_name):
			all_present = false
			missing_autoloads.append(autoload_name)
			push_warning("DLCAutoloadSetup: Missing autoload '%s'" % autoload_name)

	if all_present:
		print("DLCAutoloadSetup: All DLC autoloads are properly registered ✓")
	else:
		push_error("DLCAutoloadSetup: Missing autoloads: %s" % str(missing_autoloads))
		print("\nAdd these lines to your project.godot [autoload] section:")
		print_autoload_config()

	return all_present

## Print autoload configuration for project.godot
func print_autoload_config() -> void:
	print("\n=== Add to project.godot [autoload] section ===\n")

	for autoload_name in REQUIRED_AUTOLOADS.keys():
		var path := REQUIRED_AUTOLOADS[autoload_name]
		print('%s="*%s"' % [autoload_name, path])

	print("\n=== End of autoload configuration ===\n")

## Get autoload configuration as a string
func get_autoload_config_string() -> String:
	var config := ""

	for autoload_name in REQUIRED_AUTOLOADS.keys():
		var path := REQUIRED_AUTOLOADS[autoload_name]
		config += '%s="*%s"\n' % [autoload_name, path]

	return config

## Check if specific autoload is registered
func is_autoload_available(autoload_name: String) -> bool:
	return _is_autoload_registered(autoload_name)

## Get list of missing autoloads
func get_missing_autoloads() -> Array:
	var missing := []

	for autoload_name in REQUIRED_AUTOLOADS.keys():
		if not _is_autoload_registered(autoload_name):
			missing.append(autoload_name)

	return missing

## Get diagnostic information
func get_diagnostics() -> Dictionary:
	var diagnostics := {
		"total_required": REQUIRED_AUTOLOADS.size(),
		"registered": 0,
		"missing": [],
		"all_ok": false
	}

	for autoload_name in REQUIRED_AUTOLOADS.keys():
		if _is_autoload_registered(autoload_name):
			diagnostics.registered += 1
		else:
			diagnostics.missing.append(autoload_name)

	diagnostics.all_ok = diagnostics.missing.is_empty()

	return diagnostics

## Print detailed diagnostics
func print_diagnostics() -> void:
	var diag := get_diagnostics()

	print("\n=== DLC Autoload Diagnostics ===")
	print("Total Required: %d" % diag.total_required)
	print("Registered: %d" % diag.registered)

	if diag.all_ok:
		print("Status: ✓ All systems operational")
	else:
		print("Status: ✗ Missing autoloads detected")
		print("Missing: %s" % str(diag.missing))

	print("================================\n")

## Test all autoload functionality
func test_autoloads() -> bool:
	print("\n=== Testing DLC Autoloads ===")

	var all_working := true

	# Test ExpansionManager
	if _test_expansion_manager():
		print("✓ ExpansionManager working")
	else:
		print("✗ ExpansionManager failed")
		all_working = false

	# Test PsionicSystem
	if _test_psionic_system():
		print("✓ PsionicSystem working")
	else:
		print("✗ PsionicSystem failed")
		all_working = false

	# Test DifficultyScalingSystem
	if _test_difficulty_system():
		print("✓ DifficultyScalingSystem working")
	else:
		print("✗ DifficultyScalingSystem failed")
		all_working = false

	# Test EliteEnemySystem
	if _test_elite_system():
		print("✓ EliteEnemySystem working")
	else:
		print("✗ EliteEnemySystem failed")
		all_working = false

	# Test StealthMissionSystem
	if _test_stealth_system():
		print("✓ StealthMissionSystem working")
	else:
		print("✗ StealthMissionSystem failed")
		all_working = false

	# Test SalvageJobSystem
	if _test_salvage_system():
		print("✓ SalvageJobSystem working")
	else:
		print("✗ SalvageJobSystem failed")
		all_working = false

	if all_working:
		print("\n✓ All systems functional\n")
	else:
		print("\n✗ Some systems failed - check errors above\n")

	return all_working

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _is_autoload_registered(autoload_name: String) -> bool:
	# Try to access the autoload via Engine singleton
	if Engine.has_singleton(autoload_name):
		return true

	# Try to access via scene tree (for non-singleton autoloads)
	var scene_tree := Engine.get_main_loop()
	if scene_tree and scene_tree.has_node("/root/" + autoload_name):
		return true

	return false

func _test_expansion_manager() -> bool:
	if not Engine.has_singleton("ExpansionManager"):
		return false

	var em = Engine.get_singleton("ExpansionManager")
	return em != null and em.has_method("is_expansion_available")

func _test_psionic_system() -> bool:
	if not Engine.has_singleton("PsionicSystem"):
		return false

	var ps = Engine.get_singleton("PsionicSystem")
	return ps != null and ps.has_method("get_all_powers")

func _test_difficulty_system() -> bool:
	if not Engine.has_singleton("DifficultyScalingSystem"):
		return false

	var ds = Engine.get_singleton("DifficultyScalingSystem")
	return ds != null and ds.has_method("set_difficulty_preset")

func _test_elite_system() -> bool:
	if not Engine.has_singleton("EliteEnemySystem"):
		return false

	var es = Engine.get_singleton("EliteEnemySystem")
	return es != null and es.has_method("get_elite_version")

func _test_stealth_system() -> bool:
	if not Engine.has_singleton("StealthMissionSystem"):
		return false

	var sm = Engine.get_singleton("StealthMissionSystem")
	return sm != null and sm.has_method("start_stealth_mission")

func _test_salvage_system() -> bool:
	if not Engine.has_singleton("SalvageJobSystem"):
		return false

	var sj = Engine.get_singleton("SalvageJobSystem")
	return sj != null and sj.has_method("start_salvage_mission")
