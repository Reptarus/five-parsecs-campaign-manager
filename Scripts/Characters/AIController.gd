class_name AIController
extends Node

var combat_manager: CombatManager
var game_state: GameState
var optional_ai: OptionalEnemyAI

func _init(_combat_manager: CombatManager, _game_state: GameState):
	combat_manager = _combat_manager
	game_state = _game_state
	optional_ai = OptionalEnemyAI.new(combat_manager)

func perform_ai_turn(ai_character: Character) -> void:
	var action: Dictionary
	
	if game_state.use_optional_ai:
		action = optional_ai.determine_action(ai_character)
	else:
		action = determine_best_action(ai_character)
	
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
		OptionalEnemyAI.AIType.CAUTIOUS:
			actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
			if combat_manager.is_in_cover(ai_character):
				actions.append({"type": "aim", "target": null})
		OptionalEnemyAI.AIType.AGGRESSIVE:
			actions.append({"type": "move", "target": combat_manager.find_closest_enemy(ai_character)})
		OptionalEnemyAI.AIType.TACTICAL:
			actions.append({"type": "move", "target": combat_manager.find_tactical_position(ai_character)})
		OptionalEnemyAI.AIType.DEFENSIVE:
			if not combat_manager.is_in_cover(ai_character):
				actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})

	for target in combat_manager.current_battle.player_characters:
		if combat_manager.can_attack(ai_character, target):
			actions.append({"type": "attack", "target": target})

	if ai_character.has_usable_items():
		actions.append({"type": "use_item", "target": null})

	return actions

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

	if combat_manager.is_in_cover(Character.new(target_position)):
		base_score += 5.0

	return base_score

func evaluate_attack(ai_character: Character, target: Character) -> float:
	var weapon = ai_character.get_equipped_weapon()
	var base_score = 20.0

	base_score += (1.0 - target.health / target.max_health) * 10.0
	base_score += weapon.damage * 2.0

	if not combat_manager.is_in_cover(target):
		base_score += 5.0

	base_score += randf() * 2.0

	return base_score

func evaluate_item_use(ai_character: Character) -> float:
	return 5.0  # Base score for using an item, can be adjusted based on item type and situation

func evaluate_aim(ai_character: Character) -> float:
	return 15.0 if combat_manager.is_in_cover(ai_character) else 5.0

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
		"move_and_fire":
			combat_manager.move_character(ai_character, action.move_to)
			combat_manager.attack_character(ai_character, action.fire_at)
		"move_to_brawl":
			combat_manager.move_to_brawl(ai_character, action.target)
		"charge":
			combat_manager.charge(ai_character, action.target)
		"dash":
			combat_manager.dash(ai_character, action.move_to)
		"retreat":
			combat_manager.retreat(ai_character, action.move_to)

	combat_manager.end_turn()
