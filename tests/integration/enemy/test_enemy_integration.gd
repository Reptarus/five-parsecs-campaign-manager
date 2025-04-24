@tool
extends "res://tests/fixtures/helpers/enemy_test_helper.gd"

# Integration tests for enemy functionality
# Extends the new enemy_test_helper.gd which provides base enemy testing functionality

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Test variables
var _test_enemy_count: int = 3
var _enemy_manager: Node = null

func before_each() -> void:
	await super.before_each()
	
	# Create test enemies for integration tests
	var enemies = create_test_enemy_group(_test_enemy_count)
	for enemy in enemies:
		if enemy:
			track_test_node(enemy)
	
	await stabilize_engine()

func after_each() -> void:
	if _enemy_manager and is_instance_valid(_enemy_manager):
		_enemy_manager.queue_free()
	_enemy_manager = null
	
	await super.after_each()

# Basic integration tests
func test_enemy_creation() -> void:
	var enemy = create_test_enemy()
	assert_not_null(enemy, "Should be able to create an enemy")
	
	# Add additional assertions here

func test_enemy_group() -> void:
	var group = create_test_enemy_group(3)
	assert_eq(group.size(), 3, "Should create exactly 3 enemies")
	
	# Add additional assertions here
