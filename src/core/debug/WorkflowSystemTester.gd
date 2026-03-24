## WorkflowSystemTester.gd
## Comprehensive workflow testing utilities for development dashboard
## Created: 2025-11-19 (Boot error fix)
## Updated: 2025-12-28 (Implemented actual tests)

class_name WorkflowSystemTester
extends Object

## Runs comprehensive workflow system tests
## Returns Dictionary with test results
static func run_comprehensive_test() -> Dictionary:
	var results = {
		"overall_success": true,
		"tests_passed": 0,
		"tests_failed": 0,
		"test_details": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	var start_time: int = Time.get_ticks_msec()

	# Test 1: GameState Autoload
	var test1_start: int = Time.get_ticks_msec()
	var game_state = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	_add_test_result(results, "GameState Autoload", game_state != null, Time.get_ticks_msec() - test1_start)

	# Test 2: GameStateManager Autoload
	var test2_start: int = Time.get_ticks_msec()
	var game_state_manager = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	_add_test_result(results, "GameStateManager Autoload", game_state_manager != null, Time.get_ticks_msec() - test2_start)

	# Test 3: DiceManager Autoload
	var test3_start: int = Time.get_ticks_msec()
	var dice_manager = Engine.get_main_loop().root.get_node_or_null("/root/DiceManager")
	_add_test_result(results, "DiceManager Autoload", dice_manager != null, Time.get_ticks_msec() - test3_start)

	# Test 4: EquipmentManager Autoload
	var test4_start: int = Time.get_ticks_msec()
	var equipment_manager = Engine.get_main_loop().root.get_node_or_null("/root/EquipmentManager")
	_add_test_result(results, "EquipmentManager Autoload", equipment_manager != null, Time.get_ticks_msec() - test4_start)

	# Test 5: CampaignCreationStateManager loadable
	var test5_start: int = Time.get_ticks_msec()
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	_add_test_result(results, "CampaignCreationStateManager Script", state_mgr_script != null, Time.get_ticks_msec() - test5_start)

	# Test 6: GlobalEnums loadable
	var test6_start: int = Time.get_ticks_msec()
	var global_enums_script = load("res://src/core/systems/GlobalEnums.gd")
	_add_test_result(results, "GlobalEnums Script", global_enums_script != null, Time.get_ticks_msec() - test6_start)

	# Test 7: Core data files exist
	var test7_start: int = Time.get_ticks_msec()
	var data_exists: bool = ResourceLoader.exists("res://data/equipment_database.json") or ResourceLoader.exists("res://data/weapons.json")
	_add_test_result(results, "Core Data Files", data_exists, Time.get_ticks_msec() - test7_start)

	# Update overall success
	results["overall_success"] = results["tests_failed"] == 0
	results["total_duration_ms"] = Time.get_ticks_msec() - start_time

	return results

## Helper to add test result
static func _add_test_result(results: Dictionary, name: String, passed: bool, duration_ms: int) -> void:
	results["test_details"].append({
		"name": name,
		"status": "passed" if passed else "failed",
		"duration_ms": duration_ms
	})
	if passed:
		results["tests_passed"] += 1
	else:
		results["tests_failed"] += 1

## Generates a formatted test summary from test results
## Returns multi-line string summary
static func get_test_summary(results: Dictionary) -> String:
	if not results:
		return "\n⚠️ No test results available"

	var summary = "\n" + "=".repeat(60)
	summary += "\n🔬 WORKFLOW SYSTEM TEST RESULTS"
	summary += "\n" + "=".repeat(60)

	summary += "\n✅ Tests Passed: %d" % results.get("tests_passed", 0)
	summary += "\n❌ Tests Failed: %d" % results.get("tests_failed", 0)

	if results.has("total_duration_ms"):
		summary += "\n⏱️ Total Time: %dms" % results.get("total_duration_ms", 0)

	var overall = results.get("overall_success", false)
	summary += "\n\n📊 Overall Status: %s" % ("PASS ✅" if overall else "FAIL ❌")

	if results.has("test_details") and not results.test_details.is_empty():
		summary += "\n\n📋 Test Details:"
		for test in results.test_details:
			var status_icon = "✅" if test.status == "passed" else "❌"
			summary += "\n  %s %s" % [status_icon, test.get("name", "Unknown Test")]
			if test.has("duration_ms"):
				summary += " (%dms)" % test.duration_ms

	summary += "\n" + "=".repeat(60)

	return summary

## Quick sanity check for basic workflow functionality
## Returns true if basic workflows are operational
static func quick_sanity_check() -> bool:
	# Check core autoloads are accessible
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		return false

	var game_state = root.get_node_or_null("/root/GameState")
	var game_state_manager = root.get_node_or_null("/root/GameStateManager")

	# At minimum, GameState should exist
	if not game_state:
		push_warning("WorkflowSystemTester: GameState autoload not found")
		return false

	# Check essential script can be loaded
	var state_mgr = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	if not state_mgr:
		push_warning("WorkflowSystemTester: CampaignCreationStateManager not loadable")
		return false

	return true
