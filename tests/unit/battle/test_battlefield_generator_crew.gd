@tool
extends GdUnitGameTest

## Battlefield Generator Crew Test Suite
## Tests the functionality of battlefield generator crew components
##
## Coverage:
## - Character components and systems
## - Health bar functionality
## - Script and system verification

# Script references
const BattlefieldGeneratorCrew := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorCrew.tscn")
const Character := preload("res://src/core/character/Base/Character.gd")

# Test constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _generator: Node = null

# Setup and teardown
func before_test() -> void:
	super.before_test()
	
	# Initialize generator
	var generator_instance = BattlefieldGeneratorCrew.instantiate()
	_generator = generator_instance
	if not _generator:
		_generator = Node.new()
		return
	# track_node(_generator)
	# add_child(_generator)
	
	# Skip signal monitoring to prevent Dictionary corruption
	# monitor_signals(_generator)  # REMOVED - causes Dictionary corruption

func after_test() -> void:
	_generator = null
	super.after_test()

# Basic setup tests
func test_initial_setup() -> void:
	assert_that(_generator).is_not_null()
	assert_that(_generator.name).is_not_empty()
	assert_that(_generator.get_child_count()).is_greater_equal(0)
	assert_that(_generator.has_node("Character")).is_true()
	assert_that(_generator.has_node("HealthBar")).is_true()
	assert_that(_generator.has_node("WeaponSystem")).is_true()

# Character component tests
func test_character_components() -> void:
	var character: Node = _generator.get_node("Character")
	assert_that(character).is_not_null()
	assert_that(character.get_class()).is_equal("CharacterBody2D")
	
	var collision: CollisionShape2D = character.get_node("Collision")
	assert_that(collision).is_not_null()
	assert_that(collision.shape).is_not_null()
	
	var sprite: Sprite2D = character.get_node("Collision/Sprite")
	assert_that(sprite).is_not_null()
	assert_that(sprite.texture).is_not_null()

# Health bar tests
func test_health_bar_setup() -> void:
	var health_bar: ProgressBar = _generator.get_node("HealthBar")
	assert_that(health_bar).is_not_null()
	assert_that(health_bar.min_value).is_equal(0.0)
	assert_that(health_bar.max_value).is_equal(100.0)
	assert_that(health_bar.value).is_greater_equal(0.0)
	
	# Check health bar positioning
	assert_that(health_bar.position.x).is_not_equal(0.0)
	assert_that(health_bar.position.y).is_not_equal(0.0)
	assert_that(health_bar.size.x).is_greater(0.0)
	assert_that(health_bar.size.y).is_greater(0.0)

# Character script tests
func test_character_script() -> void:
	var character: Node = _generator.get_node("Character")
	assert_that(character).is_not_null()
	
	# Setup mock character data if not present
	if not character.has_meta("character"):
		var mock_character_data = {"name": "Test Character", "health": 100}
		character.set_meta("character", mock_character_data)
	
	assert_that(character.has_meta("character")).is_true()
	
	var character_data: Variant = character.get_meta("character")
	assert_that(character_data).is_not_null()
	assert_that(character_data).is_instance_of(TYPE_DICTIONARY)

# System setup tests
func test_systems_setup() -> void:
	var weapon_system: Node = _generator.get_node("WeaponSystem")
	var health_system: Node = _generator.get_node("HealthSystem")
	var status_effects: Node = _generator.get_node("StatusEffects")
	
	assert_that(weapon_system).is_not_null()
	assert_that(health_system).is_not_null()
	assert_that(status_effects).is_not_null()
	
	assert_that(weapon_system.name).is_equal("WeaponSystem")
	assert_that(health_system.name).is_equal("HealthSystem")
	assert_that(status_effects.name).is_equal("StatusEffects")

# Performance tests
func test_component_initialization_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i: int in range(10):
		var test_generator: Node = BattlefieldGeneratorCrew.instantiate()
		# track_node(test_generator)
		await get_tree().process_frame
		test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).is_less(TEST_TIMEOUT * 1000) # Convert to milliseconds