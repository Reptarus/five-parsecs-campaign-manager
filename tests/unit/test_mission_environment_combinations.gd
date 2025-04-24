@tool
extends "res://tests/fixtures/base/game_test.gd"

## Test suite for combinations of mission types and environments in Five Parsecs
## Tests all valid combinations to ensure proper generation and compatibility

# Dependencies
const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const MissionGameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

# Test variables
var _generator = null
var _mission_environment_results = {}
var _available_mission_types = []
var _available_environments = []

func before_each() -> void:
	await super.before_each()
	
	# Initialize generator
	_generator = BattlefieldGenerator.new()
	add_child(_generator)
	track_test_node(_generator)
	
	# Reset results
	_mission_environment_results = {}
	
	# Determine available mission types from the enums
	_available_mission_types = []
	for key in MissionGameEnums.MissionType.keys():
		if key != "NONE" and not key.begins_with("_"):
			_available_mission_types.append({
				"name": key,
				"value": MissionGameEnums.MissionType[key]
			})
	
	# Determine available environments from the enums
	_available_environments = []
	for key in MissionGameEnums.PlanetEnvironment.keys():
		if key != "NONE" and not key.begins_with("_"):
			_available_environments.append({
				"name": key,
				"value": MissionGameEnums.PlanetEnvironment[key]
			})

func after_each() -> void:
	_generator = null
	await super.after_each()

## Tests all combinations of mission types and environments
func test_all_mission_environment_combinations() -> void:
	for mission in _available_mission_types:
		var mission_type = mission.value
		var mission_name = mission.name
		
		# Skip if we don't have any mission types (shouldn't happen)
		if _available_mission_types.size() == 0:
			pending("No mission types available")
			return
		
		# Create result structure for this mission type
		_mission_environment_results[mission_name] = {}
		
		# Test with each environment
		for env in _available_environments:
			var env_value = env.value
			var env_name = env.name
			
			# Create mission config
			var config = {
				"mission_type": mission_type,
				"difficulty": 3,
				"environment": env_value,
				"size": Vector2i(24, 24),
				"cover_density": 0.2
			}
			
			# Track if environment is compatible with this mission type
			var is_compatible = true
			var completion_reason = "Success"
			var features_count = 0
			
			# Generate battlefield for this combination
			var battlefield = null
			
			# Use a try-catch to handle potential errors
			var start_time = Time.get_ticks_msec()
			
			battlefield = _generator.generate_battlefield(config)
			
			var end_time = Time.get_ticks_msec()
			var generation_time = end_time - start_time
			
			# Check result
			if battlefield == null:
				is_compatible = false
				completion_reason = "Failed to generate battlefield"
			else:
				# Check essential battlefield components
				if not battlefield.has("terrain"):
					is_compatible = false
					completion_reason = "Missing terrain"
				elif not battlefield.has("deployment_zones"):
					is_compatible = false
					completion_reason = "Missing deployment zones"
				elif not battlefield.has("objectives"):
					is_compatible = false
					completion_reason = "Missing objectives"
				else:
					# Count terrain features
					var terrain_features = _count_terrain_features(battlefield)
					features_count = terrain_features.size()
					
					# Check if appropriate objectives exist for this mission type
					var has_right_objectives = _has_appropriate_objectives(battlefield, mission_type)
					if not has_right_objectives:
						is_compatible = false
						completion_reason = "Missing appropriate objectives"
			
			# Record result
			_mission_environment_results[mission_name][env_name] = {
				"compatible": is_compatible,
				"reason": completion_reason,
				"feature_count": features_count,
				"generation_time_ms": generation_time
			}
			
			# Perform assertions - we expect all combinations to work
			assert_not_null(battlefield, "Should generate battlefield for %s in %s" % [mission_name, env_name])
			
			if battlefield:
				assert_true(battlefield.has("terrain"), "Battlefield should have terrain")
				assert_true(battlefield.has("deployment_zones"), "Battlefield should have deployment zones")
				assert_true(battlefield.has("objectives"), "Battlefield should have objectives")
			
	# Summary assertions
	for mission_name in _mission_environment_results:
		for env_name in _mission_environment_results[mission_name]:
			var result = _mission_environment_results[mission_name][env_name]
			assert_true(result.compatible, "%s in %s should be compatible" % [mission_name, env_name])

## Tests that mission types have appropriate objectives across all environments
func test_mission_specific_objectives() -> void:
	# Focus on key mission types that should have specific objectives
	var key_missions = [
		{"name": "PATROL", "objective": "patrol_points"},
		{"name": "SABOTAGE", "objective": "target_points"},
		{"name": "RESCUE", "objective": "rescue_points"}
	]
	
	# Filter to actually available missions
	var filtered_missions = []
	for mission in key_missions:
		if mission.name in MissionGameEnums.MissionType:
			filtered_missions.append({
				"name": mission.name,
				"value": MissionGameEnums.MissionType[mission.name],
				"objective": mission.objective
			})
	
	# Skip if no missions match
	if filtered_missions.size() == 0:
		pending("No matching mission types available")
		return
	
	# Create result map for mission objectives
	var objective_results = {}
	
	# Test each mission type with first available environment
	for mission in filtered_missions:
		var mission_type = mission.value
		var mission_name = mission.name
		var expected_objective = mission.objective
		objective_results[mission_name] = {}
		
		# Use each environment
		for env in _available_environments:
			var env_value = env.value
			var env_name = env.name
			
			var config = {
				"mission_type": mission_type,
				"difficulty": 3,
				"environment": env_value,
				"size": Vector2i(24, 24)
			}
			
			var battlefield = _generator.generate_battlefield(config)
			
			if battlefield and battlefield.has("objectives"):
				var objectives = battlefield.objectives
				var has_expected = objectives.has(expected_objective)
				
				objective_results[mission_name][env_name] = {
					"has_expected_objective": has_expected,
					"available_objectives": objectives.keys()
				}
				
				assert_true(has_expected,
					"%s mission should have %s objective in %s environment" %
					[mission_name, expected_objective, env_name])
	
	# Store results for reference
	_mission_environment_results["objectives"] = objective_results

## Tests that different environments produce different terrain distributions
func test_environment_terrain_distribution() -> void:
	var terrain_distribution_results = {}
	
	# Skip if no environments
	if _available_environments.size() == 0:
		pending("No environments available")
		return
	
	# Use first available mission type
	var mission_type = _available_mission_types[0].value if _available_mission_types.size() > 0 else 0
	
	# Generate battlefield for each environment
	for env in _available_environments:
		var env_value = env.value
		var env_name = env.name
		
		terrain_distribution_results[env_name] = {}
		
		var config = {
			"mission_type": mission_type,
			"difficulty": 3,
			"environment": env_value,
			"size": Vector2i(24, 24),
			"cover_density": 0.2
		}
		
		var battlefield = _generator.generate_battlefield(config)
		
		if battlefield and battlefield.has("terrain"):
			var terrain_features = _count_terrain_features(battlefield)
			terrain_distribution_results[env_name] = terrain_features
			
			# Each environment should have some terrain features
			assert_true(terrain_features.size() > 0,
				"%s environment should have terrain features" % env_name)
	
	# Compare terrain distributions between environments
	# We expect different environments to have at least somewhat different distributions
	if _available_environments.size() >= 2:
		for i in range(_available_environments.size() - 1):
			var env1 = _available_environments[i].name
			var env2 = _available_environments[i + 1].name
			
			if terrain_distribution_results.has(env1) and terrain_distribution_results.has(env2):
				var env1_features = terrain_distribution_results[env1]
				var env2_features = terrain_distribution_results[env2]
				
				var is_different = false
				
				# Check if terrain type counts are different
				if env1_features.size() != env2_features.size():
					is_different = true
				else:
					for feature in env1_features:
						if not env2_features.has(feature) or env1_features[feature] != env2_features[feature]:
							is_different = true
							break
				
				# Different environments should have different terrain distributions
				# This is a soft expectation - might not always be true based on random generation
				if not is_different:
					push_warning("%s and %s environments have identical terrain distributions" % [env1, env2])
	
	# Store results for reference
	_mission_environment_results["terrain_distribution"] = terrain_distribution_results

## Tests performance across different mission environment combinations
func test_mission_environment_performance() -> void:
	var performance_results = {}
	
	# Skip if no types to test with
	if _available_mission_types.size() == 0 or _available_environments.size() == 0:
		pending("No mission types or environments available")
		return
	
	# Sample selection of mission types and environments
	var sample_mission_count = min(3, _available_mission_types.size())
	var sample_env_count = min(3, _available_environments.size())
	
	var sample_missions = _available_mission_types.slice(0, sample_mission_count)
	var sample_environments = _available_environments.slice(0, sample_env_count)
	
	for mission in sample_missions:
		var mission_type = mission.value
		var mission_name = mission.name
		
		performance_results[mission_name] = {}
		
		for env in sample_environments:
			var env_value = env.value
			var env_name = env.name
			
			var config = {
				"mission_type": mission_type,
				"difficulty": 3,
				"environment": env_value,
				"size": Vector2i(24, 24)
			}
			
			# Generate multiple times to get average performance
			var iterations = 5
			var total_time = 0
			
			for i in range(iterations):
				var start_time = Time.get_ticks_msec()
				var battlefield = _generator.generate_battlefield(config)
				var end_time = Time.get_ticks_msec()
				
				total_time += (end_time - start_time)
				
				# Basic validation
				assert_not_null(battlefield, "Battlefield generation should succeed")
			
			var avg_time = total_time / float(iterations)
			
			performance_results[mission_name][env_name] = avg_time
			
			# Battlefield generation should be reasonably fast
			assert_true(avg_time < 100.0,
				"%s in %s should generate in under 100ms (took %.2fms)" %
				[mission_name, env_name, avg_time])
	
	# Store results for reference
	_mission_environment_results["performance"] = performance_results

## Helper function to check if battlefield has appropriate objectives for mission type
func _has_appropriate_objectives(battlefield: Dictionary, mission_type: int) -> bool:
	if not battlefield.has("objectives"):
		return false
		
	var objectives = battlefield.objectives
	
	if objectives.size() == 0:
		return false
		
	# Check for specific mission type objectives
	if "PATROL" in MissionGameEnums.MissionType and mission_type == MissionGameEnums.MissionType.PATROL:
		return objectives.has("patrol_points")
	elif "SABOTAGE" in MissionGameEnums.MissionType and mission_type == MissionGameEnums.MissionType.SABOTAGE:
		return objectives.has("target_points")
	elif "RESCUE" in MissionGameEnums.MissionType and mission_type == MissionGameEnums.MissionType.RESCUE:
		return objectives.has("rescue_points")
		
	# Default - just require some objectives
	return objectives.size() > 0

## Helper function to count terrain features in a battlefield
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