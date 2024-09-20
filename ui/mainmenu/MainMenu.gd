# MainMenu.gd
extends Control

@onready var continue_button = $MenuButtons/Continue
@onready var new_campaign_button = $MenuButtons/NewCampaign
@onready var coop_campaign_button = $MenuButtons/CoopCampaign
@onready var battle_simulator_button = $MenuButtons/BattleSimulator
@onready var bug_hunt_button = $MenuButtons/BugHunt
@onready var options_button = $MenuButtons/Options
@onready var library_button = $MenuButtons/Library

var game_state: GameState

func _ready():
	setup_ui()
	call_deferred("initialize_game_systems")

	var menu_buttons = {
		"continue_button": continue_button,
		"new_campaign_button": new_campaign_button,
		"coop_campaign_button": coop_campaign_button,
		"battle_simulator_button": battle_simulator_button,
		"bug_hunt_button": bug_hunt_button,
		"options_button": options_button,
		"library_button": library_button
	}
	
	for button_name in menu_buttons:
		if menu_buttons[button_name]:
			print_debug("%s: Connected" % button_name)
		else:
			push_warning("%s not found in the scene tree" % button_name)

	# Note: Button connections are handled in setup_ui()

func setup_ui():
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_campaign_button:
		new_campaign_button.pressed.connect(_on_new_campaign_pressed)
	if coop_campaign_button:
		coop_campaign_button.pressed.connect(_on_coop_campaign_pressed)
	if battle_simulator_button:
		battle_simulator_button.pressed.connect(_on_battle_simulator_pressed)
	if bug_hunt_button:
		bug_hunt_button.pressed.connect(_on_bug_hunt_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if library_button:
		library_button.pressed.connect(_on_library_pressed)
	
	# Add fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func initialize_game_systems():
	game_state = GameState.new()
	assert(game_state != null, "Failed to create GameState instance")
	update_continue_button_visibility()

func update_continue_button_visibility():
	continue_button.visible = game_state.current_crew != null

func _on_continue_pressed():
	if game_state.current_crew:
		transition_to_scene("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn")
	else:
		_show_not_implemented_message("No saved game found")

func _on_new_campaign_pressed():
	# Instead of directly changing the scene, let's use a deferred call
	call_deferred("_change_to_new_campaign_scene")

func _change_to_new_campaign_scene():
	# Load the scene
	var campaign_setup_scene = load("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn").instantiate()
	
	# Ensure the game_state is passed to the new scene if needed
	if campaign_setup_scene.has_method("set_game_state"):
		campaign_setup_scene.set_game_state(game_state)
	
	# Remove the current scene
	get_tree().current_scene.queue_free()
	
	# Add the new scene to the tree
	get_tree().root.add_child(campaign_setup_scene)
	
	# Set it as the current scene
	get_tree().current_scene = campaign_setup_scene

func _on_coop_campaign_pressed():
	_show_not_implemented_message("Co-op Campaign (Work in Progress)")

func _on_battle_simulator_pressed():
	transition_to_scene("res://Scenes/Management/Scenes/BattlefieldGenerator.tscn")

func _on_bug_hunt_pressed():
	_show_not_implemented_message("Bug Hunt (Work in Progress)")

func _on_options_pressed():
	transition_to_scene("res://assets/scenes/menus/options_menu/video_options_menu.tscn")

func _on_library_pressed():
	transition_to_scene("res://Scenes/Scene Container/RulesReference.tscn")

func _show_not_implemented_message(feature: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = feature + " is not implemented yet."
	add_child(dialog)
	dialog.popup_centered()

func _on_tutorial_choice_made(choice):
	var tutorial_manager = TutorialManager.new()  # Use the global class directly
	match choice:
		"story_track":
			tutorial_manager.start_tutorial("story_track")
		"compendium":
			tutorial_manager.start_tutorial("compendium")
		"skip":
			# Proceed without tutorial
			pass
	
	# Transition to CrewSizeSelection
	var crew_size_selection = preload("res://Scenes/Scene Container/CrewSizeSelection.tscn").instance()
	add_child(crew_size_selection)

func transition_to_scene(scene_path):
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(Callable(get_node("/root/Main"), "goto_scene").bind(scene_path))
