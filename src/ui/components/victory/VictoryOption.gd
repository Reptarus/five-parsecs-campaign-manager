# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control
signal value_changed(condition: GlobalEnums.FiveParcsecsCampaignVictoryType)

@onready var option_button: Button = $OptionButton
@onready var tooltip: Label = $Tooltip

var current_condition: GlobalEnums.FiveParcsecsCampaignVictoryType

func _ready() -> void:
	option_button.connect("pressed", _on_option_button_pressed)

func setup(condition: GlobalEnums.FiveParcsecsCampaignVictoryType, tooltip_text: String) -> void:
	current_condition = condition
	option_button.text = GlobalEnums.FiveParcsecsCampaignVictoryType.keys()[condition]
	tooltip.text = tooltip_text

func _on_option_button_pressed() -> void:
	value_changed.emit(current_condition)