class_name AIController
extends Node

var combat_manager: CombatManager
var game_state: GameState

enum AIType { CAUTIOUS, AGGRESSIVE, TACTICAL, RAMPAGING, DEFENSIVE, BEAST }

func _init(_combat_manager: CombatManager, _game_state: GameState):
	combat_manager = _combat_manager
	game_state = _game_state

func perform_ai_turn(ai_character: Character) -> void:
	var action = determine_best_action(ai_character)
	execute_action(ai_character, action)

func determine_best_action(ai_character: Character) -> Dictionary:
	var possible_actions = get_possible_actions(ai_character)
	var best_action = null
	var best_score = -1

	for action in possible_actions:
		var score = evaluate_action(ai_character, action)
		if score > best_score:
			best_score = score
			best_action = action

	return best_action

func get_possible_actions(ai_character: Character) -> Array:
	var actions = []
	var ai_type = ai_character.ai_type

	match ai_type:
		AIType.CAUTIOUS:
			actions.append({"type": "move", "target": find_cover_position(ai_character)})
			if combat_manager.is_in_cover(ai_character) == CombatManager.CoverType.FULL:
				actions.append({"type": "aim", "target": null})
		AIType.AGGRESSIVE:
			actions.append({"type": "move", "target": find_closest_enemy(ai_character)})
		AIType.TACTICAL:
			actions.append({"type": "move", "target": find_tactical_position(ai_character)})
		AIType.RAMPAGING:
			actions.append({"type": "move", "target": find_closest_enemy(ai_character)})
		AIType.DEFENSIVE:
			if combat_manager.is_in_cover(ai_character) != CombatManager.CoverType.FULL:
				actions.append({"type": "move", "target": find_cover_position(ai_character)})
		AIType.BEAST:
			actions.append({"type": "move", "target": find_closest_enemy(ai_character)})

	for target in combat_manager.current_battle.player_characters:
		if can_attack(ai_character, target):
			actions.append({"type": "attack", "target": target})

	if ai_character.has_usable_items():
		actions.append({"type": "use_item", "target": null})

	return actions

func find_cover_position(ai_character: Character) -> Vector2:
	var best_position = ai_character.position
	var best_cover = CombatManager.CoverType.NONE

	for x in range(combat_manager.GRID_SIZE):
		for y in range(combat_manager.GRID_SIZE):
			var pos = Vector2(x, y)
			if combat_manager.battlefield[x][y] == null:
				var cover = combat_manager.is_in_cover(Character.new(pos))
				if cover > best_cover:
					best_position = pos
					best_cover = cover

	return best_position

func find_closest_enemy(ai_character: Character) -> Vector2:
	var closest_enemy = null
	var closest_distance = INF

	for enemy in combat_manager.current_battle.player_characters:
		var distance = ai_character.position.distance_to(enemy.position)
		if distance < closest_distance:
			closest_enemy = enemy
			closest_distance = distance

	return closest_enemy.position if closest_enemy else ai_character.position

func find_tactical_position(ai_character: Character) -> Vector2:
	var cover_position = find_cover_position(ai_character)
	var enemy_position = find_closest_enemy(ai_character)
	return (cover_position + enemy_position) / 2

func can_attack(attacker: Character, target: Character) -> bool:
	var weapon = attacker.get_equipped_weapon()
	var distance = attacker.position.distance_to(target.position)
	return distance <= weapon.range

func evaluate_action(ai_character: Character, action: Dictionary) -> float:
	match action.type:
		"move":
			return evaluate_move(ai_character, action.target)
		"attack":
			return evaluate_attack(ai_character, action.target)
		"use_item":
			return evaluate_item_use(ai_character)
		"aim":
			return evaluate_aim(ai_character)
		_:
			return 0.0

func evaluate_move(ai_character: Character, target_position: Vector2) -> float:
	var base_score = 10.0
	var distance_to_target = ai_character.position.distance_to(target_position)
	
	base_score -= distance_to_target
	
	if combat_manager.is_in_cover(Character.new(target_position)) != CombatManager.CoverType.NONE:
		base_score += 5.0
	
	return base_score

func evaluate_attack(ai_character: Character, target: Character) -> float:
	var weapon = ai_character.get_equipped_weapon()
	var base_score = 20.0
	
	base_score += (1.0 - target.health / target.max_health) * 10.0
	base_score += weapon.damage * 2.0
	
	if combat_manager.is_in_cover(target) == CombatManager.CoverType.NONE:
		base_score += 5.0
	
	base_score += randf() * 2.0
	
	return base_score

func evaluate_item_use(ai_character: Character) -> float:
	return 5.0

func evaluate_aim(ai_character: Character) -> float:
	return 15.0 if combat_manager.is_in_cover(ai_character) == CombatManager.CoverType.FULL else 5.0

func execute_action(ai_character: Character, action: Dictionary) -> void:
	match action.type:
		"move":
			combat_manager.move_character(ai_character, action.target)
		"attack":
			combat_manager.attack_character(ai_character, action.target)
		"use_item":
			combat_manager.use_item(ai_character)
		"aim":
			combat_manager.aim(ai_character)
	
	combat_manager.end_turn()
	
func apply_ai_variations() -> void:
	if game_state.use_ai_variations:
		# Implement AI variation logic
		pass

func apply_enemy_deployment_variables() -> void:
	if game_state.use_enemy_deployment_variables:
		# Implement variable enemy deployment
		pass

func apply_escalating_battles() -> void:
	if game_state.use_escalating_battles:
		# Implement escalating battle mechanics
		pass

func apply_elite_level_enemies() -> void:
	if game_state.use_elite_level_enemies:
		# Implement elite enemy generation
		pass
