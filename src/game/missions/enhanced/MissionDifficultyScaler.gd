@tool
class_name MissionDifficultyScaler
extends RefCounted

## Mission Difficulty Scaling System for Five Parsecs Campaign Manager
##
## Provides dynamic difficulty scaling based on crew experience, equipment, and campaign progression.
## Integrates with existing difficulty data and Five Parsecs balancing principles.

# GlobalEnums available as autoload singleton
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")

# Difficulty data paths - loaded at runtime
const DIFFICULTY_DATA_PATH: String = "res://data/mission_tables/mission_difficulty.json"
static var _difficulty_data: Dictionary = {}

# Difficulty scaling factors
const CREW_EXPERIENCE_WEIGHTS: Dictionary = {
	"rookie": 0.8,
	"regular": 1.0,
	"veteran": 1.2,
	"elite": 1.4
}

const EQUIPMENT_QUALITY_MODIFIERS: Dictionary = {
	"basic": 0.9,
	"standard": 1.0,
	"advanced": 1.1,
	"military": 1.3,
	"exotic": 1.5
}

# Campaign turn modifiers (Five Parsecs progression)
const CAMPAIGN_TURN_SCALING: Array[Dictionary] = [
	{"turn_range": [1, 5], "modifier": 0.7, "description": "Early campaign - reduced difficulty"},
	{"turn_range": [6, 15], "modifier": 1.0, "description": "Mid campaign - standard difficulty"},
	{"turn_range": [16, 30], "modifier": 1.2, "description": "Late campaign - increased difficulty"},
	{"turn_range": [31, 999], "modifier": 1.4, "description": "Extended campaign - high difficulty"}
]

## Load difficulty data if not already loaded
static func _ensure_difficulty_data_loaded() -> void:
	if _difficulty_data.is_empty():
		_difficulty_data = _load_json_safe(DIFFICULTY_DATA_PATH, "difficulty_data")

## Safe JSON loading method (similar to DataManager)
static func _load_json_safe(file_path: String, context: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("MissionDifficultyScaler: Data file not found: " + file_path)
		return {}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("MissionDifficultyScaler: Failed to open file: " + file_path)
		return {}
	
	var text: String = file.get_as_text()
	file.close()
	
	if text.is_empty():
		return {}
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)
	
	if parse_result != OK:
		push_warning("MissionDifficultyScaler: JSON Parse Error in " + file_path)
		return {}
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	
	return data as Dictionary

## Calculate the final difficulty for a mission
static func calculate_mission_difficulty(base_difficulty: int, scaling_context: Dictionary) -> int:
	var final_difficulty: float = base_difficulty
	
	# Apply crew experience scaling
	final_difficulty *= _get_crew_experience_modifier(scaling_context)
	
	# Apply equipment quality scaling
	final_difficulty *= _get_equipment_quality_modifier(scaling_context)
	
	# Apply campaign progression scaling
	final_difficulty *= _get_campaign_progression_modifier(scaling_context)
	
	# Apply mission type specific scaling
	final_difficulty *= _get_mission_type_modifier(scaling_context)
	
	# Apply danger pay scaling (Five Parsecs rule)
	final_difficulty *= _get_danger_pay_modifier(scaling_context)
	
	# Clamp to valid range and round
	return clampi(roundi(final_difficulty), 1, 5)

## Get difficulty description based on final value
static func get_difficulty_description(difficulty: int) -> String:
	match difficulty:
		1: return "Routine - minimal opposition expected"
		2: return "Standard - normal enemy presence"
		3: return "Challenging - significant opposition"
		4: return "Dangerous - heavy enemy forces"
		5: return "Extreme - overwhelming enemy presence"
		_: return "Unknown difficulty level"

## Calculate recommended crew size for difficulty
static func get_recommended_crew_size(difficulty: int, mission_type: int) -> int:
	var base_crew: int = 3 # Five Parsecs standard
	
	# Adjust for difficulty
	match difficulty:
		1, 2: base_crew = 3
		3: base_crew = 4
		4, 5: base_crew = 5
	
	# Adjust for mission type
	var mission_category: MissionTypeRegistry.MissionCategory = MissionTypeRegistry.get_mission_category(mission_type)
	match mission_category:
		MissionTypeRegistry.MissionCategory.PATRON_CONTRACT:
			base_crew -= 1 # Patron missions often allow smaller crews
		MissionTypeRegistry.MissionCategory.OPPORTUNITY:
			base_crew += 1 # Opportunity missions benefit from larger crews
	
	return clampi(base_crew, 2, 6) # Five Parsecs crew size limits

## Calculate enemy deployment points based on difficulty
static func calculate_enemy_deployment_points(difficulty: int, crew_size: int) -> int:
	# Base deployment points from Five Parsecs rules
	var base_points: int = crew_size * 2
	
	# Scale by difficulty
	var difficulty_multiplier: float = 1.0
	match difficulty:
		1: difficulty_multiplier = 0.8
		2: difficulty_multiplier = 1.0
		3: difficulty_multiplier = 1.3
		4: difficulty_multiplier = 1.6
		5: difficulty_multiplier = 2.0
	
	return roundi(base_points * difficulty_multiplier)

## Get difficulty modifiers for specific mission elements
static func get_mission_element_modifiers(difficulty: int) -> Dictionary:
	var modifiers: Dictionary = {
		"enemy_accuracy": 0,
		"enemy_toughness": 0,
		"special_equipment_chance": 0.0,
		"elite_enemy_chance": 0.0,
		"environmental_hazards": false
	}
	
	match difficulty:
		1:
			modifiers.enemy_accuracy = -1
			modifiers.enemy_toughness = -1
			modifiers.special_equipment_chance = 0.1
			modifiers.elite_enemy_chance = 0.0
		2:
			modifiers.enemy_accuracy = 0
			modifiers.enemy_toughness = 0
			modifiers.special_equipment_chance = 0.2
			modifiers.elite_enemy_chance = 0.1
		3:
			modifiers.enemy_accuracy = 0
			modifiers.enemy_toughness = 1
			modifiers.special_equipment_chance = 0.3
			modifiers.elite_enemy_chance = 0.2
			modifiers.environmental_hazards = true
		4:
			modifiers.enemy_accuracy = 1
			modifiers.enemy_toughness = 1
			modifiers.special_equipment_chance = 0.4
			modifiers.elite_enemy_chance = 0.3
			modifiers.environmental_hazards = true
		5:
			modifiers.enemy_accuracy = 1
			modifiers.enemy_toughness = 2
			modifiers.special_equipment_chance = 0.5
			modifiers.elite_enemy_chance = 0.4
			modifiers.environmental_hazards = true
	
	return modifiers

## Validate if crew can handle the mission difficulty
static func validate_crew_capability(difficulty: int, crew_context: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"capable": true,
		"warnings": [],
		"recommendations": []
	}
	
	var crew_size: int = crew_context.get("size", 3)
	var crew_experience: String = crew_context.get("experience_level", "regular")
	var equipment_quality: String = crew_context.get("equipment_quality", "standard")
	
	# Check crew size vs recommended
	var recommended_size: int = get_recommended_crew_size(difficulty, crew_context.get("mission_type", 0))
	if crew_size < recommended_size:
		result.warnings.append("Crew size below recommended (%d vs %d)" % [crew_size, recommended_size])
		if crew_size < recommended_size - 1:
			result.capable = false
	
	# Check experience level
	if difficulty >= 4 and crew_experience in ["rookie"]:
		result.warnings.append("Rookie crew attempting high-difficulty mission")
		result.recommendations.append("Consider gaining more experience first")
	
	# Check equipment quality
	if difficulty >= 3 and equipment_quality in ["basic"]:
		result.warnings.append("Basic equipment may be insufficient")
		result.recommendations.append("Upgrade equipment before attempting")
	
	return result

## Private Methods

static func _get_crew_experience_modifier(context: Dictionary) -> float:
	var experience_level: String = context.get("crew_experience", "regular")
	return CREW_EXPERIENCE_WEIGHTS.get(experience_level, 1.0)

static func _get_equipment_quality_modifier(context: Dictionary) -> float:
	var equipment_quality: String = context.get("equipment_quality", "standard")
	return EQUIPMENT_QUALITY_MODIFIERS.get(equipment_quality, 1.0)

static func _get_campaign_progression_modifier(context: Dictionary) -> float:
	var campaign_turn: int = context.get("campaign_turn", 10)
	
	for turn_data in CAMPAIGN_TURN_SCALING:
		var turn_range: Array = turn_data.turn_range
		if campaign_turn >= turn_range[0] and campaign_turn <= turn_range[1]:
			return turn_data.modifier
	
	return 1.0

static func _get_mission_type_modifier(context: Dictionary) -> float:
	var mission_type: int = context.get("mission_type", MissionTypeRegistry.EnhancedMissionType.RED_ZONE)
	
	# Ensure difficulty data is loaded
	_ensure_difficulty_data_loaded()
	
	# Mission type difficulty modifiers from existing data
	for rule in _difficulty_data.get("modifiers", []):
		if rule.type == "mission_type_modifier":
			var type_string: String = _convert_mission_type_to_string(mission_type)
			return rule.params.get(type_string, 1.0)
	
	# Enhanced mission type modifiers
	match mission_type:
		MissionTypeRegistry.EnhancedMissionType.DELIVERY: return 0.9
		MissionTypeRegistry.EnhancedMissionType.ESCORT: return 1.0
		MissionTypeRegistry.EnhancedMissionType.INVESTIGATION: return 0.8
		MissionTypeRegistry.EnhancedMissionType.BOUNTY_HUNTING: return 1.2
		MissionTypeRegistry.EnhancedMissionType.RAID: return 1.3
		MissionTypeRegistry.EnhancedMissionType.PURSUIT: return 1.1
		MissionTypeRegistry.EnhancedMissionType.DEFENDING: return 1.0
		_: return 1.0

static func _get_danger_pay_modifier(context: Dictionary) -> float:
	var danger_pay: int = context.get("danger_pay", 0)
	
	# Five Parsecs danger pay scaling: +1 difficulty per danger pay level
	return 1.0 + (danger_pay * 0.2)

static func _convert_mission_type_to_string(mission_type: int) -> String:
	match mission_type:
		MissionTypeRegistry.EnhancedMissionType.RED_ZONE: return "RED_ZONE"
		MissionTypeRegistry.EnhancedMissionType.BLACK_ZONE: return "BLACK_ZONE"
		MissionTypeRegistry.EnhancedMissionType.PATRON: return "PATRON"
		_: return "RED_ZONE"