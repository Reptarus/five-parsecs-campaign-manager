class_name AIBehaviorController
extends Node

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")

signal action_decided(unit: Character, action: int, target_position: Vector2)
signal target_selected(unit: Character, target: Character)
signal behavior_changed(unit: Character, new_behavior: int)

enum AIBehavior {
	AGGRESSIVE,    # Prioritize attacking enemies
	DEFENSIVE,     # Prioritize staying in cover and maintaining distance
	SUPPORT,       # Focus on supporting allies
	FLANKING,      # Try to get advantageous positions
	OBJECTIVE      # Focus on mission objectives
}

enum AITactic {
	ENGAGE_CLOSE,     # Move closer to engage
	MAINTAIN_RANGE,   # Keep optimal distance
	SEEK_COVER,      # Move to cover
	FLANK_TARGET,    # Move to flanking position
	SUPPORT_ALLY,    # Move to support position
	RETREAT          # Move away from danger
}

# Required node references
@export var battlefield_manager: Node  # Will be cast to BattlefieldManager
@export var combat_resolver: Node      # Will be cast to CombatResolver

# AI state tracking
var unit_behaviors: Dictionary = {}    # Character -> AIBehavior
var unit_targets: Dictionary = {}      # Character -> Character
var unit_tactics: Dictionary = {}      # Character -> AITactic
var threat_map: Dictionary = {}        # Vector2i -> float
var current_unit: Character = null     # Currently active unit

# Squad formation settings
const IDEAL_SPACING := 3.0            # Ideal distance between units
const MAX_SUPPORT_RANGE := 12.0       # Maximum range for support calculations
const OBJECTIVE_WEIGHT := 0.6         # Weight for objective-based decisions

func _ready() -> void:
	if battlefield_manager:
		battlefield_manager.tactical_advantage_changed.connect(_on_tactical_advantage_changed)

func initialize_unit(unit: Character, behavior: int) -> void:
	unit_behaviors[unit] = behavior
	unit_tactics[unit] = AITactic.MAINTAIN_RANGE

func _evaluate_support_needs(unit: Character) -> float:
	if not battlefield_manager:
		return 0.0
		
	var allies = _get_nearby_allies(unit, 8.0)
	var support_need = 0.0
	
	for ally in allies:
		var health_ratio = float(ally.get_current_health()) / ally.get_max_health()
		if health_ratio < 0.5:
			support_need += (0.5 - health_ratio) * 2.0
		
		# Check for status effects that need support
		if ally.has_negative_effects():
			support_need += 0.3
	
	return clampf(support_need, 0.0, 1.0)

func _calculate_objective_priority(unit: Character) -> float:
	if not battlefield_manager or battlefield_manager.objective_positions.is_empty():
		return 0.0
	
	var unit_pos = battlefield_manager.unit_positions[unit]
	var closest_distance = INF
	
	for obj_pos in battlefield_manager.objective_positions:
		var distance = unit_pos.distance_to(obj_pos)
		closest_distance = min(closest_distance, distance)
	
	return 1.0 - clampf(closest_distance / 20.0, 0.0, 1.0)

func _evaluate_squad_status(unit: Character) -> Dictionary:
	var allies = _get_nearby_allies(unit, MAX_SUPPORT_RANGE)
	return {
		"average_health": _calculate_average_health(allies),
		"formation_integrity": _calculate_formation_integrity(allies),
		"support_coverage": _calculate_support_coverage(allies),
		"threat_distribution": _calculate_threat_distribution(allies)
	}

func _calculate_average_health(allies: Array) -> float:
	if allies.is_empty():
		return 0.0
	
	var total_health = 0.0
	for ally in allies:
		total_health += float(ally.get_current_health()) / ally.get_max_health()
	
	return total_health / allies.size()

func _calculate_formation_integrity(allies: Array) -> float:
	if allies.size() < 2:
		return 1.0
	
	var integrity = 1.0
	
	for i in range(allies.size()):
		for j in range(i + 1, allies.size()):
			var pos1 = battlefield_manager.unit_positions[allies[i]]
			var pos2 = battlefield_manager.unit_positions[allies[j]]
			var distance = pos1.distance_to(pos2)
			var spacing_score = 1.0 - abs(distance - IDEAL_SPACING) / IDEAL_SPACING
			integrity *= spacing_score
	
	return clampf(integrity, 0.0, 1.0)

func _calculate_support_coverage(allies: Array) -> float:
	if not current_unit or allies.is_empty():
		return 0.0
		
	var total_coverage := 0.0
	var best_support_distance := INF
	
	var unit_pos = battlefield_manager.unit_positions[current_unit]
	
	for ally in allies:
		var ally_pos = battlefield_manager.unit_positions[ally]
		best_support_distance = min(best_support_distance, ally_pos.distance_to(unit_pos))
	
	if best_support_distance < INF:
		total_coverage = 1.0 - clampf(best_support_distance / 10.0, 0.0, 1.0)
	
	return total_coverage

func _calculate_threat_distribution(allies: Array) -> float:
	if allies.is_empty():
		return 0.0
		
	var threat_positions = {}
	var total_threat = 0.0
	
	# Calculate threat for each position
	for ally in allies:
		var pos = battlefield_manager.unit_positions[ally]
		var grid_pos = battlefield_manager._world_to_grid(pos)
		var threat = _calculate_position_threat(grid_pos)
		threat_positions[grid_pos] = threat
		total_threat += threat
	
	# Calculate threat distribution evenness
	var avg_threat = total_threat / allies.size()
	var variance = 0.0
	
	for threat in threat_positions.values():
		variance += pow(threat - avg_threat, 2)
	
	variance /= allies.size()
	
	return 1.0 - clampf(sqrt(variance) / avg_threat, 0.0, 1.0)

func _get_nearby_allies(unit: Character, range: float) -> Array:
	var allies = []
	var unit_pos = battlefield_manager.unit_positions[unit]
	
	for other in battlefield_manager.unit_positions.keys():
		if other != unit and not other.is_enemy():
			var other_pos = battlefield_manager.unit_positions[other]
			if unit_pos.distance_to(other_pos) <= range:
				allies.append(other)
	
	return allies

func _calculate_position_threat(grid_pos: Vector2i) -> float:
	if not threat_map.has(grid_pos):
		return 0.0
	return threat_map[grid_pos]

func _on_tactical_advantage_changed(unit: Character, advantage_type: String, value: float) -> void:
	if unit_behaviors.has(unit):
		var new_behavior = _determine_behavior(unit)
		if new_behavior != unit_behaviors[unit]:
			unit_behaviors[unit] = new_behavior
			behavior_changed.emit(unit, new_behavior)

func _determine_behavior(unit: Character) -> int:
	# Implementation will depend on your specific game rules
	return AIBehavior.DEFENSIVE  # Default behavior