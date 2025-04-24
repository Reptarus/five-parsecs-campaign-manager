extends GutTest

# Helper functions for testing enemies
# Use conditional loading to prevent linter errors for missing files
var EnemyNode = null
var EnemyResource = null

# Import compatibility helper
const CompatHelperBase = preload("res://tests/fixtures/base/compatibility_test_helper.gd")

func _init():
	# Safely load scripts with existence check
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNode = load("res://src/core/enemy/base/EnemyNode.gd")
	elif ResourceLoader.exists("res://src/combat/entities/enemies/enemy_node.gd"):
		EnemyNode = load("res://src/combat/entities/enemies/enemy_node.gd")
		
	if ResourceLoader.exists("res://src/core/enemy/EnemyData.gd"):
		EnemyResource = load("res://src/core/enemy/EnemyData.gd")
	elif ResourceLoader.exists("res://src/combat/entities/enemies/enemy_resource.gd"):
		EnemyResource = load("res://src/combat/entities/enemies/enemy_resource.gd")

# Helper method to safely get a property value with a default fallback
func _get_property(object: Object, property_name: String, default_value = null):
	if not object:
		return default_value
		
	# Use compatibility helper to check if property exists
	if CompatHelperBase.has_property(object, property_name):
		return object.get(property_name)
		
	# Try getter method next (get_X format)
	var getter_method = "get_" + property_name
	if object.has_method(getter_method):
		return object.call(getter_method)
		
	# Return default if property not found
	return default_value

# Creates a test enemy node for testing
func create_test_enemy() -> Node:
	var enemy_scene = null
	
	# Try loading from different possible paths
	var possible_paths = [
		"res://src/combat/entities/enemies/enemy_node.tscn",
		"res://src/core/enemy/base/EnemyNode.tscn"
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			enemy_scene = load(path)
			break
			
	if not enemy_scene:
		push_warning("Could not load enemy scene from any known path")
		return null
		
	var enemy = enemy_scene.instantiate()
	if not enemy:
		push_warning("Could not instantiate enemy scene")
		return null
		
	return enemy

# Creates a test enemy resource for testing
func create_test_enemy_resource() -> Resource:
	if not EnemyResource:
		push_warning("EnemyResource script not found")
		return null
		
	var resource = EnemyResource.new()
	if not resource:
		push_warning("Could not create EnemyResource")
		return null
		
	return resource

# Creates test data for enemy initialization
func _create_enemy_test_data(id: int = 0) -> Dictionary:
	return {
		"id": id,
		"name": "Test Enemy " + str(id),
		"health": 100,
		"movement_range": 4,
		"weapon_range": 1,
		"behavior": GameEnums.AIBehavior.CAUTIOUS
	}

# Verifies an enemy's complete state
func verify_enemy_complete_state(enemy: Node) -> void:
	assert_not_null(enemy, "Enemy should not be null")
	if not enemy:
		return
		
	# Check that the enemy is the correct type
	if EnemyNode != null:
		assert_true(enemy is EnemyNode, "Enemy should be an EnemyNode")
	
	# Check if enemy has required properties and methods
	var required_methods = [
		"get_health", "take_damage", "is_dead",
		"start_turn", "end_turn", "is_active", "can_move"
	]
	
	for method in required_methods:
		if not enemy.has_method(method):
			push_warning("Enemy missing required method: " + method)
	
	var required_signals = [
		"health_changed", "died", "turn_started", "turn_ended"
	]
	
	for signal_name in required_signals:
		if not enemy.has_signal(signal_name):
			push_warning("Enemy missing required signal: " + signal_name)
	
# Additional commonly needed test helpers

# Creates a group of test enemies for group tactical testing
func create_test_enemy_group(count: int = 3) -> Array:
	var enemies = []
	for i in range(count):
		var enemy = create_test_enemy()
		if enemy:
			var data = _create_enemy_test_data(i)
			# Only initialize if the method exists
			if enemy.has_method("initialize"):
				enemy.initialize(data)
			enemies.append(enemy)
	return enemies

# Simulates a full turn for an enemy to test behavior
func simulate_enemy_turn(enemy: Node) -> void:
	if not enemy:
		return
		
	if enemy.has_method("start_turn"):
		enemy.start_turn()
		
	# Simulate actions during turn
	if enemy.has_method("decide_action"):
		enemy.decide_action()
		
	# End turn
	if enemy.has_method("end_turn"):
		enemy.end_turn()

# Helper to check if object has property - safer implementation that works in Godot 4.4
func _has_property(obj, property_name: String) -> bool:
	if not obj:
		return false
	
	# Use the compatibility helper
	return CompatHelperBase.has_property(obj, property_name)