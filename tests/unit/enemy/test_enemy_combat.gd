@tool
extends GutTest

## Tests the combat capabilities of enemy units
##
## Verifies:
## - Basic attack functionality
## - Damage calculations
## - Special attacks
## - Attack animations and effects
## - Target selection logic

# Import required helpers
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Global constants
const STABILIZE_TIME := 0.1
const COMBAT_TIMEOUT := 2.0

# Enemy test configuration
const ENEMY_TEST_CONFIG = {
	"stabilize_time": 0.1,
	"pathfinding_timeout": 1.0,
	"combat_timeout": 0.5
}

# Variables for scripts that might not exist - loaded dynamically in before_all
var EnemyNodeScript = null
var EnemyDataScript = null
var GameEnums = null

# Type-safe instance variables
var _enemy_attacker = null
var _enemy_defender = null
var _combat_system = null
var _test_enemies: Array = []

# Test nodes to track for cleanup
var _tracked_test_nodes: Array = []

# Combat result tracking
var _damage_dealt := 0
var _attack_successful := false
var _combat_signals_received := 0

# Implementation of the track_test_node function
# This tracks nodes for proper cleanup in after_each
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_test_nodes):
		_tracked_test_nodes.append(node)

# Implementation of the track_test_resource function
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
		
	# For GUT, we don't need to do anything special - resources are cleaned up by default

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	GameEnums = load("res://src/core/systems/GlobalEnums.gd") if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd") else null
	
	# Load enemy scripts
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")

func before_each() -> void:
	# Clear tracked nodes list
	_tracked_test_nodes.clear()
	
	# Reset combat tracking variables
	_damage_dealt = 0
	_attack_successful = false
	_combat_signals_received = 0
	
	# Setup the combat system
	_setup_combat_system()
	
	# Setup test enemies
	_enemy_attacker = create_test_enemy()
	_enemy_defender = create_test_enemy()
	
	# Connect combat signals
	if _enemy_attacker != null:
		if _enemy_attacker.has_signal("attack_performed"):
			_enemy_attacker.connect("attack_performed", _on_attack_performed)
		
		if _enemy_attacker.has_signal("damage_dealt"):
			_enemy_attacker.connect("damage_dealt", _on_damage_dealt)
	
	if _enemy_defender != null:
		if _enemy_defender.has_signal("damage_received"):
			_enemy_defender.connect("damage_received", _on_damage_received)
	
	await get_tree().create_timer(STABILIZE_TIME).timeout

func after_each() -> void:
	# Clean up tracked test nodes
	for node in _tracked_test_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_test_nodes.clear()
	
	# Cleanup references
	_enemy_attacker = null
	_enemy_defender = null
	_combat_system = null
	_test_enemies.clear()

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> Node:
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript != null:
		# Check if we can instantiate in a safe way
		enemy_node = EnemyNodeScript.new()
		
		if enemy_node and enemy_data:
			# Try different approaches to assign data
			if enemy_node.has_method("set_enemy_data"):
				enemy_node.set_enemy_data(enemy_data)
			elif enemy_node.has_method("initialize"):
				enemy_node.initialize(enemy_data)
			elif "enemy_data" in enemy_node:
				enemy_node.enemy_data = enemy_data
	else:
		# Fallback: create a simple Node
		push_warning("EnemyNodeScript unavailable, creating generic Node")
		enemy_node = Node.new()
		enemy_node.name = "GenericTestEnemy"
		
		# Add basic combat properties and methods
		enemy_node.set("health", 100)
		enemy_node.set("attack_power", 10)
		enemy_node.set("get_health", func(): return enemy_node.health)
		enemy_node.set("take_damage", func(amount):
			enemy_node.health -= amount
			return amount
		)
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		
	# Track locally if needed for combat tests
	if enemy_node:
		_test_enemies.append(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Function to create a test enemy resource
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	var resource = null
	
	if EnemyDataScript != null:
		resource = EnemyDataScript.new()
		if resource:
			# Initialize the resource with data
			if resource.has_method("load"):
				resource.load(data)
			elif resource.has_method("initialize"):
				resource.initialize(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# Setup Methods
func _setup_combat_system() -> void:
	_combat_system = Node.new()
	_combat_system.name = "TestCombatSystem"
	add_child_autofree(_combat_system)
	track_test_node(_combat_system)

# Signal Handler Methods
func _on_attack_performed(target, damage) -> void:
	_attack_successful = true
	_combat_signals_received += 1

func _on_damage_dealt(amount) -> void:
	_damage_dealt = amount
	_combat_signals_received += 1

func _on_damage_received(amount) -> void:
	_combat_signals_received += 1

# Basic Combat Tests
func test_basic_attack() -> void:
	# Skip if no enemies could be created
	if not _enemy_attacker or not _enemy_defender:
		pending("Test requires enemy implementation")
		return
	
	# Get initial health
	var initial_health = 0
	if _enemy_defender.has_method("get_health"):
		initial_health = _enemy_defender.get_health()
	elif "health" in _enemy_defender:
		initial_health = _enemy_defender.health
	else:
		pending("Enemy missing health property")
		return
	
	# Try different attack methods
	var attack_result = false
	if _enemy_attacker.has_method("attack"):
		attack_result = _enemy_attacker.attack(_enemy_defender)
	elif _enemy_attacker.has_method("perform_attack"):
		attack_result = _enemy_attacker.perform_attack(_enemy_defender)
	else:
		pending("Enemy missing attack method")
		return
	
	# Wait for attack to complete
	await get_tree().create_timer(COMBAT_TIMEOUT).timeout
	
	# Verify attack result
	assert_true(attack_result, "Attack should be successful")
	
	# Get final health
	var final_health = 0
	if _enemy_defender.has_method("get_health"):
		final_health = _enemy_defender.get_health()
	elif "health" in _enemy_defender:
		final_health = _enemy_defender.health
	
	# Health should be reduced
	assert_lt(final_health, initial_health, "Attack should reduce health")

# Damage Calculation Tests
func test_damage_calculation() -> void:
	# Skip if no enemies could be created
	if not _enemy_attacker or not _enemy_defender:
		pending("Test requires enemy implementation")
		return
	
	# Set attack power and defense
	var attack_power = 20
	var defense = 5
	var expected_damage = attack_power - defense
	
	# Configure attacker
	if _enemy_attacker.has_method("set_attack_power"):
		_enemy_attacker.set_attack_power(attack_power)
	elif "attack_power" in _enemy_attacker:
		_enemy_attacker.attack_power = attack_power
	else:
		pending("Enemy missing attack power property")
		return
	
	# Configure defender
	if _enemy_defender.has_method("set_defense"):
		_enemy_defender.set_defense(defense)
	elif "defense" in _enemy_defender:
		_enemy_defender.defense = defense
	else:
		pending("Enemy missing defense property")
		return
	
	# Perform attack
	if _enemy_attacker.has_method("attack"):
		_enemy_attacker.attack(_enemy_defender)
	elif _enemy_attacker.has_method("perform_attack"):
		_enemy_attacker.perform_attack(_enemy_defender)
	else:
		pending("Enemy missing attack method")
		return
	
	# Wait for attack to complete
	await get_tree().create_timer(COMBAT_TIMEOUT).timeout
	
	# Verify damage
	if _combat_signals_received > 0:
		assert_eq(_damage_dealt, expected_damage, "Damage calculation should be attack - defense")
	else:
		# If no signals, check direct health reduction
		var expected_health = 100 - expected_damage
		
		var final_health = 0
		if _enemy_defender.has_method("get_health"):
			final_health = _enemy_defender.get_health()
		elif "health" in _enemy_defender:
			final_health = _enemy_defender.health
		
		assert_eq(final_health, expected_health, "Health should be reduced by attack - defense")

# Special Attack Tests
func test_special_attack() -> void:
	# This test requires special attack functionality
	# Skip if the method doesn't exist
	if not _enemy_attacker or not _enemy_defender:
		pending("Test requires enemy implementation")
		return
	
	if not _enemy_attacker.has_method("special_attack") and not _enemy_attacker.has_method("perform_special_attack"):
		pending("Enemy missing special attack method")
		return
	
	# Get initial health
	var initial_health = 0
	if _enemy_defender.has_method("get_health"):
		initial_health = _enemy_defender.get_health()
	elif "health" in _enemy_defender:
		initial_health = _enemy_defender.health
	
	# Perform special attack
	var attack_result = false
	if _enemy_attacker.has_method("special_attack"):
		attack_result = _enemy_attacker.special_attack(_enemy_defender)
	elif _enemy_attacker.has_method("perform_special_attack"):
		attack_result = _enemy_attacker.perform_special_attack(_enemy_defender)
	
	# Wait for attack to complete
	await get_tree().create_timer(COMBAT_TIMEOUT).timeout
	
	# Verify attack result
	assert_true(attack_result, "Special attack should be successful")
	
	# Get final health
	var final_health = 0
	if _enemy_defender.has_method("get_health"):
		final_health = _enemy_defender.get_health()
	elif "health" in _enemy_defender:
		final_health = _enemy_defender.health
	
	# Health should be reduced
	assert_lt(final_health, initial_health, "Special attack should reduce health")

# Target Selection Tests
func test_target_selection() -> void:
	# Create multiple potential targets
	var targets = []
	for i in range(3):
		var target = create_test_enemy()
		if target:
			targets.append(target)
	
	# Skip if attacker or targets couldn't be created
	if not _enemy_attacker or targets.size() == 0:
		pending("Test requires enemy implementation")
		return
	
	# Test target selection if the method exists
	if _enemy_attacker.has_method("select_target"):
		var selected_target = _enemy_attacker.select_target(targets)
		assert_not_null(selected_target, "Should select a valid target")
		assert_true(selected_target in targets, "Selected target should be in targets list")
	elif _enemy_attacker.has_method("get_best_target"):
		var best_target = _enemy_attacker.get_best_target(targets)
		assert_not_null(best_target, "Should select a valid target")
		assert_true(best_target in targets, "Selected target should be in targets list")
	else:
		pending("Enemy missing target selection method")

# Verify enemy is in a valid state for tests
func verify_enemy_complete_state(enemy) -> void:
	assert_not_null(enemy, "Enemy should be non-null")
	
	if enemy.has_method("get_health"):
		assert_gt(enemy.get_health(), 0, "Enemy health should be positive")
	else:
		push_warning("Enemy missing get_health method, skipping health verification")

# Helper function to verify that one value is less than another
func assert_lt(val1, val2, message: String = "") -> void:
	assert_true(val1 < val2, message if message else str(val1) + " < " + str(val2))

# Helper function to safely get a property with a default value
func _get_property(obj: Object, prop: String, default_val = null):
	if not is_instance_valid(obj):
		return default_val
	
	if prop in obj:
		return obj.get(prop)
	return default_val

# Helper function to create enemy test data
func _create_enemy_test_data(data_type: int = 0) -> Dictionary:
	var data = {
		"id": "test_enemy_" + str(data_type),
		"name": "Test Enemy " + str(data_type),
		"health": 100,
		"max_health": 100,
		"damage": 10,
		"armor": 2,
		"movement_range": 4,
		"weapon_range": 1,
		"behavior": 0 # Default to CAUTIOUS behavior (0)
	}
	
	# Check if GameEnums has AIBehavior and set properly if it does
	if GameEnums != null and "AIBehavior" in GameEnums:
		if "CAUTIOUS" in GameEnums.AIBehavior:
			data.behavior = GameEnums.AIBehavior.CAUTIOUS
	
	return data
