class_name DifficultyOption
extends Control

signal value_changed(difficulty: int)

@onready var option_button := $OptionButton
@onready var tooltip := $TooltipLabel

var current_difficulty: int = 0

func _ready() -> void:
    _populate_difficulties()
    option_button.item_selected.connect(_on_option_selected)
    tooltip.visible = false

func _populate_difficulties() -> void:
    for i in range(5):
        var text = GlobalEnums.DifficultyMode.keys()[i]
        var tooltip_text = TooltipManager.get_tooltip("difficulty", i)
        option_button.add_item(text, i)

func setup(difficulty: int, tooltip_text: String = "") -> void:
    current_difficulty = difficulty
    option_button.select(difficulty)
    if tooltip_text.is_empty():
        tooltip.text = TooltipManager.get_tooltip("difficulty", difficulty)
    else:
        tooltip.text = tooltip_text

func _on_option_selected(index: int) -> void:
    current_difficulty = index
    value_changed.emit(current_difficulty)

func _on_mouse_entered() -> void:
    tooltip.visible = true
    tooltip.text = TooltipManager.get_tooltip("difficulty", current_difficulty)

func _on_mouse_exited() -> void:
    tooltip.visible = false 