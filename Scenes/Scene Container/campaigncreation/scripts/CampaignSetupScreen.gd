extends Control

const DifficultySettingsResource = preload("res://Scenes/Scene Container/campaigncreation/scripts/DifficultySettings.gd")

@onready var crew_name_input = $VBoxContainer/CrewNameInput
@onready var difficulty_option_button = $VBoxContainer/DifficultyOptionButton
@onready var victory_condition_button = $VBoxContainer/VictoryConditionButton
@onready var optional_features_container = $VBoxContainer/OptionalFeaturesContainer
@onready var start_campaign_button = $VBoxContainer/StartCampaignButton

var game_state: GameState
var difficulty_settings: DifficultySettingsResource

func _ready():
	difficulty_settings = DifficultySettingsResource.new()
	
	difficulty_option_button.add_item("Easy", DifficultySettings.DifficultyLevel.EASY)
	difficulty_option_button.add_item("Normal", DifficultySettings.DifficultyLevel.NORMAL)
	difficulty_option_button.add_item("Hard", DifficultySettings.DifficultyLevel.HARD)
	
	_setup_optional_features()
	
	victory_condition_button.connect("pressed", Callable(self, "_on_victory_condition_button_pressed"))
	start_campaign_button.connect("pressed", Callable(self, "_on_start_campaign_button_pressed"))
	difficulty_option_button.connect("item_selected", Callable(self, "_on_difficulty_selected"))

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

func _on_victory_condition_button_pressed():
	# Open VictoryConditionSelection scene
	var victory_condition_scene = load("res://scenes/VictoryConditionSelection.tscn").instantiate()
	victory_condition_scene.connect("condition_selected", Callable(self, "_on_victory_condition_selected"))
	add_child(victory_condition_scene)

func _on_victory_condition_selected(condition):
	game_state.victory_condition = condition
	victory_condition_button.text = "Victory Condition: " + condition.name

func _on_difficulty_selected(index: int):
	var difficulty_level = difficulty_option_button.get_item_id(index)
	difficulty_settings.set_difficulty(difficulty_level)

func _on_start_campaign_button_pressed():
	if _validate_setup():
		_apply_settings()
		# Transition to the main game scene
		get_tree().change_scene_to_file("res://scenes/MainGameScene.tscn")

func _validate_setup() -> bool:
	if crew_name_input.text.strip_edges() == "":
		print("Please enter a crew name.")
		return false
	if game_state.victory_condition == null:
		print("Please select a victory condition.")
		return false
	return true

func _apply_settings():
	game_state.current_crew.name = crew_name_input.text.strip_edges()
	game_state.difficulty_settings = difficulty_settings
	
	for checkbox in optional_features_container.get_children():
		match checkbox.text:
			"Introductory Campaign":
				game_state.use_introductory_campaign = checkbox.pressed
			"Loans":
				game_state.use_loans = checkbox.pressed
			"Story Track":
				game_state.use_story_track = checkbox.pressed
			"Expanded Factions":
				game_state.use_expanded_factions = checkbox.pressed
			"Progressive Difficulty":
				game_state.use_progressive_difficulty = checkbox.pressed
			"Fringe World Strife":
				game_state.use_fringe_world_strife = checkbox.pressed
			"Dramatic Combat":
				game_state.use_dramatic_combat = checkbox.pressed
			"Casualty Tables":
				game_state.use_casualty_tables = checkbox.pressed
			"Detailed Post-Battle Injuries":
				game_state.use_detailed_post_battle_injuries = checkbox.pressed
			"AI Variations":
				game_state.use_ai_variations = checkbox.pressed
			"Enemy Deployment Variables":
				game_state.use_enemy_deployment_variables = checkbox.pressed
			"Escalating Battles":
				game_state.use_escalating_battles = checkbox.pressed
			"Elite-Level Enemies":
				game_state.use_elite_level_enemies = checkbox.pressed
			"Expanded Missions":
				game_state.use_expanded_missions = checkbox.pressed
			"Expanded Quest Progression":
				game_state.use_expanded_quest_progression = checkbox.pressed
			"Expanded Connections":
				game_state.use_expanded_connections = checkbox.pressed
	
	# Apply difficulty settings to the game state
	game_state.apply_difficulty_settings()
