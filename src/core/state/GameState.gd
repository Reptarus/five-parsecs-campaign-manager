class_name GameState
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Campaign = preload("res://src/core/campaign/Campaign.gd")
const SaveManager = preload("res://src/core/managers/SaveManager.gd")

signal state_changed
signal campaign_loaded(campaign: Campaign)
signal campaign_saved
signal save_started
signal save_completed(success: bool, message: String)
signal load_started
signal load_completed(success: bool, message: String)

var current_campaign: Campaign
var active_save_slot: int = 0
var last_save_time: int = 0
var campaign_turn: int = 0
var credits: int = 0
var reputation: int = 0

# Game settings
var difficulty_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
var enable_permadeath: bool = true
var use_story_track: bool = true
var auto_save_enabled: bool = true

# Manager references
var save_manager: SaveManager

func _ready() -> void:
	save_manager = get_node("/root/SaveManager")
	if save_manager:
		save_manager.save_completed.connect(_on_save_manager_save_completed)
		save_manager.load_completed.connect(_on_save_manager_load_completed)

func start_new_campaign(campaign: Campaign) -> void:
	current_campaign = campaign
	campaign_turn = 1
	credits = campaign.starting_credits
	reputation = campaign.starting_reputation
	state_changed.emit()
	
	if auto_save_enabled:
		_auto_save()

func load_campaign(save_data: Dictionary) -> void:
	load_started.emit()
	
	if not save_data.has("campaign"):
		push_error("No campaign data in save file")
		load_completed.emit(false, "No campaign data in save file")
		return
	
	var campaign_data = save_data.campaign
	current_campaign = Campaign.new()
	current_campaign.from_dictionary(campaign_data)
	
	# Load game state
	campaign_turn = save_data.get("campaign_turn", 1)
	credits = save_data.get("credits", 0)
	reputation = save_data.get("reputation", 0)
	last_save_time = save_data.get("last_save_time", 0)
	
	# Load game settings
	difficulty_level = save_data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	enable_permadeath = save_data.get("enable_permadeath", true)
	use_story_track = save_data.get("use_story_track", true)
	auto_save_enabled = save_data.get("auto_save_enabled", true)
	
	campaign_loaded.emit(current_campaign)
	state_changed.emit()
	load_completed.emit(true, "Campaign loaded successfully")

func save_campaign() -> Dictionary:
	save_started.emit()
	
	if not current_campaign:
		push_error("No campaign to save")
		save_completed.emit(false, "No campaign to save")
		return {}
	
	var save_data := {
		"campaign": current_campaign.to_dictionary(),
		"campaign_turn": campaign_turn,
		"credits": credits,
		"reputation": reputation,
		"last_save_time": Time.get_unix_time_from_system(),
		"difficulty_level": difficulty_level,
		"enable_permadeath": enable_permadeath,
		"use_story_track": use_story_track,
		"auto_save_enabled": auto_save_enabled
	}
	
	campaign_saved.emit()
	return save_data

func quick_save() -> void:
	if not current_campaign:
		return
		
	var save_name = "quicksave_%d" % campaign_turn
	var save_data = save_campaign()
	save_manager.save_game(save_data, save_name)

func _auto_save() -> void:
	if not current_campaign or not auto_save_enabled:
		return
		
	var save_name = "autosave_%d" % campaign_turn
	var save_data = save_campaign()
	save_manager.save_game(save_data, save_name)

func _on_save_manager_save_completed(success: bool, message: String) -> void:
	if success:
		last_save_time = Time.get_unix_time_from_system()
	save_completed.emit(success, message)

func _on_save_manager_load_completed(success: bool, message: String) -> void:
	load_completed.emit(success, message)

func has_active_campaign() -> bool:
	return current_campaign != null

func end_campaign() -> void:
	if current_campaign and auto_save_enabled:
		_auto_save()
	
	current_campaign = null
	campaign_turn = 0
	credits = 0
	reputation = 0
	state_changed.emit()

func get_campaign() -> Campaign:
	return current_campaign

func advance_turn() -> void:
	campaign_turn += 1
	state_changed.emit()
	
	if auto_save_enabled:
		_auto_save()

func set_difficulty(new_difficulty: GameEnums.DifficultyLevel) -> void:
	difficulty_level = new_difficulty
	state_changed.emit()

func set_permadeath(enabled: bool) -> void:
	enable_permadeath = enabled
	state_changed.emit()

func set_story_track(enabled: bool) -> void:
	use_story_track = enabled
	state_changed.emit()

func set_auto_save(enabled: bool) -> void:
	auto_save_enabled = enabled
	state_changed.emit()

func modify_credits(amount: int) -> void:
	credits += amount
	state_changed.emit()

func modify_reputation(amount: int) -> void:
	reputation += amount
	state_changed.emit()