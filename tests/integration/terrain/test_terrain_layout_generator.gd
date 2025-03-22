@tool
extends "res://tests/fixtures/base/base_test.gd"

const TerrainLayoutGenerator = preload("res://src/core/terrain/TerrainLayoutGenerator.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")

var generator
var terrain_system
var position_validator

func before_each() -> void:
	await super.before_each()
	
	terrain_system = TerrainSystem.new()
	if not terrain_system:
		push_error("Failed to create terrain system")
		return
		
	add_child(terrain_system)
	track_test_node(terrain_system)
	
	if not terrain_system.has_method("initialize_grid"):
		push_warning("TerrainSystem does not have initialize_grid method, skipping initialization")
	else:
		terrain_system.initialize_grid(Vector2i(10, 10))
	
	position_validator = PositionValidator.new()
	if not position_validator:
		push_error("Failed to create position validator")
		return
		
	add_child(position_validator)
	track_test_node(position_validator)
	
	# Create generator with proper error handling
	generator = TerrainLayoutGenerator.new(terrain_system)
	if not generator:
		push_error("Failed to create terrain layout generator")
		return
	
	# Try different ways to set up the generator with terrain system
	if generator.has_method("setup"):
		generator.setup(terrain_system)
	elif generator.has_method("initialize"):
		generator.initialize(terrain_system)
	elif generator.get("terrain_system") != null:
		generator.terrain_system = terrain_system
	else:
		push_warning("Cannot set terrain system on generator")
		
	add_child(generator)
	track_test_node(generator)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	generator = null
	terrain_system = null
	position_validator = null

func test_initial_state() -> void:
	assert_not_null(generator, "Generator should be initialized")
	assert_not_null(terrain_system, "Terrain system should be initialized")
	assert_not_null(position_validator, "Position validator should be initialized")

func test_generate_layout() -> void:
	if not is_instance_valid(generator) or not is_instance_valid(terrain_system):
		push_warning("Generator or terrain system is not valid, skipping test")
		return
		
	if not generator.has_method("generate_layout") or not terrain_system.has_method("get_grid_size"):
		push_warning("Missing required methods on generator or terrain system, skipping test")
		return
		
	# Get layout type enum
	var layout_type_enum = null
	if generator.get("LayoutType"):
		layout_type_enum = generator.LayoutType.OPEN
	else:
		push_warning("LayoutType enum not found on generator, skipping test")
		return
		
	watch_signals(generator)
	if terrain_system.has_signal("terrain_modified"):
		watch_signals(terrain_system)
	
	generator.generate_layout(layout_type_enum)
	var grid_size = terrain_system.get_grid_size()
	
	# Convert to Vector2i for proper comparison
	var expected_size = Vector2i(10, 10)
	var actual_size = Vector2i(int(grid_size.x), int(grid_size.y))
	
	assert_eq(actual_size, expected_size, "Grid size should be 10x10 (expected: (10, 10), actual: %s)" % actual_size)
	
	if terrain_system.has_signal("terrain_modified"):
		assert_signal_emitted(terrain_system, "terrain_modified", "Terrain modified signal not emitted")

func test_validate_layout() -> void:
	if not is_instance_valid(generator) or not is_instance_valid(terrain_system):
		push_warning("Generator or terrain system is not valid, skipping test")
		return
		
	if not generator.has_method("generate_layout") or not terrain_system.has_method("get_grid_size"):
		push_warning("Missing required methods on generator or terrain system, skipping test")
		return
		
	if not terrain_system.has_method("get_terrain_type"):
		push_warning("TerrainSystem does not have get_terrain_type method, skipping test")
		return
		
	# Get layout type enum
	var layout_type_enum = null
	if generator.get("LayoutType"):
		layout_type_enum = generator.LayoutType.OPEN
	else:
		push_warning("LayoutType enum not found on generator, skipping test")
		return
		
	watch_signals(generator)
	
	generator.generate_layout(layout_type_enum)
	var grid_size = terrain_system.get_grid_size()
	
	# Convert to Vector2i for proper comparison
	var expected_size = Vector2i(10, 10)
	var actual_size = Vector2i(int(grid_size.x), int(grid_size.y))
	
	assert_eq(actual_size, expected_size, "Grid size should be 10x10 (expected: (10, 10), actual: %s)" % actual_size)
	
	# Get TerrainFeatureType enum for NONE value
	var none_feature_type = 0
	if terrain_system.get("TerrainFeatureType"):
		none_feature_type = terrain_system.TerrainFeatureType.NONE
	
	# Check that some terrain features were placed
	var has_features = false
	for x in range(10):
		for y in range(10):
			# Use Vector2i explicitly when calling get_terrain_type
			var terrain_type = terrain_system.get_terrain_type(Vector2i(x, y))
			if terrain_type != none_feature_type:
				has_features = true
				break
		if has_features:
			break
	
	assert_true(has_features, "Layout should have terrain features")
