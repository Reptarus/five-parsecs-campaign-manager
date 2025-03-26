@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/Enemy.gd")

# Type-safe instance variables
var _enemy_data: Resource = null

func before_each() -> void:
	await super.before_each()
	
	if not EnemyDataScript:
		push_error("EnemyData script is null")
		return
		
	_enemy_data = EnemyDataScript.new()
	if not _enemy_data:
		push_error("Failed to create enemy data")
		return
	
	# Ensure resource has a valid path for Godot 4.4
	_enemy_data = Compatibility.ensure_resource_path(_enemy_data, "test_enemy_data")
	
	# Initialize with test values
	Compatibility.safe_call_method(_enemy_data, "set_name", ["Test Enemy"])
	Compatibility.safe_call_method(_enemy_data, "set_health", [100])
	Compatibility.safe_call_method(_enemy_data, "set_max_health", [100])
	Compatibility.safe_call_method(_enemy_data, "set_damage", [10])
	Compatibility.safe_call_method(_enemy_data, "set_defense", [5])
	Compatibility.safe_call_method(_enemy_data, "set_speed", [3])
	
	track_test_resource(_enemy_data)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_enemy_data = null
	await super.after_each()

func test_enemy_data_initialization() -> void:
	assert_not_null(_enemy_data, "Enemy data should be initialized")
	
	# Test basic properties
	var name = Compatibility.safe_call_method(_enemy_data, "get_name", [], "")
	var health = Compatibility.safe_call_method(_enemy_data, "get_health", [], 0)
	var damage = Compatibility.safe_call_method(_enemy_data, "get_damage", [], 0)
	
	assert_eq(name, "Test Enemy", "Enemy should have the correct name")
	assert_eq(health, 100, "Enemy should have correct health")
	assert_eq(damage, 10, "Enemy should have correct damage")

func test_enemy_stat_modification() -> void:
	# Test modifying stats
	Compatibility.safe_call_method(_enemy_data, "set_damage", [15])
	var damage = Compatibility.safe_call_method(_enemy_data, "get_damage", [], 0)
	assert_eq(damage, 15, "Damage should be updated")
	
	Compatibility.safe_call_method(_enemy_data, "take_damage", [20])
	var health = Compatibility.safe_call_method(_enemy_data, "get_health", [], 0)
	assert_eq(health, 80, "Health should be reduced by damage")
	
	Compatibility.safe_call_method(_enemy_data, "heal", [10])
	health = Compatibility.safe_call_method(_enemy_data, "get_health", [], 0)
	assert_eq(health, 90, "Health should be increased by healing")

func test_enemy_serialization() -> void:
	# Test serialization
	var serialized = Compatibility.safe_call_method(_enemy_data, "to_dict", [], {})
	assert_not_null(serialized, "Serialized data should not be null")
	assert_true(serialized is Dictionary, "Serialized data should be a Dictionary")
	
	# Verify serialized data
	assert_eq(serialized.get("name", ""), "Test Enemy", "Serialized name should match")
	assert_eq(serialized.get("health", 0), 100, "Serialized health should match")
	assert_eq(serialized.get("damage", 0), 10, "Serialized damage should match")
	
	# Test deserialization
	var new_enemy_data = EnemyDataScript.new()
	new_enemy_data = Compatibility.ensure_resource_path(new_enemy_data, "test_enemy_data_2")
	
	var result = Compatibility.safe_call_method(new_enemy_data, "from_dict", [serialized], false)
	assert_true(result, "Deserialization should succeed")
	
	# Verify deserialized data
	var new_name = Compatibility.safe_call_method(new_enemy_data, "get_name", [], "")
	var new_health = Compatibility.safe_call_method(new_enemy_data, "get_health", [], 0)
	var new_damage = Compatibility.safe_call_method(new_enemy_data, "get_damage", [], 0)
	
	assert_eq(new_name, "Test Enemy", "Deserialized name should match")
	assert_eq(new_health, 100, "Deserialized health should match")
	assert_eq(new_damage, 10, "Deserialized damage should match")
	
	track_test_resource(new_enemy_data)