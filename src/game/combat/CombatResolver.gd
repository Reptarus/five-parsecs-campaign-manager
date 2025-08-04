@tool
extends Node

const Character = preload("res://src/core/character/Character.gd")
const TerrainTypesScript: GDScript = preload("res://src/core/terrain/TerrainTypes.gd")
const GlobalEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

## Terrain Types (loaded from TerrainTypesScript)
var TERRAIN_TYPE_WATER: int
var TERRAIN_TYPE_HAZARD: int
var TERRAIN_TYPE_DIFFICULT: int
var TERRAIN_TYPE_WALL: int

## Interface validation for Character class
const REQUIRED_CHARACTER_PROPERTIES: Array[String] = [
	"position",
	"name",
	"in_cover",
	"elevation",
	"active_effects",
	"is_wounded",
	"has_moved_this_turn",
	"is_player_controlled",
	"bot",
	"soulless"
]

const REQUIRED_CHARACTER_METHODS: Array[String] = [
	"get_equipped_weapon",
	"get_combat_skill",
	"get_speed",
	"get_melee_damage",
	"get_ranged_damage",
	"get_armor_value",
	"apply_status_effect",
	"remove_status_effect",
	"apply_damage",
	"heal_damage",
	"add_action_points",
	"reduce_action_points",
	"get_active_ability",
	"get_ability_cooldown",
	"is_ability_on_cooldown",
	"add_combat_modifier",
	"is_mechanical",
	"is_suppressed",
	"is_pinned",
	"has_overwatch",
	"can_counter_attack",
	"can_dodge",
	"can_suppress",
	"can_perform_action"
]

## Character Property Types
const CHARACTER_PROPERTY_TYPES := {
	"position": TYPE_VECTOR2I,
	"name": TYPE_STRING,
	"in_cover": TYPE_BOOL,
	"elevation": TYPE_INT,
	"active_effects": TYPE_ARRAY,
	"is_wounded": TYPE_BOOL,
	"has_moved_this_turn": TYPE_BOOL,
	"is_player_controlled": TYPE_BOOL,
	"bot": TYPE_BOOL,
	"soulless": TYPE_BOOL,
	"is_swift": TYPE_BOOL
}

## Safe Property Access Methods
func _get_character_property(character: Character, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value

	if not (property in CHARACTER_PROPERTY_TYPES):
		push_error("Unknown character property: %s" % property)
		return default_value

	if not (property in character):
		push_error("Character missing required property: %s" % property)
		return default_value

	var _value = character.get(property)
	if typeof(_value) != CHARACTER_PROPERTY_TYPES[property]:
		push_error("Character property '%s' has wrong type" % property)
		return default_value

	return _value

func _get_character_position(character: Character) -> Vector2i:
	return _get_character_property(character, "position", Vector2i())

func _get_character_name(character: Character) -> String:
	return _get_character_property(character, "name", "Unknown")

func _is_character_in_cover(character: Character) -> bool:
	return _get_character_property(character, "in_cover", false)

func _get_character_elevation(character: Character) -> int:
	return _get_character_property(character, "elevation", 0)

func _get_character_active_effects(character: Character) -> Array:
	return _get_character_property(character, "active_effects", [])

func _is_character_wounded(character: Character) -> bool:
	return _get_character_property(character, "is_wounded", false)

func _has_character_moved_this_turn(character: Character) -> bool:
	return _get_character_property(character, "has_moved_this_turn", false)

func _is_character_player_controlled(character: Character) -> bool:
	return _get_character_property(character, "is_player_controlled", false)

func _is_character_bot(character: Character) -> bool:
	return _get_character_property(character, "bot", false)

func _is_character_soulless(character: Character) -> bool:
	return _get_character_property(character, "soulless", false)

func _is_character_swift(character: Character) -> bool:
	return _get_character_property(character, "is_swift", false)

## Signals
signal combat_started()
signal combat_ended()
signal hit_calculated(attacker: Character, target: Character, hit_roll: int)
signal damage_calculated(attacker: Character, target: Character, damage: int)
signal special_ability_activated(character: Character, ability: String)
signal reaction_triggered(character: Character, reaction: String, attacker: Character)
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
var _active_combatants: Array[Character] = []
var combat_log: Array[String] = []
var manual_overrides: Dictionary = {}

## Functions
func _ready() -> void:
	combat_manager = get_node_or_null("/root/CombatManager")
	battlefield_manager = get_node_or_null("/root/BattlefieldManager")
	_load_terrain_types()
	_validate_character_interface()

func _load_terrain_types() -> void:
	var terrain_types: TerrainTypesScript = TerrainTypesScript.new()
	TERRAIN_TYPE_WATER = terrain_types.Type.WATER
	TERRAIN_TYPE_HAZARD = terrain_types.Type.HAZARD
	TERRAIN_TYPE_DIFFICULT = terrain_types.Type.DIFFICULT
	TERRAIN_TYPE_WALL = terrain_types.Type.WALL
	terrain_types.free()

func _validate_character_interface() -> void:
	var test_character: Character = Character.new()

	# Validate properties and their types
	for property: String in CHARACTER_PROPERTY_TYPES:
		assert(property in test_character, "Character class missing required property: " + property)
		var _value = test_character.get(property)
		assert(typeof(_value) == CHARACTER_PROPERTY_TYPES[property],
			"Character property %s should be type %s but was %s" % [
				property,
				CHARACTER_PROPERTY_TYPES[property],
				typeof(_value)
			])

	# Validate methods
	for method: String in REQUIRED_CHARACTER_METHODS:
		assert(test_character and test_character.has_method(method), "Character class missing required method: " + method)

	test_character.free()

func resolve_combat_action(attacker: Character, target: Character, action: GlobalEnumsScript.UnitAction) -> void:
	if not _validate_combat_requirements(attacker, target, action):
		return

	var _signal_result: Variant = emit_signal(&"combat_started")

	# Check for reactions before resolving the action
	_check_reaction_opportunities(attacker, target, action)

	match action:
		GlobalEnumsScript.UnitAction.ATTACK:
			_resolve_ranged_attack(attacker, target)
		GlobalEnumsScript.UnitAction.USE_ABILITY:
			_resolve_special_ability(attacker, target)
		_:
			push_warning("Unsupported combat action: %s" % action)

	emit_signal(&"combat_ended")

func _validate_combat_requirements(attacker: Character, target: Character, action: GlobalEnumsScript.UnitAction) -> bool:
	if not attacker or not target:
		push_error("Invalid attacker or target")
		return false

	if not attacker.can_perform_action(action):
		push_warning("Character cannot perform action: %s" % GlobalEnumsScript.UNIT_ACTION_NAMES[action])
		return false

	# Check line of sight
	if not _has_valid_line_of_sight(attacker, target):
		push_warning("No line of sight between attacker and target")
		return false

	# Check range and action-specific requirements
	match action:
		GlobalEnumsScript.UnitAction.ATTACK:
			# Check if within weapon range
			var distance: float = _get_distance_to_target(attacker, target)
			var max_range: float = _get_max_range_for_action(attacker, action)
			if distance > max_range:
				push_warning("Target out of range")
				return false

			# Check if must target closest enemy within 3"
			if distance <= 3.0:
				var closest_target: Character = _get_closest_enemy(attacker)
				if closest_target and closest_target != target:
					push_warning("Must target closest enemy within 3 inches")
					return false

			# Check if shot would endanger allies
			if _shot_endangers_allies(attacker, target):
				# Swift and Soulless can still shoot
				if not (_is_character_swift(attacker) or _is_character_soulless(attacker)):
					# Others need to roll 5+ to attempt
					if not _is_character_bot(attacker):
						var roll: int = randi() % 6 + 1
						if roll < 5:
							push_warning("Shot endangers allies and roll failed")
							return false
					else:
						push_warning("Shot endangers allies")
						return false

		GlobalEnumsScript.UnitAction.USE_ABILITY:
			# Check ability-specific requirements
			if not _validate_special_ability_requirements(attacker, target):
				push_warning("Special ability requirements not met")
				return false

	return true

func _has_valid_line_of_sight(attacker: Character, target: Character) -> bool:
	if not battlefield_manager:
		push_error("Battlefield manager not found")
		return false

	# Check basic line of sight
	if not battlefield_manager.has_line_of_sight(_get_character_position(attacker), _get_character_position(target)):
		return false

	# Check if line of sight crosses another character
	var line: Array[Vector2i] = battlefield_manager.get_line(_get_character_position(attacker), _get_character_position(target))
	for point in line:
		var blocking_character: Character = combat_manager.get_character_at(point)
		if blocking_character and blocking_character != attacker and blocking_character != target:
			return false

	# Check area feature rules
	var attacker_terrain: int = battlefield_manager.get_terrain_at(_get_character_position(attacker))
	var target_terrain: int = battlefield_manager.get_terrain_at(_get_character_position(target))

	# If attacker is in area feature and not at edge
	if _is_area_feature(attacker_terrain) and not _is_at_area_edge(_get_character_position(attacker)):
		# Can only see others in same area within 3"
		if _is_area_feature(target_terrain):
			return _get_distance_to_target(attacker, target) <= 3.0
		return false

	# If target is in area feature and not at edge
	if _is_area_feature(target_terrain) and not _is_at_area_edge(_get_character_position(target)):
		return false

	return true

func _validate_special_ability_requirements(attacker: Character, target: Character) -> bool:
	var ability: String = attacker.get_active_ability()
	if (safe_call_method(ability, "is_empty") == true):
		push_warning("No active ability")
		return false

	if attacker.is_ability_on_cooldown(ability):
		push_warning("Ability on cooldown")
		return false

	# Check ability-specific requirements
	match ability:
		"LEADERSHIP", "TACTICAL_GENIUS":
			# Requires allies within range
			var nearby_allies: Array[Character] = _get_nearby_allies(attacker)
			if (safe_call_method(nearby_allies, "is_empty") == true):
				push_warning("No allies in range for leadership/tactical ability")
				return false

		"MEDIC":
			# Requires wounded target
			if not _is_character_wounded(target):
				push_warning("Target not wounded for medic ability")
				return false

		"TECH_EXPERT":
			# Requires mechanical allies
			var nearby_allies: Array[Character] = _get_nearby_allies(attacker)
			var has_mechanical: bool = false
			for ally in nearby_allies:
				if ally.is_mechanical():
					has_mechanical = true
					break
			if not has_mechanical:
				push_warning("No mechanical allies in range for tech ability")
				return false

	return true

func _shot_endangers_allies(attacker: Character, target: Character) -> bool:
	if not battlefield_manager:
		push_error("Battlefield manager not found")
		return false

	var line: Array[Vector2i] = battlefield_manager.get_line(_get_character_position(attacker), _get_character_position(target))
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
	if not combat_manager:
		push_error("Combat manager not found")
		return null

	var enemies: Array[Character] = combat_manager.get_valid_targets(character)
	if (safe_call_method(enemies, "is_empty") == true):
		return
	var closest_enemy: Character = null
	var closest_distance: float = INF

	for enemy in enemies:
		var distance: float = _get_distance_to_target(character, enemy)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _is_area_feature(terrain_type: int) -> bool:
	# Check if terrain _type is an area feature (water, hazard, difficult)
	return terrain_type in [
		TERRAIN_TYPE_WATER,
		TERRAIN_TYPE_HAZARD,
		TERRAIN_TYPE_DIFFICULT
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

	var current_terrain: int = battlefield_manager.get_terrain_at(position)
	if not _is_area_feature(current_terrain):
		return false

	for adjacent in adjacent_positions:
		if battlefield_manager.is_valid_position(adjacent):
			var terrain: int = battlefield_manager.get_terrain_at(adjacent)
			if not _is_area_feature(terrain):
				return true

	return false

func _resolve_ranged_attack(attacker: Character, target: Character) -> void:
	var hit_modifier: int = _calculate_hit_modifier(attacker, target)
	var hit_threshold: int = _get_hit_threshold(attacker, target)
	var hit_roll: int = randi() % 6 + 1 + hit_modifier

	emit_signal(&"hit_calculated", attacker, target, hit_roll)

	if hit_roll >= hit_threshold:
		var damage: int = _calculate_damage(attacker, target, hit_roll)
		emit_signal(&"damage_calculated", attacker, target, damage)
		target.apply_damage(damage)
		_apply_combat_effects(attacker, target, hit_roll)

		# Handle weapon traits
		var weapon: Dictionary = attacker.get_equipped_weapon()
		if weapon:
			if "Critical" in weapon.traits and hit_roll == 6:
				# Critical hit - apply second hit
				damage = _calculate_damage(attacker, target, hit_roll)
				emit_signal(&"damage_calculated", attacker, target, damage)
				target.apply_damage(damage)

			if "Area" in weapon.traits:
				# Apply area effect to nearby targets
				var nearby_targets: Array[Character] = _get_targets_in_radius(_get_character_position(target), 2.0)
				for nearby in nearby_targets:
					if nearby != target:
						damage = _calculate_damage(attacker, nearby, hit_roll)
						emit_signal(&"damage_calculated", attacker, nearby, damage)
						nearby.apply_damage(damage)

			if "Terrifying" in weapon.traits:
				# Force target to retreat
				var retreat_distance: int = randi() % 6 + 1
				_apply_retreat(target, retreat_distance, _get_character_position(attacker))

			if "Stun" in weapon.traits:
				target.apply_status_effect({"effect": "stunned", "duration": 1})

func _calculate_hit_modifier(attacker: Character, target: Character) -> int:
	var modifier := 0
	var weapon: Dictionary = attacker.get_equipped_weapon()

	# Base modifiers
	modifier += attacker.get_combat_skill()

	# Range modifiers
	var distance := _get_distance_to_target(attacker, target)
	if weapon:
		if "Snap Shot" in weapon.traits and distance <= 6:
			modifier += 1
		if "Heavy" in weapon.traits and _has_character_moved_this_turn(attacker):
			modifier -= 1

	# Cover and elevation modifiers
	if _is_character_in_cover(target):
		modifier -= 1
	if _get_character_elevation(target) > _get_character_elevation(attacker):
		modifier -= 1
	elif _get_character_elevation(target) < _get_character_elevation(attacker):
		modifier += 1

	# Status effect modifiers
	modifier += _get_effect_modifier(_get_character_active_effects(attacker))

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
	var weapon: Dictionary = character.get_equipped_weapon()
	if weapon and weapon.has("effects"):
		effects.append_array(weapon.effects)
	return effects

func _get_valid_target(attacker: Character, action: GlobalEnumsScript.UnitAction) -> Character:
	if not combat_manager:
		push_error("Combat manager not found")
		return null

	var valid_targets: Array[Character] = combat_manager.get_valid_targets(attacker)
	if (safe_call_method(valid_targets, "is_empty") == true):
		return null
	if _is_character_player_controlled(attacker):
		return await _wait_for_player_target_selection(valid_targets)
	else:
		return _select_ai_target(attacker, valid_targets)

func _get_max_range_for_action(attacker: Character, action: GlobalEnumsScript.UnitAction) -> float:
	match action:
		GlobalEnumsScript.UnitAction.ATTACK:
			var weapon: Dictionary = attacker.get_equipped_weapon()
			if weapon:
				return weapon.range
			return 0.0
		GlobalEnumsScript.UnitAction.USE_ABILITY:
			var ability: String = attacker.get_active_ability()
			return _get_ability_range(ability)
		_:
			return 0.0

func _get_distance_to_target(attacker: Character, target: Character) -> float:
	if not battlefield_manager:
		push_error("Battlefield manager not found")
		return 0.0
	return battlefield_manager.get_distance_between(_get_character_position(attacker), _get_character_position(target))

func _apply_retreat(target: Character, distance: float, from_position: Vector2) -> void:
	if battlefield_manager:
		var target_pos: Vector2i = _get_character_position(target)
		# Convert Vector2i to Vector2 for calculations
		var target_pos_v2 := Vector2(target_pos)
		var retreat_direction: Vector2 = (target_pos_v2 - from_position).normalized()
		var new_position: Vector2 = target_pos_v2 + (retreat_direction * distance)
		# Convert back to Vector2i for move_character
		battlefield_manager.move_character(target, Vector2i(new_position))

func _get_targets_in_radius(center: Vector2, radius: float) -> Array[Character]:
	var targets: Array[Character] = []
	if battlefield_manager:
		targets = battlefield_manager.get_characters_in_radius(center, radius)
	return targets

func add_manual_override(override_type: String, _value: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	manual_overrides[override_type] = _value

func clear_manual_overrides() -> void:
	manual_overrides.clear()

func log_combat_event(_event: String) -> void:
	combat_log.append(_event)
	combat_log_updated.emit(_event)

func _get_hit_threshold(attacker: Character, target: Character) -> int:
	var threshold := 4 # Base threshold for hitting

	# Adjust for cover
	if _is_character_in_cover(target):
		threshold += 1

	# Adjust for elevation
	if _get_character_elevation(target) > _get_character_elevation(attacker):
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
	# Status effects based on hit _roll
	if hit_roll >= STUN_THRESHOLD:
		target.apply_status_effect({"effect": "stun", "duration": 1})
		emit_signal(&"combat_effect_applied", target, "stun")

		log_combat_event("%s was stunned" % _get_character_name(target))
	elif hit_roll >= SUPPRESS_THRESHOLD:
		target.apply_status_effect({"effect": "suppress", "duration": 1})
		emit_signal(&"combat_effect_applied", target, "suppress")

		log_combat_event("%s was suppressed" % _get_character_name(target))

	# Weapon-specific effects
	var weapon: Dictionary = attacker.get_equipped_weapon()
	if weapon:
		if "Knockback" in weapon.traits:
			_apply_knockback(target, _get_character_position(attacker), 2)
			emit_signal(&"combat_effect_applied", target, "knockback")
		if "Disarm" in weapon.traits and hit_roll >= 5:
			target.apply_status_effect({"effect": "disarmed", "duration": 1})
			emit_signal(&"combat_effect_applied", target, "disarmed")
		if "Stagger" in weapon.traits:
			target.reduce_action_points(1)
			emit_signal(&"combat_effect_applied", target, "stagger")
		if "Bleed" in weapon.traits and not target.is_mechanical():
			target.apply_status_effect({"effect": "bleeding", "duration": 2})
			emit_signal(&"combat_effect_applied", target, "bleeding")

func _apply_knockback(target: Character, from_position: Vector2i, distance: int) -> void:
	if not battlefield_manager:
		push_error("Battlefield manager not found")
		return

	var target_pos: Vector2i = _get_character_position(target)
	# Convert to Vector2 for normalization
	var direction: Vector2 = Vector2(target_pos - from_position).normalized()
	var knockback_position: Vector2i = target_pos + Vector2i(int(direction.x * distance), int(direction.y * distance))

	# Validate new _position
	if battlefield_manager.is_valid_position(knockback_position):
		battlefield_manager.move_character(target, knockback_position)

		log_combat_event("%s was knocked back" % _get_character_name(target))

		# Check for collision damage
		var terrain: int = battlefield_manager.get_terrain_at(knockback_position)
		if terrain == TERRAIN_TYPE_WALL:
			target.apply_damage(1)
			log_combat_event("%s took collision damage" % _get_character_name(target))

func _resolve_melee_attack(attacker: Character, target: Character) -> void:
	var hit_modifier: int = _calculate_melee_modifier(attacker, target)
	var hit_threshold: int = _calculate_melee_threshold(attacker, target)
	var hit_roll: int = randi() % 6 + 1 + hit_modifier

	var _signal_result: Variant = emit_signal(&"hit_calculated", attacker, target, hit_roll)

	if hit_roll >= hit_threshold:
		var damage: int = _calculate_melee_damage(attacker, target, hit_roll)
		emit_signal(&"damage_calculated", attacker, target, damage)
		target.apply_damage(damage)
		_apply_combat_effects(attacker, target, hit_roll)

func _calculate_melee_modifier(attacker: Character, target: Character) -> int:
	var modifier := 0

	# Base modifiers
	modifier += attacker.get_combat_skill()

	# Weapon traits
	var weapon: Dictionary = attacker.get_equipped_weapon()
	if weapon:
		if "Elegant" in weapon.traits:
			modifier += 1
		if "Clumsy" in weapon.traits and target.get_speed() > attacker.get_speed():
			modifier -= 1

	# Status effects
	modifier += _get_effect_modifier(_get_character_active_effects(attacker))

	return modifier

func _calculate_melee_threshold(attacker: Character, target: Character) -> int:
	var threshold := 4 # Base threshold for melee

	# Adjust for target's defense
	if _is_character_in_cover(target):
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

	var _signal_result: Variant = emit_signal(&"special_ability_activated", attacker, ability)
	log_combat_event("Special ability %s activated by %s" % [ability, _get_character_name(attacker)])

func _wait_for_player_target_selection(valid_targets: Array[Character]) -> Character:
	# This will be implemented by the UI system
	# For now, return the first valid target
	if not (safe_call_method(valid_targets, "is_empty") == true):
		return valid_targets[0]
	return null
func _select_ai_target(attacker: Character, valid_targets: Array[Character]) -> Character:
	# Simple AI - select closest valid target
	var closest_target: Character = null
	var closest_distance: float = INF

	for target in valid_targets:
		var distance: float = _get_distance_to_target(attacker, target)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target

	return closest_target

func _apply_leadership_bonus(character: Character) -> void:
	var allies: Array[Character] = _get_nearby_allies(character)
	for ally in allies:
		ally.apply_status_effect({"effect": "inspire", "duration": 2}) # Lasts 2 turns
		log_combat_event("%s inspired by %s's leadership" % [_get_character_name(ally), _get_character_name(character)])

func _apply_tactical_bonus(character: Character) -> void:
	var allies: Array[Character] = _get_nearby_allies(character)
	for ally in allies:
		ally.apply_status_effect({"effect": "focus", "duration": 2}) # Lasts 2 turns
		ally.add_action_points(1) # Bonus action point
		log_combat_event("%s gained tactical advantage from %s" % [_get_character_name(ally), _get_character_name(character)])

func _apply_marksman_bonus(character: Character) -> void:
	if character and character.has_method("apply_status_effect"): character.apply_status_effect({"effect": "focus", "duration": 3}) # Extended focus duration
	if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(1) # Elevation bonus for marksman (using integer instead of enum)
	log_combat_event("%s entered marksman stance" % _get_character_name(character))

func _apply_berserker_bonus(character: Character) -> void:
	if character and character.has_method("apply_status_effect"): character.apply_status_effect({"effect": "rage", "duration": 2}) # Lasts 2 turns
	if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(2) # Flanking bonus for berserker (using integer instead of enum)
	if character and character.has_method("add_action_points"): character.add_action_points(2) # Two bonus action points
	log_combat_event("%s entered berserker rage" % _get_character_name(character))

func _apply_medic_bonus(character: Character, target: Character) -> void:
	if target and _is_character_wounded(target):
		var heal_amount := 2
		target.heal_damage(heal_amount)
		target.remove_status_effect("bleeding")
		target.remove_status_effect("poison")
		log_combat_event("%s healed %s for %d damage" % [_get_character_name(character), _get_character_name(target), heal_amount])

func _apply_tech_bonus(character: Character) -> void:
	if character and character.has_method("apply_status_effect"): character.apply_status_effect({"effect": "tech_boost", "duration": 2}) # Lasts 2 turns
	if character and character.has_method("add_combat_modifier"): character.add_combat_modifier(3) # Stealth bonus for tech (using integer instead of enum)
	# Repair nearby mechanical allies
	var allies: Array[Character] = _get_nearby_allies(character)
	for ally in allies:
		if ally.is_mechanical():
			ally.heal_damage(1)
			log_combat_event("%s repaired %s" % [_get_character_name(character), _get_character_name(ally)])

func _get_nearby_allies(character: Character) -> Array[Character]:
	var allies: Array[Character] = []
	if battlefield_manager:
		allies = battlefield_manager.get_allies_in_range(character, 3.0) # 3 unit radius
	return allies

func _check_reaction_opportunities(attacker: Character, target: Character, action: GlobalEnumsScript.UnitAction) -> void:
	if not combat_manager:
		push_error("Combat manager not found")
		return

	var nearby_units: Array[Character] = _get_nearby_allies(target)
	for unit: Character in nearby_units:
		if unit == attacker or unit == target:
			continue

		# Check for overwatch reactions
		if action == GlobalEnumsScript.UnitAction.MOVE and unit.has_overwatch():
			emit_signal(&"reaction_triggered", unit, "overwatch", attacker)

		# Check for counter-attack reactions
		if action == GlobalEnumsScript.UnitAction.ATTACK and unit.can_counter_attack():
			emit_signal(&"reaction_triggered", unit, "counter_attack", attacker)

		# Check for dodge reactions
		if action == GlobalEnumsScript.UnitAction.ATTACK and unit.can_dodge():
			emit_signal(&"reaction_triggered", unit, "dodge", attacker)

		# Check for suppressing fire reactions
		if action == GlobalEnumsScript.UnitAction.ATTACK and unit.can_suppress():
			emit_signal(&"reaction_triggered", unit, "suppressing_fire", attacker)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null