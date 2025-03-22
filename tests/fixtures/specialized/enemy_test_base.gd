@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

## Base class for enemy-related tests
##
## Provides common functionality, type declarations, and helper methods
## for testing enemy behavior, combat, and state management.

# Core script references with type safety
const _enemy_script: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")
const _enemy_data_script: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Common test states with type safety
var _battlefield: Node2D = null
var _enemy_campaign_system: Node = null
var _combat_system: Node = null

# Test enemy states with explicit typing
const ENEMY_TEST_TEMPLATES := {
	"BASIC": {
		"health": 100.0 as float,
		"damage": 10.0 as float,
		"attack_range": 2.0 as float,
		"movement_range": 4.0 as float,
		"weapon_range": 1.0 as float,
		"behavior": GameEnums.AIBehavior.CAUTIOUS as int
	},
	"ELITE": {
		"health": 150.0 as float,
		"damage": 15.0 as float,
		"attack_range": 3.0 as float,
		"movement_range": 5.0 as float,
		"weapon_range": 2.0 as float,
		"behavior": GameEnums.AIBehavior.AGGRESSIVE as int
	}
}

# Test references with type safety
var _enemy: Enemy = null
var _enemy_data: EnemyData = null

# Core script references with type safety
# Enhanced test configuration
const PERFORMANCE_TEST_CONFIG := {
	"movement_iterations": 100 as int,
	"combat_iterations": 50 as int,
	"pathfinding_iterations": 75 as int
}

const MOBILE_TEST_CONFIG := {
	"touch_target_size": Vector2(44, 44),
	"min_frame_time": 16.67 # Target 60fps
}

# Setup methods with proper error handling
func before_each() -> void:
	await super.before_each()
	if not await setup_base_systems():
		push_error("Failed to setup base systems")
		return
	await stabilize_engine()

func after_each() -> void:
	_cleanup_test_resources()
	await super.after_each()

# Base system setup with type safety
func setup_base_systems() -> bool:
	if not _setup_battlefield():
		return false
	if not _setup_enemy_campaign_system():
		return false
	if not _setup_combat_system():
		return false
	return true

func _setup_battlefield() -> bool:
	_battlefield = Node2D.new()
	if not _battlefield:
		push_error("Failed to create battlefield")
		return false
	_battlefield.name = "TestBattlefield"
	add_child_autofree(_battlefield)
	track_test_node(_battlefield)
	return true

func _setup_enemy_campaign_system() -> bool:
	_enemy_campaign_system = Node.new()
	if not _enemy_campaign_system:
		push_error("Failed to create enemy campaign system")
		return false
	_enemy_campaign_system.name = "EnemyCampaignSystem"
	add_child_autofree(_enemy_campaign_system)
	track_test_node(_enemy_campaign_system)
	return true

func _setup_combat_system() -> bool:
	_combat_system = Node.new()
	if not _combat_system:
		push_error("Failed to create combat system")
		return false
	_combat_system.name = "CombatSystem"
	add_child_autofree(_combat_system)
	track_test_node(_combat_system)
	return true

# Resource cleanup with type safety
func _cleanup_test_resources() -> void:
	_enemy = null
	_enemy_data = null
	_battlefield = null
	_enemy_campaign_system = null
	_combat_system = null

func _capture_enemy_state(enemy: Enemy) -> Dictionary:
	if not enemy:
		push_error("Cannot capture state: enemy is null")
		return {}
	
	var result := {}
	
	# Use safe method calls with fallbacks
	result["position"] = TypeSafeMixin._safe_cast_vector2(TypeSafeMixin._call_node_method(enemy, "get_position", []))
	result["health"] = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_health", []))
	result["behavior"] = TypeSafeMixin._call_node_method_int(enemy, "get_behavior", [])
	result["movement_range"] = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_movement_range", []))
	result["weapon_range"] = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_weapon_range", []))
	
	# Add additional safety check for get_state method
	if enemy.has_method("get_state"):
		result["state"] = TypeSafeMixin._call_node_method_dict(enemy, "get_state", [])
	else:
		result["state"] = {}
		
	return result

func _capture_group_states(group: Array[Enemy]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for enemy in group:
		if not enemy:
			push_error("Cannot capture group state: enemy is null")
			continue
		states.append(_capture_enemy_state(enemy))
	return states

func _create_test_group(size: int = 3) -> Array[Enemy]:
	var group: Array[Enemy] = []
	for i in range(size):
		var enemy: Enemy = create_test_enemy()
		if not enemy:
			push_error("Failed to create test group enemy %d" % i)
			continue
		group.append(enemy)
		track_test_node(enemy)
	return group

func verify_enemy_error_handling(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	# Test invalid movement
	var invalid_pos := Vector2(-1000, -1000)
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "move_to", [invalid_pos]),
		"Enemy should handle invalid movement")
	
	# Test invalid target
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "engage_target", [null]),
		"Enemy should handle invalid target")

func verify_enemy_touch_interaction(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "handle_touch", [Vector2.ZERO])
	verify_signal_emitted(enemy, "touch_handled")

# Common setup methods
func setup_campaign_test() -> void:
	# Setup campaign test environment
	pass

# Common test data creation
func create_test_enemy_data(enemy_type: String = "BASIC") -> Resource:
	# Ensure enemy_type is valid
	if enemy_type.is_empty():
		push_error("Enemy type cannot be empty")
		enemy_type = "BASIC"
	
	# Create enemy data resource
	var data: Resource
	if _enemy_data_script and _enemy_data_script.can_instantiate():
		data = _enemy_data_script.new()
	else:
		push_error("Enemy data script is null or cannot be instantiated")
		return null
	
	# Get template data
	var template: Dictionary = ENEMY_TEST_TEMPLATES.get(enemy_type, ENEMY_TEST_TEMPLATES.get("BASIC", {}))
	if template.is_empty():
		push_error("No valid template found for enemy type: %s" % enemy_type)
		return null
	
	# Apply template data to resource
	for key in template:
		var method_name: String = "set_" + key
		if data.has_method(method_name):
			TypeSafeMixin._call_node_method_bool(data, method_name, [template[key]])
		else:
			push_warning("Method %s not found on enemy data resource" % method_name)
	
	# Track resource to prevent memory leaks
	track_test_resource(data)
	return data

# Debug helper method for troubleshooting test failures
func debug_enemy_test(enemy: Enemy) -> void:
	if not enemy:
		push_error("Cannot debug null enemy")
		return
		
	print("============ ENEMY DEBUG INFO ============")
	var debug_info := TypeSafeMixin.debug_test_object(
		enemy,
		["get_health", "get_damage", "move_to", "engage_target", "is_in_combat", "initialize"],
		["position", "health", "damage", "attack_range", "movement_range", "weapon_range"]
	)
	
	print("Enemy valid: ", debug_info.object_valid)
	print("Enemy type: ", debug_info.object_type)
	print("Enemy path: ", debug_info.object_path)
	
	print("\nMethods:")
	for method_name in debug_info.methods:
		var method_info: Dictionary = debug_info.methods[method_name]
		print("  - %s: exists=%s, callable=%s" % [method_name, method_info.exists, method_info.callable])
	
	print("\nProperties:")
	for property_name in debug_info.properties:
		var property_info: Dictionary = debug_info.properties[property_name]
		if property_info.exists:
			print("  - %s: %s (type: %s)" % [property_name, property_info.value, property_info.type])
		else:
			print("  - %s: <not found>" % property_name)
			
	# Test calling some methods directly
	print("\nDirect method calls:")
	if enemy.has_method("get_health"):
		print("  - get_health(): ", enemy.get_health())
	
	print("==========================================")