extends Control

const DifficultySettingsResource = preload("res://Scenes/Scene Container/campaigncreation/scripts/DifficultySettings.gd")

@onready var crew_name_input: LineEdit = $VBoxContainer/CrewNameInput
@onready var difficulty_option_button: OptionButton = $VBoxContainer/DifficultyOptionButton
@onready var victory_condition_button: Button = $VBoxContainer/VictoryConditionButton
@onready var optional_features_container: VBoxContainer = $VBoxContainer/OptionalFeaturesContainer
@onready var start_campaign_button: Button = $VBoxContainer/StartCampaignButton

var game_state: GameState
var difficulty_settings: DifficultySettingsResource

func _ready():
	await get_tree().process_frame
	
	difficulty_settings = DifficultySettingsResource.new()
	
	_setup_ui_elements()
	_setup_optional_features()
	_connect_signals()

func _setup_ui_elements():
	if difficulty_option_button:
		difficulty_option_button.add_item("Easy", DifficultySettings.DifficultyLevel.EASY)
		difficulty_option_button.add_item("Normal", DifficultySettings.DifficultyLevel.NORMAL)
		difficulty_option_button.add_item("Hard", DifficultySettings.DifficultyLevel.HARD)
	else:
		push_error("DifficultyOptionButton not found in the scene.")

func _setup_optional_features():
	var features = [
		"Introductory Campaign",
		"Loans",
		"Story Track",
		"Expanded Factions",
		"Progressive Difficulty",
		"Fringe World Strife",
		"Dramatic Combat",
		"Casualty Tables",
		"Detailed Post-Battle Injuries",
		"AI Variations",
		"Enemy Deployment Variables",
		"Escalating Battles",
		"Elite-Level Enemies",
		"Expanded Missions",
		"Expanded Quest Progression",
		"Expanded Connections"
	]
	
	for feature in features:
		var checkbox = CheckBox.new()
		checkbox.text = feature
		optional_features_container.add_child(checkbox)

func _connect_signals():
	if difficulty_option_button:
		difficulty_option_button.item_selected.connect(_on_difficulty_selected)
	if victory_condition_button:
		victory_condition_button.pressed.connect(_on_victory_condition_button_pressed)
	if start_campaign_button:
		start_campaign_button.pressed.connect(_on_start_campaign_button_pressed)

func _on_victory_condition_button_pressed():
	var victory_condition_scene = load("res://Scenes/Scene Container/campaigncreation/scenes/VictoryConditionSelection.tscn").instantiate()
	victory_condition_scene.condition_selected.connect(_on_victory_condition_selected)
	add_child(victory_condition_scene)

func _on_victory_condition_selected(condition):
	game_state.set_victory_condition(condition)
	victory_condition_button.text = "Victory Condition: " + condition["type"] + " - " + str(condition["value"])

func _on_difficulty_selected(index: int):
	var difficulty_level = difficulty_option_button.get_item_id(index)
	difficulty_settings.set_difficulty(difficulty_level)

func _on_start_campaign_button_pressed():
	if _validate_setup():
		_apply_settings()
		get_tree().change_scene_to_file("res://scenes/MainGameScene.tscn")

func _validate_setup() -> bool:
	if crew_name_input.text.strip_edges().is_empty():
		print_debug("Please enter a crew name.")
		return false
	if game_state.victory_condition == null:
		print_debug("Please select a victory condition.")
		return false
	return true

func _apply_settings():
	game_state.current_crew.name = crew_name_input.text.strip_edges()
	game_state.difficulty_settings = difficulty_settings
	
	for checkbox in optional_features_container.get_children():
		var feature_name = checkbox.text.to_snake_case()
		if game_state.has("use_" + feature_name):
			game_state.set("use_" + feature_name, checkbox.button_pressed)
	
	game_state.apply_difficulty_settings()

func set_game_state(new_game_state):
	game_state = new_game_state
