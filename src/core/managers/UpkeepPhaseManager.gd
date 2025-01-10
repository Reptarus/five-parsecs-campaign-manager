extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

func calculate_upkeep_cost(crew_size: int, difficulty: GameEnums.DifficultyLevel) -> int:
    var base_cost = 100 * crew_size
    
    match difficulty:
        GameEnums.DifficultyLevel.EASY:
            base_cost = int(base_cost * 0.8)
        GameEnums.DifficultyLevel.NORMAL:
            base_cost = base_cost
        GameEnums.DifficultyLevel.HARD:
            base_cost = int(base_cost * 1.2)
        GameEnums.DifficultyLevel.VETERAN:
            base_cost = int(base_cost * 1.5)
        GameEnums.DifficultyLevel.ELITE:
            base_cost = int(base_cost * 2.0)
    
    return base_cost