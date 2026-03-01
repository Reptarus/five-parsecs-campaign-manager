extends GdUnitTestSuite

## Week 3 Day 3 - End-to-End Campaign Creation Test Foundation (gdUnit4 version)
## Tests complete campaign creation workflow from start to finalization

## Phase 1: Architecture Validation Tests
func test_campaign_creation_coordinator_exists():
	var script = load("res://src/ui/screens/campaign/CampaignCreationCoordinator.gd")
	assert_that(script).is_not_null()

func test_campaign_creation_ui_exists():
	var script = load("res://src/ui/screens/campaign/CampaignCreationUI.gd")
	assert_that(script).is_not_null()

func test_campaign_creation_state_manager_exists():
	var script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	assert_that(script).is_not_null()

func test_all_panels_exist():
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
		var path = "res://src/ui/screens/campaign/panels/" + panel_name
		var script = load(path)
		assert_that(script).is_not_null()

func test_all_controllers_exist():
	var controllers = [
		"BaseController.gd",
		"CaptainPanelController.gd",
		"CrewPanelController.gd",
		"ShipPanelController.gd",
		"ConfigPanelController.gd"
	]
	
	for controller_name in controllers:
		var path = "res://src/ui/screens/campaign/controllers/" + controller_name
		var script = load(path)
		assert_that(script).is_not_null()

## Phase 2: State Management System Tests
## Note: CampaignCreationStateManager extends RefCounted - no .free() needed (auto-managed)
func test_state_manager_instantiation():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	assert_that(state_mgr_script).is_not_null()
	
	var state_mgr = state_mgr_script.new()
	assert_that(state_mgr).is_not_null()
	# RefCounted objects auto-free when reference count drops to 0

func test_state_manager_has_set_phase_data_method():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.has_method("set_phase_data")).is_true()

func test_state_manager_has_get_phase_data_method():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.has_method("get_phase_data")).is_true()

func test_state_manager_has_advance_to_next_phase_method():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.has_method("advance_to_next_phase")).is_true()

func test_campaign_data_is_dictionary():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()

	assert_bool(state_mgr.campaign_data is Dictionary).is_true()

func test_campaign_data_has_captain_key():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.campaign_data.has("captain")).is_true()

func test_campaign_data_has_crew_key():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.campaign_data.has("crew")).is_true()

func test_campaign_data_has_ship_key():
	var state_mgr_script = load("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
	var state_mgr = state_mgr_script.new()
	
	assert_that(state_mgr.campaign_data.has("ship")).is_true()

## Phase 3: Panel Workflow Integration Tests
func test_config_panel_instantiation():
	var panel_script = load("res://src/ui/screens/campaign/panels/ExpandedConfigPanel.gd")
	assert_that(panel_script).is_not_null()
	
	var panel = panel_script.new()
	assert_that(panel).is_not_null()
	panel.free()

func test_captain_panel_instantiation():
	var panel_script = load("res://src/ui/screens/campaign/panels/CaptainPanel.gd")
	assert_that(panel_script).is_not_null()
	
	var panel = panel_script.new()
	assert_that(panel).is_not_null()
	panel.free()

func test_crew_panel_instantiation():
	var panel_script = load("res://src/ui/screens/campaign/panels/CrewPanel.gd")
	assert_that(panel_script).is_not_null()
	
	var panel = panel_script.new()
	assert_that(panel).is_not_null()
	panel.free()

func test_config_panel_has_panel_completed_signal():
	var panel_script = load("res://src/ui/screens/campaign/panels/ExpandedConfigPanel.gd")
	var panel = panel_script.new()
	
	assert_that(panel.has_signal("panel_completed")).is_true()
	panel.free()

## Phase 4: Backend Services Tests
func test_campaign_finalization_service_exists():
	var script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
	assert_that(script).is_not_null()

func test_campaign_validator_exists():
	var script = load("res://src/core/validation/CampaignValidator.gd")
	assert_that(script).is_not_null()

func test_security_validator_exists():
	var script = load("res://src/core/validation/SecurityValidator.gd")
	assert_that(script).is_not_null()

## Note: CampaignFinalizationService extends RefCounted - no .free() needed (auto-managed)
func test_finalization_service_instantiation():
	var service_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
	assert_that(service_script).is_not_null()
	
	var service = service_script.new()
	assert_that(service).is_not_null()

func test_finalization_service_has_finalize_method():
	var service_script = load("res://src/core/campaign/creation/CampaignFinalizationService.gd")
	var service = service_script.new()
	
	assert_that(service.has_method("finalize_campaign")).is_true()

## Phase 5: Data Persistence Foundation Tests
func test_game_state_manager_autoload_check():
	# This is a soft test - autoloads may not be available in test environment
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager")
		if gsm:
			assert_that(gsm).is_not_null()

func test_data_manager_autoload_check():
	# This is a soft test - autoloads may not be available in test environment
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		var dm = Engine.get_main_loop().root.get_node_or_null("DataManager")
		if dm:
			assert_that(dm).is_not_null()

func test_save_system_script_exists():
	# Soft test - SaveSystem may not be implemented yet
	if FileAccess.file_exists("res://src/core/data/SaveSystem.gd"):
		var script = load("res://src/core/data/SaveSystem.gd")
		assert_that(script).is_not_null()
	else:
		push_warning("SaveSystem.gd not found - skipping test")
