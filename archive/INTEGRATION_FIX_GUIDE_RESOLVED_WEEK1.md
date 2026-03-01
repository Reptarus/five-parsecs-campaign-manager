# COMPLETE CAMPAIGN CREATION INTEGRATION FIX
# Follow these steps IN ORDER to fix all integration issues

## ✅ COMPLETED: Removed Problematic Files
- signal_connections_fix.gd (DELETED)
- finalization_integration.gd (DELETED)

## 📝 MANUAL FIXES REQUIRED IN CampaignCreationUI.gd

### STEP 1: Fix Duplicate Variable Declarations
# Search for these lines and apply fixes:

1. Line ~101: Duplicate "_navigation_update_timer"
   FIND: Second occurrence of "var _navigation_update_timer: Timer"
   ACTION: Delete the entire line

2. Line ~435 & 442: Duplicate "result" variables  
   FIND: In _ensure_save_directory() function
   CHANGE: var result = dir.make_dir_recursive("campaigns")
   TO: var dir_result = dir.make_dir_recursive("campaigns")
   AND UPDATE: if result != OK: 
   TO: if dir_result != OK:

### STEP 2: Fix Duplicate Function Declarations

1. Line ~2389: Duplicate "_connect_standard_panel_signals"
   ACTION: Delete the entire second function definition

2. Line ~3431: Duplicate "_schedule_navigation_update"
   ACTION: Delete the entire second function definition

### STEP 3: Replace Empty _connect_panel_signals() Method
# Find the EMPTY _connect_panel_signals() method (around line 1379)
# Replace it with this COMPLETE implementation:

func _connect_panel_signals() -> void:
	"""Connect all panel-specific signals with complete implementation"""
	if not current_panel:
		push_warning("CampaignCreationUI: No current panel to connect signals")
		return
	
	print("CampaignCreationUI: Connecting signals for current panel")
	
	# Connect panel to state manager
	if current_panel.has_method("set_state_manager"):
		current_panel.set_state_manager(state_manager)
	
	# Connect standard signals using proper Callable syntax
	if current_panel.has_signal("panel_data_changed"):
		if not current_panel.is_connected("panel_data_changed", _on_panel_data_changed):
			current_panel.panel_data_changed.connect(_on_panel_data_changed)
	
	if current_panel.has_signal("panel_validation_changed"):
		if not current_panel.is_connected("panel_validation_changed", _on_panel_validation_changed):
			current_panel.panel_validation_changed.connect(_on_panel_validation_changed)
	
	if current_panel.has_signal("panel_completed"):
		if not current_panel.is_connected("panel_completed", _on_panel_completed):
			current_panel.panel_completed.connect(_on_panel_completed)
	
	# Connect phase-specific signals
	match state_manager.current_phase:
		CampaignStateManager.Phase.CONFIG:
			_connect_config_panel_signals()
		CampaignStateManager.Phase.CREW_SETUP:
			_connect_crew_panel_signals()
		CampaignStateManager.Phase.CAPTAIN_CREATION:
			_connect_captain_panel_signals()
		CampaignStateManager.Phase.SHIP_ASSIGNMENT:
			_connect_ship_panel_signals()
		CampaignStateManager.Phase.EQUIPMENT_GENERATION:
			_connect_equipment_panel_signals()
		CampaignStateManager.Phase.WORLD_GENERATION:
			_connect_world_panel_signals()
		CampaignStateManager.Phase.FINAL_REVIEW:
			_connect_final_panel_signals()
	
	print("CampaignCreationUI: Panel signals connected for phase: %s" % str(state_manager.current_phase))

### STEP 4: Add/Update Handler Methods
# Add these methods if they don't exist, or update if they do:

func _on_panel_data_changed(data: Dictionary) -> void:
	"""Handle real-time panel data updates"""
	if not state_manager:
		return
	
	var current_phase = state_manager.current_phase
	
	# Validate data if security validator exists
	if security_validator:
		var validation_result = security_validator.validate_dictionary_input(data, 5000)
		if not validation_result.valid:
			push_warning("Panel data validation failed: %s" % validation_result.error)
			return
		data = validation_result.sanitized_value
	
	# Update state manager
	state_manager.set_phase_data(current_phase, data)
	
	# Schedule navigation update
	_schedule_navigation_update()
	
	# Emit update signal
	if has_signal("campaign_data_updated"):
		campaign_data_updated.emit(state_manager.get_campaign_data())

func _on_panel_validation_changed(is_valid: bool, errors: Array) -> void:
	"""Handle panel validation state changes"""
	print("CampaignCreationUI: Panel validation changed - Valid: %s" % str(is_valid))
	
	if not coordinator or not state_manager:
		return
	
	# Update coordinator
	coordinator.mark_phase_complete(state_manager.current_phase, is_valid)
	
	# Update navigation
	_update_navigation_state()

### STEP 5: Add Finalization Service Integration
# At the top of the file with other preloads, ADD:

const CampaignFinalizationService = preload("res://src/core/campaign/creation/CampaignFinalizationService.gd")
var finalization_service: CampaignFinalizationService

# In _initialize_refactored_architecture() method, ADD:

	# Initialize finalization service
	finalization_service = CampaignFinalizationService.new()
	finalization_service.finalization_started.connect(_on_finalization_started)
	finalization_service.validation_completed.connect(_on_finalization_validation_completed)
	finalization_service.save_completed.connect(_on_finalization_save_completed)
	finalization_service.finalization_failed.connect(_on_finalization_failed)
	finalization_service.finalization_completed.connect(_on_finalization_completed)

# Add these handler methods at the end of the file:

func _on_finalization_started() -> void:
	_show_loading_state(true, "Validating campaign data...")

func _on_finalization_validation_completed(result: Dictionary) -> void:
	if result.success:
		_show_loading_state(true, "Creating campaign files...")
	else:
		_show_loading_state(false)
		if result.has("error"):
			_show_validation_dialog("Validation Failed", [result.error])

func _on_finalization_save_completed(success: bool, path: String) -> void:
	if success:
		print("Campaign saved to: %s" % path)
		_show_loading_state(true, "Finalizing...")
	else:
		_show_loading_state(false)
		_show_error_dialog("Failed to save campaign")

func _on_finalization_failed(error: String) -> void:
	_show_loading_state(false)
	_show_error_dialog("Campaign Creation Failed: %s" % error)

func _on_finalization_completed(campaign: Resource) -> void:
	_show_loading_state(false)
	print("✅ Campaign creation completed!")
	
	# Clear persistence data
	_clear_persistence_data()
	
	# Emit completion signal
	if has_signal("campaign_creation_completed"):
		var campaign_dict = {}
		if campaign.has_method("to_dictionary"):
			campaign_dict = campaign.to_dictionary()
		campaign_creation_completed.emit(campaign_dict)
	
	# Transition to main scene
	var scene_path = "res://src/ui/screens/campaign/MainCampaignScene.tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)

### STEP 6: Update _finalize_campaign_creation Method
# Find _finalize_campaign_creation (around line 451) and UPDATE to use the service:

func _finalize_campaign_creation(campaign_data: Dictionary) -> void:
	"""Production-ready campaign finalization with service"""
	print("CampaignCreationUI: Starting campaign finalization...")
	
	# Extract the actual campaign data
	var final_data = campaign_data.get("campaign_data", campaign_data)
	
	if finalization_service:
		# Use the finalization service
		var result = await finalization_service.finalize_campaign(final_data, state_manager)
		
		if not result.success:
			push_error("Campaign finalization failed: %s" % result.get("error", "Unknown error"))
	else:
		push_error("Finalization service not initialized!")
		_show_error_dialog("Campaign finalization service not available")

## 🔍 VERIFICATION CHECKLIST

After applying all fixes:
1. [ ] No duplicate variable declarations
2. [ ] No duplicate function declarations  
3. [ ] _connect_panel_signals() has full implementation
4. [ ] Handler methods are present
5. [ ] Finalization service is integrated
6. [ ] No errors in Godot console

## 🎯 TEST THE FIX

1. Reload the project in Godot
2. Open CampaignCreationUI.tscn
3. Run the scene
4. Complete a full campaign creation flow
5. Verify the campaign saves to user://campaigns/

## ⚠️ COMMON ISSUES

If you see "Identifier not declared" errors:
- Make sure you're editing CampaignCreationUI.gd, not standalone files
- Verify the variable is declared in the class
- Check that you're not in a static function

If you see "Function not found" errors:
- The function should be defined in CampaignCreationUI.gd
- Check for typos in function names
- Ensure proper indentation (functions should be at class level)

## 📞 FINAL CHECK

Run this in Godot's Script Editor to verify:
1. File → Check Errors (Ctrl+Shift+E)
2. Project → Reload Current Project
3. Run the campaign creation scene

Your system should now be 100% functional!