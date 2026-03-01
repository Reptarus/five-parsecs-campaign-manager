extends SceneTree

## Test Conversion Verification Script
## Compares legacy SceneTree tests with gdUnit4 conversions
## to ensure equivalent functionality

var verification_results = {
	"legacy_tests_run": 0,
	"gdunit4_tests_run": 0,
	"comparison_checks": 0,
	"discrepancies": 0,
	"warnings": []
}

func _init():
	print("\n" + "=".repeat(80))
	print("TEST CONVERSION VERIFICATION")
	print("Comparing Legacy SceneTree Tests vs gdUnit4 Conversions")
	print("=".repeat(80) + "\n")
	
	_verify_test_files_exist()
	_verify_test_structure()
	_print_verification_summary()
	
	quit()

## Verify all test files exist in both legacy and new locations
func _verify_test_files_exist():
	print("[PHASE 1] Test File Existence Verification")
	print("-".repeat(80))
	
	var test_pairs = [
		{
			"name": "Economy System Tests",
			"legacy": "tests/legacy/test_economy_system.gd",
			"gdunit4": "tests/unit/test_economy_system.gd"
		},
		{
			"name": "Campaign Save/Load Tests",
			"legacy": "tests/legacy/test_campaign_save_load.gd",
			"gdunit4": "tests/integration/test_campaign_save_load.gd"
		},
		{
			"name": "Campaign Workflow Tests",
			"legacy": "tests/legacy/test_campaign_e2e_workflow.gd",
			"gdunit4": "tests/integration/test_campaign_workflow.gd"
		},
		{
			"name": "Campaign Foundation Tests",
			"legacy": "tests/legacy/test_campaign_e2e_foundation.gd",
			"gdunit4": "tests/integration/test_campaign_foundation.gd"
		}
	]
	
	for pair in test_pairs:
		_check_test_pair(pair)
	
	print("")

## Check if both legacy and gdUnit4 versions exist
func _check_test_pair(pair: Dictionary):
	var legacy_exists = FileAccess.file_exists("res://" + pair.legacy)
	var gdunit4_exists = FileAccess.file_exists("res://" + pair.gdunit4)
	
	if legacy_exists and gdunit4_exists:
		print("  ✅ %s: Both versions exist" % pair.name)
		verification_results.legacy_tests_run += 1
		verification_results.gdunit4_tests_run += 1
	elif legacy_exists and not gdunit4_exists:
		print("  ❌ %s: Legacy exists but gdUnit4 version missing!" % pair.name)
		verification_results.discrepancies += 1
	elif not legacy_exists and gdunit4_exists:
		print("  ⚠️  %s: gdUnit4 exists but legacy version missing" % pair.name)
		verification_results.warnings.append("Legacy test missing: " + pair.name)
	else:
		print("  ❌ %s: Both versions missing!" % pair.name)
		verification_results.discrepancies += 1

## Verify test structure conversion
func _verify_test_structure():
	print("[PHASE 2] Test Structure Verification")
	print("-".repeat(80))
	
	# Verify gdUnit4 tests extend GdUnitTestSuite
	_verify_gdunit_structure("tests/unit/test_economy_system.gd", "Economy System")
	_verify_gdunit_structure("tests/integration/test_campaign_save_load.gd", "Save/Load")
	_verify_gdunit_structure("tests/integration/test_campaign_workflow.gd", "Workflow")
	_verify_gdunit_structure("tests/integration/test_campaign_foundation.gd", "Foundation")
	
	# Verify legacy tests extend SceneTree
	_verify_legacy_structure("tests/legacy/test_economy_system.gd", "Economy System")
	_verify_legacy_structure("tests/legacy/test_campaign_save_load.gd", "Save/Load")
	_verify_legacy_structure("tests/legacy/test_campaign_e2e_workflow.gd", "Workflow")
	_verify_legacy_structure("tests/legacy/test_campaign_e2e_foundation.gd", "Foundation")
	
	print("")

## Verify gdUnit4 test structure
func _verify_gdunit_structure(path: String, name: String):
	var file = FileAccess.open("res://" + path, FileAccess.READ)
	if not file:
		print("  ❌ %s: Cannot read gdUnit4 test file" % name)
		verification_results.discrepancies += 1
		return
	
	var content = file.get_as_text()
	file.close()
	
	verification_results.comparison_checks += 1
	
	if "extends GdUnitTestSuite" in content:
		print("  ✅ %s: Correctly extends GdUnitTestSuite" % name)
	else:
		print("  ❌ %s: Does NOT extend GdUnitTestSuite!" % name)
		verification_results.discrepancies += 1
	
	# Check for test methods (func test_...)
	var test_method_count = 0
	var lines = content.split("\n")
	for line in lines:
		if line.begins_with("func test_"):
			test_method_count += 1
	
	if test_method_count > 0:
		print("      → Found %d test methods" % test_method_count)
	else:
		print("      ⚠️ No test methods found (func test_...)")
		verification_results.warnings.append(name + ": No test methods found")

## Verify legacy test structure
func _verify_legacy_structure(path: String, name: String):
	var file = FileAccess.open("res://" + path, FileAccess.READ)
	if not file:
		print("  ❌ %s: Cannot read legacy test file" % name)
		verification_results.discrepancies += 1
		return
	
	var content = file.get_as_text()
	file.close()
	
	verification_results.comparison_checks += 1
	
	if "extends SceneTree" in content:
		print("  ✅ %s Legacy: Correctly extends SceneTree" % name)
	else:
		print("  ❌ %s Legacy: Does NOT extend SceneTree!" % name)
		verification_results.discrepancies += 1

## Print verification summary
func _print_verification_summary():
	print("=".repeat(80))
	print("VERIFICATION SUMMARY")
	print("=".repeat(80))
	print("Legacy Tests Found: %d" % verification_results.legacy_tests_run)
	print("gdUnit4 Tests Found: %d" % verification_results.gdunit4_tests_run)
	print("Structure Checks: %d" % verification_results.comparison_checks)
	print("Discrepancies: %d" % verification_results.discrepancies)
	print("Warnings: %d" % verification_results.warnings.size())
	print("")
	
	if verification_results.warnings.size() > 0:
		print("Warnings:")
		for warning in verification_results.warnings:
			print("  ⚠️  %s" % warning)
		print("")
	
	if verification_results.discrepancies == 0:
		print("✅ VERIFICATION STATUS: ALL CHECKS PASSED")
		print("Test conversion appears to be successful!")
		print("")
		print("Next Steps:")
		print("1. Run legacy tests: godot --headless --script tests/legacy/test_economy_system.gd")
		print("2. Run gdUnit4 tests: Open Godot Editor → gdUnit4 panel → Run tests")
		print("3. Compare results manually for functional equivalence")
	else:
		print("⚠️ VERIFICATION STATUS: %d DISCREPANCIES FOUND" % verification_results.discrepancies)
		print("Review the issues above before proceeding")
	
	print("=".repeat(80) + "\n")

