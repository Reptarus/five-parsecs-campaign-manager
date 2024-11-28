class_name CampaignSetupScreen
extends Control

# Constants and preloads at the top
const GlobalEnums := preload("res://Resources/GameData/GlobalEnums.gd")
const VictoryDescriptions := preload("res://Resources/GameData/VictoryDescriptions.gd")
const VictorySelectionScene := preload("res://Resources/CampaignManagement/Scenes/VictoryConditionSelection.tscn")
const CaptainCreationScene = preload("res://Resources/CrewAndCharacters/Scenes/CaptainCreation.tscn")
const InitialCrewCreationScene = preload("res://Resources/CrewAndCharacters/InitialCrewCreation.tscn")

const MIN_CREW_SIZE := 3
const MAX_INITIAL_CREW_SIZE := 6  # Maximum crew size at campaign start
const MAX_TOTAL_CREW_SIZE := 8    # Maximum crew size during campaign
const DEFAULT_CREW_SIZE := 4

const EQUIPMENT_DATA_PATH := "res://data/equipment_database.json"
const CHARACTER_DATA_PATH := "res://data/character_creation_data.json"
const VICTORY_DATA_PATH := "res://data/character_creation_data.json"

# Signal declarations next
signal campaign_setup_completed(config: Dictionary)
signal captain_creation_started(config: Dictionary)

# Onready variables grouped together
@onready var victory_type_label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryTypeLabel
@onready var victory_count_label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryCountLabel
@onready var set_victory_button = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/SetVictoryConditionButton
@onready var crew_name_input = $HBoxContainer/LeftPanel/VBoxContainer/CrewNameInput
@onready var difficulty_option = $HBoxContainer/LeftPanel/VBoxContainer/DifficultyOptionButton
@onready var crew_size_slider = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/HSlider
@onready var crew_size_label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/CrewSizeLabel
@onready var start_button = $HBoxContainer/LeftPanel/VBoxContainer/StartCampaignButton
@onready var variation_descriptions = $HBoxContainer/RightPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/VariationDescriptions/MessageLabel
@onready var lock_crew_size_button = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/LockCrewSizeButton

# Campaign configuration
var campaign_config: Dictionary = {
	"crew_name": "",
	"difficulty": GlobalEnums.DifficultyMode.NORMAL,
	"crew_size": DEFAULT_CREW_SIZE,
	"victory_condition": GlobalEnums.CampaignVictoryType.NONE,
	"custom_victory_data": {}
}

# Add to the top with other variables
var crew_size_locked := false
var equipment_data: Dictionary
var character_data: Dictionary
var victory_data: Dictionary

func _ready() -> void:
	# Load JSON data first
	_load_game_data()
	
	if not _verify_nodes():
		push_error("CampaignSetupScreen: Required nodes are missing!")
		return
	
	_setup_ui()
	_connect_signals()
	_update_ui_state()

func _verify_nodes() -> bool:
	var required_nodes = [
		victory_type_label,
		victory_count_label,
		set_victory_button,
		crew_name_input,
		difficulty_option,
		crew_size_slider,
		crew_size_label,
		start_button
	]
	
	for node in required_nodes:
		if not node:
			push_error("Missing required node: " + str(node))
			return false
	
	return true

func _setup_ui() -> void:
	# Setup difficulty options with proper names
	difficulty_option.clear()
	for difficulty in GlobalEnums.DifficultyMode.values():
		var difficulty_name = GlobalEnums.DifficultyMode.keys()[difficulty].capitalize()
		difficulty_option.add_item(difficulty_name, difficulty)
	
	# Setup crew size slider using data from character_data
	var crew_sizes = character_data.get("crew_sizes", [3, 4, 5, 6, 7, 8])
	crew_size_slider.min_value = crew_sizes[0]
	crew_size_slider.max_value = crew_sizes[-1]
	crew_size_slider.value = DEFAULT_CREW_SIZE
	
	# Update initial labels
	_update_crew_size_label(DEFAULT_CREW_SIZE)
	_reset_victory_labels()
	_update_campaign_variations()
	
	# Set initial tutorial text
	var tutorial_label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/TutorialLabel
	tutorial_label.text = "Select your crew size and click 'Lock Crew Size' to continue"

func _connect_signals() -> void:
	crew_name_input.text_changed.connect(_on_crew_name_changed)
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	crew_size_slider.value_changed.connect(_on_crew_size_changed)
	start_button.pressed.connect(_on_start_campaign)
	set_victory_button.pressed.connect(_show_victory_selection)
	lock_crew_size_button.pressed.connect(_on_lock_crew_size_pressed)

func _on_crew_name_changed(new_name: String) -> void:
	campaign_config.crew_name = new_name
	_update_ui_state()

func _on_difficulty_selected(index: int) -> void:
	var difficulty = difficulty_option.get_item_id(index)
	campaign_config.difficulty = difficulty
	_update_campaign_variations()

func _on_crew_size_changed(value: float) -> void:
	campaign_config.crew_size = int(value)
	_update_crew_size_label(value)
	_update_campaign_variations()

func _update_crew_size_label(size: float) -> void:
	crew_size_label.text = "Initial Crew Size: %d (Max: %d)" % [int(size), MAX_TOTAL_CREW_SIZE]

func _reset_victory_labels() -> void:
	victory_type_label.text = "Victory Condition:"
	victory_count_label.text = "No victory condition selected"

func _show_victory_selection() -> void:
	var selection = VictorySelectionScene.instantiate()
	add_child(selection)
	
	# Connect to the signals
	selection.victory_selected.connect(
		func(condition: int, custom_data: Dictionary):
			_handle_victory_selected(condition, custom_data)
			selection.queue_free()
	)
	
	selection.closed.connect(
		func():
			selection.queue_free()
	)
	
	selection.show_dialog()

func _handle_victory_selected(condition: int, custom_data: Dictionary = {}) -> void:
	campaign_config.victory_condition = condition
	campaign_config.custom_victory_data = custom_data
	
	var condition_name = GlobalEnums.CampaignVictoryType.keys()[condition].capitalize().replace("_", " ")
	victory_type_label.text = "Victory Condition: %s" % condition_name
	
	var description = ""
	if condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		description = "Custom: %s - Target: %d" % [custom_data.type, custom_data.value]
	else:
		description = VictoryDescriptions.get_description(condition)
	
	victory_count_label.text = description
	_update_campaign_variations()
	_update_ui_state()

func _on_start_campaign() -> void:
	if !crew_size_locked:
		push_warning("Attempted to start campaign without locking crew size")
		return
	
	# Show confirmation popup
	var popup = ConfirmationDialog.new()
	popup.title = "Begin Campaign"
	
	var difficulty_name = difficulty_option.get_item_text(difficulty_option.selected)
	var victory_text = ""
	if campaign_config.victory_condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		victory_text = "Custom: %s - Target: %d" % [campaign_config.custom_victory_data.type, campaign_config.custom_victory_data.value]
	else:
		victory_text = VictoryDescriptions.get_description(campaign_config.victory_condition)
	
	popup.dialog_text = """You are about to begin campaign creation with:

[b]Campaign Name:[/b] %s
[b]Difficulty:[/b] %s
[b]Initial Crew Size:[/b] %d
[b]Victory Condition:[/b] %s

These settings cannot be changed after creation begins. Continue?""" % [
		campaign_config.crew_name,
		difficulty_name,
		campaign_config.crew_size,
		victory_text
	]
	
	popup.ok_button_text = "Start Campaign"
	popup.cancel_button_text = "Back to Settings"
	
	add_child(popup)
	
	popup.confirmed.connect(
		func():
			_start_captain_creation()
			popup.queue_free()
	)
	popup.canceled.connect(
			func():
				popup.queue_free()
	)
	
	popup.popup_centered()

func _start_captain_creation() -> void:
	var captain_creation = CaptainCreationScene.instantiate()
	add_child(captain_creation)
	captain_creation.initialize(campaign_config)
	
	captain_creation.captain_created.connect(
		func(captain):
			# Store captain and proceed to crew creation
			GameStateManager.set_captain(captain)
			_start_crew_creation()
			captain_creation.queue_free()
	)
	
	captain_creation.creation_cancelled.connect(
		func():
			captain_creation.queue_free()
	)

func _start_crew_creation() -> void:
	# Start initial crew creation with remaining slots
	var crew_creation = InitialCrewCreationScene.instantiate()
	add_child(crew_creation)
	crew_creation.initialize(campaign_config)
	
	# Connect to crew creation signals
	crew_creation.crew_created.connect(
		func(crew):
			GameStateManager.set_crew(crew)
			_finalize_campaign_setup()
			crew_creation.queue_free()
	)
	
	crew_creation.creation_cancelled.connect(
		func():
			crew_creation.queue_free()
			# Optionally return to captain creation or show error
	)

func _update_ui_state() -> void:
	var has_crew_name = campaign_config.crew_name.length() > 0
	var has_valid_victory = false
	
	if campaign_config.victory_condition == GlobalEnums.CampaignVictoryType.CUSTOM:
		# For custom victory, we need both type and value in the custom_data
		has_valid_victory = campaign_config.custom_victory_data.has("type") and campaign_config.custom_victory_data.has("value")
	else:
		has_valid_victory = campaign_config.victory_condition != GlobalEnums.CampaignVictoryType.NONE
	
	# Only enable start button if crew size is locked and other conditions are met
	start_button.disabled = !has_crew_name || !has_valid_victory || !crew_size_locked

func _update_campaign_variations() -> void:
	var text = ""
	
	# Difficulty variations
	text += "[b]Difficulty: %s[/b]\n" % difficulty_option.get_item_text(difficulty_option.selected)
	
	# Get difficulty effects from character_data if available
	var difficulty_name = GlobalEnums.DifficultyMode.keys()[campaign_config.difficulty].to_lower()
	var difficulty_effects = character_data.get("difficulty_effects", {}).get(difficulty_name, [])
	
	if difficulty_effects.size() > 0:
		for effect in difficulty_effects:
			text += "- %s\n" % effect
	else:
		# Fallback to hardcoded effects if not found in JSON
		match campaign_config.difficulty:
			GlobalEnums.DifficultyMode.EASY:
				text += "- Start with 120% of normal starting credits\n"
				text += "- Enemy numbers reduced by 1 in all encounters\n"
				text += "- +1 bonus to all injury recovery rolls\n"
				text += "- Event choices always show best outcome chance\n"
			GlobalEnums.DifficultyMode.NORMAL:
				text += "- Standard starting credits (100%)\n"
				text += "- Normal enemy numbers in encounters\n"
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
				text += "- Event choices always use worst outcome table\n"
				text += "- Characters who reach Injured status may die permanently\n"
				text += "- No save/load during missions\n"
	
	# Add crew size information
	text += "\n[b]Crew Size: %d[/b]\n" % campaign_config.crew_size
	
	# Get crew size effects from character_data
	var crew_size_effects = character_data.get("crew_size_effects", {}).get(str(campaign_config.crew_size), [])
	
	if crew_size_effects.size() > 0:
		for effect in crew_size_effects:
			text += "- %s\n" % effect
	else:
		# Fallback to hardcoded effects
		match campaign_config.crew_size:
			3:
				text += "- Begin the game with 3 characters\n"
				text += "- Deploy up to 3 characters in battle\n"
				text += "- When determining enemy numbers, roll 3D6 and use the lowest result\n"
				text += "- Each character receives 133% of normal starting gear value\n"
			4:
				text += "- Begin the game with 4 characters\n"
				text += "- Deploy up to 4 characters in battle\n"
				text += "- When determining enemy numbers, roll 2D6 and use the lower result\n"
				text += "- Each character receives 125% of normal starting gear value\n"
			5:
				text += "- Begin the game with 5 characters\n"
				text += "- Deploy up to 5 characters in battle\n"
				text += "- When determining enemy numbers, roll 1D6\n"
				text += "- Each character receives 100% of normal starting gear value\n"
			6:
				text += "- Begin the game with 6 characters\n"
				text += "- Deploy up to 6 characters in battle\n"
				text += "- When determining enemy numbers, roll 1D6+1\n"
				text += "- Each character receives 83% of normal starting gear value\n"
			7:
				text += "- Begin the game with 7 characters\n"
				text += "- Deploy up to 7 characters in battle\n"
				text += "- When determining enemy numbers, roll 1D6+2\n"
				text += "- Each character receives 71% of normal starting gear value\n"
			8:
				text += "- Begin the game with 8 characters\n"
				text += "- Deploy up to 8 characters in battle\n"
				text += "- When determining enemy numbers, roll 2D6 and use the higher result\n"
				text += "- Each character receives 62% of normal starting gear value\n"
	
	# Add victory condition information if selected
	if campaign_config.victory_condition != GlobalEnums.CampaignVictoryType.NONE:
		text += "\n[b]Victory Condition[/b]\n"
		if campaign_config.victory_condition == GlobalEnums.CampaignVictoryType.CUSTOM:
			text += "Custom: %s - Target: %d\n" % [campaign_config.custom_victory_data.type, campaign_config.custom_victory_data.value]
		else:
			# Find the victory condition in the loaded JSON data
			var victory_conditions = victory_data.get("victory_conditions", [])
			var condition_id = GlobalEnums.CampaignVictoryType.keys()[campaign_config.victory_condition].to_lower()
			
			var found_condition = null
			for condition in victory_conditions:
				if condition.get("id", "") == condition_id:
					found_condition = condition
					break
			
			if found_condition:
				text += found_condition.get("description", "No description available") + "\n"
			else:
				# Fallback to VictoryDescriptions if not found in JSON
				text += VictoryDescriptions.get_description(campaign_config.victory_condition) + "\n"
	
	variation_descriptions.text = text

func _on_lock_crew_size_pressed() -> void:
	crew_size_locked = true
	crew_size_slider.editable = false
	lock_crew_size_button.disabled = true
	lock_crew_size_button.text = "Crew Size Locked"
	
	# Update the tutorial text to guide the user
	var tutorial_label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/TutorialLabel
	tutorial_label.text = "Crew size locked. Set your victory condition and crew name to continue."
	
	_update_ui_state()

func _load_game_data() -> void:
	# Load equipment database
	var equipment_file := FileAccess.open(EQUIPMENT_DATA_PATH, FileAccess.READ)
	if equipment_file:
		var json_string = equipment_file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			equipment_data = json.get_data()
		equipment_file.close()
	
	# Load character creation data
	var character_file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	if character_file:
		var json_string = character_file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			character_data = json.get_data()
		character_file.close()
	
	# Load victory conditions data
	var victory_file := FileAccess.open(VICTORY_DATA_PATH, FileAccess.READ)
	if victory_file:
		var json_string = victory_file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			victory_data = json.get_data()
		victory_file.close()

func _finalize_campaign_setup() -> void:
	# Initialize game state with campaign configuration
	GameStateManager.initialize_campaign(campaign_config)
	
	# Emit signal that campaign setup is complete
	campaign_setup_completed.emit(campaign_config)
	
	# Clean up
	queue_free()
