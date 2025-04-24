## Battlefield Generator Crew Test Suite
## Tests the functionality of the crew battlefield generator including:
## - Initial setup and component validation
## - Character components and systems
## - Health bar functionality
## - Script and system verification
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# No need to redefine these constants as they're already in the parent class
# const GutCompatibility = preload("res://addons/gut/compatibility.gd")
# const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

# Type-safe script references
const BattlefieldGeneratorCrew := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorCrew.tscn")
# No need to reference the Character as a resource anymore
# The Character in the scene is actually a CharacterBody2D node

# Type-safe constants
const TEST_TIMEOUT := 2.0
# STABILIZE_TIME is already defined in parent class (base_test.gd)

# Type-safe instance variables
var _generator: Node2D = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize generator
	var generator_instance = BattlefieldGeneratorCrew.instantiate()
	
	# Check if we got a proper Node with proper type checking
	if is_instance_valid(generator_instance) and generator_instance is Node2D:
		_generator = generator_instance
	else:
		push_error("Failed to instantiate BattlefieldGeneratorCrew as a Node2D")
		return
		
	if not is_instance_valid(_generator):
		push_error("Failed to create generator")
		return
		
	add_child_autofree(_generator)
	track_test_node(_generator)
	
	watch_signals(_generator)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_generator = null
	await super.after_each()

# Initial Setup Tests
func test_initial_setup() -> void:
	assert_not_null(_generator, "Generator should be initialized")
	
	# Use more robust node checks with proper null checks
	if is_instance_valid(_generator):
		assert_true(_generator.has_node("Character"), "Should have character node")
		assert_true(_generator.has_node("WeaponSystem"), "Should have weapon system")
		assert_true(_generator.has_node("HealthSystem"), "Should have health system")
		assert_true(_generator.has_node("StatusEffects"), "Should have status effects")
		assert_true(_generator.has_node("HealthBar"), "Should have health bar")
	else:
		assert_false(true, "Generator is not valid for testing setup")

# Character Component Tests
func test_character_components() -> void:
	if not is_instance_valid(_generator):
		assert_false(true, "Generator is not valid for test")
		return
		
	var character_node: CharacterBody2D = TypeSafeMixin._safe_cast_to_node(_generator.get_node("Character"))
	assert_not_null(character_node, "Should have character node")
	assert_true(character_node is CharacterBody2D, "Character node should be CharacterBody2D")
	
	if not is_instance_valid(character_node):
		assert_false(true, "Character node is not valid for test")
		return
	
	var collision: CollisionShape2D = TypeSafeMixin._safe_cast_to_node(character_node.get_node("Collision"))
	assert_not_null(collision, "Should have collision shape")
	assert_true(collision is CollisionShape2D, "Collision should be CollisionShape2D")
	
	if not is_instance_valid(collision):
		assert_false(true, "Collision is not valid for test")
		return
		
	var sprite: Sprite2D = TypeSafeMixin._safe_cast_to_node(collision.get_node("Sprite"))
	assert_not_null(sprite, "Should have sprite")
	assert_true(sprite is Sprite2D, "Sprite should be Sprite2D")

# Health Bar Tests
func test_health_bar_setup() -> void:
	if not is_instance_valid(_generator):
		assert_false(true, "Generator is not valid for test")
		return
		
	var health_bar: ProgressBar = TypeSafeMixin._safe_cast_to_node(_generator.get_node("HealthBar"))
	assert_not_null(health_bar, "Should have health bar")
	assert_true(health_bar is ProgressBar, "Health bar should be ProgressBar")
	
	if not is_instance_valid(health_bar):
		assert_false(true, "Health bar is not valid for test")
		return
		
	# Use explicit bool conversion for boolean assertions
	assert_eq(health_bar.value, 100.0, "Health bar should start at 100")
	assert_false(bool(health_bar.show_percentage), "Health bar should not show percentage")
	
	# Check health bar positioning - use type-safe comparisons
	assert_eq(health_bar.position.x, -20.0, "Health bar should be properly positioned horizontally")
	assert_eq(health_bar.position.y, -30.0, "Health bar should be properly positioned vertically")
	assert_eq(health_bar.size.x, 40.0, "Health bar should have correct width")
	assert_eq(health_bar.size.y, 4.0, "Health bar should have correct height")

# Script Tests
func test_generator_script() -> void:
	assert_not_null(_generator, "Generator should be initialized")
	
	if not is_instance_valid(_generator):
		assert_false(true, "Generator is not valid for test")
		return
	
	# Check the script of the generator
	var script_class = _generator.get_script()
	assert_not_null(script_class, "Generator should have a script attached")
	
	# Verify the generator is the correct type
	assert_true(_generator is Node2D, "Generator should be a Node2D")
	
	# Test script methods if they exist using proper null checks
	if script_class and is_instance_valid(_generator):
		assert_true(_generator.has_method("take_damage"), "Generator should have take_damage method")
		assert_true(_generator.has_method("heal"), "Generator should have heal method")
		assert_true(_generator.has_method("get_current_health"), "Generator should have get_current_health method")
		assert_true(_generator.has_method("get_max_health"), "Generator should have get_max_health method")

# System Tests
func test_systems_setup() -> void:
	if not is_instance_valid(_generator):
		assert_false(true, "Generator is not valid for test")
		return
		
	var weapon_system: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("WeaponSystem"))
	var health_system: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("HealthSystem"))
	var status_effects: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("StatusEffects"))
	
	assert_not_null(weapon_system, "Should have weapon system")
	assert_not_null(health_system, "Should have health system")
	assert_not_null(status_effects, "Should have status effects")
	
	if is_instance_valid(weapon_system) and is_instance_valid(health_system) and is_instance_valid(status_effects):
		assert_true(weapon_system is Node, "Weapon system should be Node")
		assert_true(health_system is Node, "Health system should be Node")
		assert_true(status_effects is Node, "Status effects should be Node")

# Health System Tests
func test_health_system_functionality() -> void:
	if not is_instance_valid(_generator):
		assert_false(true, "Generator is not valid for test")
		return
		
	# Test health methods with proper null checks
	if is_instance_valid(_generator) and _generator.has_method("get_current_health") and _generator.has_method("get_max_health"):
		assert_eq(_generator.get_current_health(), 100.0, "Initial health should be 100")
		assert_eq(_generator.get_max_health(), 100.0, "Max health should be 100")
		
		# Test taking damage
		watch_signals(_generator)
		if _generator.has_method("take_damage"):
			_generator.take_damage(25.0)
			
			assert_signal_emitted(_generator, "health_changed")
			assert_eq(_generator.get_current_health(), 75.0, "Health should decrease after taking damage")
			
			# Test healing
			if _generator.has_method("heal"):
				_generator.heal(10.0)
				assert_eq(_generator.get_current_health(), 85.0, "Health should increase after healing")
				
				# Test health limits
				_generator.take_damage(200.0)
				assert_eq(_generator.get_current_health(), 0.0, "Health should not go below zero")
				
				_generator.heal(200.0)
				assert_eq(_generator.get_current_health(), 100.0, "Health should not exceed max")

# Performance Tests
func test_component_initialization_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(10):
		var test_generator: Node2D = BattlefieldGeneratorCrew.instantiate()
		if is_instance_valid(test_generator):
			add_child_autofree(test_generator)
			track_test_node(test_generator)
			test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should initialize 10 generators within a second")