class_name GameStateManagerNode
extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal tutorial_ended
signal battle_processed(battle_won: bool)

var game_manager: GameManager

func _ready() -> void:
	game_manager = GameManager.new()

func get_game_state() -> GameState:
	return game_manager.game_state

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
	game_manager.game_state.transition_to_state(new_state)
	state_changed.emit(new_state)

func update_mission_list() -> void:
	game_manager.game_state.update_mission_list()

func start_mission(mission: Mission) -> void:
	game_manager.start_mission(mission)

func end_battle(player_victory: bool) -> void:
	game_manager.end_mission(player_victory)
	battle_processed.emit(player_victory)

func _on_tutorial_ended() -> void:
	tutorial_ended.emit()

func generate_battlefield() -> void:
	game_manager.generate_battlefield()

func handle_player_action(action: String, params: Dictionary = {}) -> void:
	game_manager.handle_player_action(action, params)

func start_campaign_turn() -> void:
	game_manager.start_campaign_turn()

func check_campaign_progress() -> void:
	game_manager.check_campaign_progress()
