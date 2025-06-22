@tool
extends Control
class_name MainGameScene

## Main Game Scene for Five Parsecs Campaign Manager
## Primary scene for campaign management and gameplay

signal scene_changed(scene_name: String)
signal game_state_updated(state: Dictionary)

@onready var campaign_ui: Control = $CampaignUI
@onready var battle_ui: Control = $BattleUI
@onready var menu_ui: Control = $MenuUI

var current_scene_mode: String = "menu"
var game_state: Resource

func _ready() -> void:
	_initialize_scene()

func _initialize_scene() -> void:
	show_menu_ui()

func show_menu_ui() -> void:
	current_scene_mode = "menu"
	menu_ui.show()
	campaign_ui.hide()
	battle_ui.hide()
	scene_changed.emit("menu")

func show_campaign_ui() -> void:
	current_scene_mode = "campaign"
	menu_ui.hide()
	campaign_ui.show()
	battle_ui.hide()
	scene_changed.emit("campaign")

func show_battle_ui() -> void:
	current_scene_mode = "battle"
	menu_ui.hide()
	campaign_ui.hide()
	battle_ui.show()
	scene_changed.emit("battle")

func get_current_scene_mode() -> String:
	return current_scene_mode

func set_game_state(state: Resource) -> void:
	game_state = state
	game_state_updated.emit(state.serialize() if state.has_method("serialize") else {})

func get_game_state() -> Resource:
	return game_state
