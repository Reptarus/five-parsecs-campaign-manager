@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

## Base class for enemy-related tests
##
## Provides common functionality, type declarations, and helper methods
## for testing enemy behavior, combat, and state management.

# Load scripts safely with type safety
var _enemy_script = load("res://src/core/enemy/Enemy.gd") if ResourceLoader.exists("res://src/core/enemy/Enemy.gd") else load("res://src/core/battle/enemy/Enemy.gd")
var _enemy_data_script = load("res://src/core/rivals/EnemyData.gd") if ResourceLoader.exists("res://src/core/rivals/EnemyData.gd") else null

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
		"behavior": 1 as int # GameEnums.AIBehavior.CAUTIOUS
	},
	"ELITE": {
		"health": 150.0 as float,
		"damage": 15.0 as float,
		"attack_range": 3.0 as float,
		"movement_range": 5.0 as float,
		"weapon_range": 2.0 as float,
		"behavior": 2 as int # GameEnums.AIBehavior.AGGRESSIVE
	}
}

# Test references with type safety - using Node instead of explicit Enemy type
var _enemy: Node = null
var _enemy_data: Resource = null

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

func _capture_enemy_state(enemy: Node) -> Dictionary:
	if not enemy:
		push_error("Cannot capture state: enemy is null")
		return {}
	
	var result := {}
	
	# Use safe method calls with fallbacks
	result["position"] = Compatibility.safe_call_method(enemy, "get_position", [], Vector2())
	result["health"] = Compatibility.safe_call_method(enemy, "get_health", [], 0.0)
	result["behavior"] = Compatibility.safe_call_method(enemy, "get_behavior", [], 0)
	result["movement_range"] = Compatibility.safe_call_method(enemy, "get_movement_range", [], 0.0)
	result["weapon_range"] = Compatibility.safe_call_method(enemy, "get_weapon_range", [], 0.0)
	
	# Add additional safety check for get_state method
	if enemy.has_method("get_state"):
		result["state"] = Compatibility.safe_call_method(enemy, "get_state", [], {})
	else:
		result["state"] = {}
		
	return result

func _capture_group_states(group: Array) -> Array:
	var states: Array = []
	for enemy in group:
		if not enemy:
			push_error("Cannot capture group state: enemy is null")
			continue
		states.append(_capture_enemy_state(enemy))
	return states

func _create_test_group(size: int = 3) -> Array:
	var group: Array = []
	for i in range(size):
		var enemy = await create_test_enemy()
		if not enemy:
			push_error("Failed to create test group enemy %d" % i)
			continue
		group.append(enemy)
		track_test_node(enemy)
	return group

func verify_enemy_error_handling(enemy: Node) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	# Test invalid movement
	var invalid_pos := Vector2(-1000, -1000)
	assert_false(Compatibility.safe_call_method(enemy, "move_to", [invalid_pos], false),
		"Enemy should handle invalid movement")
	
	# Test invalid target
	assert_false(Compatibility.safe_call_method(enemy, "engage_target", [null], false),
		"Enemy should handle invalid target")

func verify_enemy_touch_interaction(enemy: Node) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	watch_signals(enemy)
	Compatibility.safe_call_method(enemy, "handle_touch", [Vector2.ZERO])
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
	var data: Resource = null
	if _enemy_data_script and (_enemy_data_script.can_instantiate() if _enemy_data_script.has_method("can_instantiate") else true):
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
			Compatibility.safe_call_method(data, method_name, [template[key]])
		else:
			push_warning("Method %s not found on enemy data resource" % method_name)
	
	# Ensure resource has a valid path
	data = Compatibility.ensure_resource_path(data, "test_enemy_data")
	
	# Track resource to prevent memory leaks
	track_test_resource(data)
	return data

# Debug helper method for troubleshooting test failures
func debug_enemy_test(enemy: Node) -> void:
	if not enemy:
		push_error("Cannot debug null enemy")
		return
		
	print("============ ENEMY DEBUG INFO ============")
	print("Enemy valid: ", is_instance_valid(enemy))
	print("Enemy type: ", enemy.get_class() if enemy else "null")
	print("Enemy path: ", enemy.resource_path if enemy else "null")
	
	print("\nMethods:")
	var methods = ["get_health", "get_damage", "move_to", "engage_target", "is_in_combat", "initialize"]
	for method_name in methods:
		print("  - %s: exists=%s" % [method_name, enemy.has_method(method_name) if enemy else false])
	
	print("\nProperties:")
	var properties = ["position", "health", "damage", "attack_range", "movement_range", "weapon_range"]
	for property_name in properties:
		if enemy and enemy.has(property_name):
			print("  - %s: %s" % [property_name, enemy.get(property_name)])
		else:
			print("  - %s: <not found>" % property_name)
			
	# Test calling some methods directly
	print("\nDirect method calls:")
	if enemy and enemy.has_method("get_health"):
		print("  - get_health(): ", enemy.get_health())
	
	print("==========================================")

func create_test_enemy(enemy_type = EnemyTestType.BASIC):
	# Declare the enemy variable here
	var enemy = CharacterBody2D.new()
	if not enemy:
		push_error("Failed to create CharacterBody2D for enemy")
		return null

	enemy.name = "TestEnemy_" + str(Time.get_unix_time_from_system())

	# Add minimal required signals
	if not enemy.has_signal("mission_started"):
		enemy.add_user_signal("mission_started")

	if not enemy.has_signal("mission_completed"):
		enemy.add_user_signal("mission_completed")

	if not enemy.has_signal("experience_gained"):
		enemy.add_user_signal("experience_gained", [ {"name": "amount", "type": TYPE_INT}])

	# Add NavigationAgent2D if needed (using deferred to avoid timing issues)
	if not enemy.has_node("NavigationAgent2D"):
		var nav_agent = NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		enemy.call_deferred("add_child", nav_agent)

	# Create a custom script with proper methods
	var script = GDScript.new()
	# Add get_state() to the source code
	script.source_code = """
extends CharacterBody2D

signal experience_gained(amount)

var health = 100
var max_health = 100
var damage = 20
var level = 1
var experience = 0
var mission_complete = false
var navigation_agent = null
var current_state = "idle" # Example state variable

func _ready():
	# Ensure navigation agent is properly referenced
	if has_node("NavigationAgent2D"):
		navigation_agent = get_node("NavigationAgent2D")

func get_health():
	return health

func get_damage():
	return damage

func get_level():
	return level

func get_experience():
	return experience

func is_valid():
	return true

func add_experience(amount):
	experience += amount
	emit_signal("experience_gained", amount)
	return true

func gain_experience(amount):
	return add_experience(amount)

func set_as_leader(is_leader):
	set_meta("is_leader", is_leader)

func is_leader():
	return get_meta("is_leader", false)

# Add the missing get_state method
func get_state():
	# Return some state information, e.g., a string or enum value
	# This is just a placeholder; adjust based on what your AI needs
	return current_state

# Add other methods potentially needed by AI processing if get_state isn't enough
func process_ai_turn():
	# Placeholder for AI logic
	pass

func move_to(target_position):
    # Placeholder for movement logic
    if navigation_agent:
        navigation_agent.target_position = target_position
    else:
        # Simple movement if no nav agent
        position = position.move_toward(target_position, 10.0) # Example speed

func attack(target):
    # Placeholder for attack logic
    if is_instance_valid(target) and target.has_method("take_damage"):
        target.take_damage(damage)

func take_damage(amount):
    # Placeholder for taking damage
    health -= amount
    if health <= 0:
        health = 0
        current_state = "dead"
        # queue_free() # Or handle death state

func get_attack_damage():
    return damage

"""
	# Apply the script to the enemy node
	enemy.set_script(script)

	# Wait for a frame to ensure nodes are added properly
	await get_tree().process_frame

	add_child_autofree(enemy)
	# track_test_node is implicitly called by add_child_autofree in mobile_test_base
	# If this base class doesn't inherit from mobile_test_base, uncomment track_test_node(enemy)
	# track_test_node(enemy) # Already handled if inheriting from mobile_test_base

	# Ensure _campaign_test_enemies is initialized if not already
	# if not _campaign_test_enemies is Array:
	#	_campaign_test_enemies = [] # Uncomment if initialization needed
	# _campaign_test_enemies.append(enemy) # Uncomment if needed here

	# ... (rest of the script loading and assignment) ...

	return enemy