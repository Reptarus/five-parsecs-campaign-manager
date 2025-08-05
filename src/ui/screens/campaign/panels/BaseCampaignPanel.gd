extends Control
class_name FiveParsecsCampaignPanel

## Minimal Base Campaign Panel - Framework Bible Compliant
## Simple interface for campaign creation panels - NO Enhanced bloat
## Focuses on Five Parsecs functionality, not enterprise complexity

# Essential panel signals - keep it simple
signal panel_data_changed(data: Dictionary)
signal panel_validation_changed(is_valid: bool)
signal panel_completed(data: Dictionary)
signal validation_failed(errors: Array[String])

# Simple panel state
var panel_title: String = ""
var panel_description: String = ""

func _ready() -> void:
	_setup_panel_content()

## Core Interface - Override in derived classes
func validate_panel() -> bool:
	"""Simple validation - return true if panel data is valid"""
	return true

func get_panel_data() -> Dictionary:
	"""Get panel data for campaign creation"""
	return {}

func set_panel_data(data: Dictionary) -> void:
	"""Set panel data from campaign state"""
	pass

## Panel Information
func get_panel_title() -> String:
	return panel_title

func get_panel_description() -> String:
	return panel_description

func set_panel_info(title: String, description: String) -> void:
	panel_title = title
	panel_description = description

## Simple validation and completion
func _validate_and_emit_completion() -> void:
	var is_valid = validate_panel()
	panel_validation_changed.emit(is_valid)
	
	if is_valid:
		var data = get_panel_data()
		panel_completed.emit(data)
	else:
		validation_failed.emit(["Panel validation failed"])

## Override in derived classes
func _setup_panel_content() -> void:
	"""Setup panel-specific content"""
	pass
