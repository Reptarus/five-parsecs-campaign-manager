## Battlefield Generator Enemy Test Suite
## Tests the functionality of the enemy battlefield generator including:
## - Initial setup and component validation
## - Enemy components and systems
## - Health bar functionality
## - Script and system verification
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const BattlefieldGeneratorEnemy := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn")
const EnemyBase := preload("res://src/core/enemy/base/Enemy.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _generator: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize objects - handle the case where the generator might be a Resource
	var generator_instance = load("res://src/core/battle/generators/BattlefieldGeneratorEnemy.tscn").instantiate()
	
	# Check if BattlefieldGeneratorEnemy is a Node or Resource
	if generator_instance is Node:
		_generator = generator_instance
	elif generator_instance is Resource:
		# Create a Node wrapper for the Resource
		_generator = Node.new()
		_generator.set_name("BattlefieldGeneratorEnemyWrapper")
		_generator.set_meta("generator", generator_instance)
		
		# Create forwarding methods if needed
		push_error("BattlefieldGeneratorEnemy is expected to be a Node but was a Resource")
	else:
		push_error("Failed to create BattlefieldGeneratorEnemy instance")
	
	if _generator:
		add_child(_generator)
		track_test_node(_generator)

func after_each() -> void:
	_generator = null
	await super.after_each()

# Initial Setup Tests
func test_initial_setup() -> void:
	assert_not_null(_generator, "Generator should be initialized")
	assert_true(_generator.has_node("Collision"), "Should have collision node")
	assert_true(_generator.has_node("WeaponSystem"), "Should have weapon system")
	assert_true(_generator.has_node("HealthSystem"), "Should have health system")
	assert_true(_generator.has_node("StatusEffects"), "Should have status effects")
	assert_true(_generator.has_node("HealthBar"), "Should have health bar")

# Enemy Component Tests
func test_enemy_components() -> void:
	assert_true(_generator is Node, "Generator should be Node")
	assert_true(_generator.has_node("Collision"), "Should have collision node")
	assert_true(_generator.has_node("Collision/Enemy"), "Should have enemy sprite")
	
	var collision: CollisionShape2D = TypeSafeMixin._safe_cast_to_node(_generator.get_node("Collision"))
	assert_not_null(collision, "Should have collision shape")
	assert_true(collision is CollisionShape2D, "Collision should be CollisionShape2D")
	
	var sprite: Sprite2D = TypeSafeMixin._safe_cast_to_node(_generator.get_node("Collision/Enemy"))
	assert_not_null(sprite, "Should have sprite")
	assert_true(sprite is Sprite2D, "Sprite should be Sprite2D")

# Health Bar Tests
func test_enemy_health_bar() -> void:
	var scene = _create_test_scene()
	var enemy = _get_enemy_from_scene(scene)
	var health_bar = _find_health_bar(enemy)
	
	# Test that health bar exists and is set up correctly
	assert_not_null(health_bar, "Health bar should exist")
	assert_true(health_bar is ProgressBar, "Health bar should be a ProgressBar")
	assert_eq(health_bar.value, 100.0, "Health bar should start at 100")
	assert_false(health_bar.show_percentage, "Health bar should not show percentage")
	
	# Test health bar position and size
	# Use type-safe comparisons without assuming Vector2i
	var expected_position = Vector2(0, -20)
	var expected_size = Vector2(40, 6)
	
	assert_true(health_bar.position.is_equal_approx(expected_position),
		"Health bar should be positioned above the enemy")
	assert_true(health_bar.size.is_equal_approx(expected_size),
		"Health bar should have correct size")
	
	# Clean up
	scene.queue_free()
	await get_tree().process_frame

func test_enemy_health_updates() -> void:
	var scene = _create_test_scene()
	var enemy = _get_enemy_from_scene(scene)
	var health_bar = _find_health_bar(enemy)
	
	# Set initial health
	if enemy.has_method("set_health"):
		enemy.set_health(10, 10)
		assert_eq(health_bar.value, 100.0, "Health bar should show 100% initially")
		
		# Test reducing health
		enemy.set_health(5, 10)
		assert_eq(health_bar.value, 50.0, "Health bar should show 50% when half health")
		
		# Test zero health
		enemy.set_health(0, 10)
		assert_eq(health_bar.value, 0.0, "Health bar should show 0% when no health")
	else:
		push_error("Enemy is missing set_health method")
	
	# Clean up
	scene.queue_free()
	await get_tree().process_frame

# Create a test scene with a default enemy
func _create_test_scene() -> Node2D:
	var scene = Node2D.new()
	scene.name = "TestScene"
	add_child(scene)
	
	# Add the enemy using the generator
	_generator.generate_enemy(scene, Vector2(100, 100), "thug", 10)
	
	return scene

# Get the enemy from the scene
func _get_enemy_from_scene(scene: Node2D) -> Node2D:
	for child in scene.get_children():
		if child.name.begins_with("Enemy_"):
			return child
	return null

# Find the health bar in the enemy node
func _find_health_bar(enemy: Node2D) -> Control:
	if not enemy:
		return null
		
	for child in enemy.get_children():
		if child is ProgressBar:
			return child
	
	return null

# Script Tests
func test_enemy_script() -> void:
	assert_not_null(_generator, "Generator should be initialized")
	assert_true(_generator.has_meta("enemy"), "Generator should have enemy metadata")
	
	var enemy_data: Resource = _generator.get_meta("enemy")
	assert_not_null(enemy_data, "Enemy data should be initialized")
	assert_true(enemy_data is Resource, "Enemy data should be Resource")
	assert_true(enemy_data.get_script() == EnemyBase, "Enemy data should use EnemyBase script")

# System Tests
func test_systems_setup() -> void:
	var weapon_system: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("WeaponSystem"))
	var health_system: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("HealthSystem"))
	var status_effects: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("StatusEffects"))
	
	assert_not_null(weapon_system, "Should have weapon system")
	assert_not_null(health_system, "Should have health system")
	assert_not_null(status_effects, "Should have status effects")
	
	assert_true(weapon_system is Node, "Weapon system should be Node")
	assert_true(health_system is Node, "Health system should be Node")
	assert_true(status_effects is Node, "Status effects should be Node")

# Performance Tests
func test_component_initialization_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(10):
		var test_generator: Node = BattlefieldGeneratorEnemy.instantiate()
		add_child_autofree(test_generator)
		track_test_node(test_generator)
		test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should initialize 10 generators within 1 second")
