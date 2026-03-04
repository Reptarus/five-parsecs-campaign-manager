extends Control
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
	difficulty_option.add_item("Easy", GlobalEnums.DifficultyLevel.EASY)
	difficulty_option.add_item("Normal", GlobalEnums.DifficultyLevel.NORMAL)
	difficulty_option.add_item("Hard", GlobalEnums.DifficultyLevel.HARD)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	difficulty_option.add_item("Elite", GlobalEnums.DifficultyLevel.ELITE)
	difficulty_option.select(GlobalEnums.DifficultyLevel.NORMAL)

func _connect_signals() -> void:
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	start_button.pressed.connect(_on_start_pressed)

func _update_ui_state() -> void:
	var difficulty_index = difficulty_option.get_selected_id()
	if difficulty_index == GlobalEnums.DifficultyLevel.HARDCORE or difficulty_index == GlobalEnums.DifficultyLevel.ELITE:
		permadeath_toggle.button_pressed = true
		permadeath_toggle.disabled = true
	else:
		permadeath_toggle.disabled = false

func _get_difficulty_description(difficulty: int) -> String:
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			return "Reduced enemy count and easier combat."
		GlobalEnums.DifficultyLevel.NORMAL:
			return "Standard difficulty with balanced challenges."
		GlobalEnums.DifficultyLevel.HARD:
			return "More enemies and tougher combat encounters."
		GlobalEnums.DifficultyLevel.HARDCORE:
			return "Significantly harder with elite enemies. Permadeath enabled."
		GlobalEnums.DifficultyLevel.ELITE:
			return "The ultimate challenge. Elite enemies and permadeath."
		_:
			return "Unknown difficulty level"

func _on_difficulty_changed(index: int) -> void:
	var description = _get_difficulty_description(index)
	difficulty_option.tooltip_text = description
	_update_ui_state()


func _on_start_pressed() -> void:
	var config = {
		"difficulty": difficulty_option.get_selected_id(),
		"permadeath": permadeath_toggle.button_pressed,
		"story_track": story_track_toggle.button_pressed
	}
	campaign_started.emit(config)

func get_difficulty_name(difficulty: int) -> String:
	return GlobalEnums.DifficultyLevel.keys()[difficulty]