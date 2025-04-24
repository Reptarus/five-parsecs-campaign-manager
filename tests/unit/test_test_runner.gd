## Test Runner Diagnostic
## This is a very simple test to help diagnose GUT issues
@tool
extends "res://addons/gut/test.gd"

# No external dependencies, no imports

func test_gut_is_working():
	# Simplest possible test
	assert_true(true, "This test should always pass")
	
func test_simple_math():
	# Basic arithmetic
	assert_eq(2 + 2, 4, "Basic addition should work")
	
func test_simple_array():
	# Simple array operations
	var array = [1, 2, 3]
	assert_eq(array.size(), 3, "Array should have correct size")