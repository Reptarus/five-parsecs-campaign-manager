class_name DifficultyOption
extends Control

signal value_changed(difficulty: GlobalEnums.DifficultyMode)

@onready var option_button := $OptionButton
@onready var tooltip := $TooltipLabel

var current_difficulty: GlobalEnums.DifficultyMode

func _ready() -> void:
    option_button.pressed.connect(_on_option_pressed)
    tooltip.visible = false

func setup(difficulty: GlobalEnums.DifficultyMode, tooltip_text: String) -> void:
    current_difficulty = difficulty
    option_button.text = GlobalEnums.DifficultyMode.keys()[difficulty]
    tooltip.text = tooltip_text

func _on_option_pressed() -> void:
    value_changed.emit(current_difficulty)

func _on_mouse_entered() -> void:
    tooltip.visible = true

func _on_mouse_exited() -> void:
    tooltip.visible = false

func get_difficulty() -> GlobalEnums.DifficultyMode:
    return current_difficulty

func set_difficulty(difficulty: GlobalEnums.DifficultyMode) -> void:
    current_difficulty = difficulty
    option_button.text = GlobalEnums.DifficultyMode.keys()[difficulty]
    value_changed.emit(difficulty) 