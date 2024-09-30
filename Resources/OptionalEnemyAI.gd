class_name OptionalEnemyAI
extends Resource

var combat_manager: CombatManager

func _init(_combat_manager: CombatManager):
	combat_manager = _combat_manager

func determine_action(enemy: Character) -> Dictionary:
	var ai_type = enemy.ai_type
	var base_condition_met = check_base_condition(enemy, ai_type)
	
	if base_condition_met:
		return execute_base_action(enemy, ai_type)
	
	var roll = randi() % 6 + 1
	return execute_rolled_action(enemy, ai_type, roll)

func check_base_condition(enemy: Character, ai_type: GlobalEnums.AIType) -> bool:
	match ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			return enemy.is_in_cover() and combat_manager.are_enemies_within_range(enemy, 12)
		GlobalEnums.AIType.AGGRESSIVE:
			return combat_manager.can_engage_in_brawl(enemy)
		GlobalEnums.AIType.DEFENSIVE:
			return enemy.is_in_cover() and combat_manager.are_enemies_in_open(enemy)
		GlobalEnums.AIType.TACTICAL:
			return enemy.is_in_cover() and combat_manager.are_enemies_within_range(enemy, 12)
		_:
			return false

func execute_base_action(enemy: Character, ai_type: GlobalEnums.AIType) -> Dictionary:
	match ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_distant_cover_position(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		GlobalEnums.AIType.AGGRESSIVE:
			return {
				"type": "move_to_brawl",
				"target": combat_manager.find_nearest_enemy(enemy)
			}
		GlobalEnums.AIType.DEFENSIVE, GlobalEnums.AIType.TACTICAL:
			return {
				"type": "fire",
				"target": combat_manager.find_best_target(enemy)
			}
		_:
			return {}

func execute_rolled_action(enemy: Character, ai_type: GlobalEnums.AIType, roll: int) -> Dictionary:
	match ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			return execute_cautious_action(enemy, roll)
		GlobalEnums.AIType.AGGRESSIVE:
			return execute_aggressive_action(enemy, roll)
		GlobalEnums.AIType.DEFENSIVE:
			return execute_defensive_action(enemy, roll)
		GlobalEnums.AIType.TACTICAL:
			return execute_tactical_action(enemy, roll)
		_:
			return {}

func execute_cautious_action(enemy: Character, roll: int) -> Dictionary:
	match roll:
		1:
			return {
				"type": "retreat",
				"move_to": combat_manager.find_retreat_position(enemy)
			}
		2, 3:
			return {
				"type": "fire",
				"target": combat_manager.find_best_target(enemy)
			}
		4, 5:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_cover_within_range(enemy, 12),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		6:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_cover_near_enemy(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		_:
			return {}

func execute_aggressive_action(enemy: Character, roll: int) -> Dictionary:
	match roll:
		1, 2:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_nearest_cover(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		3, 4:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_position_closer_to_enemy(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		5:
			return {
				"type": "charge",
				"target": combat_manager.find_nearest_enemy(enemy)
			}
		6:
			return {
				"type": "dash",
				"move_to": combat_manager.find_position_closer_to_enemy(enemy, true)
			}
		_:
			return {}

func execute_defensive_action(enemy: Character, roll: int) -> Dictionary:
	match roll:
		1, 2, 3:
			return {
				"type": "fire",
				"target": combat_manager.find_best_target(enemy)
			}
		4:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_better_cover(enemy),
				"fire_at": combat_manager.find_best_target(enemy)
			}
		5:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_cover_within_range(enemy, 12),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		6:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_cover_near_enemy(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		_:
			return {}

func execute_tactical_action(enemy: Character, roll: int) -> Dictionary:
	match roll:
		1:
			return {
				"type": "fire",
				"target": combat_manager.find_best_target(enemy)
			}
		2:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_better_cover(enemy),
				"fire_at": combat_manager.find_best_target(enemy)
			}
		3, 4:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_flanking_position(enemy),
				"fire_at": combat_manager.find_best_target(enemy)
			}
		5, 6:
			return {
				"type": "move_and_fire",
				"move_to": combat_manager.find_cover_near_enemy(enemy),
				"fire_at": combat_manager.find_nearest_enemy(enemy)
			}
		_:
			return {}
