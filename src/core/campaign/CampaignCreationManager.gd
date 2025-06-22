@tool
@warning_ignore("return_value_discarded")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_call_argument")
@warning_ignore("untyped_declaration")
@warning_ignore("unused_variable")
@warning_ignore("redundant_await")
@warning_ignore("unsafe_cast")
@warning_ignore("inference_on_variant")
@warning_ignore("static_called_on_instance")
extends Node
class_name CampaignCreationManager

## Campaign Creation Manager for Five Parsecs from Home
## Manages the step-by-step campaign creation process

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParcsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
# Note: GameState/SaveManager injected via setup() to avoid circular dependencies
const SaveManager = preload("res://src/core/state/SaveManager.gd")

signal creation_step_changed(step: int)
signal campaign_config_completed(config: Dictionary)
signal crew_creation_completed(crew_data: Array[Dictionary])
signal character_creation_completed(character: Character)
signal resources_initialized(resources: Dictionary)
signal campaign_creation_completed(campaign: FiveParcsecsCampaign)
signal validation_failed(errors: Array[String])

enum CreationStep {
	CONFIG,
	CREW,
	CAPTAIN,
	RESOURCES,
	FINAL
}

var current_step: CreationStep = CreationStep.CONFIG
var campaign_data: Dictionary = {}
var creation_errors: Array[String] = []
var game_state: Node # GameState - avoiding circular dependency
var save_manager: SaveManager

func _init() -> void:
	name = "CampaignCreationManager"
	_initialize_campaign_data()
	# GameState and SaveManager will be injected via setup()
	save_manager = SaveManager.new()
	# Note: Only add to scene tree if they extend Node
	# These classes may be Resources, not Nodes

func _ready() -> void:
	reset_creation()

func _initialize_campaign_data() -> void:
	campaign_data = {
		"config": {},
		"crew": [],
		"captain": {},
		"resources": {},
		"settings": {}
	}

func advance_step() -> void:
	if _validate_current_step():
		if current_step < CreationStep.FINAL:
			current_step += 1
			creation_step_changed.emit(current_step)
		else:
			_finalize_creation()
	else:
		validation_failed.emit(creation_errors)

func go_back_step() -> void:
	if current_step > CreationStep.CONFIG:
		current_step -= 1
		creation_step_changed.emit(current_step)

func _validate_current_step() -> bool:
	creation_errors.clear()
	
	match current_step:
		CreationStep.CONFIG:
			return _validate_config()
		CreationStep.CREW:
			return _validate_crew()
		CreationStep.CAPTAIN:
			return _validate_captain()
		CreationStep.RESOURCES:
			return _validate_resources()
		CreationStep.FINAL:
			return _validate_final()
		_:
			return false

func _validate_config() -> bool:
	return campaign_data.config.has("name") and campaign_data.config.has("difficulty")

func _validate_crew() -> bool:
	return campaign_data.crew.size() >= 4 and campaign_data.crew.size() <= 6

func _validate_captain() -> bool:
	return campaign_data.captain.is_valid()

func _validate_resources() -> bool:
	return not campaign_data.resources.is_empty()

func _validate_final() -> bool:
	return true

func set_config_data(config: Dictionary) -> void:
	campaign_data.config = config.duplicate(true)

func set_crew_data(crew: Array) -> void:
	campaign_data.crew = crew.duplicate(true)

func set_captain_data(captain: Dictionary) -> void:
	campaign_data.captain = captain.duplicate(true)

func set_resource_data(resources: Dictionary) -> void:
	campaign_data.resources = resources.duplicate(true)

func finalize_campaign_creation() -> FiveParcsecsCampaign:
	if _validate_all_steps():
		var campaign := FiveParcsecsCampaign.new()
		campaign.configure(campaign_data.config)
		return campaign
	return null
func _validate_all_steps() -> bool:
	creation_errors.clear()
	var valid = true
	
	for step in CreationStep.values():
		current_step = step
		if not _validate_current_step():
			valid = false
	
	return valid

func _finalize_creation() -> void:
	var final_campaign = finalize_campaign_creation()
	if final_campaign:
		campaign_creation_completed.emit(final_campaign)

func get_campaign_data() -> Dictionary:
	return campaign_data.duplicate(true)

func reset_creation() -> void:
	current_step = CreationStep.CONFIG
	_initialize_campaign_data()
	creation_errors.clear()
	creation_step_changed.emit(current_step)

func set_campaign_config(config: Dictionary) -> void:
	campaign_data.config = config.duplicate()
	campaign_config_completed.emit(campaign_data.config)

func set_initial_resources(resources: Dictionary) -> void:
	campaign_data.resources = resources.duplicate()
	resources_initialized.emit(campaign_data.resources)

func submit_captain_data(captain: Character) -> void:
	campaign_data.captain = captain
	character_creation_completed.emit(captain)
	advance_step()

func initialize_resources(difficulty: int) -> void:
	campaign_data.resources = _calculate_initial_resources(difficulty)
	resources_initialized.emit(campaign_data.resources)
	advance_step()

func _calculate_initial_resources(difficulty: int) -> Dictionary:
	var resources = {
		GameEnums.ResourceType.CREDITS: 1000,
		GameEnums.ResourceType.SUPPLIES: 5,
		GameEnums.ResourceType.TECH_PARTS: 0,
		GameEnums.ResourceType.PATRON: 0
	}
	
	# Adjust based on difficulty
	match difficulty:
		GameEnums.DifficultyLevel.EASY:
			resources[GameEnums.ResourceType.CREDITS] = 1200
			resources[GameEnums.ResourceType.SUPPLIES] = 7
		GameEnums.DifficultyLevel.HARD:
			resources[GameEnums.ResourceType.CREDITS] = 800
			resources[GameEnums.ResourceType.SUPPLIES] = 3
		GameEnums.DifficultyLevel.NIGHTMARE:
			resources[GameEnums.ResourceType.CREDITS] = 500
			resources[GameEnums.ResourceType.SUPPLIES] = 2
	
	return resources