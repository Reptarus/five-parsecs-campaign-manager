extends RefCounted
class_name BaseMissionGenerationSystem

## Base Mission Generation System
## Unified mission generation logic without UI dependencies
## Consolidates functionality from FPCM_MissionGenerator, FiveParsecsMissionGenerator, and enhanced mission components
## Part of Phase 3A Mission Generation Consolidation

# Safe imports
# GlobalEnums available as autoload singleton
const Mission = preload("res://src/core/systems/Mission.gd")
const MissionObjective = preload("res://src/core/mission/MissionObjective.gd")
const GameState = preload("res://src/core/state/GameState.gd")

# Mission generation modes
enum GenerationMode {
	BASIC,
	FIVE_PARSECS,
	ENHANCED,
	CUSTOM
}

# Mission generation signals (to be connected by UI components)
signal mission_generated(mission: Mission)
signal mission_batch_generated(missions: Array[Mission])
signal generation_failed(error: String)
signal mission_validation_failed(reason: String)

# Core mission generation data
var current_mode: GenerationMode = GenerationMode.FIVE_PARSECS
var mission_templates: Array[Dictionary] = []
var mission_count: int = 0
var current_difficulty: int = 1
var campaign_turn: int = 1

# Five Parsecs mission data
var mission_types: Array[String] = [
	"Patrol", "Salvage", "Trade", "Exploration", "Pursuit",
	"Defending", "Opportunity", "Raid", "Investigation", "Delivery"
]

var deployment_conditions: Array[String] = [
	"Standard", "Delayed", "Rushed", "Stealth", "Assault"
]

var special_rules: Array[String] = [
	"NIGHT_FIGHTING", "ENVIRONMENTAL_HAZARD", "TIME_LIMIT",
	"RIVAL_PRESENCE", "CIVILIAN_PRESENCE", "VALUABLE_CARGO"
]

# Enhanced mission generation data
var difficulty_scaling_enabled: bool = true
var reward_calculation_enabled: bool = true
var mission_registry_enabled: bool = true

# Difficulty scaling factors
var crew_experience_weights: Dictionary = {
	"rookie": 0.8,
	"regular": 1.0,
	"veteran": 1.2,
	"elite": 1.4
}

var equipment_quality_modifiers: Dictionary = {
	"basic": 0.9,
	"standard": 1.0,
	"advanced": 1.1,
	"military": 1.3,
	"exotic": 1.5
}

# Campaign turn scaling
var campaign_turn_scaling: Array[Dictionary] = [
	{"turn_range": [1, 5], "modifier": 0.7, "description": "Early campaign - reduced difficulty"},
	{"turn_range": [6, 15], "modifier": 1.0, "description": "Mid campaign - standard difficulty"},
	{"turn_range": [16, 30], "modifier": 1.2, "description": "Late campaign - increased difficulty"},
	{"turn_range": [31, 999], "modifier": 1.4, "description": "Extended campaign - high difficulty"}
]

func _init() -> void:
	_initialize_mission_system()

func _initialize_mission_system() -> void:
	"""Initialize mission generation system"""
	_initialize_basic_templates()
	_initialize_five_parsecs_data()

func _initialize_basic_templates() -> void:
	"""Initialize basic mission templates for fallback mode"""
	mission_templates = [
		{
			"type": "patrol",
			"difficulty": 1,
			"rewards": {"credits": 1000},
			"description": "Patrol the designated area"
		},
		{
			"type": "rescue",
			"difficulty": 2,
			"rewards": {"credits": 1500},
			"description": "Rescue the target"
		},
		{
			"type": "escort",
			"difficulty": 2,
			"rewards": {"credits": 1200},
			"description": "Escort convoy safely"
		},
		{
			"type": "sabotage",
			"difficulty": 3,
			"rewards": {"credits": 2000},
			"description": "Sabotage enemy facility"
		},
		{
			"type": "exploration",
			"difficulty": 1,
			"rewards": {"credits": 800},
			"description": "Explore unknown area"
		}
	]

func _initialize_five_parsecs_data() -> void:
	"""Initialize Five Parsecs specific data"""
	# Additional initialization if needed

## Core Mission Generation Methods

func setup_mission_generator(mode: GenerationMode = GenerationMode.FIVE_PARSECS, campaign_state: Dictionary = {}) -> bool:
	"""Setup mission generator with specified mode"""
	current_mode = mode
	
	# Update campaign state
	if campaign_state.has("turn"):
		campaign_turn = campaign_state.get("turn", 1)
	if campaign_state.has("difficulty"):
		current_difficulty = campaign_state.get("difficulty", 1)
	
	# Setup mode-specific features
	match current_mode:
		GenerationMode.ENHANCED:
			_setup_enhanced_mode()
		GenerationMode.CUSTOM:
			_setup_custom_mode()
		GenerationMode.BASIC:
			_setup_basic_mode()
		_:
			_setup_five_parsecs_mode()
	
	return true

func _setup_basic_mode() -> void:
	"""Setup basic mission generation mode"""
	difficulty_scaling_enabled = false
	reward_calculation_enabled = false
	mission_registry_enabled = false

func _setup_five_parsecs_mode() -> void:
	"""Setup Five Parsecs mission generation mode"""
	difficulty_scaling_enabled = true
	reward_calculation_enabled = true
	mission_registry_enabled = false

func _setup_enhanced_mode() -> void:
	"""Setup enhanced mission generation mode with all features"""
	difficulty_scaling_enabled = true
	reward_calculation_enabled = true
	mission_registry_enabled = true

func _setup_custom_mode() -> void:
	"""Setup custom mission generation mode"""
	# Custom mode allows selective feature enabling
	pass

## Mission Generation Methods

func generate_mission(mission_type: String = "", difficulty_override: int = -1) -> Mission:
	"""Generate a single mission based on current mode"""
	match current_mode:
		GenerationMode.BASIC:
			return _generate_basic_mission(mission_type, difficulty_override)
		GenerationMode.ENHANCED:
			return _generate_enhanced_mission(mission_type, difficulty_override)
		GenerationMode.CUSTOM:
			return _generate_custom_mission(mission_type, difficulty_override)
		_:
			return _generate_five_parsecs_mission(mission_type, difficulty_override)

func generate_mission_batch(count: int = 3, mission_types: Array[String] = []) -> Array[Mission]:
	"""Generate multiple missions at once"""
	var missions: Array[Mission] = []
	
	for i in range(count):
		var mission_type = ""
		if not mission_types.is_empty() and i < mission_types.size():
			mission_type = mission_types[i]
		
		var mission = generate_mission(mission_type)
		missions.append(mission)
	
	mission_batch_generated.emit(missions)
	return missions

func _generate_basic_mission(mission_type: String = "", difficulty_override: int = -1) -> Mission:
	"""Generate basic mission using templates"""
	var template = _get_basic_template(mission_type)
	var mission = Mission.new()
	
	# Set basic properties
	mission.mission_id = "mission_" + str(mission_count)
	mission.mission_title = template.get("type", "Unknown").capitalize() + " Mission"
	mission.mission_description = template.get("description", "Complete the mission objective")
	mission.mission_type = _get_mission_type_enum(template.get("type", "patrol"))
	mission.mission_difficulty = difficulty_override if difficulty_override > 0 else template.get("difficulty", 1)
	mission.reward_credits = template.get("rewards", {}).get("credits", 1000)
	
	mission_count += 1
	mission_generated.emit(mission)
	return mission

func _generate_five_parsecs_mission(mission_type: String = "", difficulty_override: int = -1) -> Mission:
	"""Generate Five Parsecs specific mission"""
	var mission = Mission.new()
	
	# Set mission ID and count
	mission.mission_id = "fp_mission_" + str(mission_count)
	mission_count += 1
	
	# Set basic mission properties
	mission.mission_type = _get_random_five_parsecs_mission_type(mission_type)
	mission.mission_difficulty = difficulty_override if difficulty_override > 0 else current_difficulty
	
	# Apply difficulty scaling if enabled
	if difficulty_scaling_enabled:
		mission.mission_difficulty = _apply_difficulty_scaling(mission.mission_difficulty)
	
	# Generate mission details
	_generate_five_parsecs_mission_name(mission)
	_generate_five_parsecs_objectives(mission)
	_generate_five_parsecs_rewards(mission)
	_add_five_parsecs_special_rules(mission)
	
	mission_generated.emit(mission)
	return mission

func _generate_enhanced_mission(mission_type: String = "", difficulty_override: int = -1) -> Mission:
	"""Generate enhanced mission with all features"""
	var mission = _generate_five_parsecs_mission(mission_type, difficulty_override)
	
	# Add enhanced features
	if reward_calculation_enabled:
		_enhance_mission_rewards(mission)
	
	if mission_registry_enabled:
		_register_mission_in_registry(mission)
	
	return mission

func _generate_custom_mission(mission_type: String = "", difficulty_override: int = -1) -> Mission:
	"""Generate custom mission based on configuration"""
	# For now, use Five Parsecs generation with custom settings
	return _generate_five_parsecs_mission(mission_type, difficulty_override)

## Five Parsecs Mission Generation Details

func _get_random_five_parsecs_mission_type(preferred_type: String = "") -> int:
	"""Get random Five Parsecs mission type or use preferred"""
	if not preferred_type.is_empty():
		return _get_mission_type_enum(preferred_type)
	
	# Random selection from Five Parsecs mission types
	var random_index = randi() % mission_types.size()
	return _get_mission_type_enum(mission_types[random_index].to_lower())

func _generate_five_parsecs_mission_name(mission: Mission) -> void:
	"""Generate Five Parsecs style mission name"""
	var prefixes = ["Operation", "Mission", "Assignment", "Contract", "Task"]
	var suffixes = ["Alpha", "Beta", "Gamma", "Prime", "Storm", "Shadow", "Dawn", "Dusk"]
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	mission.mission_title = prefix + " " + suffix

func _generate_five_parsecs_objectives(mission: Mission) -> void:
	"""Generate objectives based on Five Parsecs mission type"""
	# Primary objective based on mission type
	var primary_description = _get_primary_objective_description(mission.mission_type)
	mission.mission_description = primary_description
	
	# For now, store objectives in mission description
	# Future enhancement: use proper MissionObjective system

func _get_primary_objective_description(mission_type: int) -> String:
	"""Get primary objective description for mission type"""
	match mission_type:
		GlobalEnums.MissionType.PATROL:
			return "Patrol the designated area and eliminate threats"
		GlobalEnums.MissionType.SABOTAGE:
			return "Sabotage the target facility and extract"
		GlobalEnums.MissionType.ESCORT:
			return "Escort convoy to destination safely"
		GlobalEnums.MissionType.RESCUE:
			return "Rescue the target and extract safely"
		GlobalEnums.MissionObjective.EXPLORE:
			return "Explore the unknown area and report findings"
		GlobalEnums.MissionType.DEFENSE:
			return "Defend the position against enemy assault"
		_:
			return "Complete the assigned objective"

func _generate_five_parsecs_rewards(mission: Mission) -> void:
	"""Generate rewards based on Five Parsecs rules"""
	var base_reward = 1000 + (mission.mission_difficulty * 500)
	
	# Apply reward calculation if enabled
	if reward_calculation_enabled:
		base_reward = _calculate_enhanced_rewards(mission, base_reward)
	
	mission.reward_credits = base_reward

func _add_five_parsecs_special_rules(mission: Mission) -> void:
	"""Add special rules to Five Parsecs mission"""
	# Add deployment condition
	var deployment = deployment_conditions[randi() % deployment_conditions.size()]
	
	# Add special rule based on difficulty
	var special_rule = ""
	if mission.mission_difficulty >= 3:
		special_rule = special_rules[randi() % special_rules.size()]
	
	# Store in mission description for now
	if not deployment.is_empty() or not special_rule.is_empty():
		mission.mission_description += "\n\nDeployment: " + deployment
		if not special_rule.is_empty():
			mission.mission_description += "\nSpecial Rule: " + special_rule

## Enhanced Mission Features

func _apply_difficulty_scaling(base_difficulty: int) -> int:
	"""Apply difficulty scaling based on campaign state"""
	var scaled_difficulty = float(base_difficulty)
	
	# Apply campaign turn scaling
	scaled_difficulty *= _get_campaign_turn_modifier()
	
	# Apply crew experience modifier (placeholder - would need crew data)
	scaled_difficulty *= crew_experience_weights.get("regular", 1.0)
	
	# Apply equipment modifier (placeholder - would need equipment data)
	scaled_difficulty *= equipment_quality_modifiers.get("standard", 1.0)
	
	return int(clampf(scaled_difficulty, 1.0, 5.0))

func _get_campaign_turn_modifier() -> float:
	"""Get difficulty modifier based on campaign turn"""
	for scaling_data in campaign_turn_scaling:
		var turn_range = scaling_data.get("turn_range", [1, 999])
		if campaign_turn >= turn_range[0] and campaign_turn <= turn_range[1]:
			return scaling_data.get("modifier", 1.0)
	
	return 1.0

func _calculate_enhanced_rewards(mission: Mission, base_reward: int) -> int:
	"""Calculate enhanced rewards using advanced algorithms"""
	var enhanced_reward = base_reward
	
	# Difficulty multiplier
	enhanced_reward = int(enhanced_reward * (1.0 + (mission.mission_difficulty - 1) * 0.5))
	
	# Mission type multiplier
	match mission.mission_type:
		GlobalEnums.MissionType.SABOTAGE, GlobalEnums.MissionType.RESCUE:
			enhanced_reward = int(enhanced_reward * 1.3) # High-risk missions
		GlobalEnums.MissionType.PATROL:
			enhanced_reward = int(enhanced_reward * 0.9) # Lower-risk missions
	
	return enhanced_reward

func _enhance_mission_rewards(mission: Mission) -> void:
	"""Add enhanced reward calculation to mission"""
	# Already handled in _generate_five_parsecs_rewards if enabled
	pass

func _register_mission_in_registry(mission: Mission) -> void:
	"""Register mission in mission type registry"""
	# Placeholder for mission registry integration
	print("Mission registered: ", mission.mission_title)

## Helper Methods

func _get_basic_template(mission_type: String) -> Dictionary:
	"""Get basic mission template"""
	if mission_type.is_empty():
		return mission_templates[randi() % mission_templates.size()]
	
	for template in mission_templates:
		if template.get("type", "") == mission_type.to_lower():
			return template
	
	return mission_templates[0] # fallback

func _get_mission_type_enum(type_string: String) -> int:
	"""Convert mission type string to enum value"""
	match type_string.to_lower():
		"patrol":
			return GlobalEnums.MissionType.PATROL
		"sabotage":
			return GlobalEnums.MissionType.SABOTAGE
		"escort":
			return GlobalEnums.MissionType.ESCORT
		"rescue":
			return GlobalEnums.MissionType.RESCUE
		"exploration":
			return GlobalEnums.MissionObjective.EXPLORE
		"defense", "defending":
			return GlobalEnums.MissionType.DEFENSE
		"trade":
			return GlobalEnums.MissionType.PATRON # Map to patron
		"salvage":
			return GlobalEnums.MissionType.SABOTAGE # Map to sabotage
		"investigation":
			return GlobalEnums.MissionObjective.EXPLORE # Map to exploration
		"delivery":
			return GlobalEnums.MissionType.ESCORT # Map to escort
		_:
			return GlobalEnums.MissionType.PATROL

## Mission Validation

func validate_mission(mission: Mission) -> Dictionary:
	"""Validate mission data"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate basic properties
	if mission.mission_title.strip_edges().is_empty():
		errors.append("Mission title cannot be empty")
	
	if mission.mission_description.strip_edges().is_empty():
		warnings.append("Mission description is empty")
	
	if mission.mission_difficulty < 1 or mission.mission_difficulty > 5:
		errors.append("Mission difficulty must be between 1 and 5")
	
	if mission.reward_credits < 0:
		errors.append("Mission rewards cannot be negative")
	
	var is_valid = errors.is_empty()
	if not is_valid:
		mission_validation_failed.emit("Mission validation failed: " + str(errors))
	
	return {
		"is_valid": is_valid,
		"errors": errors,
		"warnings": warnings
	}

## Configuration Methods

func set_difficulty(difficulty: int) -> void:
	"""Set current difficulty level"""
	current_difficulty = clampi(difficulty, 1, 5)

func set_campaign_turn(turn: int) -> void:
	"""Set current campaign turn"""
	campaign_turn = maxi(turn, 1)

func enable_difficulty_scaling(enabled: bool) -> void:
	"""Enable or disable difficulty scaling"""
	difficulty_scaling_enabled = enabled

func enable_reward_calculation(enabled: bool) -> void:
	"""Enable or disable enhanced reward calculation"""
	reward_calculation_enabled = enabled

func enable_mission_registry(enabled: bool) -> void:
	"""Enable or disable mission registry"""
	mission_registry_enabled = enabled

## Data Access Methods

func get_available_mission_types() -> Array[String]:
	"""Get all available mission types"""
	match current_mode:
		GenerationMode.BASIC:
			return mission_templates.map(func(template): return template.get("type", "unknown"))
		_:
			return mission_types

func get_current_difficulty() -> int:
	"""Get current difficulty level"""
	return current_difficulty

func get_campaign_turn() -> int:
	"""Get current campaign turn"""
	return campaign_turn

func get_generation_mode() -> GenerationMode:
	"""Get current generation mode"""
	return current_mode

func get_mission_count() -> int:
	"""Get total generated mission count"""
	return mission_count

func get_system_status() -> Dictionary:
	"""Get mission generation system status"""
	return {
		"mode": current_mode,
		"difficulty": current_difficulty,
		"campaign_turn": campaign_turn,
		"mission_count": mission_count,
		"difficulty_scaling_enabled": difficulty_scaling_enabled,
		"reward_calculation_enabled": reward_calculation_enabled,
		"mission_registry_enabled": mission_registry_enabled
	}

## Safe utility methods
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object:
		if obj.has_method("get"):
			var value = obj.get(property)
			return value if value != null else default_value
		else:
			return default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null