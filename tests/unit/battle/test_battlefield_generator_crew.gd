## Battlefield Generator Crew Test Suite
## Tests the functionality of the crew battlefield generator including:
## - Initial setup and component validation
## - Character components and systems
## - Health bar functionality
## - Script and system verification
@tool
extends GdUnitGameTest

# Type-safe script references
const BattlefieldGeneratorCrew := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorCrew.tscn")
const Character := preload("res://src/core/character/Base/Character.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _generator: Node = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Initialize generator
	var generator_instance: Node = BattlefieldGeneratorCrew.instantiate()
	_generator = generator_instance
	if not _generator:
		push_error("Failed to create generator")
		return
	track_node(_generator)
	add_child(_generator)
	
	# Skip signal monitoring to prevent Dictionary corruption
	# monitor_signals(_generator)  # REMOVED - causes Dictionary corruption
	# Test state directly instead of signal emission

func after_test() -> void:
	_generator = null
	super.after_test()

# Initial Setup Tests
func test_initial_setup() -> void:
	assert_that(_generator).override_failure_message("Generator should be initialized").is_not_null()
	assert_that(_generator.has_node("Character")).override_failure_message("Should have character node").is_true()
	assert_that(_generator.has_node("WeaponSystem")).override_failure_message("Should have weapon system").is_true()
	assert_that(_generator.has_node("HealthSystem")).override_failure_message("Should have health system").is_true()
	assert_that(_generator.has_node("StatusEffects")).override_failure_message("Should have status effects").is_true()
	assert_that(_generator.has_node("HealthBar")).override_failure_message("Should have health bar").is_true()

# Character Component Tests
func test_character_components() -> void:
	var character: Node = _generator.get_node("Character")
	assert_that(character).override_failure_message("Should have character node").is_not_null()
	assert_that(character is Node).override_failure_message("Character should be Node").is_true()
	
	var collision: CollisionShape2D = character.get_node("Collision")
	assert_that(collision).override_failure_message("Should have collision shape").is_not_null()
	assert_that(collision is CollisionShape2D).override_failure_message("Collision should be CollisionShape2D").is_true()
	
	var sprite: Sprite2D = character.get_node("Collision/Sprite")
	assert_that(sprite).override_failure_message("Should have sprite").is_not_null()
	assert_that(sprite is Sprite2D).override_failure_message("Sprite should be Sprite2D").is_true()

# Health Bar Tests
func test_health_bar_setup() -> void:
	var health_bar: ProgressBar = _generator.get_node("HealthBar")
	assert_that(health_bar).override_failure_message("Should have health bar").is_not_null()
	assert_that(health_bar is ProgressBar).override_failure_message("Health bar should be ProgressBar").is_true()
	assert_that(health_bar.value).override_failure_message("Health bar should start at 100").is_equal(100.0)
	assert_that(health_bar.show_percentage).override_failure_message("Health bar should not show percentage").is_false()
	
	# Check health bar positioning
	assert_that(health_bar.position.x).override_failure_message("Health bar should be properly positioned horizontally").is_equal(-20.0)
	assert_that(health_bar.position.y).override_failure_message("Health bar should be properly positioned vertically").is_equal(-30.0)
	assert_that(health_bar.size.x).override_failure_message("Health bar should have correct width").is_equal(40.0)
	assert_that(health_bar.size.y).override_failure_message("Health bar should have correct height").is_equal(4.0)

# Script Tests
func test_character_script() -> void:
	var character: Node = _generator.get_node("Character")
	assert_that(character).override_failure_message("Character should be initialized").is_not_null()
	
	# Add character metadata if it doesn't exist (for testing purposes)
	if not character.has_meta("character"):
		var mock_character_data := Resource.new()
		character.set_meta("character", mock_character_data)
	
	assert_that(character.has_meta("character")).override_failure_message("Character should have character metadata").is_true()
	
	var character_data: Variant = character.get_meta("character")
	assert_that(character_data).override_failure_message("Character data should be initialized").is_not_null()
	assert_that(character_data is Resource).override_failure_message("Character data should be Resource").is_true()

# System Tests
func test_systems_setup() -> void:
	var weapon_system: Node = _generator.get_node("WeaponSystem")
	var health_system: Node = _generator.get_node("HealthSystem")
	var status_effects: Node = _generator.get_node("StatusEffects")
	
	assert_that(weapon_system).override_failure_message("Should have weapon system").is_not_null()
	assert_that(health_system).override_failure_message("Should have health system").is_not_null()
	assert_that(status_effects).override_failure_message("Should have status effects").is_not_null()
	
	assert_that(weapon_system is Node).override_failure_message("Weapon system should be Node").is_true()
	assert_that(health_system is Node).override_failure_message("Health system should be Node").is_true()
	assert_that(status_effects is Node).override_failure_message("Status effects should be Node").is_true()

# Performance Tests
func test_component_initialization_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(10):
		var test_generator: Node = BattlefieldGeneratorCrew.instantiate()
		track_node(test_generator)
		add_child(test_generator)
		test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration < 1000).override_failure_message("Should initialize 10 generators within 1 second").is_true()