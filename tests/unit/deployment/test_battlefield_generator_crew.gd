extends "res://addons/gut/test.gd"

const BattlefieldGeneratorCrew = preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorCrew.tscn")
const Character = preload("res://src/core/character/Base/Character.gd")

var generator: Node2D

func before_each() -> void:
	generator = BattlefieldGeneratorCrew.instantiate()
	add_child(generator)

func after_each() -> void:
	generator.queue_free()

func test_initial_setup() -> void:
	assert_not_null(generator)
	assert_true(generator.has_node("Character"))
	assert_true(generator.has_node("WeaponSystem"))
	assert_true(generator.has_node("HealthSystem"))
	assert_true(generator.has_node("StatusEffects"))
	assert_true(generator.has_node("HealthBar"))

func test_character_components() -> void:
	var character = generator.get_node("Character")
	assert_not_null(character)
	assert_true(character is CharacterBody2D)
	assert_true(character.has_node("Collision"))
	assert_true(character.has_node("Collision/Sprite"))

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

func test_character_script() -> void:
	assert_true(generator.get_script() == Character)

func test_systems_setup() -> void:
	var weapon_system = generator.get_node("WeaponSystem")
	var health_system = generator.get_node("HealthSystem")
	var status_effects = generator.get_node("StatusEffects")
	
	assert_not_null(weapon_system)
	assert_not_null(health_system)
	assert_not_null(status_effects)
	
	assert_true(weapon_system is Node)
	assert_true(health_system is Node)
	assert_true(status_effects is Node) 