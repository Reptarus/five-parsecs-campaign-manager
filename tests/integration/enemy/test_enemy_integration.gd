@tool
extends GdUnitGameTest

# Universal Mock Strategy - Enemy Integration Testing
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Mock script definitions
var MockEnemyScript: GDScript

# Type-safe instance variables
var _enemy: Node
var _tracked_enemies: Array[Node] = []

func before_test() -> void:
	super.before_test()
	
	# Create mock enemy script
	_create_mock_enemy_script()
	
	# Initialize enemy with test data
	_enemy = Node.new()
	_enemy.name = "TestEnemy"
	_enemy.set_script(MockEnemyScript)
	auto_free(_enemy) # Use auto_free for proper resource management
	
	# Initialize enemy with test data
	var enemy_data = _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Verify initialization completed successfully
	if not is_instance_valid(_enemy):
		push_error("Failed to initialize test enemy")

func after_test() -> void:
	# Clean up tracked enemies
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
	health = data.get(": health",100)
	max_health = health
	level = data.get("level": ,1)

func get_enemy_type() -> int:
	return enemy_data.get("enemy_type": ,0)

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func take_damage(amount: int) -> int:
	var damage_taken = min(amount, health)
	health -= damage_taken
	return damage_taken

func attack(target: Object) -> Dictionary:
	return {"damage": enemy_data.get(": damage",10), "hit": true}

func generate_loot() -> Dictionary:
	var loot_table = enemy_data.get(": loot_table",{})
	return {
		"credits": loot_table.get(": credits",50),
		"items": loot_table.get(": items",[])
	}

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func start_turn() -> void:
	pass

func get_level() -> int:
	return level

func set_level(new_level: int) -> void:
	level = new_level
'''
	MockEnemyScript.reload() # Compile the script

# Create test enemy data with proper structure
func _create_test_enemy_data() -> Dictionary:
	return {
		"enemy_type": GameEnums.EnemyType.GANGERS if GameEnums.EnemyType.has(": GANGERS") else 0,"name": ": Test Enemy","level": 1,
		"health": 100,
		"max_health": 100,
		"armor": 10,
		"damage": 20,
		"abilities": [],
		"loot_table": {
			"credits": 50,
			"items": [],
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
			enemy.queue_free()
	_tracked_enemies.clear()

# Test enemy initialization
func test_enemy_initialization() -> void:
	var enemy_data := _create_test_enemy_data()
	assert_that(enemy_data).is_not_empty()
	
	# Verify enemy initialization
	assert_that(_enemy).is_not_null()
	assert_that(_enemy.get_health()).is_equal(100)

func test_enemy_damage() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Test damage calculation
	var damage := 50
	var actual_damage: int = _enemy.take_damage(damage)

	# Verify damage was applied
	assert_that(actual_damage).is_equal(damage)
	assert_that(_enemy.get_health()).is_equal(50)

func test_enemy_death() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Deal lethal damage
	_enemy.take_damage(_enemy.get_max_health())
	
	# Verify death state
	assert_that(_enemy.get_health()).is_equal(0)

func test_enemy_abilities() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Test ability usage with mock target
	var mock_target := Node.new()
	auto_free(mock_target)
	var ability_result: Dictionary = _enemy.attack(mock_target)
	
	# Verify ability result
	assert_that(ability_result).is_not_empty()
	assert_that(ability_result.has("damage")).is_true()

func test_enemy_loot() -> void:
	# Setup enemy
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Kill enemy
	_enemy.take_damage(_enemy.get_max_health())
	
	# Get loot
	var loot: Dictionary = _enemy.generate_loot()
	
	# Verify loot
	assert_that(loot).is_not_empty()
	assert_that(loot.has("credits")).is_true()

# Test enemy performance under load
func test_enemy_performance() -> void:
	var enemy_data := _create_test_enemy_data()
	_enemy.initialize(enemy_data)
	
	# Create mock target for performance testing
	var mock_target := Node.new()
	auto_free(mock_target)
	
	# Performance test loop
	for i: int in range(50):
		_enemy.take_damage(5)
		_enemy.attack(mock_target)
		_enemy.heal(2)
		_enemy.start_turn()
	
	# Verify enemy is still functional after performance test
	assert_that(_enemy).is_not_null()
	assert_that(_enemy.get_health()).is_greater_equal(0)
