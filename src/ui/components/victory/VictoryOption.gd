# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self = preload("res://src/ui/components/victory/VictoryOption.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal value_changed(condition: GameEnums.FiveParcsecsCampaignVictoryType)

@onready var option_button: Button = $OptionButton
@onready var tooltip: Label = $Tooltip

var current_condition: GameEnums.FiveParcsecsCampaignVictoryType

func _ready() -> void:
	option_button.connect("pressed", _on_option_button_pressed)

func setup(condition: GameEnums.FiveParcsecsCampaignVictoryType, tooltip_text: String) -> void:
	current_condition = condition
	option_button.text = GameEnums.FiveParcsecsCampaignVictoryType.keys()[condition]
	tooltip.text = tooltip_text

func _on_option_button_pressed() -> void:
	value_changed.emit(current_condition)