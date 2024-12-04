class_name MissionGeneratorBase
extends Resource

var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func _get_mission_config(mission_type: int) -> Dictionary:
    # Virtual method to be implemented by child classes
    return {}

func _generate_objectives(mission: Mission, location: Planet) -> void:
    # Virtual method to be implemented by child classes
    pass

func _generate_enemy_force(mission: Mission, location: Planet) -> void:
    # Virtual method to be implemented by child classes
    pass

func _setup_deployment(mission: Mission) -> void:
    # Virtual method to be implemented by child classes
    pass

func _calculate_rewards(mission: Mission, location: Planet) -> void:
    # Virtual method to be implemented by child classes
    pass 