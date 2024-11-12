class_name CombatManager
extends Node

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal ui_update_needed(current_round: int, phase: GlobalEnums.CampaignPhase, current_character: Character)
signal log_action(action: String)
signal character_moved(character: Character, new_position: Vector2i)
signal enable_player_controls(character: Character)
signal update_turn_label(round: int)
signal update_current_character_label(character_name: String)
signal highlight_valid_positions(positions: Array[Vector2i])

const MAX_ROUNDS := 12

var current_round := 0
var mission: Mission
var crew: Array[Character]
var enemies: Array[Character]
var game_state_manager
var ai_controller: AIController
var battlefield: TileMap
var active_character: Character

func initialize(p_game_state_manager, p_mission: Mission, p_battlefield: TileMap) -> void:
	game_state_manager = p_game_state_manager
	mission = p_mission
	battlefield = p_battlefield
	
	var current_ship = game_state_manager.get_current_ship()
	if current_ship and current_ship.crew:
		crew = current_ship.crew
	else:
		push_error("Unable to access crew from current ship")
		crew = []
	
	# Assuming enemies are stored directly in the Mission resource
	if mission.has("enemies"):
		enemies = mission.enemies as Array[Character]
	else:
		push_error("Mission does not have an 'enemies' property")
		enemies = []

func _ready() -> void:
	ai_controller = AIController.new()
	ai_controller.initialize(self, game_state_manager)

func start_combat() -> void:
	current_round = 1
	combat_started.emit()
	_start_round()

func _start_round() -> void:
	if current_round > MAX_ROUNDS:
		end_combat(false)
		return

	update_turn_label.emit(current_round)
	_perform_actions()

func _perform_actions() -> void:
	var all_units: Array[Character] = []
	all_units.append_array(crew)
	all_units.append_array(enemies)
	all_units.sort_custom(func(a: Character, b: Character): return a.reactions > b.reactions)

	for unit in all_units:
		active_character = unit
		update_current_character_label.emit(unit.name)
		turn_started.emit(unit)
		if unit in crew:
			enable_player_controls.emit(unit)
		else:
			_perform_enemy_action(unit)
		turn_ended.emit(unit)

	_end_round()

func handle_move(character: Character, new_position: Vector2) -> void:
	character.position = new_position
	character_moved.emit(character, new_position)
	log_action.emit(character.name + " moved to " + str(new_position))

func handle_attack(attacker: Character, target: Character) -> void:
	var damage = attacker.calculate_damage()
	target.take_damage(damage)
	log_action.emit(attacker.name + " attacked " + target.name + " for " + str(damage) + " damage")

func handle_end_turn() -> void:
	turn_ended.emit(active_character)
	active_character = null

func _perform_enemy_action(enemy: Character) -> void:
	var ai_behavior = _get_ai_behavior(enemy.ai_type)
	ai_controller.set_ai_behavior(ai_behavior)
	ai_controller.perform_ai_turn(enemy)

func _get_ai_behavior(ai_type: GlobalEnums.AIType) -> GlobalEnums.AIBehavior:
	match ai_type:
		GlobalEnums.AIType.CAUTIOUS:
			return GlobalEnums.AIBehavior.CAUTIOUS
		GlobalEnums.AIType.AGGRESSIVE:
			return GlobalEnums.AIBehavior.AGGRESSIVE
		GlobalEnums.AIType.TACTICAL:
			return GlobalEnums.AIBehavior.TACTICAL
		GlobalEnums.AIType.DEFENSIVE:
			return GlobalEnums.AIBehavior.DEFENSIVE
		GlobalEnums.AIType.RAMPAGE:
			return GlobalEnums.AIBehavior.RAMPAGE
		GlobalEnums.AIType.BEAST:
			return GlobalEnums.AIBehavior.BEAST
		GlobalEnums.AIType.GUARDIAN:
			return GlobalEnums.AIBehavior.GUARDIAN
		_:
			push_error("Invalid AI type")
			return GlobalEnums.AIBehavior.CAUTIOUS

func _end_round() -> void:
	_check_objective()
	_check_morale()
	current_round += 1
	_start_round()

func _check_objective() -> void:
	if game_state_manager.is_objective_completed():
		end_combat(true)

func _check_morale() -> void:
	var casualties_this_round = game_state_manager.get_casualties_this_round()
	
	for i in range(casualties_this_round):
		if _roll_dice(6) <= game_state_manager.get_panic_range():
			var enemy_to_remove = game_state_manager.get_random_enemy()
			if enemy_to_remove:
				game_state_manager.remove_enemy(enemy_to_remove)
				log_action.emit("Enemy fled due to low morale!")

func _roll_dice(sides: int) -> int:
	return randi() % sides + 1

func end_combat(player_victory: bool) -> void:
	combat_ended.emit(player_victory)

func is_combat_over() -> bool:
	return crew.is_empty() or enemies.is_empty() or current_round > MAX_ROUNDS

func get_valid_move_positions(_character: Character) -> Array[Vector2i]:
	# Implement logic to get valid move positions
	var valid_positions: Array[Vector2i] = []
	# ... (implement the logic)
	return valid_positions

func get_valid_targets(_character: Character) -> Array[Character]:
	# Implement logic to get valid targets
	var valid_targets: Array[Character] = []
	# ... (implement the logic)
	return valid_targets

func get_character_at_position(_position: Vector2) -> Character:
	# Implement logic to get character at position
	# ... (implement the logic)
	return null

func get_mission_results() -> Dictionary:
	# Implement logic to get mission results
	var results = {}
	# ... (implement the logic)
	return results
