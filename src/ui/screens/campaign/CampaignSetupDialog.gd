extends Control

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

signal setup_completed(config: Dictionary)
signal setup_cancelled

@onready var crew_size_spin_box := $Panel/MarginContainer/VBoxContainer/SettingsContainer/CrewSizeSpinBox
@onready var difficulty_option := $Panel/MarginContainer/VBoxContainer/SettingsContainer/DifficultyOptionButton
@onready var victory_option := $Panel/MarginContainer/VBoxContainer/SettingsContainer/VictoryOptionButton
@onready var story_track_check := $Panel/MarginContainer/VBoxContainer/SettingsContainer/StoryTrackCheckBox
@onready var permadeath_check := $Panel/MarginContainer/VBoxContainer/SettingsContainer/PermadeathCheckBox
@onready var starting_credits_spin := $Panel/MarginContainer/VBoxContainer/SettingsContainer/StartingCreditsSpinBox
@onready var back_button := $Panel/MarginContainer/VBoxContainer/ButtonContainer/BackButton
@onready var start_button := $Panel/MarginContainer/VBoxContainer/ButtonContainer/StartButton

var campaign_manager: GameCampaignManager

func _ready() -> void:
	campaign_manager = get_node("/root/CampaignManager")
	if not campaign_manager:
		push_error("CampaignManager not found")
		queue_free()
		return
	
	_connect_signals()
	_initialize_ui()

func _connect_signals() -> void:
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	victory_option.item_selected.connect(_on_victory_changed)
	
	# Update permadeath based on difficulty
	difficulty_option.item_selected.connect(_update_permadeath_state)

func _initialize_ui() -> void:
	# Set default values
	crew_size_spin_box.value = GameEnums.CrewSize.FOUR
	difficulty_option.select(GameEnums.DifficultyMode.NORMAL) # Normal difficulty
	victory_option.select(0) # 20 turns
	story_track_check.button_pressed = true
	permadeath_check.button_pressed = false
	starting_credits_spin.value = 1000
	
	# Update initial permadeath state
	_update_permadeath_state(difficulty_option.selected)

func _update_permadeath_state(difficulty_index: int) -> void:
	# Force permadeath on Hardcore and Insanity modes
	if difficulty_index == GameEnums.DifficultyMode.HARDCORE or difficulty_index == GameEnums.DifficultyMode.INSANITY:
		permadeath_check.button_pressed = true
		permadeath_check.disabled = true
	else:
		permadeath_check.disabled = false

func _on_difficulty_changed(index: int) -> void:
	# Adjust starting credits based on difficulty
	match index:
		GameEnums.DifficultyMode.EASY:
			starting_credits_spin.value = 1500
		GameEnums.DifficultyMode.NORMAL:
			starting_credits_spin.value = 1000
		GameEnums.DifficultyMode.CHALLENGING:
			starting_credits_spin.value = 800
		GameEnums.DifficultyMode.HARDCORE:
			starting_credits_spin.value = 600
		GameEnums.DifficultyMode.INSANITY:
			starting_credits_spin.value = 500

func _on_victory_changed(_index: int) -> void:
	# Additional victory condition logic can be added here
	pass

func _on_back_pressed() -> void:
	setup_cancelled.emit()
	queue_free()

func _on_start_pressed() -> void:
	var config := {
		"crew_size": crew_size_spin_box.value,
		"difficulty_mode": difficulty_option.selected,
		"victory_condition": victory_option.selected,
		"use_story_track": story_track_check.button_pressed,
		"enable_permadeath": permadeath_check.button_pressed,
		"starting_credits": starting_credits_spin.value,
		"enable_tutorial": true # Can be made configurable if needed
	}
	
	setup_completed.emit(config)
	queue_free()

func get_difficulty_name(difficulty: int) -> String:
	return GameEnums.DifficultyMode.keys()[difficulty]

func get_victory_condition_name(condition: int) -> String:
	return GameEnums.CampaignVictoryType.keys()[condition]