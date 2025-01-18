@tool
extends Node

## Signals
signal combat_started()
signal combat_ended()
signal hit_calculated(attacker: Character, target: Character, hit_roll: int)
signal damage_calculated(attacker: Character, target: Character, damage: int)
signal special_ability_activated(character: Character, ability: String)
signal reaction_triggered(character: Character, reaction: String)
signal combat_effect_applied(target: Character, effect: String)
signal combat_log_updated(log_entry: String)

## Enums
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
	SUPPRESSING_FIRE
}

## Constants
const STUN_THRESHOLD := 8
const SUPPRESS_THRESHOLD := 6
const INSPIRE_THRESHOLD := 7
const FOCUS_THRESHOLD := 7
const ABILITY_COOLDOWN := 3

## Variables
var combat_manager: Node = null
var battlefield_manager: Node = null
var active_combatants: Array[Character] = []
var combat_log: Array[String] = []
var manual_overrides: Dictionary = {}

## Functions
func _ready() -> void:
	combat_manager = get_node_or_null("/root/CombatManager")
	battlefield_manager = get_node_or_null("/root/BattlefieldManager")

func resolve_combat_action(attacker: Character, target: Character, action: GameEnums.UnitAction) -> void:
	if not _validate_combat_requirements(attacker, target, action):
		return
	
	match action:
		GameEnums.UnitAction.ATTACK:
			_resolve_ranged_attack(attacker, target)
		GameEnums.UnitAction.BRAWL:
			_resolve_melee_attack(attacker, target)
		GameEnums.UnitAction.SPECIAL_ABILITY:
			_resolve_special_ability(attacker, target)
		_:
			push_warning("Unsupported combat action: %s" % action)

func _validate_combat_requirements(attacker: Character, target: Character, action: GameEnums.UnitAction) -> bool:
	if not attacker or not target:
		return false
		
	if not attacker.can_perform_action(action):
		return false
		
	# Check line of sight
	if not _has_valid_line_of_sight(attacker, target):
		return false
	
	# Check range and action-specific requirements
	match action:
		GameEnums.UnitAction.ATTACK:
			# Check if within weapon range
			var distance := _get_distance_to_target(attacker, target)
			var max_range := _get_max_range_for_action(attacker, action)
			if distance > max_range:
				return false
				
			# Check if must target closest enemy within 3"
			if distance <= 3.0:
				var closest_target := _get_closest_enemy(attacker)
				if closest_target and closest_target != target:
					return false
					
			# Check if shot would endanger allies
			if _shot_endangers_allies(attacker, target):
				# Swift and Soulless can still shoot
				if not (attacker.is_swift() or attacker.soulless):
					# Others need to roll 5+ to attempt
					if not attacker.bot:
						var roll := randi() % 6 + 1
						if roll < 5:
							return false
					else:
						return false
		
		GameEnums.UnitAction.BRAWL:
			# Must be in base contact
			if _get_distance_to_target(attacker, target) > 1.0:
				return false
	
		GameEnums.UnitAction.SPECIAL_ABILITY:
			# Check ability-specific requirements
			if not _validate_special_ability_requirements(attacker, target):
				return false
	
	return true

func _has_valid_line_of_sight(attacker: Character, target: Character) -> bool:
	if not battlefield_manager:
		return false
		
	# Check basic line of sight
	if not battlefield_manager.has_line_of_sight(attacker.position, target.position):
		return false
		
	# Check if line of sight crosses another character
	var line: Array[Vector2i] = battlefield_manager.get_line(attacker.position, target.position)
	for point in line:
		var character: Character = combat_manager.get_character_at(point)
		if character and character != attacker and character != target:
			return false
			
	# Check area feature rules
	var attacker_terrain: TerrainTypes.Type = battlefield_manager.get_terrain_at(attacker.position)
	var target_terrain: TerrainTypes.Type = battlefield_manager.get_terrain_at(target.position)
	
	# If attacker is in area feature and not at edge
	if _is_area_feature(attacker_terrain) and not _is_at_area_edge(attacker.position):
		# Can only see others in same area within 3"
		if _is_area_feature(target_terrain):
			return _get_distance_to_target(attacker, target) <= 3.0
		return false
		
	# If target is in area feature and not at edge
	if _is_area_feature(target_terrain) and not _is_at_area_edge(target.position):
		return false
		
	return true

func _validate_special_ability_requirements(attacker: Character, target: Character) -> bool:
	var ability: String = attacker.get_active_ability()
	if not ability:
		return false
		
	# Check cooldown
	if attacker.is_ability_on_cooldown(ability):
		return false
		
	# Check range requirements
	var ability_range: float = _get_ability_range(ability)
	if ability_range > 0:
		var distance := _get_distance_to_target(attacker, target)
		if distance > ability_range:
			return false
			
	# Check status effects that prevent ability use
	if attacker.is_suppressed() or attacker.is_pinned():
		return false
		
	return true

func _shot_endangers_allies(attacker: Character, target: Character) -> bool:
	var line: Array[Vector2i] = battlefield_manager.get_line(attacker.position, target.position)
	for point in line:
		var character: Character = combat_manager.get_character_at(point)
		if character and character != attacker and character != target:
			if combat_manager.are_allies(attacker, character):
				return true
	return false

func _get_ability_range(ability: String) -> float:
	match ability:
		"leadership":
			return 6.0 # Leadership affects allies within 6"
		"tactical":
			return 12.0 # Tactical genius affects battlefield within 12"
		"marksman":
			return 0.0 # No range limit
		"berserker":
			return 1.0 # Must be in base contact
		"medic":
			return 3.0 # Can heal allies within 3"
		"tech":
			return 3.0 # Can repair/hack within 3"
		_:
			return 0.0

func _get_closest_enemy(character: Character) -> Character:
	var closest_distance := INF
	var closest_enemy: Character = null
	
	for enemy in combat_manager.get_enemies(character):
		var distance := _get_distance_to_target(character, enemy)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
			
	return closest_enemy

func _is_area_feature(terrain_type: TerrainTypes.Type) -> bool:
	# Check if terrain type is an area feature (water, hazard, difficult)
	return terrain_type in [
		TerrainTypes.Type.WATER,
		TerrainTypes.Type.HAZARD,
		TerrainTypes.Type.DIFFICULT
	]

func _is_at_area_edge(position: Vector2i) -> bool:
	if not battlefield_manager:
		return false
		
	# Check adjacent tiles for non-area terrain
	var adjacent_positions := [
		Vector2i(position.x - 1, position.y),
		Vector2i(position.x + 1, position.y),
		Vector2i(position.x, position.y - 1),
		Vector2i(position.x, position.y + 1)
	]
	
	var current_terrain: TerrainTypes.Type = battlefield_manager.get_terrain_at(position)
	if not _is_area_feature(current_terrain):
		return false
		
	for adjacent in adjacent_positions:
		if battlefield_manager.is_valid_position(adjacent):
			var terrain: TerrainTypes.Type = battlefield_manager.get_terrain_at(adjacent)
			if not _is_area_feature(terrain):
				return true
				
	return false

func _resolve_ranged_attack(attacker: Character, target: Character) -> void:
	var hit_modifier := _calculate_hit_modifier(attacker, target)
	var hit_threshold := _get_hit_threshold(attacker, target)
	var hit_roll := randi() % 6 + 1 + hit_modifier
	
	emit_signal("hit_calculated", attacker, target, hit_roll)
	
	if hit_roll >= hit_threshold:
		var damage := _calculate_damage(attacker, target, hit_roll)
		emit_signal("damage_calculated", attacker, target, damage)
		target.apply_damage(damage)
		_apply_combat_effects(attacker, target, hit_roll)
		
		# Handle weapon traits
		var weapon = attacker.get_equipped_weapon()
		if weapon:
			if "Critical" in weapon.traits and hit_roll == 6:
				# Critical hit - apply second hit
				damage = _calculate_damage(attacker, target, hit_roll)
				emit_signal("damage_calculated", attacker, target, damage)
				target.apply_damage(damage)
				
			if "Area" in weapon.traits:
				# Apply area effect to nearby targets
				var nearby_targets := _get_targets_in_radius(target.position, 2.0)
				for nearby in nearby_targets:
					if nearby != target:
						damage = _calculate_damage(attacker, nearby, hit_roll)
						emit_signal("damage_calculated", attacker, nearby, damage)
						nearby.apply_damage(damage)
						
			if "Terrifying" in weapon.traits:
				# Force target to retreat
				var retreat_distance := randi() % 6 + 1
				_apply_retreat(target, retreat_distance, attacker.position)
				
			if "Stun" in weapon.traits:
				target.apply_status_effect("stunned", 1)

func _calculate_hit_modifier(attacker: Character, target: Character) -> int:
	var modifier := 0
	var weapon = attacker.get_equipped_weapon()
	
	# Base modifiers
	modifier += attacker.get_combat_skill()
	
	# Range modifiers
	var distance := _get_distance_to_target(attacker, target)
	if weapon:
		if "Snap Shot" in weapon.traits and distance <= 6:
			modifier += 1
		if "Heavy" in weapon.traits and attacker.has_moved_this_turn:
			modifier -= 1
			
	# Cover and elevation modifiers
	if target.in_cover:
		modifier -= 1
	if target.elevation > attacker.elevation:
		modifier -= 1
	elif target.elevation < attacker.elevation:
		modifier += 1
		
	# Status effect modifiers
	modifier += _get_effect_modifier(attacker.active_effects)
	
	return modifier

func _get_effect_modifier(effects: Array) -> int:
	var modifier := 0
	for effect in effects:
		match effect:
			"stun":
				modifier -= 2
			"suppress":
				modifier -= 1
			"inspire":
				modifier += 1
			"focus":
				modifier += 1
	return modifier

func _get_weapon_effects(character: Character) -> Array[String]:
	var effects: Array[String] = []
	var weapon = character.get_equipped_weapon()
	if weapon and weapon.has("effects"):
		effects.append_array(weapon.effects)
	return effects

func _get_valid_target(attacker: Character, action: GameEnums.UnitAction) -> Character:
	if not combat_manager:
		return null
		
	var valid_targets: Array[Character] = combat_manager.get_valid_targets(attacker)
	if valid_targets.is_empty():
		return null
	
	if attacker.is_player_controlled:
		return await _wait_for_player_target_selection(valid_targets)
	else:
		return _select_ai_target(attacker, valid_targets)
	
func _get_max_range_for_action(attacker: Character, action: GameEnums.UnitAction) -> float:
	match action:
		GameEnums.UnitAction.ATTACK:
			var weapon = attacker.get_equipped_weapon()
			if weapon:
				return weapon.range
			return 0.0
		GameEnums.UnitAction.BRAWL:
			return 1.0
		GameEnums.UnitAction.SPECIAL_ABILITY:
			var ability: String = attacker.get_active_ability()
			return _get_ability_range(ability)
		_:
			return 0.0

func _get_distance_to_target(attacker: Character, target: Character) -> float:
	if battlefield_manager:
		return battlefield_manager.get_distance_between(attacker.position, target.position)
	return 0.0

func _apply_retreat(target: Character, distance: float, from_position: Vector2) -> void:
	if battlefield_manager:
		var retreat_direction: Vector2 = (target.position - from_position).normalized()
		var new_position: Vector2 = target.position + (retreat_direction * distance)
		battlefield_manager.move_character(target, new_position)

func _get_targets_in_radius(center: Vector2, radius: float) -> Array[Character]:
	var targets: Array[Character] = []
	if battlefield_manager:
		targets = battlefield_manager.get_characters_in_radius(center, radius)
	return targets

func add_manual_override(override_type: String, value: Variant) -> void:
	manual_overrides[override_type] = value

func clear_manual_overrides() -> void:
	manual_overrides.clear()

func log_combat_event(event: String) -> void:
	combat_log.append(event)
	emit_signal("combat_log_updated", event)

func _get_hit_threshold(attacker: Character, target: Character) -> int:
	var threshold := 4 # Base threshold for hitting
	
	# Adjust for cover
	if target.in_cover:
		threshold += 1
		
	# Adjust for elevation
	if target.elevation > attacker.elevation:
		threshold += 1
		
	return threshold

func _calculate_damage(attacker: Character, target: Character, hit_roll: int) -> int:
	var base_damage: int = attacker.get_ranged_damage()
	var armor_reduction: int = target.get_armor_value()
	
	# Critical hit bonus
	if hit_roll == 6:
		base_damage *= 2
		
	return maxi(1, base_damage - armor_reduction) # Minimum 1 damage

func _apply_combat_effects(attacker: Character, target: Character, hit_roll: int) -> void:
	# Status effects based on hit roll
	if hit_roll >= STUN_THRESHOLD:
		target.apply_status_effect("stun", 1)
		log_combat_event("%s was stunned" % target.name)
	elif hit_roll >= SUPPRESS_THRESHOLD:
		target.apply_status_effect("suppress", 1)
		log_combat_event("%s was suppressed" % target.name)
	
	# Weapon-specific effects
	var weapon = attacker.get_equipped_weapon()
	if weapon:
		if "Knockback" in weapon.traits:
			_apply_knockback(target, attacker.position, 2)
		if "Disarm" in weapon.traits and hit_roll >= 5:
			target.apply_status_effect("disarmed", 1)
		if "Stagger" in weapon.traits:
			target.reduce_action_points(1)
		if "Bleed" in weapon.traits and not target.is_mechanical():
			target.apply_status_effect("bleeding", 2)

func _apply_knockback(target: Character, from_position: Vector2i, distance: int) -> void:
	var knockback_position: Vector2i = target.position
	var direction: Vector2 = (target.position - from_position).normalized()
	knockback_position += Vector2i(direction.x * distance, direction.y * distance)
	
	# Validate new position
	if battlefield_manager and battlefield_manager.is_valid_position(knockback_position):
		battlefield_manager.move_character(target, knockback_position)
		log_combat_event("%s was knocked back" % target.name)
		
		# Check for collision damage
		var terrain: TerrainTypes.Type = battlefield_manager.get_terrain_at(knockback_position)
		if terrain == TerrainTypes.Type.WALL:
			target.apply_damage(1)
			log_combat_event("%s took collision damage" % target.name)

func _resolve_melee_attack(attacker: Character, target: Character) -> void:
	var hit_modifier := _calculate_melee_modifier(attacker, target)
	var hit_threshold := _get_melee_threshold(attacker, target)
	var hit_roll := randi() % 6 + 1 + hit_modifier
	
	emit_signal("hit_calculated", attacker, target, hit_roll)
	
	if hit_roll >= hit_threshold:
		var damage := _calculate_melee_damage(attacker, target, hit_roll)
		emit_signal("damage_calculated", attacker, target, damage)
		target.apply_damage(damage)
		_apply_combat_effects(attacker, target, hit_roll)

func _calculate_melee_modifier(attacker: Character, target: Character) -> int:
	var modifier := 0
	
	# Base modifiers
	modifier += attacker.get_combat_skill()
	
	# Weapon traits
	var weapon = attacker.get_equipped_weapon()
	if weapon:
		if "Elegant" in weapon.traits:
			modifier += 1
		if "Clumsy" in weapon.traits and target.get_speed() > attacker.get_speed():
			modifier -= 1
			
	# Status effects
	modifier += _get_effect_modifier(attacker.active_effects)
	
	return modifier

func _get_melee_threshold(attacker: Character, target: Character) -> int:
	var threshold := 4 # Base threshold for melee
	
	# Adjust for target's defense
	if target.in_cover:
		threshold += 1
		
	return threshold

func _calculate_melee_damage(attacker: Character, target: Character, hit_roll: int) -> int:
	var base_damage: int = attacker.get_melee_damage()
	var armor_reduction: int = target.get_armor_value()
	
	# Critical hit bonus
	if hit_roll == 6:
		base_damage *= 2
		
	return maxi(1, base_damage - armor_reduction) # Minimum 1 damage

func _resolve_special_ability(attacker: Character, target: Character) -> void:
	var ability: String = attacker.get_active_ability()
	if ability == "NONE":
		return
		
	# Check cooldown
	if attacker.get_ability_cooldown(ability) > 0:
		return
		
	# Apply ability effects
	match ability:
		"LEADERSHIP":
			_apply_leadership_bonus(attacker)
		"TACTICAL":
			_apply_tactical_bonus(attacker)
		"MARKSMAN":
			_apply_marksman_bonus(attacker)
		"BERSERKER":
			_apply_berserker_bonus(attacker)
		"MEDIC":
			_apply_medic_bonus(attacker, target)
		"TECH":
			_apply_tech_bonus(attacker)
			
	emit_signal("special_ability_activated", attacker, ability)
	log_combat_event("Special ability %s activated by %s" % [ability, attacker.name])

func _wait_for_player_target_selection(valid_targets: Array[Character]) -> Character:
	# This will be implemented by the UI system
	# For now, return the first valid target
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null

func _select_ai_target(attacker: Character, valid_targets: Array[Character]) -> Character:
	# Simple AI - select closest valid target
	var closest_target: Character = null
	var closest_distance := INF
	
	for target in valid_targets:
		var distance := _get_distance_to_target(attacker, target)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
			
	return closest_target

func _apply_leadership_bonus(character: Character) -> void:
	var allies := _get_nearby_allies(character)
	for ally in allies:
		ally.apply_status_effect("inspire", 2) # Lasts 2 turns
		log_combat_event("%s inspired by %s's leadership" % [ally.name, character.name])

func _apply_tactical_bonus(character: Character) -> void:
	var allies := _get_nearby_allies(character)
	for ally in allies:
		ally.apply_status_effect("focus", 2) # Lasts 2 turns
		ally.add_action_points(1) # Bonus action point
		log_combat_event("%s gained tactical advantage from %s" % [ally.name, character.name])

func _apply_marksman_bonus(character: Character) -> void:
	character.apply_status_effect("focus", 3) # Extended focus duration
	character.add_combat_modifier(GameEnums.CombatModifier.ELEVATION) # Elevation bonus for marksman
	log_combat_event("%s entered marksman stance" % character.name)

func _apply_berserker_bonus(character: Character) -> void:
	character.apply_status_effect("rage", 2) # Lasts 2 turns
	character.add_combat_modifier(GameEnums.CombatModifier.FLANKING) # Flanking bonus for berserker
	character.add_action_points(2) # Two bonus action points
	log_combat_event("%s entered berserker rage" % character.name)

func _apply_medic_bonus(character: Character, target: Character) -> void:
	if target and target.is_wounded:
		var heal_amount := 2
		target.heal_damage(heal_amount)
		target.remove_status_effect("bleeding")
		target.remove_status_effect("poison")
		log_combat_event("%s healed %s for %d damage" % [character.name, target.name, heal_amount])

func _apply_tech_bonus(character: Character) -> void:
	character.apply_status_effect("tech_boost", 2) # Lasts 2 turns
	character.add_combat_modifier(GameEnums.CombatModifier.STEALTH) # Stealth bonus for tech
	# Repair nearby mechanical allies
	var allies := _get_nearby_allies(character)
	for ally in allies:
		if ally.is_mechanical():
			ally.heal_damage(1)
			log_combat_event("%s repaired %s" % [character.name, ally.name])

func _get_nearby_allies(character: Character) -> Array[Character]:
	var allies: Array[Character] = []
	if battlefield_manager:
		allies = battlefield_manager.get_allies_in_range(character, 3.0) # 3 unit radius
	return allies
