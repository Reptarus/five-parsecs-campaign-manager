@tool
# REMOVED: class_name ValidationManager
# This class previously used class_name ValidationManager but it was removed to prevent conflicts
# The authoritative ValidationManager class is in src/core/systems/ValidationManager.gd
# This class is now implemented as StateValidationManager (without class_name)
# Use explicit preloads to reference this class: preload("res://src/core/state/StateValidator.gd")
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal validation_complete(results: Array)
signal validation_failed(errors: Array[String])
signal validation_success

## Validation Types
enum ValidationType {
	GAME_STATE,
	CAMPAIGN_STATE,
	CHARACTER_STATE,
	CREW_STATE,
	BATTLE_STATE,
	MISSION_STATE
}

## Validation scopes define what to validate
enum ValidationScope {
	ALL,
	CURRENT,
	SPECIFIC
}

## Validation results
class ValidationResult:
	var type: int = GameEnums.VerificationType.NONE
	var scope: int = 0
	var result: int = 0
	var message: String = ""
	var context: Dictionary = {}
	
	func _init(
		p_type: int = 0,
		p_result: int = 0,
		p_message: String = "",
		p_context: Dictionary = {}
	) -> void:
		type = p_type
		result = p_result
		message = p_message
		context = p_context
	
	func is_error() -> bool:
		return result == GameEnums.VerificationResult.ERROR or result == GameEnums.VerificationResult.CRITICAL
	
	func is_warning() -> bool:
		return result == GameEnums.VerificationResult.WARNING
	
	func is_success() -> bool:
		return result == GameEnums.VerificationResult.SUCCESS

# Factory method to create ValidationResult objects
func create_result(
	p_type: int = 0,
	p_result: int = 0,
	p_message: String = "",
	p_context: Dictionary = {}
) -> ValidationResult:
	var result = ValidationResult.new(p_type, p_result, p_message, p_context)
	return result

## Validate the current game state
func validate_game_state(game_state: FiveParsecsGameState) -> Array:
	var results: Array = []
	
	# Validate basic state integrity
	if not game_state:
		results.append(create_result(
			GameEnums.VerificationType.STATE,
			GameEnums.VerificationResult.ERROR,
			"Game state is null or invalid"
		))
		return results
	
	# Check if the campaign is valid
	if not game_state.has_active_campaign():
		results.append(create_result(
			GameEnums.VerificationType.STATE,
			GameEnums.VerificationResult.WARNING,
			"No active campaign"
		))
	
	# Check if the crew is valid
	if not game_state.has_crew():
		results.append(create_result(
			GameEnums.VerificationType.STATE,
			GameEnums.VerificationResult.WARNING,
			"No active crew"
		))
	else:
		var crew_size = game_state.get_crew_size()
		if crew_size < 1:
			results.append(create_result(
				GameEnums.VerificationType.STATE,
				GameEnums.VerificationResult.ERROR,
				"Crew size is invalid: " + str(crew_size)
			))
	
	# Check resources
	if not game_state.has_method("has_resource"):
		results.append(create_result(
			GameEnums.VerificationType.STATE,
			GameEnums.VerificationResult.WARNING,
			"GameState missing has_resource method"
		))
	else:
		if not game_state.has_resource(GameEnums.ResourceType.CREDITS):
			results.append(create_result(
				GameEnums.VerificationType.STATE,
				GameEnums.VerificationResult.WARNING,
				"No credits resource found"
			))
		
		if not game_state.has_resource(GameEnums.ResourceType.FUEL):
			results.append(create_result(
				GameEnums.VerificationType.STATE,
				GameEnums.VerificationResult.WARNING,
				"No fuel resource found"
			))
	
	# Check if there's a current location
	if not game_state.get_current_location():
		results.append(create_result(
			GameEnums.VerificationType.STATE,
			GameEnums.VerificationResult.WARNING,
			"No current location set"
		))
	
	return results

## Validates a campaign state and returns any errors found
func validate_campaign_state(campaign_state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	# Check for required campaign fields
	if not campaign_state.has("campaign_name"):
		errors.append("Campaign is missing a name")
	
	if not campaign_state.has("campaign_id"):
		errors.append("Campaign is missing an ID")
	
	if not campaign_state.has("current_phase"):
		errors.append("Campaign is missing current phase")
	
	# Check for crew
	if not campaign_state.has("crew") or not campaign_state.crew is Array or campaign_state.crew.size() < 1:
		errors.append("Campaign must have at least one crew member")
	
	# Check for resources
	if not campaign_state.has("resources") or not campaign_state.resources is Dictionary:
		errors.append("Campaign is missing resources data")
	else:
		var resources = campaign_state.resources
		if not resources.has("credits"):
			errors.append("Campaign resources missing credits")
	
	# Check for ships
	if not campaign_state.has("ships") or not campaign_state.ships is Array:
		errors.append("Campaign is missing ships data")
	
	# Check for world
	if not campaign_state.has("current_world") or not campaign_state.current_world is Dictionary:
		errors.append("Campaign is missing current world data")
	
	# If errors were found, emit the validation_failed signal
	if errors.size() > 0:
		validation_failed.emit(errors)
		
	return errors

## Validates character data and returns any errors found
func validate_character(character_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	# Check for required character fields
	if not character_data.has("character_id"):
		errors.append("Character is missing an ID")
	
	if not character_data.has("character_name") or character_data.character_name.strip_edges().is_empty():
		errors.append("Character is missing a name")
	
	if not character_data.has("character_class"):
		errors.append("Character is missing a class")
	
	# Check for stats
	if not character_data.has("stats") or not character_data.stats is Dictionary:
		errors.append("Character is missing stats")
	else:
		var stats = character_data.stats
		var required_stats = ["strength", "agility", "toughness", "intelligence", "willpower"]
		
		for stat in required_stats:
			if not stats.has(stat):
				errors.append("Character is missing required stat: " + stat)
	
	# Check for equipment
	if not character_data.has("equipment") or not character_data.equipment is Dictionary:
		errors.append("Character is missing equipment data")
	
	return errors

## Validates a mission and returns any errors found
func validate_mission(mission_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	# Check for required mission fields
	if not mission_data.has("mission_id"):
		errors.append("Mission is missing an ID")
	
	if not mission_data.has("mission_name") or mission_data.mission_name.strip_edges().is_empty():
		errors.append("Mission is missing a name")
	
	if not mission_data.has("mission_type"):
		errors.append("Mission is missing a type")
	
	if not mission_data.has("objectives") or not mission_data.objectives is Array or mission_data.objectives.size() < 1:
		errors.append("Mission must have at least one objective")
	
	if not mission_data.has("reward") or not mission_data.reward is Dictionary:
		errors.append("Mission is missing reward data")
	
	return errors

## Validates a ship and returns any errors found
func validate_ship(ship_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	
	# Check for required ship fields
	if not ship_data.has("ship_id"):
		errors.append("Ship is missing an ID")
	
	if not ship_data.has("ship_name") or ship_data.ship_name.strip_edges().is_empty():
		errors.append("Ship is missing a name")
	
	if not ship_data.has("ship_type"):
		errors.append("Ship is missing a type")
	
	# Check for components
	if not ship_data.has("components") or not ship_data.components is Array:
		errors.append("Ship is missing component data")
	
	return errors

## Run validation and emit signals
func run_validation(game_state: FiveParsecsGameState, validation_type: ValidationType, scope: ValidationScope = ValidationScope.CURRENT) -> void:
	var results = []
	
	match validation_type:
		ValidationType.GAME_STATE:
			results = validate_game_state(game_state)
		ValidationType.CAMPAIGN_STATE:
			if game_state.has_active_campaign():
				results = validate_campaign_state(game_state.get_active_campaign_data())
			else:
				results.append(create_result(
					GameEnums.VerificationType.STATE,
					GameEnums.VerificationResult.ERROR,
					"No active campaign to validate"
				))
		ValidationType.CHARACTER_STATE:
			if game_state.has_crew():
				for character in game_state.get_crew_members():
					results.append_array(validate_character(character))
			else:
				results.append(create_result(
					GameEnums.VerificationType.STATE,
					GameEnums.VerificationResult.ERROR,
					"No crew to validate characters"
				))
	
	# Check for errors
	var errors: Array[String] = []
	for result in results:
		if result.is_error():
			errors.append(result.message)
	
	if errors.size() > 0:
		validation_failed.emit(errors)
	else:
		validation_success.emit()
	
	validation_complete.emit(results)