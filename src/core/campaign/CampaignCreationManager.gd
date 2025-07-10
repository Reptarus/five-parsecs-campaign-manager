@tool
@warning_ignore("return_value_discarded")
@warning_ignore("unsafe_method_access")
@warning_ignore("untyped_declaration")
extends Node
class_name CampaignCreationManager

## Campaign Creation Manager for Five Parsecs from Home
## Manages the step-by-step campaign creation process

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterBase = preload("res://src/core/character/Base/Character.gd")

# Dynamic loading to avoid circular dependencies
var FiveParcsecsCampaign: Variant = null
var SaveManager: Variant = null

signal creation_step_changed(step: int)
signal campaign_config_completed(config: Dictionary)
signal crew_creation_completed(crew_data: Array[Dictionary])
signal character_creation_completed(character: Character)
signal resources_initialized(resources: Dictionary)
signal campaign_creation_completed(campaign)
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
var game_state: Node = null # Injected via setup()
var save_manager: Variant = null

func _init() -> void:
	name = "CampaignCreationManager"
	_initialize_campaign_data()
	_load_dependencies()

func _load_dependencies() -> void:
	"""Load dependencies dynamically to avoid circular references"""
	# Try to load Campaign class
	var campaign_path = "res://src/core/campaign/Campaign.gd"
	if FileAccess.file_exists(campaign_path):
		FiveParcsecsCampaign = load(campaign_path)
	else:
		# Try alternative path
		campaign_path = "res://src/game/campaign/FiveParsecsCampaign.gd"
		if FileAccess.file_exists(campaign_path):
			FiveParcsecsCampaign = load(campaign_path)
		else:
			push_warning("CampaignCreationManager: Campaign class not found")

	# Try to load SaveManager
	var save_path: String = "res://src/core/state/SaveManager.gd"
	if FileAccess.file_exists(save_path):
		SaveManager = load(save_path)
		if SaveManager:
			save_manager = SaveManager.new()
	else:
		push_warning("CampaignCreationManager: SaveManager class not found")

func _ready() -> void:
	print("CampaignCreationManager: Initializing...")
	reset_creation()

func setup(state: Node) -> void:
	"""Setup with external dependencies"""
	game_state = state
	print("CampaignCreationManager: Setup complete with game state")

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
			creation_errors.append("Invalid creation step")
			return false

func _validate_config() -> bool:
	if not campaign_data.config.has("name"):
		creation_errors.append("Campaign name is required")
		return false
	if not campaign_data.config.has("difficulty"):
		creation_errors.append("Difficulty level is required")
		return false
	return true

func _validate_crew() -> bool:
	if campaign_data.crew.size() < 4:
		creation_errors.append("Minimum 4 crew members required")
		return false
	if campaign_data.crew.size() > 6:
		creation_errors.append("Maximum 6 crew members allowed")
		return false
	return true

func _validate_captain() -> bool:
	if campaign_data.captain.is_empty():
		creation_errors.append("Captain data is required")
		return false
	if not campaign_data.captain.has("name"):
		creation_errors.append("Captain must have a name")
		return false
	return true

func _validate_resources() -> bool:
	if campaign_data.resources.is_empty():
		creation_errors.append("Resource data is required")
		return false
	return true

func _validate_final() -> bool:
	# Validate all steps
	var config_valid = _validate_config()
	var crew_valid = _validate_crew()
	var captain_valid = _validate_captain()
	var resources_valid = _validate_resources()

	return config_valid and crew_valid and captain_valid and resources_valid

func set_config_data(config: Dictionary) -> void:
	campaign_data.config = config.duplicate(true)
	campaign_config_completed.emit(campaign_data.config)

func set_crew_data(crew: Array) -> void:
	campaign_data.crew = crew.duplicate(true)
	crew_creation_completed.emit(campaign_data.crew)

func set_captain_data(captain: Dictionary) -> void:
	campaign_data.captain = captain.duplicate(true)
	if captain.has("character_object") and captain.character_object is Character:
		character_creation_completed.emit(captain.character_object)

func set_resource_data(resources: Dictionary) -> void:
	campaign_data.resources = resources.duplicate(true)
	resources_initialized.emit(campaign_data.resources)

func finalize_campaign_creation():
	"""Create and return the final campaign object"""
	if not _validate_all_steps():
		push_error("CampaignCreationManager: Cannot finalize - validation failed")
		return null

	if not FiveParcsecsCampaign:
		push_error("CampaignCreationManager: Campaign class not available")
		return null

	var campaign: Resource = FiveParcsecsCampaign.new()

	# Configure the campaign with our data
	if campaign and campaign.has_method("configure"):
		campaign.configure(campaign_data.config)
	elif campaign and campaign.has_method("set_config"):
		campaign.set_config(campaign_data.config)
	else:
		push_warning("CampaignCreationManager: Campaign doesn't support configuration")

	# Set additional data if methods exist
	if campaign.has_method("set_crew") and not campaign_data.crew.is_empty():
		campaign.set_crew(campaign_data.crew)

	if campaign.has_method("set_captain") and not campaign_data.captain.is_empty():
		campaign.set_captain(campaign_data.captain)

	if campaign.has_method("set_resources") and not campaign_data.resources.is_empty():
		campaign.set_resources(campaign_data.resources)

	print("CampaignCreationManager: Campaign creation finalized")
	return campaign

func _validate_all_steps() -> bool:
	creation_errors.clear()
	var valid: bool = true

	var original_step = current_step

	for step in CreationStep.values():
		current_step = step
		if not _validate_current_step():
			valid = false

	current_step = original_step
	return valid

func _finalize_creation() -> void:
	var final_campaign = finalize_campaign_creation()
	if final_campaign:
		campaign_creation_completed.emit(final_campaign)
		print("CampaignCreationManager: Creation completed successfully")
	else:
		push_error("CampaignCreationManager: Failed to create campaign")
		validation_failed.emit(["Failed to create campaign object"])

func get_campaign_data() -> Dictionary:
	return campaign_data.duplicate(true)

func reset_creation() -> void:
	current_step = CreationStep.CONFIG
	_initialize_campaign_data()
	creation_errors.clear()
	creation_step_changed.emit(current_step)
	print("CampaignCreationManager: Creation reset")

func set_campaign_config(config: Dictionary) -> void:
	campaign_data.config = config.duplicate()
	campaign_config_completed.emit(campaign_data.config)

func set_initial_resources(resources: Dictionary) -> void:
	campaign_data.resources = resources.duplicate()
	resources_initialized.emit(campaign_data.resources)

func submit_captain_data(captain: Character) -> void:
	campaign_data.captain = {
		"character_object": captain,
		"name": captain.character_name if captain.has("character_name") else "Captain"
	}
	character_creation_completed.emit(captain)
	advance_step()

func initialize_resources(difficulty: int) -> void:
	campaign_data.resources = _calculate_initial_resources(difficulty)
	resources_initialized.emit(campaign_data.resources)
	advance_step()

func _calculate_initial_resources(difficulty: int) -> Dictionary:
	var resources = {
		GlobalEnums.ResourceType.CREDITS: 1000,
		GlobalEnums.ResourceType.SUPPLIES: 5,
		GlobalEnums.ResourceType.TECH_PARTS: 0,
		GlobalEnums.ResourceType.PATRON: 0
	}

	# Adjust based on difficulty
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			resources[GlobalEnums.ResourceType.CREDITS] = 1200
			resources[GlobalEnums.ResourceType.SUPPLIES] = 7
		GlobalEnums.DifficultyLevel.HARD:
			resources[GlobalEnums.ResourceType.CREDITS] = 800
			resources[GlobalEnums.ResourceType.SUPPLIES] = 3
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			resources[GlobalEnums.ResourceType.CREDITS] = 500
			resources[GlobalEnums.ResourceType.SUPPLIES] = 2

	return resources
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null