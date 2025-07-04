class_name FPCM_DifficultyOption
extends Control

signal value_changed(difficulty: GameEnums.DifficultyLevel)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var option_button: OptionButton = get_node_or_null("OptionButton")
var current_difficulty: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL

func _ready() -> void:
	if option_button:
		_setup_options()
		_connect_signals()
	else:
		push_warning("DifficultyOption: OptionButton node not found")

func setup(difficulty: GameEnums.DifficultyLevel, tooltip_text: String) -> void:
	current_difficulty = difficulty
	if option_button:
		option_button.text = GameEnums.DifficultyLevel.keys()[difficulty]
		option_button.tooltip_text = tooltip_text

func _setup_options() -> void:
	if not option_button:
		return
	option_button.clear()
	option_button.add_item("Easy", GameEnums.DifficultyLevel.EASY)
	option_button.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
	option_button.add_item("Hard", GameEnums.DifficultyLevel.HARD)
	option_button.add_item("Hardcore", GameEnums.DifficultyLevel.HARDCORE)
	option_button.add_item("Elite", GameEnums.DifficultyLevel.ELITE)

func _connect_signals() -> void:
	if option_button:
		option_button.item_selected.connect(_on_option_selected)
func get_difficulty() -> GameEnums.DifficultyLevel:
	return current_difficulty

func set_difficulty(difficulty: GameEnums.DifficultyLevel) -> void:
	current_difficulty = difficulty
	if option_button:
		option_button.select(difficulty)

func _on_option_selected(index: int) -> void:
	current_difficulty = index
	value_changed.emit(current_difficulty)