class_name InitialCrewCreation
extends Control

@onready var character_columns := [
	$HBoxContainer/LeftPanel/VBoxContainer/CharacterColumns/CharacterColumn1,
	$HBoxContainer/LeftPanel/VBoxContainer/CharacterColumns/CharacterColumn2
]
@onready var confirm_button := $HBoxContainer/LeftPanel/VBoxContainer/ConfirmButton

var current_phase: GlobalEnums.CampaignPhase

func _ready() -> void:
	if not GameStateManager:
		push_error("GameStateManager not found. Ensure it's properly set up.")
		return
	current_phase = GameStateManager.get_game_state()
	
	setup_ui()
	connect_signals()
	
	# Initialize crew if not exists
	if not GameStateManager.game_state.crew:
		GameStateManager.game_state.crew = Crew.new()
	
	update_character_panels()

func setup_ui() -> void:
	update_character_panels()

func update_character_panels() -> void:
	var crew = GameStateManager.game_state.crew
	for i in range(8):
		# warning-ignore:integer_division
		var panel = character_columns[i / 4].get_child(i % 4)
		if i < crew.get_crew_size():
			update_panel_with_character(panel, crew.get_character(i))
		else:
			reset_panel(panel)

func reset_panel(panel: Panel) -> void:
	var name_label = panel.get_node_or_null("HBoxContainer/VBoxContainer/Name")
	var species_label = panel.get_node_or_null("HBoxContainer/VBoxContainer/Species")
	var class_label = panel.get_node_or_null("HBoxContainer/VBoxContainer/Class")
	
	if name_label:
		name_label.text = "Click to Create"
	if species_label:
		species_label.text = ""
	if class_label:
		class_label.text = ""

func connect_signals() -> void:
	for column in character_columns:
		for panel in column.get_children():
			if panel is Panel:
				panel.gui_input.connect(_on_character_panel_input.bind(panel))
	
	confirm_button.pressed.connect(_on_confirm_button_pressed)

func _on_character_panel_input(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var character_index = get_character_index(panel)
		_on_character_panel_pressed(character_index)

func _on_character_panel_pressed(character_index: int) -> void:
	GameStateManager.temp_data["editing_character_index"] = character_index
	get_tree().change_scene_to_file("res://Scenes/Scene Container/campaigncreation/CharacterCreator.tscn")

func get_character_index(panel: Panel) -> int:
	var index := 0
	for column in character_columns:
		for child in column.get_children():
			if child == panel:
				return index
			index += 1
	return -1

func _on_confirm_button_pressed() -> void:
	var crew = GameStateManager.game_state.crew
	if crew.get_crew_size() == Crew.MAX_CREW_SIZE:
		get_tree().change_scene_to_file("res://Scenes/campaign/NewCampaignSetup/ShipCreation.tscn")
	else:
		print("Please create all 8 characters before confirming.")

func update_panel_with_character(panel: Panel, character: CrewMember) -> void:
	panel.get_node("HBoxContainer/VBoxContainer/Name").text = character.name
	panel.get_node("HBoxContainer/VBoxContainer/Species").text = character.species
	panel.get_node("HBoxContainer/VBoxContainer/Class").text = character.character_class

# Connect this function to the "back" button in CharacterCreator scene
func _on_back_from_character_creator() -> void:
	get_tree().change_scene_to_file("res://Scenes/Scene Container/InitialCrewCreation.tscn")
