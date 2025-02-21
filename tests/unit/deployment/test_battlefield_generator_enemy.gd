extends "res://addons/gut/test.gd"

const BattlefieldGeneratorEnemy = preload("res://src/data/resources/Deployment/Units/BattlefieldGeneratorEnemy.tscn")
const EnemyBase = preload("res://src/core/enemy/base/Enemy.gd")

var generator: CharacterBody2D

func before_each() -> void:
	generator = BattlefieldGeneratorEnemy.instantiate()
	add_child(generator)
	if not is_instance_valid(generator) or not generator.is_inside_tree():
		push_error("Failed to add generator node")
		return

func after_each() -> void:
	if is_instance_valid(generator):
		generator.queue_free()
	generator = null

func test_initial_setup() -> void:
	assert_not_null(generator, "Generator should be initialized")
	assert_true(generator.has_node("Collision"), "Should have collision node")
	assert_true(generator.has_node("WeaponSystem"), "Should have weapon system")
	assert_true(generator.has_node("HealthSystem"), "Should have health system")
	assert_true(generator.has_node("StatusEffects"), "Should have status effects")
	assert_true(generator.has_node("HealthBar"), "Should have health bar")

func test_enemy_components() -> void:
	assert_true(generator is CharacterBody2D, "Generator should be CharacterBody2D")
	assert_true(generator.has_node("Collision"), "Should have collision node")
	assert_true(generator.has_node("Collision/Enemy"), "Should have enemy sprite")
	
	var collision: CollisionShape2D = generator.get_node("Collision")
	assert_not_null(collision, "Should have collision shape")
	assert_true(collision is CollisionShape2D, "Collision should be CollisionShape2D")
	
	var sprite: Sprite2D = generator.get_node("Collision/Enemy")
	assert_not_null(sprite, "Should have sprite")
	assert_true(sprite is Sprite2D, "Sprite should be Sprite2D")

func test_health_bar_setup() -> void:
	var health_bar: ProgressBar = generator.get_node("HealthBar")
	assert_not_null(health_bar, "Should have health bar")
	assert_true(health_bar is ProgressBar, "Health bar should be ProgressBar")
	assert_eq(health_bar.value, 100.0, "Health bar should start at 100")
	assert_false(health_bar.show_percentage, "Health bar should not show percentage")
	
	# Check health bar positioning
	assert_eq(health_bar.position.x, -20.0, "Health bar should be properly positioned horizontally")
	assert_eq(health_bar.position.y, -30.0, "Health bar should be properly positioned vertically")
	assert_eq(health_bar.size.x, 40.0, "Health bar should have correct width")
	assert_eq(health_bar.size.y, 4.0, "Health bar should have correct height")

func test_enemy_script() -> void:
	var script: Script = generator.get_script()
	assert_not_null(script, "Generator should have a script")
	assert_eq(script, EnemyBase, "Generator should use Enemy script")

func test_systems_setup() -> void:
	var weapon_system: Node = generator.get_node("WeaponSystem")
	var health_system: Node = generator.get_node("HealthSystem")
	var status_effects: Node = generator.get_node("StatusEffects")
	
	assert_not_null(weapon_system, "Should have weapon system")
	assert_not_null(health_system, "Should have health system")
	assert_not_null(status_effects, "Should have status effects")
	
	assert_true(weapon_system is Node, "Weapon system should be Node")
	assert_true(health_system is Node, "Health system should be Node")
	assert_true(status_effects is Node, "Status effects should be Node")