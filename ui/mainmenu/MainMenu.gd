# MainMenu.gd
extends Control

const GameStateManager = preload("res://StateMachines/GameStateManager.gd")

@onready var continue_button: Button = $MenuButtons/Continue
@onready var new_campaign_button: Button = $MenuButtons/NewCampaign
@onready var coop_campaign_button: Button = $MenuButtons/CoopCampaign
@onready var battle_simulator_button: Button = $MenuButtons/BattleSimulator
@onready var bug_hunt_button: Button = $MenuButtons/BugHunt
@onready var options_button: Button = $MenuButtons/Options
@onready var library_button: Button = $MenuButtons/Library
@onready var tutorial_popup: Panel = $TutorialPopup

var game_state_manager: GameStateManager

func setup(manager: GameStateManager) -> void:
	game_state_manager = manager
	update_continue_button_visibility()

func _ready() -> void:
	setup_ui()
	tutorial_popup.hide()
	_connect_tutorial_signals()

func _connect_tutorial_signals() -> void:
	var tutorial_container := tutorial_popup.get_node("VBoxContainer")
	if not tutorial_container:
		push_error("Tutorial container not found")
		return
		
	var buttons := {
		"StoryTrackButton": "story_track",
		"CompendiumButton": "compendium",
		"SkipButton": "skip"
	}
	
	for button_name in buttons:
		var button: Button = tutorial_container.get_node_or_null(button_name)
		if button:
			if button.is_connected("pressed", _on_tutorial_popup_button_pressed):
				button.pressed.disconnect(_on_tutorial_popup_button_pressed)
			button.pressed.connect(_on_tutorial_popup_button_pressed.bind(buttons[button_name]))

func setup_ui() -> void:
	connect_buttons()
	add_fade_in_animation()

func connect_buttons() -> void:
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

func add_fade_in_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func update_continue_button_visibility() -> void:
	if not game_state_manager:
		continue_button.visible = false
		return
		
	if game_state_manager.game_state and game_state_manager.game_state.current_ship:
		continue_button.visible = game_state_manager.game_state.current_ship.crew.size() > 0
	else:
		continue_button.visible = false

func _on_continue_pressed() -> void:
	if game_state_manager and game_state_manager.game_state.current_ship and game_state_manager.game_state.current_ship.crew.size() > 0:
		request_scene_change("crew_management")
	else:
		show_message("No active campaign to continue")

func _on_new_campaign_pressed() -> void:
	if game_state_manager and game_state_manager.settings.get("disable_tutorial_popup", false):
		_start_new_campaign()
	else:
		_show_tutorial_popup()

func _show_tutorial_popup() -> void:
	if not tutorial_popup:
		push_error("Tutorial popup not found")
		return
		
	var checkbox = tutorial_popup.get_node_or_null("VBoxContainer/DisableTutorialCheckbox")
	if checkbox and game_state_manager:
		checkbox.button_pressed = game_state_manager.settings.get("disable_tutorial_popup", false)
	
	tutorial_popup.visible = true

func _start_new_campaign() -> void:
	if game_state_manager:
		game_state_manager.game_state.current_state = GlobalEnums.GameState.SETUP
		request_scene_change("campaign_setup")

func _on_tutorial_popup_button_pressed(choice: String) -> void:
	tutorial_popup.visible = false
	_handle_tutorial_choice(choice)

func _handle_tutorial_choice(choice: String) -> void:
	if not game_state_manager:
		return
		
	match choice:
		"story_track", "compendium":
			game_state_manager.game_state.is_tutorial_active = true
			request_scene_change("tutorial_setup")
		"skip":
			game_state_manager.game_state.is_tutorial_active = false
			_start_new_campaign()

func _on_disable_tutorial_toggled(button_pressed: bool) -> void:
	if game_state_manager:
		game_state_manager.settings["disable_tutorial_popup"] = button_pressed
		if game_state_manager.has_method("save_settings"):
			game_state_manager.save_settings()

# Additional button handlers
func _on_coop_campaign_pressed() -> void:
	show_message("Co-op Campaign feature is coming soon!")

func _on_battle_simulator_pressed() -> void:
	request_scene_change("battle_simulator")

func _on_bug_hunt_pressed() -> void:
	show_message("Bug Hunt feature is coming soon!")

func _on_options_pressed() -> void:
	request_scene_change("options")

func _on_library_pressed() -> void:
	request_scene_change("library")

# Helper functions
func show_message(text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()

func request_scene_change(scene_name: String) -> void:
	# Emit signal that MainGameScene will handle
	get_parent().get_parent().change_scene(scene_name)
