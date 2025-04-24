## Ultra simple test that avoids all dependencies
@tool
extends "res://addons/gut/test.gd"

# No dependencies to other scripts
# No complex data structures

func test_simple_boolean() -> void:
	# The simplest possible test
	assert_true(true, "True is true")
	assert_false(false, "False is false")

func test_direct_math() -> void:
	# Basic math operations
	assert_eq(2 + 2, 4, "2 + 2 = 4")
	assert_gt(5, 3, "5 > 3")