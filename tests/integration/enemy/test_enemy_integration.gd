@tool
@warning_ignore("return_value_discarded")
	extends GdUnitGameTest

# Import GameEnums for testing
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe mock script creation for testing
var MockEnemyScript: GDScript

# Type-safe instance variables
var _enemy: Node
var _tracked_enemies: @warning_ignore("unsafe_call_argument")
	Array[Node] = []

func before_test() -> void:
	super.before_test()
	
	# Create mock enemy script
	_create_mock_enemy_script()
	
	# Initialize test enemy
	_enemy = Node.new()
	_enemy.name = "TestEnemy"
	@warning_ignore("unsafe_method_access")
	_enemy.set_script(MockEnemyScript)
	@warning_ignore("return_value_discarded")
	auto_free(_enemy) # Use auto_free for proper resource management
	
	# Initialize enemy with test data
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	@warning_ignore("unsafe_method_access")
	await get_tree().process_frame

func after_test() -> void:
	_cleanup_test_enemies()
	_enemy = null
	super.after_test()

func _create_mock_enemy_script() -> void:
	MockEnemyScript = GDScript.new()
	MockEnemyScript.source_code = '''
extends Node

var enemy_data: Dictionary = {}
var health: int = 100
var max_health: int = 100
var level: int = 1

func initialize(data: Dictionary) -> void:
	enemy_data = data.duplicate()

	health = @warning_ignore("unsafe_call_argument")
	data.get("health", 100)
	max_health = health

	level = @warning_ignore("unsafe_call_argument")
	data.get("level", 1)

func get_enemy_type() -> int:

	return @warning_ignore("unsafe_call_argument")
	enemytest_data.get("enemy_type", 0)

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func take_damage(amount: int) -> int:
	var damage_taken = min(amount, health)
	health -= damage_taken
	return damage_taken

func attack(target: Object) -> Dictionary:
	return {"success": true, "damage": 15}

func generate_loot() -> Dictionary:

	var loot_table = @warning_ignore("unsafe_call_argument")
	enemytest_data.get("loot_table", {})
	return {

		"credits": @warning_ignore("unsafe_call_argument")
	loot_table.get("credits", 50),

		"items": @warning_ignore("unsafe_call_argument")
	loot_table.get("items", [])
	}

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func start_turn() -> void:
	pass

func get_level() -> int:
	return level

func set_level(new_level: int) -> void:
	_level = new_level
'''
	MockEnemyScript.reload() # Compile the script

# Helper Methods
func _create_test_enemy_data() -> Dictionary:
	return {
		"enemy_type": GameEnums.EnemyType.GANGERS if GameEnums.@warning_ignore("unsafe_call_argument")
	EnemyType.has("GANGERS") else 0,
		"name": "Test Enemy",
		"level": 1,
		"health": 100,
		"max_health": 100,
		"armor": 10,
		"damage": 20,
		"abilities": [],
		"loot_table": {
			"credits": 50,
			"items": []
		}
	}

func _create_test_ability(ability_type: int) -> Dictionary:
	return {
		"ability_type": ability_type,
		"damage": 15,
		"cooldown": 2,
		"range": 3,
		"area_effect": false
	}

func _cleanup_test_enemies() -> void:
	for enemy: Node in _tracked_enemies:
		if is_instance_valid(enemy):
			enemy.@warning_ignore("return_value_discarded")
	queue_free()
	_tracked_enemies.clear()

# Test Methods
@warning_ignore("unsafe_method_access")
func test_enemy_initialization() -> void:
	var enemy_data := _create_test_enemy_data()
	assert_that(enemy_data).is_not_null()
	
	# Verify enemy initialization
	assert_that(_enemy.get_enemy_type()).is_equal(enemy_data.enemy_type)
	assert_that(_enemy.get_health()).is_equal(100)

@warning_ignore("unsafe_method_access")
func test_enemy_damage() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Test damage calculation
	var damage := 50
	var actual_damage: int = _enemy.take_damage(damage)

	# Verify damage was applied
	assert_that(actual_damage).is_greater(0)
	assert_that(_enemy.get_health()).is_less(enemy_data.health)

@warning_ignore("unsafe_method_access")
func test_enemy_death() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Kill enemy
	_enemy.take_damage(_enemy.get_max_health())
	
	# Verify death state
	assert_that(_enemy.get_health()).is_equal(0)

@warning_ignore("unsafe_method_access")
func test_enemy_abilities() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Test ability usage with mock target
	var mock_target := Node.new()
	@warning_ignore("return_value_discarded")
	auto_free(mock_target)
	
	var ability_result: Dictionary = _enemy.attack(mock_target)
	
	# Verify ability result
	assert_that(@warning_ignore("unsafe_call_argument")
	ability_result.has("success")).is_true()
	assert_that(@warning_ignore("unsafe_call_argument")
	ability_result.has("damage")).is_true()

@warning_ignore("unsafe_method_access")
func test_enemy_loot() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Kill enemy to trigger loot
	_enemy.take_damage(_enemy.get_max_health())
	
	# Get loot
	var loot: Dictionary = _enemy.generate_loot()
	
	# Verify loot
	assert_that(@warning_ignore("unsafe_call_argument")
	loot.has("credits")).is_true()
	assert_that(loot.credits).is_equal(enemy_data.loot_table.credits)

# Performance Testing
@warning_ignore("unsafe_method_access")
func test_enemy_performance() -> void:
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Create mock target for performance testing
	var mock_target := Node.new()
	@warning_ignore("return_value_discarded")
	auto_free(mock_target)
	
	# Perform multiple operations for performance testing
	for i: int in range(50):
		_enemy.take_damage(5)
		_enemy.attack(mock_target)
		_enemy.heal(2)
		_enemy.start_turn()
		@warning_ignore("unsafe_method_access")
	await get_tree().process_frame
	
	# Verify enemy is still functional after performance test
	assert_that(_enemy.get_health()).is_greater(0)
	assert_that(_enemy.get_level()).is_greater_equal(1)
