class_name GameStateManagerNode
extends Node

signal state_changed(new_state: GlobalEnums.CampaignPhase)
signal tutorial_ended
signal battle_processed(battle_won: bool)

func get_game_state() -> GameState:
    return GameState

func transition_to_state(new_state: GlobalEnums.CampaignPhase) -> void:
    GameState.transition_to_state(new_state)

func update_mission_list() -> void:
    GameState.update_mission_list()

func start_mission(tree: SceneTree = null) -> void:
    GameState.start_mission(tree)

func end_battle(player_victory: bool, scene_tree: SceneTree) -> void:
    GameState.end_battle(player_victory, scene_tree)

func _on_state_changed(new_state: GlobalEnums.CampaignPhase) -> void:
    state_changed.emit(new_state)

func _on_tutorial_ended() -> void:
    tutorial_ended.emit()

func _on_battle_processed(battle_won: bool) -> void:
    battle_processed.emit(battle_won)
