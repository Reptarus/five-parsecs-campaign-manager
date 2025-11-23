@tool
extends FiveParsecsCampaignPanel

const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

signal campaign_creation_requested(campaign_data: Dictionary)

# Autonomous signals for coordinator pattern
signal campaign_finalization_complete(data: Dictionary)

@onready var config_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/ConfigSummary")
@onready var crew_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/CrewSummary")
@onready var create_button: Button = get_node_or_null("Content/ButtonContainer/CreateCampaignButton")

var campaign_data: Dictionary = {}
var campaign_state: Dictionary = {}  # Add missing campaign_state variable
var is_campaign_complete: bool = false
var last_validation_errors: Array[String] = []

# Coordinator reference for consistent access
var coordinator: Node = null

func set_coordinator(coord: Node) -> void:
	"""Set coordinator reference for consistent access"""
	coordinator = coord
	print("FinalPanel: Coordinator set")
	if coordinator and coordinator.has_signal("campaign_state_updated"):
		if not coordinator.campaign_state_updated.is_connected(_on_campaign_state_updated):
			coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
	sync_with_coordinator()

func sync_with_coordinator() -> void:
	"""Sync panel with coordinator state"""
	if not coordinator:
		print("FinalPanel: No coordinator available for sync")
		return
	print("FinalPanel: Syncing with coordinator")
	if coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		campaign_data = state.duplicate()
		_update_display()
		_validate_and_complete()

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update final panel with complete campaign state
	campaign_data = state_data.duplicate()
	_update_display()


func _ready() -> void:
	# Set panel info before base initialization with more informative description  
	set_panel_info("Campaign Review", "Verify all settings. All data from previous steps should appear below. Click 'Create Campaign' to start.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# COMPREHENSIVE DEBUG OUTPUT - Panel Initialization
	call_deferred("_log_panel_initialization_debug")
	
	# Initialize final panel-specific functionality
	_initialize_security_validator()
	if create_button:
		create_button.pressed.connect(_on_create_campaign_pressed)
	
	# CRITICAL FIX: Aggregate campaign data when panel becomes ready
	call_deferred("_aggregate_campaign_data")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup final panel-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	# SecurityValidator is now available as a static class
	pass

func set_campaign_data(data: Dictionary) -> void:
	campaign_data = data
	_update_display()

func _handle_campaign_state_update(state_data: Dictionary) -> void:
	"""Override from base class - auto-aggregate campaign data on state changes"""
	print("FinalPanel: Received state update with keys: %s" % str(state_data.keys()))

	# Auto-aggregate data from coordinator when any panel updates
	_aggregate_campaign_data()

func _aggregate_campaign_data() -> void:
	"""Aggregate campaign data from coordinator - enhanced for proper data access"""
	print("FinalPanel: Aggregating campaign data from coordinator")

	# Use base class method to get coordinator reference
	if not coordinator:
		coordinator = get_coordinator_reference()
	
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var unified_state = coordinator.get_unified_campaign_state()
			print("FinalPanel: Retrieved unified campaign state with keys: %s" % str(unified_state.keys()))
			
			# Update campaign data
			campaign_data = unified_state.duplicate()
			campaign_state = unified_state.duplicate()
			
			# Update display with aggregated data
			_update_display()
			_validate_and_complete()
			
			print("FinalPanel: Campaign data aggregation complete")
			return
	
	# Fallback: Use signal-based data if coordinator not available
	if not campaign_state.is_empty():
		campaign_data = campaign_state.duplicate()
		_update_display()
		_validate_and_complete()
		print("FinalPanel: Used signal-based campaign data")
	else:
		print("FinalPanel: ⚠️ No campaign data available from coordinator or signals")

func _update_display() -> void:
	"""Update comprehensive campaign summary display"""
	_update_config_summary()
	_update_crew_summary()

func _update_config_summary() -> void:
	"""Update configuration summary display"""
	if not config_summary:
		return
	
	var config_text = "[b]Campaign Configuration:[/b]\n"
	var config_data = campaign_data.get("campaign_config", campaign_data.get("config", {}))
	
	config_text += "Name: %s\n" % config_data.get("campaign_name", "Unknown Campaign")
	config_text += "Difficulty: %s\n" % config_data.get("difficulty", "Normal")
	config_text += "Mode: %s\n" % config_data.get("game_mode", "Standard")
	
	# CRITICAL FIX: Add victory condition display with proper handling
	var victory_conditions = config_data.get("victory_conditions", {})
	var selected_conditions = []
	for key in victory_conditions.keys():
		if victory_conditions[key] == true:
			selected_conditions.append(_get_victory_condition_display_name(key))
	
	if selected_conditions.size() > 0:
		config_text += "Victory Conditions: %s\n" % ", ".join(selected_conditions)
	else:
		config_text += "Victory Conditions: None Selected\n"
	
	# Add story track setting
	var story_track = config_data.get("story_track_enabled", false)
	config_text += "Story Track: %s\n" % ("Enabled" if story_track else "Disabled")
	
	# Add validation status
	var completion_status = campaign_data.get("completion_status", {})
	var config_complete = completion_status.get("CONFIG", false)
	config_text += "Status: %s\n" % ("✅ Complete" if config_complete else "❌ Incomplete")
	
	config_summary.text = config_text

func _update_crew_summary() -> void:
	"""Update crew summary display"""
	if not crew_summary:
		return
	
	var crew_text = "[b]Campaign Summary:[/b]\n"
	
	# Crew information
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	crew_text += "Crew Members: %d\n" % crew_members.size()
	
	# Captain information - improved access patterns
	var captain_data = campaign_data.get("captain", {})
	var captain_name = captain_data.get("name", "")
	if captain_name.is_empty():
		# Try alternate captain access patterns
		var captain = captain_data.get("captain")
		if captain:
			if captain is Dictionary:
				captain_name = captain.get("character_name", captain.get("name", "Unknown Captain"))
			elif captain.has("character_name"):
				captain_name = captain.character_name
			else:
				captain_name = str(captain)
	
	if not captain_name.is_empty():
		crew_text += "Captain: %s\n" % captain_name
		var captain_background = captain_data.get("background", "")
		if not captain_background.is_empty():
			crew_text += "Background: %s\n" % captain_background
	else:
		crew_text += "Captain: Not Assigned\n"
	
	# Ship information
	var ship_data = campaign_data.get("ship", {})
	crew_text += "Ship: %s (%s)\n" % [
		ship_data.get("name", "Unnamed"),
		ship_data.get("type", "Unknown Type")
	]
	
	# Equipment information
	var equipment_data = campaign_data.get("equipment", {})
	var equipment_list = equipment_data.get("items", equipment_data.get("equipment", []))
	crew_text += "Equipment Items: %d\n" % equipment_list.size()
	crew_text += "Starting Credits: %d\n" % equipment_data.get("starting_credits", equipment_data.get("credits", 0))
	
	# World information if available
	var world_data = campaign_data.get("world", {})
	if not world_data.is_empty():
		crew_text += "Starting World: %s\n" % world_data.get("name", "Unknown World")
	
	# Overall completion status
	var completion_status = campaign_data.get("completion_status", {})
	var completed_phases = 0
	var total_phases = completion_status.keys().size()
	
	for phase in completion_status.keys():
		if completion_status[phase] == true:
			completed_phases += 1
	
	var completion_pct = 0.0
	if total_phases > 0:
		completion_pct = (float(completed_phases) / float(total_phases)) * 100.0
	
	crew_text += "\n[b]Campaign Readiness: %.1f%% (%d/%d phases)[/b]\n" % [completion_pct, completed_phases, total_phases]
	
	if completion_pct >= 100.0:
		crew_text += "[color=green]✅ Ready to Launch![/color]"
	elif completion_pct >= 80.0:
		crew_text += "[color=yellow]⚠️ Nearly Ready[/color]"
	else:
		crew_text += "[color=red]❌ Incomplete Setup[/color]"
	
	crew_summary.text = crew_text

func _get_victory_condition_display_name(condition_key: String) -> String:
	"""Get display name for victory condition key"""
	match condition_key:
		"standard_victory":
			return "Standard Victory"
		"quest_victory":
			return "Quest Victory"
		"wealth_victory":
			return "Wealth Victory"
		"exploration_victory":
			return "Exploration Victory"
		"survival_victory":
			return "Survival Victory"
		"custom_victory":
			return "Custom Victory"
		"none":
			return "No Victory Condition"
		"play_20_turns":
			return "Play 20 Campaign Turns"
		"play_50_turns":
			return "Play 50 Campaign Turns"
		"play_100_turns":
			return "Play 100 Campaign Turns"
		"complete_3_quests":
			return "Complete 3 Quests"
		"complete_5_quests":
			return "Complete 5 Quests"
		"complete_10_quests":
			return "Complete 10 Quests"
		"win_20_battles":
			return "Win 20 Tabletop Battles"
		"win_50_battles":
			return "Win 50 Tabletop Battles"
		"upgrade_1_character_10":
			return "Upgrade 1 Character 10 Times"
		"upgrade_3_characters_10":
			return "Upgrade 3 Characters 10 Times"
		"upgrade_5_characters_10":
			return "Upgrade 5 Characters 10 Times"
		"challenging_50_turns":
			return "Play 50 Turns in Challenging Mode"
		"hardcore_50_turns":
			return "Play 50 Turns in Hardcore Mode"
		"insanity_50_turns":
			return "Play 50 Turns in Insanity Mode"
		_:
			return condition_key.capitalize().replace("_", " ")

func _on_create_campaign_pressed() -> void:
	"""Handle create campaign button with CampaignFinalizationService"""
	_validate_and_complete()
	
	if is_campaign_complete:
		create_button.disabled = true  # Prevent double-clicks
		print("FinalPanel: Initiating campaign finalization...")
		
		# Load and use CampaignFinalizationService
		const CampaignFinalizationService = preload("res://src/core/campaign/creation/CampaignFinalizationService.gd")
		var service = CampaignFinalizationService.new()
		var state_manager = coordinator.state_manager if coordinator and coordinator.has("state_manager") else null
		
		var result = await service.finalize_campaign(campaign_data, state_manager)
		
		if result.success:
			print("FinalPanel: Campaign finalized successfully")
			campaign_creation_requested.emit(campaign_data)
			campaign_finalization_complete.emit(campaign_data)
			# Note: CampaignCreationUI handles transition via _on_campaign_finalization_complete_from_panel
		else:
			print("FinalPanel: Finalization failed: ", result.error)
			create_button.disabled = false
			validation_failed.emit([result.error])
	else:
		print("FinalPanel: Campaign validation failed: ", last_validation_errors)
		validation_failed.emit(last_validation_errors)

func _validate_and_complete() -> void:
	"""Enhanced validation with coordinator pattern integration"""
	last_validation_errors = _validate_campaign_data()
	
	if not last_validation_errors.is_empty():
		is_campaign_complete = false
		validation_failed.emit(last_validation_errors)
		print("FinalPanel: Campaign validation failed: ", last_validation_errors)
	else:
		is_campaign_complete = _check_completion_requirements()
		
		if is_campaign_complete:
			print("FinalPanel: Campaign finalization validation passed")
		else:
			print("FinalPanel: Campaign completion requirements not met")

func _check_completion_requirements() -> bool:
	"""Check if all requirements for campaign completion are met"""
	# Must have campaign data
	if campaign_data.is_empty():
		return false
	
	# Check completion status from validation summary
	var validation_summary = campaign_data.get("validation_summary", {})
	var completion_pct = validation_summary.get("completion_percentage", 0.0)
	
	# Require at least 80% completion
	if completion_pct < 80.0:
		return false
	
	# Check critical phases are complete
	var completion_status = campaign_data.get("completion_status", {})
	var required_phases = ["CONFIG", "CREW_SETUP", "CAPTAIN_CREATION"]
	
	for phase in required_phases:
		if not completion_status.get(phase, false):
			return false
	
	return true

func _validate_campaign_data() -> Array[String]:
	"""Performs validation on the complete campaign data"""
	var errors: Array[String] = []
	
	# Validate campaign has basic structure
	if campaign_data.is_empty():
		errors.append("Campaign data is empty.")
		return errors
	
	# Validate config phase
	var config_data = campaign_data.get("config", {})
	if config_data.is_empty():
		errors.append("Campaign configuration is missing.")
	elif config_data.get("campaign_name", "").strip_edges().is_empty():
		errors.append("Campaign name is required.")
	
	# Validate crew phase
	var crew_data = campaign_data.get("crew", {})
	var crew_members = crew_data.get("members", [])
	if crew_members.is_empty():
		errors.append("Campaign must have crew members.")
	
	# Validate captain phase
	var captain_data = campaign_data.get("captain", {})
	if not captain_data.get("captain"):
		errors.append("Campaign must have a captain.")
	
	# Check overall completion
	var validation_summary = campaign_data.get("validation_summary", {})
	var completion_pct = validation_summary.get("completion_percentage", 0.0)
	if completion_pct < 80.0:
		errors.append("Campaign setup is only %.1f%% complete. Must be at least 80%% to create." % completion_pct)
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data with standardized metadata"""
	var data = campaign_data.duplicate()
	data["is_complete"] = is_campaign_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["finalization_metadata"] = {
		"finalized_at": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"panel_type": "campaign_finalization"
	}
	return data

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation (BaseCampaignPanel compliance)"""
	return get_data()

func is_valid() -> bool:
	return is_campaign_complete and last_validation_errors.is_empty()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate panel data - simplified validation"""
	var errors = _validate_campaign_data()
	return errors.is_empty()

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("FinalPanel: No data to restore")
		return
	
	print("FinalPanel: Restoring panel data: ", data.keys())
	
	# Restore campaign data
	campaign_data = data.duplicate()
	
	# Update completion status
	if data.has("is_complete"):
		is_campaign_complete = data.is_complete
	
	print("FinalPanel: Restored campaign data with %d sections" % campaign_data.size())
	
	# Update display with restored data
	_update_display()
	
	print("FinalPanel: Panel data restoration complete")

## Debug Helper Methods

func _log_panel_initialization_debug() -> void:
	"""Comprehensive debug output for panel initialization"""
	print("\n==== [PANEL: FinalPanel] INITIALIZATION ====")
	print("  Phase: 7 of 7 (Campaign Review)")
	print("  Panel Title: %s" % panel_title)
	print("  Panel Description: %s" % panel_description)
	
	# Check for coordinator access
	# Fixed: Check owner (CampaignCreationUI) instead of direct parent (content_container)
	var campaign_ui = owner if owner != null else get_parent().get_parent()
	var has_coordinator = campaign_ui != null and campaign_ui.has_method("get_coordinator")
	print("  Has Coordinator Access: %s" % has_coordinator)
	if has_coordinator:
		var coordinator = campaign_ui.get_coordinator() if campaign_ui.has_method("get_coordinator") else null
		print("    Coordinator Available: %s" % (coordinator != null))
		if coordinator and coordinator.has_method("get_unified_campaign_state"):
			var campaign_state = coordinator.get_unified_campaign_state()
			print("    Campaign State Keys: %s" % str(campaign_state.keys()))
		else:
			print("    ⚠️  No unified campaign state available")
	
	# Check autoloaded managers availability
	print("  === AUTOLOAD MANAGER CHECK ===")
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	var save_manager = get_node_or_null("/root/SaveManager")
	
	print("    CampaignManager: %s" % (campaign_manager != null))
	print("    GameStateManager: %s" % (game_state_manager != null))
	print("    SaveManager: %s" % (save_manager != null))
	
	# Check current campaign data
	print("  === FINAL CAMPAIGN DATA ===")
	print("    Campaign Data Keys: %s" % str(campaign_data.keys()))
	print("    Campaign State Keys: %s" % str(campaign_state.keys()))
	print("    Is Campaign Complete: %s" % is_campaign_complete)
	print("    Last Validation Errors: %d" % last_validation_errors.size())
	
	if campaign_data.size() > 0:
		print("  === CAMPAIGN DATA SUMMARY ===")
		if campaign_data.has("config"):
			print("    Config: Campaign '%s'" % campaign_data.config.get("campaign_name", "Unknown"))
		if campaign_data.has("captain"):
			print("    Captain: '%s'" % campaign_data.captain.get("name", "Unknown"))
		if campaign_data.has("crew"):
			print("    Crew: %d members" % campaign_data.crew.get("members", []).size())
		if campaign_data.has("ship"):
			print("    Ship: '%s'" % campaign_data.ship.get("name", "Unknown"))
		
		# Add mathematical validation from test file
		print("  === MATHEMATICAL VALIDATION ===")
		_log_mathematical_validation()
	else:
		print("    ⚠️  NO CAMPAIGN DATA AVAILABLE - Previous panels may not be saving correctly")
	
	# Check UI component availability
	print("  === UI COMPONENTS ===")
	print("    Config Summary: %s" % (config_summary != null))
	print("    Crew Summary: %s" % (crew_summary != null))
	print("    Create Button: %s" % (create_button != null))
	
	print("==== [PANEL: FinalPanel] INIT COMPLETE ====\n")

func _log_mathematical_validation() -> void:
	"""Mathematical validation debug output - adapted from test file"""
	if campaign_data.is_empty():
		print("    ⚠️  No campaign data for mathematical validation")
		return
	
	# Calculate captain total skills
	var captain_data = campaign_data.get("captain", {})
	var captain = captain_data.get("captain", captain_data)
	var captain_total = 0
	if captain is Dictionary:
		captain_total = captain.get("reactions", 0) + captain.get("speed", 0) + captain.get("combat_skill", 0) + captain.get("toughness", 0) + captain.get("savvy", 0) + captain.get("luck", 0)
	
	# Calculate equipment value
	var equipment_data = campaign_data.get("equipment", {})
	var equipment_items = equipment_data.get("items", equipment_data.get("equipment", []))
	var equipment_value = 0
	for item in equipment_items:
		if item is Dictionary and item.has("value"):
			equipment_value += item.value
	
	# Calculate net worth
	var ship_data = campaign_data.get("ship", {})
	var debt = ship_data.get("debt", 0)
	var credits = equipment_data.get("starting_credits", equipment_data.get("credits", 0))
	var net_worth = credits - debt + equipment_value
	
	# Crew size validation
	var crew_data = campaign_data.get("crew", {})
	var crew_size = crew_data.get("members", []).size()
	
	# Output mathematical validation
	print("    Captain Total Skills: %d" % captain_total)
	print("    Equipment Value: %d credits" % equipment_value)
	print("    Net Worth: %d credits (Credits: %d - Debt: %d + Equipment: %d)" % [
		net_worth, credits, debt, equipment_value
	])
	print("    Crew Size: %d/4 minimum (%s)" % [crew_size, "VALID" if crew_size >= 4 else "INVALID"])
	print("    Campaign Ready: %s" % ("YES" if is_campaign_complete else "NO"))
