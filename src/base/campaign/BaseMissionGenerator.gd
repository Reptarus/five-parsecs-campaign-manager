@tool
extends Resource

signal mission_generated(mission_data: Dictionary)
signal mission_completed(mission_data: Dictionary, success: bool)

# DataManager for JSON data loading
const DataManager = preload("res://src/core/data/DataManager.gd")

# JSON data loaded from data/ directory
var mission_types_data: Dictionary = {}
var difficulty_settings_data: Dictionary = {}
var reward_tables_data: Dictionary = {}

# Fallback hardcoded data (maintained for backward compatibility)
var difficulty_levels: Dictionary = {
	0: "Tutorial",
	1: "Easy",
	2: "Normal",
	3: "Hard",
	4: "Very Hard",
	5: "Extreme"
}

var mission_types: Dictionary = {
	0: "Combat",
	1: "Exploration",
	2: "Retrieval",
	3: "Escort",
	4: "Defense",
	5: "Sabotage",
	6: "Assassination",
	7: "Rescue",
	8: "Infiltration",
	9: "Investigation"
}

func _init() -> void:
	"""Initialize mission generator with JSON data"""
	_load_mission_data()

func _load_mission_data() -> void:
	"""Load mission data from JSON files"""
	# DataManager is static, use direct static calls
	
	# Load mission types data
	mission_types_data = DataManager._load_json_safe("res://data/missions/mission_types.json", "BaseMissionGenerator")
	if mission_types_data.is_empty():
		print("BaseMissionGenerator: mission_types.json not found, using fallback data")
		_create_mission_types_fallback()
	else:
		print("BaseMissionGenerator: Loaded %d mission categories from JSON" % mission_types_data.get("mission_categories", []).size())
	
	# Load difficulty settings data
	difficulty_settings_data = DataManager._load_json_safe("res://data/missions/difficulty_settings.json", "BaseMissionGenerator")
	if difficulty_settings_data.is_empty():
		print("BaseMissionGenerator: difficulty_settings.json not found, creating fallback data")
		_create_difficulty_settings_fallback()
	else:
		print("BaseMissionGenerator: Loaded %d difficulty levels from JSON" % difficulty_settings_data.get("difficulty_levels", []).size())
	
	# Load reward tables data
	reward_tables_data = DataManager._load_json_safe("res://data/missions/reward_tables.json", "BaseMissionGenerator")
	if reward_tables_data.is_empty():
		print("BaseMissionGenerator: reward_tables.json not found, creating fallback data")
		_create_reward_tables_fallback()
	else:
		print("BaseMissionGenerator: Loaded reward calculation tables from JSON")

func _create_mission_types_fallback() -> void:
	"""Create fallback mission types data when JSON unavailable"""
	mission_types_data = {
		"mission_categories": [
			{
				"id": 0,
				"name": "Combat",
				"description": "Direct confrontation with enemy forces",
				"base_difficulty_modifier": 1.0,
				"required_crew_size": 3,
				"typical_duration": "2-4 hours",
				"special_requirements": []
			},
			{
				"id": 1,
				"name": "Exploration",
				"description": "Survey unknown territories and gather intelligence",
				"base_difficulty_modifier": 0.8,
				"required_crew_size": 2,
				"typical_duration": "3-5 hours",
				"special_requirements": ["scanner", "survival_gear"]
			},
			{
				"id": 2,
				"name": "Retrieval",
				"description": "Recover specific items or data from hostile territory",
				"base_difficulty_modifier": 1.0,
				"required_crew_size": 3,
				"typical_duration": "2-3 hours",
				"special_requirements": ["transport_capacity"]
			},
			{
				"id": 3,
				"name": "Escort",
				"description": "Protect civilians or cargo during transport",
				"base_difficulty_modifier": 1.1,
				"required_crew_size": 4,
				"typical_duration": "4-6 hours",
				"special_requirements": ["heavy_weapons"]
			},
			{
				"id": 4,
				"name": "Defense",
				"description": "Hold strategic positions against enemy assault",
				"base_difficulty_modifier": 1.3,
				"required_crew_size": 4,
				"typical_duration": "3-5 hours",
				"special_requirements": ["defensive_equipment", "ammunition"]
			}
		],
		"generation_parameters": {
			"max_mission_types": 10,
			"difficulty_scaling": 1.2,
			"crew_size_influence": 0.15
		}
	}

func _create_difficulty_settings_fallback() -> void:
	"""Create fallback difficulty settings when JSON unavailable"""
	difficulty_settings_data = {
		"difficulty_levels": [
			{
				"level": 0,
				"name": "Tutorial",
				"description": "Introduction to game mechanics",
				"enemy_scaling": 0.5,
				"reward_modifier": 0.3,
				"injury_chance": 0.1,
				"special_events_chance": 0.05
			},
			{
				"level": 1,
				"name": "Easy",
				"description": "Suitable for new crews",
				"enemy_scaling": 0.7,
				"reward_modifier": 0.6,
				"injury_chance": 0.15,
				"special_events_chance": 0.1
			},
			{
				"level": 2,
				"name": "Normal",
				"description": "Standard difficulty for experienced crews",
				"enemy_scaling": 1.0,
				"reward_modifier": 1.0,
				"injury_chance": 0.25,
				"special_events_chance": 0.2
			},
			{
				"level": 3,
				"name": "Hard",
				"description": "Challenging missions for veteran crews",
				"enemy_scaling": 1.3,
				"reward_modifier": 1.4,
				"injury_chance": 0.35,
				"special_events_chance": 0.3
			},
			{
				"level": 4,
				"name": "Very Hard",
				"description": "Extreme challenges with high stakes",
				"enemy_scaling": 1.6,
				"reward_modifier": 1.8,
				"injury_chance": 0.45,
				"special_events_chance": 0.4
			},
			{
				"level": 5,
				"name": "Extreme",
				"description": "Only for the most experienced crews",
				"enemy_scaling": 2.0,
				"reward_modifier": 2.5,
				"injury_chance": 0.55,
				"special_events_chance": 0.5
			}
		],
		"scaling_parameters": {
			"base_scaling_factor": 1.0,
			"crew_experience_modifier": 0.1,
			"equipment_quality_modifier": 0.15
		}
	}

func _create_reward_tables_fallback() -> void:
	"""Create fallback reward tables when JSON unavailable"""
	reward_tables_data = {
		"base_rewards": {
			"tutorial": 50,
			"easy": 100,
			"normal": 200,
			"hard": 350,
			"very_hard": 550,
			"extreme": 800
		},
		"mission_type_modifiers": {
			"Combat": 1.2,
			"Exploration": 0.8,
			"Retrieval": 1.0,
			"Escort": 1.1,
			"Defense": 1.3,
			"Sabotage": 1.4,
			"Assassination": 1.5,
			"Rescue": 1.2,
			"Infiltration": 1.3,
			"Investigation": 0.9
		},
		"completion_bonuses": {
			"perfect_stealth": 0.2,
			"no_casualties": 0.3,
			"time_bonus": 0.15,
			"extra_objectives": 0.25
		},
		"risk_multipliers": {
			"high_security": 1.5,
			"unknown_territory": 1.3,
			"time_pressure": 1.2,
			"limited_equipment": 1.4
		}
	}

func generate_mission(difficulty: int = 2, type: int = -1) -> Dictionary:
	push_error("BaseMissionGenerator.generate_mission() must be overridden by derived class")
	return {}

func generate_random_mission() -> Dictionary:
	var difficulty = randi() % 5 + 1
	var type = randi() % (safe_call_method(mission_types, "size") as int)

	return generate_mission(difficulty, type)

func generate_mission_batch(count: int = 3, min_difficulty: int = 1, max_difficulty: int = 5) -> Array:
	var missions: Array[Dictionary] = []

	for i: int in range(count):
		var _difficulty = randi() % (max_difficulty - min_difficulty + 1) + min_difficulty
		var mission = generate_mission(_difficulty)
		missions.append(mission)

	return missions

func complete_mission(mission_data: Dictionary, success: bool = true) -> void:
	mission_completed.emit(mission_data, success)

func get_difficulty_name(difficulty: int) -> String:
	if difficulty_levels.has(difficulty):
		return difficulty_levels[difficulty]
	return "Unknown"

func get_mission_type_name(type: int) -> String:
	if mission_types.has(type):
		return mission_types[type]
	return "Unknown"

func generate_mission_title(type: int) -> String:
	push_error("BaseMissionGenerator.generate_mission_title() must be overridden by derived class")
	return "Mission"

func generate_mission_description(type: int, difficulty: int) -> String:
	push_error("BaseMissionGenerator.generate_mission_description() must be overridden by derived class")
	return "Mission description"

func calculate_mission_reward(difficulty: int, type: int) -> int:
	"""Enhanced reward calculation using JSON data"""
	var base_reward: int = 100
	
	# Get base reward from JSON data
	var difficulty_name = get_difficulty_name(difficulty).to_lower().replace(" ", "_")
	if reward_tables_data.has("base_rewards") and reward_tables_data.base_rewards.has(difficulty_name):
		base_reward = reward_tables_data.base_rewards[difficulty_name]
	else:
		# Fallback calculation
		base_reward = 100 * difficulty
	
	# Apply mission type modifier from JSON data
	var mission_type_name = get_mission_type_name(type)
	var type_modifier: float = 1.0
	
	if reward_tables_data.has("mission_type_modifiers") and reward_tables_data.mission_type_modifiers.has(mission_type_name):
		type_modifier = reward_tables_data.mission_type_modifiers[mission_type_name]
	else:
		# Fallback modifiers
		match type:
			0: type_modifier = 1.2 # Combat
			1: type_modifier = 0.8 # Exploration
			2: type_modifier = 1.0 # Retrieval
			3: type_modifier = 1.1 # Escort
			4: type_modifier = 1.3 # Defense
			5: type_modifier = 1.4 # Sabotage
			6: type_modifier = 1.5 # Assassination
			7: type_modifier = 1.2 # Rescue
			8: type_modifier = 1.3 # Infiltration
			9: type_modifier = 0.9 # Investigation
			_: type_modifier = 1.0
	
	var final_reward = int(base_reward * type_modifier)
	
	# Log reward calculation for debugging
	print("BaseMissionGenerator: Calculated reward - Base: %d, Type: %s (%.1fx), Final: %d" % [base_reward, mission_type_name, type_modifier, final_reward])
	
	return final_reward

func calculate_enhanced_reward(difficulty: int, type: int, completion_bonuses: Array = [], risk_factors: Array = []) -> Dictionary:
	"""Enhanced reward calculation with bonuses and risk factors"""
	var base_reward = calculate_mission_reward(difficulty, type)
	var bonus_total: float = 0.0
	var risk_multiplier: float = 1.0
	
	# Apply completion bonuses from JSON data
	if reward_tables_data.has("completion_bonuses"):
		for bonus in completion_bonuses:
			if reward_tables_data.completion_bonuses.has(bonus):
				bonus_total += reward_tables_data.completion_bonuses[bonus]
	
	# Apply risk multipliers from JSON data
	if reward_tables_data.has("risk_multipliers"):
		for risk in risk_factors:
			if reward_tables_data.risk_multipliers.has(risk):
				risk_multiplier *= reward_tables_data.risk_multipliers[risk]
	
	var bonus_amount = int(base_reward * bonus_total)
	var final_reward = int((base_reward + bonus_amount) * risk_multiplier)
	
	return {
		"base_reward": base_reward,
		"bonus_amount": bonus_amount,
		"risk_multiplier": risk_multiplier,
		"final_reward": final_reward,
		"completion_bonuses": completion_bonuses,
		"risk_factors": risk_factors
	}

func get_mission_requirements(type: int) -> Dictionary:
	"""Get mission requirements from JSON data"""
	var requirements = {
		"crew_size": 3,
		"special_requirements": [],
		"typical_duration": "2-4 hours",
		"description": "Mission description"
	}
	
	if mission_types_data.has("mission_categories"):
		for mission_category in mission_types_data.mission_categories:
			if mission_category.get("id", -1) == type:
				requirements.crew_size = mission_category.get("required_crew_size", 3)
				requirements.special_requirements = mission_category.get("special_requirements", [])
				requirements.typical_duration = mission_category.get("typical_duration", "2-4 hours")
				requirements.description = mission_category.get("description", "Mission description")
				break
	
	return requirements

func get_difficulty_scaling(difficulty: int) -> Dictionary:
	"""Get difficulty scaling parameters from JSON data"""
	var scaling = {
		"enemy_scaling": 1.0,
		"reward_modifier": 1.0,
		"injury_chance": 0.25,
		"special_events_chance": 0.2
	}
	
	if difficulty_settings_data.has("difficulty_levels"):
		for level_data in difficulty_settings_data.difficulty_levels:
			if level_data.get("level", -1) == difficulty:
				scaling.enemy_scaling = level_data.get("enemy_scaling", 1.0)
				scaling.reward_modifier = level_data.get("reward_modifier", 1.0)
				scaling.injury_chance = level_data.get("injury_chance", 0.25)
				scaling.special_events_chance = level_data.get("special_events_chance", 0.2)
				break
	
	return scaling

func serialize_mission(mission_data: Dictionary) -> Dictionary:
	# Base implementation just returns a copy of the mission _data
	return mission_data.duplicate(true)

func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	# Base implementation just returns a copy of the serialized _data
	return serialized_data.duplicate(true)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null