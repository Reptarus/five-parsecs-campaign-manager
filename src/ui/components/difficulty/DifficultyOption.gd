# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/components/difficulty/DifficultyOption.gd")

signal value_changed(difficulty: GameEnums.DifficultyLevel)

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var option_button = $OptionButton
var current_difficulty: GameEnums.DifficultyLevel

func _ready() -> void:
    _setup_options()
    _connect_signals()

func setup(difficulty: GameEnums.DifficultyLevel, tooltip_text: String) -> void:
    current_difficulty = difficulty
    option_button.text = GameEnums.DifficultyLevel.keys()[difficulty]
    option_button.tooltip_text = tooltip_text

func _setup_options() -> void:
    option_button.clear()
    option_button.add_item("Easy", GameEnums.DifficultyLevel.EASY)
    option_button.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
    option_button.add_item("Hard", GameEnums.DifficultyLevel.HARD)
    option_button.add_item("Hardcore", GameEnums.DifficultyLevel.HARDCORE)
    option_button.add_item("Elite", GameEnums.DifficultyLevel.ELITE)

func _connect_signals() -> void:
    option_button.item_selected.connect(_on_option_selected)

func get_difficulty() -> GameEnums.DifficultyLevel:
    return current_difficulty

func set_difficulty(difficulty: GameEnums.DifficultyLevel) -> void:
    current_difficulty = difficulty
    option_button.text = GameEnums.DifficultyLevel.keys()[difficulty]

func _on_option_selected(index: int) -> void:
    current_difficulty = index
    value_changed.emit(current_difficulty)