extends Node
func calculate_upkeep_cost(crew_size: int, difficulty: GlobalEnums.DifficultyLevel) -> int:
	var base_cost = 100 * crew_size
    
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			base_cost = int(base_cost * 0.8)
		GlobalEnums.DifficultyLevel.NORMAL:
			base_cost = base_cost
		GlobalEnums.DifficultyLevel.HARD:
			base_cost = int(base_cost * 1.2)
		GlobalEnums.DifficultyLevel.HARDCORE:
			base_cost = int(base_cost * 1.5)
		GlobalEnums.DifficultyLevel.ELITE:
			base_cost = int(base_cost * 2.0)
    
	return base_cost
