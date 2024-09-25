# Scenes/Scene Container/campaigncreation/scripts/CrewManagement.gd

extends Control

var crew: Array[Character] = []
@onready var crew_grid: GridContainer = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent/CrewGrid
@onready var character_display: CharacterDisplay = $CharacterDisplay

func _ready():
	load_crew()
	update_crew_display()

func load_crew():
	# Load crew data from save file or create a new crew
	# For now, we'll create a sample crew
	for i in range(3):
		var character = Character.new()
		character.name = "Crew Member " + str(i + 1)
		crew.append(character)

func update_crew_display():
	for child in crew_grid.get_children():
		child.queue_free()
	
	for character in crew:
		var character_box = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterBox.tscn").instantiate()
		character_box.set_character(character)
		character_box.connect("pressed", _on_character_box_pressed.bind(character))
		crew_grid.add_child(character_box)

func _on_character_box_pressed(character: Character):
	character_display.set_character(character)
	character_display.show_detailed_view()

func _on_create_character_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Scene Container/campaigncreation/CharacterCreator.tscn")

func _on_finalize_crew_button_pressed():
	# Implement crew finalization logic
	pass
