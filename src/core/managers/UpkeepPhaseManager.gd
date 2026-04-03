extends Node

## Upkeep cost calculator — Core Rules p.76
## 1 credit for 4-6 crew, +1 per crew member past 6.
## Difficulty does NOT modify upkeep in Core Rules.
func calculate_upkeep_cost(crew_size: int, _difficulty: GlobalEnums.DifficultyLevel) -> int:
	if crew_size < 4:
		return 0
	return 1 + max(0, crew_size - 6)
