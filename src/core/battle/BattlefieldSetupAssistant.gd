class_name FPCM_BattlefieldSetupAssistant
extends Node

## Battlefield Setup Assistant
##
## Generates terrain placement suggestions and deployment guidance
## following Five Parsecs from Home Core Rules (p.67-69).
## Designed as a companion tool - provides suggestions for physical setup,
## not mandatory placement enforcement.
##
## Architecture: Lightweight suggestion engine focused on rulebook compliance
## Performance: Optimized for real-time generation with minimal memory overhead

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const BattlefieldData = preload("res://src/core/battle/BattlefieldData.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals for UI integration
signal setup_suggestions_ready(suggestions: SetupSuggestions)
signal terrain_generation_complete(terrain_features: Array[BattlefieldTypes.TerrainFeature])
signal deployment_zones_calculated(crew_zone: Array[Vector2i], enemy_zone: Array[Vector2i])
signal objectives_placed(objectives: Array[BattlefieldTypes.FPCM_ObjectiveMarker])
signal setup_error(error_message: String, context: Dictionary)

# Setup suggestion data structure
class SetupSuggestions extends Resource:
	@export var terrain_suggestions: Array[TerrainSuggestion] = []
	@export var deployment_guidance: DeploymentGuidance = null
	@export var objective_recommendations: Array[ObjectiveRecommendation] = []
	@export var special_rules: Array[String] = []
	@export var estimated_setup_time: int = 15 # minutes
	@export var complexity_rating: String = "Standard" # Simple, Standard, Complex

	func get_total_terrain_pieces() -> int:
		return terrain_suggestions.size()

	func get_setup_summary() -> String:
		return "Battlefield with %d terrain features, estimated %d min setup" % [
			get_total_terrain_pieces(), estimated_setup_time
		]

class TerrainSuggestion extends Resource:
	@export var suggestion_id: String = ""
	@export var terrain_type: StringName = &""
	@export var placement_description: String = ""
	@export var visual_description: String = ""
	@export var game_effects: Array[String] = []
	@export var suggested_models: Array[String] = []
	@export var priority: int = 1 # 1=Required, 2=Recommended, 3=Optional
	@export var estimated_footprint: Vector2i = Vector2i(1, 1)
	@export var alternative_options: Array[String] = []

class DeploymentGuidance extends Resource:
	@export var crew_zone_description: String = ""
	@export var enemy_zone_description: String = ""
	@export var deployment_restrictions: Array[String] = []
	@export var special_deployment_rules: Array[String] = []
	@export var recommended_spacing: int = 2 # inches between models

class ObjectiveRecommendation extends Resource:
	@export var objective_type: StringName = &""
	@export var placement_suggestion: String = ""
	@export var victory_condition: String = ""
	@export var special_rules: Array[String] = []
	@export var required_markers: Array[String] = []

# System state
@export var battlefield_size: Vector2i = Vector2i(20, 20) # 20x20 inch standard
@export var current_mission_type: String = "patrol"
@export var difficulty_modifier: int = 0
@export var environmental_conditions: Dictionary = {}

# Manager references with dependency injection
var battlefield_data: BattlefieldData = null
var dice_manager: Node = null

func _ready() -> void:
	"""Initialize setup assistant with error handling"""
	_initialize_dependencies()
	_validate_configuration()

func _initialize_dependencies() -> void:
	"""Initialize manager dependencies with fallback handling"""
	# Dice manager dependency
	dice_manager = _get_manager_reference("DiceManager")
	if not dice_manager:
		push_warning("SetupAssistant: DiceManager not available, using fallback generation")

	# Battlefield data can be injected or created
	if not battlefield_data:
		battlefield_data = BattlefieldData.new()

func _get_manager_reference(manager_name: String) -> Node:
	"""Safe manager reference retrieval"""
	var paths_to_try := [
		"/root/%s" % manager_name,
		"../../%s" % manager_name,
		"../%s" % manager_name
	]

	for path in paths_to_try:
		if has_node(path):
			return get_node(path)

	return null

func _validate_configuration() -> void:
	"""Validate setup assistant configuration"""
	if battlefield_size.x < 12 or battlefield_size.y < 12:
		push_warning("SetupAssistant: Battlefield size may be too small for proper deployment")

	if battlefield_size.x > 48 or battlefield_size.y > 48:
		push_warning("SetupAssistant: Large battlefield may require additional terrain")

# =====================================================
# PUBLIC API - MAIN GENERATION METHODS
# =====================================================

func generate_battlefield_suggestions(mission_data: Resource = null, options: Dictionary = {}) -> SetupSuggestions:
	"""
	Generate complete battlefield setup suggestions

	@param mission_data: Optional mission resource containing specific requirements
	@param options: Setup options like terrain_density, complexity_level
	@return: Complete setup suggestions ready for physical implementation
	"""
	var suggestions := SetupSuggestions.new()

	# Parse mission requirements
	var mission_context := _parse_mission_requirements(mission_data, options)
	if mission_context.is_empty():
		var error_msg := "Failed to parse mission requirements"
		var context := {"mission_data": mission_data != null, "options": options}
		setup_error.emit(error_msg, context)
		return _generate_fallback_suggestions()

	# Generate terrain suggestions per Five Parsecs rules
	suggestions.terrain_suggestions = _generate_terrain_suggestions(mission_context)
	if suggestions.terrain_suggestions.is_empty():
		push_warning("SetupAssistant: No terrain suggestions generated, using fallback")
		suggestions.terrain_suggestions = _generate_fallback_terrain()

	# Calculate deployment zones
	suggestions.deployment_guidance = _generate_deployment_guidance(mission_context)
	if not suggestions.deployment_guidance:
		push_warning("SetupAssistant: Failed to generate deployment guidance")
		suggestions.deployment_guidance = _generate_fallback_deployment()

	# Generate objective recommendations
	suggestions.objective_recommendations = _generate_objective_recommendations(mission_context)
	if suggestions.objective_recommendations.is_empty():
		push_warning("SetupAssistant: No objectives generated, using fallback")
		suggestions.objective_recommendations = _generate_fallback_objectives()

	# Add special rules and modifiers
	suggestions.special_rules = _determine_special_rules(mission_context)

	# Calculate complexity and time estimates
	_calculate_setup_estimates(suggestions)

	setup_suggestions_ready.emit(suggestions)
	return suggestions

func quick_generate_standard_battlefield() -> SetupSuggestions:
	"""Generate standard patrol battlefield with default settings"""
	var standard_options := {
		"terrain_density": "standard",
		"complexity": "simple",
		"mission_type": "patrol"
	}

	return generate_battlefield_suggestions(null, standard_options)

func regenerate_terrain_only(current_suggestions: SetupSuggestions) -> Array[TerrainSuggestion]:
	"""Regenerate only terrain suggestions, keeping other elements"""
	var mission_context := {
		"terrain_density": "standard",
		"mission_type": current_mission_type
	}

	var new_terrain := _generate_terrain_suggestions(mission_context)
	terrain_generation_complete.emit(_convert_suggestions_to_features(new_terrain))
	return new_terrain

# =====================================================
# TERRAIN GENERATION - FIVE PARSECS RULES IMPLEMENTATION
# =====================================================

func _generate_terrain_suggestions(context: Dictionary) -> Array[TerrainSuggestion]:
	"""Generate terrain per Five Parsecs Core Rules p.67-69"""
	var terrain_suggestions: Array[TerrainSuggestion] = []

	# Determine terrain feature count (Five Parsecs rule: 2d6+2 features)
	var feature_count := _roll_dice_safe("2d6") + 2

	# Apply mission modifiers
	feature_count += context.get("terrain_modifier", 0)
	feature_count = clampi(feature_count, 3, 12) # Reasonable bounds

	# Generate individual terrain features
	for i in feature_count:
		var suggestion := _create_terrain_suggestion(context, i)
		if suggestion:
			terrain_suggestions.append(suggestion)

	# Ensure minimum cover availability (tactical balance)
	_ensure_tactical_balance(terrain_suggestions, context)

	return terrain_suggestions

func _create_terrain_suggestion(context: Dictionary, index: int) -> TerrainSuggestion:
	"""Create individual terrain suggestion following rulebook"""
	var suggestion := TerrainSuggestion.new()
	suggestion.suggestion_id = "terrain_%d_%d" % [index, Time.get_unix_time_from_system()]

	# Roll for terrain type (Five Parsecs table)
	var terrain_roll := _roll_dice_safe("d6")

	match terrain_roll:
		1, 2: # Cover features (33% chance)
			_setup_cover_suggestion(suggestion, context)
		3, 4: # Elevation features (33% chance)
			_setup_elevation_suggestion(suggestion, context)
		5: # Difficult terrain (17% chance)
			_setup_difficult_terrain_suggestion(suggestion, context)
		6: # Special/hazard terrain (17% chance)
			_setup_special_terrain_suggestion(suggestion, context)

	return suggestion

func _setup_cover_suggestion(suggestion: TerrainSuggestion, context: Dictionary) -> void:
	"""Setup cover terrain suggestion with Five Parsecs compliance"""
	suggestion.terrain_type = &"cover"
	suggestion.priority = 1 # Cover is essential for tactical gameplay

	# Randomize cover type
	var cover_types := [
		{
			"visual": "Stone wall or metal barrier",
			"placement": "3-inch straight line providing full cover",
			"models": ["Walls", "Barriers", "Rubble"],
			"effects": ["Blocks line of sight", "Provides cover (+2 to target number)"]
		},
		{
			"visual": "Rock formation or debris pile",
			"placement": "L-shaped formation, 2x2 inch footprint",
			"models": ["Rocks", "Debris", "Ruins"],
			"effects": ["Blocks line of sight", "Can be climbed for elevation"]
		},
		{
			"visual": "Shipping containers or structures",
			"placement": "Rectangular block, 3x2 inch area",
			"models": ["Containers", "Buildings", "Vehicles"],
			"effects": ["Full cover", "May have access points"]
		}
	]

	var cover_type: Dictionary = cover_types[_roll_dice_safe("d3") - 1]
	suggestion.visual_description = cover_type.visual
	suggestion.placement_description = cover_type.placement
	suggestion.suggested_models = cover_type.models
	suggestion.game_effects = cover_type.effects

	# Set appropriate footprint
	suggestion.estimated_footprint = Vector2i(3, 1) if "straight line" in cover_type.placement else Vector2i(2, 2)

func _setup_elevation_suggestion(suggestion: TerrainSuggestion, context: Dictionary) -> void:
	"""Setup elevation terrain per rules"""
	suggestion.terrain_type = &"elevation"
	suggestion.priority = 2 # Recommended for tactical depth

	var elevation_types := [
		{
			"visual": "Hill or raised platform",
			"placement": "2x2 inch elevated area, 1 inch height",
			"models": ["Hills", "Platforms", "Ruins"],
			"effects": ["Height advantage", "Clear line of sight", "Difficult to climb"]
		},
		{
			"visual": "Multi-level structure",
			"placement": "3x3 inch area with varying heights",
			"models": ["Buildings", "Ruins", "Rockpiles"],
			"effects": ["Multiple firing positions", "Complex cover"]
		}
	]

	var elevation_type: Dictionary = elevation_types[_roll_dice_safe("d2") - 1]
	suggestion.visual_description = elevation_type.visual
	suggestion.placement_description = elevation_type.placement
	suggestion.suggested_models = elevation_type.models
	suggestion.game_effects = elevation_type.effects
	suggestion.estimated_footprint = Vector2i(2, 2)

func _setup_difficult_terrain_suggestion(suggestion: TerrainSuggestion, context: Dictionary) -> void:
	"""Setup difficult terrain areas"""
	suggestion.terrain_type = &"difficult"
	suggestion.priority = 3 # Optional tactical element

	var difficult_types := [
		{
			"visual": "Rough ground with debris and obstacles",
			"placement": "2x2 inch area of scattered terrain",
			"models": ["Debris", "Craters", "Vegetation"],
			"effects": ["Halves movement speed", "No cover bonus"]
		},
		{
			"visual": "Marshy or unstable ground",
			"placement": "Irregular 3 inch area",
			"models": ["Swamp", "Mud", "Loose rocks"],
			"effects": ["Movement penalty", "Possible stuck results"]
		}
	]

	var terrain_type: Dictionary = difficult_types[_roll_dice_safe("d2") - 1]
	suggestion.visual_description = terrain_type.visual
	suggestion.placement_description = terrain_type.placement
	suggestion.suggested_models = terrain_type.models
	suggestion.game_effects = terrain_type.effects
	suggestion.estimated_footprint = Vector2i(2, 2)

func _setup_special_terrain_suggestion(suggestion: TerrainSuggestion, context: Dictionary) -> void:
	"""Setup mission-specific or hazardous terrain"""
	suggestion.terrain_type = &"special"
	suggestion.priority = 2 # Mission-relevant

	var mission_type: String = str(context.get("mission_type", "patrol"))

	match mission_type:
		"assault":
			suggestion.visual_description = "Fortified position or bunker"
			suggestion.placement_description = "Central defensive structure"
			suggestion.game_effects = ["Objective location", "Heavy cover", "Multiple firing ports"]
		"investigation":
			suggestion.visual_description = "Archaeological site or crash wreckage"
			suggestion.placement_description = "Scatter of interesting features"
			suggestion.game_effects = ["Investigation points", "Potential loot", "Cover elements"]
		_: # Default to environmental hazard
			suggestion.visual_description = "Environmental hazard or dangerous area"
			suggestion.placement_description = "Marked hazardous zone"
			suggestion.game_effects = ["Area effect", "Movement restriction", "Special rules apply"]

	suggestion.suggested_models = ["Mission-specific", "Objective markers", "Special terrain"]
	suggestion.estimated_footprint = Vector2i(2, 2)

func _ensure_tactical_balance(suggestions: Array[TerrainSuggestion], context: Dictionary) -> void:
	"""Ensure battlefield has proper tactical balance"""
	var cover_count := 0
	var elevation_count := 0

	# Count existing terrain types
	for suggestion in suggestions:
		match suggestion.terrain_type:
			&"cover": cover_count += 1
			&"elevation": elevation_count += 1

	# Ensure minimum cover for tactical gameplay
	if cover_count < 2:
		var additional_cover := TerrainSuggestion.new()
		_setup_cover_suggestion(additional_cover, context)
		additional_cover.priority = 1 # Required
		suggestions.append(additional_cover)

	# Ensure some elevation for tactical depth
	if elevation_count < 1 and suggestions.size() < 8:
		var additional_elevation := TerrainSuggestion.new()
		_setup_elevation_suggestion(additional_elevation, context)
		additional_elevation.priority = 2 # Recommended
		suggestions.append(additional_elevation)

# =====================================================
# DEPLOYMENT GUIDANCE GENERATION
# =====================================================

func _generate_deployment_guidance(context: Dictionary) -> DeploymentGuidance:
	"""Generate deployment zone guidance per Five Parsecs rules"""
	var guidance := DeploymentGuidance.new()

	# Standard deployment zones (Five Parsecs p.70)
	guidance.crew_zone_description = "Western edge: Deploy crew within 4 inches of western board edge"
	guidance.enemy_zone_description = "Eastern edge: Deploy enemies within 4 inches of eastern board edge"

	# Mission-specific modifications
	var mission_type: String = str(context.get("mission_type", "patrol"))
	match mission_type:
		"defense":
			guidance.crew_zone_description = "Central positions: Deploy crew around objective markers"
			guidance.enemy_zone_description = "Board edges: Enemies enter from random board edges"
			guidance.special_deployment_rules.append("Crew deploys first")
			guidance.special_deployment_rules.append("Enemies may have multiple entry points")
		"assault":
			guidance.deployment_restrictions.append("No deployment within 6 inches of objectives")
			guidance.special_deployment_rules.append("Attackers deploy second")
		"investigation":
			guidance.deployment_restrictions.append("No deployment within line of sight at start")
			guidance.special_deployment_rules.append("Hidden deployment recommended")

	# Standard spacing recommendations
	guidance.recommended_spacing = 2 # 2 inches between models
	guidance.deployment_restrictions.append("No deployment within difficult terrain")
	guidance.deployment_restrictions.append("Models must have clear base placement")

	return guidance

# =====================================================
# OBJECTIVE RECOMMENDATIONS
# =====================================================

func _generate_objective_recommendations(context: Dictionary) -> Array[ObjectiveRecommendation]:
	"""Generate objective placement recommendations"""
	var recommendations: Array[ObjectiveRecommendation] = []
	var mission_type: String = str(context.get("mission_type", "patrol"))

	match mission_type:
		"patrol":
			recommendations = _create_patrol_objectives()
		"assault":
			recommendations = _create_assault_objectives()
		"defense":
			recommendations = _create_defense_objectives()
		"investigation":
			recommendations = _create_investigation_objectives()
		_:
			recommendations = _create_default_objectives()

	return recommendations

func _create_patrol_objectives() -> Array[ObjectiveRecommendation]:
	"""Create patrol mission objectives"""
	var objectives: Array[ObjectiveRecommendation] = []

	var obj := ObjectiveRecommendation.new()
	obj.objective_type = &"investigate"
	obj.placement_suggestion = "Center board area, avoid deployment zones"
	obj.victory_condition = "Control objective for 1 full turn"
	obj.required_markers = ["Objective marker", "Investigation token"]
	obj.special_rules = ["Requires action to investigate", "Random event on investigation"]

	objectives.append(obj)
	return objectives

func _create_assault_objectives() -> Array[ObjectiveRecommendation]:
	"""Create assault mission objectives"""
	var objectives: Array[ObjectiveRecommendation] = []

	var obj := ObjectiveRecommendation.new()
	obj.objective_type = &"destroy"
	obj.placement_suggestion = "Enemy deployment zone, defensible position"
	obj.victory_condition = "Destroy target structure or eliminate defenders"
	obj.required_markers = ["Target marker", "Destruction template"]
	obj.special_rules = ["Target has armor value", "Multiple attack methods possible"]

	objectives.append(obj)
	return objectives

func _create_defense_objectives() -> Array[ObjectiveRecommendation]:
	"""Create defense mission objectives"""
	var objectives: Array[ObjectiveRecommendation] = []

	for i: int in range(2): # Multiple defense points
		var obj := ObjectiveRecommendation.new()
		obj.objective_type = &"secure"
		obj.placement_suggestion = "Crew deployment area, key positions"
		obj.victory_condition = "Maintain control until turn 6"
		obj.required_markers = ["Control point marker"]
		obj.special_rules = ["Enemy must capture to win", "Control checked each turn"]
		objectives.append(obj)

	return objectives

func _create_investigation_objectives() -> Array[ObjectiveRecommendation]:
	"""Create investigation mission objectives"""
	var objectives: Array[ObjectiveRecommendation] = []
	var num_sites := _roll_dice_safe("d3") # 1-3 investigation sites

	for i in num_sites:
		var obj := ObjectiveRecommendation.new()
		obj.objective_type = &"investigate"
		obj.placement_suggestion = "Scattered across battlefield, avoid open areas"
		obj.victory_condition = "Successfully investigate %d of %d sites" % [ceili(num_sites * 0.6), num_sites]
		obj.required_markers = ["Investigation site %d" % (i + 1)]
		obj.special_rules = ["Roll for discovery results", "May trigger random events"]
		objectives.append(obj)

	return objectives

func _create_default_objectives() -> Array[ObjectiveRecommendation]:
	"""Create generic objectives for unknown mission types"""
	var objectives: Array[ObjectiveRecommendation] = []

	var obj := ObjectiveRecommendation.new()
	obj.objective_type = &"secure"
	obj.placement_suggestion = "Central battlefield position"
	obj.victory_condition = "Control objective at game end"
	obj.required_markers = ["Generic objective marker"]

	objectives.append(obj)
	return objectives

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _parse_mission_requirements(mission_data: Resource, options: Dictionary) -> Dictionary:
	"""Parse mission data and options into context dictionary"""
	var context := options.duplicate()

	if mission_data:
		# Extract mission type safely
		var mission_type_value = mission_data.mission_type if mission_data else null
		context["mission_type"] = str(mission_type_value) if mission_type_value != null else "patrol"

		# Extract terrain modifier safely
		var terrain_mod_value = mission_data.terrain_modifier if mission_data else null
		context["terrain_modifier"] = int(terrain_mod_value) if terrain_mod_value != null else 0

		# Extract special requirements safely
		var special_req_value = mission_data.special_requirements if mission_data else null
		context["special_requirements"] = special_req_value if special_req_value != null else []

		# Extract environmental effects safely
		var env_effects_value = mission_data.environmental_effects if mission_data else null
		context["environmental_effects"] = env_effects_value if env_effects_value != null else {}

	return context

func _determine_special_rules(context: Dictionary) -> Array[String]:
	"""Determine special rules based on context"""
	var rules: Array[String] = []

	# Mission-specific rules
	var mission_type: String = str(context.get("mission_type", "patrol"))
	match mission_type:
		"assault":
			rules.append("Attacker initiative bonus")
			rules.append("Defensive positions provide extra cover")
		"defense":
			rules.append("Defender deploys first")
			rules.append("Reinforcement rolls each turn")
		"investigation":
			rules.append("Limited visibility at start")
			rules.append("Discovery rolls trigger events")

	# Environmental effects
	var env_effects: Dictionary = context.get("environmental_effects", {})
	if env_effects.has("fog"):
		rules.append("Reduced visibility: Line of sight limited to 12 inches")
	if env_effects.has("rain"):
		rules.append("Movement penalty: All movement -1 inch")

	return rules

func _calculate_setup_estimates(suggestions: SetupSuggestions) -> void:
	"""Calculate setup time and complexity estimates"""
	var terrain_count := suggestions.terrain_suggestions.size()
	var objective_count := suggestions.objective_recommendations.size()

	# Base setup time calculation
	var base_time := 10 # minutes
	var terrain_time := terrain_count * 2 # 2 min per terrain piece
	var objective_time := objective_count * 1 # 1 min per objective

	suggestions.estimated_setup_time = base_time + terrain_time + objective_time

	# Complexity rating
	if terrain_count <= 4 and objective_count <= 1:
		suggestions.complexity_rating = "Simple"
	elif terrain_count <= 8 and objective_count <= 3:
		suggestions.complexity_rating = "Standard"
	else:
		suggestions.complexity_rating = "Complex"

func _convert_suggestions_to_features(suggestions: Array[TerrainSuggestion]) -> Array[BattlefieldTypes.TerrainFeature]:
	"""Convert suggestions to battlefield features for integration"""
	var features: Array[BattlefieldTypes.TerrainFeature] = []

	for suggestion in suggestions:
		var feature := BattlefieldTypes.TerrainFeature.new()
		feature.feature_id = suggestion.suggestion_id
		feature.feature_type = suggestion.terrain_type
		feature.title = suggestion.visual_description
		feature.description = suggestion.placement_description
		feature.special_rules = suggestion.game_effects
		features.append(feature)

	return features

func _generate_fallback_suggestions() -> SetupSuggestions:
	"""Generate minimal fallback suggestions for error cases"""
	var suggestions := SetupSuggestions.new()

	# Minimal terrain setup
	var cover_suggestion := TerrainSuggestion.new()
	cover_suggestion.terrain_type = &"cover"
	cover_suggestion.visual_description = "Simple wall or barrier"
	cover_suggestion.placement_description = "3-inch line across center board"
	cover_suggestion.priority = 1
	suggestions.terrain_suggestions.append(cover_suggestion)

	# Basic deployment guidance
	suggestions.deployment_guidance = DeploymentGuidance.new()
	suggestions.deployment_guidance.crew_zone_description = "Western 4 inches"
	suggestions.deployment_guidance.enemy_zone_description = "Eastern 4 inches"

	# Single objective
	var obj := ObjectiveRecommendation.new()
	obj.objective_type = &"secure"
	obj.placement_suggestion = "Center board"
	suggestions.objective_recommendations.append(obj)

	suggestions.complexity_rating = "Simple"
	suggestions.estimated_setup_time = 10

	return suggestions

func _generate_fallback_terrain() -> Array[TerrainSuggestion]:
	"""Generate a minimal set of terrain suggestions for fallback"""
	var fallback_terrain: Array[TerrainSuggestion] = []

	var cover_suggestion := TerrainSuggestion.new()
	cover_suggestion.terrain_type = &"cover"
	cover_suggestion.visual_description = "Simple wall or barrier"
	cover_suggestion.placement_description = "3-inch line across center board"
	cover_suggestion.priority = 1
	fallback_terrain.append(cover_suggestion)

	return fallback_terrain

func _generate_fallback_deployment() -> DeploymentGuidance:
	"""Generate a minimal deployment guidance for fallback"""
	var fallback_guidance := DeploymentGuidance.new()
	fallback_guidance.crew_zone_description = "Western 4 inches"
	fallback_guidance.enemy_zone_description = "Eastern 4 inches"
	fallback_guidance.recommended_spacing = 2
	fallback_guidance.deployment_restrictions.append("No deployment within difficult terrain")
	fallback_guidance.deployment_restrictions.append("Models must have clear base placement")

	return fallback_guidance

func _generate_fallback_objectives() -> Array[ObjectiveRecommendation]:
	"""Generate a minimal set of objective recommendations for fallback"""
	var fallback_objectives: Array[ObjectiveRecommendation] = []

	var obj := ObjectiveRecommendation.new()
	obj.objective_type = &"secure"
	obj.placement_suggestion = "Center board"
	obj.victory_condition = "Control objective at game end"
	obj.required_markers = ["Generic objective marker"]
	fallback_objectives.append(obj)

	return fallback_objectives

func _roll_dice_safe(pattern: String) -> int:
	"""Safe dice rolling with fallback"""
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice("SetupAssistant", pattern)
	else:
		return _fallback_dice_roll(pattern)

func _fallback_dice_roll(pattern: String) -> int:
	"""Fallback dice implementation"""
	match pattern.to_lower():
		"d2": return randi_range(1, 2)
		"d3": return randi_range(1, 3)
		"d6": return randi_range(1, 6)
		"2d6": return randi_range(1, 6) + randi_range(1, 6)
		_: return randi_range(1, 6)

# =====================================================
# DEPENDENCY INJECTION & CONFIGURATION
# =====================================================

func inject_battlefield_data(data: BattlefieldData) -> void:
	"""Inject battlefield data dependency"""
	battlefield_data = data

func set_battlefield_size(size: Vector2i) -> void:
	"""Configure battlefield dimensions"""
	battlefield_size = size
	_validate_configuration()

func set_mission_type(mission_type: String) -> void:
	"""Set current mission type for context"""
	current_mission_type = mission_type

func add_environmental_condition(condition: String, active: bool) -> void:
	"""Add environmental condition modifier"""
	environmental_conditions[condition] = active

func clear_environmental_conditions() -> void:
	"""Clear all environmental modifiers"""
	environmental_conditions.clear()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return default_value
	if obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return null
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null