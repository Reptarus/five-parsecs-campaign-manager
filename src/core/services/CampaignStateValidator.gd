class_name CampaignStateValidator
## Campaign State Validator for Five Parsecs Campaign Manager
## Validates campaign state integrity, phase transitions, and victory conditions
## Based on Five Parsecs Core Rulebook campaign rules
##
## Usage: Service layer for campaign state validation
## Architecture: Stateless validator using all Constants classes

## Dependencies
const CampaignPhaseConstants = preload("res://src/core/systems/CampaignPhaseConstants.gd")
const CampaignVictoryConstants = preload("res://src/core/systems/CampaignVictoryConstants.gd")
const CharacterAdvancementConstants = preload("res://src/core/systems/CharacterAdvancementConstants.gd")
const InjurySystemConstants = preload("res://src/core/systems/InjurySystemConstants.gd")
const FiveParsecsConstants = preload("res://src/core/systems/FiveParsecsConstants.gd")

## Campaign-specific validation result structure
class CampaignValidationResult:
	var valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var info: Array[String] = []

	func add_error(message: String) -> void:
		errors.append(message)
		valid = false

	func add_warning(message: String) -> void:
		warnings.append(message)

	func add_info(message: String) -> void:
		info.append(message)

	func to_dict() -> Dictionary:
		return {
			"valid": valid,
			"errors": errors,
			"warnings": warnings,
			"info": info
		}

## ==========================================
## PUBLIC API - CAMPAIGN STATE VALIDATION
## ==========================================

## Validate complete campaign state
static func validate_campaign_state(campaign_data: Dictionary) -> CampaignValidationResult:
	"""Comprehensive campaign state validation

	Args:
		campaign_data: Complete campaign state dictionary

	Returns:
		CampaignValidationResult with all validation issues
	"""
	var result := CampaignValidationResult.new()

	# Validate required fields
	_validate_required_fields(campaign_data, result)

	# Validate crew composition
	_validate_crew(campaign_data, result)

	# Validate economy state
	_validate_economy(campaign_data, result)

	# Validate phase state
	_validate_phase(campaign_data, result)

	# Validate victory progress
	_validate_victory_progress(campaign_data, result)

	return result

## Validate phase transition
static func validate_phase_transition(current_phase: int, target_phase: int) -> CampaignValidationResult:
	"""Validate if phase transition is allowed

	Args:
		current_phase: Current CampaignPhase enum value
		target_phase: Target CampaignPhase enum value

	Returns:
		CampaignValidationResult
	"""
	var result := CampaignValidationResult.new()

	var transition_check := CampaignPhaseConstants.validate_transition(current_phase, target_phase)

	if not transition_check.valid:
		result.add_error(transition_check.reason)
	else:
		result.add_info("Valid transition: %s -> %s" % [
			CampaignPhaseConstants.get_phase_name(current_phase),
			CampaignPhaseConstants.get_phase_name(target_phase)
		])

	return result

## Validate crew composition
static func validate_crew_composition(crew: Array) -> CampaignValidationResult:
	"""Validate crew size and member validity

	Args:
		crew: Array of character dictionaries

	Returns:
		CampaignValidationResult
	"""
	var result := CampaignValidationResult.new()

	# Check minimum crew size
	var min_crew := FiveParsecsConstants.CHARACTER_CREATION.min_crew_size
	if crew.size() < min_crew:
		result.add_error("Crew size (%d) below minimum (%d)" % [crew.size(), min_crew])

	# Check maximum crew size
	var max_crew := FiveParsecsConstants.CHARACTER_CREATION.max_crew_size
	if crew.size() > max_crew:
		result.add_error("Crew size (%d) exceeds maximum (%d)" % [crew.size(), max_crew])

	# Validate each crew member
	for i in range(crew.size()):
		var member = crew[i]
		if member == null or not member is Dictionary:
			result.add_error("Crew member %d is null or invalid" % i)
			continue

		# Check required fields
		if not member.has("character_id") or member.character_id == "":
			result.add_error("Crew member %d missing character_id" % i)

		# Check for duplicate IDs
		for j in range(i + 1, crew.size()):
			if crew[j] is Dictionary and crew[j].get("character_id", "") == member.get("character_id", ""):
				result.add_error("Duplicate character_id: %s" % member.character_id)
				break

	return result

## Validate victory condition progress
static func check_victory_condition(campaign_data: Dictionary, condition_type: int, target_value: int) -> CampaignValidationResult:
	"""Check if victory condition is met

	Args:
		campaign_data: Campaign state dictionary
		condition_type: CampaignVictoryConstants.VictoryConditionType enum
		target_value: Target value for victory

	Returns:
		CampaignValidationResult with victory status
	"""
	var result := CampaignValidationResult.new()

	var current_value := 0

	# Get current value based on condition type
	match condition_type:
		CampaignVictoryConstants.VictoryConditionType.SURVIVE_TURNS:
			current_value = campaign_data.get("current_turn", 0)
		CampaignVictoryConstants.VictoryConditionType.STORY_POINTS:
			current_value = campaign_data.get("story_points", 0)
		CampaignVictoryConstants.VictoryConditionType.WEALTH:
			current_value = campaign_data.get("credits", 0)
		CampaignVictoryConstants.VictoryConditionType.REPUTATION:
			current_value = campaign_data.get("reputation", 0)
		CampaignVictoryConstants.VictoryConditionType.CREW_SIZE:
			var crew: Array = campaign_data.get("crew", [])
			current_value = crew.size()
		_:
			result.add_warning("Unknown victory condition type: %d" % condition_type)
			return result

	# Check if condition met
	var is_met := CampaignVictoryConstants.check_victory_condition(condition_type, current_value, target_value)

	if is_met:
		result.add_info("Victory condition MET: %d/%d" % [current_value, target_value])
	else:
		var percentage := CampaignVictoryConstants.get_completion_percentage(current_value, target_value)
		result.add_info("Victory progress: %d/%d (%.1f%%)" % [current_value, target_value, percentage])

	return result

## ==========================================
## PRIVATE VALIDATION HELPERS
## ==========================================

static func _validate_required_fields(campaign_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate required campaign fields exist"""
	var required_fields := [
		"campaign_name",
		"current_turn",
		"current_phase",
		"crew",
		"credits"
	]

	for field in required_fields:
		if not campaign_data.has(field):
			result.add_error("Missing required field: %s" % field)

static func _validate_crew(campaign_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate crew composition and status"""
	if not campaign_data.has("crew"):
		return  # Already flagged by required fields check

	var crew: Array = campaign_data.crew if campaign_data.crew is Array else []
	var crew_validation := validate_crew_composition(crew)

	# Merge validation results
	for error in crew_validation.errors:
		result.add_error(error)
	for warning in crew_validation.warnings:
		result.add_warning(warning)

	# Check for injured/dead crew
	var active_count := 0
	var injured_count := 0
	var dead_count := 0
	var current_turn: int = campaign_data.get("current_turn", 0)

	for member in crew:
		if member is Dictionary:
			var status: String = member.get("status", "ACTIVE")
			match status:
				"ACTIVE":
					active_count += 1
				"INJURED":
					injured_count += 1
					# Check if injury should be recovered
					var available_turn: int = member.get("available_turn", 0)
					if available_turn > 0 and current_turn >= available_turn:
						result.add_warning("Crew member %s should be recovered (turn %d >= %d)" % [
							member.get("character_id", "unknown"),
							current_turn,
							available_turn
						])
				"DEAD":
					dead_count += 1

	result.add_info("Crew status: %d active, %d injured, %d dead" % [active_count, injured_count, dead_count])

	if active_count == 0 and injured_count == 0:
		result.add_error("Campaign has no available crew members!")

static func _validate_economy(campaign_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate economy state"""
	var credits: int = campaign_data.get("credits", 0)

	if credits < 0:
		result.add_error("Credits cannot be negative: %d" % credits)

	# Check if credits are suspiciously high
	if credits > 10000:
		result.add_warning("Credits extremely high: %d (possible cheating?)" % credits)

	# Check equipment stash size if available
	if campaign_data.has("equipment"):
		var equipment: Array = campaign_data.equipment if campaign_data.equipment is Array else []
		const MAX_STASH := 10

		if equipment.size() > MAX_STASH:
			result.add_error("Equipment stash exceeds maximum: %d/%d" % [equipment.size(), MAX_STASH])

static func _validate_phase(campaign_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate current campaign phase"""
	if not campaign_data.has("current_phase"):
		return  # Already flagged by required fields

	var current_phase: int = campaign_data.current_phase

	# Validate phase value
	if not current_phase in CampaignPhaseConstants.CampaignPhase.values():
		result.add_error("Invalid campaign phase value: %d" % current_phase)
		return

	var phase_name := CampaignPhaseConstants.get_phase_name(current_phase)
	result.add_info("Current phase: %s" % phase_name)

	# Check phase requirements
	var requirements := CampaignPhaseConstants.get_phase_requirements(current_phase)

	if requirements.has("min_credits"):
		var credits: int = campaign_data.get("credits", 0)
		if credits < requirements.min_credits:
			result.add_warning("Credits below phase requirement: %d < %d" % [credits, requirements.min_credits])

	if requirements.has("min_crew"):
		var crew: Array = campaign_data.get("crew", [])
		if crew.size() < requirements.min_crew:
			result.add_error("Crew size below phase requirement: %d < %d" % [crew.size(), requirements.min_crew])

static func _validate_victory_progress(campaign_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate victory condition progress"""
	# Check if victory condition is defined
	if not campaign_data.has("victory_condition"):
		result.add_warning("No victory condition defined for campaign")
		return

	var victory_condition: Dictionary = campaign_data.victory_condition if campaign_data.victory_condition is Dictionary else {}

	if not victory_condition.has("type") or not victory_condition.has("target"):
		result.add_warning("Victory condition missing type or target")
		return

	var condition_type: int = victory_condition.type
	var target_value: int = victory_condition.target

	# Check victory progress
	var victory_check := check_victory_condition(campaign_data, condition_type, target_value)

	for info in victory_check.info:
		result.add_info(info)
	for warning in victory_check.warnings:
		result.add_warning(warning)

## ==========================================
## PUBLIC API - ACHIEVEMENT VALIDATION
## ==========================================

## Check all achievements for campaign
static func check_achievements(campaign_data: Dictionary) -> Array[String]:
	"""Get list of unlocked achievement IDs

	Args:
		campaign_data: Campaign state dictionary

	Returns:
		Array of achievement ID strings
	"""
	return CampaignVictoryConstants.get_unlocked_achievements(campaign_data)

## Validate achievement unlock
static func validate_achievement(achievement_id: String, campaign_data: Dictionary) -> CampaignValidationResult:
	"""Check if achievement is validly unlocked

	Args:
		achievement_id: Achievement identifier
		campaign_data: Campaign state dictionary

	Returns:
		CampaignValidationResult
	"""
	var result := CampaignValidationResult.new()

	if not CampaignVictoryConstants.ACHIEVEMENT_THRESHOLDS.has(achievement_id):
		result.add_error("Unknown achievement ID: %s" % achievement_id)
		return result

	var achievement: Dictionary = CampaignVictoryConstants.ACHIEVEMENT_THRESHOLDS[achievement_id]
	var check_type: String = achievement.get("check_type", "")
	var threshold: int = achievement.get("threshold", 0)
	var current_value := 0

	# Get current value based on check type
	match check_type:
		"credits":
			current_value = campaign_data.get("credits", 0)
		"crew_size":
			var crew: Array = campaign_data.get("crew", [])
			current_value = crew.size()
		"captain_xp":
			var captain: Dictionary = campaign_data.get("captain", {})
			current_value = captain.get("experience", 0)
		"casualties":
			current_value = campaign_data.get("total_casualties", 0)
		"weapon_count":
			var equipment: Array = campaign_data.get("equipment", [])
			current_value = equipment.size()
		"turns":
			current_value = campaign_data.get("current_turn", 0)
		_:
			result.add_warning("Unknown achievement check type: %s" % check_type)
			return result

	# Check if unlocked
	var is_unlocked := CampaignVictoryConstants.check_achievement(achievement_id, current_value)

	if is_unlocked:
		result.add_info("Achievement UNLOCKED: %s (%d >= %d)" % [achievement.name, current_value, threshold])
	else:
		result.add_info("Achievement locked: %s (%d / %d)" % [achievement.name, current_value, threshold])

	return result
