class_name CampaignCreationStateManager
extends RefCounted

## Enterprise-grade Campaign Creation State Manager
## Provides centralized state management and validation for campaign creation workflow

# GDScript 2.0: Typed constants
const SecurityValidator := preload("res://src/core/validation/SecurityValidator.gd")
const FiveParsecsValidationResult := preload("res://src/core/validation/ValidationResult.gd")

# GDScript 2.0: Remove VICTORY_CONDITIONS from enum (merge into CONFIG)
# Core Rules SOP: Equipment before Ship (p.30)
enum Phase {
	CONFIG,                    # Now includes victory conditions
	CAPTAIN_CREATION,
	CREW_SETUP,
	EQUIPMENT_GENERATION,      # Core Rules: Equipment comes before Ship
	SHIP_ASSIGNMENT,           # Core Rules: Ship is final step (determines debt)
	WORLD_GENERATION,
	FINAL_REVIEW
}

# GDScript 2.0: Typed dictionary with victory conditions merged into config
var campaign_data: Dictionary = {
	"config": {
		"campaign_name": "",
		"campaign_type": "standard",
		"victory_conditions": {},  # Moved here from separate section
		"story_track": "",
		"tutorial_mode": "",
		"is_complete": false
	},
	# REMOVED: separate "victory_conditions": {} entry
	"captain": {},
	"crew": {},
	"ship": {},
	"equipment": {},
	"world": {},
	"metadata": {
		"created_at": "",
		"version": "1.0",
		"is_complete": false
	}
}

var current_phase: Phase = Phase.CONFIG
var validation_errors: Array[String] = []

# PHASE 1A: Concurrency protection for production-grade state management
var _operation_lock: Mutex = Mutex.new()
var _is_processing_confirmation: bool = false

# PHASE 1A: Transaction system integration
const FPCMCampaignCreationTransaction = preload("res://src/core/campaign/creation/CampaignCreationTransaction.gd")
var _active_transactions: Dictionary = {}

signal state_updated(phase: Phase, data: Dictionary)
signal validation_changed(is_valid: bool, errors: Array[String])
signal phase_completed(phase: Phase)
signal creation_completed(campaign_data: Dictionary)

func _init() -> void:
	_initialize_state()

func initialize() -> void:
	## Public method to initialize the state manager
	_initialize_state()

func _initialize_state() -> void:
	## Initialize campaign data with default values
	campaign_data["metadata"]["created_at"] = Time.get_datetime_string_from_system()
	_validate_current_phase()

# Phase Management
func set_phase(new_phase: Phase) -> bool:
	## Set the current phase directly
	if new_phase >= Phase.CONFIG and new_phase <= Phase.FINAL_REVIEW:
		current_phase = new_phase
		_validate_current_phase()
		pass # Phase set
		return true
	else:
		push_warning("CampaignCreationStateManager: Invalid phase: %s" % str(new_phase))
		return false

func advance_to_next_phase() -> bool:
	## Advance to next phase with enhanced progression logic - allows warnings
	# CRITICAL FIX: Require proper validation before advancing
	pass # Attempting phase advance
	
	# Validate current phase before allowing advancement
	var validation_result: Dictionary = _validate_phase_with_warnings(current_phase)
	
	if validation_result.blocks_progression:
		push_warning("Cannot advance: Current phase has blocking errors: %s" % str(validation_result.blocking_errors))
		return false
	
	# Allow progression if only warnings exist
	if validation_result.has_warnings:
		push_warning("CampaignCreationStateManager: Advancing with warnings: %s" % str(validation_result.warnings))

	var next_phase_int: int = int(current_phase) + 1
	if next_phase_int < int(Phase.FINAL_REVIEW) + 1:
		current_phase = next_phase_int as Phase
		phase_completed.emit((next_phase_int - 1) as Phase)
		_validate_current_phase()
		return true

	return false

func go_to_previous_phase() -> bool:
	## Go back to the previous phase if possible
	pass # Attempting to go to previous phase
	
	if current_phase == Phase.CONFIG:
		return false # Cannot go back from first phase
	
	var previous_phase_int: int = int(current_phase) - 1
	if previous_phase_int < 0:
		return false
	
	var previous_phase: Phase = Phase.values()[previous_phase_int] as Phase
	current_phase = previous_phase
	
	# Emit signals for UI updates
	state_updated.emit(current_phase, get_phase_data(current_phase))
	_validate_current_phase()
	
	pass # Moved back to previous phase
	return true

func can_go_to_previous_phase() -> bool:
	## Check if we can go to the previous phase
	return current_phase > Phase.CONFIG

func get_navigation_debug_info() -> Dictionary:
	## Get debug information about navigation state
	return {
		"current_phase": current_phase,
		"current_phase_name": get_phase_name(current_phase),
		"can_advance": _is_phase_valid(current_phase),
		"can_go_back": can_go_to_previous_phase(),
		"validation_errors": validation_errors.duplicate()
	}

func set_phase_data(phase: Phase, data: Dictionary) -> void:
	## Update data for specific phase with validation
	match phase:
		Phase.CONFIG:
			campaign_data["config"] = data.duplicate()
		Phase.CREW_SETUP:
			campaign_data["crew"] = data.duplicate()
		Phase.CAPTAIN_CREATION:
			campaign_data["captain"] = data.duplicate()
		Phase.SHIP_ASSIGNMENT:
			campaign_data["ship"] = data.duplicate()
		Phase.EQUIPMENT_GENERATION:
			campaign_data["equipment"] = data.duplicate()
		Phase.WORLD_GENERATION:
			campaign_data["world"] = data.duplicate()

	_validate_current_phase()
	state_updated.emit(phase, data)

func get_phase_data(phase: Phase) -> Dictionary:
	## Retrieve data for specific phase
	match phase:
		Phase.CONFIG:
			return campaign_data["config"]
		Phase.CREW_SETUP:
			return campaign_data["crew"]
		Phase.CAPTAIN_CREATION:
			return campaign_data["captain"]
		Phase.SHIP_ASSIGNMENT:
			return campaign_data["ship"]
		Phase.EQUIPMENT_GENERATION:
			return campaign_data["equipment"]
		Phase.WORLD_GENERATION:
			return campaign_data["world"]
		_:
			return {}

# Validation Framework
func _validate_current_phase() -> void:
	## Validate current phase and update validation state
	validation_errors.clear()
	var is_valid: bool = _is_phase_valid(current_phase)
	validation_changed.emit(is_valid, validation_errors)

func _is_phase_valid(phase: Phase) -> bool:
	## Validate specific phase data
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
		Phase.WORLD_GENERATION:
			return _validate_world_phase()
		Phase.FINAL_REVIEW:
			return _validate_final_phase()
		_:
			return false

func _validate_config_phase() -> bool:
	## GDScript 2.0: Validate campaign configuration including victory conditions
	var config: Dictionary = campaign_data["config"] as Dictionary

	if not config.has("campaign_name") or str(config.get("campaign_name", "")).is_empty():
		validation_errors.append("Campaign name is required")
		return false

	# GDScript 2.0: Victory conditions validation (NEW)
	# Victory conditions are stored as nested dictionaries (not bools)
	# Presence of a key with valid data means that condition is selected
	var has_victory := false
	if config.has("victory_conditions"):
		var conditions: Dictionary = config["victory_conditions"]
		# If any condition exists with valid data, victory is set
		for key: String in conditions:
			var condition_data = conditions.get(key, {})
			if condition_data is Dictionary and not condition_data.is_empty():
				has_victory = true
				break

	if not has_victory:
		validation_errors.append("At least one victory condition must be selected")
		return false

	return true

func _validate_crew_phase() -> bool:
	## Enhanced crew setup validation with character completeness checking
	var crew: Dictionary = campaign_data["crew"] as Dictionary

	# Allow empty crew data initially - panels will populate it
	if crew.is_empty():
		return true

	if not crew.has("members"):
		# If no members key exists, assume default crew is being used
		return true

	# If members array exists but is empty, that's an error
	var members_array: Array = crew["members"] as Array
	if members_array.is_empty():
		validation_errors.append("At least one crew member is required")
		return false

	if int(crew.get("size", 0)) < 1:
		validation_errors.append("Invalid crew size")
		return false

	# Enhanced validation for character completeness
	var required_size: int = int(crew.get("size", 4))
	if members_array.size() < required_size:
		validation_errors.append("Crew requires %d members, currently has %d" % [required_size, members_array.size()])
		return false

	# SPRINT 26.21 FIX: Check for captain assignment - accept either has_captain flag OR captain object
	var has_captain: bool = bool(crew.get("has_captain", false))
	if not has_captain:
		# Also check if captain object exists
		var captain = crew.get("captain", null)
		if captain != null:
			has_captain = true
		else:
			# Check if any member is marked as captain
			for member in members_array:
				if member is Dictionary and member.get("is_captain", false):
					has_captain = true
					break
				elif member is Object and "is_captain" in member and member.is_captain:
					has_captain = true
					break

	if not has_captain:
		validation_errors.append("Crew must have an assigned captain")
		return false

	# SPRINT 26.21 FIX: Relaxed validation - customization completeness is optional
	# Character customization is handled at generation time, not required for validation
	# The crew is valid if we have the right number of members with a captain

	# SPRINT 26.21 FIX: Removed completion_level requirement
	# If we have enough members and a captain, crew setup is complete
	# The completion_level check was designed for manual character editing which isn't required

	pass # Crew validation passed
	return true

func _validate_captain_phase() -> bool:
	## Enhanced captain phase validation with flexible requirements
	var captain: Dictionary = campaign_data["captain"] as Dictionary

	# Allow initial empty state for captain creation UI
	if captain.is_empty():
		return true

	# Basic captain validation
	if not captain.has("character_name") or str(captain.get("character_name", "")).is_empty():
		validation_errors.append("Captain must have a name")
		return false

	if not captain.has("combat") or int(captain.get("combat", 0)) < 1:
		validation_errors.append("Captain needs valid combat attribute")
		return false

	if not captain.has("toughness") or int(captain.get("toughness", 0)) < 1:
		validation_errors.append("Captain needs valid toughness attribute")
		return false

	# Optional: Check for captain customization completeness
	var completeness: float = float(captain.get("customization_completeness", 1.0))
	if completeness < 0.6: # Require 60% completion minimum
		validation_errors.append("Captain needs more customization")
		return false

	pass # Captain validation passed
	return true

func _validate_ship_phase() -> bool:
	## Validate ship assignment
	var ship: Dictionary = campaign_data["ship"] as Dictionary

	if not ship.has("name") or str(ship.get("name", "")).is_empty():
		validation_errors.append("Ship name is required")
		return false

	if not ship.has("type") or str(ship.get("type", "")).is_empty():
		validation_errors.append("Ship type must be selected")
		return false

	# SPRINT 26.21 FIX: Check both is_configured and is_complete (they are semantically equivalent)
	if not bool(ship.get("is_configured", ship.get("is_complete", false))):
		validation_errors.append("Ship configuration incomplete")
		return false

	return true

func _validate_equipment_phase() -> bool:
	## Validate equipment generation with backend integration check
	var equipment: Dictionary = campaign_data["equipment"] as Dictionary

	# FIX: Use Dictionary access (equipment is stored as Dictionary, not Resource)
	if not equipment.has("equipment") or (equipment["equipment"] as Array).is_empty():
		validation_errors.append("Starting equipment must be generated")
		return false

	if not bool(equipment.get("is_complete", false)):
		validation_errors.append("Equipment setup incomplete")
		return false

	# SPRINT ENHANCEMENT: Validate backend integration for equipment generation
	# Note: Backend generation is optional - warnings don't block completion
	# if not equipment.get("backend_generated", false):
	#     print("Warning: Equipment not generated via backend system (mock data in use)")

	return true

func _validate_world_phase() -> bool:
	## Validate world generation - very permissive as world can use defaults
	var _world: Dictionary = campaign_data["world"] as Dictionary
	
	# World generation is optional - empty world data will use defaults
	# This is intentionally permissive to allow campaign creation to complete
	# even if world data hasn't been fully populated
	return true

func _validate_final_phase() -> bool:
	## Validate complete campaign data
	# Clear any previous validation errors before final validation
	validation_errors.clear()
	
	var all_phases_valid: bool = true

	for phase_idx: int in range(int(Phase.FINAL_REVIEW)):
		var phase_valid: bool = _is_phase_valid(phase_idx as Phase)
		if not phase_valid:
			all_phases_valid = false

	if all_phases_valid:
		campaign_data["metadata"]["is_complete"] = true
	else:
		push_warning("CampaignCreationStateManager: Final validation failed. Total errors: %d" % validation_errors.size())

	return all_phases_valid

# Campaign Creation
# PHASE 1 DAY 1: Enhanced validation system with warnings support

func _validate_phase_with_warnings(phase: Phase) -> Dictionary:
	## Enhanced validation that separates blocking errors from warnings
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": [],
		"phase": phase
	}
	
	match phase:
		Phase.CONFIG:
			return _validate_config_with_warnings()
		Phase.CREW_SETUP:
			return _validate_crew_with_warnings()
		Phase.CAPTAIN_CREATION:
			return _validate_captain_with_warnings()
		Phase.SHIP_ASSIGNMENT:
			return _validate_ship_with_warnings()
		Phase.EQUIPMENT_GENERATION:
			return _validate_equipment_with_warnings()
		Phase.WORLD_GENERATION:
			return _validate_world_with_warnings()
		Phase.FINAL_REVIEW:
			return _validate_final_with_warnings()
		_:
			result.blocks_progression = true
			(result.blocking_errors as Array).append("Unknown phase: " + str(phase))
			return result

func _validate_config_with_warnings() -> Dictionary:
	## Enhanced config validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	var config: Dictionary = campaign_data["config"] as Dictionary

	# Allow progression even with empty config initially
	if config.is_empty():
		(result.warnings as Array).append("Configuration not set - will use defaults")
		result.has_warnings = true
		return result

	# Warnings that don't block progression
	if not config.has("campaign_name") or str(config.get("campaign_name", "")).is_empty():
		(result.warnings as Array).append("Campaign name not set - will use default")
		result.has_warnings = true

	if not config.has("difficulty_level") or int(config.get("difficulty_level", 0)) == 0:
		(result.warnings as Array).append("Difficulty level not set - will use default")
		result.has_warnings = true

	if not config.has("crew_size") or int(config.get("crew_size", 0)) == 0:
		(result.warnings as Array).append("Crew size not set - will use default of 4")
		result.has_warnings = true

	return result

func _validate_crew_with_warnings() -> Dictionary:
	## Enhanced crew validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	var crew: Dictionary = campaign_data["crew"] as Dictionary

	# Allow empty crew data initially
	if crew.is_empty():
		(result.warnings as Array).append("Crew data empty - will be populated during setup")
		result.has_warnings = true
		return result

	# Warnings for incomplete setup
	if not crew.has("members") or (crew["members"] as Array).is_empty():
		(result.warnings as Array).append("No crew members defined - using default setup")
		result.has_warnings = true

	if not bool(crew.get("has_captain", false)):
		(result.warnings as Array).append("No captain assigned - will be set during captain creation")
		result.has_warnings = true

	# Check backend integration (warning only)
	if not bool(crew.get("backend_generated", false)):
		(result.warnings as Array).append("Crew not generated via backend system (using fallback)")
		result.has_warnings = true

	return result

func _validate_captain_with_warnings() -> Dictionary:
	## Enhanced captain validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	var captain: Dictionary = campaign_data["captain"] as Dictionary

	# Allow initial empty state
	if captain.is_empty():
		(result.warnings as Array).append("Captain not created yet - will be handled in captain panel")
		result.has_warnings = true
		return result

	# Warnings only - allow incomplete captains
	if not captain.has("character_name") or str(captain.get("character_name", "")).is_empty():
		(result.warnings as Array).append("Captain name not set - will use default")
		result.has_warnings = true

	if not captain.has("combat") or int(captain.get("combat", 0)) < 1:
		(result.warnings as Array).append("Captain combat stats need setting")
		result.has_warnings = true

	if not captain.has("toughness") or int(captain.get("toughness", 0)) < 1:
		(result.warnings as Array).append("Captain toughness stats need setting")
		result.has_warnings = true

	# Customization completeness warning
	var completeness: float = float(captain.get("customization_completeness", 1.0))
	if completeness < 0.8:
		(result.warnings as Array).append("Captain customization could be more complete (%.0f%%)" % (completeness * 100))
		result.has_warnings = true

	return result

func _validate_ship_with_warnings() -> Dictionary:
	## Enhanced ship validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	var ship: Dictionary = campaign_data["ship"] as Dictionary

	# Allow empty ship data initially
	if ship.is_empty():
		(result.warnings as Array).append("Ship not assigned yet - will use default")
		result.has_warnings = true
		return result

	# Warnings only
	if not ship.has("name") or str(ship.get("name", "")).is_empty():
		(result.warnings as Array).append("Ship name not set - will use default")
		result.has_warnings = true

	if not ship.has("type") or str(ship.get("type", "")).is_empty():
		(result.warnings as Array).append("Ship type not specified - will use default")
		result.has_warnings = true

	# SPRINT 26.21 FIX: Check both is_configured and is_complete (they are semantically equivalent)
	if not bool(ship.get("is_configured", ship.get("is_complete", false))):
		(result.warnings as Array).append("Ship configuration incomplete - using default setup")
		result.has_warnings = true

	return result

func _validate_equipment_with_warnings() -> Dictionary:
	## Enhanced equipment validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	var equipment: Dictionary = campaign_data["equipment"] as Dictionary

	# Allow empty equipment initially
	if equipment.is_empty():
		(result.warnings as Array).append("Equipment not generated yet - will use default starting equipment")
		result.has_warnings = true
		return result

	# Warnings only - equipment generation is flexible (FIX: use Dictionary access)
	if not equipment.has("equipment") or (equipment["equipment"] as Array).is_empty():
		(result.warnings as Array).append("Starting equipment list empty - will generate defaults")
		result.has_warnings = true

	if not bool(equipment.get("is_complete", false)):
		(result.warnings as Array).append("Equipment setup marked as incomplete")
		result.has_warnings = true

	# Backend integration warning
	if not bool(equipment.get("backend_generated", false)):
		(result.warnings as Array).append("Equipment not generated via backend system (using fallback)")
		result.has_warnings = true

	return result

func _validate_world_with_warnings() -> Dictionary:
	## Enhanced world validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}

	var world: Dictionary = campaign_data["world"] as Dictionary
	
	# World generation is optional in early phases
	if world.is_empty():
		(result.warnings as Array).append("World data not generated yet - will use defaults")
		result.has_warnings = true
	
	return result

func _validate_final_with_warnings() -> Dictionary:
	## Enhanced final validation with warnings support
	var result: Dictionary = {
		"valid": true,
		"blocks_progression": false,
		"has_warnings": false,
		"blocking_errors": [],
		"warnings": []
	}
	
	# Check all phases for blocking errors (only final review requires strict validation)
	var phases_to_check: Array[Phase] = [Phase.CONFIG, Phase.CREW_SETUP, Phase.CAPTAIN_CREATION, Phase.SHIP_ASSIGNMENT, Phase.EQUIPMENT_GENERATION, Phase.WORLD_GENERATION]
	
	for phase: Phase in phases_to_check:
		var phase_result: Dictionary = _validate_phase_with_warnings(phase)
		
		# For final review, warnings become more important but still don't block
		if phase_result.has_warnings:
			(result.warnings as Array).append_array(phase_result.warnings as Array)
			result.has_warnings = true
	
	return result

func complete_campaign_creation() -> Dictionary:
	## Finalize campaign creation and return complete data with enhanced serialization
	if not _validate_final_phase():
		push_error("Cannot complete campaign: Validation failed")
		return {}

	# Generate final campaign data with metadata
	var final_data: Dictionary = campaign_data.duplicate()
	var final_metadata: Dictionary = final_data.metadata as Dictionary
	var final_crew: Dictionary = final_data.crew as Dictionary
	var final_equipment: Dictionary = final_data.equipment as Dictionary
	
	final_metadata.completed_at = Time.get_datetime_string_from_system()
	final_metadata.total_crew_size = final_crew.get("size", 0)
	final_metadata.starting_credits = final_equipment.get("starting_credits", 1000)
	
	# Enhanced character data serialization
	final_data.crew = _serialize_crew_data(final_crew)
	
	# Add campaign statistics
	final_metadata.crew_statistics = _calculate_crew_statistics(final_data.crew as Dictionary)

	creation_completed.emit(final_data)
	return final_data

## Enhanced Character Data Management

func _serialize_crew_data(crew_data: Dictionary) -> Dictionary:
	## Serialize crew data with enhanced character information
	var serialized_crew: Dictionary = crew_data.duplicate()
	
	if crew_data.has("members"):
		var serialized_members: Array = []
		for member: Variant in crew_data.members as Array:
			# Check if member is an Object (Character) or raw Dictionary
			if member is Object:
				var member_obj: Object = member as Object
				if member_obj.has_method("serialize_enhanced"):
					serialized_members.append(member_obj.call("serialize_enhanced"))
				elif member_obj.has_method("serialize"):
					serialized_members.append(member_obj.call("serialize"))
				else:
					serialized_members.append(_fallback_character_serialization(member))
			else:
				# member is a Dictionary, use fallback serialization
				serialized_members.append(_fallback_character_serialization(member))

		serialized_crew.members = serialized_members
	
	return serialized_crew

func _fallback_character_serialization(character: Variant) -> Dictionary:
	## Fallback character serialization for compatibility
	# Sprint 26.3: Character-Everywhere - check Character/Object first
	var char_dict: Dictionary = {}
	if character is Object and character.has_method("to_dictionary"):
		char_dict = character.to_dictionary()
	elif character is Dictionary:
		char_dict = character as Dictionary
	elif character is Object:
		# Convert object properties to dictionary manually
		char_dict = {}
	
	return {
		"character_name": char_dict.get("character_name", ""),
		"background": char_dict.get("background", 0),
		"motivation": char_dict.get("motivation", 0),
		"combat": char_dict.get("combat", 0),
		"reactions": char_dict.get("reactions", char_dict.get("reaction", 0)),
		"toughness": char_dict.get("toughness", 3),
		"savvy": char_dict.get("savvy", 0),
		"speed": char_dict.get("speed", 4),
		"max_health": char_dict.get("max_health", 5),
		"health": char_dict.get("health", 5),
		"is_captain": char_dict.get("is_captain", false),
		"patrons": char_dict.get("patrons", []),
		"rivals": char_dict.get("rivals", []),
		"personal_equipment": char_dict.get("personal_equipment", {}),
		"traits": char_dict.get("traits", []),
		"credits_earned": char_dict.get("credits_earned", 0)
	}

func _calculate_crew_statistics(crew_data: Dictionary) -> Dictionary:
	## Calculate comprehensive crew statistics for campaign metadata
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
		if member is Object and member.has_method("get_customization_completeness"):
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
	## Helper to increment distribution counters
	if distribution.has(key):
		distribution[key] += 1
	else:
		distribution[key] = 1

func reset_creation() -> void:
	## Reset campaign creation state
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
	## Calculate overall completion percentage
	var completed_phases: int = 0
	var total_phases = Phase.FINAL_REVIEW # Exclude FINAL_REVIEW itself

	for phase: int in range(total_phases):
		if _is_phase_valid(phase):
			completed_phases += 1

	return float(completed_phases) / float(total_phases) * 100.0

func get_validation_summary() -> Dictionary:
	## Get comprehensive validation summary
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
	## Export campaign data in format suitable for saving
	return campaign_data.duplicate()

func import_from_save(save_data: Dictionary) -> bool:
	## Import campaign data from save file
	# Security validation for imported data
	var validation_result = _validate_imported_data(save_data)
	if not validation_result.valid:
		return false
	
	campaign_data = validation_result.sanitized_value
	_validate_current_phase()
	return true

# Security validation methods
func _validate_imported_data(save_data: Dictionary) -> FiveParsecsValidationResult:
	## Validate imported save data for security threats
	var result = FiveParsecsValidationResult.new()
	
	# Check for required structure
	var required_keys = ["config", "crew", "captain", "ship", "equipment", "metadata"]
	for key in required_keys:
		if not save_data.has(key):
			result.valid = false
			result.error = "Missing required key: " + key
			return result
	
	# Validate campaign name if present
	if save_data["config"].has("campaign_name"):
		var name_validation = SecurityValidator.validate_string_input(save_data["config"]["campaign_name"], 50)
		if not name_validation.valid:
			result.valid = false
			result.error = "Invalid campaign name: " + name_validation.error
			return result
		save_data["config"]["campaign_name"] = name_validation.sanitized_value

	# Validate character names
	if save_data["crew"].has("members"):
		for member in save_data["crew"]["members"]:
			if member.has("name"):
				var name_validation = SecurityValidator.validate_string_input(member.name, 50)
				if not name_validation.valid:
					result.valid = false
					result.error = "Invalid character name: " + name_validation.error
					return result
				member.name = name_validation.sanitized_value
	
	# Validate captain name
	if save_data.captain.has("name"):
		var name_validation = SecurityValidator.validate_string_input(save_data.captain.name, 50)
		if not name_validation.valid:
			result.valid = false
			result.error = "Invalid captain name: " + name_validation.error
			return result
		save_data.captain.name = name_validation.sanitized_value
	
	result.valid = true
	result.sanitized_value = save_data
	return result

func update_campaign_config_secure(config_data: Dictionary) -> bool:
	## Update campaign configuration with security validation
	var local_validation_errors: Array[String] = []
	
	# Validate campaign name
	if config_data.has("campaign_name"):
		var name_validation: FiveParsecsValidationResult = SecurityValidator.validate_string_input(str(config_data.campaign_name), 50)
		if not name_validation.valid:
			local_validation_errors.append("Campaign name: " + name_validation.error)
		else:
			config_data.campaign_name = name_validation.sanitized_value
	
	# Validate difficulty setting
	if config_data.has("difficulty"):
		var diff_validation: FiveParsecsValidationResult = SecurityValidator.validate_numeric_input(
			config_data.difficulty, 1, 5
		)
		if not diff_validation.valid:
			local_validation_errors.append("Difficulty: " + diff_validation.error)
	
	# Validate crew size
	if config_data.has("crew_size"):
		var crew_validation: FiveParsecsValidationResult = SecurityValidator.validate_numeric_input(
			config_data.crew_size, 1, 8
		)
		if not crew_validation.valid:
			local_validation_errors.append("Crew size: " + crew_validation.error)
	
	if local_validation_errors.size() > 0:
		return false
	
	campaign_data["config"].merge(config_data)
	return true

func update_character_secure(character_data: Dictionary, character_type: String = "crew") -> bool:
	## Update character data with security validation
	var local_validation_errors: Array[String] = []
	
	# Validate character name
	if character_data.has("name"):
		var name_validation: FiveParsecsValidationResult = SecurityValidator.validate_string_input(str(character_data.name), 50)
		if not name_validation.valid:
			local_validation_errors.append("Character name: " + name_validation.error)
		else:
			character_data.name = name_validation.sanitized_value
	
	# Validate background text
	if character_data.has("background_text"):
		var text_validation: FiveParsecsValidationResult = SecurityValidator.validate_string_input(
			str(character_data.background_text), 500
		)
		if not text_validation.valid:
			local_validation_errors.append("Background: " + text_validation.error)
		else:
			character_data.background_text = text_validation.sanitized_value
	
	# Validate numeric attributes
	var numeric_attrs: Array[String] = ["combat", "reactions", "toughness", "savvy", "tech", "speed"]
	for attr: String in numeric_attrs:
		if character_data.has(attr):
			var attr_validation: FiveParsecsValidationResult = SecurityValidator.validate_numeric_input(
				character_data[attr], 1, 6
			)
			if not attr_validation.valid:
				local_validation_errors.append(attr.capitalize() + ": " + attr_validation.error)
	
	if local_validation_errors.size() > 0:
		push_warning("CampaignCreationStateManager: CHARACTER_VALIDATION_FAILED - Character: %s, Errors: %s" % [character_data.get("name", "Unknown"), str(local_validation_errors)])
		return false
	
	# Update appropriate data structure
	match character_type:
		"captain":
			(campaign_data["captain"] as Dictionary).merge(character_data)
		"crew":
			if not (campaign_data["crew"] as Dictionary).has("members"):
				campaign_data["crew"]["members"] = []
			(campaign_data["crew"]["members"] as Array).append(character_data)
	
	pass # Character validated and updated
	return true

# Public API methods for external access
func get_current_phase() -> Phase:
	## Get the current campaign creation phase
	return current_phase

func is_phase_valid(phase: Phase) -> bool:
	## Public wrapper for phase validation
	return _is_phase_valid(phase)

## UI Integration Methods - Bridge between UI expectations and internal implementation
func validate_phase(phase: Phase) -> bool:
	## Validate a specific phase - public method for UI integration
	return _is_phase_valid(phase)

## Data Update Methods - UI Integration Wrappers

func update_config_data(config_data: Dictionary) -> bool:
	## Update configuration data - wrapper for UI integration
	if config_data.is_empty():
		return false

	# Merge with existing config data
	for key in config_data:
		campaign_data["config"][key] = config_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

func update_crew_data(crew_data: Dictionary) -> bool:
	## Update crew data - wrapper for UI integration
	if crew_data.is_empty():
		return false

	# Merge with existing crew data
	for key in crew_data:
		campaign_data["crew"][key] = crew_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

func update_captain_data(captain_data: Dictionary) -> bool:
	## Update captain data - wrapper for UI integration
	if captain_data.is_empty():
		return false

	# Merge with existing captain data
	for key in captain_data:
		campaign_data["captain"][key] = captain_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

# PHASE 1A: Atomic captain confirmation with concurrency protection
func confirm_captain_creation(captain_data: Dictionary) -> Dictionary:
	## Confirm captain creation with atomic operations and concurrency protection
	
	# Lock for atomic operation
	_operation_lock.lock()
	var result = {"success": false, "error": "", "captain_name": ""}
	
	# Prevent concurrent confirmations
	if _is_processing_confirmation:
		result.error = "Captain confirmation already in progress"
		_operation_lock.unlock()
		return result
	
	_is_processing_confirmation = true
	_operation_lock.unlock()
	
	# Validate captain data before confirmation
	if not captain_data.has("character_name") or str(captain_data.get("character_name", "")).is_empty():
		result.error = "Captain must have a name before confirmation"
		_is_processing_confirmation = false
		return result

	# Store original state for rollback if needed
	var original_captain_data = campaign_data["captain"].duplicate(true)

	# Update captain data
	if not update_captain_data(captain_data):
		result.error = "Failed to update captain data"
		_is_processing_confirmation = false
		return result

	# Mark captain as confirmed
	campaign_data["captain"]["confirmed"] = true
	campaign_data["captain"]["created_at"] = Time.get_datetime_string_from_system()

	# Validate captain phase after confirmation
	validation_errors.clear()
	if not _validate_captain_phase():
		# Rollback on validation failure
		campaign_data["captain"] = original_captain_data
		result.error = "Captain validation failed after confirmation: " + str(validation_errors)
		_is_processing_confirmation = false
		return result
	
	# Mark captain creation as complete in metadata
	if not campaign_data["metadata"].has("phase_completion"):
		campaign_data["metadata"]["phase_completion"] = {}

	campaign_data["metadata"]["phase_completion"][Phase.CAPTAIN_CREATION] = {
		"completed": true,
		"completed_at": Time.get_datetime_string_from_system(),
		"captain_name": captain_data.get("character_name", "Unknown")
	}
	
	# Success
	result.success = true
	result.captain_name = captain_data.get("character_name", "Unknown")
	
	
	# Emit state update
	state_updated.emit(Phase.CAPTAIN_CREATION, get_phase_data(Phase.CAPTAIN_CREATION))
	
	_is_processing_confirmation = false
	return result

# PHASE 1A: Transaction-based atomic operations
func create_captain_confirmation_transaction(captain_data: Dictionary) -> String:
	## Create a transaction for atomic captain confirmation with rollback capability
	var transaction := FPCMCampaignCreationTransaction.new()
	var transaction_id = transaction.transaction_id
	
	# Store transaction
	_active_transactions[transaction_id] = transaction
	
	# Begin transaction with current state
	var current_state = get_campaign_data()
	if not transaction.begin_transaction(current_state):
		_active_transactions.erase(transaction_id)
		push_error("Failed to begin captain confirmation transaction")
		return ""
	
	# Add captain update operation
	transaction.add_operation("update_captain", captain_data, {"original_captain": current_state.get("captain", {})})
	
	# Add captain confirmation operation
	transaction.add_operation("confirm_captain", captain_data, {})
	
	# Add validation operation
	transaction.add_operation("validate_phase", {"phase": Phase.CAPTAIN_CREATION}, {})
	
	return transaction_id

func execute_transaction(transaction_id: String) -> Dictionary:
	## Execute a transaction atomically with rollback on failure
	if not _active_transactions.has(transaction_id):
		return {"success": false, "error": "Transaction not found: " + transaction_id}
	
	var transaction = _active_transactions[transaction_id]
	var result = {"success": false, "error": "", "final_state": {}}
	
	# Execute operations
	var success = transaction.execute_operations(self)
	if not success:
		result.error = "Transaction execution failed: " + transaction.last_error
		# Transaction automatically rolls back on failure
		return result
	
	# Commit transaction
	var final_state = transaction.commit_transaction(self)
	if final_state.is_empty():
		result.error = "Transaction commit failed: " + transaction.last_error
		return result
	
	# Success
	result.success = true
	result.final_state = final_state
	
	# Emit state update signals
	state_updated.emit(Phase.CAPTAIN_CREATION, get_phase_data(Phase.CAPTAIN_CREATION))
	
	return result

func rollback_transaction(transaction_id: String, reason: String = "") -> bool:
	## Rollback a transaction to its initial state
	if not _active_transactions.has(transaction_id):
		push_error("Transaction not found for rollback: " + transaction_id)
		return false
	
	var transaction = _active_transactions[transaction_id]
	var success = transaction.rollback_transaction(self, reason)
	
	if success:
		# Emit state update signals after rollback
		_validate_current_phase()
		state_updated.emit(current_phase, get_phase_data(current_phase))
	
	return success

func cleanup_transaction(transaction_id: String) -> void:
	## Clean up completed transaction resources
	if _active_transactions.has(transaction_id):
		var transaction = _active_transactions[transaction_id]
		transaction.cleanup_transaction()
		_active_transactions.erase(transaction_id)

func get_transaction_status(transaction_id: String) -> Dictionary:
	## Get status of a specific transaction
	if not _active_transactions.has(transaction_id):
		return {"error": "Transaction not found"}
	
	var transaction = _active_transactions[transaction_id]
	return transaction.get_transaction_status()

func get_active_transactions() -> Array[String]:
	## Get list of active transaction IDs
	return _active_transactions.keys()

func cleanup_completed_transactions() -> void:
	## Clean up all completed transactions
	var completed_transactions: Array[String] = []
	
	for transaction_id in _active_transactions.keys():
		var transaction = _active_transactions[transaction_id]
		if transaction.is_transaction_complete():
			completed_transactions.append(transaction_id)
	
	for transaction_id in completed_transactions:
		cleanup_transaction(transaction_id)
	
	pass # Transactions cleaned up

func update_ship_data(ship_data: Dictionary) -> bool:
	## Update ship data - wrapper for UI integration
	if ship_data.is_empty():
		return false

	# Merge with existing ship data
	for key in ship_data:
		campaign_data["ship"][key] = ship_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

func update_equipment_data(equipment_data: Dictionary) -> bool:
	## Update equipment data - wrapper for UI integration
	if equipment_data.is_empty():
		return false

	# Merge with existing equipment data
	for key in equipment_data:
		campaign_data["equipment"][key] = equipment_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

func update_world_data(world_data: Dictionary) -> bool:
	## Update world data - wrapper for UI integration
	if world_data.is_empty():
		return false

	# Merge with existing world data
	for key in world_data:
		campaign_data["world"][key] = world_data[key]

	_validate_current_phase()
	state_updated.emit(current_phase, get_phase_data(current_phase))
	return true

func save_phase_data(phase: Phase, data: Dictionary) -> bool:
	## Save data for specific phase - UI integration method
	match phase:
		Phase.CONFIG:
			return update_config_data(data)
		Phase.CREW_SETUP:
			return update_crew_data(data)
		Phase.CAPTAIN_CREATION:
			return update_captain_data(data)
		Phase.SHIP_ASSIGNMENT:
			return update_ship_data(data)
		Phase.EQUIPMENT_GENERATION:
			return update_equipment_data(data)
		Phase.WORLD_GENERATION:
			return update_world_data(data)
		_:
			push_warning("Unknown phase for save_phase_data: " + str(phase))
			return false

func validate_current_step() -> bool:
	## Validate current step - public wrapper for UI integration
	return _is_phase_valid(current_phase)

func can_proceed_to_next_step() -> bool:
	## Check if current step allows proceeding to next step - UI integration method
	return _is_phase_valid(current_phase)

func create_campaign() -> Dictionary:
	## Create final campaign - public wrapper for UI integration
	return complete_campaign_creation()

## Public API method for UI integration - returns complete campaign data
func get_campaign_data() -> Dictionary:
	## Get complete campaign data - public API method for UI integration
	return campaign_data.duplicate()

func get_completion_status() -> Dictionary:
	## Get completion status for all phases
	var status := {}
	for phase in Phase.values():
		var phase_name := get_phase_name(phase)
		status[phase_name] = _is_phase_valid(phase)
	return status

func get_phase_name(phase: Phase) -> String:
	## Get the string name for a phase enum value
	match phase:
		Phase.CONFIG: return "CONFIG"
		Phase.CREW_SETUP: return "CREW_SETUP"
		Phase.CAPTAIN_CREATION: return "CAPTAIN_CREATION"
		Phase.SHIP_ASSIGNMENT: return "SHIP_ASSIGNMENT"
		Phase.EQUIPMENT_GENERATION: return "EQUIPMENT_GENERATION"
		Phase.WORLD_GENERATION: return "WORLD_GENERATION"
		Phase.FINAL_REVIEW: return "FINAL_REVIEW"
		_: return "UNKNOWN"

func update_campaign_data(update_data: Dictionary) -> bool:
	## Update complete campaign data - comprehensive update method for UI integration
	if update_data.is_empty():
		return false
	
	pass # Updating campaign data
	
	# Update each section of campaign data
	var sections_updated = []

	# Update config section
	if update_data.has("config"):
		for key in update_data["config"]:
			campaign_data["config"][key] = update_data["config"][key]
		sections_updated.append("config")

	# Update captain section
	if update_data.has("captain"):
		for key in update_data["captain"]:
			campaign_data["captain"][key] = update_data["captain"][key]
		sections_updated.append("captain")

	# Update crew section
	if update_data.has("crew"):
		for key in update_data["crew"]:
			campaign_data["crew"][key] = update_data["crew"][key]
		sections_updated.append("crew")

	# Update ship section
	if update_data.has("ship"):
		for key in update_data["ship"]:
			campaign_data["ship"][key] = update_data["ship"][key]
		sections_updated.append("ship")

	# Update equipment section
	if update_data.has("equipment"):
		for key in update_data["equipment"]:
			campaign_data["equipment"][key] = update_data["equipment"][key]
		sections_updated.append("equipment")

	# Update world section
	if update_data.has("world"):
		for key in update_data["world"]:
			campaign_data["world"][key] = update_data["world"][key]
		sections_updated.append("world")

	# Update metadata section
	if update_data.has("metadata"):
		for key in update_data["metadata"]:
			campaign_data["metadata"][key] = update_data["metadata"][key]
		sections_updated.append("metadata")
	
	# Validate current phase after updates
	_validate_current_phase()
	
	# Emit state update signal
	state_updated.emit(current_phase, get_phase_data(current_phase))
	
	pass # Campaign data updated
	return true
