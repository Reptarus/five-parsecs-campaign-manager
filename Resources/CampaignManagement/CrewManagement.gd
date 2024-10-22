# Scenes/Management/CrewManagement.gd
class_name CrewManagement
extends Control

signal crew_finalized

@onready var game_state_manager: Node = get_node("/root/GameStateManager")
@onready var crew_list: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/CrewOverview/CrewList
@onready var character_sheet: Control = $MarginContainer/VBoxContainer/HSplitContainer/CharacterDetails/CharacterSheet
@onready var finalize_crew_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/FinalizeCrew
@onready var create_character_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/CreateCharacterButton

const MAX_CREW_SIZE = 8
const CharacterBox = preload("res://Resources/CrewAndCharacters/Scenes/CharacterBox.tscn")

func _ready() -> void:
	print("Starting _ready function in CrewManagement")
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
	
	update_crew_display()
	character_sheet.hide()

func update_crew_display() -> void:
	var crew = game_state_manager.get_crew()
	for child in crew_list.get_children():
		child.queue_free()
	
	for character in crew:
		var character_box = CharacterBox.instantiate()
		character_box.set_character(character)
		character_box.connect("gui_input", _on_character_box_gui_input.bind(character))
		crew_list.add_child(character_box)

func _on_character_box_gui_input(event: InputEvent, character: CrewMember) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_character_details(character)

func show_character_details(character: CrewMember) -> void:
	character_sheet.set_character(character)
	character_sheet.show()

func _on_create_character_button_pressed() -> void:
	var crew = game_state_manager.get_crew()
	if crew.size() < MAX_CREW_SIZE:
		var new_character = CrewMember.new()  # Implement character creation logic
		crew.append(new_character)
		update_crew_display()
		show_character_details(new_character)
	else:
		push_error("Cannot add character. Crew is at maximum capacity.")

func _on_finalize_crew_button_pressed() -> void:
	var crew = game_state_manager.get_crew()
	if crew.size() > 0:
		game_state_manager.current_state = GlobalEnums.CampaignPhase.UPKEEP
		emit_signal("crew_finalized")
	else:
		push_warning("Crew is empty. Add at least one crew member before finalizing.")

func _on_character_sheet_item_dropped(item, target_slot) -> void:
	# Implement item swapping logic here
	pass
