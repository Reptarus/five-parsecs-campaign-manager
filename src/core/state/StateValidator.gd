@tool
# REMOVED: class_name ValidationManager

# This class previously used class_name ValidationManager but it was removed to prevent conflicts
# The authoritative ValidationManager class is in src/core/systems/ValidationManager.gd

# This class is now implemented as StateValidationManager (without class_name)
# Use explicit preloads to reference this class: preload("res://src/core/state/StateValidator.gd")
extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")

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
	var type: int = 0 # VerificationType.NONE
	var scope: int = 0 # VerificationScope.NONE
	var result: int = 0 # VerificationResult.NONE
	var message: String = ""
	var context: Dictionary = {}

	func _init(
		p_type: int = 0, # VerificationType.NONE
		p_result: int = 0, # VerificationResult.NONE
		p_message: String = "",
		p_context: Dictionary = {}
	) -> void:
		type = p_type
		result = p_result
		message = p_message
		context = p_context

	func is_error() -> bool:
		return result == 1 or result == 2 # ERROR or CRITICAL

	func is_warning() -> bool:
		return result == 3 # WARNING

	func is_success() -> bool:
		return result == 4 # SUCCESS

# Factory method to create ValidationResult objects
func create_result(
	p_type: int = 0, # VerificationType.NONE
	p_result: int = 0, # VerificationResult.NONE
	p_message: String = "",
	p_context: Dictionary = {}
) -> ValidationResult:
	var result: Variant = ValidationResult.new(p_type, p_result, p_message, p_context)
	return result

## Validate the current game state
func validate_game_state(game_state: GameState) -> Array:
	var results: Array = []

	# Validate basic state integrity
	if not game_state:
		results.append(create_result(
			1, # VerificationType.STATE
			1, # VerificationResult.ERROR
			"Game state is null or invalid"
		))
		return results

	# Check if the campaign is valid
	if not game_state.has_active_campaign():
		results.append(create_result(
			1, # VerificationType.STATE
			3, # VerificationResult.WARNING
			"No active campaign"
		))

	# Check if the crew is valid
	if not game_state.has_crew():
		results.append(create_result(
			1, # VerificationType.STATE
			3, # VerificationResult.WARNING
			"No active crew"
		))
	else:
		var crew_size = game_state.get_crew_size()
		if crew_size < 1:
			results.append(create_result(
				1, # VerificationType.STATE
				1, # VerificationResult.ERROR
				"Crew size is invalid: " + str(crew_size)
			))

	# Check resources
	if not game_state.has_resource(GlobalEnums.ResourceType.CREDITS):
		results.append(create_result(
			1, # VerificationType.STATE
			3, # VerificationResult.WARNING
			"No credits resource found"
		))

	if not game_state.has_resource(GlobalEnums.ResourceType.FUEL):
		results.append(create_result(
			1, # VerificationType.STATE
			3, # VerificationResult.WARNING
			"No fuel resource found"
		))

	# Check if there's a current location
	var current_location = game_state.get_current_location()
	if (safe_call_method(current_location, "is_empty") == true):
		results.append(create_result(
			1, # VerificationType.STATE
			3, # VerificationResult.WARNING
			"No current location set"
		))

	return results

## Validates a campaign _state and returns any errors found
func validate_campaign_state(campaign_state: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# Check for required campaign fields
	if not campaign_state.has("campaign_name"):
		errors.append("Campaign is missing a name") # warning: return value discarded (intentional)

	if not campaign_state.has("campaign_id"):
		errors.append("Campaign is missing an ID") # warning: return value discarded (intentional)

	if not campaign_state.has("current_phase"):
		errors.append("Campaign is missing current phase") # warning: return value discarded (intentional)

	# Check for crew
	if not campaign_state.has("crew") or not campaign_state.crew is Array or campaign_state.crew.size() < 1:
		errors.append("Campaign must have at least one crew member") # warning: return value discarded (intentional)

	# Check for resources
	if not campaign_state.has("resources") or not campaign_state.resources is Dictionary:
		errors.append("Campaign is missing resources data") # warning: return value discarded (intentional)
	else:
		var resources = campaign_state.resources
		if not resources.has("credits"):
			errors.append("Campaign resources missing credits") # warning: return value discarded (intentional)

	# Check for ships
	if not campaign_state.has("ships") or not campaign_state.ships is Array:
		errors.append("Campaign is missing ships data") # warning: return value discarded (intentional)

	# Check for world
	if not campaign_state.has("current_world") or not campaign_state.current_world is Dictionary:
		errors.append("Campaign is missing current world data") # warning: return value discarded (intentional)

	# If errors were found, emit the validation_failed signal
	if errors.size() > 0:
		validation_failed.emit(errors) # warning: return value discarded (intentional)

	return errors

## Validates character data and returns any errors found
func validate_character(character_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# Check for required character fields
	if not character_data.has("character_id"):
		errors.append("Character is missing an ID") # warning: return value discarded (intentional)

	if not character_data.has("character_name") or character_data.character_name.strip_edges().is_empty():
		errors.append("Character is missing a name") # warning: return value discarded (intentional)

	if not character_data.has("character_class"):
		errors.append("Character is missing a class") # warning: return value discarded (intentional)

	# Check for stats
	if not character_data.has("stats") or not character_data.stats is Dictionary:
		errors.append("Character is missing stats") # warning: return value discarded (intentional)
	else:
		var stats = character_data.stats
		var required_stats = ["strength", "agility", "toughness", "intelligence", "willpower"]

		for stat in required_stats:
			if not stats.has(stat):
				errors.append("Character is missing required stat: " + stat) # warning: return value discarded (intentional)

	# Check for equipment
	if not character_data.has("equipment") or not character_data.equipment is Dictionary:
		errors.append("Character is missing equipment data") # warning: return value discarded (intentional)

	return errors

## Validates a mission and returns any errors found
func validate_mission(mission_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# Check for required mission fields
	if not mission_data.has("mission_id"):
		errors.append("Mission is missing an ID") # warning: return value discarded (intentional)

	if not mission_data.has("mission_name") or mission_data.mission_name.strip_edges().is_empty():
		errors.append("Mission is missing a name") # warning: return value discarded (intentional)

	if not mission_data.has("mission_type"):
		errors.append("Mission is missing a type") # warning: return value discarded (intentional)

	if not mission_data.has("objectives") or not mission_data.objectives is Array or mission_data.objectives.size() < 1:
		errors.append("Mission must have at least one objective") # warning: return value discarded (intentional)

	if not mission_data.has("reward") or not mission_data.reward is Dictionary:
		errors.append("Mission is missing reward data") # warning: return value discarded (intentional)

	return errors

## Validates a ship and returns any errors found
func validate_ship(ship_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# Check for required ship fields
	if not ship_data.has("ship_id"):
		errors.append("Ship is missing an ID") # warning: return value discarded (intentional)

	if not ship_data.has("ship_name") or ship_data.ship_name.strip_edges().is_empty():
		errors.append("Ship is missing a name") # warning: return value discarded (intentional)

	if not ship_data.has("ship_type"):
		errors.append("Ship is missing a type") # warning: return value discarded (intentional)

	# Check for components
	if not ship_data.has("components") or not ship_data.components is Array:
		errors.append("Ship is missing component data") # warning: return value discarded (intentional)

	return errors

## Run validation and emit signals
func run_validation(game_state: GameState, validation_type: ValidationType, scope: ValidationScope = ValidationScope.CURRENT) -> void:
	var results: Array = []

	match validation_type:
		ValidationType.GAME_STATE:
			results = validate_game_state(game_state)
		ValidationType.CAMPAIGN_STATE:
			if game_state.has_active_campaign():
				var campaign_data: Dictionary = game_state.get_active_campaign_data()
				var campaign_errors: Array[String] = validate_campaign_state(campaign_data)
				# Convert string errors to ValidationResult objects
				for error_msg in campaign_errors:
					results.append(create_result(
						1, # VerificationType.STATE
						1, # VerificationResult.ERROR
						error_msg
					))
			else:
				results.append(create_result(
					1, # VerificationType.STATE
					1, # VerificationResult.ERROR
					"No active campaign to validate"
				))
		ValidationType.CHARACTER_STATE:
			if game_state.has_crew():
				var crew_members: Array = game_state.get_crew_members()
				for character in crew_members:
					if character is Dictionary:
						var character_dict: Dictionary = character as Dictionary
						var character_errors: Array[String] = validate_character(character_dict)
						# Convert string errors to ValidationResult objects
						for error_msg in character_errors:
							results.append(create_result(
								1, # VerificationType.STATE
								1, # VerificationResult.ERROR
								error_msg
							))
					else:
						results.append(create_result(
							1, # VerificationType.STATE
							1, # VerificationResult.ERROR
							"Invalid character data type"
						))
			else:
				results.append(create_result(
					1, # VerificationType.STATE
					1, # VerificationResult.ERROR
					"No crew to validate characters"
				))

	# Check for errors
	var errors: Array[String] = []
	for result in results:
		if result is ValidationResult and result.is_error():
			errors.append(result.message) # warning: return value discarded (intentional)

	if errors.size() > 0:
		validation_failed.emit(errors) # warning: return value discarded (intentional)
	else:
		validation_success.emit() # warning: return value discarded (intentional)

	validation_complete.emit(results) # warning: return value discarded (intentional)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null