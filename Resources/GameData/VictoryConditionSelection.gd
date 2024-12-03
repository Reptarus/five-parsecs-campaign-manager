# VictoryConditionSelection.gd
class_name VictoryConditionSelection
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal victory_selected(type: GlobalEnums.CampaignVictoryType, data: Dictionary)

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
		"REPUTATION_NOTORIOUS": {
			"type": GlobalEnums.CampaignVictoryType.REPUTATION_GOAL,
			"name": "Notorious Reputation",
			"description": "Become a notorious crew through successful missions and story events"
		}
	},
	"Story": {
		"STORY_COMPLETE": {
			"type": GlobalEnums.CampaignVictoryType.STORY_COMPLETE,
			"name": "Story Complete",
			"description": "Complete the main story campaign"
		}
	},
	"Combat": {
		"BLACK_ZONE_MASTER": {
			"type": GlobalEnums.CampaignVictoryType.SURVIVAL,
			"name": "Black Zone Master",
			"description": "Successfully complete 3 super-hard Black Zone jobs"
		},
		"RED_ZONE_VETERAN": {
			"type": GlobalEnums.CampaignVictoryType.SURVIVAL,
			"name": "Red Zone Veteran",
			"description": "Successfully complete 5 high-risk Red Zone jobs"
		}
	},
	"Quests": {
		"QUEST_MASTER": {
			"type": GlobalEnums.CampaignVictoryType.SURVIVAL,
			"name": "Quest Master",
			"description": "Complete 10 quests"
		}
	},
	"Faction": {
		"FACTION_DOMINANCE": {
			"type": GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE,
			"name": "Faction Dominance",
			"description": "Become dominant in a faction"
		}
	},
	"Fleet": {
		"FLEET_COMMANDER": {
			"type": GlobalEnums.CampaignVictoryType.SURVIVAL,
			"name": "Fleet Commander",
			"description": "Build up a significant fleet"
		}
	},
	"Custom": {
		"CUSTOM": {
			"type": GlobalEnums.CampaignVictoryType.SURVIVAL,
			"name": "Custom Victory Condition",
			"description": "Set your own victory condition"
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
	custom_type_option.add_item("Credits", 0)
	custom_type_option.add_item("Reputation", 1)
	custom_type_option.add_item("Quests", 2)
	custom_type_option.add_item("Battles", 3)
	custom_type_option.add_item("Crew Size", 4)

func select_victory_condition(condition_key: String) -> void:
	if not condition_key in VICTORY_CATEGORIES.values().reduce(func(acc, cat): return acc + cat.keys(), []):
		push_error("Invalid victory condition key")
		return
	
	current_condition = condition_key
	
	if condition_key == "CUSTOM":
		var custom_data = {
			"type": custom_type_option.get_selected_id(),
			"value": custom_value_spin.value
		}
		victory_selected.emit(GlobalEnums.CampaignVictoryType.SURVIVAL, custom_data)
	else:
		if current_condition.is_empty():
			return
			
		for category in VICTORY_CATEGORIES.values():
			if current_condition in category:
				var condition = category[current_condition]
				victory_selected.emit(condition.type, {})
				return
