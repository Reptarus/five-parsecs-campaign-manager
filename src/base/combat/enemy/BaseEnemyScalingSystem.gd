@tool
extends Node
class_name BaseEnemyScalingSystem

# Signals
signal enemy_scaled(enemy: Node, difficulty: float, scale_factors: Dictionary)
signal difficulty_changed(new_difficulty: float)
signal scaling_rules_updated()

# Configuration
var base_difficulty: float = 1.0
var difficulty_multiplier: float = 1.0
var scaling_enabled: bool = true
var adaptive_scaling: bool = false
var player_performance_weight: float = 0.5
var mission_progress_weight: float = 0.3
var game_progress_weight: float = 0.2

# Scaling factors
var health_scaling: float = 1.0
var damage_scaling: float = 1.0
var defense_scaling: float = 1.0
var accuracy_scaling: float = 1.0
var ai_aggression_scaling: float = 1.0
var special_ability_scaling: float = 1.0
var quantity_scaling: float = 1.0

# Performance tracking
var player_performance_score: float = 0.0
var mission_progress: float = 0.0
var game_progress: float = 0.0

# Virtual methods to be implemented by derived classes
func initialize(config: Dictionary = {}) -> void:
	# Apply configuration
	if "base_difficulty" in config:
		base_difficulty = config.base_difficulty
	if "difficulty_multiplier" in config:
		difficulty_multiplier = config.difficulty_multiplier
	if "scaling_enabled" in config:
		scaling_enabled = config.scaling_enabled
	if "adaptive_scaling" in config:
		adaptive_scaling = config.adaptive_scaling
	
	# Apply scaling factors
	if "scaling_factors" in config:
		var factors = config.scaling_factors
		if "health" in factors:
			health_scaling = factors.health
		if "damage" in factors:
			damage_scaling = factors.damage
		if "defense" in factors:
			defense_scaling = factors.defense
		if "accuracy" in factors:
			accuracy_scaling = factors.accuracy
		if "ai_aggression" in factors:
			ai_aggression_scaling = factors.ai_aggression
		if "special_ability" in factors:
			special_ability_scaling = factors.special_ability
		if "quantity" in factors:
			quantity_scaling = factors.quantity
	
	scaling_rules_updated.emit()

func scale_enemy(enemy: Node, enemy_type: String = "") -> void:
	if not scaling_enabled:
		return
	
	var current_difficulty = calculate_current_difficulty()
	var scale_factors = calculate_scale_factors(enemy_type, current_difficulty)
	
	_apply_scaling(enemy, scale_factors)
	
	enemy_scaled.emit(enemy, current_difficulty, scale_factors)

func calculate_current_difficulty() -> float:
	var difficulty = base_difficulty * difficulty_multiplier
	
	if adaptive_scaling:
		var performance_factor = player_performance_score * player_performance_weight
		var mission_factor = mission_progress * mission_progress_weight
		var game_factor = game_progress * game_progress_weight
		
		difficulty *= (1.0 + performance_factor + mission_factor + game_factor)
	
	return difficulty

func calculate_scale_factors(enemy_type: String, difficulty: float) -> Dictionary:
	var factors = {
		"health": health_scaling * difficulty,
		"damage": damage_scaling * difficulty,
		"defense": defense_scaling * difficulty,
		"accuracy": accuracy_scaling * difficulty,
		"ai_aggression": ai_aggression_scaling * difficulty,
		"special_ability": special_ability_scaling * difficulty,
		"quantity": quantity_scaling * difficulty
	}
	
	# Apply enemy type specific modifiers
	_apply_enemy_type_modifiers(factors, enemy_type)
	
	return factors

func _apply_enemy_type_modifiers(factors: Dictionary, enemy_type: String) -> void:
	# To be implemented by derived classes
	pass

func _apply_scaling(enemy: Node, scale_factors: Dictionary) -> void:
	# To be implemented by derived classes
	pass

# Performance tracking
func update_player_performance(performance_data: Dictionary) -> void:
	if not adaptive_scaling:
		return
	
	# Calculate new performance score
	var new_score = _calculate_performance_score(performance_data)
	
	# Update performance score with smoothing
	player_performance_score = lerp(player_performance_score, new_score, 0.3)
	
	# Update difficulty
	var new_difficulty = calculate_current_difficulty()
	difficulty_changed.emit(new_difficulty)

func update_mission_progress(progress: float) -> void:
	mission_progress = clamp(progress, 0.0, 1.0)
	
	if adaptive_scaling:
		var new_difficulty = calculate_current_difficulty()
		difficulty_changed.emit(new_difficulty)

func update_game_progress(progress: float) -> void:
	game_progress = clamp(progress, 0.0, 1.0)
	
	if adaptive_scaling:
		var new_difficulty = calculate_current_difficulty()
		difficulty_changed.emit(new_difficulty)

func _calculate_performance_score(performance_data: Dictionary) -> float:
	var score = 0.0
	
	# Factors to consider
	if "kills" in performance_data:
		score += performance_data.kills * 0.2
	if "damage_dealt" in performance_data:
		score += performance_data.damage_dealt * 0.1
	if "damage_taken" in performance_data:
		score -= performance_data.damage_taken * 0.1
	if "objectives_completed" in performance_data:
		score += performance_data.objectives_completed * 0.3
	if "turns_taken" in performance_data and performance_data.turns_taken > 0:
		score -= 1.0 / performance_data.turns_taken * 0.2
	
	return clamp(score, -1.0, 1.0)

# Utility methods
func get_scaling_config() -> Dictionary:
	return {
		"base_difficulty": base_difficulty,
		"difficulty_multiplier": difficulty_multiplier,
		"scaling_enabled": scaling_enabled,
		"adaptive_scaling": adaptive_scaling,
		"player_performance_weight": player_performance_weight,
		"mission_progress_weight": mission_progress_weight,
		"game_progress_weight": game_progress_weight,
		"scaling_factors": {
			"health": health_scaling,
			"damage": damage_scaling,
			"defense": defense_scaling,
			"accuracy": accuracy_scaling,
			"ai_aggression": ai_aggression_scaling,
			"special_ability": special_ability_scaling,
			"quantity": quantity_scaling
		}
	}

func set_scaling_config(config: Dictionary) -> void:
	initialize(config)

func reset_performance_tracking() -> void:
	player_performance_score = 0.0
	mission_progress = 0.0