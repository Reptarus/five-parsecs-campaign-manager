# InitialCrewCreation.gd
extends Control

@onready var crew_size_slider = $HSlider
@onready var current_size_label = $CurrentSizeLabel
@onready var tutorial_label = $TutorialLabel
@onready var confirm_button = $ConfirmButton

var game_state_manager: GameStateManager

func _ready():
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found. Ensure it's properly set up.")
		return
	
	setup_ui()
	update_tutorial_label()

func setup_ui():
	crew_size_slider.min_value = 4
	crew_size_slider.max_value = 6
	crew_size_slider.value = 5  # Default to 5 for tutorial
	update_current_size_label()

func update_current_size_label():
	current_size_label.text = "Current Crew Size: %d" % crew_size_slider.value

func update_tutorial_label():
	if game_state_manager.game_state.is_tutorial_active:
		tutorial_label.text = "Tutorial Mode: Create your initial crew of 5 members."
		tutorial_label.visible = true
		crew_size_slider.editable = false
		crew_size_slider.value = 5
	else:
		tutorial_label.visible = false
		crew_size_slider.editable = true

func _on_h_slider_value_changed(_value):
	update_current_size_label()

func _on_confirm_button_pressed():
	var crew_size = int(crew_size_slider.value)
	game_state_manager.game_state.crew_size = crew_size
	
	# Generate initial crew members
	for i in range(crew_size):
		var new_crew_member = generate_crew_member()
		game_state_manager.game_state.crew.append(new_crew_member)
	
	if game_state_manager.game_state.is_tutorial_active:
		get_tree().change_scene_to_file("res://Scenes/TutorialBattle.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn")

func generate_crew_member():
	# This is a placeholder function. In a full implementation, you would:
	# 1. Roll for species (or select based on player choice)
	# 2. Generate stats based on species
	# 3. Assign initial equipment
	# 4. Generate a name
	# For now, we'll return a simple dictionary
	return {
		"name": "Crew Member %d" % (game_state_manager.game_state.crew.size() + 1),
		"species": "Human",
		"reactions": 1,
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"savvy": 0,
		"equipment": ["Service Pistol", "Trooper Armor"]
	}
