@tool
extends "res://tests/fixtures/base_test.gd"

# This is a compatibility proxy for older test files
# All test files should eventually be updated to extend from base_test.gd directly.

var _logger = null

# Required by GUT framework
func set_logger(logger):
	_logger = logger

func get_logger():
	return _logger

# Helper methods
func add_child_autofree(node: Node) -> void:
	add_child(node)
	track_test_node(node)
