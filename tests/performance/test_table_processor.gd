extends "res://addons/gut/test.gd"

const TableProcessor = preload("res://src/core/systems/TableProcessor.gd")
const TableLoader = preload("res://src/core/systems/TableLoader.gd")

var processor: TableProcessor
var test_table: TableProcessor.Table
var error_messages: Array[String] = []

func before_each() -> void:
	processor = TableProcessor.new()
	test_table = TableProcessor.Table.new("test_table")
	error_messages.clear()
	
	# Add some test entries
	test_table.add_entry(TableProcessor.TableEntry.new(1, 20, "Common Result"))
	test_table.add_entry(TableProcessor.TableEntry.new(21, 40, "Uncommon Result"))
	test_table.add_entry(TableProcessor.TableEntry.new(41, 60, "Rare Result"))
	test_table.add_entry(TableProcessor.TableEntry.new(61, 80, "Very Rare Result"))
	test_table.add_entry(TableProcessor.TableEntry.new(81, 100, "Legendary Result"))
	
	processor.register_table(test_table)

func after_each() -> void:
	processor.free()

func test_table_registration() -> void:
	assert_true(processor.has_table("test_table"))
	assert_eq(processor.get_table("test_table").name, "test_table")

func test_basic_roll() -> void:
	var result = processor.roll_table("test_table")
	assert_true(result["success"])
	assert_not_null(result["result"])

func test_custom_roll() -> void:
	var result = processor.roll_table("test_table", 50)
	assert_true(result["success"])
	assert_eq(result["result"], "Rare Result")

func test_weighted_roll() -> void:
	var weighted_table = TableProcessor.Table.new("weighted_test")
	weighted_table.add_entry(TableProcessor.TableEntry.new(1, 100, "Common", 0.7))
	weighted_table.add_entry(TableProcessor.TableEntry.new(1, 100, "Uncommon", 0.2))
	weighted_table.add_entry(TableProcessor.TableEntry.new(1, 100, "Rare", 0.1))
	
	processor.register_table(weighted_table)
	
	var common_count = 0
	var uncommon_count = 0
	var rare_count = 0
	
	for i in range(1000):
		var result = processor.roll_weighted_table("weighted_test")
		match result["result"]:
			"Common": common_count += 1
			"Uncommon": uncommon_count += 1
			"Rare": rare_count += 1
	
	# Check if the distribution roughly matches the weights
	assert_true(common_count > uncommon_count)
	assert_true(uncommon_count > rare_count)
	assert_true(common_count > 500) # Should be around 700
	assert_true(rare_count < 200) # Should be around 100

func test_validation_rules() -> void:
	var validated_table = TableProcessor.Table.new("validated_test")
	validated_table.add_entry(TableProcessor.TableEntry.new(1, 100, "Valid Result"))
	
	# Add a validation rule that only allows even numbers
	validated_table.add_validation_rule(
		func(roll: int) -> Dictionary:
			return {
				"valid": roll % 2 == 0,
				"reason": "Roll must be even"
			}
	)
	
	processor.register_table(validated_table)
	
	var odd_roll = processor.roll_table("validated_test", 15)
	var even_roll = processor.roll_table("validated_test", 16)
	
	assert_false(odd_roll["success"])
	assert_true(even_roll["success"])

func test_modifiers() -> void:
	var modified_table = TableProcessor.Table.new("modified_test")
	modified_table.add_entry(TableProcessor.TableEntry.new(1, 100, 10))
	
	# Add a modifier that doubles the result
	modified_table.add_modifier(
		func(result: Variant) -> Variant:
			return result * 2
	)
	
	processor.register_table(modified_table)
	
	var result = processor.roll_table("modified_test", 50)
	assert_eq(result["result"], 20)

func test_history_tracking() -> void:
	processor.roll_table("test_table", 50)
	processor.roll_table("test_table", 75)
	
	var history = processor.get_roll_history("test_table")
	assert_eq(history.size(), 2)
	assert_eq(history[0]["roll"], 50)
	assert_eq(history[1]["roll"], 75)

func test_table_serialization() -> void:
	var table_data = {
		"name": "serialized_test",
		"entries": [
			{
				"roll_range": [1, 50],
				"result": "First Half",
				"weight": 1.0,
				"tags": ["common"]
			},
			{
				"roll_range": [51, 100],
				"result": "Second Half",
				"weight": 1.0,
				"tags": ["common"]
			}
		]
	}
	
	var loaded_table = TableLoader.create_table_from_data(table_data)
	assert_not_null(loaded_table)
	assert_eq(loaded_table.name, "serialized_test")
	
	processor.register_table(loaded_table)
	var result = processor.roll_table("serialized_test", 75)
	assert_eq(result["result"], "Second Half")

func test_table_persistence() -> void:
	# Roll some test results
	processor.roll_table("test_table", 25)
	processor.roll_table("test_table", 75)
	
	# Serialize
	var serialized = processor.serialize()
	assert_true(serialized.has("history"))
	assert_eq(serialized["history"].size(), 2)
	
	# Create new processor and deserialize
	var new_processor = TableProcessor.new()
	new_processor.deserialize(serialized)
	
	# Check history was restored
	var history = new_processor.get_roll_history()
	assert_eq(history.size(), 2)
	assert_eq(history[0]["roll"], 25)
	assert_eq(history[1]["roll"], 75)
	
	new_processor.free()