# MainMenu.gd
extends Control

@onready var continue_button = $MenuButtons/Continue
@onready var new_campaign_button = $MenuButtons/NewCampaign
@onready var coop_campaign_button = $MenuButtons/CoopCampaign
@onready var battle_simulator_button = $MenuButtons/BattleSimulator
@onready var bug_hunt_button = $MenuButtons/BugHunt
@onready var options_button = $MenuButtons/Options
@onready var library_button = $MenuButtons/Library
@onready var new_campaign_tutorial = preload("res://Scenes/Scene Container/campaigncreation/scenes/NewCampaignTutorial.tscn")
@onready var tutorial_popup = $TutorialPopup

var game_state_manager: GameStateManager

func _ready():
	setup_ui()
	call_deferred("initialize_game_systems")
	tutorial_popup.hide()  # Hide the tutorial popup on startup

func setup_ui():
	connect_buttons()
	add_fade_in_animation()

func connect_buttons():
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

func add_fade_in_animation():
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func initialize_game_systems():
	game_state_manager = get_node("/root/GameStateManager")
	if game_state_manager == null:
		push_warning("GameStateManager not found. Retrying in 1 second.")
		get_tree().create_timer(1.0).timeout.connect(initialize_game_systems)
	else:
		update_continue_button_visibility()

func update_continue_button_visibility():
	if game_state_manager and game_state_manager.game_state and game_state_manager.game_state.current_ship:
		continue_button.visible = game_state_manager.game_state.current_ship.crew.size() > 0
	else:
		continue_button.visible = false

func _on_continue_pressed():
	if game_state_manager and game_state_manager.game_state.current_ship.crew.size() > 0:
		transition_to_scene("res://Scenes/Management/CrewManagement.tscn")
	else:
		print("No active campaign to continue")

func _on_new_campaign_pressed():
	# Always show the tutorial popup
	_show_tutorial_popup()

func _show_tutorial_popup():
	tutorial_popup.show()
	# Center the popup
	tutorial_popup.position = (get_viewport_rect().size - tutorial_popup.size) / 2

func _change_to_new_campaign_scene():
	game_state_manager.start_new_game()
	transition_to_scene("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn")

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
	match choice:
		"story_track":
			game_state_manager.game_state.is_tutorial_active = true
			game_state_manager.story_track.start_tutorial()
			transition_to_scene("res://Scenes/Scene Container/InitialCrewCreation.tscn")
		"compendium":
			game_state_manager.game_state.is_tutorial_active = true
			game_state_manager.story_track.start_tutorial()
			transition_to_scene("res://Scenes/Scene Container/InitialCrewCreation.tscn")
		"skip":
			game_state_manager.game_state.is_tutorial_active = false
			_change_to_new_campaign_scene()

func transition_to_scene(scene_path):
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(get_tree().change_scene_to_file.bind(scene_path))

#func _on_disable_tutorial_toggled(button_pressed: bool):
#	if game_state_manager:
#		if "settings" in game_state_manager:
#			if "disable_tutorial_popup" in game_state_manager.settings:
#				game_state_manager.settings.disable_tutorial_popup = button_pressed
#				game_state_manager.save_settings()
#			else:
#				push_error("disable_tutorial_popup not found in GameStateManager settings")
#		else:
#			push_error("settings not found in GameStateManager")
#	else:
#		push_error("GameStateManager not found")

# Add this new function to handle the tutorial popup buttons
func _on_tutorial_popup_button_pressed(choice: String):
	tutorial_popup.hide()
	_on_tutorial_choice_made(choice)
