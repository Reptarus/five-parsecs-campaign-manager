extends Control

@onready var new_mission_button = $"Menu Buttons/NewMission"
@onready var continue_mission_button = $"Menu Buttons/ContinueMission"
@onready var squad_management_button = $"Menu Buttons/SquadManagement"
@onready var armory_button = $"Menu Buttons/Armory"
@onready var options_button = $"Menu Buttons/Options"
@onready var rules_reference_button = $"Menu Buttons/RulesReference"

func _ready():
	new_mission_button.connect("pressed", Callable(self, "_on_new_mission_pressed"))
	continue_mission_button.connect("pressed", Callable(self, "_on_continue_mission_pressed"))
	squad_management_button.connect("pressed", Callable(self, "_on_squad_management_pressed"))
	armory_button.connect("pressed", Callable(self, "_on_armory_pressed"))
	options_button.connect("pressed", Callable(self, "_on_options_pressed"))
	rules_reference_button.connect("pressed", Callable(self, "_on_rules_reference_pressed"))

func _on_new_mission_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/bug_hunt/mission_setup.tscn")

func _on_continue_mission_pressed():
	get_node("/root/Main").load_game()

func _on_squad_management_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/bug_hunt/squad_management.tscn")

func _on_armory_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/bug_hunt/armory.tscn")

func _on_options_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/options_menu.tscn")

func _on_rules_reference_pressed():
	get_node("/root/Main").goto_scene("res://assets/scenes/bug_hunt/rules_reference.tscn")

func _show_not_implemented_message(feature: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = feature + " is not implemented yet."
	add_child(dialog)
	dialog.popup_centered()

