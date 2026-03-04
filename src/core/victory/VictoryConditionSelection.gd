# VictoryConditionSelection.gd
@tool
extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names
signal victory_selected(type: int, data: Dictionary)

# Victory types
var selected_victory_type: int = GlobalEnums.FiveParcsecsCampaignVictoryType.NONE

# Define victory categories as an array
const VICTORY_CATEGORIES = [
	GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE,
	GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
	GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL,
	GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE
]

var current_condition: String = ""
var custom_value_spin: SpinBox
var custom_type_option: OptionButton

func _init() -> void:
	custom_value_spin = SpinBox.new()
	custom_value_spin.min_value = 1
	custom_value_spin.max_value = 1000000
	custom_value_spin.step = 1000
	custom_value_spin.value = 10000
	
	custom_type_option = OptionButton.new()
	_setup_custom_options()

func _setup_custom_options() -> void:
	custom_type_option.add_item("Credits", GlobalEnums.ResourceType.CREDITS)
	custom_type_option.add_item("Reputation", GlobalEnums.ResourceType.PATRON)
	custom_type_option.add_item("Story Points", GlobalEnums.ResourceType.STORY_POINT)
	custom_type_option.add_item("Supplies", GlobalEnums.ResourceType.SUPPLIES)

func select_victory_condition(condition_key: int) -> void:
	if condition_key in VICTORY_CATEGORIES:
		selected_victory_type = condition_key
		victory_selected.emit(selected_victory_type, {})

func get_victory_type() -> int:
	return selected_victory_type

func set_victory_type(type: int) -> void:
	if type in VICTORY_CATEGORIES:
		selected_victory_type = type

func get_victory_description(type: int) -> String:
	match type:
		GlobalEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			return "Complete the main story campaign"
		GlobalEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			return "Accumulate significant wealth"
		GlobalEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			return "Build your reputation in the galaxy"
		GlobalEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			return "Achieve dominance with your chosen faction"
		_:
			return "Unknown victory condition"
