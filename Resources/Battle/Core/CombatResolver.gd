## Handles combat resolution and effects in the Five Parsecs battle system
class_name CombatResolver
extends Node

## Signals
signal combat_started(attacker: Character, defender: Character)
signal combat_ended(attacker: Character, defender: Character, hit: bool, damage: int)
signal critical_hit(attacker: Character, defender: Character, multiplier: float)
signal special_effect_triggered(attacker: Character, defender: Character, effect: String)
signal target_selected(attacker: Character, target: Character)
signal target_invalid(attacker: Character, reason: String)

## Required dependencies
const GlobalEnums := preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character := preload("res://Resources/Core/Character/Base/Character.gd")
const BattlefieldManager := preload("res://Resources/Battle/Core/BattlefieldManager.gd")

## Combat modifiers
const CRITICAL_HIT_THRESHOLD: int = 6
const MAX_RANGE_PENALTY: int = -4
const COVER_BONUS: int = 2
const ELEVATION_BONUS: int = 1

## Status effect thresholds
const STUN_THRESHOLD: float = 0.4  # 40% of max health
const WOUND_THRESHOLD: float = 0.25  # 25% of max health

## Reference to the battle state machine
@export var battle_state_machine: Node  # Will be cast to BattleStateMachine
## Reference to the battlefield manager
@export var battlefield_manager: Node   # Will be cast to BattlefieldManager
## Reference to the combat manager
@export var combat_manager: Node        # Will be cast to CombatManager

## Cache for active status effects - maps Character to Array[String]
var _active_effects: Dictionary = {}
## Cache for combat modifiers - maps Character to Dictionary of modifiers
var _combat_modifiers: Dictionary = {}

## Called when the node enters the scene tree
func _ready() -> void:
	if not combat_manager:
		push_warning("CombatResolver: No combat manager assigned")
	if not battle_state_machine:
		push_warning("CombatResolver: No battle state machine assigned")
	if not battlefield_manager:
		push_warning("CombatResolver: No battlefield manager assigned")

## Resolves a combat action between an attacker and their target
## Parameters:
## - attacker: The Character initiating the combat action
## - action: The type of action from GlobalEnums.UnitAction
func resolve_combat_action(attacker: Character, action: int) -> void:
	if not attacker:
		push_error("CombatResolver: Invalid attacker")
		return
		
	var target: Character = await _get_valid_target(attacker, action)
	if not target:
		target_invalid.emit(attacker, "No valid target selected")
		return
	
	if not _validate_combat_requirements(attacker, target, action):
		return
	
	combat_started.emit(attacker, target)
	
	match action:
		GlobalEnums.UnitAction.ATTACK:
			await _resolve_ranged_attack(attacker, target)
		GlobalEnums.UnitAction.BRAWL:
			await _resolve_melee_attack(attacker, target)
		GlobalEnums.UnitAction.SNAP_FIRE:
			await _resolve_snap_fire(attacker, target)
		_:
			push_warning("CombatResolver: Invalid combat action %d" % action)

## Validates combat requirements between attacker and target
## Returns: bool indicating if combat can proceed
func _validate_combat_requirements(attacker: Character, target: Character, action: int) -> bool:
	if not combat_manager:
		push_error("CombatResolver: Cannot validate combat requirements without combat manager")
		return false
		
	if not attacker or not target:
		push_error("CombatResolver: Invalid attacker or target")
		return false
		
	# Check if target is in range
	var distance: float = _get_distance_to_target(attacker, target)
	var max_range: float = _get_max_range_for_action(attacker, action)
	
	if distance > max_range:
		target_invalid.emit(attacker, "Target out of range")
		return false
	
	# Check line of sight for ranged attacks
	if action in [GlobalEnums.UnitAction.ATTACK, GlobalEnums.UnitAction.SNAP_FIRE]:
		if not battlefield_manager or not battlefield_manager.check_line_of_sight(attacker, target):
			target_invalid.emit(attacker, "No line of sight to target")
			return false
	
	# Check melee requirements
	if action == GlobalEnums.UnitAction.BRAWL:
		if not combat_manager.is_in_melee_range(attacker.position, target.position):
			target_invalid.emit(attacker, "Target not in melee range")
			return false
	
	return true

## Resolves a ranged attack between attacker and defender
func _resolve_ranged_attack(attacker: Character, defender: Character) -> void:
	var base_hit_chance: int = attacker.get_ranged_accuracy()
	var modifiers: int = _calculate_ranged_modifiers(attacker, defender)
	var final_chance: int = base_hit_chance + modifiers
	
	var roll: int = _roll_to_hit()
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_ranged_damage(attacker, defender, roll)
		_apply_damage(defender, damage)
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier: float = 2.0
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
		
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

## Resolves a melee attack between attacker and defender
func _resolve_melee_attack(attacker: Character, defender: Character) -> void:
	var base_hit_chance: int = attacker.get_melee_accuracy()
	var modifiers: int = _calculate_melee_modifiers(attacker, defender)
	var final_chance: int = base_hit_chance + modifiers
	
	var roll: int = _roll_to_hit()
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_melee_damage(attacker, defender, roll)
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier: float = _calculate_critical_multiplier(attacker)
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
			
		_apply_damage(defender, damage)
		_check_and_apply_status_effects(defender, damage)
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

## Resolves a snap fire attack between attacker and defender
func _resolve_snap_fire(attacker: Character, defender: Character) -> void:
	var base_hit_chance: int = attacker.get_ranged_accuracy() - 2  # Snap fire penalty
	var modifiers: int = _calculate_ranged_modifiers(attacker, defender)
	var final_chance: int = base_hit_chance + modifiers
	
	var roll: int = _roll_to_hit()
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_ranged_damage(attacker, defender, roll)
		damage = int(damage * 0.75)  # Reduced snap fire damage
		_apply_damage(defender, damage)
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

## Calculates modifiers for ranged attacks
## Returns: Total modifier value
func _calculate_ranged_modifiers(attacker: Character, defender: Character) -> int:
	if not combat_manager:
		return 0
		
	var modifiers: int = 0
	
	# Get terrain and elevation modifiers from combat manager
	var terrain_mod: float = combat_manager.calculate_terrain_modifier(
		Vector2i(attacker.position),
		Vector2i(defender.position)
	)
	modifiers += int(terrain_mod * 2)  # Convert float modifier to int bonus
	
	# Range modifiers
	var distance: float = _get_distance_to_target(attacker, defender)
	modifiers += _calculate_range_penalty(distance, attacker.get_weapon_range())
	
	# Status effects
	modifiers += _get_status_modifiers(attacker)
	modifiers += _get_status_modifiers(defender)
	
	return modifiers

## Calculates modifiers for melee attacks
## Returns: Total modifier value
func _calculate_melee_modifiers(attacker: Character, defender: Character) -> int:
	if not combat_manager:
		return 0
		
	var modifiers: int = 0
	
	# Get terrain modifiers from combat manager
	var terrain_mod: float = combat_manager.calculate_terrain_modifier(
		Vector2i(attacker.position),
		Vector2i(defender.position)
	)
	modifiers += int(terrain_mod * 2)  # Convert float modifier to int bonus
	
	# Status effects
	modifiers += _get_status_modifiers(attacker)
	modifiers += _get_status_modifiers(defender)
	
	# Weapon bonuses
	modifiers += attacker.get_melee_weapon_bonus()
	
	return modifiers

## Calculates range penalty based on distance and maximum range
## Returns: Range penalty value
func _calculate_range_penalty(distance: float, max_range: float) -> int:
	if distance <= max_range * 0.5:
		return 0
	elif distance <= max_range:
		return -2
	else:
		return MAX_RANGE_PENALTY

## Gets status effect modifiers for a character
## Returns: Total status effect modifier value
func _get_status_modifiers(character: Character) -> int:
	if not character:
		return 0
		
	var modifiers: int = 0
	
	if character.is_stunned():
		modifiers -= 2
	if character.is_wounded():
		modifiers -= 1
	
	return modifiers

## Gets a valid target for the given action
## Returns: Selected target Character or null
func _get_valid_target(attacker: Character, action: int) -> Character:
	var valid_targets: Array[Character] = _get_potential_targets(attacker, action)
	if valid_targets.is_empty():
		return null
	
	# For AI-controlled units
	if attacker.is_ai_controlled():
		return _select_ai_target(attacker, valid_targets)
	
	# For player-controlled units, wait for player selection
	var selected_target: Character = await _wait_for_player_target_selection(attacker, valid_targets)
	if selected_target:
		target_selected.emit(attacker, selected_target)
	
	return selected_target

## Gets all potential targets for an action
## Returns: Array of valid target Characters
func _get_potential_targets(attacker: Character, action: int) -> Array[Character]:
	if not combat_manager or not battle_state_machine:
		return []
		
	var max_range: float = _get_max_range_for_action(attacker, action)
	var potential_targets: Array[Character] = []
	
	for unit in battle_state_machine.active_units:
		if not unit is Character or unit == attacker or not unit.is_alive():
			continue
		
		if attacker.is_enemy() != unit.is_enemy():  # Only target opposing forces
			var distance: float = _get_distance_to_target(attacker, unit)
			if distance <= max_range:
				if action in [GlobalEnums.UnitAction.ATTACK, GlobalEnums.UnitAction.SNAP_FIRE]:
					if battlefield_manager and battlefield_manager.check_line_of_sight(attacker, unit):
						potential_targets.append(unit)
				else:  # Melee doesn't require LOS
					potential_targets.append(unit)
	
	return potential_targets

## Gets the maximum range for a given action
## Returns: Maximum range value
func _get_max_range_for_action(attacker: Character, action: int) -> float:
	match action:
		GlobalEnums.UnitAction.ATTACK:
			return attacker.get_weapon_range()
		GlobalEnums.UnitAction.SNAP_FIRE:
			return attacker.get_weapon_range() * 0.75
		GlobalEnums.UnitAction.BRAWL:
			return 1.5  # Melee range with slight tolerance
		_:
			return 0.0

## Gets the distance between attacker and target
## Returns: Distance value
func _get_distance_to_target(attacker: Character, target: Character) -> float:
	if not combat_manager or not attacker or not target:
		return INF
		
	var attacker_pos: Vector2 = combat_manager.get_character_position(attacker)
	var target_pos: Vector2 = combat_manager.get_character_position(target)
	return attacker_pos.distance_to(target_pos)

## Selects a target for AI-controlled units
## Returns: Selected target Character
func _select_ai_target(attacker: Character, valid_targets: Array[Character]) -> Character:
	var closest_target: Character = null
	var closest_distance: float = INF
	
	for target in valid_targets:
		var distance: float = _get_distance_to_target(attacker, target)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
	
	return closest_target

## Waits for player target selection
## Returns: Selected target Character or null
func _wait_for_player_target_selection(attacker: Character, valid_targets: Array[Character]) -> Character:
	# This will be implemented by the UI system
	# For now, just return the first valid target
	return valid_targets[0] if not valid_targets.is_empty() else null

## Rolls a d6 for hit resolution
## Returns: Roll result (1-6)
func _roll_to_hit() -> int:
	return randi() % 6 + 1

## Calculates critical hit multiplier for a character
## Returns: Critical hit damage multiplier
func _calculate_critical_multiplier(attacker: Character) -> float:
	var base_multiplier: float = 2.0
	if attacker.has_trait("deadly"):
		base_multiplier += 0.5
	return base_multiplier

## Calculates ranged damage
## Returns: Final damage value
func _calculate_ranged_damage(attacker: Character, defender: Character, roll: int) -> int:
	var weapon = attacker.get_active_weapon()
	if not weapon:
		return 0
	
	var base_damage: int = weapon.get_damage()
	var armor_reduction: int = defender.get_armor()
	
	return max(1, base_damage - armor_reduction)  # Minimum 1 damage

## Calculates melee damage
## Returns: Final damage value
func _calculate_melee_damage(attacker: Character, defender: Character, roll: int) -> int:
	var weapon = attacker.get_active_weapon()
	var base_damage: int = weapon.get_damage() if weapon else attacker.get_base_melee_damage()
	var armor_reduction: int = defender.get_armor()
	
	return max(1, base_damage - armor_reduction)  # Minimum 1 damage

## Applies damage to a target and checks for status effects
func _apply_damage(target: Character, damage: int) -> void:
	if not target:
		return
		
	target.take_damage(damage)
	_check_and_apply_status_effects(target, damage)

## Checks and applies status effects based on damage
func _check_and_apply_status_effects(target: Character, damage: int) -> void:
	if not target:
		return
		
	var max_health: int = target.get_max_health()
	
	# Check for stun
	if damage >= max_health * STUN_THRESHOLD:
		target.add_status_effect("stunned")
		special_effect_triggered.emit(null, target, "stunned")
	
	# Check for wound
	if damage >= max_health * WOUND_THRESHOLD:
		target.add_status_effect("wounded")
		special_effect_triggered.emit(null, target, "wounded")
	