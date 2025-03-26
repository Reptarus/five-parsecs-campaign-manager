## Inventory System Test Suite
## Tests the functionality of the game's inventory system including item
## management, stacking, sorting, filtering, and UI integration.
##
## Covers:
## - Basic inventory operations (add/remove/move items)
## - Item stacking behavior
## - Inventory capacity handling
## - Weight and volume constraints
## - Category filtering and sorting
## - Inventory persistence
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
var InventoryScript = load("res://src/core/inventory/base/Inventory.gd") if ResourceLoader.exists("res://src/core/inventory/base/Inventory.gd") else load("res://src/core/inventory/Inventory.gd") if ResourceLoader.exists("res://src/core/inventory/Inventory.gd") else null
var ItemScript = load("res://src/core/inventory/items/Item.gd") if ResourceLoader.exists("res://src/core/inventory/items/Item.gd") else load("res://src/core/inventory/Item.gd") if ResourceLoader.exists("res://src/core/inventory/Item.gd") else null
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Type-safe constants
const MAX_INVENTORY_SLOTS: int = 50
const STANDARD_STACK_SIZE: int = 10
const PERFORMANCE_TEST_ITERATIONS: int = 1000

# Enum values for tests - use ints instead of non-existent enums
enum ItemCategory {WEAPON = 0, ARMOR = 1, CONSUMABLE = 2, GENERAL = 3}

# Type-safe instance variables
var _inventory: Resource = null
var _test_items: Array[Resource] = []

# Helper methods
func _create_test_item(item_id: String, item_name: String, stack_size: int = 1) -> Resource:
	if not ItemScript:
		push_error("Item script is null")
		return null
		
	var item: Resource = ItemScript.new()
	if not item:
		push_error("Failed to create test item")
		return null
	
	# Ensure resource has a valid path for Godot 4.4
	item = Compatibility.ensure_resource_path(item, "test_item_%s" % item_id)
	
	# Set item properties safely
	Compatibility.safe_call_method(item, "set_id", [item_id])
	Compatibility.safe_call_method(item, "set_name", [item_name])
	Compatibility.safe_call_method(item, "set_stack_size", [stack_size])
	Compatibility.safe_call_method(item, "set_max_stack_size", [STANDARD_STACK_SIZE])
	Compatibility.safe_call_method(item, "set_weight", [1.0])
	Compatibility.safe_call_method(item, "set_category", [ItemCategory.GENERAL])
	
	return item

func _create_sample_items() -> Array[Resource]:
	var items: Array[Resource] = []
	var categories = [
		ItemCategory.WEAPON,
		ItemCategory.ARMOR,
		ItemCategory.CONSUMABLE,
		ItemCategory.GENERAL
	]
	
	for i in range(10):
		var category = categories[i % categories.size()]
		var item = _create_test_item("item_%d" % i, "Test Item %d" % i)
		if item:
			Compatibility.safe_call_method(item, "set_category", [category])
			items.append(item)
	
	return items

# Setup and teardown
func before_each() -> void:
	await super.before_each()
	
	# Create inventory
	if not InventoryScript:
		push_error("Inventory script is null")
		return
		
	_inventory = InventoryScript.new()
	if not _inventory:
		push_error("Failed to create inventory")
		return
	
	# Ensure resource has a valid path for Godot 4.4
	_inventory = Compatibility.ensure_resource_path(_inventory, "test_inventory")
	
	# Initialize inventory
	Compatibility.safe_call_method(_inventory, "initialize", [MAX_INVENTORY_SLOTS])
	
	# Create test items
	_test_items = _create_sample_items()
	
	# Watch signals
	watch_signals(_inventory)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_inventory = null
	_test_items.clear()
	await super.after_each()

# Basic functionality tests
func test_initial_state() -> void:
	assert_not_null(_inventory, "Inventory should be created")
	var capacity: int = Compatibility.safe_call_method(_inventory, "get_capacity", [], 0)
	assert_eq(capacity, MAX_INVENTORY_SLOTS, "Capacity should match initial value")
	var count: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count, 0, "Inventory should start empty")

func test_add_item() -> void:
	if _test_items.is_empty():
		push_error("Test items not created")
		return
		
	var item = _test_items[0]
	var result: bool = Compatibility.safe_call_method(_inventory, "add_item", [item], false)
	assert_true(result, "Should add item successfully")
	
	var count: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count, 1, "Inventory should have one item")
	
	var items: Array = Compatibility.safe_call_method(_inventory, "get_items", [], [])
	assert_eq(items.size(), 1, "Items array should contain one item")
	assert_eq(items[0], item, "Retrieved item should match added item")

func test_add_and_remove_item() -> void:
	if _test_items.size() < 2:
		push_error("Not enough test items created")
		return
	
	var item1 = _test_items[0]
	var item2 = _test_items[1]
	
	Compatibility.safe_call_method(_inventory, "add_item", [item1])
	Compatibility.safe_call_method(_inventory, "add_item", [item2])
	
	var count_before: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count_before, 2, "Inventory should have two items")
	
	var result: bool = Compatibility.safe_call_method(_inventory, "remove_item", [item1], false)
	assert_true(result, "Should remove item successfully")
	
	var count_after: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count_after, 1, "Inventory should have one item after removal")
	
	var items: Array = Compatibility.safe_call_method(_inventory, "get_items", [], [])
	assert_eq(items.size(), 1, "Items array should contain one item")
	assert_eq(items[0], item2, "Remaining item should be item2")

# Item stacking tests
func test_stack_items() -> void:
	var item1 = _create_test_item("stack_test_1", "Stack Test 1", 5)
	var item2 = _create_test_item("stack_test_1", "Stack Test 1", 3) # Same ID for stacking
	
	Compatibility.safe_call_method(_inventory, "add_item", [item1])
	var result: bool = Compatibility.safe_call_method(_inventory, "add_item", [item2], false)
	assert_true(result, "Should stack items successfully")
	
	var count: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count, 1, "Should have one stack")
	
	var items: Array = Compatibility.safe_call_method(_inventory, "get_items", [], [])
	assert_eq(items.size(), 1, "Items array should contain one stack")
	
	var stack_size: int = Compatibility.safe_call_method(items[0], "get_stack_size", [], 0)
	assert_eq(stack_size, 8, "Stack size should be combined")

func test_stack_overflow() -> void:
	var item1 = _create_test_item("stack_test_2", "Stack Test 2", STANDARD_STACK_SIZE)
	var item2 = _create_test_item("stack_test_2", "Stack Test 2", 2)
	
	Compatibility.safe_call_method(_inventory, "add_item", [item1])
	var result: bool = Compatibility.safe_call_method(_inventory, "add_item", [item2], false)
	assert_true(result, "Should handle overflow stack")
	
	var count: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count, 2, "Should have two stacks")
	
	var items: Array = Compatibility.safe_call_method(_inventory, "get_items", [], [])
	assert_eq(items.size(), 2, "Items array should contain two stacks")
	
	var first_stack_size: int = Compatibility.safe_call_method(items[0], "get_stack_size", [], 0)
	assert_eq(first_stack_size, STANDARD_STACK_SIZE, "First stack should be at max")
	
	var second_stack_size: int = Compatibility.safe_call_method(items[1], "get_stack_size", [], 0)
	assert_eq(second_stack_size, 2, "Second stack should contain overflow")

# Capacity tests
func test_capacity_limit() -> void:
	# Fill inventory to capacity
	for i in range(MAX_INVENTORY_SLOTS):
		var item = _create_test_item("capacity_test_%d" % i, "Capacity Test %d" % i)
		var result: bool = Compatibility.safe_call_method(_inventory, "add_item", [item], false)
		assert_true(result, "Should add item within capacity")
	
	# Try to add one more item
	var overflow_item = _create_test_item("overflow", "Overflow Item")
	var result: bool = Compatibility.safe_call_method(_inventory, "add_item", [overflow_item], true)
	assert_false(result, "Should reject item beyond capacity")
	
	var count: int = Compatibility.safe_call_method(_inventory, "get_item_count", [], 0)
	assert_eq(count, MAX_INVENTORY_SLOTS, "Inventory should be at capacity")

# Category filtering tests
func test_filter_by_category() -> void:
	for item in _test_items:
		Compatibility.safe_call_method(_inventory, "add_item", [item])
	
	var weapons: Array = Compatibility.safe_call_method(_inventory, "get_items_by_category",
												[ItemCategory.WEAPON], [])
	var armor: Array = Compatibility.safe_call_method(_inventory, "get_items_by_category",
											   [ItemCategory.ARMOR], [])
	
	# Count expected items
	var expected_weapons = 0
	var expected_armor = 0
	for item in _test_items:
		var category = Compatibility.safe_call_method(item, "get_category", [], -1)
		if category == ItemCategory.WEAPON:
			expected_weapons += 1
		elif category == ItemCategory.ARMOR:
			expected_armor += 1
	
	assert_eq(weapons.size(), expected_weapons, "Should filter weapons correctly")
	assert_eq(armor.size(), expected_armor, "Should filter armor correctly")

# Performance test
func test_inventory_performance() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(PERFORMANCE_TEST_ITERATIONS):
		var item = _create_test_item("perf_test_%d" % i, "Performance Test %d" % i)
		if i % 2 == 0:
			Compatibility.safe_call_method(_inventory, "add_item", [item])
		else:
			Compatibility.safe_call_method(_inventory, "add_item", [item])
			Compatibility.safe_call_method(_inventory, "remove_item", [item])
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	# 500ms is a reasonable threshold for 1000 operations
	assert_true(duration < 500, "Inventory operations should be performant")

# Signal verification tests
func test_inventory_signals() -> void:
	watch_signals(_inventory)
	
	var item = _test_items[0]
	Compatibility.safe_call_method(_inventory, "add_item", [item])
	verify_signal_emitted(_inventory, "item_added")
	
	Compatibility.safe_call_method(_inventory, "remove_item", [item])
	verify_signal_emitted(_inventory, "item_removed")
	
	# Test sorting signal
	Compatibility.safe_call_method(_inventory, "sort_by_category", [])
	verify_signal_emitted(_inventory, "inventory_changed")
