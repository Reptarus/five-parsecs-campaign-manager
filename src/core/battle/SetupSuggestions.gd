class_name FPCM_SetupSuggestions
extends Resource

## Battlefield Setup Suggestions Resource
##
## Contains generated terrain and deployment suggestions following Five Parsecs rules.
## This class provides the missing type that's referenced throughout the battle system.

# Core suggestion data
@export var terrain_features: Array[FPCM_BattlefieldTypes.TerrainFeature] = []
@export var deployment_zones: Dictionary = {}
@export var special_rules: Array[String] = []
@export var mission_context: Dictionary = {}

# Generation metadata
@export var generation_seed: int = 0
@export var generation_time: float = 0.0
@export var generator_version: String = "1.0"

# Display helpers
@export var setup_summary: String = ""
@export var terrain_count: int = 0
@export var difficulty_rating: String = "Standard"

func _init() -> void:
	generation_time = Time.get_unix_time_from_system()
	generation_seed = RandomNumberGenerator.new().randi()

## Initialize with terrain suggestions
func setup_terrain_suggestions(features: Array[FPCM_BattlefieldTypes.TerrainFeature]) -> void:
	terrain_features = features
	terrain_count = features.size()
	_generate_setup_summary()

## Add deployment zone information
func set_deployment_zones(crew_zone: Array[Vector2i], enemy_zone: Array[Vector2i]) -> void:
	deployment_zones = {
		"crew": crew_zone,
		"enemy": enemy_zone,
		"crew_area": "Western 4 inches",
		"enemy_area": "Eastern 4 inches"
	}

## Add special rules for this battlefield
func add_special_rule(rule: String) -> void:
	if rule not in special_rules:
		special_rules.append(rule)

## Set mission context
func set_mission_context(context: Dictionary) -> void:
	mission_context = context
	_update_difficulty_rating()

## Get formatted setup summary for UI display
func get_setup_summary() -> String:
	if setup_summary.is_empty():
		_generate_setup_summary()
	return setup_summary

## Get terrain features for UI display
func get_terrain_features() -> Array[FPCM_BattlefieldTypes.TerrainFeature]:
	return terrain_features

## Get deployment guidance for UI
func get_deployment_guidance() -> Dictionary:
	return {
		"crew_deployment": deployment_zones.get("crew_area", "Western edge"),
		"enemy_deployment": deployment_zones.get("enemy_area", "Eastern edge"),
		"spacing_rules": ["2-inch minimum spacing", "No deployment in difficult terrain"],
		"special_notes": special_rules
	}

## Get difficulty assessment
func get_difficulty_rating() -> String:
	return difficulty_rating

## Check if suggestions are complete
func is_complete() -> bool:
	return terrain_features.size() > 0 and not deployment_zones.is_empty()

## Generate terrain count summary
func get_terrain_count() -> int:
	return terrain_count

## Convert to dictionary for serialization
func to_dict() -> Dictionary:
	return {
		"terrain_features": terrain_features.map(func(f): return f.to_dict() if f.has_method("to_dict") else {}),
		"deployment_zones": deployment_zones,
		"special_rules": special_rules,
		"mission_context": mission_context,
		"generation_seed": generation_seed,
		"generation_time": generation_time,
		"setup_summary": setup_summary,
		"terrain_count": terrain_count,
		"difficulty_rating": difficulty_rating
	}

## Generate setup summary text
func _generate_setup_summary() -> void:
	var feature_types: Dictionary = {}
	
	# Count feature types
	for feature in terrain_features:
		var type_name = str(feature.feature_type)
		feature_types[type_name] = feature_types.get(type_name, 0) + 1
	
	# Build summary
	var summary_parts: Array[String] = []
	summary_parts.append("Battlefield Setup: %d terrain features" % terrain_count)
	
	for type_name in feature_types.keys():
		var count = feature_types[type_name]
		summary_parts.append("• %d %s feature%s" % [count, type_name.capitalize(), "s" if count > 1 else ""])
	
	if special_rules.size() > 0:
		summary_parts.append("Special Rules: %d active" % special_rules.size())
	
	setup_summary = "\n".join(summary_parts)

## Update difficulty rating based on mission and terrain
func _update_difficulty_rating() -> void:
	var difficulty_score = 0
	
	# Base difficulty from terrain count
	if terrain_count >= 6:
		difficulty_score += 2
	elif terrain_count >= 4:
		difficulty_score += 1
	
	# Mission complexity modifier
	var mission_type = mission_context.get("mission_type", "patrol")
	match mission_type:
		"assault", "defense":
			difficulty_score += 2
		"investigation", "rescue":
			difficulty_score += 1
	
	# Special rules modifier
	difficulty_score += special_rules.size()
	
	# Determine rating
	if difficulty_score >= 5:
		difficulty_rating = "Challenging"
	elif difficulty_score >= 3:
		difficulty_rating = "Moderate"
	else:
		difficulty_rating = "Standard"
