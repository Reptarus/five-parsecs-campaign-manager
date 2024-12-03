class_name CampaignSetupScreen
extends Control

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

const DEFAULT_CREW_SIZE := 4
const MIN_CREW_SIZE := 3
const MAX_CREW_SIZE := 8

var campaign_config := {
	"crew_name": "",
	"crew_size": DEFAULT_CREW_SIZE,
	"difficulty": GlobalEnums.DifficultyMode.NORMAL,
	"victory_condition": GlobalEnums.CampaignVictoryType.NONE,
	"custom_victory_data": {}
}

func _ready() -> void:
	_setup_difficulty_options()
	_setup_victory_conditions()
	_update_summary()

func _setup_difficulty_options() -> void:
	var difficulty_option = $DifficultyOption
	difficulty_option.clear()
	
	difficulty_option.add_item("Easy", GlobalEnums.DifficultyMode.EASY)
	difficulty_option.add_item("Normal", GlobalEnums.DifficultyMode.NORMAL)
	difficulty_option.add_item("Hard", GlobalEnums.DifficultyMode.HARD)
	difficulty_option.add_item("Veteran", GlobalEnums.DifficultyMode.VETERAN)
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyMode.CHALLENGING)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyMode.HARDCORE)
	difficulty_option.add_item("Insanity", GlobalEnums.DifficultyMode.INSANITY)
	
	difficulty_option.select(GlobalEnums.DifficultyMode.NORMAL)

func _setup_victory_conditions() -> void:
	var victory_option = $VictoryOption
	victory_option.clear()
	
	victory_option.add_item("Story Complete", GlobalEnums.CampaignVictoryType.STORY_COMPLETE)
	victory_option.add_item("Wealth Goal", GlobalEnums.CampaignVictoryType.WEALTH_GOAL)
	victory_option.add_item("Reputation Goal", GlobalEnums.CampaignVictoryType.REPUTATION_GOAL)
	victory_option.add_item("Faction Dominance", GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE)
	victory_option.add_item("Survival", GlobalEnums.CampaignVictoryType.SURVIVAL)
	victory_option.add_item("Custom", GlobalEnums.CampaignVictoryType.CUSTOM)
	
	victory_option.select(GlobalEnums.CampaignVictoryType.NONE)

func _on_victory_condition_selected(condition: int, custom_data: Dictionary = {}) -> void:
	campaign_config.victory_condition = condition
	campaign_config.custom_victory_data = custom_data
	
	var description = ""
	if condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		description = "Custom: %s - Target: %d" % [custom_data.type, custom_data.value]
	else:
		description = VictoryDescriptions.get_description(condition)
	
	$VictoryDescription.text = description
	_update_summary()

func _update_summary() -> void:
	var summary = $SummaryLabel
	var difficulty_name = $DifficultyOption.get_item_text($DifficultyOption.selected)
	var victory_text = ""
	
	if campaign_config.victory_condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		victory_text = "Custom: %s - Target: %d" % [campaign_config.custom_victory_data.type, campaign_config.custom_victory_data.value]
	else:
		victory_text = VictoryDescriptions.get_description(campaign_config.victory_condition)
	
	summary.text = """
	Crew Name: %s
	Crew Size: %d
	Difficulty: %s
	Victory Condition: %s
	""" % [campaign_config.crew_name, campaign_config.crew_size, difficulty_name, victory_text]

func _get_difficulty_description(difficulty: int) -> String:
	var text = ""
	match difficulty:
		GlobalEnums.DifficultyMode.EASY:
			text += "- Start with 120% of normal starting credits\n"
			text += "- Enemy numbers reduced by 1 in all encounters\n"
			text += "- +1 bonus to injury recovery rolls\n"
			text += "- Event choices show outcome chances\n"
		GlobalEnums.DifficultyMode.NORMAL:
			text += "- Standard starting credits\n"
			text += "- Normal enemy numbers\n"
			text += "- Standard injury recovery rules\n"
			text += "- Normal event resolution\n"
		GlobalEnums.DifficultyMode.CHALLENGING:
			text += "- Start with 80% of normal starting credits\n"
			text += "- Enemy numbers increased by 1 in all encounters\n"
			text += "- -1 penalty to injury recovery rolls\n"
			text += "- Event choices have hidden outcome chances\n"
		GlobalEnums.DifficultyMode.HARDCORE:
			text += "- Start with 60% of normal starting credits\n"
			text += "- Enemy numbers increased by 2 in all encounters\n"
			text += "- -2 penalty to injury recovery rolls\n"
			text += "- Failed event rolls use worst outcome\n"
			text += "- Characters who reach Critical status may die permanently\n"
		GlobalEnums.DifficultyMode.INSANITY:
			text += "- Start with 50% of normal starting credits\n"
			text += "- All enemy groups include at least one Elite\n"
			text += "- -3 penalty to injury recovery rolls\n"
			text += "- Failed event rolls always use worst outcome\n"
			text += "- Characters who reach Critical status will die permanently\n"
	return text

func _validate_campaign_config() -> bool:
	var has_crew_name = not campaign_config.crew_name.strip_edges().is_empty()
	var crew_size_locked = campaign_config.crew_size >= MIN_CREW_SIZE and campaign_config.crew_size <= MAX_CREW_SIZE
	var has_valid_victory = false
	
	if campaign_config.victory_condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		# For custom victory, we need both type and value in the custom_data
		has_valid_victory = campaign_config.custom_victory_data.has("type") and campaign_config.custom_victory_data.has("value")
	else:
		has_valid_victory = campaign_config.victory_condition != GlobalEnums.CampaignVictoryType.NONE
	
	return has_crew_name and crew_size_locked and has_valid_victory
