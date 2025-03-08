@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")

signal event_occurred(event_data: Dictionary)
signal phase_changed(phase: int)
signal campaign_started(campaign: FiveParsecsCampaign)
signal campaign_ended(victory: bool)

var gamestate: GameState = null
var current_phase: int = GameEnums.CampaignPhase.SETUP
var current_campaign: FiveParsecsCampaign = null

func _init() -> void:
	gamestate = GameState.new()
	if gamestate:
		add_child(gamestate)
	else:
		push_error("Failed to initialize GameState")

func start_campaign(config: FiveParsecsCampaign) -> void:
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
	# Create campaign from data directly instead of using the file loading path
	var campaign = FiveParsecsCampaign.new()
	var load_result = campaign.deserialize(save_data)
	
	if not load_result.success:
		push_error("Failed to load campaign: " + load_result.message)
		return
	
	# Set as current campaign in gamestate
	gamestate.set_current_campaign(campaign)
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
