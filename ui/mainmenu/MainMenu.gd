# MainMenu.gd
extends Control

@onready var continue_button = $"Menu Buttons/Continue"
@onready var new_campaign_button = $"Menu Buttons/NewCampaign"
@onready var coop_campaign_button = $"Menu Buttons/CoopCampaign"
@onready var battle_simulator_button = $"Menu Buttons/BattleSimulator"
@onready var bug_hunt_button = $"Menu Buttons/BugHunt"
@onready var options_button = $"Menu Buttons/Options"
@onready var library_button = $"Menu Buttons/Library"

var game_state: GameState

func _ready():
	game_state = get_node("/root/GameState") as GameState
	assert(game_state != null, "Expected GameState, but got null")
	
	continue_button.pressed.connect(_on_continue_pressed)
	new_campaign_button.pressed.connect(_on_new_campaign_pressed)
	coop_campaign_button.pressed.connect(_on_coop_campaign_pressed)
	battle_simulator_button.pressed.connect(_on_battle_simulator_pressed)
	bug_hunt_button.pressed.connect(_on_bug_hunt_pressed)
	options_button.pressed.connect(_on_options_pressed)
	library_button.pressed.connect(_on_library_pressed)
	
	update_continue_button_visibility()
	
	# Add fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func update_continue_button_visibility():
	continue_button.visible = game_state.current_crew != null

func _on_continue_pressed():
	if game_state.current_crew:
		transition_to_scene("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn")
	else:
		_show_not_implemented_message("No saved game found")

func _on_new_campaign_pressed():
	var campaign_setup = load("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn").instantiate()
	campaign_setup.connect("ready", Callable(campaign_setup, "show_tutorial_popup"))
	transition_to_scene(campaign_setup)

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

func transition_to_scene(scene_path):
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(Callable(get_node("/root/Main"), "goto_scene").bind(scene_path))
