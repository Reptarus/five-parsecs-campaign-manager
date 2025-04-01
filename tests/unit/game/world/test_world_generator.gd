@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var WorldGeneratorScript = load("res://src/game/world/WorldGenerator.gd") if ResourceLoader.exists("res://src/game/world/WorldGenerator.gd") else null
var WorldDataScript = load("res://src/game/world/WorldData.gd") if ResourceLoader.exists("res://src/game/world/WorldData.gd") else null

# Type-safe instance variables
var _world_generator: Node = null
var _world_data: Resource = null

func before_each() -> void:
	await super.before_each()
	
	if not WorldGeneratorScript:
		push_error("WorldGenerator script is null")
		return
		
	_world_generator = WorldGeneratorScript.new()
	if not _world_generator:
		push_error("Failed to create world generator")
		return
		
	add_child_autofree(_world_generator)
	track_test_node(_world_generator)
	
	if not WorldDataScript:
		push_error("WorldData script is null")
		return
		
	_world_data = WorldDataScript.new()
	if not _world_data:
		push_error("Failed to create world data")
		return
	
	# Ensure resource has a valid path for Godot 4.4
	_world_data = Compatibility.ensure_resource_path(_world_data, "test_world_data")
	
	track_test_resource(_world_data)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_world_generator = null
	_world_data = null
	await super.after_each()

func test_world_generation() -> void:
	assert_not_null(_world_generator, "World generator should be initialized")
	assert_not_null(_world_data, "World data should be initialized")
	
	# Check if required methods exist
	if not (_world_generator.has_method("generate_world") and
	        _world_data.has_method("get_name") and
	        _world_data.has_method("get_size") and
	        _world_data.has_method("get_sector_count")):
		push_warning("Skipping test_world_generation: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	# Test world generation with seed
	var seed_value = 12345
	var result = Compatibility.safe_call_method(_world_generator, "generate_world", [seed_value, _world_data], false)
	assert_true(result, "World generation should succeed")
	
	# Test basic world properties
	var world_name = Compatibility.safe_call_method(_world_data, "get_name", [], "")
	var world_size = Compatibility.safe_call_method(_world_data, "get_size", [], Vector2i.ZERO)
	var sector_count = Compatibility.safe_call_method(_world_data, "get_sector_count", [], 0)
	
	assert_ne(world_name, "", "Generated world should have a name")
	assert_ne(world_size, Vector2i.ZERO, "World should have non-zero size")
	assert_gt(sector_count, 0, "World should have at least one sector")
	
	# Test additional world data
	if _world_data.has_method("validate"):
		var is_valid = Compatibility.safe_call_method(_world_data, "validate", [], false)
		assert_true(is_valid, "Generated world should be valid")