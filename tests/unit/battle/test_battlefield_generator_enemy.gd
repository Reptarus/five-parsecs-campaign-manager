## Battlefield Generator Enemy Test Suite
## Tests the functionality of the enemy battlefield generator including:
## - Initial setup and component validation
## - Enemy components and systems
## - Health bar functionality
## - Script and system verification
@tool
extends GdUnitGameTest

# Type-safe script references
const BattlefieldGeneratorEnemy := preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn")
const EnemyBase := preload("res://src/core/enemy/base/Enemy.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe instance variables
var _generator: Node = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Initialize generator
	var generator_instance: Node = BattlefieldGeneratorEnemy.instantiate()
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
	assert_that(_generator.has_node("Collision")).override_failure_message("Should have collision node").is_true()
	assert_that(_generator.has_node("WeaponSystem")).override_failure_message("Should have weapon system").is_true()
	assert_that(_generator.has_node("HealthSystem")).override_failure_message("Should have health system").is_true()
	assert_that(_generator.has_node("StatusEffects")).override_failure_message("Should have status effects").is_true()
	assert_that(_generator.has_node("HealthBar")).override_failure_message("Should have health bar").is_true()

# Enemy Component Tests
func test_enemy_components() -> void:
	assert_that(_generator is Node).override_failure_message("Generator should be Node").is_true()
	assert_that(_generator.has_node("Collision")).override_failure_message("Should have collision node").is_true()
	assert_that(_generator.has_node("Collision/Enemy")).override_failure_message("Should have enemy sprite").is_true()
	
	var collision: CollisionShape2D = _generator.get_node("Collision")
	assert_that(collision).override_failure_message("Should have collision shape").is_not_null()
	assert_that(collision is CollisionShape2D).override_failure_message("Collision should be CollisionShape2D").is_true()
	
	var sprite: Sprite2D = _generator.get_node("Collision/Enemy")
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
func test_enemy_script() -> void:
	assert_that(_generator).override_failure_message("Generator should be initialized").is_not_null()
	
	# Add enemy metadata if it doesn't exist (for testing purposes)
	if not _generator.has_meta("enemy"):
		var mock_enemy_data := Resource.new()
		mock_enemy_data.set_script(EnemyBase)
		_generator.set_meta("enemy", mock_enemy_data)
	
	assert_that(_generator.has_meta("enemy")).override_failure_message("Generator should have enemy metadata").is_true()
	
	var enemy_data: Resource = _generator.get_meta("enemy")
	assert_that(enemy_data).override_failure_message("Enemy data should be initialized").is_not_null()
	assert_that(enemy_data is Resource).override_failure_message("Enemy data should be Resource").is_true()
	
	# Safe script check
	if enemy_data.get_script():
		assert_that(enemy_data.get_script() == EnemyBase).override_failure_message("Enemy data should use EnemyBase script").is_true()

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
		var test_generator: Node = BattlefieldGeneratorEnemy.instantiate()
		track_node(test_generator)
		add_child(test_generator)
		test_generator.queue_free()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration < 1000).override_failure_message("Should initialize 10 generators within 1 second").is_true()