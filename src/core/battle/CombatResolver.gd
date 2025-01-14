## Handles combat resolution and effects in the Five Parsecs battle system
class_name CombatResolver
extends Node

## Signals
signal combat_started(attacker: Character, defender: Character)
signal combat_ended(result: Dictionary)
signal hit_calculated(hit_data: Dictionary)
signal damage_calculated(damage_data: Dictionary)
signal effects_applied(effect_data: Dictionary)
signal target_invalid(attacker: Character, reason: String)
signal target_selected(attacker: Character, target: Character)
signal critical_hit(attacker: Character, defender: Character, multiplier: float)
signal special_effect_triggered(source: Node, target: Node, effect: String)
signal combat_resolved(result: Dictionary)
signal special_ability_activated(character: Character, ability: String, targets: Array)
signal reaction_triggered(character: Character, reaction_type: String, trigger: Dictionary)
signal group_action_started(leader: Character, group: Array[Character])
signal coordinated_fire_started(attackers: Array[Character], target: Character)

## Tabletop support signals
signal dice_roll_requested(context: String, modifier: int)
signal dice_roll_completed(result: int, context: String)
signal modifier_applied(source: String, value: int, description: String)
signal manual_override_requested(context: String, current_value: int)
signal combat_log_updated(message: String, details: Dictionary)

## Special Abilities and Reactions
enum SpecialAbility {
	NONE,
	LEADERSHIP,
	TACTICAL_GENIUS,
	MARKSMAN,
	BERSERKER,
	MEDIC,
	TECH_EXPERT
}

enum ReactionType {
	NONE,
	OVERWATCH,
	DODGE,
	COUNTER_ATTACK,
	PROTECT_ALLY,
	SUPPRESSING_FIRE
}

## Combat modifiers
const CRITICAL_HIT_THRESHOLD: int = 6
const MAX_RANGE_PENALTY: int = -4
const COVER_BONUS: int = 2
const ELEVATION_BONUS: int = 1

## Status effect thresholds
const STUN_THRESHOLD: float = 0.4 # 40% of max health
const WOUND_THRESHOLD: float = 0.25 # 25% of max health

## Special ability cooldowns (in turns)
const ABILITY_COOLDOWNS = {
	SpecialAbility.LEADERSHIP: 3,
	SpecialAbility.TACTICAL_GENIUS: 4,
	SpecialAbility.MARKSMAN: 2,
	SpecialAbility.BERSERKER: 3,
	SpecialAbility.MEDIC: 2,
	SpecialAbility.TECH_EXPERT: 3
}

## Reaction chance modifiers
const REACTION_MODIFIERS = {
	ReactionType.OVERWATCH: - 1,
	ReactionType.DODGE: 0,
	ReactionType.COUNTER_ATTACK: - 2,
	ReactionType.PROTECT_ALLY: - 1,
	ReactionType.SUPPRESSING_FIRE: - 2
}

## Required dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const BattlefieldManager := preload("res://src/core/battle/BattlefieldManager.gd")
const BattleStateManager := preload("res://src/core/battle/state/BattleStateMachine.gd")
const BattleRules := preload("res://src/core/battle/BattleRules.gd")

## Reference to the battle state machine
@export var battle_state_machine: BattleStateManager
## Reference to the battlefield manager
@export var battlefield_manager: BattlefieldManager
## Reference to the combat manager
@export var combat_manager: Node # Will be cast to CombatManager

## Cache for active status effects - maps Character to Array[String]
var _active_effects: Dictionary = {}
## Cache for combat modifiers - maps Character to Dictionary of modifiers
var _combat_modifiers: Dictionary = {}
## Cache for ability cooldowns - maps Character to Dictionary of ability timers
var _ability_cooldowns: Dictionary = {}
## Cache for reaction states - maps Character to Dictionary of reaction states
var _reaction_states: Dictionary = {}

## Manual override properties
var allow_manual_overrides: bool = true
var pending_override_request: Dictionary = {}
var manual_override_value: int = -1

## Combat log properties
var combat_log: Array[Dictionary] = []
var detailed_modifier_log: Array[Dictionary] = []

## Active combatants in the current battle
var _active_combatants: Array[Character] = []

## Called when the node enters the scene tree
func _ready() -> void:
	if not combat_manager:
		push_warning("CombatResolver: No combat manager assigned")
	if not battle_state_machine:
		push_warning("CombatResolver: No battle state machine assigned")
	if not battlefield_manager:
		push_warning("CombatResolver: No battlefield manager assigned")

## Handles manual override requests for dice rolls and modifiers
func request_manual_override(context: String, current_value: int) -> void:
	if not allow_manual_overrides:
		return
		
	pending_override_request = {
		"context": context,
		"current_value": current_value,
		"timestamp": Time.get_unix_time_from_system()
	}
	manual_override_requested.emit(context, current_value)

## Applies a manual override value
func apply_manual_override(value: int) -> void:
	if not pending_override_request:
		return
		
	manual_override_value = value
	var context: String = pending_override_request.get("context", "")
	_log_combat_event("Manual Override", {
		"context": context,
		"original_value": pending_override_request.get("current_value"),
		"override_value": value
	})
	pending_override_request.clear()

## Logs a modifier application with details
func log_modifier(source: String, value: int, description: String) -> void:
	var modifier_data := {
		"source": source,
		"value": value,
		"description": description,
		"timestamp": Time.get_unix_time_from_system()
	}
	detailed_modifier_log.append(modifier_data)
	modifier_applied.emit(source, value, description)

## Logs a combat event with details
func _log_combat_event(event_type: String, details: Dictionary) -> void:
	var log_entry := {
		"type": event_type,
		"details": details,
		"timestamp": Time.get_unix_time_from_system()
	}
	combat_log.append(log_entry)
	combat_log_updated.emit(event_type, details)

## Performs a dice roll with optional manual override
func _roll_dice(context: String = "", modifier: int = 0) -> int:
	dice_roll_requested.emit(context, modifier)
	
	if allow_manual_overrides and manual_override_value >= 0:
		var roll := manual_override_value
		manual_override_value = -1
		dice_roll_completed.emit(roll, context)
		return roll
	
	var roll := (randi() % 6) + 1
	dice_roll_completed.emit(roll, context)
	return roll

## Gets the complete modifier log for a combat action
func get_modifier_log() -> Array[Dictionary]:
	return detailed_modifier_log

## Clears the combat and modifier logs
func clear_logs() -> void:
	combat_log.clear()
	detailed_modifier_log.clear()

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
	
	# Log base accuracy and modifiers
	log_modifier("Base Accuracy", base_hit_chance, "Character's base ranged accuracy")
	log_modifier("Combat Modifiers", modifiers, "Combined situational modifiers")
	
	_log_combat_event("Ranged Attack Started", {
		"attacker": attacker.get_name(),
		"defender": defender.get_name(),
		"base_chance": base_hit_chance,
		"final_chance": final_chance
	})
	
	var roll: int = _roll_dice("Ranged Attack", modifiers)
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_ranged_damage(attacker, defender, roll)
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier: float = 2.0
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
			_log_combat_event("Critical Hit", {
				"roll": roll,
				"multiplier": crit_multiplier,
				"final_damage": damage
			})
		
		_apply_damage(defender, damage)
		_log_combat_event("Hit Resolved", {
			"hit": true,
			"roll": roll,
			"damage": damage,
			"target_health": defender.get_health()
		})
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": true,
			"damage": damage,
			"roll": roll,
			"modifiers": modifiers
		})
	else:
		_log_combat_event("Attack Missed", {
			"roll": roll,
			"required": final_chance
		})
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": false,
			"damage": 0,
			"roll": roll,
			"modifiers": modifiers
		})

## Resolves a melee attack between attacker and defender
func _resolve_melee_attack(attacker: Character, defender: Character) -> void:
	var base_hit_chance: int = attacker.get_melee_accuracy()
	var modifiers: int = _calculate_melee_modifiers(attacker, defender)
	var final_chance: int = base_hit_chance + modifiers
	
	# Log base accuracy and modifiers
	log_modifier("Base Melee Accuracy", base_hit_chance, "Character's base melee accuracy")
	log_modifier("Melee Modifiers", modifiers, "Combined melee situational modifiers")
	
	_log_combat_event("Melee Attack Started", {
		"attacker": attacker.get_name(),
		"defender": defender.get_name(),
		"base_chance": base_hit_chance,
		"final_chance": final_chance
	})
	
	var roll: int = _roll_dice("Melee Attack", modifiers)
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_melee_damage(attacker, defender, roll)
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier: float = _calculate_critical_multiplier(attacker)
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
			_log_combat_event("Critical Hit", {
				"roll": roll,
				"multiplier": crit_multiplier,
				"final_damage": damage
			})
			
		_apply_damage(defender, damage)
		_check_and_apply_status_effects(defender, damage)
		
		_log_combat_event("Melee Hit Resolved", {
			"hit": true,
			"roll": roll,
			"damage": damage,
			"target_health": defender.get_health()
		})
		
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": true,
			"damage": damage,
			"roll": roll,
			"modifiers": modifiers
		})
	else:
		_log_combat_event("Melee Attack Missed", {
			"roll": roll,
			"required": final_chance
		})
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": false,
			"damage": 0,
			"roll": roll,
			"modifiers": modifiers
		})

## Resolves a snap fire attack between attacker and defender
func _resolve_snap_fire(attacker: Character, defender: Character) -> void:
	var base_hit_chance: int = attacker.get_ranged_accuracy() - 2 # Snap fire penalty
	var modifiers: int = _calculate_ranged_modifiers(attacker, defender)
	var final_chance: int = base_hit_chance + modifiers
	
	# Log base accuracy and modifiers
	log_modifier("Base Snap Fire Accuracy", base_hit_chance, "Character's base accuracy with snap fire penalty")
	log_modifier("Snap Fire Modifiers", modifiers, "Combined situational modifiers")
	
	_log_combat_event("Snap Fire Started", {
		"attacker": attacker.get_name(),
		"defender": defender.get_name(),
		"base_chance": base_hit_chance,
		"final_chance": final_chance
	})
	
	var roll: int = _roll_dice("Snap Fire", modifiers)
	var hit: bool = roll <= final_chance
	
	if hit:
		var damage: int = _calculate_ranged_damage(attacker, defender, roll)
		damage = int(damage * 0.75) # Reduced snap fire damage
		
		if roll >= CRITICAL_HIT_THRESHOLD:
			var crit_multiplier: float = 1.5 # Reduced critical for snap fire
			critical_hit.emit(attacker, defender, crit_multiplier)
			damage = int(damage * crit_multiplier)
			_log_combat_event("Snap Fire Critical", {
				"roll": roll,
				"multiplier": crit_multiplier,
				"final_damage": damage
			})
		
		_apply_damage(defender, damage)
		_log_combat_event("Snap Fire Hit Resolved", {
			"hit": true,
			"roll": roll,
			"damage": damage,
			"target_health": defender.get_health()
		})
		
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": true,
			"damage": damage,
			"roll": roll,
			"modifiers": modifiers,
			"attack_type": "snap_fire"
		})
	else:
		_log_combat_event("Snap Fire Missed", {
			"roll": roll,
			"required": final_chance
		})
		
		combat_ended.emit({
			"attacker": attacker,
			"defender": defender,
			"hit": false,
			"damage": 0,
			"roll": roll,
			"modifiers": modifiers,
			"attack_type": "snap_fire"
		})

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
	modifiers += int(terrain_mod * 2) # Convert float modifier to int bonus
	
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
	modifiers += int(terrain_mod * 2) # Convert float modifier to int bonus
	
	# Status effects
	modifiers += _get_status_modifiers(attacker)
	modifiers += _get_status_modifiers(defender)
	
	# Weapon bonuses
	modifiers += attacker.get_melee_weapon_bonus()
	
	return modifiers

## Calculates range penalty based on distance and maximum range
## Returns: Range penalty value
func _calculate_range_penalty(distance: float, max_range: float) -> float:
	if distance <= max_range * 0.5:
		return 0.0 # No penalty within half range
	elif distance <= max_range:
		return -2.0 # Medium penalty within full range
	else:
		return float(MAX_RANGE_PENALTY) # Maximum penalty beyond range

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
		
		if attacker.is_enemy() != unit.is_enemy(): # Only target opposing forces
			var distance: float = _get_distance_to_target(attacker, unit)
			if distance <= max_range:
				if action in [GlobalEnums.UnitAction.ATTACK, GlobalEnums.UnitAction.SNAP_FIRE]:
					if battlefield_manager and battlefield_manager.check_line_of_sight(attacker, unit):
						potential_targets.append(unit)
				else: # Melee doesn't require LOS
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
			return 1.5 # Melee range with slight tolerance
		_:
			return 0.0

## Gets the distance between attacker and target
## Returns: Distance value in world units
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
	
	return max(1, base_damage - armor_reduction) # Minimum 1 damage

## Calculates melee damage
## Returns: Final damage value
func _calculate_melee_damage(attacker: Character, defender: Character, roll: int) -> int:
	var weapon = attacker.get_active_weapon()
	var base_damage: int = weapon.get_damage() if weapon else attacker.get_base_melee_damage()
	var armor_reduction: int = defender.get_armor()
	
	return max(1, base_damage - armor_reduction) # Minimum 1 damage

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

func _calculate_hit_chance(attacker: Character, target: Character, weapon_data: Dictionary) -> float:
	var base_chance := float(attacker.get_ranged_accuracy())
	var modifiers := _calculate_ranged_modifiers(attacker, target)
	var final_chance := base_chance + modifiers
	
	# Apply weapon modifiers
	final_chance += weapon_data.get("accuracy_modifier", 0)
	
	# Apply range modifiers
	var distance := _get_distance_to_target(attacker, target)
	var max_range: float = weapon_data.get("max_range", 24.0) # Default max range of 24 units
	final_chance += _calculate_range_penalty(distance, max_range)
	
	return clamp(final_chance, 5, 95) # Always at least 5% chance to hit, max 95%

func add_combat_modifier(character: Character, modifier: int) -> void:
	if not character:
		return
		
	if not _combat_modifiers.has(character):
		_combat_modifiers[character] = []
	
	if not modifier in _combat_modifiers[character]:
		_combat_modifiers[character].append(modifier)

func remove_combat_modifier(character: Character, modifier: int) -> void:
	if not character or not _combat_modifiers.has(character):
		return
		
	_combat_modifiers[character].erase(modifier)
	if _combat_modifiers[character].is_empty():
		_combat_modifiers.erase(character)

func get_active_modifiers(character: Character) -> Array:
	return _combat_modifiers.get(character, [])

## Activates a special ability for a character
func activate_special_ability(character: Character, ability: SpecialAbility, targets: Array = []) -> bool:
	if not character or ability == SpecialAbility.NONE:
		return false
		
	if not _can_use_ability(character, ability):
		return false
	
	var ability_result := _resolve_special_ability(character, ability, targets)
	if ability_result:
		_start_ability_cooldown(character, ability)
		special_ability_activated.emit(character, ability, targets)
		
	return ability_result

## Checks if a reaction can be triggered
func can_trigger_reaction(character: Character, reaction_type: ReactionType, trigger: Dictionary) -> bool:
	if not character or reaction_type == ReactionType.NONE:
		return false
		
	if _reaction_states.get(character, {}).get("active_reaction", ReactionType.NONE) != ReactionType.NONE:
		return false
		
	var base_chance: int = character.get_reaction_chance()
	var modifier: int = REACTION_MODIFIERS.get(reaction_type, 0)
	
	return _roll_dice("Reaction Check", modifier) <= base_chance

## Triggers a reaction for a character
func trigger_reaction(character: Character, reaction_type: ReactionType, trigger: Dictionary) -> void:
	if not can_trigger_reaction(character, reaction_type, trigger):
		return
		
	_reaction_states[character] = {
		"active_reaction": reaction_type,
		"trigger": trigger,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	reaction_triggered.emit(character, reaction_type, trigger)
	_resolve_reaction(character, reaction_type, trigger)

## Resolves a special ability
func _resolve_special_ability(character: Character, ability: SpecialAbility, targets: Array) -> bool:
	match ability:
		SpecialAbility.LEADERSHIP:
			return _resolve_leadership_ability(character, targets)
		SpecialAbility.TACTICAL_GENIUS:
			return _resolve_tactical_genius_ability(character)
		SpecialAbility.MARKSMAN:
			return _resolve_marksman_ability(character)
		SpecialAbility.BERSERKER:
			return _resolve_berserker_ability(character)
		SpecialAbility.MEDIC:
			return _resolve_medic_ability(character, targets)
		SpecialAbility.TECH_EXPERT:
			return _resolve_tech_expert_ability(character, targets)
		_:
			return false

## Resolves a reaction
func _resolve_reaction(character: Character, reaction_type: ReactionType, trigger: Dictionary) -> void:
	match reaction_type:
		ReactionType.OVERWATCH:
			_resolve_overwatch_reaction(character, trigger)
		ReactionType.DODGE:
			_resolve_dodge_reaction(character, trigger)
		ReactionType.COUNTER_ATTACK:
			_resolve_counter_attack_reaction(character, trigger)
		ReactionType.PROTECT_ALLY:
			_resolve_protect_ally_reaction(character, trigger)
		ReactionType.SUPPRESSING_FIRE:
			_resolve_suppressing_fire_reaction(character, trigger)

## Checks if a character can use an ability
func _can_use_ability(character: Character, ability: SpecialAbility) -> bool:
	if not character or ability == SpecialAbility.NONE:
		return false
		
	var cooldowns: Dictionary = _ability_cooldowns.get(character, {})
	return not cooldowns.has(ability) or cooldowns[ability] <= 0

## Starts the cooldown for an ability
func _start_ability_cooldown(character: Character, ability: SpecialAbility) -> void:
	if not character or ability == SpecialAbility.NONE:
		return
		
	if not _ability_cooldowns.has(character):
		_ability_cooldowns[character] = {}
		
	_ability_cooldowns[character][ability] = ABILITY_COOLDOWNS.get(ability, 1)

## Updates ability cooldowns at the end of a turn
func update_cooldowns() -> void:
	for character in _ability_cooldowns.keys():
		var cooldowns: Dictionary = _ability_cooldowns[character]
		for ability in cooldowns.keys():
			cooldowns[ability] = max(0, cooldowns[ability] - 1)
			
	# Clear reaction states
	_reaction_states.clear()

## Resolves leadership ability
func _resolve_leadership_ability(character: Character, targets: Array[Character]) -> bool:
	if targets.is_empty():
		return false
		
	for target in targets:
		if target == character:
			continue
			
		# Grant bonus action points and combat advantage
		target.add_action_points(1)
		_combat_modifiers[target] = _combat_modifiers.get(target, []) + ["leadership_bonus"]
		
	_log_combat_event("Leadership Ability", {
		"leader": character.get_name(),
		"targets": targets.map(func(t): return t.get_name()),
		"bonus": "action_point_and_combat"
	})
	
	return true

## Resolves tactical genius ability
func _resolve_tactical_genius_ability(character: Character) -> bool:
	var nearby_allies := _get_nearby_allies(character, 3) # 3 tile radius
	if nearby_allies.is_empty():
		return false
		
	for ally in nearby_allies:
		# Grant movement bonus and improved cover
		_combat_modifiers[ally] = _combat_modifiers.get(ally, []) + ["tactical_bonus"]
		
	_log_combat_event("Tactical Genius", {
		"tactician": character.get_name(),
		"affected_allies": nearby_allies.map(func(a): return a.get_name()),
		"bonus": "movement_and_cover"
	})
	
	return true

## Resolves marksman ability
func _resolve_marksman_ability(character: Character) -> bool:
	# Grant improved accuracy and critical hit chance
	_combat_modifiers[character] = _combat_modifiers.get(character, []) + ["marksman_focus"]
	
	_log_combat_event("Marksman Focus", {
		"character": character.get_name(),
		"bonus": "accuracy_and_crit"
	})
	
	return true

## Resolves berserker ability
func _resolve_berserker_ability(character: Character) -> bool:
	# Grant extra melee damage and movement
	_combat_modifiers[character] = _combat_modifiers.get(character, []) + ["berserker_rage"]
	
	_log_combat_event("Berserker Rage", {
		"character": character.get_name(),
		"bonus": "melee_and_movement"
	})
	
	return true

## Resolves medic ability
func _resolve_medic_ability(character: Character, targets: Array[Character]) -> bool:
	if targets.is_empty():
		return false
		
	for target in targets:
		if target.get_health() >= target.get_max_health():
			continue
			
		# Heal target and remove negative status effects
		var heal_amount := int(target.get_max_health() * 0.3) # 30% heal
		target.heal(heal_amount)
		_remove_negative_effects(target)
		
	_log_combat_event("Medical Aid", {
		"medic": character.get_name(),
		"targets": targets.map(func(t): return t.get_name()),
		"heal_amount": "30%"
	})
	
	return true

## Resolves tech expert ability
func _resolve_tech_expert_ability(character: Character, targets: Array[Character]) -> bool:
	if targets.is_empty():
		return false
		
	for target in targets:
		# Grant tech bonus (improved equipment effectiveness)
		_combat_modifiers[target] = _combat_modifiers.get(target, []) + ["tech_enhanced"]
		
	_log_combat_event("Tech Enhancement", {
		"tech_expert": character.get_name(),
		"targets": targets.map(func(t): return t.get_name()),
		"bonus": "equipment_boost"
	})
	
	return true

## Resolves overwatch reaction
func _resolve_overwatch_reaction(character: Character, trigger: Dictionary) -> void:
	var target: Character = trigger.get("target")
	if not target:
		return
		
	# Perform reaction shot with penalty
	var reaction_shot := {
		"attacker": character,
		"defender": target,
		"modifier": REACTION_MODIFIERS[ReactionType.OVERWATCH]
	}
	_resolve_ranged_attack(reaction_shot.attacker, reaction_shot.defender)

## Resolves dodge reaction
func _resolve_dodge_reaction(character: Character, trigger: Dictionary) -> void:
	# Grant temporary defense bonus
	_combat_modifiers[character] = _combat_modifiers.get(character, []) + ["dodge_bonus"]
	
	_log_combat_event("Dodge Reaction", {
		"character": character.get_name(),
		"trigger": trigger,
		"bonus": "defense"
	})

## Resolves counter attack reaction
func _resolve_counter_attack_reaction(character: Character, trigger: Dictionary) -> void:
	var attacker: Character = trigger.get("attacker")
	if not attacker:
		return
		
	# Perform counter attack with penalty
	var counter_attack := {
		"attacker": character,
		"defender": attacker,
		"modifier": REACTION_MODIFIERS[ReactionType.COUNTER_ATTACK]
	}
	_resolve_melee_attack(counter_attack.attacker, counter_attack.defender)

## Resolves protect ally reaction
func _resolve_protect_ally_reaction(character: Character, trigger: Dictionary) -> void:
	var ally: Character = trigger.get("ally")
	if not ally:
		return
		
	# Move to protect ally and grant them cover bonus
	if battlefield_manager:
		var ally_pos: Vector2 = battlefield_manager.get_character_position(ally)
		battlefield_manager.move_character(character, ally_pos)
		_combat_modifiers[ally] = _combat_modifiers.get(ally, []) + ["protection_bonus"]
	
	_log_combat_event("Protect Ally", {
		"protector": character.get_name(),
		"ally": ally.get_name(),
		"bonus": "cover"
	})

## Resolves suppressing fire reaction
func _resolve_suppressing_fire_reaction(character: Character, trigger: Dictionary) -> void:
	var target: Character = trigger.get("target")
	if not target:
		return
		
	# Apply suppression effect
	_combat_modifiers[target] = _combat_modifiers.get(target, []) + ["suppressed"]
	
	_log_combat_event("Suppressing Fire", {
		"suppressor": character.get_name(),
		"target": target.get_name(),
		"effect": "movement_penalty"
	})

## Gets nearby allies within radius
func _get_nearby_allies(character: Character, radius: int) -> Array[Character]:
	var nearby_allies: Array[Character] = []
	
	if not battlefield_manager:
		return nearby_allies
		
	var char_pos: Vector2 = battlefield_manager.get_character_position(character)
	for other in _active_combatants:
		if other == character:
			continue
			
		var other_pos: Vector2 = battlefield_manager.get_character_position(other)
		var distance: float = char_pos.distance_to(other_pos)
		if distance <= radius:
			nearby_allies.append(other)
			
	return nearby_allies

## Removes negative status effects from a character
func _remove_negative_effects(character: Character) -> void:
	var effects: Array = _active_effects.get(character, [])
	var positive_effects: Array[String] = effects.filter(func(effect: String) -> bool:
		return not effect.begins_with("negative_")
	)
	_active_effects[character] = positive_effects
