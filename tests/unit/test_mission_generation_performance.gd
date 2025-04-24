@tool
extends "res://tests/fixtures/base/game_test.gd"

## Test suite for performance of mission and battlefield generation
## Focuses on measuring resource usage and stability across multiple mission types

# Dependencies - use explicit preloads
const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

# Use a different variable name to avoid conflict with base test class
const MissionGameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Test parameters
const TEST_ITERATIONS = 100
const TEST_BATCH_SIZE = 10
const PERFORMANCE_THRESHOLD_MS = 50 # ms per battlefield generation

# Instance variables with type safety
var _generator: Node = null
var _timer: Timer = null
var _performance_results: Dictionary = {}
var _position_validator = null

func before_each() -> void:
	await super.before_each()
	
	# Initialize battlefield generator
	_generator = BattlefieldGenerator.new()
	if not is_instance_valid(_generator):
		push_error("Failed to create battlefield generator")
		return
	
	# Check if PositionValidator exists and initialize it
	if ResourceLoader.exists("res://src/core/systems/PositionValidator.gd"):
		var PositionValidator = load("res://src/core/systems/PositionValidator.gd")
		_position_validator = PositionValidator.new()
		if is_instance_valid(_position_validator) and _generator.has_method("setup"):
			_generator.setup(_position_validator)
	
	add_child(_generator)
	track_test_node(_generator)
	
	# Set up timer for performance testing
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	track_test_node(_timer)
	
	# Reset performance results
	_performance_results = {}

func after_each() -> void:
	# Explicitly clean up resources
	if is_instance_valid(_generator):
		_generator.queue_free()
	_generator = null
	
	if is_instance_valid(_position_validator):
		_position_validator.queue_free()
	_position_validator = null
	
	if is_instance_valid(_timer):
		_timer.queue_free()
	_timer = null
	
	# Force garbage collection
	OS.delay_msec(100) # Give time for queue_free to complete
	await force_garbage_collection()
	
	await super.after_each()

# Helper to force garbage collection
func force_garbage_collection() -> void:
	# Create then clear arrays to try to force GC
	var temp_arrays = []
	for i in range(5):
		temp_arrays.append(PackedByteArray().resize(1024 * 1024)) # 1MB chunks
	temp_arrays.clear()
	
	# Wait for the next frame to give GC a chance to run
	var tree = get_tree()
	if tree != null:
		await tree.process_frame
	else:
		await Engine.get_main_loop().process_frame

## Helper method to safely generate battlefield with null checks
func _safe_generate_battlefield(config: Dictionary) -> Dictionary:
	if not is_instance_valid(_generator):
		push_error("Battlefield generator is null")
		return {}
		
	if not _generator.has_method("generate_battlefield"):
		push_error("Battlefield generator missing generate_battlefield method")
		return {}
		
	var battlefield = _generator.generate_battlefield(config)
	return battlefield if battlefield != null else {}

## Tests generation of a batch of missions for performance
func test_batch_mission_generation() -> void:
	var mission_types = [
		MissionGameEnums.MissionType.PATROL,
		MissionGameEnums.MissionType.SABOTAGE,
		MissionGameEnums.MissionType.RESCUE
	]
	
	# Use constants for environment types that actually exist in the codebase
	var environments = [
		MissionGameEnums.PlanetEnvironment.URBAN
	]
	
	# Add other environments if they exist
	if "FOREST" in MissionGameEnums.PlanetEnvironment:
		environments.append(MissionGameEnums.PlanetEnvironment["FOREST"])
	elif "WILDERNESS" in MissionGameEnums.PlanetEnvironment:
		# Fallback to another environment
		environments.append(MissionGameEnums.PlanetEnvironment.URBAN)
		
	if "INDUSTRIAL" in MissionGameEnums.PlanetEnvironment:
		# Fallback to another environment
		environments.append(MissionGameEnums.PlanetEnvironment.URBAN)
		
	if "STARSHIP" in MissionGameEnums.PlanetEnvironment:
		# Fallback to another environment
		environments.append(MissionGameEnums.PlanetEnvironment.URBAN)
	
	for i in range(TEST_BATCH_SIZE):
		var mission_type = mission_types[i % mission_types.size()]
		var environment = environments[i % environments.size()]
		var difficulty = (i % 5) + 1
		
		var mission_config = {
			"mission_type": mission_type,
			"difficulty": difficulty,
			"environment": environment,
			"size": Vector2i(24, 24),
			"cover_density": 0.2 + (i * 0.05)
		}
		
		var start_time = Time.get_ticks_msec()
		var battlefield = _safe_generate_battlefield(mission_config)
		var end_time = Time.get_ticks_msec()
		var duration = end_time - start_time
		
		# Log performance
		if not _performance_results.has(mission_type):
			_performance_results[mission_type] = []
		_performance_results[mission_type].append(duration)
		
		# Verify battlefield was generated
		assert_true(battlefield.size() > 0, "Failed to generate mission %d" % i)
		
		# Basic validation of battlefield properties
		if battlefield.size() > 0:
			assert_eq(battlefield.get("size"), mission_config.get("size"), "Battlefield size should match config")
			assert_true(battlefield.has("terrain"), "Battlefield should have terrain")
			assert_true(battlefield.has("deployment_zones"), "Battlefield should have deployment zones")
			
			if battlefield.has("deployment_zones"):
				assert_true(battlefield.deployment_zones.has("player"), "Battlefield should have player deployment zone")
				assert_true(battlefield.deployment_zones.has("enemy"), "Battlefield should have enemy deployment zone")

## Tests performance of battlefield generation across different environment types
func test_environment_battlefield_generation() -> void:
	var environments = {
		"URBAN": MissionGameEnums.PlanetEnvironment.URBAN
	}
	
	# Add other environments if they exist
	if "FOREST" in MissionGameEnums.PlanetEnvironment:
		environments["FOREST"] = MissionGameEnums.PlanetEnvironment["FOREST"]
	elif "WILDERNESS" in MissionGameEnums.PlanetEnvironment:
		# Use a different environment as this one doesn't exist
		environments["DESERT"] = MissionGameEnums.PlanetEnvironment.DESERT
		
	if "INDUSTRIAL" in MissionGameEnums.PlanetEnvironment:
		# Use a different environment as this one doesn't exist
		environments["DESERT"] = MissionGameEnums.PlanetEnvironment.DESERT
		
	if "STARSHIP" in MissionGameEnums.PlanetEnvironment:
		# Use a different environment as this one doesn't exist
		environments["HAZARDOUS"] = MissionGameEnums.PlanetEnvironment.HAZARDOUS
	
	for env_name in environments:
		var config = {
			"size": Vector2i(24, 24),
			"environment": environments[env_name],
			"cover_density": 0.2
		}
		
		var timings = []
		for i in range(5): # Generate 5 battlefields per environment
			var start_time = Time.get_ticks_msec()
			var battlefield = _safe_generate_battlefield(config)
			var end_time = Time.get_ticks_msec()
			timings.append(end_time - start_time)
			
			# Validate battlefield
			assert_true(battlefield.size() > 0, "Failed to generate %s battlefield" % env_name)
			
			# Verify adequate terrain features based on environment
			if battlefield.size() > 0 and battlefield.has("terrain"):
				var terrain_counts = count_terrain_features(battlefield)
				assert_true(terrain_counts.size() > 0, "%s should have terrain features" % env_name)
		
		# Calculate average time
		var avg_time = 0.0
		for t in timings:
			avg_time += t
		avg_time /= timings.size()
		
		# Log performance
		_performance_results[env_name] = avg_time
		
		# Check performance is within acceptable range
		assert_true(avg_time < PERFORMANCE_THRESHOLD_MS,
			"%s generation should be under %d ms (was %.2f ms)" % [env_name, PERFORMANCE_THRESHOLD_MS, avg_time])

## Tests battlefield generation with different sizes
func test_battlefield_size_scaling() -> void:
	var sizes = [
		Vector2i(16, 16), # Small
		Vector2i(24, 24), # Medium
		Vector2i(32, 32), # Large
		Vector2i(48, 48) # Extra Large
	]
	
	for size in sizes:
		var config = {
			"size": size,
			"environment": MissionGameEnums.PlanetEnvironment.URBAN,
			"cover_density": 0.2
		}
		
		var start_time = Time.get_ticks_msec()
		var battlefield = _safe_generate_battlefield(config)
		var end_time = Time.get_ticks_msec()
		var duration = end_time - start_time
		
		# Log performance
		_performance_results["size_%dx%d" % [size.x, size.y]] = duration
		
		# Verify battlefield was generated with correct size
		assert_true(battlefield.size() > 0, "Failed to generate battlefield of size %dx%d" % [size.x, size.y])
		if battlefield.size() > 0:
			assert_eq(battlefield.get("size"), size, "Generated battlefield should have correct size")
			
			# Larger battlefields should have more walkable tiles
			if battlefield.has("walkable_tiles"):
				assert_true(battlefield.walkable_tiles.size() > (size.x * size.y * 0.5),
					"Battlefield should have sufficient walkable tiles")

## Tests mission objectives generation for different mission types
func test_mission_objectives() -> void:
	var mission_types = {
		"PATROL": MissionGameEnums.MissionType.PATROL,
		"SABOTAGE": MissionGameEnums.MissionType.SABOTAGE,
		"RESCUE": MissionGameEnums.MissionType.RESCUE
	}
	
	for mission_name in mission_types:
		var config = {
			"size": Vector2i(24, 24),
			"environment": MissionGameEnums.PlanetEnvironment.URBAN,
			"mission_type": mission_types[mission_name],
			"difficulty": 3,
			"cover_density": 0.2
		}
		
		var battlefield = _safe_generate_battlefield(config)
		assert_true(battlefield.size() > 0, "Failed to generate battlefield for %s mission" % mission_name)
		
		# Verify mission-specific objectives were generated
		if battlefield and battlefield.has("objectives"):
			var objectives = battlefield.objectives
			assert_true(objectives.size() > 0, "%s mission should have objectives" % mission_name)
			
			match mission_types[mission_name]:
				MissionGameEnums.MissionType.PATROL:
					assert_true(objectives.has("patrol_points"), "Patrol mission should have patrol points")
					assert_true(objectives.patrol_points.size() > 0, "Patrol mission should have at least one patrol point")
				MissionGameEnums.MissionType.SABOTAGE:
					assert_true(objectives.has("target_points"), "Sabotage mission should have target points")
					assert_true(objectives.target_points.size() > 0, "Sabotage mission should have at least one target point")
				MissionGameEnums.MissionType.RESCUE:
					assert_true(objectives.has("rescue_points"), "Rescue mission should have rescue points")
					assert_true(objectives.rescue_points.size() > 0, "Rescue mission should have at least one rescue point")

## Tests performance over multiple iterations
func test_mission_serialization_performance() -> void:
	var mission = Mission.new()
	mission.mission_id = "test_mission"
	mission.mission_title = "Test Mission"
	mission.mission_description = "This is a test mission"
	mission.mission_type = MissionGameEnums.MissionType.PATROL
	mission.mission_difficulty = 3
	mission.reward_credits = 500
	
	var start_time = Time.get_ticks_msec()
	for i in range(TEST_ITERATIONS):
		var serialized = mission.serialize()
		var deserialized = Mission.new().deserialize(serialized)
		assert_eq(deserialized.mission_id, mission.mission_id, "Mission ID should be preserved")
		assert_eq(deserialized.mission_type, mission.mission_type, "Mission type should be preserved")
	var end_time = Time.get_ticks_msec()
	
	var duration = end_time - start_time
	var per_operation = duration / float(TEST_ITERATIONS)
	_performance_results["serialization"] = per_operation
	
	# Verify performance is acceptable
	assert_true(per_operation < 1.0, "Serialization should take less than 1ms per operation")

## Tests memory usage of mission generation
func test_mission_memory_usage() -> void:
	var pre_gen_memory = OS.get_static_memory_usage()
	var mission_count = 100
	var missions = []
	
	for i in range(mission_count):
		var mission = Mission.new()
		mission.mission_id = "test_mission_%d" % i
		mission.mission_title = "Test Mission %d" % i
		mission.mission_description = "This is test mission %d" % i
		mission.mission_type = i % 3 # Alternate between mission types
		mission.mission_difficulty = (i % 5) + 1
		mission.reward_credits = 100 * ((i % 5) + 1)
		missions.append(mission)
	
	var post_gen_memory = OS.get_static_memory_usage()
	var memory_per_mission = (post_gen_memory - pre_gen_memory) / mission_count
	
	_performance_results["memory_per_mission"] = memory_per_mission
	
	# Verify memory usage is reasonable
	assert_true(memory_per_mission < 1024 * 10, "Each mission should use less than 10KB of memory")
	
	# Clean up (allow GC to reclaim memory)
	missions.clear()

## Tests battlefield validation with various configurations
func test_battlefield_validation() -> void:
	var configs = [
		{
			"size": Vector2i(24, 24),
			"environment": MissionGameEnums.PlanetEnvironment.URBAN,
			"cover_density": 0.2
		}
	]
	
	# Add other environments if they exist
	if "FOREST" in MissionGameEnums.PlanetEnvironment:
		configs.append({
			"size": Vector2i(12, 12), # Small size
			"environment": MissionGameEnums.PlanetEnvironment["FOREST"],
			"cover_density": 0.1
		})
	elif "WILDERNESS" in MissionGameEnums.PlanetEnvironment:
		configs.append({
			"size": Vector2i(12, 12), # Small size
			"environment": MissionGameEnums.PlanetEnvironment.DESERT, # Use existing environment
			"cover_density": 0.1
		})
	
	if "INDUSTRIAL" in MissionGameEnums.PlanetEnvironment:
		configs.append({
			"size": Vector2i(48, 48), # Large size
			"environment": MissionGameEnums.PlanetEnvironment.DESERT, # Use existing environment
			"cover_density": 0.3
		})
	
	if "STARSHIP" in MissionGameEnums.PlanetEnvironment:
		configs.append({
			"size": Vector2i(24, 24),
			"environment": MissionGameEnums.PlanetEnvironment.HAZARDOUS, # Use existing environment
			"cover_density": 0.4
		})
	
	for config in configs:
		var battlefield = _safe_generate_battlefield(config)
		assert_true(battlefield.size() > 0, "Battlefield generation should succeed")
		
		if battlefield.size() > 0:
			# Check for valid deployment zones
			assert_true(battlefield.has("deployment_zones"), "Battlefield should have deployment zones")
			if battlefield.has("deployment_zones"):
				assert_true(battlefield.deployment_zones.has("player"), "Should have player deployment zone")
				assert_true(battlefield.deployment_zones.has("enemy"), "Should have enemy deployment zone")
				
				# Verify deployment zones aren't empty
				assert_true(battlefield.deployment_zones.player.size() > 0, "Player deployment zone should have points")
				assert_true(battlefield.deployment_zones.enemy.size() > 0, "Enemy deployment zone should have points")
			
			# Check walkable tiles
			assert_true(battlefield.has("walkable_tiles"), "Battlefield should have walkable tiles")
			if battlefield.has("walkable_tiles"):
				assert_true(battlefield.walkable_tiles.size() > 0, "Should have walkable tiles")
				
				# Check if deployment zones are walkable
				if battlefield.has("deployment_zones"):
					var player_zone = battlefield.deployment_zones.player[0]
					var enemy_zone = battlefield.deployment_zones.enemy[0]
					
					assert_true(player_zone in battlefield.walkable_tiles,
						"Player deployment zone should be walkable")
					assert_true(enemy_zone in battlefield.walkable_tiles,
						"Enemy deployment zone should be walkable")

## Helper function to count terrain features in a battlefield
func count_terrain_features(battlefield: Dictionary) -> Dictionary:
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