class_name FiveParsecsUIControllerBridge
extends Node

## FiveParsecsUIControllerBridge - Bridge class for Five Parsecs campaign panel controllers
## Provides Five Parsecs-specific UI patterns and validation on top of BaseController
## Ensures consistent behavior across all campaign creation panels

# Enhanced signals for Five Parsecs campaign flow
signal panel_data_changed()
signal panel_validation_changed()
signal panel_complete()

# Base class signals
signal data_updated(panel_name: String, data: Dictionary)
signal validation_changed(panel_name: String, is_valid: bool, errors: Array[String])
signal panel_completed(panel_name: String, data: Dictionary)

# Five Parsecs specific state
var five_parsecs_data: Dictionary = {}
var campaign_context: Dictionary = {}

func _init(panel_name: String = "", panel_node: Control = null) -> void:
	_initialize_five_parsecs_extensions()

func _initialize_five_parsecs_extensions() -> void:
	"""Initialize Five Parsecs specific functionality"""
	five_parsecs_data = {}
	campaign_context = {}
	
	# Connect base signals to Five Parsecs specific signals
	if not data_updated.is_connected(_on_data_updated):
		data_updated.connect(_on_data_updated)
	if not validation_changed.is_connected(_on_validation_changed):
		validation_changed.connect(_on_validation_changed)
	if not panel_completed.is_connected(_on_panel_completed):
		panel_completed.connect(_on_panel_completed)

## Five Parsecs specific methods

func set_campaign_context(context: Dictionary) -> void:
	"""Set campaign creation context for validation"""
	campaign_context = context.duplicate()

func get_campaign_context() -> Dictionary:
	"""Get campaign creation context"""
	return campaign_context.duplicate()

func validate_five_parsecs_requirements(data: Dictionary) -> ValidationResult:
	"""Validate Five Parsecs specific requirements"""
	var result = ValidationResult.new()
	
	# Five Parsecs validation can be added here
	# For now, return a basic validation result
	result.valid = true
	return result

## Enhanced validation with Five Parsecs rules

func _validate_character_stats(stats: Dictionary) -> ValidationResult:
	"""Validate character stats according to Five Parsecs rules"""
	var result = ValidationResult.new()
	var errors: Array[String] = []
	
	var required_stats = ["combat", "toughness", "savvy", "tech", "speed", "luck"]
	for stat in required_stats:
		if not stats.has(stat):
			errors.append("Missing required stat: %s" % stat)
			continue
		
		var value = stats[stat]
		if typeof(value) != TYPE_INT:
			errors.append("Stat %s must be an integer" % stat)
			continue
			
		if value < 1 or value > 6:
			errors.append("Stat %s must be between 1 and 6" % stat)
	
	if errors.is_empty():
		result.valid = true
	else:
		result.valid = false
		result.error = errors[0]
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

func _validate_crew_composition(crew_data: Dictionary) -> ValidationResult:
	"""Validate crew composition according to Five Parsecs rules"""
	var result = ValidationResult.new()
	var errors: Array[String] = []
	
	var crew_members = crew_data.get("crew_members", [])
	if crew_members.is_empty():
		errors.append("Crew must have at least one member")
	elif crew_members.size() > 8:
		errors.append("Crew cannot exceed 8 members")
	
	# Check for captain
	var has_captain = false
	for member in crew_members:
		if member is Dictionary and member.get("is_captain", false):
			has_captain = true
			break
	
	if not has_captain:
		errors.append("Crew must have a designated captain")
	
	if errors.is_empty():
		result.valid = true
	else:
		result.valid = false
		result.error = errors[0]
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

## Safe input validation for Five Parsecs data

func validate_character_name(name: String) -> ValidationResult:
	"""Validate character name according to Five Parsecs standards"""
	var result = ValidationResult.new()
	
	if name.is_empty():
		result.valid = false
		result.error = "Character name is required"
		return result
	
	if name.length() < 2:
		result.valid = false
		result.error = "Character name must be at least 2 characters"
		return result
	
	if name.length() > 30:
		result.valid = false
		result.error = "Character name cannot exceed 30 characters"
		return result
	
	# Basic sanitization
	var sanitized = name.strip_edges()
	if sanitized != name:
		result.add_warning("Character name was trimmed")
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

func validate_campaign_name(name: String) -> ValidationResult:
	"""Validate campaign name according to Five Parsecs standards"""
	var result = ValidationResult.new()
	
	if name.is_empty():
		result.valid = false
		result.error = "Campaign name is required"
		return result
	
	if name.length() < 3:
		result.valid = false
		result.error = "Campaign name must be at least 3 characters"
		return result
	
	if name.length() > 50:
		result.valid = false
		result.error = "Campaign name cannot exceed 50 characters"
		return result
	
	var sanitized = name.strip_edges()
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Signal handlers for Five Parsecs specific emissions

func _on_data_updated(panel_name: String, data: Dictionary) -> void:
	"""Handle base data update and emit Five Parsecs specific signal"""
	five_parsecs_data = data.duplicate()
	panel_data_changed.emit()

func _on_validation_changed(panel_name: String, is_valid: bool, errors: Array[String]) -> void:
	"""Handle base validation change and emit Five Parsecs specific signal"""
	panel_validation_changed.emit()

func _on_panel_completed(panel_name: String, data: Dictionary) -> void:
	"""Handle base panel completion and emit Five Parsecs specific signal"""
	panel_complete.emit()

## Debug and monitoring

func get_five_parsecs_debug_info() -> Dictionary:
	"""Get debug information specific to Five Parsecs implementation"""
	var base_info = {
		"controller_type": "FiveParsecsUIControllerBridge",
		"five_parsecs_data_keys": five_parsecs_data.keys(),
		"campaign_context_keys": campaign_context.keys(),
		"five_parsecs_signals_connected": [
			data_updated.is_connected(_on_data_updated),
			validation_changed.is_connected(_on_validation_changed),
			panel_completed.is_connected(_on_panel_completed)
		]
	}
	return base_info