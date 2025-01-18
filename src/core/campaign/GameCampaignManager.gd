class_name GameCampaignManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")

signal phase_changed(old_phase: int, new_phase: int)
signal resource_updated(resource_type: int, new_value: int)
signal event_occurred(event_data: Dictionary)

var gamestate: GameState
var current_phase: int = GameEnums.CampaignPhase.SETUP

func _init() -> void:
	gamestate = GameState.new()
	add_child(gamestate)

func start_campaign(config: Campaign) -> void:
	gamestate.start_new_campaign(config)
	current_phase = GameEnums.CampaignPhase.SETUP
	phase_changed.emit(GameEnums.CampaignPhase.NONE, current_phase)

func end_campaign() -> void:
	gamestate.end_campaign()
	current_phase = GameEnums.CampaignPhase.NONE
	phase_changed.emit(GameEnums.CampaignPhase.SETUP, current_phase)

func save_campaign() -> Dictionary:
	return gamestate.save_campaign()

func load_campaign(save_data: Dictionary) -> void:
	gamestate.load_campaign(save_data)
	current_phase = save_data.get("current_phase", GameEnums.CampaignPhase.SETUP)
	phase_changed.emit(GameEnums.CampaignPhase.NONE, current_phase)

func update_resource(resource_type: int, amount: int) -> void:
	gamestate.update_resource(resource_type, amount)
	resource_updated.emit(resource_type, gamestate.get_resource(resource_type))

func trigger_event(event_data: Dictionary) -> void:
	event_occurred.emit(event_data)

func get_game_state() -> GameState:
	return gamestate