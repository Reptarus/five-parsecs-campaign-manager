class_name AIController
extends Node

var combat_manager: CombatManager
var game_state: GameState

func initialize(_combat_manager: CombatManager, _game_state: GameState) -> void:
	combat_manager = _combat_manager
	game_state = _game_state

# Perform an AI turn for the given character
func perform_ai_turn(ai_character: Character) -> void:
	var action = determine_best_action(ai_character)
	execute_action(ai_character, action)

# Determine the best action for the AI character
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

# Get all possible actions for the AI character
func get_possible_actions(ai_character: Character) -> Array:
	var actions = []

	match ai_character.ai_type:
		Character.AIType.CAUTIOUS:
			actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
			if combat_manager.is_in_cover(ai_character):
				actions.append({"type": "aim", "target": null})
		Character.AIType.AGGRESSIVE:
			actions.append({"type": "move", "target": combat_manager.find_closest_enemy(ai_character)})
		Character.AIType.TACTICAL:
			actions.append({"type": "move", "target": combat_manager.find_tactical_position(ai_character)})
		Character.AIType.DEFENSIVE:
			if not combat_manager.is_in_cover(ai_character):
				actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})

	for target in combat_manager.get_valid_targets(ai_character):
		if combat_manager.can_attack(ai_character, target):
			actions.append({"type": "attack", "target": target})

	if ai_character.has_usable_items():
		actions.append({"type": "use_item", "target": null})

	return actions

# Evaluate the potential effectiveness of an action
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
	return 0.0

# Evaluate a move action
func evaluate_move(ai_character: Character, target_position: Vector2) -> float:
	var base_score = 10.0
	var distance_to_target = ai_character.position.distance_to(target_position)
	
	base_score -= distance_to_target
	
	if combat_manager.is_in_cover(ai_character):
		base_score += 5.0
	
	return base_score

# Evaluate an attack action
func evaluate_attack(ai_character: Character, target: Character) -> float:
	var weapon = ai_character.get_equipped_weapon()
	var base_score = 20.0
	
	base_score += (1.0 - target.health / target.max_health) * 10.0
	base_score += weapon.damage * 2.0
	
	if not combat_manager.is_in_cover(target):
		base_score += 5.0
	
	return base_score

# Evaluate using an item
func evaluate_item_use(ai_character: Character) -> float:
	return 5.0  # Base score for using an item, can be adjusted based on item type and situation

# Evaluate aiming
func evaluate_aim(ai_character: Character) -> float:
	return 15.0 if combat_manager.is_in_cover(ai_character) else 5.0

# Execute the chosen action
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
