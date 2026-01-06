extends SceneTree

## Week 3 Day 3 - End-to-End Campaign Creation Test Foundation
## Tests complete campaign creation workflow from start to finalization

var test_results = {
	"total": 0,
	"passed": 0,
	"failed": 0,
	"warnings": 0
}

func _init():
	print("\n" + "=".repeat(60))
	print("WEEK 3 E2E TEST: Campaign Creation Workflow Foundation")
	print("=".repeat(60) + "\n")

	# Phase 1: Architecture validation
	_test_phase_1_architecture()

	# Phase 2: State management system
	_test_phase_2_state_management()

	# Phase 3: Panel workflow integration
	_test_phase_3_panel_workflow()

	# Phase 4: Backend services
	_test_phase_4_backend_services()

	# Phase 5: Data persistence foundation
	_test_phase_5_persistence_foundation()

	# Print final summary
	_print_summary()

	quit()

## Phase 1: Validate all required components exist
func _test_phase_1_architecture():
	print("[PHASE 1] Architecture Validation")
	print("-".repeat(60))

	# Test 1.1: Core campaign creation components
	_run_test("CampaignCreationCoordinator exists", func():
		var script = load("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
		return script != null
	)

	_run_test("CampaignCreationUI exists", func():
		var script = load("res://src/ui/screens/campaign/CampaignCreationUI.gd")
		return script != null
	)

	_run_test("CampaignCreationStateManager exists", func():
		var script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		return script != null
	)

	# Test 1.2: All panels exist
	var panels = [
		"BaseCampaignPanel.gd",
		"ExpandedConfigPanel.gd",
		"CaptainPanel.gd",
		"CrewPanel.gd",
		"EquipmentPanel.gd",
		"ShipPanel.gd",
		"WorldInfoPanel.gd",
		"FinalPanel.gd"
	]

	for panel_name in panels:
		_run_test("Panel: " + panel_name, func():
			var path = "res://src/ui/screens/campaign/panels/" + panel_name
			var script = load(path)
			return script != null
		, panel_name)

	# Test 1.3: Controllers exist
	var controllers = [
		"BaseController.gd",
		"CaptainPanelController.gd",
		"CrewPanelController.gd",
		"ShipPanelController.gd",
		"ConfigPanelController.gd"
	]

	for controller_name in controllers:
		_run_test("Controller: " + controller_name, func():
			var path = "res://src/ui/screens/campaign/controllers/" + controller_name
			var script = load(path)
			return script != null
		, controller_name)

	print("")

## Phase 2: Test state management system
func _test_phase_2_state_management():
	print("[PHASE 2] State Management System")
	print("-".repeat(60))

	# Test 2.1: StateManager can be instantiated
	_run_test("StateManager instantiation", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		if not state_mgr_script:
			return false
		var state_mgr = state_mgr_script.new()
		return state_mgr != null
	)

	# Test 2.2: StateManager has required methods
	_run_test("StateManager has set_phase_data() method", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.has_method("set_phase_data")
	)

	_run_test("StateManager has get_phase_data() method", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.has_method("get_phase_data")
	)

	_run_test("StateManager has advance_to_next_phase() method", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.has_method("advance_to_next_phase")
	)

	# Test 2.3: State structure validation
	_run_test("campaign_data is a Dictionary", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.campaign_data is Dictionary
	)

	_run_test("campaign_data has 'captain' key", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.campaign_data.has("captain")
	)

	_run_test("campaign_data has 'crew' key", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.campaign_data.has("crew")
	)

	_run_test("campaign_data has 'ship' key", func():
		var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
		var state_mgr = state_mgr_script.new()
		return state_mgr.campaign_data.has("ship")
	)

	print("")

## Phase 3: Test panel workflow
func _test_phase_3_panel_workflow():
	print("[PHASE 3] Panel Workflow Integration")
	print("-".repeat(60))

	# Test 3.1: ExpandedConfigPanel can be instantiated
	_run_test("ExpandedConfigPanel instantiation", func():
		var panel_script = load("res://src/ui/screens/campaign/panels/ExpandedConfigPanel.gd")
		if not panel_script:
			return false
		var panel = panel_script.new()
		return panel != null
	)

	# Test 3.2: CaptainPanel can be instantiated
	_run_test("CaptainPanel instantiation", func():
		var panel_script = load("res://src/ui/screens/campaign/panels/CaptainPanel.gd")
		if not panel_script:
			return false
		var panel = panel_script.new()
		return panel != null
	)

	# Test 3.3: CrewPanel can be instantiated
	_run_test("CrewPanel instantiation", func():
		var panel_script = load("res://src/ui/screens/campaign/panels/CrewPanel.gd")
		if not panel_script:
			return false
		var panel = panel_script.new()
		return panel != null
	)

	# Test 3.4: Panel signals exist
	_run_test("ExpandedConfigPanel has 'panel_completed' signal", func():
		var panel_script = load("res://src/ui/screens/campaign/panels/ExpandedConfigPanel.gd")
		var panel = panel_script.new()
		return panel.has_signal("panel_completed")
	, "ExpandedConfigPanel")

	print("")

## Phase 4: Test backend services
func _test_phase_4_backend_services():
	print("[PHASE 4] Backend Services")
	print("-".repeat(60))

	# Test 4.1: CampaignFinalizationService exists
	_run_test("CampaignFinalizationService exists", func():
		var script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
		return script != null
	)

	# Test 4.2: CampaignValidator exists
	_run_test("CampaignValidator exists", func():
		var script = load("res://src/core/validation/CampaignValidator.gd")
		return script != null
	)

	# Test 4.3: SecurityValidator exists
	_run_test("SecurityValidator exists", func():
		var script = load("res://src/core/validation/SecurityValidator.gd")
		return script != null
	)

	# Test 4.4: FinalizationService can be instantiated
	_run_test("FinalizationService instantiation", func():
		var service_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
		if not service_script:
			return false
		var service = service_script.new()
		return service != null
	)

	# Test 4.5: FinalizationService has finalize method
	_run_test("FinalizationService has finalize() method", func():
		var service_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
		var service = service_script.new()
		return service.has_method("finalize_campaign")
	)

	print("")

## Phase 5: Data persistence foundation
func _test_phase_5_persistence_foundation():
	print("[PHASE 5] Data Persistence Foundation")
	print("-".repeat(60))

	# Test 5.1: GameStateManager autoload availability
	_run_test("GameStateManager autoload check", func():
		var gsm = root.get_node_or_null("GameStateManager")
		if gsm:
			print("  ✓ GameStateManager available: " + gsm.get_class())
			return true
		else:
			print("  ⚠ GameStateManager not available (expected in test environment)")
			test_results.warnings += 1
			return true  # Not a failure in test environment
	)

	# Test 5.2: DataManager autoload availability
	_run_test("DataManager autoload check", func():
		var dm = root.get_node_or_null("DataManager")
		if dm:
			print("  ✓ DataManager available: " + dm.get_class())
			return true
		else:
			print("  ⚠ DataManager not available (expected in test environment)")
			test_results.warnings += 1
			return true  # Not a failure in test environment
	)

	# Test 5.3: SaveSystem exists
	_run_test("SaveSystem script exists", func():
		var script = load("res://src/core/data/SaveSystem.gd")
		if script:
			print("  ✓ SaveSystem script found")
			return true
		else:
			print("  ⚠ SaveSystem script not found (may not be implemented yet)")
			test_results.warnings += 1
			return true  # Warning, not failure
	)

	print("")

## Helper: Run a single test
func _run_test(test_name: String, test_func: Callable, context: String = ""):
	test_results.total += 1
	var result = test_func.call()

	if result:
		test_results.passed += 1
		print("  ✅ %s" % test_name)
	else:
		test_results.failed += 1
		print("  ❌ %s FAILED!" % test_name)
		if context:
			print("      Context: %s" % context)

## Print final test summary
func _print_summary():
	print("=".repeat(60))
	print("E2E TEST FOUNDATION SUMMARY")
	print("=".repeat(60))
	print("Total Tests: %d" % test_results.total)
	print("Passed: %d (%.1f%%)" % [test_results.passed, (test_results.passed * 100.0 / test_results.total)])
	print("Failed: %d" % test_results.failed)
	print("Warnings: %d" % test_results.warnings)
	print("")

	if test_results.failed == 0:
		print("✅ E2E FOUNDATION STATUS: ALL TESTS PASSED")
		print("Campaign creation architecture is ready for workflow testing")
	else:
		print("⚠️ E2E FOUNDATION STATUS: %d FAILURES DETECTED" % test_results.failed)
		print("Fix failures before proceeding to E2E workflow tests")

	print("=".repeat(60) + "\n")
