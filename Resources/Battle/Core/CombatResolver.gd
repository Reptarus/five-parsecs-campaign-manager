class_name CombatResolver
extends Node

signal combat_started(attacker: Character, defender: Character)
signal combat_ended(attacker: Character, defender: Character, hit: bool, damage: int)
signal critical_hit(attacker: Character, defender: Character, multiplier: float)
signal special_effect_triggered(attacker: Character, defender: Character, effect: String)
signal target_selected(attacker: Character, target: Character)
signal target_invalid(attacker: Character, reason: String)

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const BattlefieldManager = preload("res://Battle/BattlefieldManager.gd")

# Combat modifiers
const CRITICAL_HIT_THRESHOLD := 6
const MAX_RANGE_PENALTY := -4
const COVER_BONUS := 2
const ELEVATION_BONUS := 1

# Status effect thresholds
const STUN_THRESHOLD := 0.4  # 40% of max health
const WOUND_THRESHOLD := 0.25  # 25% of max health

@export var battle_state_machine: Node  # Will be cast to BattleStateMachine
@export var battlefield_manager: Node   # Will be cast to BattlefieldManager

# Cache for performance
var _active_effects: Dictionary = {}
var _combat_modifiers: Dictionary = {}

func resolve_combat_action(attacker: Character, action: int) -> void:
	var target = await _get_valid_target(attacker, action)
	if not target:
		target_invalid.emit(attacker, "No valid target selected")
		return
	
	if not _validate_combat_requirements(attacker, target, action):
		return
	
	combat_started.emit(attacker, target)
	
	match action:
		BattleStateMachine.UnitAction.ATTACK:
			await _resolve_ranged_attack(attacker, target)
		BattleStateMachine.UnitAction.BRAWL:
			await _resolve_melee_attack(attacker, target)
		BattleStateMachine.UnitAction.SNAP_FIRE:
			await _resolve_snap_fire(attacker, target)

func _validate_combat_requirements(attacker: Character, target: Character, action: int) -> bool:
	# Check if target is in range
	var distance = _get_distance_to_target(attacker, target)
	var max_range = _get_max_range_for_action(attacker, action)
	
	if distance > max_range:
		target_invalid.emit(attacker, "Target out of range")
		return false
	
	# Check line of sight for ranged attacks
	if action in [BattleStateMachine.UnitAction.ATTACK, BattleStateMachine.UnitAction.SNAP_FIRE]:
		if not battlefield_manager.check_line_of_sight(attacker, target):
			target_invalid.emit(attacker, "No line of sight to target")
			return false
	
	# Check melee requirements
	if action == BattleStateMachine.UnitAction.BRAWL:
		if distance > 1.5:  # Allow slight tolerance for melee range
			target_invalid.emit(attacker, "Target not in melee range")
			return false
	
	return true

func _resolve_ranged_attack(attacker: Character, defender: Character) -> void:
	var base_hit_chance = attacker.get_ranged_accuracy()
	var modifiers = _calculate_ranged_modifiers(attacker, defender)
	var final_chance = base_hit_chance + modifiers
	
	var roll = _roll_to_hit()
	var hit = roll <= final_chance
	
	if hit:
		var damage = _calculate_ranged_damage(attacker, defender, roll)
		_apply_damage(defender, damage)
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier = 2.0
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage *= crit_multiplier
		
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

func _resolve_melee_attack(attacker: Character, defender: Character) -> void:
	var base_hit_chance = attacker.get_melee_accuracy()
	var modifiers = _calculate_melee_modifiers(attacker, defender)
	var final_chance = base_hit_chance + modifiers
	
	var roll = _roll_to_hit()
	var hit = roll <= final_chance
	
	if hit:
		var damage = _calculate_melee_damage(attacker, defender, roll)
		
		# Enhanced critical hit system
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier = _calculate_critical_multiplier(attacker)
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
			
		_apply_damage(defender, damage)
		_check_and_apply_status_effects(defender, damage)
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

func _resolve_snap_fire(attacker: Character, defender: Character) -> void:
	var base_hit_chance = attacker.get_ranged_accuracy() - 2  # Snap fire penalty
	var modifiers = _calculate_ranged_modifiers(attacker, defender)
	var final_chance = base_hit_chance + modifiers
	
	var roll = _roll_to_hit()
	var hit = roll <= final_chance
	
	if hit:
		var damage = _calculate_ranged_damage(attacker, defender, roll)
		damage = ceil(damage * 0.75)  # Reduced snap fire damage
		_apply_damage(defender, damage)
		combat_ended.emit(attacker, defender, true, damage)
	else:
		combat_ended.emit(attacker, defender, false, 0)

func _calculate_ranged_modifiers(attacker: Character, defender: Character) -> int:
	var modifiers = 0
	
	# Range modifiers
	var distance = _get_distance_to_target(attacker, defender)
	modifiers += _calculate_range_penalty(distance, attacker.get_weapon_range())
	
	# Cover bonus from battlefield manager
	var cover_bonus = battlefield_manager.get_cover_bonus(defender)
	modifiers -= cover_bonus
	
	# Elevation bonus from battlefield manager
	var elevation_bonus = battlefield_manager.get_elevation_bonus(attacker, defender)
	modifiers += elevation_bonus
	
	# Status effects
	modifiers += _get_status_modifiers(attacker)
	modifiers += _get_status_modifiers(defender)
	
	return modifiers

func _calculate_melee_modifiers(attacker: Character, defender: Character) -> int:
	var modifiers = 0
	
	# Status effects
	modifiers += _get_status_modifiers(attacker)
	modifiers += _get_status_modifiers(defender)
	
	# Weapon bonuses
	modifiers += attacker.get_melee_weapon_bonus()
	
	# Elevation can affect melee combat
	var elevation_bonus = battlefield_manager.get_elevation_bonus(attacker, defender)
	modifiers += elevation_bonus
	
	return modifiers

func _calculate_range_penalty(distance: float, max_range: float) -> int:
	if distance <= max_range * 0.5:
		return 0
	elif distance <= max_range:
		return -2
	else:
		return MAX_RANGE_PENALTY

func _get_status_modifiers(character: Character) -> int:
	var modifiers = 0
	
	if character.is_stunned():
		modifiers -= 2
	if character.is_wounded():
		modifiers -= 1
	
	return modifiers

func _get_valid_target(attacker: Character, action: int) -> Character:
	var valid_targets = _get_potential_targets(attacker, action)
	if valid_targets.is_empty():
		return null
	
	# For AI-controlled units
	if attacker.is_ai_controlled():
		return _select_ai_target(attacker, valid_targets)
	
	# For player-controlled units, wait for player selection
	var selected_target = await _wait_for_player_target_selection(attacker, valid_targets)
	if selected_target:
		target_selected.emit(attacker, selected_target)
	
	return selected_target

func _get_potential_targets(attacker: Character, action: int) -> Array[Character]:
	var max_range = _get_max_range_for_action(attacker, action)
	var potential_targets: Array[Character] = []
	
	for unit in battle_state_machine.active_units:
		if unit == attacker or not unit.is_alive():
			continue
		
		if attacker.is_enemy() != unit.is_enemy():  # Only target opposing forces
			var distance = _get_distance_to_target(attacker, unit)
			if distance <= max_range:
				if action in [BattleStateMachine.UnitAction.ATTACK, BattleStateMachine.UnitAction.SNAP_FIRE]:
					if battlefield_manager.check_line_of_sight(attacker, unit):
						potential_targets.append(unit)
				else:  # Melee doesn't require LOS
					potential_targets.append(unit)
	
	return potential_targets

func _get_max_range_for_action(attacker: Character, action: int) -> float:
	match action:
		BattleStateMachine.UnitAction.ATTACK:
			return attacker.get_weapon_range()
		BattleStateMachine.UnitAction.SNAP_FIRE:
			return attacker.get_weapon_range() * 0.75
		BattleStateMachine.UnitAction.BRAWL:
			return 1.5  # Melee range with slight tolerance
		_:
			return 0.0

func _get_distance_to_target(attacker: Character, target: Character) -> float:
	return battlefield_manager.unit_positions[attacker].distance_to(
		battlefield_manager.unit_positions[target]
	)

func _select_ai_target(attacker: Character, valid_targets: Array[Character]) -> Character:
	# Simple AI target selection - choose the closest valid target
	var closest_target: Character = null
	var closest_distance := INF
	
	for target in valid_targets:
		var distance = _get_distance_to_target(attacker, target)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
	
	return closest_target

func _wait_for_player_target_selection(attacker: Character, valid_targets: Array[Character]) -> Character:
	# This should be implemented to interface with your UI system
	# For now, return the first valid target
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null

func _roll_to_hit() -> int:
	return randi() % 6 + 1  # D6 roll

func _calculate_ranged_damage(attacker: Character, defender: Character, roll: int) -> int:
	var base_damage = attacker.get_weapon_damage()
	var armor = defender.get_armor_value()
	return max(0, base_damage - armor)

func _calculate_melee_damage(attacker: Character, defender: Character, roll: int) -> int:
	var base_damage = attacker.get_melee_damage()
	var armor = defender.get_armor_value()
	return max(0, base_damage - ceil(armor * 0.5))  # Melee ignores some armor

func _apply_damage(character: Character, damage: int) -> void:
	character.take_damage(damage)
	
	# Check for special effects
	if damage >= character.get_max_health() * 0.5:
		special_effect_triggered.emit(null, character, "staggered")
	
	# Apply status effects based on damage
	if damage > 0:
		_check_and_apply_status_effects(character, damage)

func _check_and_apply_status_effects(character: Character, damage: int) -> void:
	var max_health = character.get_max_health()
	
	# Check for stun
	if damage >= max_health * STUN_THRESHOLD:
		character.apply_status_effect("stunned", 1)  # 1 round duration
		special_effect_triggered.emit(null, character, "stunned")
	
	# Check for wound
	if damage >= max_health * WOUND_THRESHOLD:
		character.apply_status_effect("wounded", 2)  # 2 rounds duration
		special_effect_triggered.emit(null, character, "wounded")
	
func _calculate_critical_multiplier(attacker: Character) -> float:
	var base_multiplier = 1.5
	# Add weapon traits and character skills modifiers
	if attacker.has_trait("precise_strikes"):
		base_multiplier += 0.2
	return base_multiplier
	