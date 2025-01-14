@tool
class_name BaseTest
extends "res://addons/gut/test.gd"

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Test lifecycle methods
func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# Common test utilities
func cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
		await node.tree_exited

func assert_between(value: float, min_value: float, max_value: float, message: String = "") -> void:
	var in_range := value >= min_value and value <= max_value
	assert_true(in_range, "%s Expected value between %f and %f, got %f" % [
		message if message else "",
		min_value,
		max_value,
		value
	])

func assert_string_contains(value: Variant, search: Variant, match_case: bool = true) -> Variant:
	var text := str(value)
	var substring := str(search)
	var contains := text.contains(substring) if match_case else text.to_lower().contains(substring.to_lower())
	assert_true(contains, "Expected '%s' to contain '%s'" % [text, substring])
	return null

func assert_has(dict: Dictionary, key: String, message: String = "") -> void:
	var has_key := dict.has(key)
	assert_true(has_key, "%s Expected dictionary to have key '%s'" % [
		message if message else "",
		key
	])