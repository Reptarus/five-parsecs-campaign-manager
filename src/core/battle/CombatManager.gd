## Manages combat state and coordinates combat-related systems
class_name CombatManager
extends Node

## Required dependencies
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const BattleRules := preload("res://src/core/battle/BattleRules.gd")
const TerrainTypes := preload("res://src/core/battle/TerrainTypes.gd")

## Combat-related signals
signal combat_state_changed(new_state: Dictionary)
signal character_position_updated(character: Character, new_position: Vector2i)
signal terrain_modifier_applied(position: Vector2i, modifier: GlobalEnums.TerrainModifier)
signal combat_result_calculated(attacker: Character, target: Character, result: GlobalEnums.CombatResult)
signal combat_advantage_changed(character: Character, advantage: GlobalEnums.CombatAdvantage)
signal combat_status_changed(character: Character, status: GlobalEnums.CombatStatus)

## Reference to the battlefield manager
@export var battlefield_manager: BattlefieldManager

## Combat state tracking
var _active_combatants: Array[Character] = []
var _combat_positions: Dictionary = {}  # Maps Character to Vector2i position
var _terrain_modifiers: Dictionary = {}  # Maps Vector2i position to TerrainModifier
var _combat_advantages: Dictionary = {}  # Maps Character to CombatAdvantage
var _combat_statuses: Dictionary = {}  # Maps Character to CombatStatus

class CombatState:
	var character: Character
	var position: Vector2i
	var action_points: int
	var combat_advantage: GlobalEnums.CombatAdvantage
	var combat_status: GlobalEnums.CombatStatus
	var combat_tactic: GlobalEnums.CombatTactic
	
	func _init(char: Character) -> void:
		character = char
		position = Vector2i.ZERO
		action_points = BattleRules.BASE_ACTION_POINTS
		combat_advantage = GlobalEnums.CombatAdvantage.NONE
		combat_status = GlobalEnums.CombatStatus.NONE
		combat_tactic = GlobalEnums.CombatTactic.NONE

## Called when the node enters the scene tree
func _ready() -> void:
	if not battlefield_manager:
		push_warning("CombatManager: No battlefield manager assigned")

## Registers a character for combat tracking
func register_character(character: Character, position: Vector2i) -> void:
	if not character in _active_combatants:
		_active_combatants.append(character)
		_combat_positions[character] = position
		_combat_advantages[character] = GlobalEnums.CombatAdvantage.NONE
		_combat_statuses[character] = GlobalEnums.CombatStatus.NONE
		character_position_updated.emit(character, position)

## Unregisters a character from combat tracking
func unregister_character(character: Character) -> void:
	_active_combatants.erase(character)
	_combat_positions.erase(character)
	_combat_advantages.erase(character)
	_combat_statuses.erase(character)

## Updates a character's position
func update_character_position(character: Character, new_position: Vector2i) -> void:
	if character in _active_combatants:
		_combat_positions[character] = new_position
		character_position_updated.emit(character, new_position)
		_update_combat_state(character)

## Gets a character's current position
func get_character_position(character: Character) -> Vector2i:
	return _combat_positions.get(character, Vector2i.ZERO)

## Updates combat state for a character
func _update_combat_state(character: Character) -> void:
	if not character in _active_combatants:
		return
		
	var position := get_character_position(character)
	var modifiers := BattleRules.CombatModifiers.new()
	
	# Check terrain modifiers
	var terrain_modifier := get_terrain_modifier(position)
	modifiers.cover = terrain_modifier == GlobalEnums.TerrainModifier.COVER_BONUS
	
	# Check height advantage
	if battlefield_manager:
		var terrain_data: Dictionary = battlefield_manager.get_terrain_at(position)
		modifiers.height_advantage = terrain_data.get("elevation", 0) > 0
	
	# Check flanking
	modifiers.flanking = _check_flanking(character)
	
	# Update combat advantage
	var new_advantage := _calculate_combat_advantage(modifiers)
	if new_advantage != _combat_advantages[character]:
		_combat_advantages[character] = new_advantage
		combat_advantage_changed.emit(character, new_advantage)
	
	# Update combat status
	var new_status := _calculate_combat_status(character, modifiers)
	if new_status != _combat_statuses[character]:
		_combat_statuses[character] = new_status
		combat_status_changed.emit(character, new_status)

## Calculates combat advantage based on modifiers
func _calculate_combat_advantage(modifiers: BattleRules.CombatModifiers) -> GlobalEnums.CombatAdvantage:
	var advantage_count := 0
	
	if modifiers.height_advantage:
		advantage_count += 1
	if modifiers.flanking:
		advantage_count += 1
	if not modifiers.cover:
		advantage_count += 1
	
	match advantage_count:
		1:
			return GlobalEnums.CombatAdvantage.MINOR
		2:
			return GlobalEnums.CombatAdvantage.MAJOR
		3:
			return GlobalEnums.CombatAdvantage.OVERWHELMING
	
	return GlobalEnums.CombatAdvantage.NONE

## Calculates combat status based on character state and modifiers
func _calculate_combat_status(character: Character, modifiers: BattleRules.CombatModifiers) -> GlobalEnums.CombatStatus:
	var enemies := get_characters_in_range(get_character_position(character), BattleRules.BASE_MOVEMENT)
	var enemy_count := 0
	
	for enemy in enemies:
		if enemy.is_enemy() != character.is_enemy():
			enemy_count += 1
	
	if enemy_count >= 3:
		return GlobalEnums.CombatStatus.SURROUNDED
	elif modifiers.flanking:
		return GlobalEnums.CombatStatus.FLANKED
	elif modifiers.suppressed:
		return GlobalEnums.CombatStatus.PINNED
	
	return GlobalEnums.CombatStatus.NONE

## Checks if a character is being flanked
func _check_flanking(character: Character) -> bool:
	var char_pos := get_character_position(character)
	var enemies := get_characters_in_range(char_pos, BattleRules.BASE_MOVEMENT * 2)
	var flanking_positions := 0
	
	for enemy in enemies:
		if enemy.is_enemy() != character.is_enemy():
			var enemy_pos := get_character_position(enemy)
			if _is_flanking_position(enemy_pos, char_pos):
				flanking_positions += 1
	
	return flanking_positions >= 2

## Checks if a position is in a flanking arc relative to a target
func _is_flanking_position(attacker_pos: Vector2i, target_pos: Vector2i) -> bool:
	# Calculate vector from target to attacker
	var direction := Vector2(attacker_pos - target_pos)
	var angle := rad_to_deg(atan2(direction.y, direction.x))
	
	# Normalize angle to 0-360 range
	if angle < 0:
		angle += 360
	
	# Check if position is in flanking arc (120 degrees behind target)
	return angle >= 150 and angle <= 210

## Applies a terrain modifier to a position
func apply_terrain_modifier(position: Vector2i, modifier: GlobalEnums.TerrainModifier) -> void:
	_terrain_modifiers[position] = modifier
	terrain_modifier_applied.emit(position, modifier)
	
	# Update combat state for any characters at this position
	for character in _active_combatants:
		if get_character_position(character) == position:
			_update_combat_state(character)

## Gets terrain modifier at a position
func get_terrain_modifier(position: Vector2i) -> GlobalEnums.TerrainModifier:
	return _terrain_modifiers.get(position, GlobalEnums.TerrainModifier.NONE)

## Resolves combat between two characters
func resolve_combat(attacker: Character, target: Character, action: GlobalEnums.UnitAction) -> GlobalEnums.CombatResult:
	if not attacker in _active_combatants or not target in _active_combatants:
		return GlobalEnums.CombatResult.NONE
		
	var modifiers := BattleRules.CombatModifiers.new()
	
	# Get terrain modifiers
	var target_pos := get_character_position(target)
	modifiers.cover = get_terrain_modifier(target_pos) == GlobalEnums.TerrainModifier.COVER_BONUS
	
	# Get combat advantage
	modifiers.combat_advantage = _combat_advantages.get(attacker, GlobalEnums.CombatAdvantage.NONE)
	
	# Get combat status
	modifiers.combat_status = _combat_statuses.get(attacker, GlobalEnums.CombatStatus.NONE)
	
	# Calculate hit chance
	var hit_chance := BattleRules.calculate_hit_chance(BattleRules.BASE_HIT_CHANCE, modifiers)
	
	# Get combat result
	return BattleRules.get_combat_result(hit_chance, modifiers)

## Checks if a position is in melee range of another position
func is_in_melee_range(pos1: Vector2, pos2: Vector2) -> bool:
	return pos1.distance_to(pos2) <= BattleRules.BASE_MOVEMENT

## Calculates terrain modifier for a position
func calculate_terrain_modifier(from_pos: Vector2i, to_pos: Vector2i) -> float:
	if not battlefield_manager:
		return 0.0
		
	var total_modifier: float = 0.0
	
	# Get terrain at both positions
	var from_terrain: Dictionary = battlefield_manager.get_terrain_at(from_pos)
	var to_terrain: Dictionary = battlefield_manager.get_terrain_at(to_pos)
	
	# Apply height advantage
	if from_terrain.get("elevation", 0) > to_terrain.get("elevation", 0):
		total_modifier += BattleRules.HEIGHT_MODIFIER
	
	# Apply cover bonus
	if to_terrain.get("provides_cover", false):
		total_modifier += BattleRules.COVER_MODIFIER
	
	# Apply terrain-specific modifiers
	var terrain_type: TerrainTypes.Type = to_terrain.get("type", TerrainTypes.Type.NONE)
	total_modifier += TerrainTypes.get_combat_modifier(terrain_type)
	
	return total_modifier

## Checks if a character can perform a combat action
func can_perform_combat_action(character: Character, action: GlobalEnums.UnitAction, target_position: Vector2) -> bool:
	if not character in _active_combatants:
		return false
		
	var char_pos: Vector2 = get_character_position(character)
	var distance: float = char_pos.distance_to(target_position)
	
	match action:
		GlobalEnums.UnitAction.ATTACK:
			return distance <= character.get_weapon_range()
		GlobalEnums.UnitAction.BRAWL:
			return is_in_melee_range(char_pos, target_position)
		GlobalEnums.UnitAction.SNAP_FIRE:
			return distance <= character.get_weapon_range() * 0.75
		_:
			return true

## Gets all characters within range of a position
func get_characters_in_range(position: Vector2, range: float) -> Array[Character]:
	var in_range: Array[Character] = []
	
	for character in _active_combatants:
		var char_pos: Vector2 = get_character_position(character)
		if char_pos.distance_to(position) <= range:
			in_range.append(character)
	
	return in_range

## Gets all valid targets for a character's action
func get_valid_targets(character: Character, action: GlobalEnums.UnitAction) -> Array[Character]:
	var valid_targets: Array[Character] = []
	var char_pos: Vector2 = get_character_position(character)
	
	for potential_target in _active_combatants:
		if potential_target == character or not potential_target.is_alive():
			continue
			
		if character.is_enemy() != potential_target.is_enemy():
			var target_pos: Vector2 = get_character_position(potential_target)
			if can_perform_combat_action(character, action, target_pos):
				valid_targets.append(potential_target)
	
	return valid_targets

## Checks if there's line of sight between two positions
func check_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	if not battlefield_manager:
		return true
		
	# Convert to grid positions
	var grid_from := Vector2i(from_pos)
	var grid_to := Vector2i(to_pos)
	
	# Get all positions along the line
	var line: Array[Vector2i] = get_line_positions(grid_from, grid_to)
	
	# Check each position for blocking terrain
	for pos in line:
		var terrain: Dictionary = battlefield_manager.get_terrain_at(pos)
		if TerrainTypes.blocks_line_of_sight(terrain.get("type", TerrainTypes.Type.NONE)):
			return false
	
	return true

## Gets all positions along a line between two points
func get_line_positions(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var steps: int = maxi(abs(dx), abs(dy))
	
	if steps == 0:
		positions.append(from)
		return positions
	
	var x_inc: float = float(dx) / steps
	var y_inc: float = float(dy) / steps
	
	for i in range(steps + 1):
		positions.append(Vector2i(
			from.x + roundi(x_inc * i),
			from.y + roundi(y_inc * i)
		))
	
	return positions
