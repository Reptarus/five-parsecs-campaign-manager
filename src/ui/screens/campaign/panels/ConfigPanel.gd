extends Control

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal config_updated(config: Dictionary)

@onready var campaign_name_input: LineEdit = $"Content/CampaignName/LineEdit"
@onready var difficulty_option: OptionButton = $"Content/Difficulty/OptionButton"
@onready var victory_condition_option: OptionButton = $"Content/VictoryCondition/OptionButton"
@onready var story_track_toggle: CheckBox = $"Content/StoryTrack/CheckBox"
@onready var description_label: Label = $"Content/Description/Label"

var current_config: Dictionary = {
	"name": "",
	"difficulty": GlobalEnums.DifficultyLevel.STANDARD,
	"victory_condition": "none",
	"story_track_enabled": false,
	"elite_ranks": 0
}

func _ready() -> void:
	_setup_difficulty_options()
	_setup_victory_conditions()
	_connect_signals()
	_update_description()

func _setup_difficulty_options() -> void:
	difficulty_option.clear()

	difficulty_option.add_item("Story", GlobalEnums.DifficultyLevel.STORY)
	difficulty_option.add_item("Standard", GlobalEnums.DifficultyLevel.STANDARD)
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING)
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)
	difficulty_option.add_item("Nightmare", GlobalEnums.DifficultyLevel.NIGHTMARE)

	difficulty_option.select(1) # Default to Standard

func _setup_victory_conditions() -> void:
	if not victory_condition_option:
		return

	victory_condition_option.clear()

	# Official Victory Conditions from Five Parsecs rules
	victory_condition_option.add_item("No Victory Condition", 0)
	victory_condition_option.add_item("Play 20 Campaign Turns", 1)
	victory_condition_option.add_item("Play 50 Campaign Turns", 2)
	victory_condition_option.add_item("Play 100 Campaign Turns", 3)
	victory_condition_option.add_item("Complete 3 Quests", 4)
	victory_condition_option.add_item("Complete 5 Quests", 5)
	victory_condition_option.add_item("Complete 10 Quests", 6)
	victory_condition_option.add_item("Win 20 Tabletop Battles", 7)
	victory_condition_option.add_item("Win 50 Tabletop Battles", 8)
	victory_condition_option.add_item("Upgrade 1 Character 10 Times", 9)
	victory_condition_option.add_item("Upgrade 3 Characters 10 Times", 10)
	victory_condition_option.add_item("Upgrade 5 Characters 10 Times", 11)
	victory_condition_option.add_item("Play 50 Turns in Challenging Mode", 12)
	victory_condition_option.add_item("Play 50 Turns in Hardcore Mode", 13)
	victory_condition_option.add_item("Play 50 Turns in Insanity Mode", 14)

	victory_condition_option.select(0) # Default to no victory condition

func _connect_signals() -> void:
	if campaign_name_input and campaign_name_input.has_signal("text_changed"):
		campaign_name_input.text_changed.connect(_on_campaign_name_changed)
	if difficulty_option and difficulty_option.has_signal("item_selected"):
		difficulty_option.item_selected.connect(_on_difficulty_selected)
	if victory_condition_option and victory_condition_option.has_signal("item_selected"):
		victory_condition_option.item_selected.connect(_on_victory_condition_selected)
	if story_track_toggle and story_track_toggle.has_signal("toggled"):
		story_track_toggle.toggled.connect(_on_story_track_toggled)

func _on_campaign_name_changed(new_text: String) -> void:
	current_config.name = new_text
	config_updated.emit(current_config)

func _on_difficulty_selected(index: int) -> void:
	current_config.difficulty = difficulty_option.get_item_id(index)
	_update_description()
	config_updated.emit(current_config)

func _on_victory_condition_selected(index: int) -> void:
	var victory_id = victory_condition_option.get_item_id(index)
	current_config.victory_condition = _get_victory_condition_string(victory_id)
	config_updated.emit(current_config)

func _on_story_track_toggled(enabled: bool) -> void:
	current_config.story_track_enabled = enabled
	config_updated.emit(current_config)

func _get_victory_condition_string(victory_id: int) -> String:
	match victory_id:
		0: return "none"
		1: return "play_20_turns"
		2: return "play_50_turns"
		3: return "play_100_turns"
		4: return "complete_3_quests"
		5: return "complete_5_quests"
		6: return "complete_10_quests"
		7: return "win_20_battles"
		8: return "win_50_battles"
		9: return "upgrade_1_character_10_times"
		10: return "upgrade_3_characters_10_times"
		11: return "upgrade_5_characters_10_times"
		12: return "play_50_turns_challenging"
		13: return "play_50_turns_hardcore"
		14: return "play_50_turns_insanity"
		_: return "none"

func _update_description() -> void:
	var description: String = ""

	match current_config.difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			description = "Story Mode: Casual play with reduced difficulty, more starting resources, easier combat encounters. Perfect for learning the game mechanics."
		GlobalEnums.DifficultyLevel.STANDARD:
			description = "Standard Mode: Core rules as written, balanced challenges, standard resource allocation. The authentic Five Parsecs experience."
		GlobalEnums.DifficultyLevel.CHALLENGING:
			description = "Challenging Mode: Increased enemy strength, tougher combat encounters, higher upkeep costs. For experienced captains seeking a challenge."
		GlobalEnums.DifficultyLevel.HARDCORE:
			description = "Hardcore Mode: Maximum difficulty with elite enemies, minimal starting resources, brutal combat encounters. The ultimate test of survival."
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			description = "Nightmare Mode: Custom ultra-hard mode with extreme challenges, minimal resources, and the most difficult encounters possible."

	if description_label:
		description_label.text = description

func get_config() -> Dictionary:
	return current_config.duplicate()

func get_config_data() -> Dictionary:
	"""Get configuration data in the format expected by CampaignCreationStateManager"""
	var config_data = {
		"campaign_name": current_config.get("name", "").strip_edges(),
		"difficulty_level": current_config.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD),
		"victory_condition": current_config.get("victory_condition", "none"),
		"story_track_enabled": current_config.get("story_track_enabled", false),
		"elite_ranks": current_config.get("elite_ranks", 0),
		"created_date": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}
	return config_data

func is_valid() -> bool:
	return not current_config.name.strip_edges().is_empty()

func validate() -> Array[String]:
	"""Validate configuration and return error messages"""
	var errors: Array[String] = []
	
	if current_config.name.strip_edges().is_empty():
		errors.append("Campaign name is required")
	elif current_config.name.strip_edges().length() < 3:
		errors.append("Campaign name must be at least 3 characters")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_config_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("name"):
		campaign_name_input.text = data.name
		current_config.name = data.name
	if data.has("difficulty"):
		_set_difficulty_selection(data.difficulty)
		current_config.difficulty = data.difficulty
	if data.has("victory_condition"):
		_set_victory_condition_selection(data.victory_condition)
		current_config.victory_condition = data.victory_condition
	if data.has("story_track_enabled"):
		story_track_toggle.button_pressed = data.story_track_enabled
		current_config.story_track_enabled = data.story_track_enabled
	
	_update_config()

func _set_difficulty_selection(difficulty: int) -> void:
	"""Set difficulty selection safely"""
	for i in range(difficulty_option.get_item_count()):
		if difficulty_option.get_item_id(i) == difficulty:
			difficulty_option.select(i)
			break

func _set_victory_condition_selection(victory_condition: String) -> void:
	"""Set victory condition selection safely"""
	for i in range(victory_condition_option.get_item_count()):
		if victory_condition_option.get_item_text(i).to_lower().contains(victory_condition.to_lower()):
			victory_condition_option.select(i)
			break

func _update_config() -> void:
	"""Update configuration and emit the config_updated signal"""
	_update_description()
	config_updated.emit(current_config)
