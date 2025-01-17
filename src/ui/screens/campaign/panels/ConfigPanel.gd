extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal config_updated(config: Dictionary)

@onready var campaign_name_input = $Content/CampaignName/LineEdit
@onready var difficulty_option = $Content/Difficulty/OptionButton
@onready var description_label = $Content/Description/Label

var current_config: Dictionary = {
	"name": "",
	"difficulty": GameEnums.DifficultyLevel.NORMAL
}

func _ready() -> void:
	_setup_difficulty_options()
	_connect_signals()
	_update_description()

func _setup_difficulty_options() -> void:
	difficulty_option.clear()
	
	difficulty_option.add_item("Easy", GameEnums.DifficultyLevel.EASY)
	difficulty_option.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
	difficulty_option.add_item("Hard", GameEnums.DifficultyLevel.HARD)
	difficulty_option.add_item("Nightmare", GameEnums.DifficultyLevel.NIGHTMARE)
	
	difficulty_option.select(1) # Default to Normal

func _connect_signals() -> void:
	campaign_name_input.text_changed.connect(_on_campaign_name_changed)
	difficulty_option.item_selected.connect(_on_difficulty_selected)

func _on_campaign_name_changed(new_text: String) -> void:
	current_config.name = new_text
	config_updated.emit(current_config)

func _on_difficulty_selected(index: int) -> void:
	current_config.difficulty = difficulty_option.get_item_id(index)
	_update_description()
	config_updated.emit(current_config)

func _update_description() -> void:
	var description = ""
	
	match current_config.difficulty:
		GameEnums.DifficultyLevel.EASY:
			description = """
			Easy Mode:
			- More starting resources
			- Easier combat encounters
			- More forgiving upkeep costs
			Perfect for learning the game mechanics.
			"""
		GameEnums.DifficultyLevel.NORMAL:
			description = """
			Normal Mode:
			- Standard resource allocation
			- Balanced combat encounters
			- Regular upkeep costs
			The classic Five Parsecs experience.
			"""
		GameEnums.DifficultyLevel.HARD:
			description = """
			Hard Mode:
			- Fewer starting resources
			- Tougher combat encounters
			- Higher upkeep costs
			For experienced captains seeking a challenge.
			"""
		GameEnums.DifficultyLevel.NIGHTMARE:
			description = """
			Nightmare Mode:
			- Minimal starting resources
			- Brutal combat encounters
			- Extreme upkeep costs
			The ultimate test of survival.
			"""
	
	description_label.text = description

func get_config() -> Dictionary:
	return current_config.duplicate()

func is_valid() -> bool:
	return not current_config.name.strip_edges().is_empty()