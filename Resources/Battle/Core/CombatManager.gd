extends Node

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

@export var battlefield_manager: Node  # Will be cast to BattlefieldManager
@export var combat_resolver: Node      # Will be cast to CombatResolver

signal combat_effect_triggered(effect_name: String, source: Character, target: Character)
signal reaction_opportunity(unit: Character, reaction_type: String, source: Character)
signal action_completed

const CRITICAL_MULTIPLIER := 1.5
const MELEE_RANGE := 1.5

func _apply_pre_attack_effects(attacker: Character) -> void:
	# Apply weapon preparation effects
	if attacker.has_weapon_effects():
		attacker.apply_weapon_effects()
	
	# Apply offensive stance bonuses
	if attacker.has_offensive_stance():
		attacker.apply_offensive_bonus()

func _handle_post_attack_effects(attacker: Character, target: Character, combat_result: Dictionary) -> void:
	# Reset temporary combat bonuses
	attacker.reset_combat_bonuses()
	
	# Apply post-attack status effects
	if attacker.has_post_attack_effects():
		attacker.apply_post_attack_effects()
	
	# Process combat result effects
	for effect in combat_result.effects:
		combat_effect_triggered.emit(effect, attacker, target)
	
	# Handle reactions
	for reaction in combat_result.reactions:
		reaction_opportunity.emit(reaction.unit, reaction.type, attacker)

func _update_combat_state(attacker: Character, target: Character, combat_result: Dictionary) -> void:
	# Update unit states
	attacker.update_combat_state()
	target.update_combat_state()
	
	# Update battlefield state if needed
	if combat_result.has("battlefield_effects"):
		for effect in combat_result.battlefield_effects:
			_apply_battlefield_effect(effect)

func _apply_battlefield_effect(effect: Dictionary) -> void:
	match effect.type:
		"terrain_damage":
			# Handle terrain damage
			pass
		"area_effect":
			# Handle area effects
			pass
		"environmental":
			# Handle environmental changes
			pass

func _is_in_melee_range(pos1: Vector2, pos2: Vector2) -> bool:
	return pos1.distance_to(pos2) <= MELEE_RANGE

func _calculate_terrain_modifier(attacker_pos: Vector2i, target_pos: Vector2i) -> float:
	var modifier = 1.0
	
	# Get terrain types
	var attacker_terrain = TerrainTypes.Type.EMPTY
	var target_terrain = TerrainTypes.Type.EMPTY
	
	if battlefield_manager:
		var terrain_map = battlefield_manager.terrain_map
		if _is_valid_position(attacker_pos):
			attacker_terrain = terrain_map[attacker_pos.x][attacker_pos.y]
		if _is_valid_position(target_pos):
			target_terrain = terrain_map[target_pos.x][target_pos.y]
	
	# Apply elevation advantage
	var elevation_diff = TerrainTypes.get_elevation(attacker_terrain) - TerrainTypes.get_elevation(target_terrain)
	if elevation_diff > 0:
		modifier *= 1.2
	elif elevation_diff < 0:
		modifier *= 0.8
	
	# Apply cover penalty
	if TerrainTypes.get_cover_value(target_terrain) > 0:
		modifier *= 0.8
	
	return modifier

func _is_valid_position(pos: Vector2i) -> bool:
	if not battlefield_manager:
		return false
		
	return pos.x >= 0 and pos.x < battlefield_manager.grid_size.x and \
		   pos.y >= 0 and pos.y < battlefield_manager.grid_size.y

func get_character_position(character: Character) -> Vector2:
	if battlefield_manager:
		return battlefield_manager.unit_positions.get(character, Vector2.ZERO)
	return Vector2.ZERO
