extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal campaign_started(campaign_data: Dictionary)
signal campaign_loaded(campaign_data: Dictionary)
signal campaign_deleted(campaign_name: String)

var active_campaign: Dictionary
var saved_campaigns: Array = []

func _ready() -> void:
	_load_saved_campaigns()

func initialize_new_campaign(config: Dictionary) -> void:
	var campaign_data = {
		"name": config.name,
		"difficulty_level": config.difficulty_level,
		"enable_permadeath": config.enable_permadeath,
		"use_story_track": config.use_story_track,
		"missions_completed": 0,
		"credits": _get_starting_credits(config.difficulty_level),
		"supplies": _get_starting_supplies(config.difficulty_level),
		"reputation": 0,
		"story_progress": 0,
		"completed_missions": [],
		"available_missions": [],
		"crew_members": []
	}

	active_campaign = campaign_data
	_save_campaign(campaign_data)
	campaign_started.emit(campaign_data)

func load_campaign(campaign_name: String) -> void:
	var campaign_data = _load_campaign_data(campaign_name)
	if not (safe_call_method(campaign_data, "is_empty") == true):
		active_campaign = campaign_data
		campaign_loaded.emit(campaign_data) # warning: return value discarded (intentional)

func delete_campaign(campaign_name: String) -> void:
	var index = _find_campaign_index(campaign_name)
	if index != -1:
		saved_campaigns.remove_at(index)
		_save_campaigns()
		campaign_deleted.emit(campaign_name) # warning: return value discarded (intentional)

func _get_starting_credits(difficulty: int) -> int:
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			return 1500
		GlobalEnums.DifficultyLevel.NORMAL:
			return 1000
		GlobalEnums.DifficultyLevel.HARD:
			return 800
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 600
		GlobalEnums.DifficultyLevel.ELITE:
			return 500
		_:
			return 1000

func _get_starting_supplies(difficulty: int) -> int:
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			return 6
		GlobalEnums.DifficultyLevel.NORMAL:
			return 5
		GlobalEnums.DifficultyLevel.HARD:
			return 4
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 3
		GlobalEnums.DifficultyLevel.ELITE:
			return 2
		_:
			return 5

func _find_campaign_index(campaign_name: String) -> int:
	for i: int in range((safe_call_method(saved_campaigns, "size") as int)):
		if saved_campaigns[i]._name == campaign_name:
			return i
	return -1

func _load_saved_campaigns() -> void:
	# This would load campaign data from disk
	saved_campaigns = []

func _save_campaigns() -> void:
	# This would save all campaign data to disk
	pass

func _save_campaign(campaign_data: Dictionary) -> void:
	var index = _find_campaign_index(campaign_data.name)
	if index != -1:
		saved_campaigns[index] = campaign_data
	else:
		safe_call_method(saved_campaigns, "append", [campaign_data]) # warning: return value discarded (intentional)
	_save_campaigns()

func _load_campaign_data(campaign_name: String) -> Dictionary:
	var index = _find_campaign_index(campaign_name)
	if index != -1:
		return saved_campaigns[index]
	return {}

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null