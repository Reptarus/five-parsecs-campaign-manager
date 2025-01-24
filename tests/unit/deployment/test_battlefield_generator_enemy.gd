extends "res://addons/gut/test.gd"

const BattlefieldGeneratorEnemy = preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn")
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

var generator: CharacterBody2D

func before_each() -> void:
	generator = BattlefieldGeneratorEnemy.instantiate()
	add_child(generator)

func after_each() -> void:
	generator.queue_free()

func test_initial_setup() -> void:
	assert_not_null(generator)
	assert_true(generator.has_node("Collision"))
	assert_true(generator.has_node("WeaponSystem"))
	assert_true(generator.has_node("HealthSystem"))
	assert_true(generator.has_node("StatusEffects"))
	assert_true(generator.has_node("HealthBar"))

func test_enemy_components() -> void:
	assert_true(generator is CharacterBody2D)
	assert_true(generator.has_node("Collision"))
	assert_true(generator.has_node("Collision/Enemy"))
	
	var collision = generator.get_node("Collision")
	assert_not_null(collision)
	assert_true(collision is CollisionShape2D)
	
	var sprite = generator.get_node("Collision/Enemy")
	assert_not_null(sprite)
	assert_true(sprite is Sprite2D)

func test_health_bar_setup() -> void:
	var health_bar = generator.get_node("HealthBar")
	assert_not_null(health_bar)
	assert_true(health_bar is ProgressBar)
	assert_eq(health_bar.value, 100.0)
	assert_false(health_bar.show_percentage)
	
	# Check health bar positioning
	assert_eq(health_bar.position.x, -20.0)
	assert_eq(health_bar.position.y, -30.0)
	assert_eq(health_bar.size.x, 40.0)
	assert_eq(health_bar.size.y, 4.0)

func test_enemy_script() -> void:
	assert_true(generator.get_script() == Enemy)

func test_systems_setup() -> void:
	var weapon_system = generator.get_node("WeaponSystem")
	var health_system = generator.get_node("HealthSystem")
	var status_effects = generator.get_node("StatusEffects")
	
	assert_not_null(weapon_system)
	assert_not_null(health_system)
	assert_not_null(status_effects)
	
	assert_true(weapon_system is Node)
	assert_true(health_system is Node)
	assert_true(status_effects is Node)