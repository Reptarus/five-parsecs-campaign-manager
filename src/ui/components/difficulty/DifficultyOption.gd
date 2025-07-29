class_name FPCM_DifficultyOption
extends Control

signal value_changed(difficulty: GlobalEnums.DifficultyLevel)

# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

# Difficulty Level Constants
const DIFFICULTY_STORY = 0
const DIFFICULTY_STANDARD = 1
const DIFFICULTY_CHALLENGING = 2
const DIFFICULTY_HARDCORE = 3
const DIFFICULTY_NIGHTMARE = 4

@onready var option_button: OptionButton = get_node_or_null("OptionButton")
var current_difficulty: GlobalEnums.DifficultyLevel = GlobalEnums.DifficultyLevel.STANDARD

func _ready() -> void:
	if option_button:
		option_button.item_selected.connect(_on_difficulty_selected)
		_setup_difficulty_options()
	else:
		push_warning("DifficultyOption: OptionButton node not found")

func setup(difficulty: GlobalEnums.DifficultyLevel, tooltip_text: String) -> void:
	current_difficulty = difficulty
	if option_button:
		option_button.text = GlobalEnums.DifficultyLevel.keys()[difficulty]
		option_button.tooltip_text = tooltip_text

func _setup_difficulty_options() -> void:
	if not option_button:
		return

	option_button.clear()
	option_button.add_item("Story Mode", GlobalEnums.DifficultyLevel.STORY)
	option_button.add_item("Standard", GlobalEnums.DifficultyLevel.STANDARD)
	option_button.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING)
	option_button.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	option_button.add_item("Nightmare", GlobalEnums.DifficultyLevel.NIGHTMARE)

	# Set default selection
	option_button.select(GlobalEnums.DifficultyLevel.STANDARD)

func _connect_signals() -> void:
	if option_button:
		option_button.item_selected.connect(_on_difficulty_selected)

func _on_difficulty_selected(index: int) -> void:
	var selected_difficulty = option_button.get_item_id(index)
	value_changed.emit(selected_difficulty)

func get_difficulty() -> GlobalEnums.DifficultyLevel:
	return current_difficulty

func set_difficulty(difficulty: GlobalEnums.DifficultyLevel) -> void:
	current_difficulty = difficulty
	if option_button:
		option_button.select(difficulty)