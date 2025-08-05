@tool
extends FiveParsecsCampaignPanel

const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
# SecurityValidator is inherited from FiveParsecsCampaignPanel

signal campaign_creation_requested(campaign_data: Dictionary)

# Autonomous signals for coordinator pattern
signal campaign_finalization_complete(data: Dictionary)

@onready var config_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/ConfigSummary")
@onready var crew_summary: RichTextLabel = get_node_or_null("Content/ScrollContainer/ReviewContent/CrewSummary")
@onready var create_button: Button = get_node_or_null("Content/ButtonContainer/CreateCampaignButton")

var campaign_data: Dictionary = {}
var security_validator: SecurityValidator
var is_campaign_complete: bool = false
var last_validation_errors: Array[String] = []

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update final panel with complete campaign state
	campaign_data = state_data.duplicate()
	_update_display()


func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Final Review", "Review all campaign settings and create your Five Parsecs campaign.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# Initialize final panel-specific functionality
	_initialize_security_validator()
	if create_button:
		create_button.pressed.connect(_on_create_campaign_pressed)

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup final panel-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	security_validator = _validate_simple_input()

func set_campaign_data(data: Dictionary) -> void:
	campaign_data = data
	_update_display()

func _aggregate_campaign_data() -> void:
	"""Aggregate campaign data from campaign state via signal-based architecture"""
	# In signal-based architecture, data is received through _on_campaign_state_updated
	# This function is now just a placeholder for compatibility
	print("FinalPanel: Campaign data will be received via signal-based updates")
	
	# If we have campaign state data, use it
	if not campaign_state.is_empty():
		campaign_data = campaign_state.duplicate()
		_update_display()
		_validate_and_complete()
	
	print("FinalPanel: Campaign data aggregation setup complete")

func _update_display() -> void:
	"""Update comprehensive campaign summary display"""
	_update_config_summary()
	_update_crew_summary()

func _update_config_summary() -> void:
	"""Update configuration summary display"""
	if not config_summary:
		return
	
	var config_text = "[b]Campaign Configuration:[/b]\n"
	var config_data = campaign_data.get("config", {})
	
	config_text += "Name: %s\n" % config_data.get("campaign_name", "Unknown Campaign")
	config_text += "Difficulty: %s\n" % config_data.get("difficulty", "Normal")
	config_text += "Mode: %s\n" % config_data.get("game_mode", "Standard")
	
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
	
	# Captain information
	var captain_data = campaign_data.get("captain", {})
	var captain = captain_data.get("captain")
	if captain:
		crew_text += "Captain: %s\n" % captain.character_name
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
	var equipment_list = equipment_data.get("equipment", [])
	crew_text += "Equipment Items: %d\n" % equipment_list.size()
	crew_text += "Starting Credits: %d\n" % equipment_data.get("starting_credits", 0)
	
	# Overall completion status
	var validation_summary = campaign_data.get("validation_summary", {})
	var completion_pct = validation_summary.get("completion_percentage", 0.0)
	crew_text += "\n[b]Campaign Readiness: %.1f%%[/b]\n" % completion_pct
	
	if completion_pct >= 100.0:
		crew_text += "[color=green]✅ Ready to Launch![/color]"
	elif completion_pct >= 80.0:
		crew_text += "[color=yellow]⚠️ Nearly Ready[/color]"
	else:
		crew_text += "[color=red]❌ Incomplete Setup[/color]"
	
	crew_summary.text = crew_text

func _on_create_campaign_pressed() -> void:
	"""Handle create campaign button with validation"""
	_validate_and_complete()
	
	if is_campaign_complete:
		print("FinalPanel: Campaign validation passed, requesting creation...")
		campaign_creation_requested.emit(campaign_data)
		campaign_finalization_complete.emit(campaign_data)
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

func is_valid() -> bool:
	return is_campaign_complete and last_validation_errors.is_empty()

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> ValidationResult:
	"""Validate panel data and return ValidationResult"""
	var result = ValidationResult.new()
	var errors = _validate_campaign_data()
	
	if errors.is_empty():
		result.valid = true
		result.sanitized_value = get_data()
	else:
		result.valid = false
		result.error = errors[0] if errors.size() > 0 else "Final campaign validation failed"
		# Add additional errors as warnings since ValidationResult only has one error field
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

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
