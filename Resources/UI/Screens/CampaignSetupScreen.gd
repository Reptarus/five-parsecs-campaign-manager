class_name CampaignSetupScreen
extends Control

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

const DEFAULT_CREW_SIZE := 4
const MIN_CREW_SIZE := 3
const MAX_CREW_SIZE := 8

@onready var victory_option := $VictoryOption
@onready var victory_description_label := $VictoryDescription
@onready var summary_label := $SummaryLabel

var campaign_config := {
	"crew_name": "",
	"crew_size": DEFAULT_CREW_SIZE,
	"difficulty": GameEnums.DifficultyMode.NORMAL,
	"victory_condition": GameEnums.VictoryConditionType.TURNS,
	"custom_victory_data": {}
}

func _ready() -> void:
	_setup_difficulty_options()
	_setup_victory_options()
	_update_summary()

func _setup_difficulty_options() -> void:
	var difficulty_option = $DifficultyOption
	difficulty_option.clear()
	
	difficulty_option.add_item("Easy", GameEnums.DifficultyMode.EASY)
	difficulty_option.add_item("Normal", GameEnums.DifficultyMode.NORMAL)
	difficulty_option.add_item("Hard", GameEnums.DifficultyMode.HARD)
	difficulty_option.add_item("Veteran", GameEnums.DifficultyMode.VETERAN)
	difficulty_option.add_item("Challenging", GameEnums.DifficultyMode.CHALLENGING)
	difficulty_option.add_item("Hardcore", GameEnums.DifficultyMode.HARDCORE)
	difficulty_option.add_item("Insanity", GameEnums.DifficultyMode.INSANITY)
	
	difficulty_option.select(GameEnums.DifficultyMode.NORMAL)

func _setup_victory_options() -> void:
	victory_option.clear()
	
	victory_option.add_item("Turns", GameEnums.VictoryConditionType.TURNS)
	victory_option.add_item("Quests", GameEnums.VictoryConditionType.QUESTS)
	victory_option.add_item("Survival", GameEnums.VictoryConditionType.SURVIVAL)
	
	victory_option.select(GameEnums.VictoryConditionType.TURNS)

func _on_victory_condition_selected(condition: int, custom_data: Dictionary = {}) -> void:
	campaign_config.victory_condition = condition
	campaign_config.custom_victory_data = custom_data
	
	var description = VictoryDescriptions.get_description(condition)
	victory_description_label.text = description

func _update_victory_description() -> void:
	var victory_text = VictoryDescriptions.get_description(campaign_config.victory_condition)
	victory_description_label.text = victory_text

func _update_summary() -> void:
	var difficulty_name = $DifficultyOption.get_item_text($DifficultyOption.selected)
	var victory_text = VictoryDescriptions.get_description(campaign_config.victory_condition)
	
	summary_label.text = """
	Crew Name: %s
	Crew Size: %d
	Difficulty: %s
	Victory Condition: %s
	""" % [campaign_config.crew_name, campaign_config.crew_size, difficulty_name, victory_text]

func _get_difficulty_description(difficulty: int) -> String:
	var text = ""
	match difficulty:
		GameEnums.DifficultyMode.EASY:
			text += "- Start with 120% of normal starting credits\n"
			text += "- Enemy numbers reduced by 1 in all encounters\n"
			text += "- +1 bonus to injury recovery rolls\n"
			text += "- Event choices show outcome chances\n"
		GameEnums.DifficultyMode.NORMAL:
			text += "- Standard starting credits\n"
			text += "- Normal enemy numbers\n"
			text += "- Standard injury recovery rules\n"
			text += "- Normal event resolution\n"
		GameEnums.DifficultyMode.CHALLENGING:
			text += "- Start with 80% of normal starting credits\n"
			text += "- Enemy numbers increased by 1 in all encounters\n"
			text += "- -1 penalty to injury recovery rolls\n"
			text += "- Event choices have hidden outcome chances\n"
		GameEnums.DifficultyMode.HARDCORE:
			text += "- Start with 60% of normal starting credits\n"
			text += "- Enemy numbers increased by 2 in all encounters\n"
			text += "- -2 penalty to injury recovery rolls\n"
			text += "- Failed event rolls use worst outcome\n"
			text += "- Characters who reach Critical status may die permanently\n"
		GameEnums.DifficultyMode.INSANITY:
			text += "- Start with 50% of normal starting credits\n"
			text += "- All enemy groups include at least one Elite\n"
			text += "- -3 penalty to injury recovery rolls\n"
			text += "- Failed event rolls always use worst outcome\n"
			text += "- Characters who reach Critical status will die permanently\n"
	return text

func _validate_config() -> bool:
	var has_crew_name = not campaign_config.crew_name.strip_edges().is_empty()
	var crew_size_locked = campaign_config.crew_size >= MIN_CREW_SIZE and campaign_config.crew_size <= MAX_CREW_SIZE
	var has_valid_victory = campaign_config.victory_condition in [
		GameEnums.VictoryConditionType.TURNS,
		GameEnums.VictoryConditionType.QUESTS,
		GameEnums.VictoryConditionType.SURVIVAL
	]
	
	return has_crew_name and crew_size_locked and has_valid_victory
