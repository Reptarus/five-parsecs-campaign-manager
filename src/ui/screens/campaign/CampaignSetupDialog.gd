extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var difficulty_option = $VBoxContainer/DifficultyOption
@onready var permadeath_toggle = $VBoxContainer/PermadeathToggle
@onready var story_track_toggle = $VBoxContainer/StoryTrackToggle
@onready var start_button = $VBoxContainer/StartButton

signal campaign_started(config: Dictionary)

func _ready() -> void:
	_setup_difficulty_options()
	_connect_signals()
	_update_ui_state()

func _setup_difficulty_options() -> void:
	difficulty_option.clear()
	difficulty_option.add_item("Easy", GameEnums.DifficultyLevel.EASY)
	difficulty_option.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
	difficulty_option.add_item("Hard", GameEnums.DifficultyLevel.HARD)
	difficulty_option.add_item("Veteran", GameEnums.DifficultyLevel.VETERAN)
	difficulty_option.add_item("Elite", GameEnums.DifficultyLevel.ELITE)
	difficulty_option.select(GameEnums.DifficultyLevel.NORMAL)

func _connect_signals() -> void:
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	permadeath_toggle.toggled.connect(_on_permadeath_toggled)
	story_track_toggle.toggled.connect(_on_story_track_toggled)
	start_button.pressed.connect(_on_start_pressed)

func _update_ui_state() -> void:
	var difficulty_index = difficulty_option.get_selected_id()
	if difficulty_index == GameEnums.DifficultyLevel.VETERAN or difficulty_index == GameEnums.DifficultyLevel.ELITE:
		permadeath_toggle.button_pressed = true
		permadeath_toggle.disabled = true
	else:
		permadeath_toggle.disabled = false

func _get_difficulty_description(difficulty: int) -> String:
	match difficulty:
		GameEnums.DifficultyLevel.EASY:
			return "Reduced enemy count and easier combat."
		GameEnums.DifficultyLevel.NORMAL:
			return "Standard difficulty with balanced challenges."
		GameEnums.DifficultyLevel.HARD:
			return "More enemies and tougher combat encounters."
		GameEnums.DifficultyLevel.VETERAN:
			return "Significantly harder with elite enemies. Permadeath enabled."
		GameEnums.DifficultyLevel.ELITE:
			return "The ultimate challenge. Elite enemies and permadeath."
		_:
			return "Unknown difficulty level"

func _on_difficulty_changed(index: int) -> void:
	var description = _get_difficulty_description(index)
	difficulty_option.tooltip_text = description
	_update_ui_state()

func _on_permadeath_toggled(enabled: bool) -> void:
	pass

func _on_story_track_toggled(enabled: bool) -> void:
	pass

func _on_start_pressed() -> void:
	var config = {
		"difficulty": difficulty_option.get_selected_id(),
		"permadeath": permadeath_toggle.button_pressed,
		"story_track": story_track_toggle.button_pressed
	}
	campaign_started.emit(config)

func get_difficulty_name(difficulty: int) -> String:
	return GameEnums.DifficultyLevel.keys()[difficulty]