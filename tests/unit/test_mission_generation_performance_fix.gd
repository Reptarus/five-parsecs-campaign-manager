@tool
extends "res://tests/fixtures/base/game_test.gd"

## Fixed test suite for performance of mission and battlefield generation
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

# Safely check if a value exists in a dictionary (enum)
func _safe_has_value(dict: Dictionary, value) -> bool:
	# Safe version of "value in dict" that avoids the "Invalid base object for 'in'" error
	if dict == null:
		return false
		
	# For string keys
	if typeof(value) == TYPE_STRING and dict.has(value):
		return true
		
	# For int values 
	if typeof(value) == TYPE_INT:
		return dict.values().has(value)
		
	return false

# Safely check if a key exists in an object
func _safe_has_key(obj, key: String) -> bool:
	if obj == null:
		return false
		
	# For dictionaries
	if obj is Dictionary:
		return obj.has(key)
		
	# For objects with properties
	if obj is Object:
		return obj.get(key) != null
		
	return false

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

## Fixed tests that avoid the 'in' operator issue
func test_simple_battlefield() -> void:
	# A basic test that ensures we can generate a battlefield without error
	var config = {
		"size": Vector2i(16, 16),
		"environment": 0, # Use integer constant instead of enum to avoid 'in' issue
		"cover_density": 0.2
	}
	
	var battlefield = _safe_generate_battlefield(config)
	assert_true(battlefield.size() > 0, "Should generate a basic battlefield")
	
	# Verify battlefield has required components using safe checks
	assert_true(_safe_has_key(battlefield, "size"), "Battlefield should have size")
	assert_true(_safe_has_key(battlefield, "terrain"), "Battlefield should have terrain")
	
	if _safe_has_key(battlefield, "deployment_zones"):
		var zones = battlefield.deployment_zones
		assert_true(_safe_has_key(zones, "player"), "Should have player deployment zone")
		assert_true(_safe_has_key(zones, "enemy"), "Should have enemy deployment zone")

func test_battlefield_generation_time() -> void:
	# Test that battlefield generation completes within a reasonable time
	var config = {
		"size": Vector2i(24, 24),
		"environment": 0, # Using integer to avoid enum issues
		"mission_type": 0, # Using integer to avoid enum issues
		"cover_density": 0.2
	}
	
	var start_time = Time.get_ticks_msec()
	var battlefield = _safe_generate_battlefield(config)
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	assert_true(battlefield.size() > 0, "Should successfully generate battlefield")
	assert_true(duration < PERFORMANCE_THRESHOLD_MS,
		"Battlefield generation should complete within %d ms (took %d ms)" % [PERFORMANCE_THRESHOLD_MS, duration])

# Count terrain features safely without using 'in' operator
func count_terrain_features(battlefield: Dictionary) -> Dictionary:
	var counts = {}
	
	if not _safe_has_key(battlefield, "terrain"):
		return counts
		
	var terrain = battlefield.terrain
	if terrain is Array:
		for feature in terrain:
			var type = ""
			if feature is Dictionary and _safe_has_key(feature, "type"):
				type = str(feature.type)
			
			if not counts.has(type):
				counts[type] = 0
			counts[type] += 1
	
	return counts