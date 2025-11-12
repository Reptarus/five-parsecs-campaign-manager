# VictoryConditionSelection.gd
extends Resource

# GlobalEnums available as autoload singleton

signal victory_selected(type: int, data: Dictionary)

# Victory types
var selected_victory_type: int = GlobalEnums.FiveParsecsCampaignVictoryType.NONE

# Define victory categories as an array - Five Parsecs Core Rules compliant
const VICTORY_CATEGORIES = [
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20,
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50,
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100,
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20,
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50,
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100,
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3,
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5,
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10,
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10,
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20,
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K,
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K,
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10,
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20,
	GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL,
	GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10
]

var _current_condition: String = ""
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
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return "Play 20 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return "Play 50 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return "Play 100 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			return "Fight 20 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			return "Fight 50 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return "Fight 100 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return "Complete 3 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return "Complete 5 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return "Complete 10 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			return "Accumulate 10 story points"
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return "Accumulate 20 story points"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			return "Accumulate 50,000 credits"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return "Accumulate 100,000 credits"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			return "Achieve reputation level 10"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return "Achieve reputation level 20"
		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return "Keep your original character alive"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10:
			return "Reach crew size of 10"
		_:
			return "Unknown victory condition"
