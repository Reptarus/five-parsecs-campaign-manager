@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParcsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

enum CreationStep {
	CAMPAIGN_CONFIG,
	CREW_CREATION,
	RESOURCE_SETUP,
	FINALIZATION
}

# Signals for campaign creation flow
signal creation_step_changed(step: int)
signal campaign_config_completed(config: Dictionary)
signal crew_creation_completed(crew_data: Array[Dictionary])
signal character_creation_completed(character: Character)
signal resources_initialized(resources: Dictionary)
signal campaign_creation_completed(campaign: FiveParcsecsCampaign)

var current_step: int = CreationStep.CAMPAIGN_CONFIG
var campaign_config: Dictionary = {}
var crew_data: Array[Dictionary] = []
var captain_data: Character
var initial_resources: Dictionary = {}

var game_state: GameState
var save_manager: SaveManager

func _init() -> void:
	game_state = GameState.new()
	save_manager = SaveManager.new()
	add_child(game_state)
	add_child(save_manager)

func _ready() -> void:
	reset_creation_data()

func reset_creation_data() -> void:
	current_step = CreationStep.CAMPAIGN_CONFIG
	campaign_config.clear()
	crew_data.clear()
	initial_resources.clear()
	captain_data = null

func start_campaign_creation() -> void:
	reset_creation_data()
	advance_to_next_step()

func advance_to_next_step() -> void:
	match current_step:
		CreationStep.CAMPAIGN_CONFIG:
			current_step = CreationStep.CREW_CREATION
		CreationStep.CREW_CREATION:
			current_step = CreationStep.RESOURCE_SETUP
		CreationStep.RESOURCE_SETUP:
			current_step = CreationStep.FINALIZATION
		CreationStep.FINALIZATION:
			finalize_campaign_creation()
			return
	
	creation_step_changed.emit(current_step)

func set_campaign_config(config: Dictionary) -> void:
	campaign_config = config.duplicate()
	campaign_config_completed.emit(campaign_config)

func set_crew_data(data: Array[Dictionary]) -> void:
	crew_data = data.duplicate()
	crew_creation_completed.emit(crew_data)

func set_initial_resources(resources: Dictionary) -> void:
	initial_resources = resources.duplicate()
	resources_initialized.emit(initial_resources)

func finalize_campaign_creation() -> FiveParcsecsCampaign:
	var campaign = FiveParcsecsCampaign.new()
	
	# Configure campaign with collected data
	campaign.configure(campaign_config)
	campaign.set_crew(crew_data)
	campaign.set_resources(initial_resources)
	
	campaign_creation_completed.emit(campaign)
	return campaign

func submit_captain_data(captain: Character) -> void:
	captain_data = captain
	character_creation_completed.emit(captain)
	advance_to_next_step()

func initialize_resources(difficulty: int) -> void:
	initial_resources = _calculate_initial_resources(difficulty)
	resources_initialized.emit(initial_resources)
	advance_to_next_step()

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

# Validation methods
func can_advance_to_next_step() -> bool:
	match current_step:
		CreationStep.CAMPAIGN_CONFIG:
			return _validate_campaign_config()
		CreationStep.CREW_CREATION:
			return _validate_crew_data()
		CreationStep.RESOURCE_SETUP:
			return _validate_resources()
		CreationStep.FINALIZATION:
			return true
	return false

func _validate_campaign_config() -> bool:
	return campaign_config.has("name") and campaign_config.has("difficulty")

func _validate_crew_data() -> bool:
	return crew_data.size() >= 4 and crew_data.size() <= 6

func _validate_resources() -> bool:
	return not initial_resources.is_empty()