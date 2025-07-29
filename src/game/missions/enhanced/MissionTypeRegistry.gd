@tool
class_name MissionTypeRegistry
extends RefCounted

## Enhanced Mission Type Registry for Five Parsecs Campaign Manager
##
## Provides centralized management and generation of mission types with full Five Parsecs integration.
## Built on existing Mission base class and leverages current JSON data structure.

# GlobalEnums available as autoload singleton
const Mission = preload("res://src/core/systems/Mission.gd")

# Static typing for performance
static var _mission_type_cache: Dictionary = {}
static var _mission_data_loaded: bool = false

# Load JSON data as const for performance - using existing data structure
const MISSION_TYPES_DATA: Dictionary = preload("res://data/mission_tables/mission_types.json")
const MISSION_DIFFICULTY_DATA: Dictionary = preload("res://data/mission_tables/mission_difficulty.json")
const MISSION_REWARDS_DATA: Dictionary = preload("res://data/mission_tables/mission_rewards.json")

# Enhanced mission type constants
enum EnhancedMissionType {
	# Existing types (maintain compatibility)
	RED_ZONE = 0,
	BLACK_ZONE = 1,
	PATRON = 2,
	
	# New Five Parsecs-specific types
	DELIVERY = 10,
	BOUNTY_HUNTING = 11,
	ESCORT = 12,
	INVESTIGATION = 13,
	RAID = 20,
	PURSUIT = 21,
	DEFENDING = 22
}

# Mission category classification
enum MissionCategory {
	PATRON_CONTRACT = 0,
	OPPORTUNITY = 1,
	SPECIAL_OPERATION = 2
}

## Initialize the registry and load all mission data
static func initialize() -> void:
	if _mission_data_loaded:
		return
		
	_load_mission_type_data()
	_mission_data_loaded = true

## Generate a mission based on campaign context
static func generate_mission(context: Dictionary) -> Mission:
	initialize()
	
	var mission_type: int = _determine_mission_type(context)
	var mission_data: Dictionary = get_mission_type_data(mission_type)
	var mission: Mission = _create_mission_instance(mission_type, mission_data, context)
	
	return mission

## Get mission type data with validation
static func get_mission_type_data(mission_type: int) -> Dictionary:
	initialize()
	
	if _mission_type_cache.has(mission_type):
		return _mission_type_cache[mission_type]
	
	# Fallback to base mission types for compatibility
	var base_data: Dictionary = _get_base_mission_data(mission_type)
	_mission_type_cache[mission_type] = base_data
	return base_data

## Check if mission type is available based on campaign phase and crew capabilities
static func is_mission_type_available(mission_type: int, campaign_phase: String, crew_capabilities: Dictionary) -> bool:
	var mission_data: Dictionary = get_mission_type_data(mission_type)
	
	# Check phase requirements
	if not _check_phase_requirements(mission_type, campaign_phase):
		return false
	
	# Check crew capabilities
	if not _check_crew_requirements(mission_data, crew_capabilities):
		return false
	
	return true

## Get all available mission types for current context
static func get_available_mission_types(context: Dictionary) -> Array[int]:
	initialize()
	
	var available: Array[int] = []
	var campaign_phase: String = context.get("campaign_phase", "MID_GAME")
	var crew_capabilities: Dictionary = context.get("crew_capabilities", {})
	
	# Check standard mission types
	for entry in MISSION_TYPES_DATA.entries:
		var mission_type: int = _convert_string_to_enum(entry.result.type)
		if is_mission_type_available(mission_type, campaign_phase, crew_capabilities):
			available.append(mission_type)
	
	# Check enhanced mission types
	for enhanced_type in EnhancedMissionType.values():
		if enhanced_type >= 10 and is_mission_type_available(enhanced_type, campaign_phase, crew_capabilities):
			available.append(enhanced_type)
	
	return available

## Get mission category for a mission type
static func get_mission_category(mission_type: int) -> MissionCategory:
	match mission_type:
		EnhancedMissionType.DELIVERY, EnhancedMissionType.BOUNTY_HUNTING, EnhancedMissionType.ESCORT, EnhancedMissionType.INVESTIGATION:
			return MissionCategory.PATRON_CONTRACT
		EnhancedMissionType.RAID, EnhancedMissionType.PURSUIT, EnhancedMissionType.DEFENDING:
			return MissionCategory.OPPORTUNITY
		_:
			return MissionCategory.SPECIAL_OPERATION

## Private Methods

static func _load_mission_type_data() -> void:
	# Cache existing mission types
	for entry in MISSION_TYPES_DATA.entries:
		var mission_type: int = _convert_string_to_enum(entry.result.type)
		_mission_type_cache[mission_type] = entry.result

static func _determine_mission_type(context: Dictionary) -> int:
	var available_types: Array[int] = get_available_mission_types(context)
	
	if available_types.is_empty():
		return EnhancedMissionType.RED_ZONE  # Fallback
	
	# Use weighted selection based on context
	var weights: Array[float] = []
	for mission_type in available_types:
		weights.append(_calculate_mission_weight(mission_type, context))
	
	return _weighted_random_selection(available_types, weights)

static func _create_mission_instance(mission_type: int, mission_data: Dictionary, context: Dictionary) -> Mission:
	var mission: Mission = Mission.new()
	
	# Set basic properties
	mission.mission_type = mission_type
	mission.mission_title = mission_data.get("name", "Unknown Mission")
	mission.mission_description = mission_data.get("description", "No description available")
	mission.mission_difficulty = _calculate_final_difficulty(mission_data, context)
	mission.reward_credits = _calculate_base_rewards(mission_data, context)
	
	# Set advanced properties
	if mission_data.has("special_rules"):
		mission.advanced_rules["special_rules"] = mission_data.special_rules
	
	return mission

static func _get_base_mission_data(mission_type: int) -> Dictionary:
	# Enhanced mission types - provide default data
	match mission_type:
		EnhancedMissionType.DELIVERY:
			return {
				"name": "Delivery Mission",
				"description": "Transport cargo safely to the destination",
				"base_difficulty": 2,
				"reward_multiplier": 1.1,
				"available_objectives": ["TRANSPORT", "PROTECT", "DELIVER"],
				"special_rules": ["cargo_protection", "time_pressure"],
				"required_skills": ["pilot"],
				"category": "patron_contract"
			}
		EnhancedMissionType.BOUNTY_HUNTING:
			return {
				"name": "Bounty Hunt",
				"description": "Capture or eliminate a specific target",
				"base_difficulty": 3,
				"reward_multiplier": 1.3,
				"available_objectives": ["LOCATE", "CAPTURE", "ELIMINATE"],
				"special_rules": ["target_specific", "bounty_rules"],
				"required_skills": ["combat"],
				"category": "patron_contract"
			}
		EnhancedMissionType.ESCORT:
			return {
				"name": "Escort Mission",
				"description": "Protect a VIP during travel",
				"base_difficulty": 2,
				"reward_multiplier": 1.2,
				"available_objectives": ["PROTECT", "ESCORT", "DEFEND"],
				"special_rules": ["vip_protection", "movement_restrictions"],
				"required_skills": ["combat", "tech"],
				"category": "patron_contract"
			}
		EnhancedMissionType.INVESTIGATION:
			return {
				"name": "Investigation",
				"description": "Gather intelligence and uncover secrets",
				"base_difficulty": 2,
				"reward_multiplier": 1.0,
				"available_objectives": ["INVESTIGATE", "GATHER_INTEL", "INFILTRATE"],
				"special_rules": ["stealth_preferred", "information_gathering"],
				"required_skills": ["savvy"],
				"category": "patron_contract"
			}
		EnhancedMissionType.RAID:
			return {
				"name": "Raid Mission",
				"description": "Assault a target location for loot and glory",
				"base_difficulty": 3,
				"reward_multiplier": 1.4,
				"available_objectives": ["ASSAULT", "LOOT", "DESTROY"],
				"special_rules": ["aggressive_approach", "loot_focused"],
				"required_skills": ["combat"],
				"category": "opportunity"
			}
		EnhancedMissionType.PURSUIT:
			return {
				"name": "Pursuit Mission", 
				"description": "Chase down fleeing enemies across multiple locations",
				"base_difficulty": 3,
				"reward_multiplier": 1.2,
				"available_objectives": ["PURSUE", "CAPTURE", "INTERCEPT"],
				"special_rules": ["multi_location", "time_critical"],
				"required_skills": ["pilot", "combat"],
				"category": "opportunity"
			}
		EnhancedMissionType.DEFENDING:
			return {
				"name": "Defense Mission",
				"description": "Hold a position against incoming attacks",
				"base_difficulty": 2,
				"reward_multiplier": 1.1,
				"available_objectives": ["DEFEND", "HOLD_POSITION", "REPEL"],
				"special_rules": ["defensive_tactics", "fortifications"],
				"required_skills": ["combat", "tech"],
				"category": "opportunity"
			}
		_:
			return MISSION_TYPES_DATA.get("default_result", {})

static func _check_phase_requirements(mission_type: int, campaign_phase: String) -> bool:
	# Check validation rules from existing data
	for rule in MISSION_TYPES_DATA.get("validation_rules", []):
		if rule.type == "phase_requirement":
			var phase_data: Dictionary = rule.params.get(campaign_phase, {})
			var allowed_types: Array = phase_data.get("allowed_types", [])
			
			if not allowed_types.is_empty():
				var type_string: String = _convert_enum_to_string(mission_type)
				return type_string in allowed_types
	
	# Enhanced types availability based on campaign phase
	match campaign_phase:
		"EARLY_GAME":
			return mission_type in [EnhancedMissionType.RED_ZONE, EnhancedMissionType.DELIVERY, EnhancedMissionType.ESCORT]
		"MID_GAME":
			return mission_type not in [EnhancedMissionType.RAID, EnhancedMissionType.PURSUIT]
		"LATE_GAME":
			return true
		_:
			return true

static func _check_crew_requirements(mission_data: Dictionary, crew_capabilities: Dictionary) -> bool:
	var required_skills: Array = mission_data.get("required_skills", [])
	var crew_skills: Array = crew_capabilities.get("skills", [])
	
	for skill in required_skills:
		if not skill in crew_skills:
			return false
	
	return true

static func _calculate_mission_weight(mission_type: int, context: Dictionary) -> float:
	var base_weight: float = 1.0
	var mission_data: Dictionary = get_mission_type_data(mission_type)
	
	# Adjust weight based on campaign phase
	var campaign_phase: String = context.get("campaign_phase", "MID_GAME")
	match campaign_phase:
		"EARLY_GAME":
			if mission_type in [EnhancedMissionType.DELIVERY, EnhancedMissionType.ESCORT]:
				base_weight *= 1.5
		"LATE_GAME":
			if mission_type in [EnhancedMissionType.RAID, EnhancedMissionType.PURSUIT]:
				base_weight *= 1.3
	
	# Adjust based on crew preferences
	var crew_preferences: Dictionary = context.get("crew_preferences", {})
	if crew_preferences.has("mission_category"):
		var preferred_category: MissionCategory = crew_preferences.mission_category
		if get_mission_category(mission_type) == preferred_category:
			base_weight *= 1.2
	
	return base_weight

static func _weighted_random_selection(options: Array[int], weights: Array[float]) -> int:
	var total_weight: float = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for i in range(options.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			return options[i]
	
	return options[-1] if not options.is_empty() else EnhancedMissionType.RED_ZONE

static func _calculate_final_difficulty(mission_data: Dictionary, context: Dictionary) -> int:
	var base_difficulty: int = mission_data.get("base_difficulty", 1)
	var campaign_phase: String = context.get("campaign_phase", "MID_GAME")
	
	# Apply phase modifiers from existing data
	for rule in MISSION_TYPES_DATA.get("validation_rules", []):
		if rule.type == "phase_requirement":
			var phase_data: Dictionary = rule.params.get(campaign_phase, {})
			var modifier: float = phase_data.get("difficulty_modifier", 1.0)
			base_difficulty = int(base_difficulty * modifier)
	
	return clampi(base_difficulty, 1, 5)

static func _calculate_base_rewards(mission_data: Dictionary, context: Dictionary) -> int:
	var base_credits: int = 200
	var difficulty: int = mission_data.get("base_difficulty", 1)
	var multiplier: float = mission_data.get("reward_multiplier", 1.0)
	
	return int((base_credits + (difficulty * 100)) * multiplier)

static func _convert_string_to_enum(type_string: String) -> int:
	match type_string:
		"RED_ZONE": return EnhancedMissionType.RED_ZONE
		"BLACK_ZONE": return EnhancedMissionType.BLACK_ZONE
		"PATRON": return EnhancedMissionType.PATRON
		_: return EnhancedMissionType.RED_ZONE

static func _convert_enum_to_string(mission_type: int) -> String:
	match mission_type:
		EnhancedMissionType.RED_ZONE: return "RED_ZONE"
		EnhancedMissionType.BLACK_ZONE: return "BLACK_ZONE"
		EnhancedMissionType.PATRON: return "PATRON"
		_: return "RED_ZONE"