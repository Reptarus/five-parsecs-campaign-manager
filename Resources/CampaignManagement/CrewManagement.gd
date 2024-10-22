# Scenes/Management/CrewManagement.gd
class_name CrewManagement
extends Control

signal crew_finalized

@onready var game_state_manager: Node = get_node("/root/GameStateManager")
@onready var crew_grid: GridContainer = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent/CrewGrid
@onready var character_display: Control = $CharacterDisplay
@onready var finalize_crew_button: Button = $FinalizeCrew
@onready var create_character_button: Button = $CreateCharacterButton

const MAX_CREW_SIZE = 8

func _ready() -> void:
	print("Starting _ready function in CrewManagement")
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found in the scene tree.")
		return
	
	var game_state = game_state_manager.get_internal_game_state()
	if not game_state:
		push_error("Failed to get GameState from GameStateManager.")
		return
	
	if not game_state.crew:
		push_error("Crew not initialized. Initializing with default values.")
		game_state.crew = Crew.new()
	
	setup_crew_slots()
	update_crew_display()

func _initialize_default_game_state() -> void:
	if not game_state_manager.game_state:
		game_state_manager.game_state = MockGameState.new()
	if not game_state_manager.game_state.crew:
		game_state_manager.game_state.crew = Crew.new()

func setup_crew_slots() -> void:
	for i in range(MAX_CREW_SIZE):
		var character_slot = Panel.new()
		character_slot.connect("gui_input", _on_character_slot_pressed.bind(i))
		crew_grid.add_child(character_slot)

func update_crew_display() -> void:
	var crew = game_state_manager.get_crew()
	for i in range(crew_grid.get_child_count()):
		var character_slot = crew_grid.get_child(i)
		if i < crew.size():
			var character = crew[i]
			_update_character_slot(character_slot, character)
		else:
			_clear_character_slot(character_slot)

func _update_character_slot(slot: Panel, character: CrewMember) -> void:
	# Update the slot with character information
	# This is a placeholder - implement actual UI update logic
	var label = Label.new()
	label.text = character.name
	slot.add_child(label)

func _clear_character_slot(slot: Panel) -> void:
	# Clear the slot
	for child in slot.get_children():
		child.queue_free()

func _on_character_slot_pressed(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var crew = game_state_manager.get_crew()
		if slot_index < crew.size():
			_show_character_details(crew[slot_index])
		else:
			_create_new_character()

func _show_character_details(character: CrewMember) -> void:
	# Implement character details display logic
	print("Showing details for character: ", character.name)

func _create_new_character() -> void:
	var crew = game_state_manager.get_crew()
	if crew.size() < MAX_CREW_SIZE:
		var new_character = CrewMember.new()  # Implement character creation logic
		crew.append(new_character)
		update_crew_display()
	else:
		push_error("Cannot add character. Crew is at maximum capacity.")

func _on_finalize_crew_button_pressed() -> void:
	var crew = game_state_manager.get_crew()
	if crew.size() > 0:
		game_state_manager.current_state = GlobalEnums.CampaignPhase.UPKEEP
		get_tree().change_scene_to_file("res://Scenes/Management/CampaignDashboard.tscn")
	else:
		push_warning("Crew is empty. Add at least one crew member before finalizing.")

func _on_create_character_button_pressed() -> void:
	_create_new_character()
