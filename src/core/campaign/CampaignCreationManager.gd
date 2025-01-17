extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Campaign = preload("res://src/core/campaign/Campaign.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

# Signals for campaign creation flow
signal creation_step_changed(step: int)
signal campaign_config_completed(config: Dictionary)
signal crew_creation_completed(crew_data: Array)
signal character_creation_completed(character: Character)
signal resources_initialized(resources: Dictionary)
signal campaign_creation_completed(campaign: Campaign)

enum CreationStep {
	CAMPAIGN_CONFIG,
	CREW_CREATION,
	CAPTAIN_CREATION,
	RESOURCE_SETUP,
	FINAL_SETUP
}

var current_step: CreationStep = CreationStep.CAMPAIGN_CONFIG
var campaign_config: Dictionary = {}
var crew_data: Array = []
var captain_data: Character
var initial_resources: Dictionary = {}

var game_state: GameState
var save_manager: SaveManager

func _init() -> void:
	game_state = GameState.new()
	save_manager = SaveManager.new()
	add_child(game_state)
	add_child(save_manager)

# Campaign Creation Flow
func start_campaign_creation() -> void:
	current_step = CreationStep.CAMPAIGN_CONFIG
	_reset_creation_data()
	creation_step_changed.emit(current_step)

func submit_campaign_config(config: Dictionary) -> void:
	campaign_config = config
	campaign_config_completed.emit(config)
	advance_to_next_step()

func submit_crew_data(crew: Array) -> void:
	crew_data = crew
	crew_creation_completed.emit(crew)
	advance_to_next_step()

func submit_captain_data(captain: Character) -> void:
	captain_data = captain
	character_creation_completed.emit(captain)
	advance_to_next_step()

func initialize_resources(difficulty: int) -> void:
	initial_resources = _calculate_initial_resources(difficulty)
	resources_initialized.emit(initial_resources)
	advance_to_next_step()

func finalize_campaign_creation() -> Campaign:
	var campaign = Campaign.new()
	
	# Configure campaign with collected data
	var complete_config = {
		"name": campaign_config.get("name", "New Campaign"),
		"difficulty": campaign_config.get("difficulty", GameEnums.DifficultyLevel.NORMAL),
		"starting_credits": initial_resources.get(GameEnums.ResourceType.CREDITS, 1000),
		"starting_supplies": initial_resources.get(GameEnums.ResourceType.SUPPLIES, 5),
		"crew": crew_data,
		"captain": captain_data
	}
	
	campaign.start_campaign(complete_config)
	
	# Initialize game state with new campaign
	game_state.start_new_campaign(campaign)
	
	# Auto-save the initial campaign state
	var save_data = game_state.save_campaign()
	save_manager.save_game(save_data)
	
	campaign_creation_completed.emit(campaign)
	
	return campaign

func advance_to_next_step() -> void:
	match current_step:
		CreationStep.CAMPAIGN_CONFIG:
			current_step = CreationStep.CREW_CREATION
		CreationStep.CREW_CREATION:
			current_step = CreationStep.CAPTAIN_CREATION
		CreationStep.CAPTAIN_CREATION:
			current_step = CreationStep.RESOURCE_SETUP
		CreationStep.RESOURCE_SETUP:
			current_step = CreationStep.FINAL_SETUP
		CreationStep.FINAL_SETUP:
			# Creation complete
			pass
	
	creation_step_changed.emit(current_step)

func _reset_creation_data() -> void:
	campaign_config.clear()
	crew_data.clear()
	captain_data = null
	initial_resources.clear()

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
		CreationStep.CAPTAIN_CREATION:
			return _validate_captain_data()
		CreationStep.RESOURCE_SETUP:
			return _validate_resources()
		CreationStep.FINAL_SETUP:
			return true
	return false

func _validate_campaign_config() -> bool:
	return campaign_config.has("name") and campaign_config.has("difficulty")

func _validate_crew_data() -> bool:
	return crew_data.size() >= 4 and crew_data.size() <= 6

func _validate_captain_data() -> bool:
	return captain_data != null

func _validate_resources() -> bool:
	return not initial_resources.is_empty()