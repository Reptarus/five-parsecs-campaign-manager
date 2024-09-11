# MainMenu.gd
extends Control

@onready var continue_button = $"Menu Buttons/Continue"
@onready var new_campaign_button = $"Menu Buttons/NewCampaign"
@onready var coop_campaign_button = $"Menu Buttons/CoopCampaign"
@onready var battle_simulator_button = $"Menu Buttons/BattleSimulator"
@onready var bug_hunt_button = $"Menu Buttons/BugHunt"
@onready var options_button = $"Menu Buttons/Options"
@onready var library_button = $"Menu Buttons/Library"

func _ready():
	continue_button.connect("pressed", Callable(self, "_on_continue_pressed"))
	new_campaign_button.connect("pressed", Callable(self, "_on_new_campaign_pressed"))
	coop_campaign_button.connect("pressed", Callable(self, "_on_coop_campaign_pressed"))
	battle_simulator_button.connect("pressed", Callable(self, "_on_battle_simulator_pressed"))
	bug_hunt_button.connect("pressed", Callable(self, "_on_bug_hunt_pressed"))
	options_button.connect("pressed", Callable(self, "_on_options_pressed"))
	library_button.connect("pressed", Callable(self, "_on_library_pressed"))

func _on_continue_pressed():
	get_node("/root/Main").load_game()

func _on_new_campaign_pressed():
	get_node("/root/Main").goto_scene("res://Resources/CrewSetup.tscn")

func _on_coop_campaign_pressed():
	# Implement co-op campaign functionality
	_show_not_implemented_message("Co-op Campaign")

func _on_battle_simulator_pressed():
	# Implement battle simulator functionality
	_show_not_implemented_message("Battle Simulator")

func _on_bug_hunt_pressed():
	# Implement bug hunt functionality
	_show_not_implemented_message("Bug Hunt")

func _on_options_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/options_menu.tscn")

func _on_library_pressed():
	get_node("/root/Main").goto_scene("res://Scenes/Scene Container/RulesReference.tscn")

func _show_not_implemented_message(feature: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = feature + " is not implemented yet."
	add_child(dialog)
	dialog.popup_centered()
