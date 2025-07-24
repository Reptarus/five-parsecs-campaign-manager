class_name FPCM_VictoryOption
extends Control

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")

# Victory Condition Types
enum VictoryConditionType {
	ELIMINATION,
	EXTRACTION,
	DEFENSE,
	ESCORT,
	RECOVERY,
	INFILTRATION,
	SABOTAGE,
	ASSASSINATION,
	PATROL,
	EXPLORATION,
	TIME_LIMIT,
	OBJECTIVE_BASED
}

signal value_changed(condition: GlobalEnums.FiveParsecsCampaignVictoryType)

@onready var option_button: Button = get_node_or_null("OptionButton")
@onready var tooltip: Label = get_node_or_null("Tooltip")

var current_condition: GlobalEnums.FiveParsecsCampaignVictoryType = GlobalEnums.FiveParsecsCampaignVictoryType.WEALTH_GOAL

func _ready() -> void:
	if option_button:
		option_button.pressed.connect(_on_option_button_pressed)
	else:
		push_warning("VictoryOption: OptionButton node not found")

func setup(condition: GlobalEnums.FiveParsecsCampaignVictoryType, tooltip_text: String) -> void:
	current_condition = condition
	if option_button:
		option_button.text = GlobalEnums.FiveParsecsCampaignVictoryType.keys()[condition]
	if tooltip:
		tooltip.text = tooltip_text

func _on_option_button_pressed() -> void:
	value_changed.emit(current_condition)
