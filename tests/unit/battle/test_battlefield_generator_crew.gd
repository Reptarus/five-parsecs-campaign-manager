## Battlefield Generator Crew Test Suite
## Tests the functionality of the crew battlefield generator including:
## - Initial setup and component validation
## - Character components and systems
## - Health bar functionality
## - Script and system verification
@tool
extends GameTest

# Type-safe script references
const BattlefieldGeneratorCrew := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorCrew.tscn")
const Character := preload("res://src/core/character/Base/Character.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _generator: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize generator
	var generator_instance: Node = BattlefieldGeneratorCrew.instantiate()
	_generator = TypeSafeMixin._safe_cast_to_node(generator_instance)
	if not _generator:
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
	assert_true(_generator.has_node("Character"), "Should have character node")
	assert_true(_generator.has_node("WeaponSystem"), "Should have weapon system")
	assert_true(_generator.has_node("HealthSystem"), "Should have health system")
	assert_true(_generator.has_node("StatusEffects"), "Should have status effects")
	assert_true(_generator.has_node("HealthBar"), "Should have health bar")

# Character Component Tests
func test_character_components() -> void:
	var character: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("Character"))
	assert_not_null(character, "Should have character node")
	assert_true(character is Node, "Character should be Node")
	
	var collision: CollisionShape2D = TypeSafeMixin._safe_cast_to_node(character.get_node("Collision"))
	assert_not_null(collision, "Should have collision shape")
	assert_true(collision is CollisionShape2D, "Collision should be CollisionShape2D")
	
	var sprite: Sprite2D = TypeSafeMixin._safe_cast_to_node(character.get_node("Collision/Sprite"))
	assert_not_null(sprite, "Should have sprite")
	assert_true(sprite is Sprite2D, "Sprite should be Sprite2D")

# Health Bar Tests
func test_health_bar_setup() -> void:
	var health_bar: ProgressBar = TypeSafeMixin._safe_cast_to_node(_generator.get_node("HealthBar"))
	assert_not_null(health_bar, "Should have health bar")
	assert_true(health_bar is ProgressBar, "Health bar should be ProgressBar")
	assert_eq(health_bar.value, 100.0, "Health bar should start at 100")
	assert_false(health_bar.show_percentage, "Health bar should not show percentage")
	
	# Check health bar positioning
	assert_eq(health_bar.position.x, -20.0, "Health bar should be properly positioned horizontally")
	assert_eq(health_bar.position.y, -30.0, "Health bar should be properly positioned vertically")
	assert_eq(health_bar.size.x, 40.0, "Health bar should have correct width")
	assert_eq(health_bar.size.y, 4.0, "Health bar should have correct height")

# Script Tests
func test_character_script() -> void:
	var character: Node = TypeSafeMixin._safe_cast_to_node(_generator.get_node("Character"))
	assert_not_null(character, "Character should be initialized")
	assert_true(character.has_meta("character"), "Character should have character metadata")
	
	var character_data: Variant = character.get_meta("character")
	assert_not_null(character_data, "Character data should be initialized")
	assert_true(character_data is Resource, "Character data should be Resource")

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
		var test_generator: Node = BattlefieldGeneratorCrew.instantiate()
		add_child_autofree(test_generator)
		track_test_node(test_generator)
		test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should initialize 10 generators within 1 second")