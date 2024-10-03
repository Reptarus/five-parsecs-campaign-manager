class_name CampaignSetupScreen
extends Control

const DifficultySettingsResource = preload("res://Scenes/Scene Container/campaigncreation/scripts/DifficultySettings.gd")

@onready var difficulty_option_button: OptionButton = $MarginContainer/VBoxContainer/DifficultyOptionButton
@onready var victory_condition_container: HBoxContainer = $MarginContainer/VBoxContainer/VictoryConditionContainer
@onready var victory_type_label: Label = $MarginContainer/VBoxContainer/VictoryConditionContainer/VictoryTypeLabel
@onready var victory_count_label: Label = $MarginContainer/VBoxContainer/VictoryConditionContainer/VictoryCountLabel
@onready var optional_features_container: VBoxContainer = $MarginContainer/VBoxContainer/OptionalFeaturesContainer
@onready var start_campaign_button: Button = $MarginContainer/VBoxContainer/StartCampaignButton
@onready var crew_size_slider: HSlider = $MarginContainer/VBoxContainer/CrewSizeContainer/HSlider
@onready var current_size_label: Label = $MarginContainer/VBoxContainer/CrewSizeContainer/CurrentSizeLabel
@onready var crew_size_tutorial_label: Label = $MarginContainer/VBoxContainer/CrewSizeContainer/TutorialLabel
@onready var set_victory_condition_button: Button = $MarginContainer/VBoxContainer/VictoryConditionContainer/SetVictoryConditionButton
@onready var lock_crew_size_button: Button = $MarginContainer/VBoxContainer/CrewSizeContainer/LockCrewSizeButton

var game_state_manager: GameStateManager
var difficulty_settings: DifficultySettingsResource
var victory_types = ["Missions", "Credits", "Reputation", "Story Points"]
var current_victory_type = 0
var current_victory_count = 5

func _ready():
	await get_tree().process_frame
	
	difficulty_settings = DifficultySettingsResource.new()
	
	# Use the GameStateManager autoload
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager autoload not found. Make sure it's properly set up in Project Settings.")
		return

	if victory_condition_container and victory_type_label and victory_count_label:
		_setup_victory_conditions()
	else:
		push_error("Some required nodes for victory conditions are missing. Check your scene structure.")

	_setup_ui_elements()
	_setup_optional_features()
	_setup_crew_size_selection()
	_connect_signals()
	_setup_animations()

func _setup_ui_elements():
	if difficulty_option_button:
		difficulty_option_button.clear()
		for mode in GlobalEnums.DifficultyMode.keys():
			difficulty_option_button.add_item(mode, GlobalEnums.DifficultyMode[mode])
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
	
	# Add "Set Victory Condition" button
	if set_victory_condition_button:
		set_victory_condition_button.pressed.connect(_on_set_victory_condition_pressed)
	else:
		push_error("SetVictoryConditionButton not found in the scene.")

func _setup_crew_size_selection() -> void:
	_update_current_size_label(int(crew_size_slider.value))
	_setup_crew_size_tutorial()

func _setup_crew_size_tutorial() -> void:
	# Implement tutorial logic if needed
	pass

func _on_crew_size_slider_value_changed(value: float) -> void:
	var crew_size = int(value)
	if game_state_manager:
		game_state_manager.game_state.crew_size = crew_size
	else:
		push_error("GameStateManager is not initialized")
	_update_current_size_label(crew_size)

func _update_current_size_label(crew_size: int) -> void:
	current_size_label.text = "Current Crew Size: %d" % crew_size

func _connect_signals():
	if difficulty_option_button:
		if not difficulty_option_button.is_connected("item_selected", _on_difficulty_selected):
			difficulty_option_button.item_selected.connect(_on_difficulty_selected)
	if start_campaign_button:
		if not start_campaign_button.is_connected("pressed", _on_start_campaign_button_pressed):
			start_campaign_button.pressed.connect(_on_start_campaign_button_pressed)
	if crew_size_slider:
		if not crew_size_slider.is_connected("value_changed", _on_crew_size_slider_value_changed):
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
	if game_state_manager.game_state.victory_condition.is_empty():
		print_debug("Please set a victory condition.")
		return false
	if game_state_manager.game_state.crew_size == 0:
		print_debug("Please select a crew size.")
		return false
	return true

func _apply_settings() -> void:
	# Apply difficulty settings
	game_state_manager.game_state.difficulty_settings = difficulty_settings

	# Apply optional features
	for checkbox in optional_features_container.get_children():
		if checkbox is CheckBox:
			var feature_name: String = checkbox.text.to_snake_case()
			# Assuming game_state has a dictionary for optional features
			game_state_manager.game_state.set(feature_name, checkbox.button_pressed)

	# Apply victory condition
	game_state_manager.game_state.victory_condition = {
		"type": GlobalEnums.VictoryConditionType.keys()[current_victory_type],
		"value": current_victory_count
	}

	# Apply crew size
	game_state_manager.game_state.crew_size = int(crew_size_slider.value)

func _on_button_mouse_entered(button: Button):
	button.scale = Vector2(1.05, 1.05)

func _on_button_mouse_exited(button: Button):
	button.scale = Vector2(1.0, 1.0)

func _on_button_pressed(button: Button):
	button.scale = Vector2(0.95, 0.95)

func _on_button_released(button: Button):
	button.scale = Vector2(1.0, 1.0)

func _on_set_victory_condition_pressed():
	game_state_manager.game_state.victory_condition = {
		"type": GlobalEnums.VictoryConditionType.keys()[current_victory_type],
		"value": current_victory_count
	}
	print("Victory condition set: ", game_state_manager.game_state.victory_condition)
	# Optionally, disable the victory condition selection after setting
	for child in victory_condition_container.get_children():
		if child is Button:
			child.disabled = true
	set_victory_condition_button.disabled = true
