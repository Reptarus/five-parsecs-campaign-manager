class_name AIController
extends Node

var combat_manager: CombatManager
var game_state: GameState

# AI types from core rulebook
enum AIType {
	CAUTIOUS,
	AGGRESSIVE,
	TACTICAL,
	DEFENSIVE,
	BEAST,
	RAMPAGING
}

# Compendium AI types (to be implemented as DLC if requested)
enum CompendiumAIType {
	COWARDLY,
	PROTECTIVE,
	BERSERKER,
	SNIPER
}

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
	var best_action: Dictionary = {}
	var best_score: float = -1.0

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
		AIType.CAUTIOUS:
			actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
			if combat_manager.is_in_cover(ai_character):
				actions.append({"type": "aim", "target": null})
		AIType.AGGRESSIVE:
			actions.append({"type": "move", "target": combat_manager.find_closest_enemy(ai_character)})
		AIType.TACTICAL:
			actions.append({"type": "move", "target": combat_manager.find_tactical_position(ai_character)})
		AIType.DEFENSIVE:
			if not combat_manager.is_in_cover(ai_character):
				actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
		AIType.BEAST:
			actions.append({"type": "move", "target": combat_manager.find_closest_enemy(ai_character)})
		AIType.RAMPAGING:
			actions.append({"type": "move", "target": combat_manager.find_random_position()})

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
	
	base_score += (1.0 - target.health / float(target.max_health)) * 10.0
	base_score += weapon.damage * 2.0
	
	if not combat_manager.is_in_cover(target):
		base_score += 5.0
	
	return base_score

# Evaluate using an item
func evaluate_item_use(_ai_character: Character) -> float:
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
			combat_manager.use_item(ai_character, action.item)  # Added action.item as the second argument
		"aim":
			combat_manager.aim(ai_character)

	combat_manager.end_turn()

# Compendium AI functions (based on Five Parsecs From Home-Compendium)
func get_compendium_possible_actions(ai_character: Character) -> Array:
	var actions = []
	
	# Check for psionic abilities
	if ai_character.has_psionics:
		var psionic_action = game_state.psionic_manager.determine_enemy_psionic_action(ai_character)
		actions.append({"type": "use_psionic", "power": psionic_action.power, "target": psionic_action.target})
	
	# Check for special species abilities
	if ai_character.species in ["Skulker", "Krag"]:
		actions.append({"type": "use_species_ability", "ability": get_species_ability(ai_character)})
	
	# Check for advanced equipment
	if ai_character.has_advanced_equipment():
		actions.append({"type": "use_advanced_equipment", "item": get_best_advanced_equipment(ai_character)})
	
	# Check for bot upgrades
	if ai_character.is_bot and ai_character.has_upgrades():
		actions.append({"type": "use_bot_upgrade", "upgrade": get_best_bot_upgrade(ai_character)})
	
	return actions

func evaluate_compendium_action(ai_character: Character, action: Dictionary) -> float:
	var base_score = 0.0
	
	match action.type:
		"use_psionic":
			base_score = evaluate_psionic_action(ai_character, action.power)
		"use_species_ability":
			base_score = evaluate_species_ability(ai_character, action.ability)
		"use_advanced_equipment":
			base_score = evaluate_advanced_equipment(ai_character, action.item)
		"use_bot_upgrade":
			base_score = evaluate_bot_upgrade(ai_character, action.upgrade)
	
	# Adjust score based on current situation
	if combat_manager.is_in_cover(ai_character):
		base_score *= 1.2
	
	return base_score

func get_best_psionic_ability(ai_character: Character) -> String:
	var abilities = ai_character.psionic_abilities
	var best_ability = ""
	var highest_score = 0
	
	for ability in abilities:
		var score = 0
		match ability:
			"Telekinesis":
				score = 10 if combat_manager.get_nearby_objects().size() > 0 else 5
			"Mind Control":
				score = 15 if combat_manager.get_nearby_enemies(ai_character).size() > 0 else 0
			"Healing":
				score = 20 if ai_character.health < ai_character.max_health * 0.5 else 5
			"Psionic Blast":
				score = 15 if combat_manager.get_nearby_enemies(ai_character).size() > 1 else 10
		
		if score > highest_score:
			highest_score = score
			best_ability = ability
	
	return best_ability

func get_species_ability(ai_character: Character) -> String:
	match ai_character.species:
		"Skulker":
			return "Shadow Blend"
		"Krag":
			return "Berserker Rage"
	return ""

func get_best_advanced_equipment(ai_character: Character) -> String:
	var equipment = ai_character.advanced_equipment
	var best_equipment = ""
	var highest_score = 0
	
	for item in equipment:
		var score = 0
		match item:
			"Energy Shield":
				score = 15 if ai_character.health < ai_character.max_health * 0.7 else 10
			"Grav Boots":
				score = 12 if combat_manager.is_difficult_terrain() else 5
			"Nano-Medkit":
				score = 18 if ai_character.health < ai_character.max_health * 0.3 else 8
			"Holo-Projector":
				score = 14 if not combat_manager.is_in_cover(ai_character) else 6
		
		if score > highest_score:
			highest_score = score
			best_equipment = item
	
	return best_equipment

func get_best_bot_upgrade(ai_character: Character) -> String:
	var upgrades = ai_character.bot_upgrades
	var best_upgrade = ""
	var highest_score = 0
	
	for upgrade in upgrades:
		var score = 0
		match upgrade:
			"Targeting System":
				score = 15 if combat_manager.get_distance_to_nearest_enemy(ai_character) > 5 else 10
			"Reinforced Plating":
				score = 18 if ai_character.health < ai_character.max_health * 0.5 else 12
			"Overclocked Processor":
				score = 14
			"Self-Repair Module":
				score = 20 if ai_character.health < ai_character.max_health * 0.3 else 10
		
		if score > highest_score:
			highest_score = score
			best_upgrade = upgrade
	
	return best_upgrade

func evaluate_psionic_action(ai_character: Character, power: String) -> float:
	var base_score = 25.0
	
	match power:
		"Telekinesis":
			base_score += 5 if combat_manager.get_nearby_objects().size() > 0 else 0
		"Mind Control":
			base_score += 10 if combat_manager.get_nearby_enemies(ai_character).size() > 0 else -5
		"Healing":
			base_score += 15 if ai_character.health < ai_character.max_health * 0.5 else -10
		"Psionic Blast":
			base_score += 10 if combat_manager.get_nearby_enemies(ai_character).size() > 1 else 0
	
	return base_score

func evaluate_species_ability(ai_character: Character, ability: String) -> float:
	var base_score = 20.0
	
	match ability:
		"Shadow Blend":
			base_score += 10 if not combat_manager.is_in_cover(ai_character) else 0
		"Berserker Rage":
			base_score += 15 if ai_character.health < ai_character.max_health * 0.5 else 5
	
	return base_score

func evaluate_advanced_equipment(ai_character: Character, item: String) -> float:
	var base_score = 15.0
	
	match item:
		"Energy Shield":
			base_score += 10 if ai_character.health < ai_character.max_health * 0.7 else 5
		"Grav Boots":
			base_score += 8 if combat_manager.is_difficult_terrain() else 0
		"Nano-Medkit":
			base_score += 15 if ai_character.health < ai_character.max_health * 0.3 else 0
		"Holo-Projector":
			base_score += 12 if not combat_manager.is_in_cover(ai_character) else 2
	
	return base_score

func evaluate_bot_upgrade(ai_character: Character, upgrade: String) -> float:
	var base_score = 18.0
	
	match upgrade:
		"Targeting System":
			base_score += 7 if combat_manager.get_distance_to_nearest_enemy(ai_character) > 5 else 3
		"Reinforced Plating":
			base_score += 10 if ai_character.health < ai_character.max_health * 0.5 else 5
		"Overclocked Processor":
			base_score += 5
		"Self-Repair Module":
			base_score += 12 if ai_character.health < ai_character.max_health * 0.3 else 2
	
	return base_score
