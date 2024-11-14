extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const Enemy = preload("res://Resources/RivalAndPatrons/Enemy.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")
const AIController = preload("res://Resources/GameData/AIController.gd")

signal combat_started
signal combat_ended(player_victory: bool)
signal turn_started(character: Character)
signal turn_ended(character: Character)
signal ui_update_needed(current_round: int, phase: GlobalEnums.BattlePhase, current_character: Character)
signal log_action(action: String)
signal character_moved(character: Character, new_position: Vector2i)
signal enable_player_controls(character: Character)
signal update_turn_label(round: int)
signal update_current_character_label(character_name: String)
signal highlight_valid_positions(positions: Array[Vector2i])

const MAX_ROUNDS := 12
const INVALID_POSITION := Vector2(-1, -1)

var current_round := 0
var mission: Mission
var crew: Array[Character] = []
var enemies: Array[Enemy] = []
var game_state_manager: GameStateManager
var ai_controller: AIController
var battlefield: TileMap
var active_character: Character
var battle_system: BattleSystem

func initialize(p_game_state_manager: GameStateManager, p_mission: Mission, p_battlefield: TileMap, p_battle_system: BattleSystem) -> void:
	if not _validate_initialization_params(p_game_state_manager, p_mission, p_battlefield, p_battle_system):
		return
		
	game_state_manager = p_game_state_manager
	mission = p_mission
	battlefield = p_battlefield
	battle_system = p_battle_system
	
	_setup_crew_and_enemies()
	_initialize_ai_controller()

func start_combat() -> void:
	current_round = 1
	combat_started.emit()
	_start_round()

func handle_move(character: Character, new_position: Vector2) -> void:
	character.position = new_position
	character_moved.emit(character, new_position)
	log_action.emit("%s moved to %s" % [character.name, str(new_position)])

func handle_attack(attacker: Character, target: Character) -> void:
	var damage = attacker.calculate_damage()
	target.take_damage(damage)
	log_action.emit("%s attacked %s for %d damage" % [attacker.name, target.name, damage])

func handle_end_turn() -> void:
	turn_ended.emit(active_character)
	active_character = null

func end_combat(outcome: GlobalEnums.VictoryConditionType) -> void:
	var victory = outcome == GlobalEnums.VictoryConditionType.QUESTS
	var messages = {
		GlobalEnums.VictoryConditionType.QUESTS: "Victory achieved!",
		GlobalEnums.VictoryConditionType.ELIMINATION: "Mission failed...",
		GlobalEnums.VictoryConditionType.EXTRACTION: "Tactical retreat executed",
		GlobalEnums.VictoryConditionType.TURNS: "Battle ended in stalemate"
	}
	
	game_state_manager.handle_game_over(victory)
	log_action.emit(messages[outcome])
	combat_ended.emit(victory)

# Battle system wrapper functions
func get_valid_move_positions(character: Character) -> Array[Vector2i]:
	return battle_system.get_valid_move_positions(character) if battle_system else []

func get_valid_targets(character: Character) -> Array[Character]:
	return battle_system.get_valid_targets(character) if battle_system else []

func get_character_at_position(position: Vector2i) -> Character:
	return battle_system.get_character_at_position(position) if battle_system else null

func get_mission_results() -> Dictionary:
	return battle_system.get_mission_results() if battle_system else {}

func find_cover_position(character: Character) -> Vector2:
	return battle_system.find_cover_position(character) if battle_system else Vector2.ZERO

func find_nearest_enemy(character: Character) -> Character:
	return battle_system.find_nearest_enemy(character) if battle_system else null

func find_tactical_position(character: Character) -> Vector2:
	return battle_system.find_tactical_position(character) if battle_system else Vector2.ZERO

func find_cover_near_enemy(character: Character) -> Vector2:
	return battle_system.find_cover_near_enemy(character) if battle_system else Vector2.ZERO

func find_best_target(character: Character) -> Character:
	return battle_system.find_best_target(character) if battle_system else null

func find_random_enemy() -> Character:
	return battle_system.find_random_enemy() if battle_system else null

func find_random_ally() -> Character:
	return battle_system.find_random_ally() if battle_system else null

func get_random_position() -> Vector2:
	return battle_system.get_random_position() if battle_system else Vector2.ZERO

# Character state management
func cleanup_reactions() -> void:
	_cleanup_character_state("reset_reaction_state")

func cleanup_quick_actions() -> void:
	_cleanup_character_state("reset_quick_actions")

func cleanup_enemy_actions() -> void:
	for enemy in enemies:
		enemy.reset_action_state()

func cleanup_slow_actions() -> void:
	_cleanup_character_state("reset_slow_actions")

func cleanup_round() -> void:
	_cleanup_character_state("reset_round_state")

func get_active_characters() -> Array[Character]:
	return crew + enemies.filter(func(c): return c.can_act())

func get_initiative_order() -> Array[Character]:
	var ordered = crew + enemies
	ordered.sort_custom(func(a, b): return a.initiative > b.initiative)
	return ordered

func get_enemy_units() -> Array[Character]:
	return enemies.map(func(e): return e as Character)

func deploy_character(character: Character, position: Vector2) -> void:
	character.position = position
	character_moved.emit(character, Vector2i(position))

func is_player_victory() -> bool:
	return enemies.is_empty() or _check_mission_objectives_complete()

# Private methods
func _validate_initialization_params(p_game_state_manager: GameStateManager, p_mission: Mission, p_battlefield: TileMap, p_battle_system: BattleSystem) -> bool:
	if not p_game_state_manager or not p_mission or not p_battlefield or not p_battle_system:
		push_error("Invalid parameters provided to CombatManager")
		return false
	return true

func _setup_crew_and_enemies() -> void:
	var current_ship = game_state_manager.get_current_ship()
	if not current_ship or not current_ship.crew:
		push_error("Invalid ship or crew")
		crew = []
		return
		
	crew = current_ship.crew
	enemies = mission.enemies if mission.enemies else []

func _initialize_ai_controller() -> void:
	ai_controller = AIController.new()
	ai_controller.setup(get_node("."), game_state_manager)

func _start_round() -> void:
	if current_round > MAX_ROUNDS:
		end_combat(GlobalEnums.VictoryConditionType.TURNS)
		return

	update_turn_label.emit(current_round)
	_perform_actions()

func _perform_actions() -> void:
	var all_units = (crew + enemies) as Array[Character]
	all_units.sort_custom(func(a: Character, b: Character): return a.reactions > b.reactions)

	for unit in all_units:
		_handle_unit_turn(unit)

	_end_round()

func _handle_unit_turn(unit: Character) -> void:
	active_character = unit
	update_current_character_label.emit(unit.name)
	turn_started.emit(unit)
	
	if unit in crew:
		enable_player_controls.emit(unit)
	else:
		_perform_enemy_action(unit)
		
	turn_ended.emit(unit)

func _perform_enemy_action(enemy: Character) -> void:
	ai_controller.set_ai_behavior(_get_ai_behavior(enemy.ai_type))
	ai_controller.perform_ai_turn(enemy)

func _get_ai_behavior(ai_type: GlobalEnums.FactionType) -> GlobalEnums.FactionType:
	if ai_type in GlobalEnums.FactionType.values():
		return ai_type
	push_error("Invalid AI behavior")
	return GlobalEnums.FactionType.NEUTRAL

func _end_round() -> void:
	_check_objective()
	_check_morale()
	current_round += 1
	_start_round()

func _check_objective() -> void:
	if game_state_manager.is_objective_completed():
		end_combat(GlobalEnums.VictoryConditionType.QUESTS)

func _check_morale() -> void:
	var casualties = game_state_manager.get_casualties_this_round()
	var panic_range = game_state_manager.get_panic_range()
	
	for i in range(casualties):
		if randi() % 6 + 1 <= panic_range:
			var enemy = game_state_manager.get_random_enemy()
			if enemy:
				game_state_manager.remove_enemy(enemy)
				log_action.emit("Enemy fled due to low morale!")

func _cleanup_character_state(method: String) -> void:
	for character in crew + enemies:
		character.call(method)

func _check_mission_objectives_complete() -> bool:
	if not mission:
		return false
		
	match mission.objective:
		GlobalEnums.MissionObjective.ELIMINATE:
			return enemies.is_empty()
		GlobalEnums.MissionObjective.SURVIVE:
			return current_round >= MAX_ROUNDS
		GlobalEnums.MissionObjective.CONTROL_POINT:
			return _check_control_points()
		GlobalEnums.MissionObjective.PROTECT:
			return _check_protected_targets()
		GlobalEnums.MissionObjective.RETRIEVE:
			return _check_retrieved_items()
	return false

func _check_control_points() -> bool:
	return false

func _check_protected_targets() -> bool:
	return false

func _check_retrieved_items() -> bool:
	return false
