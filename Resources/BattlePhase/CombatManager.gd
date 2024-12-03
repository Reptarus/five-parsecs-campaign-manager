extends Node

signal turn_started(character: Character)
signal turn_ended(character: Character)
signal ui_update_needed(current_round: int, phase: int, current_character: Character)
signal log_action(action: String)
signal character_moved(character: Character, new_position: Vector2i)
signal enable_player_controls(character: Character)
signal action_completed

const MAX_ROUNDS = 20
const MAX_RETRIES = 3

var game_state_manager: Node  # Will be set at runtime
var current_mission: Mission
var battlefield: TileMap
var active_character: Character
var battle_system: Node  # Will be set at runtime

func _init() -> void:
	pass

func initialize(p_game_state_manager: Node, p_mission: Mission, p_battlefield: TileMap, p_battle_system: Node) -> void:
	if not _validate_initialization_params(p_game_state_manager, p_mission, p_battlefield, p_battle_system):
		return
		
	game_state_manager = p_game_state_manager
	current_mission = p_mission
	battlefield = p_battlefield
	battle_system = p_battle_system
	
	_connect_signals()

func cleanup() -> void:
	active_character = null

func end_combat(outcome: int) -> void:
	var victory = outcome == GlobalEnums.VictoryConditionType.QUESTS
	var messages = {
		GlobalEnums.VictoryConditionType.QUESTS: "Victory achieved!",
		GlobalEnums.VictoryConditionType.ELIMINATION: "Mission failed...",
		GlobalEnums.VictoryConditionType.EXTRACTION: "Tactical retreat executed",
		GlobalEnums.VictoryConditionType.TURNS: "Battle ended in stalemate"
	}
	
	game_state_manager.handle_game_over(victory)
	log_action.emit(messages[outcome])

func start_attack(character: Character) -> void:
	if not character or not character.can_attack():
		return
		
	active_character = character
	enable_player_controls.emit(character)

func start_movement(character: Character) -> void:
	if not character or not character.can_move():
		return
		
	active_character = character
	enable_player_controls.emit(character)

func execute_attack(attacker: Character, target: Character) -> void:
	if not _validate_attack(attacker, target):
		return
		
	var damage = _calculate_damage(attacker, target)
	target.take_damage(damage)
	
	log_action.emit("%s attacks %s for %d damage" % [attacker.name, target.name, damage])
	action_completed.emit()
	
	if target.is_defeated():
		_handle_character_defeat(target)

func execute_movement(character: Character, new_position: Vector2i) -> void:
	if not _validate_movement(character, new_position):
		return
		
	var old_position = character.position
	character.position = new_position
	
	character_moved.emit(character, new_position)
	log_action.emit("%s moves from %s to %s" % [character.name, old_position, new_position])
	action_completed.emit()

# Private methods
func _validate_initialization_params(p_game_state_manager: Node, p_mission: Mission, p_battlefield: TileMap, p_battle_system: Node) -> bool:
	if not p_game_state_manager or not p_mission or not p_battlefield or not p_battle_system:
		push_error("Invalid parameters provided to CombatManager")
		return false
	return true

func _connect_signals() -> void:
	if battle_system:
		battle_system.connect("phase_changed", _on_phase_changed)
		battle_system.connect("turn_started", _on_turn_started)
		battle_system.connect("turn_ended", _on_turn_ended)

func _validate_attack(attacker: Character, target: Character) -> bool:
	if not attacker or not target:
		return false
	if not attacker.can_attack():
		return false
	if not _is_in_range(attacker, target):
		return false
	return true

func _validate_movement(character: Character, new_position: Vector2i) -> bool:
	if not character or not character.can_move():
		return false
	if not _is_valid_position(new_position):
		return false
	if not _is_within_move_range(character, new_position):
		return false
	return true

func _calculate_damage(attacker: Character, target: Character) -> int:
	var base_damage = attacker.get_attack_power()
	var defense = target.get_defense()
	return max(1, base_damage - defense)  # Minimum 1 damage

func _handle_character_defeat(character: Character) -> void:
	log_action.emit("%s is defeated!" % character.name)
	if character.is_player_controlled:
		_check_defeat_condition()
	else:
		_check_victory_condition()

func _check_victory_condition() -> void:
	var enemies_remaining = game_state_manager.game_state.get_active_enemies().size()
	if enemies_remaining == 0:
		end_combat(GlobalEnums.VictoryConditionType.ELIMINATION)

func _check_defeat_condition() -> void:
	var allies_remaining = game_state_manager.game_state.get_active_allies().size()
	if allies_remaining == 0:
		end_combat(GlobalEnums.VictoryConditionType.ELIMINATION)

func _is_in_range(attacker: Character, target: Character) -> bool:
	var distance = attacker.position.distance_to(target.position)
	return distance <= attacker.get_attack_range()

func _is_valid_position(position: Vector2i) -> bool:
	return battlefield.get_cell_source_id(0, position) != -1

func _is_within_move_range(character: Character, new_position: Vector2i) -> bool:
	var distance = character.position.distance_to(Vector2(new_position))
	return distance <= character.get_move_range()

# Signal handlers
func _on_phase_changed(new_phase: int) -> void:
	ui_update_needed.emit(battle_system.current_round, new_phase, active_character)

func _on_turn_started(character: Character) -> void:
	active_character = character
	turn_started.emit(character)

func _on_turn_ended(character: Character) -> void:
	if character == active_character:
		active_character = null
	turn_ended.emit(character)

func handle_attack(attacker: Character, target: Character) -> void:
	if not _validate_attack(attacker, target):
		return
		
	# Check for terrain effects
	var attacker_pos = get_character_position(attacker)
	var target_pos = get_character_position(target)
	var terrain_modifier = _calculate_terrain_modifier(attacker_pos, target_pos)
	
	# Apply pre-attack effects
	_apply_pre_attack_effects(attacker)
	
	# Determine attack type and resolve
	if _is_in_melee_range(attacker_pos, target_pos):
		combat_resolver._resolve_melee_attack(attacker, target)
	else:
		combat_resolver._resolve_ranged_attack(attacker, target)
	
	# Handle post-attack effects
	_handle_post_attack_effects(attacker)
	action_completed.emit()

func _calculate_terrain_modifier(attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	var modifier = 1.0
	var target_terrain = battlefield_manager.get_terrain_at(target_pos)
	
	# Apply cover bonuses
	if TerrainTypes.get_cover_value(target_terrain) > 0:
		modifier *= 0.75
	
	# Apply elevation advantages
	var elevation_diff = TerrainTypes.get_elevation(battlefield_manager.get_terrain_at(attacker_pos)) - \
						TerrainTypes.get_elevation(target_terrain)
	if elevation_diff > 0:
		modifier *= 1.2
	
	return modifier
