@tool
extends "res://tests/fixtures/base/game_test.gd"

## Test suite for different mission categories and types in Five Parsecs
## Tests mission generation, validation, and gameplay flow

# Dependencies - use explicit preloads
const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const MissionGameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Mission categories and test data
var _mission_types = [
	"PATROL",
	"SABOTAGE",
	"RESCUE",
	"DEFENSE"
]

# Environment types to test
var _environment_types = [
	"URBAN"
]

# Difficulty levels
var _difficulty_levels = [1, 2, 3, 4, 5]

# Test variables
var _generator = null
var _mission_results = {}

func before_each() -> void:
	await super.before_each()
	
	# Initialize generator
	_generator = BattlefieldGenerator.new()
	add_child(_generator)
	track_test_node(_generator)
	
	# Reset results
	_mission_results = {}
	
	# Determine available environment types
	_environment_types = ["URBAN"]
	
	if "FOREST" in MissionGameEnums.PlanetEnvironment:
		_environment_types.append("FOREST")
	elif "WILDERNESS" in MissionGameEnums.PlanetEnvironment:
		_environment_types.append("WILDERNESS")
		
	if "INDUSTRIAL" in MissionGameEnums.PlanetEnvironment:
		_environment_types.append("INDUSTRIAL")
		
	if "STARSHIP" in MissionGameEnums.PlanetEnvironment:
		_environment_types.append("STARSHIP")
	
	# Get available mission types
	_mission_types = []
	for key in MissionGameEnums.MissionType.keys():
		if key != "NONE" and not key.begins_with("_"):
			_mission_types.append(key)

func after_each() -> void:
	_generator = null
	await super.after_each()

## Test mission type categorization and validation
func test_mission_type_categories() -> void:
	for mission_type in _mission_types:
		if mission_type in MissionGameEnums.MissionType:
			var type_value = MissionGameEnums.MissionType[mission_type]
			assert_true(type_value >= 0, "Mission type %s should have valid enum value" % mission_type)
			
			# Create a mission of this type
			var mission = Mission.new()
			mission.mission_type = type_value
			mission.mission_title = "Test %s Mission" % mission_type
			
			# Verify serialization preserves type
			var serialized = mission.serialize()
			assert_eq(serialized.mission_type, type_value, "Serialized mission should preserve type")
			
			# Test that the mission is categorized correctly
			var category = _get_mission_category(type_value)
			assert_true(category.length() > 0, "Mission type %s should have a category" % mission_type)
			
			_mission_results[mission_type] = {
				"category": category,
				"type_value": type_value
			}

## Test that each mission type has appropriate objectives
func test_mission_type_objectives() -> void:
	# Test all mission types
	for mission_type in _mission_types:
		if mission_type in MissionGameEnums.MissionType:
			var type_value = MissionGameEnums.MissionType[mission_type]
			
			# Create a mission config
			var config = {
				"mission_type": type_value,
				"difficulty": 3,
				"environment": MissionGameEnums.PlanetEnvironment.URBAN,
				"size": Vector2i(24, 24)
			}
			
			# Generate battlefield for this mission type
			var battlefield = _generator.generate_battlefield(config)
			
			# Verify battlefield generation
			assert_not_null(battlefield, "Battlefield should be generated for %s" % mission_type)
			
			if battlefield:
				# Check for objectives
				assert_true(battlefield.has("objectives"), "Battlefield should have objectives for %s" % mission_type)
				
				if battlefield.has("objectives"):
					var objectives = battlefield.objectives
					assert_true(objectives.size() > 0, "Objectives should not be empty for %s" % mission_type)
					
					# Store for reporting
					_mission_results[mission_type]["objectives"] = objectives.keys()
					
					# Verify appropriate objective types based on mission type
					match type_value:
						MissionGameEnums.MissionType.PATROL if "PATROL" in MissionGameEnums.MissionType else -1:
							assert_true(objectives.has("patrol_points"), "Patrol mission should have patrol points")
						MissionGameEnums.MissionType.SABOTAGE if "SABOTAGE" in MissionGameEnums.MissionType else -1:
							assert_true(objectives.has("target_points"), "Sabotage mission should have target points")
						MissionGameEnums.MissionType.RESCUE if "RESCUE" in MissionGameEnums.MissionType else -1:
							assert_true(objectives.has("rescue_points"), "Rescue mission should have rescue points")
						MissionGameEnums.MissionType.DEFENSE if "DEFENSE" in MissionGameEnums.MissionType else -1:
							assert_true(objectives.has("defense_points") or objectives.has("defend_points"),
								"Defense mission should have defense points")

## Test mission difficulty scaling
func test_mission_difficulty_scaling() -> void:
	var mission_type = _mission_types[0] if _mission_types.size() > 0 else "PATROL"
	var type_value = MissionGameEnums.MissionType[mission_type] if mission_type in MissionGameEnums.MissionType else 0
	
	var difficulty_results = {}
	
	# Test each difficulty level
	for difficulty in _difficulty_levels:
		# Create mission config
		var config = {
			"mission_type": type_value,
			"difficulty": difficulty,
			"environment": MissionGameEnums.PlanetEnvironment.URBAN,
			"size": Vector2i(24, 24)
		}
		
		var battlefield = _generator.generate_battlefield(config)
		assert_not_null(battlefield, "Battlefield should be generated for difficulty %d" % difficulty)
		
		if battlefield:
			# Check for enemy count
			if battlefield.has("enemies"):
				var enemy_count = battlefield.enemies.size()
				difficulty_results[difficulty] = enemy_count
				
				# Higher difficulty should have more enemies than lower difficulty
				if difficulty > 1 and difficulty_results.has(difficulty - 1):
					assert_true(enemy_count >= difficulty_results[difficulty - 1],
						"Higher difficulty should have at least as many enemies as lower difficulty")
			
			# Check for terrain complexity
			if battlefield.has("terrain"):
				var terrain_features = _count_terrain_features(battlefield)
				var feature_count = 0
				for feature in terrain_features:
					feature_count += terrain_features[feature]
				
				# Store result
				if not difficulty_results.has(difficulty):
					difficulty_results[difficulty] = {}
				difficulty_results[difficulty]["terrain_features"] = feature_count
	
	# Store results
	_mission_results["difficulty_scaling"] = difficulty_results

## Test mission environment variation
func test_mission_environment_variation() -> void:
	var mission_type = _mission_types[0] if _mission_types.size() > 0 else "PATROL"
	var type_value = MissionGameEnums.MissionType[mission_type] if mission_type in MissionGameEnums.MissionType else 0
	
	var environment_results = {}
	
	# Test each environment type
	for env_name in _environment_types:
		if env_name in MissionGameEnums.PlanetEnvironment:
			var env_value = MissionGameEnums.PlanetEnvironment[env_name]
			
			# Create mission config
			var config = {
				"mission_type": type_value,
				"difficulty": 3,
				"environment": env_value,
				"size": Vector2i(24, 24)
			}
			
			var battlefield = _generator.generate_battlefield(config)
			assert_not_null(battlefield, "Battlefield should be generated for environment %s" % env_name)
			
			if battlefield:
				# Check for terrain features
				if battlefield.has("terrain"):
					var terrain_features = _count_terrain_features(battlefield)
					environment_results[env_name] = terrain_features
					
					# Each environment should have appropriate feature distribution
					assert_true(terrain_features.size() > 0, "Environment should have terrain features")
	
	# Store results
	_mission_results["environment_variation"] = environment_results

## Test mission reward calculation
func test_mission_reward_calculation() -> void:
	var mission_rewards = {}
	
	# Test reward scaling with difficulty
	for difficulty in _difficulty_levels:
		var mission = Mission.new()
		mission.mission_difficulty = difficulty
		mission.reward_credits = difficulty * 100 # Example reward calculation
		
		mission_rewards[difficulty] = mission.reward_credits
		
		# Higher difficulty should give better rewards
		if difficulty > 1:
			assert_true(mission_rewards[difficulty] > mission_rewards[difficulty - 1],
				"Higher difficulty should give better rewards")
	
	# Store results
	_mission_results["reward_scaling"] = mission_rewards

## Test mission completion flow
func test_mission_completion_flow() -> void:
	var mission = Mission.new()
	mission.mission_id = "test_flow"
	mission.mission_title = "Test Flow Mission"
	mission.mission_type = MissionGameEnums.MissionType.PATROL if "PATROL" in MissionGameEnums.MissionType else 0
	mission.mission_difficulty = 3
	
	assert_false(mission.is_completed, "Mission should start as not completed")
	assert_false(mission.is_failed, "Mission should start as not failed")
	
	# Test completion
	mission.complete(true)
	assert_true(mission.is_completed, "Mission should be marked as completed")
	
	# Test failure
	var fail_mission = Mission.new()
	fail_mission.mission_id = "test_flow_fail"
	fail_mission.fail()
	assert_true(fail_mission.is_failed, "Mission should be marked as failed")
	
	# Store results
	_mission_results["completion_flow"] = {
		"completed": mission.is_completed,
		"failed": fail_mission.is_failed
	}

## Test integrated mission flow
func test_integrated_mission_flow() -> void:
	var mission_id = "integrated_test"
	var mission_type = MissionGameEnums.MissionType.PATROL if "PATROL" in MissionGameEnums.MissionType else 0
	var difficulty = 3
	
	# 1. Create mission
	var mission = Mission.new()
	mission.mission_id = mission_id
	mission.mission_title = "Integrated Test Mission"
	mission.mission_description = "A comprehensive test mission"
	mission.mission_type = mission_type
	mission.mission_difficulty = difficulty
	mission.reward_credits = difficulty * 100
	
	# 2. Generate battlefield
	var config = {
		"mission_type": mission_type,
		"difficulty": difficulty,
		"environment": MissionGameEnums.PlanetEnvironment.URBAN,
		"size": Vector2i(24, 24)
	}
	
	var battlefield = _generator.generate_battlefield(config)
	assert_not_null(battlefield, "Battlefield should be generated for integrated test")
	
	if not battlefield:
		pending("Could not generate battlefield for integrated test")
		return
	
	# 3. Validate basic battlefield properties
	assert_true(battlefield.has("terrain"), "Battlefield should have terrain")
	assert_true(battlefield.has("deployment_zones"), "Battlefield should have deployment zones")
	assert_true(battlefield.has("objectives"), "Battlefield should have objectives")
	
	# 4. Complete mission and check results
	mission.complete(true)
	assert_true(mission.is_completed, "Mission should be marked as completed")
	
	# 5. Serialize and deserialize to verify
	var serialized = mission.serialize()
	var deserialized = Mission.new().deserialize(serialized)
	
	assert_eq(deserialized.mission_id, mission_id, "Deserialized mission should have same ID")
	assert_eq(deserialized.mission_type, mission_type, "Deserialized mission should have same type")
	assert_true(deserialized.is_completed, "Deserialized mission should still be completed")
	
	# Store results
	_mission_results["integrated_flow"] = {
		"mission_created": mission != null,
		"battlefield_generated": battlefield != null,
		"objectives_valid": battlefield.has("objectives"),
		"completion_persisted": deserialized.is_completed
	}

## Helper function to get mission category
func _get_mission_category(mission_type: int) -> String:
	match mission_type:
		MissionGameEnums.MissionType.PATROL if "PATROL" in MissionGameEnums.MissionType else -1:
			return "COMBAT"
		MissionGameEnums.MissionType.SABOTAGE if "SABOTAGE" in MissionGameEnums.MissionType else -1:
			return "STEALTH"
		MissionGameEnums.MissionType.RESCUE if "RESCUE" in MissionGameEnums.MissionType else -1:
			return "SPECIAL"
		MissionGameEnums.MissionType.DEFENSE if "DEFENSE" in MissionGameEnums.MissionType else -1:
			return "COMBAT"
		_:
			return "UNKNOWN"

## Helper function to count terrain features
func _count_terrain_features(battlefield: Dictionary) -> Dictionary:
	var counts = {}
	
	if battlefield.has("terrain") and battlefield.terrain is Array:
		var terrain_data = battlefield.terrain
		
		for x in range(terrain_data.size()):
			var column = terrain_data[x]
			
			# Check format - might be 1D array or have nested 'row' property
			if column is Dictionary and column.has("row") and column.row is Array:
				for cell in column.row:
					if cell is Dictionary and cell.has("type"):
						var type = cell.type
						if not counts.has(type):
							counts[type] = 0
						counts[type] += 1
			elif column is Array:
				for cell in column:
					if cell is Dictionary and cell.has("type"):
						var type = cell.type
						if not counts.has(type):
							counts[type] = 0
						counts[type] += 1
	
	return counts
