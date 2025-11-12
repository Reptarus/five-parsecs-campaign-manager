extends Control

# GlobalEnums available as autoload singleton

@onready var difficulty_option: Button = $"VBoxContainer/DifficultyOption"
@onready var permadeath_toggle: Button = $"VBoxContainer/PermadeathToggle"
@onready var story_track_toggle: Button = $"VBoxContainer/StoryTrackToggle"
@onready var start_button: Button = $"VBoxContainer/StartButton"

signal campaign_started(config: Dictionary)

func _ready() -> void:
	_setup_difficulty_options()
	_connect_signals()
	_update_ui_state()

func _setup_difficulty_options() -> void:
	difficulty_option.clear()
	difficulty_option.add_item("Story", GlobalEnums.DifficultyLevel.STORY)
	difficulty_option.add_item("Standard", GlobalEnums.DifficultyLevel.STANDARD)
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	difficulty_option.add_item("Nightmare", GlobalEnums.DifficultyLevel.NIGHTMARE)
	difficulty_option.select(GlobalEnums.DifficultyLevel.STANDARD)

func _connect_signals() -> void:
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	permadeath_toggle.toggled.connect(_on_permadeath_toggled)
	story_track_toggle.toggled.connect(_on_story_track_toggled)
	start_button.pressed.connect(_on_start_pressed)

func _update_ui_state() -> void:
	var difficulty_index = difficulty_option.get_selected_id()
	if difficulty_index == GlobalEnums.DifficultyLevel.HARDCORE or difficulty_index == GlobalEnums.DifficultyLevel.NIGHTMARE:
		permadeath_toggle.button_pressed = true
		permadeath_toggle.disabled = true
	else:
		permadeath_toggle.disabled = false

func _get_difficulty_description(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			return "Casual play with reduced difficulty for learning."
		GlobalEnums.DifficultyLevel.STANDARD:
			return "Core rules as written - the classic experience."
		GlobalEnums.DifficultyLevel.CHALLENGING:
			return "Increased enemy strength and tougher encounters."
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Maximum difficulty with elite enemies. Permadeath enabled."
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return "Custom ultra-hard mode. The ultimate challenge with permadeath."
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
	return GlobalEnums.DifficultyLevel.keys()[difficulty]
