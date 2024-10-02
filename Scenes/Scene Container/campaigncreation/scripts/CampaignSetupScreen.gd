class_name CampaignSetupScreen
extends Control

const DifficultySettingsResource = preload("res://Scenes/Scene Container/campaigncreation/scripts/DifficultySettings.gd")
const CrewSetup = preload("res://Resources/CrewSetup.gd")

@onready var difficulty_option_button: OptionButton = $MarginContainer/VBoxContainer/DifficultyOptionButton
@onready var victory_condition_container: HBoxContainer = $MarginContainer/VBoxContainer/VictoryConditionContainer
@onready var victory_type_label: Label = $MarginContainer/VBoxContainer/VictoryConditionContainer/VictoryTypeLabel
@onready var victory_count_label: Label = $MarginContainer/VBoxContainer/VictoryConditionContainer/VictoryCountLabel
@onready var optional_features_container: VBoxContainer = $MarginContainer/VBoxContainer/OptionalFeaturesContainer
@onready var start_campaign_button: Button = $MarginContainer/VBoxContainer/StartCampaignButton
@onready var crew_size_slider: HSlider = $MarginContainer/VBoxContainer/CrewSizeContainer/HSlider
@onready var current_size_label: Label = $MarginContainer/VBoxContainer/CrewSizeContainer/CurrentSizeLabel
@onready var crew_size_tutorial_label: Label = $MarginContainer/VBoxContainer/CrewSizeContainer/TutorialLabel

var game_state: GameStateManager
var difficulty_settings: DifficultySettingsResource
var victory_types = ["Missions", "Credits", "Reputation", "Story Points"]
var current_victory_type = 0
var current_victory_count = 5

func _ready():
	await get_tree().process_frame
	
	difficulty_settings = DifficultySettingsResource.new()
	game_state = GameStateManager.get_game_state()
	
	_setup_ui_elements()
	_setup_optional_features()
	_setup_victory_conditions()
	_setup_crew_size_selection()
	_connect_signals()
	_setup_animations()

func _setup_ui_elements():
	if difficulty_option_button:
		difficulty_option_button.clear()
		difficulty_option_button.add_item("Easy", DifficultySettings.DifficultyLevel.EASY)
		difficulty_option_button.add_item("Normal", DifficultySettings.DifficultyLevel.NORMAL)
		difficulty_option_button.add_item("Challenging", DifficultySettings.DifficultyLevel.CHALLENGING)
		difficulty_option_button.add_item("Hardcore", DifficultySettings.DifficultyLevel.HARDCORE)
		difficulty_option_button.add_item("Insanity", DifficultySettings.DifficultyLevel.INSANITY)
		difficulty_option_button.add_item("Basic Tutorial", DifficultySettings.DifficultyLevel.BASIC_TUTORIAL)
		difficulty_option_button.add_item("Advanced Tutorial", DifficultySettings.DifficultyLevel.ADVANCED_TUTORIAL)
	else:
		push_error("DifficultyOptionButton not found in the scene.")

func _setup_optional_features():
	var features = [
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

func _setup_victory_conditions():
	victory_type_label.text = victory_types[current_victory_type]
	victory_count_label.text = str(current_victory_count)
	
	var left_type_button = Button.new()
	left_type_button.text = "<"
	left_type_button.pressed.connect(_on_victory_type_left_pressed)
	victory_condition_container.add_child(left_type_button)
	
	var right_type_button = Button.new()
	right_type_button.text = ">"
	right_type_button.pressed.connect(_on_victory_type_right_pressed)
	victory_condition_container.add_child(right_type_button)
	
	var left_count_button = Button.new()
	left_count_button.text = "<"
	left_count_button.pressed.connect(_on_victory_count_left_pressed)
	victory_condition_container.add_child(left_count_button)
	
	var right_count_button = Button.new()
	right_count_button.text = ">"
	right_count_button.pressed.connect(_on_victory_count_right_pressed)
	victory_condition_container.add_child(right_count_button)

func _setup_crew_size_selection() -> void:
	_update_current_size_label(int(crew_size_slider.value))
	_setup_crew_size_tutorial()

func _setup_crew_size_tutorial() -> void:
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_step_active("crew_size_selection"):
		crew_size_tutorial_label.text = tutorial_manager.get_tutorial_text("crew_size_selection")
		crew_size_tutorial_label.show()
	else:
		crew_size_tutorial_label.hide()

func _on_crew_size_slider_value_changed(value: float) -> void:
	var crew_size = int(value)
	game_state.set_crew_size(crew_size)
	_update_current_size_label(crew_size)

func _update_current_size_label(crew_size: int) -> void:
	current_size_label.text = "Current Crew Size: %d" % crew_size

func _connect_signals():
	if difficulty_option_button:
		difficulty_option_button.item_selected.connect(_on_difficulty_selected)
	if start_campaign_button:
		start_campaign_button.pressed.connect(_on_start_campaign_button_pressed)
	if crew_size_slider:
		crew_size_slider.value_changed.connect(_on_crew_size_slider_value_changed)

func _setup_animations():
	for button in get_tree().get_nodes_in_group("animated_buttons"):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.button_down.connect(_on_button_pressed.bind(button))
		button.button_up.connect(_on_button_released.bind(button))

func _on_victory_type_left_pressed():
	current_victory_type = (current_victory_type - 1 + victory_types.size()) % victory_types.size()
	victory_type_label.text = victory_types[current_victory_type]

func _on_victory_type_right_pressed():
	current_victory_type = (current_victory_type + 1) % victory_types.size()
	victory_type_label.text = victory_types[current_victory_type]

func _on_victory_count_left_pressed():
	current_victory_count = max(1, current_victory_count - 1)
	victory_count_label.text = str(current_victory_count)

func _on_victory_count_right_pressed():
	current_victory_count += 1
	victory_count_label.text = str(current_victory_count)

func _on_difficulty_selected(index: int):
	var difficulty_level = difficulty_option_button.get_item_id(index)
	difficulty_settings.set_difficulty(difficulty_level)

func _on_start_campaign_button_pressed():
	if _validate_setup():
		_apply_settings()
		get_tree().change_scene_to_file("res://Scenes/Management/CrewManagement.tscn")

func _validate_setup() -> bool:
	if game_state.victory_condition == null:
		print_debug("Please select a victory condition.")
		return false
	if game_state.get_crew_size() == 0:
		print_debug("Please select a crew size.")
		return false
	return true

func _apply_settings() -> void:
	var crew_setup := get_node("/root/CrewSetup") as CrewSetup
	if not crew_setup:
		push_error("CrewSetup node not found. Make sure it's properly set up in the scene tree.")
		return

	# Apply difficulty settings
	crew_setup.set_difficulty_settings(difficulty_settings)

	# Apply optional features
	for checkbox in optional_features_container.get_children():
		if checkbox is CheckBox:
			var feature_name: String = checkbox.text.to_snake_case()
			crew_setup.set_optional_feature(feature_name, checkbox.button_pressed)

	# Apply victory condition
	game_state.set_victory_condition({
		"type": victory_types[current_victory_type],
		"value": current_victory_count
	})

	# Apply Story Track if enabled
	if crew_setup.get_optional_feature("story_track"):
		var story_track := StoryTrack.new()
		var game_state_node := get_node("/root/GameStateNode") as GameStateManager
		if game_state_node:
			story_track.initialize(game_state_node)
			game_state.set_story_track(story_track)
		else:
			push_error("GameStateManagerNode not found. Unable to initialize StoryTrack.")

	# Apply crew size
	crew_setup.set_crew_size(int(crew_size_slider.value))

func set_game_state(new_game_state):
	if new_game_state is GameStateManager:
		game_state = new_game_state
	else:
		push_error("Invalid game state type provided to CampaignSetupScreen")

func _on_button_mouse_entered(button: Button):
	button.scale = Vector2(1.05, 1.05)

func _on_button_mouse_exited(button: Button):
	button.scale = Vector2(1.0, 1.0)

func _on_button_pressed(button: Button):
	button.scale = Vector2(0.95, 0.95)

func _on_button_released(button: Button):
	button.scale = Vector2(1.0, 1.0)

func _on_crew_name_input_text_changed(new_text: String) -> void:
	if game_state:
		game_state.set_crew_name(new_text)
	else:
		push_warning("GameState not available. Crew name not saved.")

func _on_difficulty_option_button_item_selected(index: int) -> void:
	var difficulty_level = difficulty_option_button.get_item_id(index)
	difficulty_settings.set_difficulty(difficulty_level)
	if game_state:
		game_state.set_difficulty(difficulty_level)
	else:
		push_warning("GameState not available. Difficulty not saved.")

func _on_victory_condition_button_pressed() -> void:
	var victory_condition_selection = $VictoryConditionSelection
	if victory_condition_selection:
		victory_condition_selection.visible = true
	else:
		push_error("VictoryConditionSelection node not found in the scene.")
