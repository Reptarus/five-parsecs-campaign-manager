extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")

signal game_state_changed(new_state: int)
signal campaign_phase_changed(new_phase: int)
signal difficulty_changed(new_difficulty: int)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)

@export var initial_credits: int = 1000
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0

var game_state: GameState = null
var campaign_phase: int = 0 # Using 0 as default (equivalent to NONE)
var difficulty_level: int = GameEnums.DifficultyLevel.NORMAL
var credits: int = initial_credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0

# Settings
var enable_tutorials: bool = true
var auto_save_enabled: bool = true
var language: String = "English"

func _ready() -> void:
	# Initialize with default values
	set_credits(initial_credits)
	set_supplies(initial_supplies)
	set_reputation(initial_reputation)
	set_story_progress(0)

# State management
func set_game_state(new_state: GameState) -> void:
	if game_state != new_state:
		game_state = new_state
		game_state_changed.emit(game_state)

func set_campaign_phase(new_phase: int) -> void:
	if campaign_phase != new_phase:
		campaign_phase = new_phase
		campaign_phase_changed.emit(campaign_phase)

func set_difficulty(new_difficulty: int) -> void:
	if difficulty_level != new_difficulty:
		difficulty_level = new_difficulty
		difficulty_changed.emit(difficulty_level)

# Settings management
func set_tutorials_enabled(enabled: bool) -> void:
	enable_tutorials = enabled
	
func set_auto_save_enabled(enabled: bool) -> void:
	auto_save_enabled = enabled
	
func set_language(language_name: String) -> void:
	language = language_name
	# You might want to emit a signal or perform additional actions here

# Resource management
func set_credits(new_amount: int) -> void:
	if credits != new_amount:
		credits = new_amount
		credits_changed.emit(credits)

func set_supplies(new_amount: int) -> void:
	if supplies != new_amount:
		supplies = new_amount
		supplies_changed.emit(supplies)

func set_reputation(new_amount: int) -> void:
	if reputation != new_amount:
		reputation = new_amount
		reputation_changed.emit(reputation)

func set_story_progress(new_amount: int) -> void:
	if story_progress != new_amount:
		story_progress = new_amount
		story_progress_changed.emit(story_progress)

# Getters
func get_game_state() -> GameState:
	return game_state

func get_campaign_phase() -> int:
	return campaign_phase

func get_difficulty() -> int:
	return difficulty_level

func get_credits() -> int:
	return credits

func get_supplies() -> int:
	return supplies

func get_reputation() -> int:
	return reputation

func get_story_progress() -> int:
	return story_progress

# Save/load settings
func save_settings() -> void:
	# This would save the settings to a file or other storage
	pass
	
func load_settings() -> void:
	# This would load the settings from a file or other storage
	pass
