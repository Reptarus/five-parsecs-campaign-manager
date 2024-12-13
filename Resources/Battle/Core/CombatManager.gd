extends Node

const TerrainTypes = preload("res://Resources/Battle/Core/TerrainTypes.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")

signal combat_effect_triggered(effect_name: String, source: Character, target: Character)
signal reaction_opportunity(unit: Character, reaction_type: String, source: Character)
signal terrain_updated(position: Vector2i, old_type: int, new_type: int)
signal battlefield_effect_applied(effect_type: String, position: Vector2i)

@export var battlefield_manager: Node  # Will be cast to BattlefieldManager

const MELEE_RANGE := 1.5
const COVER_MODIFIER := 0.8
const ELEVATION_ADVANTAGE := 1.2
const ELEVATION_DISADVANTAGE := 0.8

# Initialization
func _ready() -> void:
	if not battlefield_manager:
		push_warning("CombatManager: No battlefield manager assigned")

# Terrain and Position Management
func calculate_terrain_modifier(attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	if not _validate_battlefield_manager():
		return 1.0
		
	var modifier = 1.0
	var terrain_data = _get_terrain_data(attacker_pos, target_pos)
	
	# Apply elevation advantage
	modifier *= _calculate_elevation_modifier(terrain_data)
	
	# Apply cover penalty
	modifier *= _calculate_cover_modifier(terrain_data)
	
	return modifier

func _get_terrain_data(attacker_pos: Vector2i, target_pos: Vector2i) -> Dictionary:
	var data = {
		"attacker_terrain": TerrainTypes.Type.EMPTY,
		"target_terrain": TerrainTypes.Type.EMPTY,
		"valid_positions": false
	}
	
	if battlefield_manager and battlefield_manager.terrain_map:
		if is_valid_position(attacker_pos) and is_valid_position(target_pos):
			data.attacker_terrain = battlefield_manager.terrain_map[attacker_pos.x][attacker_pos.y]
			data.target_terrain = battlefield_manager.terrain_map[target_pos.x][target_pos.y]
			data.valid_positions = true
	
	return data

func _calculate_elevation_modifier(terrain_data: Dictionary) -> float:
	if not terrain_data.valid_positions:
		return 1.0
		
	var elevation_diff = TerrainTypes.get_elevation(terrain_data.attacker_terrain) - \
						TerrainTypes.get_elevation(terrain_data.target_terrain)
	
	if elevation_diff > 0:
		return ELEVATION_ADVANTAGE
	elif elevation_diff < 0:
		return ELEVATION_DISADVANTAGE
	return 1.0

func _calculate_cover_modifier(terrain_data: Dictionary) -> float:
	if not terrain_data.valid_positions:
		return 1.0
		
	return COVER_MODIFIER if TerrainTypes.get_cover_value(terrain_data.target_terrain) > 0 else 1.0

func is_valid_position(pos: Vector2i) -> bool:
	if not _validate_battlefield_manager():
		return false
		
	return pos.x >= 0 and pos.x < battlefield_manager.grid_size.x and \
		   pos.y >= 0 and pos.y < battlefield_manager.grid_size.y

func get_character_position(character: Character) -> Vector2:
	if not _validate_battlefield_manager():
		return Vector2.ZERO
		
	return battlefield_manager.unit_positions.get(character, Vector2.ZERO)

func is_in_melee_range(pos1: Vector2, pos2: Vector2) -> bool:
	return pos1.distance_to(pos2) <= MELEE_RANGE

# Combat State Management
func update_combat_state(attacker: Character, target: Character, combat_result: Dictionary) -> void:
	if not _validate_combat_state_update(attacker, target, combat_result):
		return
		
	# Update unit states
	attacker.update_combat_state()
	target.update_combat_state()
	
	# Update battlefield state if needed
	if combat_result.has("battlefield_effects"):
		for effect in combat_result.battlefield_effects:
			apply_battlefield_effect(effect)

func apply_battlefield_effect(effect: Dictionary) -> void:
	if not _validate_battlefield_manager():
		return
		
	if not _validate_effect(effect):
		push_warning("CombatManager: Invalid battlefield effect data")
		return
		
	match effect.type:
		"terrain_damage":
			_apply_terrain_damage(effect)
		"area_effect":
			_apply_area_effect(effect)
		"environmental":
			_apply_environmental_effect(effect)
			
	battlefield_effect_applied.emit(effect.type, effect.get("position", Vector2i.ZERO))

func _apply_terrain_damage(effect: Dictionary) -> void:
	if battlefield_manager.has_method("apply_terrain_damage"):
		battlefield_manager.apply_terrain_damage(effect.position, effect.amount)
		terrain_updated.emit(effect.position, effect.old_type, effect.new_type)

func _apply_area_effect(effect: Dictionary) -> void:
	if battlefield_manager.has_method("apply_area_effect"):
		battlefield_manager.apply_area_effect(effect.center, effect.radius, effect.effect_type)

func _apply_environmental_effect(effect: Dictionary) -> void:
	if battlefield_manager.has_method("update_environment"):
		battlefield_manager.update_environment(effect.changes)

# Combat Effects
func apply_pre_attack_effects(attacker: Character) -> void:
	if not attacker:
		return
		
	# Apply weapon preparation effects
	if attacker.has_weapon_effects():
		attacker.apply_weapon_effects()
		combat_effect_triggered.emit("weapon_prepared", attacker, null)
	
	# Apply offensive stance bonuses
	if attacker.has_offensive_stance():
		attacker.apply_offensive_bonus()
		combat_effect_triggered.emit("offensive_stance", attacker, null)

func handle_post_attack_effects(attacker: Character, target: Character, combat_result: Dictionary) -> void:
	if not _validate_post_attack_state(attacker, target, combat_result):
		return
		
	# Reset temporary combat bonuses
	attacker.reset_combat_bonuses()
	
	# Apply post-attack status effects
	if attacker.has_post_attack_effects():
		attacker.apply_post_attack_effects()
		combat_effect_triggered.emit("post_attack", attacker, target)
	
	# Process combat result effects
	for effect in combat_result.get("effects", []):
		combat_effect_triggered.emit(effect, attacker, target)

func check_reaction_opportunities(target: Character, source: Character) -> void:
	if not target or not source:
		return
		
	# Check for reaction fire opportunity
	if target.can_react() and target.has_reaction_shots():
		reaction_opportunity.emit(target, "snap_fire", source)
	
	# Check for other reaction types
	if target.can_react() and target.has_defensive_stance():
		reaction_opportunity.emit(target, "defensive_stance", source)

# Validation Helpers
func _validate_battlefield_manager() -> bool:
	return battlefield_manager != null and battlefield_manager.is_inside_tree()

func _validate_combat_state_update(attacker: Character, target: Character, combat_result: Dictionary) -> bool:
	return attacker != null and target != null and combat_result != null

func _validate_effect(effect: Dictionary) -> bool:
	return effect.has("type") and effect.type in ["terrain_damage", "area_effect", "environmental"]

func _validate_post_attack_state(attacker: Character, target: Character, combat_result: Dictionary) -> bool:
	return attacker != null and target != null and combat_result != null
