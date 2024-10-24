class_name CampaignSetupScreen
extends Control

const DifficultySettingsResource = preload("res://Resources/GameData/DifficultySettings.gd")

signal campaign_setup_completed

@export var victory_types: Array[String] = ["Missions", "Credits", "Reputation", "Story Points"]

@onready var difficulty_option_button: OptionButton = $HBoxContainer/LeftPanel/VBoxContainer/DifficultyOptionButton
@onready var victory_condition_container: HBoxContainer = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer
@onready var victory_type_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryTypeLabel
@onready var victory_count_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/VictoryCountLabel
@onready var optional_features_container: VBoxContainer = $HBoxContainer/LeftPanel/VBoxContainer/OptionalFeaturesContainer
@onready var start_campaign_button: Button = $HBoxContainer/LeftPanel/VBoxContainer/StartCampaignButton
@onready var crew_size_slider: HSlider = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/HSlider
@onready var current_size_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/CurrentSizeLabel
@onready var crew_size_tutorial_label: Label = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/TutorialLabel
@onready var set_victory_condition_button: Button = $HBoxContainer/LeftPanel/VBoxContainer/VictoryConditionContainer/SetVictoryConditionButton
@onready var lock_crew_size_button: Button = $HBoxContainer/LeftPanel/VBoxContainer/CrewSizeContainer/LockCrewSizeButton
@onready var variation_descriptions: VBoxContainer = $HBoxContainer/RightPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/VariationDescriptions
@onready var message_label: Label = $HBoxContainer/RightPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/VariationDescriptions/MessageLabel

var game_state_manager: MockGameState
var difficulty_settings: DifficultySettingsResource
var current_victory_type: int = 0
var current_victory_count: int = 5

var feature_descriptions: Dictionary = {
	"Loans": "Enable the ability to take out loans for financial flexibility.",
	"Story Track": "Follow a narrative-driven campaign with branching storylines.",
	"Expanded Factions": "Interact with a wider variety of factions and political entities.",
	"Progressive Difficulty": "Face increasingly challenging missions as your campaign progresses.",
	"Fringe World Strife": "Navigate conflicts in remote, lawless sectors of space.",
	"Dramatic Combat": "Experience more intense and cinematic battle scenarios.",
	"Casualty Tables": "Deal with realistic consequences of combat injuries.",
	"Detailed Post-Battle Injuries": "Manage complex injury recovery for your crew.",
	"AI Variations": "Encounter diverse and unpredictable AI behaviors.",
	"Enemy Deployment Variables": "Face varied enemy compositions and strategies.",
	"Escalating Battles": "Participate in larger-scale conflicts as your reputation grows.",
	"Elite-Level Enemies": "Confront highly skilled and well-equipped adversaries.",
	"Expanded Missions": "Access a wider variety of mission types and objectives.",
	"Expanded Quest Progression": "Engage in more complex and interconnected quest lines.",
	"Expanded Connections": "Develop deeper relationships with NPCs and factions."
}

func _ready() -> void:
	await get_tree().process_frame
	
	game_state_manager = load("res://Resources/MockGameState.gd").new()
	if not game_state_manager:
		push_error("Failed to load MockGameState resource.")
		return

	if not game_state_manager.has_method("get_game_state"):
		push_error("MockGameState doesn't have the expected interface.")
		return

	if message_label:
		message_label.visible = true
		message_label.custom_minimum_size = Vector2(300, 0)

	if _check_required_nodes():
		_setup_victory_conditions()
		_setup_ui_elements()
		_setup_optional_features()
		_setup_crew_size_selection()
		_connect_signals()
		_setup_animations()
		_show_tutorial_popup()
	else:
		push_error("Some required nodes are missing. Please check your scene structure and node names.")

func _check_required_nodes() -> bool:
	var all_nodes_present := true

	if not victory_condition_container or not victory_type_label or not victory_count_label:
		push_error("Some required nodes for victory conditions are missing. Check your scene structure.")
		all_nodes_present = false

	if not difficulty_option_button:
		push_error("DifficultyOptionButton not found in the scene.")
		all_nodes_present = false

	if not optional_features_container:
		push_error("OptionalFeaturesContainer not found. Check the scene structure and node names.")
		all_nodes_present = false

	if not crew_size_slider or not current_size_label or not crew_size_tutorial_label:
		push_error("Some required nodes for crew size selection are missing. Check your scene structure.")
		all_nodes_present = false

	if not variation_descriptions:
		push_error("VariationDescriptions node not found. Check your scene structure.")
		all_nodes_present = false

	return all_nodes_present

func _setup_ui_elements() -> void:
	difficulty_option_button.clear()
	for mode in GlobalEnums.DifficultyMode.keys():
		difficulty_option_button.add_item(mode, GlobalEnums.DifficultyMode[mode])

func _setup_optional_features() -> void:
	for feature in feature_descriptions.keys():
		var checkbox := CheckBox.new()
		checkbox.text = feature
		checkbox.toggled.connect(_on_feature_toggled.bind(feature))
		optional_features_container.add_child(checkbox)

func _on_feature_toggled(button_pressed: bool, feature: String) -> void:
	if button_pressed:
		_add_feature_description(feature)
	else:
		_remove_feature_description(feature)

func _add_feature_description(feature: String) -> void:
	var label := Label.new()
	label.text = feature_descriptions[feature]
	label.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	label.name = feature.replace(" ", "_") + "_Description"
	if variation_descriptions:
		variation_descriptions.add_child(label)
	else:
		push_error("VariationDescriptions node not found in the scene.")

func _remove_feature_description(feature: String) -> void:
	if variation_descriptions:
		var description_node := variation_descriptions.get_node_or_null(feature.replace(" ", "_") + "_Description")
		if description_node:
			description_node.queue_free()
	else:
		push_error("VariationDescriptions node not found in the scene.")

func _setup_victory_conditions() -> void:
	victory_type_label.text = victory_types[current_victory_type]
	victory_count_label.text = str(current_victory_count)
	
	_add_victory_buttons()

	if set_victory_condition_button:
		set_victory_condition_button.pressed.connect(_on_set_victory_condition_pressed)
	else:
		push_error("SetVictoryConditionButton not found in the scene.")

func _add_victory_buttons() -> void:
	var left_type_button := Button.new()
	left_type_button.text = "<"
	left_type_button.pressed.connect(_on_victory_type_left_pressed)
	victory_condition_container.add_child(left_type_button)
	
	var right_type_button := Button.new()
	right_type_button.text = ">"
	right_type_button.pressed.connect(_on_victory_type_right_pressed)
	victory_condition_container.add_child(right_type_button)
	
	var left_count_button := Button.new()
	left_count_button.text = "<"
	left_count_button.pressed.connect(_on_victory_count_left_pressed)
	victory_condition_container.add_child(left_count_button)
	
	var right_count_button := Button.new()
	right_count_button.text = ">"
	right_count_button.pressed.connect(_on_victory_count_right_pressed)
	victory_condition_container.add_child(right_count_button)

func _setup_crew_size_selection() -> void:
	if crew_size_slider:
		_update_current_size_label(int(crew_size_slider.value))
	else:
		push_error("crew_size_slider is null. Make sure it's properly set up in the scene.")
	_setup_crew_size_tutorial()

func _setup_crew_size_tutorial() -> void:
	# Implement tutorial logic if needed
	pass

func _on_crew_size_slider_value_changed(value: float) -> void:
	var crew_size := int(value)
	if game_state_manager:
		game_state_manager.crew_size = crew_size
	else:
		push_error("GameStateManager is not initialized")
	_update_current_size_label(crew_size)

func _update_current_size_label(crew_size: int) -> void:
	if current_size_label:
		current_size_label.text = "Current Crew Size: %d" % crew_size
	else:
		push_error("current_size_label is null. Make sure it's properly set up in the scene.")

func _connect_signals() -> void:
	if not start_campaign_button.is_connected("pressed", _on_start_campaign_button_pressed):
		start_campaign_button.pressed.connect(_on_start_campaign_button_pressed)
	
	if not crew_size_slider.is_connected("value_changed", _on_crew_size_slider_value_changed):
		crew_size_slider.value_changed.connect(_on_crew_size_slider_value_changed)
	
	if not set_victory_condition_button.is_connected("pressed", _on_set_victory_condition_pressed):
		set_victory_condition_button.pressed.connect(_on_set_victory_condition_pressed)

func _on_lock_crew_size_pressed() -> void:
	if game_state_manager:
		var crew_size := int(crew_size_slider.value)
		
		print_debug("Crew size locked at: ", crew_size)
		
		update_message("Confirming crew size: " + str(crew_size))
		
		var confirm_dialog := AcceptDialog.new()
		confirm_dialog.dialog_text = "Crew size locked at " + str(crew_size) + ". This cannot be changed later. Proceed?"
		confirm_dialog.get_ok_button().text = "Confirm"
		confirm_dialog.add_cancel_button("Cancel")
		add_child(confirm_dialog)
		
		confirm_dialog.confirmed.connect(func():
			_finalize_crew_size(crew_size)
		)
		
		confirm_dialog.canceled.connect(func():
			print_debug("Crew size locking cancelled.")
			update_message("Crew size locking cancelled.")
		)
		
		confirm_dialog.popup_centered()
	else:
		push_error("GameStateManager is not initialized")

func _finalize_crew_size(crew_size: int) -> void:
	game_state_manager.crew_size = crew_size
	
	crew_size_slider.editable = false
	_update_current_size_label(crew_size)
	
	print_debug("Crew size finalized at: ", crew_size)
	
	update_message("Crew size finalized at: " + str(crew_size) + ". Initial crew members generated.")
	
	await get_tree().create_timer(2.0).timeout
	
	get_tree().change_scene_to_file("res://Resources/CrewAndCharacters/InitialCrewCreation.tscn")

func _setup_animations() -> void:
	for button in get_tree().get_nodes_in_group("animated_buttons"):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.button_down.connect(_on_button_pressed.bind(button))
		button.button_up.connect(_on_button_released.bind(button))

func _on_victory_type_left_pressed() -> void:
	current_victory_type = (current_victory_type - 1 + victory_types.size()) % victory_types.size()
	victory_type_label.text = victory_types[current_victory_type]

func _on_victory_type_right_pressed() -> void:
	current_victory_type = (current_victory_type + 1) % victory_types.size()
	victory_type_label.text = victory_types[current_victory_type]

func _on_victory_count_left_pressed() -> void:
	current_victory_count = max(1, current_victory_count - 1)
	victory_count_label.text = str(current_victory_count)

func _on_victory_count_right_pressed() -> void:
	current_victory_count += 1
	victory_count_label.text = str(current_victory_count)

func _on_difficulty_selected(index: int) -> void:
	var difficulty_level := difficulty_option_button.get_item_id(index)
	difficulty_settings.set_difficulty(difficulty_level)

func _on_start_campaign_button_pressed() -> void:
	if _validate_setup():
		_apply_settings()
		_show_tutorial_popup()
		await get_tree().create_timer(0.1).timeout
		get_tree().change_scene_to_file("res://Resources/CrewAndCharacters/InitialCrewCreation.tscn")

func _validate_setup() -> bool:
	if game_state_manager.victory_condition.is_empty():
		print_debug("Please set a victory condition.")
		return false
	if game_state_manager.crew_size == 0:
		print_debug("Please select a crew size.")
		return false
	return true

func _apply_settings() -> void:
	game_state_manager.difficulty_settings = difficulty_settings

	for checkbox in optional_features_container.get_children():
		if checkbox is CheckBox:
			var feature_name: String = checkbox.text.to_snake_case()
			game_state_manager.set(feature_name, checkbox.button_pressed)

	game_state_manager.victory_condition = {
		"type": GlobalEnums.VictoryConditionType.keys()[current_victory_type],
		"value": current_victory_count
	}

	game_state_manager.crew_size = int(crew_size_slider.value)

func _on_button_mouse_entered(button: Button) -> void:
	button.scale = Vector2(1.05, 1.05)

func _on_button_mouse_exited(button: Button) -> void:
	button.scale = Vector2(1.0, 1.0)

func _on_button_pressed(button: Button) -> void:
	button.scale = Vector2(0.95, 0.95)

func _on_button_released(button: Button) -> void:
	button.scale = Vector2(1.0, 1.0)

func _on_set_victory_condition_pressed() -> void:
	game_state_manager.victory_condition = {
		"type": GlobalEnums.VictoryConditionType.keys()[current_victory_type],
		"value": current_victory_count
	}
	print("Victory condition set: ", game_state_manager.victory_condition)
	for child in victory_condition_container.get_children():
		if child is Button:
			child.disabled = true
	set_victory_condition_button.disabled = true

func _show_tutorial_popup() -> void:
	var tutorial_popup := AcceptDialog.new()
	tutorial_popup.dialog_text = "Welcome to the Campaign Setup! Here you can customize your campaign settings."
	add_child(tutorial_popup)
	tutorial_popup.popup_centered()

func update_message(text: String) -> void:
	if message_label:
		message_label.text = text
	else:
		push_error("MessageLabel not found in the scene.")
