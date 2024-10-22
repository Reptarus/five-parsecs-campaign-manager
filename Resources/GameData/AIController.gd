class_name AIController
extends Node

signal ai_action_completed(action: Dictionary)

@export var ai_behavior: GlobalEnums.AIBehavior = GlobalEnums.AIBehavior.AGGRESSIVE

var combat_manager: CombatManager
var game_state_manager: GameStateManager
var escalating_battles_manager: EscalatingBattlesManager
var enemy_deployment_manager: EnemyDeploymentManager

func _init() -> void:
	pass  # Initialize managers in the initialize function

func initialize(_combat_manager: CombatManager, _game_state_manager: GameStateManager) -> void:
	combat_manager = _combat_manager
	game_state_manager = _game_state_manager
	var game_state = game_state_manager.get_game_state()
	escalating_battles_manager = EscalatingBattlesManager.new(game_state)
	enemy_deployment_manager = EnemyDeploymentManager.new(game_state)
	var difficulty_settings = game_state_manager.difficulty_settings
	escalating_battles_manager.initialize(game_state, difficulty_settings)
	enemy_deployment_manager.initialize(game_state, difficulty_settings)

func perform_ai_turn(ai_character: Character) -> void:
	var action: Dictionary
	match ai_behavior:
		GlobalEnums.AIBehavior.AGGRESSIVE, GlobalEnums.AIBehavior.CAUTIOUS, GlobalEnums.AIBehavior.DEFENSIVE, GlobalEnums.AIBehavior.TACTICAL:
			action = determine_best_action(ai_character)
		GlobalEnums.AIBehavior.RAMPAGE, GlobalEnums.AIBehavior.BEAST:
			action = determine_dice_based_action(ai_character)
		_:
			push_error("Invalid AI behavior: %s" % ai_behavior)
			action = determine_best_action(ai_character)  # Fallback to deterministic
	execute_action(ai_character, action)

func determine_best_action(ai_character: Character) -> Dictionary:
	var possible_actions := get_possible_actions(ai_character)
	var best_action := {}
	var best_score := -1.0

	for action in possible_actions:
		var score := evaluate_action(ai_character, action)
		if score > best_score:
			best_score = score
			best_action = action

	return best_action

func get_possible_actions(ai_character: Character) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []

	match ai_character.ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
			if combat_manager.is_in_cover(ai_character):
				actions.append({"type": "aim", "target": null})
		GlobalEnums.AIType.AGGRESSIVE:
			actions.append({"type": "move", "target": combat_manager.find_nearest_enemy(ai_character)})
		GlobalEnums.AIType.TACTICAL:
			actions.append({"type": "move", "target": combat_manager.find_tactical_position(ai_character)})
		GlobalEnums.AIType.DEFENSIVE:
			if not combat_manager.is_in_cover(ai_character):
				actions.append({"type": "move", "target": combat_manager.find_cover_position(ai_character)})
		GlobalEnums.AIType.BEAST, GlobalEnums.AIType.RAMPAGE:
			actions.append({"type": "move", "target": combat_manager.find_nearest_enemy(ai_character)})

	for target in combat_manager.get_valid_targets(ai_character):
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
	var base_score: float = 10.0
	var distance_to_target: float = ai_character.position.distance_to(target_position)
	
	base_score -= distance_to_target
	
	if combat_manager.is_in_cover(ai_character):
		base_score += 5.0
	
	return base_score

func evaluate_attack(ai_character: Character, target: Character) -> float:
	var weapon: Weapon = ai_character.get_equipped_weapon()
	var base_score := 20.0
	base_score += (1.0 - target.get_health() / float(target.get_max_health())) * 10.0
	base_score += float(weapon.get_damage()) * 2.0
	
	if not combat_manager.is_in_cover(target):
		base_score += 5.0
	return base_score

func evaluate_item_use(_ai_character: Character) -> float:
	return 5.0

func evaluate_aim(ai_character: Character) -> float:
	return 15.0 if combat_manager.is_in_cover(ai_character) else 5.0

func execute_action(ai_character: Character, action: Dictionary) -> void:
	match action.type:
		"move":
			combat_manager.move_character(ai_character, action.target)
		"attack":
			combat_manager.attack_character(ai_character, action.target)
		"use_item":
			combat_manager.use_item(ai_character, action.item)
		"aim":
			combat_manager.aim(ai_character)

	ai_action_completed.emit(action)
func determine_dice_based_action(ai_character: Character) -> Dictionary:
	var roll: int = game_state_manager.roll_dice(1, 6)
	
	match ai_character.ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			return _cautious_dice_action(ai_character, roll)
		GlobalEnums.AIType.AGGRESSIVE:
			return _aggressive_dice_action(ai_character, roll)
		GlobalEnums.AIType.TACTICAL:
			return _tactical_dice_action(ai_character, roll)
		GlobalEnums.AIType.DEFENSIVE:
			return _defensive_dice_action(ai_character, roll)
		_:
			return _beast_dice_action(ai_character, roll)

func _cautious_dice_action(ai_character: Character, roll: int) -> Dictionary:
	match roll:
		1:
			return {"type": "move", "target": combat_manager.find_distant_cover_position(ai_character)}
		2, 3:
			return {"type": "attack", "target": combat_manager.find_best_target(ai_character)}
		4, 5:
			return {"type": "move", "target": combat_manager.find_cover_within_range(ai_character, 12.0)}
		_:
			return {"type": "aim", "target": null}

func _aggressive_dice_action(ai_character: Character, roll: int) -> Dictionary:
	match roll:
		1, 2:
			return {"type": "move", "target": combat_manager.find_nearest_enemy(ai_character)}
		3, 4, 5:
			return {"type": "attack", "target": combat_manager.find_best_target(ai_character)}
		_:
			return {"type": "charge", "target": combat_manager.find_nearest_enemy(ai_character)}

func _tactical_dice_action(ai_character: Character, roll: int) -> Dictionary:
	match roll:
		1: return {"type": "move", "target": combat_manager.find_cover_near_enemy(ai_character)}
		2, 3: return {"type": "attack", "target": combat_manager.find_best_target(ai_character)}
		4: return {"type": "aim", "target": null}
		5: return {"type": "use_item", "target": null}
		_: return {"type": "move", "target": combat_manager.find_tactical_position(ai_character)}

func _defensive_dice_action(ai_character: Character, roll: int) -> Dictionary:
	match roll:
		1, 2:
			return {"type": "move", "target": combat_manager.find_cover_position(ai_character)}
		3, 4:
			return {"type": "attack", "target": combat_manager.find_best_target(ai_character)}
		5:
			return {"type": "aim", "target": null}
		_:
			return {"type": "use_item", "target": null}

func _beast_dice_action(ai_character: Character, roll: int) -> Dictionary:
	match roll:
		1, 2, 3:
			return {"type": "move", "target": combat_manager.find_nearest_enemy(ai_character)}
		4, 5:
			return {"type": "attack", "target": combat_manager.find_nearest_enemy(ai_character)}
		_:
			return {"type": "charge", "target": combat_manager.find_nearest_enemy(ai_character)}

func apply_escalation(battle_state: Dictionary) -> void:
	var escalation := escalating_battles_manager.check_escalation(battle_state)
	if not escalation.is_empty():
		_apply_escalation_effect(escalation)

func _apply_escalation_effect(escalation: Dictionary) -> void:
	match escalation.type:
		"reinforcements":
			_spawn_reinforcements()
		"psionic_event":
			_trigger_psionic_event()
		"equipment_malfunction":
			_cause_equipment_malfunction()
		"environmental_hazard":
			_create_environmental_hazard()
		"alien_intervention":
			_trigger_alien_intervention()

func _spawn_reinforcements() -> void:
	var new_enemies := enemy_deployment_manager.generate_deployment(GlobalEnums.AIType.TACTICAL, combat_manager.get_battle_map())
	for enemy in new_enemies:
		combat_manager.add_enemy(enemy)

func _trigger_psionic_event() -> void:
	var psionic_effects := ["mind_control", "fear_wave", "telekinetic_push"]
	var chosen_effect: String = psionic_effects[randi() % psionic_effects.size()]
	
	match chosen_effect:
		"mind_control":
			var target: Character = combat_manager.find_random_enemy()
			target.set_state("mind_controlled")
		"fear_wave":
			var enemies: Array[Character] = combat_manager.get_all_enemies()
			for enemy in enemies:
				enemy.apply_status_effect("fear")
		"telekinetic_push":
			var target: Character = combat_manager.find_nearest_enemy(combat_manager.get_player())
			if target:
				target.apply_force(Vector2(randf_range(-10, 10), randf_range(-10, 10)))

func _cause_equipment_malfunction() -> void:
	var malfunction_effects := ["weapon_jam", "armor_failure", "sensor_glitch"]
	var chosen_effect: String = malfunction_effects[randi() % malfunction_effects.size()]
	
	match chosen_effect:
		"weapon_jam":
			var target: Character = combat_manager.find_random_ally()
			if target:
				target.disable_weapon()
		"armor_failure":
			var target: Character = combat_manager.find_random_ally()
			if target:
				target.reduce_armor(50)
		"sensor_glitch":
			var target: Character = combat_manager.find_random_ally()
			if target:
				target.disable_sensors()

func _create_environmental_hazard() -> void:
	var hazard_effects := ["fire", "toxic_gas", "earthquake"]
	var chosen_effect: String = hazard_effects[randi() % hazard_effects.size()]
	
	match chosen_effect:
		"fire":
			combat_manager.create_hazard("fire", combat_manager.get_random_position())
		"toxic_gas":
			combat_manager.create_hazard("toxic_gas", combat_manager.get_random_position())
		"earthquake":
			combat_manager.trigger_earthquake()

func _trigger_alien_intervention() -> void:
	var intervention_effects := ["alien_attack", "alien_support", "alien_observation"]
	var chosen_effect: String = intervention_effects[randi() % intervention_effects.size()]
	
	match chosen_effect:
		"alien_attack":
			var new_aliens := enemy_deployment_manager.generate_deployment(GlobalEnums.AIType.BEAST, combat_manager.get_battle_map())
			for alien in new_aliens:
				combat_manager.add_enemy(alien)
		"alien_support":
			var new_allies := enemy_deployment_manager.generate_deployment(GlobalEnums.AIType.TACTICAL, combat_manager.get_battle_map())
			for ally in new_allies:
				combat_manager.add_ally(ally)
		"alien_observation":
			var observers := enemy_deployment_manager.generate_deployment(GlobalEnums.AIType.CAUTIOUS, combat_manager.get_battle_map())
			for observer in observers:
				combat_manager.add_neutral(observer)

func set_ai_behavior(behavior: GlobalEnums.AIBehavior) -> void:
	ai_behavior = behavior
