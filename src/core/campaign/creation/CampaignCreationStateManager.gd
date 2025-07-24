class_name CampaignCreationStateManager
extends RefCounted

## Enterprise-grade Campaign Creation State Manager
## Provides centralized state management and validation for campaign creation workflow

# State validation framework
enum ValidationResult {VALID, INCOMPLETE, INVALID}

# Campaign creation phases
enum Phase {
	CONFIG,
	CREW_SETUP,
	CAPTAIN_CREATION,
	SHIP_ASSIGNMENT,
	EQUIPMENT_GENERATION,
	FINAL_REVIEW
}

# Centralized state container
var campaign_data: Dictionary = {
	"config": {},
	"crew": {},
	"captain": {},
	"ship": {},
	"equipment": {},
	"metadata": {
		"created_at": "",
		"version": "1.0",
		"is_complete": false
	}
}

var current_phase: Phase = Phase.CONFIG
var validation_errors: Array[String] = []

signal state_updated(phase: Phase, data: Dictionary)
signal validation_changed(is_valid: bool, errors: Array[String])
signal phase_completed(phase: Phase)
signal creation_completed(campaign_data: Dictionary)

func _init() -> void:
	_initialize_state()

func _initialize_state() -> void:
	"""Initialize campaign data with default values"""
	campaign_data.metadata.created_at = Time.get_datetime_string_from_system()
	_validate_current_phase()

# Phase Management
func advance_to_next_phase() -> bool:
	"""Advance to next phase if current phase is valid"""
	# Special case: Allow advancing from initial CONFIG phase even if empty
	# This enables users to navigate to other panels to fill in data
	if current_phase == Phase.CONFIG and campaign_data.config.is_empty():
		print("CampaignCreationStateManager: Allowing advance from empty CONFIG phase for initial setup")
		var next_phase = current_phase + 1
		if next_phase < Phase.FINAL_REVIEW + 1:
			current_phase = next_phase
			phase_completed.emit(current_phase - 1)
			_validate_current_phase()
			return true
		return false
	
	if not _is_phase_valid(current_phase):
		push_warning("Cannot advance: Current phase invalid")
		return false

	var next_phase = current_phase + 1
	if next_phase < Phase.FINAL_REVIEW + 1:
		current_phase = next_phase
		phase_completed.emit(current_phase - 1)
		_validate_current_phase()
		return true

	return false

func set_phase_data(phase: Phase, data: Dictionary) -> void:
	"""Update data for specific phase with validation"""
	match phase:
		Phase.CONFIG:
			campaign_data.config = data.duplicate()
		Phase.CREW_SETUP:
			campaign_data.crew = data.duplicate()
		Phase.CAPTAIN_CREATION:
			campaign_data.captain = data.duplicate()
		Phase.SHIP_ASSIGNMENT:
			campaign_data.ship = data.duplicate()
		Phase.EQUIPMENT_GENERATION:
			campaign_data.equipment = data.duplicate()

	_validate_current_phase()
	state_updated.emit(phase, data)

func get_phase_data(phase: Phase) -> Dictionary:
	"""Retrieve data for specific phase"""
	match phase:
		Phase.CONFIG:
			return campaign_data.config
		Phase.CREW_SETUP:
			return campaign_data.crew
		Phase.CAPTAIN_CREATION:
			return campaign_data.captain
		Phase.SHIP_ASSIGNMENT:
			return campaign_data.ship
		Phase.EQUIPMENT_GENERATION:
			return campaign_data.equipment
		_:
			return {}

# Validation Framework
func _validate_current_phase() -> void:
	"""Validate current phase and update validation state"""
	validation_errors.clear()
	var is_valid = _is_phase_valid(current_phase)
	validation_changed.emit(is_valid, validation_errors)

func _is_phase_valid(phase: Phase) -> bool:
	"""Validate specific phase data"""
	match phase:
		Phase.CONFIG:
			return _validate_config_phase()
		Phase.CREW_SETUP:
			return _validate_crew_phase()
		Phase.CAPTAIN_CREATION:
			return _validate_captain_phase()
		Phase.SHIP_ASSIGNMENT:
			return _validate_ship_phase()
		Phase.EQUIPMENT_GENERATION:
			return _validate_equipment_phase()
		Phase.FINAL_REVIEW:
			return _validate_final_phase()
		_:
			return false

func _validate_config_phase() -> bool:
	"""Validate campaign configuration"""
	var config = campaign_data.config

	if not config.has("campaign_name") or config.campaign_name.is_empty():
		validation_errors.append("Campaign name is required")
		return false

	if not config.has("difficulty_level"):
		validation_errors.append("Difficulty level must be selected")
		return false

	return true

func _validate_crew_phase() -> bool:
	"""Enhanced crew setup validation with character completeness checking"""
	var crew = campaign_data.crew

	if not crew.has("members") or crew.members.is_empty():
		validation_errors.append("At least one crew member is required")
		return false

	if crew.get("size", 0) < 1:
		validation_errors.append("Invalid crew size")
		return false

	# Enhanced validation for character completeness
	var required_size = crew.get("size", 4)
	if crew.members.size() < required_size:
		validation_errors.append("Crew requires %d members, currently has %d" % [required_size, crew.members.size()])
		return false

	# Check for captain assignment
	if not crew.get("has_captain", false):
		validation_errors.append("Crew must have an assigned captain")
		return false

	# Check character customization completeness
	var incomplete_characters = []
	for member in crew.members:
		if member.has_method("get_customization_completeness"):
			var completeness = member.get_customization_completeness()
			if completeness < 0.8: # Require 80% completion
				# Use safe property access for Resource objects
				var name = ""
				if member.has_method("get"):
					name = member.get("character_name")
				elif member.has_property("character_name"):
					name = member.character_name
				else:
					name = "Unnamed Character"
				incomplete_characters.append(name)
	
	if incomplete_characters.size() > 0:
		validation_errors.append("Characters need more customization: " + ", ".join(incomplete_characters))
		return false

	# Check crew composition quality
	var completion_level = crew.get("completion_level", 0.0)
	if completion_level < 0.75: # Require 75% overall completion
		validation_errors.append("Crew setup needs more completion (currently %.0f%%)" % (completion_level * 100))
		return false

	return true

func _validate_captain_phase() -> bool:
	"""Validate captain creation"""
	var captain = campaign_data.captain

	if not captain.has("character_data"):
		validation_errors.append("Captain character must be created")
		return false

	return true

func _validate_ship_phase() -> bool:
	"""Validate ship assignment"""
	var ship = campaign_data.ship

	if not ship.has("name") or ship.name.is_empty():
		validation_errors.append("Ship name is required")
		return false

	if not ship.has("type") or ship.type.is_empty():
		validation_errors.append("Ship type must be selected")
		return false

	if not ship.get("is_configured", false):
		validation_errors.append("Ship configuration incomplete")
		return false

	return true

func _validate_equipment_phase() -> bool:
	"""Validate equipment generation"""
	var equipment = campaign_data.equipment

	if not equipment.has("equipment") or equipment.equipment.is_empty():
		validation_errors.append("Starting equipment must be generated")
		return false

	if not equipment.get("is_complete", false):
		validation_errors.append("Equipment setup incomplete")
		return false

	return true

func _validate_final_phase() -> bool:
	"""Validate complete campaign data"""
	var all_phases_valid: bool = true

	for phase: int in range(Phase.FINAL_REVIEW):
		if not _is_phase_valid(phase):
			all_phases_valid = false

	if all_phases_valid:
		campaign_data.metadata.is_complete = true

	return all_phases_valid

# Campaign Creation
func complete_campaign_creation() -> Dictionary:
	"""Finalize campaign creation and return complete data with enhanced serialization"""
	if not _validate_final_phase():
		push_error("Cannot complete campaign: Validation failed")
		return {}

	# Generate final campaign data with metadata
	var final_data = campaign_data.duplicate()
	final_data.metadata.completed_at = Time.get_datetime_string_from_system()
	final_data.metadata.total_crew_size = final_data.crew.get("size", 0)
	final_data.metadata.starting_credits = final_data.equipment.get("starting_credits", 1000)
	
	# Enhanced character data serialization
	final_data.crew = _serialize_crew_data(final_data.crew)
	
	# Add campaign statistics
	final_data.metadata.crew_statistics = _calculate_crew_statistics(final_data.crew)

	creation_completed.emit(final_data)
	return final_data

## Enhanced Character Data Management

func _serialize_crew_data(crew_data: Dictionary) -> Dictionary:
	"""Serialize crew data with enhanced character information"""
	var serialized_crew = crew_data.duplicate()
	
	if crew_data.has("members"):
		var serialized_members = []
		for member in crew_data.members:
			if member.has_method("serialize_enhanced"):
				serialized_members.append(member.serialize_enhanced())
			elif member.has_method("serialize"):
				serialized_members.append(member.serialize())
			else:
				# Fallback serialization
				serialized_members.append(_fallback_character_serialization(member))
		
		serialized_crew.members = serialized_members
	
	return serialized_crew

func _fallback_character_serialization(character) -> Dictionary:
	"""Fallback character serialization for compatibility"""
	return {
		"character_name": character.get("character_name", ""),
		"background": character.get("background", 0),
		"motivation": character.get("motivation", 0),
		"combat": character.get("combat", 0),
		"reaction": character.get("reaction", 0),
		"toughness": character.get("toughness", 3),
		"savvy": character.get("savvy", 0),
		"speed": character.get("speed", 4),
		"max_health": character.get("max_health", 5),
		"health": character.get("health", 5),
		"is_captain": character.get("is_captain", false),
		"patrons": character.get("patrons", []),
		"rivals": character.get("rivals", []),
		"personal_equipment": character.get("personal_equipment", {}),
		"traits": character.get("traits", []),
		"credits_earned": character.get("credits_earned", 0)
	}

func _calculate_crew_statistics(crew_data: Dictionary) -> Dictionary:
	"""Calculate comprehensive crew statistics for campaign metadata"""
	var stats = {
		"total_members": 0,
		"captain_name": "",
		"average_completeness": 0.0,
		"total_patrons": 0,
		"total_rivals": 0,
		"total_traits": 0,
		"total_equipment_value": 0,
		"total_starting_credits": 0,
		"background_distribution": {},
		"motivation_distribution": {},
		"class_distribution": {}
	}
	
	if not crew_data.has("members"):
		return stats
	
	var total_completeness = 0.0
	stats.total_members = crew_data.members.size()
	
	for member in crew_data.members:
		# Captain identification
		if member.get("is_captain", false):
			stats.captain_name = member.get("character_name", "Unknown")
		
		# Completeness tracking
		if member.has_method("get_customization_completeness"):
			total_completeness += member.get_customization_completeness()
		
		# Relationship counting
		stats.total_patrons += member.get("patrons", []).size()
		stats.total_rivals += member.get("rivals", []).size()
		stats.total_traits += member.get("traits", []).size()
		
		# Wealth tracking
		stats.total_starting_credits += member.get("credits_earned", 0)
		
		var equipment = member.get("personal_equipment", {})
		stats.total_equipment_value += equipment.get("value", 0)
		
		# Distribution tracking
		var background = member.get("background", 0)
		var motivation = member.get("motivation", 0)
		var character_class = member.get("character_class", 0)
		
		_increment_distribution(stats.background_distribution, str(background))
		_increment_distribution(stats.motivation_distribution, str(motivation))
		_increment_distribution(stats.class_distribution, str(character_class))
	
	# Calculate averages
	if stats.total_members > 0:
		stats.average_completeness = total_completeness / stats.total_members
	
	return stats

func _increment_distribution(distribution: Dictionary, key: String) -> void:
	"""Helper to increment distribution counters"""
	if distribution.has(key):
		distribution[key] += 1
	else:
		distribution[key] = 1

func reset_creation() -> void:
	"""Reset campaign creation state"""
	campaign_data = {
		"config": {},
		"crew": {},
		"captain": {},
		"ship": {},
		"equipment": {},
		"metadata": {
			"created_at": Time.get_datetime_string_from_system(),
			"version": "1.0",
			"is_complete": false
		}
	}
	current_phase = Phase.CONFIG
	validation_errors.clear()
	_validate_current_phase()

# Utility Methods
func get_completion_percentage() -> float:
	"""Calculate overall completion percentage"""
	var completed_phases: int = 0
	var total_phases = Phase.FINAL_REVIEW # Exclude FINAL_REVIEW itself

	for phase: int in range(total_phases):
		if _is_phase_valid(phase):
			completed_phases += 1

	return float(completed_phases) / float(total_phases) * 100.0

func get_validation_summary() -> Dictionary:
	"""Get comprehensive validation summary"""
	var summary = {
		"current_phase": current_phase,
		"is_current_phase_valid": _is_phase_valid(current_phase),
		"validation_errors": validation_errors.duplicate(),
		"completion_percentage": get_completion_percentage(),
		"can_advance": _is_phase_valid(current_phase),
		"can_complete": _validate_final_phase()
	}

	return summary

func export_for_save() -> Dictionary:
	"""Export campaign data in format suitable for saving"""
	return campaign_data.duplicate()

func import_from_save(save_data: Dictionary) -> bool:
	"""Import campaign data from save file"""
	if not save_data.has("metadata"):
		push_error("Invalid save data: Missing metadata")
		return false

	campaign_data = save_data.duplicate()
	current_phase = Phase.FINAL_REVIEW # Assume complete if loading
	_validate_current_phase()
	return true

# Public API methods for external access
func get_current_phase() -> Phase:
	"""Get the current campaign creation phase"""
	return current_phase

func is_phase_valid(phase: Phase) -> bool:
	"""Public wrapper for phase validation"""
	return _is_phase_valid(phase)

## UI Integration Methods - Bridge between UI expectations and internal implementation
func validate_current_step() -> bool:
	"""Validate current step - public wrapper for UI integration"""
	return _is_phase_valid(current_phase)

func can_proceed_to_next_step() -> bool:
	"""Check if current step allows proceeding to next step - UI integration method"""
	return _is_phase_valid(current_phase)

func create_campaign() -> Dictionary:
	"""Create final campaign - public wrapper for UI integration"""
	return complete_campaign_creation()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
     