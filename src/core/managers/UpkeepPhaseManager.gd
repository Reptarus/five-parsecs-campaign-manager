extends Node

# GlobalEnums available as autoload singleton

func calculate_upkeep_cost(crew_size: int, difficulty: GlobalEnums.DifficultyLevel) -> int:
	var base_cost: int = 100 * crew_size

	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			base_cost = int(base_cost * 0.8)
		GlobalEnums.DifficultyLevel.STANDARD:
			base_cost = base_cost
		GlobalEnums.DifficultyLevel.CHALLENGING:
			base_cost = int(base_cost * 1.2)
		GlobalEnums.DifficultyLevel.HARDCORE:
			base_cost = int(base_cost * 1.5)
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			base_cost = int(base_cost * 2.0)

	return base_cost