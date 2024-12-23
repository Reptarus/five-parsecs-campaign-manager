# VictoryConditionSelection.gd
class_name VictoryConditionSelection
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal victory_selected(type: int, data: Dictionary)

# Move victory conditions to a const to prevent modification
const VICTORY_CATEGORIES = {
	"Wealth": {
		"WEALTH_5000": {
			"type": GlobalEnums.CampaignVictoryType.WEALTH_GOAL,
			"name": "Wealthy Crew",
			"description": "Accumulate 5000 credits through jobs, trade, and salvage"
		}
	},
	"Reputation": {
		"REPUTATION_HIGH": {
			"type": GlobalEnums.CampaignVictoryType.REPUTATION_GOAL,
			"name": "Renowned Crew",
			"description": "Achieve high reputation with a major faction"
		}
	},
	"Faction": {
		"FACTION_DOMINANCE": {
			"type": GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE,
			"name": "Faction Champion",
			"description": "Lead your chosen faction to dominance"
		}
	},
	"Story": {
		"STORY_COMPLETE": {
			"type": GlobalEnums.CampaignVictoryType.STORY_COMPLETE,
			"name": "Story Completion",
			"description": "Complete the main story campaign"
		}
	}
}

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
	custom_type_option.add_item("Experience", GlobalEnums.ResourceType.XP)
	custom_type_option.add_item("Supplies", GlobalEnums.ResourceType.SUPPLIES)

func select_victory_condition(condition_key: String) -> void:
	var all_conditions = []
	for category in VICTORY_CATEGORIES.values():
		all_conditions.append_array(category.keys())
	
	if not condition_key in all_conditions and condition_key != "CUSTOM":
		push_error("Invalid victory condition key")
		return
	
	current_condition = condition_key
	
	if condition_key == "CUSTOM":
		var custom_data = {
			"type": custom_type_option.get_selected_id(),
			"value": custom_value_spin.value
		}
		victory_selected.emit(GlobalEnums.CampaignVictoryType.NONE, custom_data)
	else:
		if current_condition.is_empty():
			return
			
		for category in VICTORY_CATEGORIES.values():
			if current_condition in category:
				var condition = category[current_condition]
				victory_selected.emit(condition.type, {})
