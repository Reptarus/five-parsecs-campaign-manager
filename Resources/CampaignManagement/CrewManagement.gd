extends Control

signal crew_finalized

var game_state: MockGameState
var crew_box_scene = preload("res://Resources/CrewAndCharacters/Scenes/CharacterBox.tscn")

@onready var crew_list = $MainLayout/LeftPanel/VBoxContainer/CrewList/VBoxContainer
@onready var crew_count_label = $MainLayout/LeftPanel/VBoxContainer/CrewCountLabel
@onready var crew_list_label = $MainLayout/LeftPanel/VBoxContainer/CrewListLabel
@onready var add_crew_button = $MainLayout/LeftPanel/VBoxContainer/AddCrew

func _ready() -> void:
	# For testing, create a new MockGameState instance
	game_state = MockGameState.new()
	
	# Initialize UI elements
	crew_list_label.text = "Crew Members"
	add_crew_button.text = "Add New Crew"
	
	# Connect signals
	add_crew_button.pressed.connect(_on_add_crew_pressed)
	
	# Populate the crew list
	_update_crew_display()

func _update_crew_display() -> void:
	# Clear existing crew boxes
	for child in crew_list.get_children():
		child.queue_free()
	
	# Get crew from mock game state
	var crew_members = game_state.get_crew()
	
	# Create character boxes for each crew member
	for crew_member in crew_members:
		var character_box = crew_box_scene.instantiate()
		crew_list.add_child(character_box)
		
		# Update character box with crew member data
		character_box.update_display(crew_member)
	
	# Update crew count
	crew_count_label.text = "Total Crew: %d" % crew_members.size()

func _on_add_crew_pressed() -> void:
	# This is just a placeholder for now
	print("Add crew functionality to be implemented")
