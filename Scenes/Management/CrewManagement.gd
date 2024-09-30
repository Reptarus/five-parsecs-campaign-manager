# Scenes/Management/CrewManagement.gd

extends Control

signal crew_finalized

var game_state: GameState
var crew: Array[Character] = []
@onready var crew_grid: GridContainer = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent/CrewGrid
@onready var character_display: CharacterDisplay = $CharacterDisplay

func _ready() -> void:
	game_state = GameState.get_game_state()
	if not game_state:
		push_error("GameState not found. Make sure GameState is properly set up as an AutoLoad.")
		return
	
	load_crew()
	update_crew_display()

func load_crew() -> void:
	crew = game_state.get_current_crew().members

func update_crew_display() -> void:
	for child in crew_grid.get_children():
		child.queue_free()
	
	for character in crew:
		var character_box = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterBox.tscn").instantiate()
		character_box.set_character(character)
		character_box.pressed.connect(_on_character_box_pressed.bind(character))
		crew_grid.add_child(character_box)

func _on_character_box_pressed(character: Character) -> void:
	character_display.set_character(character)
	character_display.show_detailed_view()

func _on_create_character_button_pressed() -> void:
	var character_creator = preload("res://Scenes/Scene Container/campaigncreation/CharacterCreator.tscn").instantiate()
	add_child(character_creator)
	character_creator.character_created.connect(_on_character_created)

func _on_character_created(new_character: Character) -> void:
	if game_state.get_current_crew().can_add_member():
		game_state.get_current_crew().add_member(new_character)
		crew.append(new_character)
		update_crew_display()
	else:
		push_warning("Crew is at maximum capacity. Cannot add new character.")

func _on_finalize_crew_button_pressed() -> void:
	if crew.size() >= game_state.get_min_crew_size():
		game_state.set_current_crew(crew)
		crew_finalized.emit()
	else:
		push_warning("Not enough crew members. Minimum required: " + str(game_state.get_min_crew_size()))

func _on_remove_character_button_pressed(character: Character) -> void:
	if crew.size() > game_state.get_min_crew_size():
		crew.erase(character)
		game_state.get_current_crew().remove_member(character)
		update_crew_display()
	else:
		push_warning("Cannot remove character. Minimum crew size reached.")
