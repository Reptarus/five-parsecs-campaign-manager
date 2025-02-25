@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const FiveParcsecsCampaign = preload("res://src/core/campaign/Campaign.gd")

signal event_occurred(event_data: Dictionary)
signal phase_changed(phase: int)
signal campaign_started(campaign: FiveParcsecsCampaign)
signal campaign_ended(victory: bool)

var gamestate: GameState = null
var current_phase: int = GameEnums.CampaignPhase.SETUP
var current_campaign: FiveParcsecsCampaign = null

func _init() -> void:
	gamestate = GameState.new()
	if gamestate:
		add_child(gamestate)
	else:
		push_error("Failed to initialize GameState")

func start_campaign(config: FiveParcsecsCampaign) -> void:
	if not config:
		push_error("Invalid campaign configuration provided")
		return
	
	current_campaign = config
	current_phase = GameEnums.CampaignPhase.SETUP
	gamestate.start_new_campaign(config)
	campaign_started.emit(config)

func end_campaign(victory: bool = false) -> void:
	if current_campaign:
		current_campaign.end_campaign(victory)
		campaign_ended.emit(victory)
	current_phase = GameEnums.CampaignPhase.END

func save_campaign() -> Dictionary:
	return gamestate.save_campaign()

func load_campaign(save_data: Dictionary) -> void:
	gamestate.load_campaign(save_data)
	current_phase = save_data.get("current_phase", GameEnums.CampaignPhase.SETUP)

func update_resource(resource_type: int, amount: int) -> void:
	gamestate.update_resource(resource_type, amount)

func trigger_event(event_data: Dictionary) -> void:
	event_occurred.emit(event_data)

func get_game_state() -> GameState:
	return gamestate

func _exit_tree() -> void:
	if gamestate:
		gamestate.queue_free()
	if current_campaign:
		current_campaign.queue_free()