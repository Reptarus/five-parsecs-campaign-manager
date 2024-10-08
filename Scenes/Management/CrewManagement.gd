# Scenes/Management/CrewManagement.gd

extends Control

signal crew_finalized

@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")
@onready var crew_grid: GridContainer = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent/CrewGrid
@onready var character_display: Control = $CharacterDisplay
@onready var finalize_crew_button: Button = $FinalizeCrew
@onready var create_character_button: Button = $CreateCharacterButton

var character_creator_scene = preload("res://Scenes/Scene Container/campaigncreation/CharacterCreator.tscn")
var character_box_scene = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterBox.tscn")

const DEFAULT_CREW_SIZE = 8

@export var current_crew: Crew

func _ready() -> void:
	print("Starting _ready function in CrewManagement")
	var game_state_manager = get_node("/root/GameStateManager")
	print("GameStateManager node: ", game_state_manager)
	if game_state_manager != null:
		print("GameStateManager methods: ", game_state_manager.get_method_list())
	
	if game_state_manager == null:
		push_error("GameStateManager not found in the scene tree.")
		return
	
	if not game_state_manager.has_method("get_game_state"):
		push_error("GameStateManager does not have the get_game_state method.")
		return
	
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		push_error("Failed to get GameState from GameStateManager. Initializing with default values.")
		_initialize_default_game_state()
		game_state = game_state_manager.get_game_state()  # Get updated game state
	
	if not game_state.current_crew:
		push_error("Current crew not initialized. Initializing with default values.")
		game_state.current_crew = Crew.new()
	
	setup_crew_slots()
	update_crew_display()

func _initialize_default_game_state() -> void:
	if not game_state_manager.game_state:
		game_state_manager.game_state = GameState.new()
	if not game_state_manager.game_state.current_crew:
		game_state_manager.game_state.current_crew = Crew.new()

func setup_crew_slots() -> void:
	var crew_size = game_state_manager.game_state.crew_size if game_state_manager.game_state.crew_size > 0 else DEFAULT_CREW_SIZE
	for i in range(crew_size):
		var character_box = character_box_scene.instantiate()
		character_box.pressed.connect(_on_character_box_pressed.bind(i))
		character_box.edit_character.connect(_on_edit_character_pressed)
		character_box.remove_character.connect(_on_remove_character_pressed)
		crew_grid.add_child(character_box)

func update_crew_display() -> void:
	var current_crew = game_state_manager.game_state.current_crew
	if not current_crew:
		push_error("Current crew is null. Cannot update display.")
		return
	
	for i in range(crew_grid.get_child_count()):
		var character_box = crew_grid.get_child(i)
		if i < current_crew.characters.size():
			character_box.set_character(current_crew.characters[i])
			character_box.get_node("MarginContainer/VBoxContainer/EditButton").visible = true
			character_box.get_node("MarginContainer/VBoxContainer/RemoveButton").visible = true
		else:
			character_box.set_empty()
			character_box.get_node("MarginContainer/VBoxContainer/EditButton").visible = false
			character_box.get_node("MarginContainer/VBoxContainer/RemoveButton").visible = false

func _on_character_box_pressed(slot_index: int) -> void:
	var current_crew = game_state_manager.game_state.current_crew
	if not current_crew:
		push_error("Current crew is null. Cannot process character box press.")
		return
	
	if slot_index < current_crew.characters.size():
		_show_character_details(current_crew.characters[slot_index])
	else:
		_create_new_character(slot_index)

func _show_character_details(character: Character) -> void:
	character_display.set_character(character)
	character_display.show()

func _create_new_character(_slot_index: int) -> void:
	var character_creator = character_creator_scene.instantiate()
	character_creator.connect("character_created", _on_character_created)
	add_child(character_creator)

func _on_character_created(new_character: Character) -> void:
	var current_crew = game_state_manager.game_state.current_crew
	if current_crew.can_add_member():
		current_crew.add_character(new_character)
		update_crew_display()
	else:
		push_error("Cannot add character. Crew is at maximum capacity.")

func _on_edit_character_pressed(character: Character) -> void:
	var character_creator = character_creator_scene.instantiate()
	character_creator.set_character(character)
	character_creator.character_updated.connect(_on_character_updated)
	add_child(character_creator)

func _on_character_updated(_updated_character: Character) -> void:
	update_crew_display()

func _on_remove_character_pressed(character: Character) -> void:
	game_state_manager.game_state.current_crew.remove_member(character)
	update_crew_display()

func _on_finalize_crew_button_pressed() -> void:
	if game_state_manager.game_state.current_crew.is_valid():
		game_state_manager.game_state.current_state = GlobalEnums.CampaignPhase.UPKEEP
		get_tree().change_scene_to_file("res://Scenes/Management/CampaignDashboard.tscn")
	else:
		push_warning("Crew is not valid. Ensure you have the minimum required members.")

func _on_create_character_button_pressed() -> void:
	var game_state = game_state_manager.get_game_state()
	if game_state is Dictionary and game_state.has("current_crew"):
		var current_crew = game_state.current_crew
		if not current_crew:
			push_error("Current crew is null. Creating a new crew for testing.")
	else:
		push_error("Invalid game state or missing current_crew property.")
	
	if current_crew.can_add_member():
		_create_new_character(current_crew.characters.size())
	else:
			# Show a message that the crew is full
			print("Crew is at maximum capacity. Cannot add new character.")
