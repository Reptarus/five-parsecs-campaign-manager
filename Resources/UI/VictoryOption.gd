class_name VictoryOption
extends Control

signal value_changed(condition: GlobalEnums.VictoryConditionType)

@onready var option_button := $OptionButton
@onready var tooltip := $TooltipLabel

var current_condition: GlobalEnums.VictoryConditionType

func _ready() -> void:
    option_button.pressed.connect(_on_option_pressed)
    tooltip.visible = false

func setup(condition: GlobalEnums.VictoryConditionType, tooltip_text: String) -> void:
    current_condition = condition
    option_button.text = GlobalEnums.VictoryConditionType.keys()[condition]
    tooltip.text = tooltip_text

func _on_option_pressed() -> void:
    value_changed.emit(current_condition)

func _on_mouse_entered() -> void:
    tooltip.visible = true

func _on_mouse_exited() -> void:
    tooltip.visible = false 