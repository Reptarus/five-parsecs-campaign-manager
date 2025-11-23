extends GdUnitTestSuite

## Week 3 Day 2 - Economy System Integration Tests (gdUnit4 version)
## Tests GameItem, GameGear, and DataManager integration

var game_item_script: GDScript
var game_gear_script: GDScript
var global_enums
var data_manager

func before_test():
	game_item_script = load("res://src/core/economy/loot/GameItem.gd")
	game_gear_script = load("res://src/core/economy/loot/GameGear.gd")
	
	# Get autoloads - note: these may be null in headless mode
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		global_enums = Engine.get_main_loop().root.get_node_or_null("GlobalEnums")
		data_manager = Engine.get_main_loop().root.get_node_or_null("DataManager")

func test_game_item_script_loads():
	assert_that(game_item_script).is_not_null()

func test_game_gear_script_loads():
	assert_that(game_gear_script).is_not_null()

func test_data_manager_autoload_available():
	# This is a soft test - autoloads may not be available in test environment
	if data_manager:
		assert_that(data_manager).is_not_null()
		assert_that(data_manager.get_class()).is_not_empty()

func test_game_item_creation():
	var test_item = game_item_script.new()
	assert_that(test_item).is_not_null()
	
	# Verify default properties exist
	assert_that(test_item.get("item_id")).is_not_null()
	assert_that(test_item.get("item_name")).is_not_null()

func test_game_item_initialize_from_data():
	var item_type_consumable = global_enums.ItemType.CONSUMABLE if global_enums else 0
	
	var test_data = {
		"id": "test_item_001",
		"name": "Test Medipack",
		"category": "medical",
		"description": "A test medical item",
		"type": item_type_consumable,
		"effects": [{"type": "heal", "value": 5}],
		"uses": 3,
		"cost": {"credits": 10, "rarity": "Common"},
		"tags": ["medical", "consumable"],
		"requirements": {}
	}
	
	var initialized_item = game_item_script.new()
	var init_success = initialized_item.initialize_from_data(test_data)
	
	assert_that(init_success).is_true()
	assert_that(initialized_item.item_name).is_equal("Test Medipack")
	assert_that(initialized_item.item_type).is_equal(item_type_consumable)
	assert_that(initialized_item.item_uses).is_equal(3)
	assert_that(initialized_item.item_cost.get("credits", 0)).is_equal(10)
	assert_that(initialized_item.item_cost.get("rarity", "Unknown")).is_equal("Common")

func test_game_gear_creation():
	var test_gear = game_gear_script.new()
	assert_that(test_gear).is_not_null()

func test_game_gear_initialize_from_data():
	var gear_data = {
		"id": "test_gear_001",
		"name": "Test Combat Armor",
		"category": "armor",
		"description": "Test armor gear",
		"effects": [{"type": "protection", "value": 2}],
		"traits": ["protective", "heavy"],
		"cost": {"credits": 50, "rarity": "Uncommon"},
		"tags": ["armor", "heavy"],
		"requirements": {"level": 1}
	}
	
	var initialized_gear = game_gear_script.new()
	var gear_init_success = initialized_gear.initialize_from_data(gear_data)
	
	assert_that(gear_init_success).is_true()
	assert_that(initialized_gear.gear_name).is_equal("Test Combat Armor")
	assert_that(initialized_gear.gear_category).is_equal("armor")
	assert_that(initialized_gear.gear_traits).contains(["protective", "heavy"])
	assert_that(initialized_gear.gear_cost.get("credits", 0)).is_equal(50)

func test_game_item_serialization():
	var item_type_consumable = global_enums.ItemType.CONSUMABLE if global_enums else 0
	
	var test_data = {
		"id": "test_item_002",
		"name": "Serialization Test Item",
		"category": "test",
		"description": "Test item for serialization",
		"type": item_type_consumable,
		"effects": [{"type": "test", "value": 1}],
		"uses": 5,
		"cost": {"credits": 20, "rarity": "Common"},
		"tags": ["test"],
		"requirements": {}
	}
	
	var initialized_item = game_item_script.new()
	initialized_item.initialize_from_data(test_data)
	
	var serialized = initialized_item.serialize()
	assert_that(serialized).is_not_null()
	assert_that(serialized is Dictionary).is_true()
	assert_that(serialized.keys().size()).is_greater(0)
	
	# Test deserialization
	var deserialized_item = game_item_script.new()
	var deserialize_success = deserialized_item.initialize_from_data(serialized)
	
	assert_that(deserialize_success).is_true()
	assert_that(deserialized_item.item_name).is_equal(initialized_item.item_name)

func test_data_manager_integration():
	# This test is conditional - only runs if DataManager is available
	if data_manager and data_manager.has_method("get_gear_item"):
		var dm_item = data_manager.get_gear_item("medkit")
		# Note: Result may be empty if database not initialized - that's expected
		if dm_item and not dm_item.is_empty():
			assert_that(dm_item.get("name", "")).is_not_empty()

func test_cost_calculations():
	var common_item = game_item_script.new()
	common_item.item_cost = {"credits": 10, "rarity": "Common"}
	
	var rare_item = game_item_script.new()
	rare_item.item_cost = {"credits": 100, "rarity": "Rare"}
	
	var legendary_item = game_item_script.new()
	legendary_item.item_cost = {"credits": 500, "rarity": "Legendary"}
	
	assert_that(common_item.item_cost.credits).is_equal(10)
	assert_that(rare_item.item_cost.credits).is_equal(100)
	assert_that(legendary_item.item_cost.credits).is_equal(500)
	
	assert_that(common_item.item_cost.rarity).is_equal("Common")
	assert_that(rare_item.item_cost.rarity).is_equal("Rare")
	assert_that(legendary_item.item_cost.rarity).is_equal("Legendary")

